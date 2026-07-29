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

const SAVE_VERSION: int = 2
const SAVE_DIR: String = "user://saves/"
const QUICK_SLOT: String = "quicksave"

signal game_saved(slot: String)
signal game_loaded(slot: String)

## Parsed save waiting to be applied after the scene reload. Static so it
## survives reload_current_scene() (statics live on the script, not the node).
static var _pending_load: Dictionary = {}
## Slot name the pending load came from, so game_loaded reports the slot that was
## actually loaded rather than always "quicksave" (WI-38 A6). Same static-survives-
## the-scene-swap reasoning as _pending_load, and cleared alongside it.
static var _pending_slot: String = ""
## True only while sections are being applied - spawn-on-ready code
## (CrewManager's starting crew) checks this so saved pawns aren't duplicated.
static var _loading: bool = false

var _module_data_by_id: Dictionary[StringName, ModuleData] = {}
var _resource_data_by_id: Dictionary[StringName, ResourceData] = {}

## version -> Callable(data: Dictionary) -> Dictionary, upgrading one version
## step. Static because the menus load saves before any SaveManager node exists
## (WI-36).
static var _migrations: Dictionary[int, Callable] = {
	1: _migrate_1_to_2,
}

## v1 -> v2 (WI-44): in-flight jobs changed shape completely. A v1 job entry is
## {"type": "<job class id>", ...} written by the old per-class serializers; a v2
## entry is {"def": "<JobData id>", "index": <action>, ...} written by
## Job.to_dict(). There is no honest mapping between them - the v1 form records a
## job's STATE ENUM, and the action a resumed job should re-enter has to be
## derived from a driver that did not exist when the save was written.
##
## So they are dropped rather than translated. Everything a dropped job would
## have done gets re-derived on load anyway: board jobs are re-posted by their
## components, needs re-queue from the decay loop, and a pawn left holding cargo
## sweeps it into storage. The cost is one interrupted trip per pawn, once, on
## the first load of an old save - which is exactly the behaviour WI-44 replaced
## for every load, so nothing is lost that the old system guaranteed.
static func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	var pawns: Array = data.get("pawns", [])
	for entry: Variant in pawns:
		var pawn_entry: Dictionary = entry as Dictionary
		if pawn_entry == null:
			continue
		pawn_entry.erase("current_job")
		pawn_entry.erase("job_queue")
	data["version"] = 2
	return data

static func has_pending_load() -> bool:
	return not _pending_load.is_empty()

static func is_loading() -> bool:
	return _loading

## Drops a staged load. New Game from the pause menu goes straight into
## main.tscn, and a leftover pending load would silently restore the old run.
static func clear_pending_load() -> void:
	_pending_load = {}
	_pending_slot = ""

func _ready() -> void:
	Global.save_manager = self
	_build_lookups()
	_reset_resource_runtime_state()
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

## ResourceData is a shared .tres and its runtime fields (global_total, the
## derived cache, the registered-storage list) are mutated all run long. Godot's
## resource cache holds those objects across a scene swap, so WI-36's Quit to Menu
## -> New Game used to start the new run holding the old run's credits (WI-38 A8).
##
## Runs unconditionally: this is the first thing that touches resources in the new
## scene (Managers/ ready before Main._ready calls spawn_starting_station), and on
## the load path _load_resources overwrites these one deferred tick later. Doing it
## unconditionally also means a has_global_store resource added *since* a save was
## written gets its authored seed rather than a stale carried-over value.
##
## registered_storage.clear() is defensive rather than known-broken: registration
## is symmetric today, but that array holds StorageComponent node references and a
## single missed _exit_tree across a scene swap would leave freed objects for
## _recalc_resource to walk.
func _reset_resource_runtime_state() -> void:
	for id: StringName in _resource_data_by_id:
		var resource: ResourceData = _resource_data_by_id[id]
		resource.global_total = resource.starting_global_total
		resource.cached_total = 0
		resource.needs_recalc = true
		resource.registered_storage.clear()

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
		"food":
			var food := FoodInstanceData.new()
			food.quality = float(data.get("quality", FoodInstanceData.DEFAULT_QUALITY))
			food.food_type = StringName(data.get("food_type", ""))
			return food
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

## Reference to a component inside a placed module (WI-21): the owning module's
## layer+cell (as module_ref) plus the node path from the module to the
## component. Same layer+cell+path scheme ModuleBase already uses to key its
## per-storage save data, so a re-placed module resolves the exact component.
static func component_ref(component: ComponentBase) -> Dictionary:
	if component == null or not is_instance_valid(component) or component.owner_module == null:
		return {}
	var ref: Dictionary = module_ref(component.owner_module)
	if ref.is_empty():
		return {}
	ref["path"] = String(component.owner_module.get_path_to(component))
	return ref

static func resolve_component_ref(ref: Dictionary) -> ComponentBase:
	var module: ModuleBase = resolve_module_ref(ref)
	if module == null:
		return null
	var path_str: String = String(ref.get("path", ""))
	if path_str == "":
		return null
	return module.get_node_or_null(NodePath(path_str)) as ComponentBase

## Reference to an asteroid by its stable id (WI-21). Empty for a null/freed
## rock; resolve returns null when the id is gone (mined dry, despawned, or a
## hand-edited save) so a mining job cancels cleanly through its lifecycle.
static func asteroid_ref(asteroid: AsteroidBase) -> Dictionary:
	if asteroid == null or not is_instance_valid(asteroid):
		return {}
	return {"id": asteroid.asteroid_id}

static func resolve_asteroid_ref(ref: Dictionary) -> AsteroidBase:
	if ref.is_empty() or Global.asteroid_manager == null:
		return null
	return Global.asteroid_manager.get_asteroid_by_id(int(ref.get("id", -1)))

## Reference to a pawn by its stable pawn_id (WI-23 ids, WI-44 job targets).
## Pawns are restored before their jobs are rebuilt (_load_pawn_jobs runs at the
## end of the pawn section), so a resolve during job restore always sees them.
static func pawn_ref(pawn: PawnBase) -> Dictionary:
	if pawn == null or not is_instance_valid(pawn) or pawn.pawn_id == 0:
		return {}
	return {"pawn": pawn.pawn_id}

static func resolve_pawn_ref(ref: Dictionary) -> PawnBase:
	if ref.is_empty() or Global.world_manager == null:
		return null
	var target_id: int = int(ref.get("pawn", 0))
	if target_id == 0:
		return null
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group(Groups.PAWN):
		var pawn: PawnBase = node as PawnBase
		if pawn != null and pawn.pawn_id == target_id:
			return pawn
	return null

## Reference to a resource pile by its stable id (WI-21). Piles are saved in the
## piles section with their ids, so resolve scans the live resource_debris group.
static func pile_ref(pile: ResourcePile) -> Dictionary:
	if pile == null or not is_instance_valid(pile):
		return {}
	return {"id": pile.pile_id}

static func resolve_pile_ref(ref: Dictionary) -> ResourcePile:
	if ref.is_empty() or Global.world_manager == null:
		return null
	var target_id: int = int(ref.get("id", -1))
	if target_id < 0:
		return null
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group(Groups.RESOURCE_DEBRIS):
		var pile: ResourcePile = node as ResourcePile
		if pile != null and pile.pile_id == target_id:
			return pile
	return null

# --- save --------------------------------------------------------------------

func save_slot(slot: String) -> Error:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		# Cheap headline stats for the slot list (WI-36), so the menus never have
		# to parse the (large) sections just to render a row.
		"meta": _get_meta(),
		"sections": {
			# Difficulty (WI-37) is a single id rather than a manager section: it's
			# chosen once before the run and never mutates, so there's no state to
			# collect. Written here as well as in meta because meta is a display
			# summary - this is the authoritative field the load path restores from.
			"difficulty": String(Global.difficulty_id()),
			"time": Global.time_manager.get_save_data(),
			"unlocks": Global.unlock_manager.get_save_data(),
			"resources": _get_resources_save(),
			"market": Global.market_manager.get_save_data(),
			"economy": Global.economy_manager.get_save_data(),
			"world": Global.world_manager.get_save_data(),
			"asteroids": Global.asteroid_manager.get_save_data(),
			"turbolifts": Global.turbolift_manager.get_save_data(),
			"piles": _get_piles_save(),
			"pawns": _get_pawns_save(),
			"crew": Global.crew_manager.get_save_data(),
			"traders": Global.trader_manager.get_save_data(),
			"events": Global.event_manager.get_save_data(),
			"contracts": Global.contract_manager.get_save_data(),
			"raid": Global.raid_manager.get_save_data(),
			"visitors": Global.visitor_manager.get_save_data(),
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
	return slot_path(slot)

static func slot_path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"

## Headline stats written into the envelope. Kept to values the slot list shows -
## anything richer belongs in a section, not here.
func _get_meta() -> Dictionary:
	var credits: ResourceData = get_resource_by_id(&"credits")
	return {
		"cycle": Global.time_manager.cycle,
		"hour": Global.time_manager.hour,
		"credits": credits.global_total if credits != null else 0,
		"crew": Global.crew_manager.crew_count() if Global.crew_manager != null else 0,
		"tier": Global.unlock_manager.current_tier if Global.unlock_manager != null else 1,
		# WI-37: the slot list labels each save with the difficulty it was played at.
		"difficulty": String(Global.difficulty_id()),
	}

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
	for node: Node in get_tree().get_nodes_in_group(Groups.RESOURCE_DEBRIS):
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
			"id": pile.pile_id,
			"position": [pile.global_position.x, pile.global_position.y],
			"module": module_ref(pile.parent_module),
			"contents": contents,
		})
	return out

func _get_pawns_save() -> Array:
	var out: Array = []
	for node: Node in get_tree().get_nodes_in_group(Groups.PAWN):
		var pawn: PawnBase = node as PawnBase
		# All pawns are saved and loaded - except the ARC inspector (WI-26): it's
		# driven by a runtime-only InspectionRunner that a load doesn't restore, so a
		# saved inspector would dangle (the in-progress inspection cancels cleanly on
		# load and the offer re-rolls). Guest visitors (WI-33) ARE saved: their
		# behavior is self-contained (need-driven), so they resume fine.
		if pawn == null or pawn is InspectorPawn:
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
		# Skills (WI-22): levels + partial xp, own section like needs/health.
		var skills: PawnSkillsComponent = pawn.get_component_by_type(PawnSkillsComponent) as PawnSkillsComponent
		# Traits (WI-22): just the id list; happiness modifiers are re-derived
		# from it on load (see PawnTraitsComponent), never saved as modifiers.
		var traits: PawnTraitsComponent = pawn.get_component_by_type(PawnTraitsComponent) as PawnTraitsComponent
		# Conveyed pawns (WI-15, formalized by WI-20): rides aren't serialized -
		# a pawn a carrier owns saves as standing at the cab's current floor
		# module, never a mid-shaft position. If ride state ever does get
		# saved (WI-21+), RideRequest.to_floor is the module ref to record.
		var save_module: ModuleBase = pawn.current_module
		var save_position: Vector2 = pawn.global_position
		var cab: TurboliftCab = pawn.path_position_override as TurboliftCab
		if cab != null:
			var ride_floor: ModuleTurbolift = cab.current_turbolift
			if ride_floor == null and cab.shaft != null:
				ride_floor = cab.get_closest_exit()
			if ride_floor != null:
				save_module = ride_floor
				save_position = ride_floor.get_global_center()

		var entry: Dictionary = {
			"scene": pawn.scene_file_path,
			"name": pawn.pawn_name,
			# Stable save id (WI-23): workspace assignments persist by this id.
			"pawn_id": pawn.pawn_id,
			# Identity tint (WI-22) - saved so a pawn keeps its colour, unlike the
			# instance-id-reseeded cosmetic jitter.
			"tint": [pawn.tint.r, pawn.tint.g, pawn.tint.b, pawn.tint.a],
			# What the pawn cost to hire (WI-22); WI-25 wages read it.
			"hire_price": pawn.hire_price,
			# Personal wallet (WI-33): routed wages / visitor funds. Restored as 0
			# on pre-WI-33 saves (missing key), same as a pawn that never earned.
			"personal_credits": pawn.personal_credits,
			"position": [save_position.x, save_position.y],
			"module": module_ref(save_module),
			"needs": needs.get_save_data() if needs != null else {},
			"health": health.get_save_data() if health != null else {},
			"skills": skills.get_save_data() if skills != null else {},
			"traits": traits.get_save_data() if traits != null else [],
			"schedule": Array(pawn.schedule.slots) if pawn.schedule != null else [],
			"carried": carried,
		}
		# Diseases (WI-31): active-disease state (stage/timers/treatment progress);
		# staged effects re-derive from it on load, never saved as modifiers. Absent
		# when the crew member is well, so a healthy station stays lean.
		var disease: PawnDiseaseComponent = pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
		if disease != null:
			var disease_save: Dictionary = disease.get_save_data()
			if not disease_save.is_empty():
				entry["disease"] = disease_save
		# EVA accrual toward Void Sickness (WI-31); absent for interior crew.
		var breathing: PawnBreathingComponent = pawn.get_component_by_type(PawnBreathingComponent) as PawnBreathingComponent
		if breathing != null:
			var breathing_save: Dictionary = breathing.get_save_data()
			if not breathing_save.is_empty():
				entry["breathing"] = breathing_save
		# Mining Drones need their parent
		if pawn is MiningDronePawn and (pawn as MiningDronePawn).parent_mining_component != null:
			entry["mining_comp"] = component_ref((pawn as MiningDronePawn).parent_mining_component)
		# Hauler robots (WI-27) ride the same way, referencing their Logistics Bay.
		if pawn is HaulerRobotPawn and (pawn as HaulerRobotPawn).parent_bay != null:
			entry["logistics_bay"] = component_ref((pawn as HaulerRobotPawn).parent_bay)
		# Robot battery + integrity (WI-28), only present on robots. Charger and
		# repair-bay slot occupancy is runtime-only and re-derives on load.
		var robot_power: RobotPowerComponent = pawn.get_component_by_type(RobotPowerComponent) as RobotPowerComponent
		if robot_power != null:
			entry["robot_power"] = robot_power.get_save_data()
		var robot_integrity: RobotIntegrityComponent = pawn.get_component_by_type(RobotIntegrityComponent) as RobotIntegrityComponent
		if robot_integrity != null:
			entry["robot_integrity"] = robot_integrity.get_save_data()
		# Guest visit state (WI-33): stay timer + leaving latch. Only on visitors.
		if pawn is VisitorPawn:
			entry["visitor"] = (pawn as VisitorPawn).get_visitor_save_data()
		# In-flight jobs (WI-21, generalised by WI-44): definition id + target refs
		# + WHICH ACTION is current, so a job resumes on the step it was on rather
		# than restarting. Only saveable jobs serialize (idle, wander, the cargo
		# sweep and the departure job are flagged saveable = false on their .tres
		# and return {}); omit the keys entirely when there's nothing to save.
		var current_job_data: Dictionary = pawn.current_job.to_dict() if pawn.current_job != null else {}
		if not current_job_data.is_empty():
			entry["current_job"] = current_job_data
		var queue_data: Array = _serialize_job_queue(pawn.job_queue)
		if not queue_data.is_empty():
			entry["job_queue"] = queue_data
		out.append(entry)
	return out

## Serializes a pawn's personal queue, preserving order and dropping any jobs
## that aren't saveable (to_dict() == {}).
func _serialize_job_queue(queue: Array[Job]) -> Array:
	var out: Array = []
	for job: Job in queue:
		var job_data: Dictionary = job.to_dict()
		if not job_data.is_empty():
			out.append(job_data)
	return out

# --- load --------------------------------------------------------------------

## Returns false if the slot is missing or unreadable; the current game keeps
## running untouched in that case.
func load_slot(slot: String) -> bool:
	if not stage_load(slot):
		return false
	get_tree().reload_current_scene()
	return true

## Reads, migrates and stages a slot WITHOUT touching the scene tree. Loading
## from the main menu (WI-36) stages here and then enters main.tscn, where the
## fresh SaveManager applies the pending sections exactly as it does after a
## reload. Returns false (and stages nothing) on a missing or unreadable slot.
static func stage_load(slot: String) -> bool:
	var parsed: Dictionary = read_slot(slot)
	if parsed.is_empty():
		return false
	var data: Dictionary = _migrate(parsed)
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Save version %s can't be migrated to %d, load aborted" % [str(data.get("version")), SAVE_VERSION])
		return false
	_pending_load = data
	_pending_slot = slot
	# Difficulty (WI-37) is staged HERE, not in _apply_pending_load: managers read
	# it from _ready onward (RaidManager's gate, every needs component's mood
	# modifier), and _ready runs a deferred tick before the sections apply. Staging
	# at read time also overwrites whatever the main menu's picker left behind, so
	# loading a Hard save after a Peaceful run can't inherit the menu leftover.
	Global.set_difficulty(read_difficulty(data))
	return true

## The difficulty a parsed envelope was played at. Prefers the authoritative
## sections field, falls back to the meta summary, then to Normal - which is what
## every pre-WI-37 save (neither key present) resolves to.
static func read_difficulty(data: Dictionary) -> StringName:
	var sections: Dictionary = data.get("sections", {})
	var from_section: String = String(sections.get("difficulty", ""))
	if from_section != "":
		return StringName(from_section)
	var meta: Dictionary = data.get("meta", {})
	return StringName(String(meta.get("difficulty", String(DifficultyData.DEFAULT_ID))))

## Parses a slot file into its envelope dictionary. Returns {} for anything
## missing, unopenable or malformed - callers treat that as "no such save".
static func read_slot(slot: String) -> Dictionary:
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("No save file: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file: " + path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not (parsed as Dictionary).has("sections"):
		push_warning("Save file is malformed: " + path)
		return {}
	return parsed as Dictionary

## Every slot in user://saves/, newest first. One row per file, each already
## summarized for display - see summarize().
static func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var slot: String = file_name.get_basename()
		var data: Dictionary = read_slot(slot)
		if data.is_empty():
			continue
		out.append(summarize(data, slot))
	# Newest first. Timestamps are Time.get_datetime_string_from_system(), which
	# is ISO-8601, so lexical order is chronological order.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("timestamp", "")) > String(b.get("timestamp", "")))
	return out

## Pure: parsed envelope -> the row the slot list renders. Pre-WI-36 saves have
## no meta block, so the values are recovered from the sections instead (cheap:
## time and resources are tiny, and the pawn list only needs its size). The
## legacy crew figure is approximate - the saved pawn list also holds robots and
## visitors, which crew_count() excludes - but it's a slot subtitle, not a stat.
static func summarize(data: Dictionary, slot: String) -> Dictionary:
	var sections: Dictionary = data.get("sections", {})
	var meta: Dictionary = data.get("meta", {})
	var time_section: Dictionary = sections.get("time", {})
	var resources: Dictionary = sections.get("resources", {})
	var pawns: Array = sections.get("pawns", [])
	return {
		"slot": slot,
		"timestamp": String(data.get("timestamp", "")),
		"version": int(data.get("version", 0)),
		# A version this build can't migrate still lists (so the player can see and
		# delete it), but the menu greys out its Load button.
		"loadable": int(data.get("version", 0)) == SAVE_VERSION or _migrations.has(int(data.get("version", 0))),
		"cycle": int(meta.get("cycle", time_section.get("cycle", 0))),
		"hour": int(meta.get("hour", time_section.get("hour", 0))),
		"credits": int(meta.get("credits", resources.get("credits", 0))),
		"crew": int(meta.get("crew", pawns.size())),
		"tier": int(meta.get("tier", 1)),
		# WI-37. Pre-WI-37 saves carry neither key and read back as Normal, which is
		# also the difficulty they will actually load at.
		"difficulty": String(read_difficulty(data)),
	}

## "Cycle 4, 14:00 · 12340 cr · 6 crew" - the one-line subtitle for a slot row.
static func describe_slot(info: Dictionary) -> String:
	return "Cycle %d, %02d:00 · %d cr · %d crew · Tier %d · %s" % [
		int(info.get("cycle", 0)), int(info.get("hour", 0)),
		int(info.get("credits", 0)), int(info.get("crew", 0)), int(info.get("tier", 1)),
		difficulty_label(StringName(String(info.get("difficulty", DifficultyData.DEFAULT_ID))))]

## Display name for a saved difficulty id, falling back to the id itself if the
## .tres it names has since been renamed or removed.
static func difficulty_label(difficulty_id: StringName) -> String:
	var data: DifficultyData = DifficultyData.by_id(difficulty_id)
	return data.display_name if data != null else String(difficulty_id).capitalize()

## Player-typed slot names become file names, so anything that could walk out of
## user://saves/ (separators, dots, colons) is folded to underscores. Returns ""
## for a name with nothing usable left, which callers reject.
static func sanitize_slot_name(name: String) -> String:
	const ALLOWED: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_"
	var out: String = ""
	for character: String in name.strip_edges():
		out += character if ALLOWED.contains(character) else "_"
	out = out.strip_edges()
	# A name made entirely of separators would produce an unreachable file.
	for character: String in out:
		if character != "_" and character != "-" and character != " ":
			return out
	return ""

static func slot_exists(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))

static func delete_slot(slot: String) -> bool:
	if not slot_exists(slot):
		return false
	return DirAccess.remove_absolute(slot_path(slot)) == OK

static func _migrate(data: Dictionary) -> Dictionary:
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
## world before asteroids/piles/pawns (jobs restored on pawns resolve their
## targets - modules, asteroids, piles - so all three must exist first).
func _apply_pending_load() -> void:
	var data: Dictionary = _pending_load
	var slot: String = _pending_slot
	_pending_load = {}
	_pending_slot = ""
	_loading = true
	var sections: Dictionary = data.get("sections", {})
	Global.time_manager.load_save_data(sections.get("time", {}))
	Global.unlock_manager.load_save_data(sections.get("unlocks", {}))
	_load_resources(sections.get("resources", {}))
	Global.market_manager.load_save_data(sections.get("market", {}))
	# After resources: the economy ledger/loan/insolvency counters restore. No
	# phantom settlement fires - time.load_save_data above announces the restored
	# calendar with calendar_restored rather than replaying cycle_changed (WI-38 A3).
	Global.economy_manager.load_save_data(sections.get("economy", {}))
	Global.world_manager.load_save_data(sections.get("world", {}))
	# After world, before pawns: mining jobs resolve their asteroid by id.
	Global.asteroid_manager.load_save_data(sections.get("asteroids", {}))
	# After world: shafts have re-merged from module adjacency by now.
	Global.turbolift_manager.load_save_data(sections.get("turbolifts", {}))
	# Before pawns: a restored collect-pile job resolves its pile by id.
	_load_piles(sections.get("piles", []))
	_load_pawns(sections.get("pawns", []))
	# After world: pending hires resolve their bay by layer+cell at arrival.
	Global.crew_manager.load_save_data(sections.get("crew", {}))
	# After world AND market: an active visit re-parks its shuttle at the bay
	# and its price snapshot/stock restore by resource id.
	Global.trader_manager.load_save_data(sections.get("traders", {}))
	# After pawns: station-wide happiness effects re-apply to the loaded crew.
	# After market: supply shocks re-register without re-snapping stock.
	Global.event_manager.load_save_data(sections.get("events", {}))
	# After world: contract demand re-registers on the restored bay via the
	# first slow_tick; staged goods are already back in the bin.
	Global.contract_manager.load_save_data(sections.get("contracts", {}))
	# After world: an in-progress raid respawns its ships against the restored
	# station geometry. Events don't re-fire effects on load, so there's no risk
	# of a second raid spawning alongside the restored one (WI-32 edge case).
	Global.raid_manager.load_save_data(sections.get("raid", {}))
	# Visitor economy (WI-33): reputation + arrival pacing. The guest pawns
	# themselves ride in the pawns section (typed like robots); this restores only
	# the manager's standing/accumulator. Independent of other sections' order.
	Global.visitor_manager.load_save_data(sections.get("visitors", {}))
	_loading = false
	print("Loaded save from %s" % Global.time_manager.format_time())
	game_loaded.emit(slot)
	# Load-path counterpart to Main's new-game emission (WI-18): the world is now
	# fully restored and playable. Fires after all sections apply, mirroring the
	# new-game path where it fires after spawn_starting_station.
	SignalBus.game_bootstrapped.emit()

func _load_resources(data: Dictionary) -> void:
	for id_str: String in data:
		var resource: ResourceData = get_resource_by_id(StringName(id_str))
		if resource == null:
			push_warning("Unknown resource id in save, skipping: " + id_str)
			continue
		resource.global_total = int(data[id_str])
		resource.needs_recalc = true

func _load_piles(data: Array) -> void:
	var max_saved_id: int = -1
	for entry: Dictionary in data:
		var pos_arr: Array = entry.get("position", [0, 0])
		var pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		var module: ModuleBase = resolve_module_ref(entry.get("module", {}))
		var parent_node: Node = module.get_parent() if module != null else Global.world_manager.pawn_layer
		var pile: ResourcePile = ResourcePile.spawn(parent_node, pos, module)
		# Restore the saved id (spawn() assigned a fresh one) so a collect job
		# refs resolve to this exact pile.
		pile.pile_id = int(entry.get("id", pile.pile_id))
		max_saved_id = maxi(max_saved_id, pile.pile_id)
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
	# Bump the shared counter past every restored id so post-load piles (which
	# take fresh ids from spawn()) can never collide with a restored one.
	if max_saved_id >= 0:
		ResourcePile._next_pile_id = maxi(ResourcePile._next_pile_id, max_saved_id + 1)

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
		# Stable save id (WI-23). Set before add_child so _ready sees a non-zero id
		# and bumps the counter past it instead of allocating a fresh one. Pre-WI-23
		# saves lack the key (0) and get a freshly-allocated id, same as a new pawn.
		pawn.pawn_id = int(entry.get("pawn_id", 0))
		# Identity tint (WI-22). Set before add_child: the setter no-ops until the
		# sprite resolves, and _ready re-applies the stored value. Pre-WI-22 saves
		# lack the key and keep the scene default (proper crew migration is step 5).
		var tint_arr: Array = entry.get("tint", [])
		if tint_arr.size() >= 3:
			var alpha: float = float(tint_arr[3]) if tint_arr.size() >= 4 else 1.0
			pawn.tint = Color(float(tint_arr[0]), float(tint_arr[1]), float(tint_arr[2]), alpha)
		pawn.hire_price = int(entry.get("hire_price", 0))
		# Personal wallet (WI-33). Missing on pre-WI-33 saves -> 0, same as a pawn
		# that never earned. Set before add_child, like the other scalar identity.
		pawn.personal_credits = int(entry.get("personal_credits", 0))
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
		else:
			# These values won't get updated if we don't push a new module value
			pawn.update_layer_and_sprite()
		var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
		if needs != null:
			needs.load_save_data(entry.get("needs", {}))
		var health: PawnHealthComponent = pawn.get_component_by_type(PawnHealthComponent) as PawnHealthComponent
		if health != null:
			health.load_save_data(entry.get("health", {}))
		var skills: PawnSkillsComponent = pawn.get_component_by_type(PawnSkillsComponent) as PawnSkillsComponent
		if skills != null:
			skills.load_save_data(entry.get("skills", {}))
		var traits: PawnTraitsComponent = pawn.get_component_by_type(PawnTraitsComponent) as PawnTraitsComponent
		if traits != null:
			traits.load_save_data(entry.get("traits", []))
		# Diseases (WI-31) after skills/traits: load_save_data re-derives the skill
		# maluses / mood modifiers / move-speed from the restored disease state, so
		# the base skill levels and trait modifiers must already be in place.
		var disease: PawnDiseaseComponent = pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
		if disease != null:
			disease.load_save_data(entry.get("disease", {}))
		var breathing: PawnBreathingComponent = pawn.get_component_by_type(PawnBreathingComponent) as PawnBreathingComponent
		if breathing != null:
			breathing.load_save_data(entry.get("breathing", {}))
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
		if pawn is MiningDronePawn:
			(pawn as MiningDronePawn).set_owner_component(resolve_component_ref(entry.get("mining_comp", {})) as MiningComponent)
		# Hauler robots (WI-27) re-register with their bay so it re-owns/powers them.
		if pawn is HaulerRobotPawn:
			(pawn as HaulerRobotPawn).set_owner_component(resolve_component_ref(entry.get("logistics_bay", {})) as LogisticsBayComponent)
		# Robot battery + integrity (WI-28). The components are created in
		# RobotPawnBase._ready (on add_child, above), so they resolve here.
		# Missing keys (pre-WI-28 saves) default to full inside load_save_data.
		var robot_power: RobotPowerComponent = pawn.get_component_by_type(RobotPowerComponent) as RobotPowerComponent
		if robot_power != null:
			robot_power.load_save_data(entry.get("robot_power", {}))
		var robot_integrity: RobotIntegrityComponent = pawn.get_component_by_type(RobotIntegrityComponent) as RobotIntegrityComponent
		if robot_integrity != null:
			robot_integrity.load_save_data(entry.get("robot_integrity", {}))
		# Guest visit state (WI-33): stay timer + leaving latch. A guest saved
		# mid-walk-out resumes leaving; the reported latch prevents a double count.
		if pawn is VisitorPawn and entry.has("visitor"):
			(pawn as VisitorPawn).load_visitor_save_data(entry["visitor"])
		# Jobs last (WI-21): module/needs/inventory are all in place, so the
		# restored job's claim gauntlet - run on the pawn's first start_job()
		# tick, not here - sees the true world. Queue in saved order, then push
		# the current job to the front so it runs first; queue_job (not direct
		# assignment) routes it through start_job()'s normal validity/claim path,
		# and a pawn carrying cargo sweeps it before the
		# restored haul re-runs (no double-withdraw). Jobs whose targets are gone
		# deserialize to null and are silently dropped.
		_load_pawn_jobs(pawn, entry, needs)

## Rebuilds current_job + job_queue onto a freshly restored pawn.
func _load_pawn_jobs(pawn: PawnBase, entry: Dictionary, needs: PawnNeedsComponent) -> void:
	for job_data: Dictionary in entry.get("job_queue", []):
		var job: Job = Job.from_dict(job_data)
		if job != null:
			pawn.queue_job(job)
			_adopt_if_need_job(pawn, needs, job)
	var current_job: Job = Job.from_dict(entry.get("current_job", {}))
	if current_job != null:
		pawn.queue_job(current_job, true) # to front: runs before the restored queue
		_adopt_if_need_job(pawn, needs, current_job)

## A restored need job must be re-linked to the component that queued it, or that
## component (which lost its pending-job pointer on load) would queue a second
## job for the same need. Covers organic needs (Eat/Sleep/Recreate) and the robot
## needs (WI-28: recharge -> RobotPowerComponent, repair -> RobotIntegrityComponent).
## No-op for anything else.
func _adopt_if_need_job(pawn: PawnBase, needs: PawnNeedsComponent, job: Job) -> void:
	if needs != null and (job.is_type(&"eat") or job.is_type(&"sleep")
			or job.is_type(&"recreate") or job.is_type(&"shop")):
		needs.adopt_restored_need_job(job)
	elif job.is_type(&"recharge"):
		var power: RobotPowerComponent = pawn.get_component_by_type(RobotPowerComponent) as RobotPowerComponent
		if power != null:
			power.adopt_restored_recharge_job(job)
	elif job.is_type(&"get_repaired"):
		var integrity: RobotIntegrityComponent = pawn.get_component_by_type(RobotIntegrityComponent) as RobotIntegrityComponent
		if integrity != null:
			integrity.adopt_restored_repair_job(job)
	elif job.is_type(&"get_treatment"):
		# Health & disease (WI-31): re-link so the disease component's seek loop
		# treats it as the already-pending job instead of queuing a second.
		var disease: PawnDiseaseComponent = pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
		if disease != null:
			disease.adopt_restored_treatment_job(job)
