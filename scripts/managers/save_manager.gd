class_name SaveManager
extends Node

## Central save/load. One versioned JSON file per slot in user://saves/.
## Each system contributes a section via get_save_data()/load_save_data()
## (the pattern UnlockManager established); this manager owns the envelope,
## the id->definition lookups, and the load orchestration.
##
## Load strategy is full teardown -> rebuild: load_slot() stashes the parsed
## save in a static (so it survives the scene swap), reloads main.tscn, and
## the fresh SaveManager applies the sections once the new tree is ready.
## In-flight jobs are deliberately NOT saved - the board repopulates from
## storage deficits / construction states within a tick of loading.

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves/"
const QUICK_SLOT: String = "quicksave"

signal game_saved(slot: String)
signal game_loaded(slot: String)

## Parsed save waiting to be applied after the scene reload. Static so it
## survives reload_current_scene() (statics live on the script, not the node).
static var _pending_load: Dictionary = {}
## True only while sections are being applied - spawn-on-ready code
## (CrewManager's starting crew) checks this so saved pawns aren't duplicated.
static var _loading: bool = false

var _module_data_by_id: Dictionary[StringName, ModuleData] = {}
var _resource_data_by_id: Dictionary[StringName, ResourceData] = {}

## version -> Callable(data: Dictionary) -> Dictionary, upgrading one version
## step. Empty until the format actually changes.
var _migrations: Dictionary[int, Callable] = {}

static func has_pending_load() -> bool:
	return not _pending_load.is_empty()

static func is_loading() -> bool:
	return _loading

func _ready() -> void:
	Global.save_manager = self
	_build_lookups()
	if has_pending_load():
		# Deferred so the entire new scene tree (managers AND UI) is ready
		# before sections start mutating state.
		call_deferred("_apply_pending_load")

func _unhandled_input(event: InputEvent) -> void:
	# Mark handled BEFORE acting: load_slot frees this scene immediately
	# (reload_current_scene), after which get_viewport() is null.
	if event.is_action_pressed("quick_save"):
		get_viewport().set_input_as_handled()
		save_slot(QUICK_SLOT)
	elif event.is_action_pressed("quick_load"):
		get_viewport().set_input_as_handled()
		load_slot(QUICK_SLOT)

# --- id lookups -------------------------------------------------------------

func _build_lookups() -> void:
	for path: String in ResourceScanner.scan_paths("res://data/modules/"):
		var res: Resource = ResourceLoader.load(path)
		if res is ModuleData:
			_register_id(_module_data_by_id, (res as ModuleData).id, res, path)
	for path: String in ResourceScanner.scan_paths("res://data/resources/"):
		var res: Resource = ResourceLoader.load(path)
		if res is ResourceData:
			_register_id(_resource_data_by_id, (res as ResourceData).id, res, path)

func _register_id(table: Dictionary, id: StringName, res: Resource, path: String) -> void:
	if id == &"":
		push_warning("Save id missing on " + path + " - it cannot be saved/loaded")
		return
	if table.has(id):
		push_warning("Duplicate save id '" + String(id) + "' (" + path + ") - keeping the first")
		return
	table[id] = res

func get_module_data_by_id(id: StringName) -> ModuleData:
	return _module_data_by_id.get(id)

func get_resource_by_id(id: StringName) -> ResourceData:
	return _resource_data_by_id.get(id)

# --- shared serialization helpers -------------------------------------------

## Rebuild an ItemInstanceData from its to_dict() form. Returns null for
## empty/generic entries (null instance_data == plain fungible stack).
static func instance_from_dict(data: Dictionary) -> ItemInstanceData:
	match String(data.get("type", "")):
		"ore":
			var ore := OreInstanceData.new()
			ore.richness = float(data.get("richness", 0.5))
			return ore
	return null

static func stacks_to_dicts(stacks: Array[ResourceStack]) -> Array:
	var out: Array = []
	for stack: ResourceStack in stacks:
		var entry: Dictionary = {"amount": stack.amount}
		if stack.instance_data != null:
			entry["instance"] = stack.instance_data.to_dict()
		out.append(entry)
	return out

static func stack_from_dict(resource: ResourceData, data: Dictionary) -> ResourceStack:
	var stack := ResourceStack.new()
	stack.resource_data = resource
	stack.amount = int(data.get("amount", 0))
	stack.instance_data = instance_from_dict(data.get("instance", {}))
	return stack

## Reference to a placed module instance: layer + root cell uniquely identify
## it (no per-instance ids needed). Null module -> empty dict.
static func module_ref(module: ModuleBase) -> Dictionary:
	if module == null or module.module_data == null:
		return {}
	return {
		"layer": module.module_data.interaction_layer,
		"cell": [module.module_cell.x, module.module_cell.y],
	}

static func resolve_module_ref(ref: Dictionary) -> ModuleBase:
	if ref.is_empty():
		return null
	var cell_arr: Array = ref.get("cell", [])
	if cell_arr.size() != 2:
		return null
	var layer: WorldManager.StructureLayer = int(ref.get("layer", 0)) as WorldManager.StructureLayer
	return Global.world_manager.get_module_by_cell(layer, Vector2i(int(cell_arr[0]), int(cell_arr[1])))

# --- save --------------------------------------------------------------------

func save_slot(slot: String) -> Error:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"sections": {
			"time": Global.time_manager.get_save_data(),
			"unlocks": Global.unlock_manager.get_save_data(),
			"resources": _get_resources_save(),
			"market": Global.market_manager.get_save_data(),
			"world": Global.world_manager.get_save_data(),
			"turbolifts": Global.turbolift_manager.get_save_data(),
			"piles": _get_piles_save(),
			"pawns": _get_pawns_save(),
			"crew": Global.crew_manager.get_save_data(),
			"traders": Global.trader_manager.get_save_data(),
		},
	}
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save file for writing: " + _slot_path(slot))
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Saved '%s' at %s" % [slot, Global.time_manager.format_time()])
	game_saved.emit(slot)
	return OK

func _slot_path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"

## Global (non-storage) resource totals - currently just credits and anything
## else with has_global_store. Storage-held amounts live in the world section.
func _get_resources_save() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in _resource_data_by_id:
		var resource: ResourceData = _resource_data_by_id[id]
		if resource.has_global_store:
			out[String(id)] = resource.global_total
	return out

func _get_piles_save() -> Array:
	var out: Array = []
	for node: Node in get_tree().get_nodes_in_group("resource_debris"):
		var pile: ResourcePile = node as ResourcePile
		if pile == null or pile.is_empty():
			continue
		var contents: Array = []
		for resource: ResourceData in pile.get_contained_resources():
			if resource.id == &"":
				continue
			contents.append({
				"resource": String(resource.id),
				"stacks": stacks_to_dicts(pile.contents[resource].stacks),
			})
		out.append({
			"position": [pile.global_position.x, pile.global_position.y],
			"module": module_ref(pile.parent_module),
			"contents": contents,
		})
	return out

func _get_pawns_save() -> Array:
	var out: Array = []
	for node: Node in get_tree().get_nodes_in_group("pawn"):
		var pawn: PawnBase = node as PawnBase
		# Drones are transient: their MiningComponent rebuilds them (cargo in
		# flight is acceptable v1 loss - documented in WI-03).
		if pawn == null or pawn is MiningDronePawn:
			continue
		var carried: Array = []
		if pawn.inventory_component != null:
			for resource: ResourceData in pawn.inventory_component.get_carried_resources():
				if resource.id == &"":
					continue
				carried.append({
					"resource": String(resource.id),
					"stacks": stacks_to_dicts(pawn.inventory_component.carried[resource].stacks),
				})
		var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
		# Health lives in its own component (WI-05), so it gets its own section.
		var health: PawnHealthComponent = pawn.get_component_by_type(PawnHealthComponent) as PawnHealthComponent
		# Mid-turbolift-ride pawns (WI-15): rides aren't serialized, so instead
		# of popping out at their raw position inside the shaft wall, they
		# "arrive early" - saved standing at the cab's current floor module.
		var save_module: ModuleBase = pawn.current_module
		var save_position: Vector2 = pawn.global_position
		var cab: TurboliftCab = pawn.path_position_override as TurboliftCab
		if cab != null:
			var ride_floor: ModuleTurbolift = cab.current_turbolift
			if ride_floor == null and cab.shaft != null:
				ride_floor = cab.get_closest_exit()
			if ride_floor != null:
				save_module = ride_floor
				save_position = ride_floor.global_position + ride_floor.get_waiting_slot()
		out.append({
			"scene": pawn.scene_file_path,
			"name": pawn.pawn_name,
			"position": [save_position.x, save_position.y],
			"module": module_ref(save_module),
			"needs": needs.get_save_data() if needs != null else {},
			"health": health.get_save_data() if health != null else {},
			"schedule": Array(pawn.schedule.slots) if pawn.schedule != null else [],
			"carried": carried,
		})
	return out

# --- load --------------------------------------------------------------------

## Returns false if the slot is missing or unreadable; the current game keeps
## running untouched in that case.
func load_slot(slot: String) -> bool:
	if not FileAccess.file_exists(_slot_path(slot)):
		push_warning("No save file: " + _slot_path(slot))
		return false
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		push_warning("Could not open save file: " + _slot_path(slot))
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not (parsed as Dictionary).has("sections"):
		push_warning("Save file is malformed, load aborted: " + _slot_path(slot))
		return false
	var data: Dictionary = _migrate(parsed)
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Save version %s can't be migrated to %d, load aborted" % [str(data.get("version")), SAVE_VERSION])
		return false
	_pending_load = data
	get_tree().reload_current_scene()
	return true

func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	while version < SAVE_VERSION:
		if not _migrations.has(version):
			break # unmigratable - load_slot rejects it on the version check
		data = _migrations[version].call(data)
		var new_version: int = int(data.get("version", version))
		if new_version <= version:
			break # defensive: a migration must advance the version
		version = new_version
	return data

## Runs on the fresh scene, one deferred tick after every _ready(). Section
## order matters: time first (systems tick in loaded time), unlocks before
## world (ready_constructed applies global modifiers / granted-module checks),
## world before piles/pawns (they resolve module refs by layer+cell).
func _apply_pending_load() -> void:
	var data: Dictionary = _pending_load
	_pending_load = {}
	_loading = true
	var sections: Dictionary = data.get("sections", {})
	Global.time_manager.load_save_data(sections.get("time", {}))
	Global.unlock_manager.load_save_data(sections.get("unlocks", {}))
	_load_resources(sections.get("resources", {}))
	Global.market_manager.load_save_data(sections.get("market", {}))
	Global.world_manager.load_save_data(sections.get("world", {}))
	# After world: shafts have re-merged from module adjacency by now.
	Global.turbolift_manager.load_save_data(sections.get("turbolifts", {}))
	_load_piles(sections.get("piles", []))
	_load_pawns(sections.get("pawns", []))
	# After world: pending hires resolve their bay by layer+cell at arrival.
	Global.crew_manager.load_save_data(sections.get("crew", {}))
	# After world AND market: an active visit re-parks its shuttle at the bay
	# and its price snapshot/stock restore by resource id.
	Global.trader_manager.load_save_data(sections.get("traders", {}))
	_loading = false
	print("Loaded save from %s" % Global.time_manager.format_time())
	game_loaded.emit(QUICK_SLOT)

func _load_resources(data: Dictionary) -> void:
	for id_str: String in data:
		var resource: ResourceData = get_resource_by_id(StringName(id_str))
		if resource == null:
			push_warning("Unknown resource id in save, skipping: " + id_str)
			continue
		resource.global_total = int(data[id_str])
		resource.needs_recalc = true

func _load_piles(data: Array) -> void:
	for entry: Dictionary in data:
		var pos_arr: Array = entry.get("position", [0, 0])
		var pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		var module: ModuleBase = resolve_module_ref(entry.get("module", {}))
		var parent_node: Node = module.get_parent() if module != null else Global.world_manager.pawn_layer
		var pile: ResourcePile = ResourcePile.spawn(parent_node, pos, module)
		if module != null:
			# Re-link so future overflow tops up this pile instead of spawning
			# a second one; _despawn() clears the link itself.
			module.overflow_pile = pile
		for content: Dictionary in entry.get("contents", []):
			var resource: ResourceData = get_resource_by_id(StringName(String(content.get("resource", ""))))
			if resource == null:
				push_warning("Unknown resource id in saved pile, skipping: " + str(content.get("resource")))
				continue
			var stacks: Array[ResourceStack] = []
			for stack_dict: Dictionary in content.get("stacks", []):
				stacks.append(stack_from_dict(resource, stack_dict))
			# add_stacks also posts the collection job, same as live overflow.
			pile.add_stacks(resource, stacks)

func _load_pawns(data: Array) -> void:
	for entry: Dictionary in data:
		var scene_path: String = String(entry.get("scene", ""))
		var scene: PackedScene = load(scene_path) if scene_path != "" else null
		if scene == null:
			push_warning("Unknown pawn scene in save, skipping: " + scene_path)
			continue
		var pawn: PawnBase = scene.instantiate() as PawnBase
		if pawn == null:
			push_warning("Saved pawn scene is not a PawnBase, skipping: " + scene_path)
			continue
		pawn.pawn_name = String(entry.get("name", ""))
		# Add to tree first: current_module's setter reparents, which needs a
		# parent to exist (CrewManager.spawn_crew follows the same order).
		Global.world_manager.pawn_layer.add_child(pawn)
		var pos_arr: Array = entry.get("position", [0, 0])
		pawn.global_position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
		# Missing module (deleted mid-save / in-transit pawn) -> stays in
		# space at their last position and paths home via an airlock.
		var module: ModuleBase = resolve_module_ref(entry.get("module", {}))
		if module != null:
			pawn.current_module = module
		var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
		if needs != null:
			needs.load_save_data(entry.get("needs", {}))
		var health: PawnHealthComponent = pawn.get_component_by_type(PawnHealthComponent) as PawnHealthComponent
		if health != null:
			health.load_save_data(entry.get("health", {}))
		# Painted schedules are per-pawn state; _ready already duplicated the
		# scene's shared default, so writing into slots is safe. Shift state
		# itself isn't saved - is_on_shift() derives from the loaded hour.
		var saved_schedule: Array = entry.get("schedule", [])
		if pawn.schedule != null and not saved_schedule.is_empty():
			for i: int in mini(saved_schedule.size(), pawn.schedule.slots.size()):
				pawn.schedule.slots[i] = int(saved_schedule[i])
		for content: Dictionary in entry.get("carried", []):
			var resource: ResourceData = get_resource_by_id(StringName(String(content.get("resource", ""))))
			if resource == null:
				push_warning("Unknown resource id in saved pawn inventory, skipping: " + str(content.get("resource")))
				continue
			var stacks: Array[ResourceStack] = []
			for stack_dict: Dictionary in content.get("stacks", []):
				stacks.append(stack_from_dict(resource, stack_dict))
			pawn.inventory_component.add_stacks(resource, stacks)
