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

const SAVE_VERSION: int = 3
const SAVE_DIR: String = "user://saves/"
const QUICK_SLOT: String = "quicksave"

## Where slots are read and written. [constant SAVE_DIR] everywhere but the
## integration suite (WI-69), which points it at a directory of its own so a
## test's save/reload never lands in the player's real `user://saves/`. Static
## for the same reason [member _pending_load] is: the path has to be the same on
## both sides of the scene swap a load performs.
static var _save_dir: String = SAVE_DIR

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

## Registered sections (WI-47 M3), in registration order; sorted on use.
##
## STATIC on purpose. SaveManager is deliberately LAST under Managers/ (it applies
## a pending load deferred), so it does not exist yet when the systems that feed it
## are readying - there is no instance for them to register into. Registration
## replaces by id, so the scene reload a load performs refreshes every vanilla
## entry, and anything left pointing at a freed node is dropped by is_live().
static var _sections: Array[SaveSection] = []

## Sections read from the last loaded save that nobody claimed - a mod's state
## while the mod is disabled. Written back out untouched on the next save (WI-47
## M3), so turning a mod off for one session doesn't destroy its data.
##
## "Untouched" means semantically, not byte-for-byte: the block goes through
## JSON.parse_string on the way in, and JSON has a single number type, so an int
## comes back a float. Every vanilla load_save_data already coerces with int()/
## float() for that reason - a mod reading its own section is under the same
## obligation whether or not it sat out a session.
var _unclaimed_sections: Dictionary = {}

## version -> Callable(data: Dictionary) -> Dictionary, upgrading one version
## step. Static because the menus load saves before any SaveManager node exists
## (WI-36).
static var _migrations: Dictionary[int, Callable] = {
	1: _migrate_1_to_2,
	2: _migrate_2_to_3,
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

## v2 -> v3 (WI-65): a module's input bin and output bin became one bin.
##
## A v2 save of a refinery has two blocks under `storage`, keyed by node path -
## "Input Storage" and "Output Storage", or "Input"/"Output" on the growers - and
## the v3 scene has one node called "Storage Bay". Left alone, ModuleBase's walk
## iterates live components and would restore neither: both saved paths are
## orphans, and the player's ore and iron would silently vanish, which is exactly
## what _warn_orphaned_blocks exists to shout about.
##
## So the pair is folded. Contents merge (the two never held the same resource -
## one side's ingredients, the other's products), and the priority is taken from
## the INPUT block: an output slot's priority is derived from its role in v3 and
## whatever the old export bin was tuned to no longer means anything.
##
## Roles themselves are NOT written here. They are derived on load by whatever
## configures the bin - the recipe for a processor, the order sheet for a bay -
## all of which run in the ready pass, before this block is applied. A v2 save
## that named a recipe which has since changed would otherwise restore slots
## roled for a recipe that no longer exists.
static func _migrate_2_to_3(data: Dictionary) -> Dictionary:
	var sections: Dictionary = data.get("sections", {})
	var world: Dictionary = sections.get("world", {})
	for entry: Variant in world.get("modules", []):
		var module: Dictionary = entry as Dictionary
		if module == null or not module.has("storage"):
			continue
		var bins: Dictionary = module["storage"]
		var input_key: String = ""
		var output_key: String = ""
		for key: String in bins:
			var lowered: String = key.to_lower()
			if lowered.begins_with("input"):
				input_key = key
			elif lowered.begins_with("output"):
				output_key = key
		if input_key == "" or output_key == "":
			continue
		var merged: Dictionary = bins[input_key]
		var resources: Dictionary = merged.get("resources", {})
		for id_str: String in Dictionary(bins[output_key]).get("resources", {}):
			# An id in both blocks would be a resource that was an ingredient AND a
			# product of the same recipe, which v3 asserts against. Keep the input
			# side rather than guessing, and say so.
			if resources.has(id_str):
				push_warning("WI-65 migration: %s appears in both bins of a module, keeping the input side"
					% id_str)
				continue
			resources[id_str] = Dictionary(bins[output_key])["resources"][id_str]
		merged["resources"] = resources
		bins.erase(input_key)
		bins.erase(output_key)
		bins["Storage Bay"] = merged
	data["version"] = 3
	return data

# --- section registry (WI-47 M3) ------------------------------------------------

## Declares a top-level save section. Call from the contributing system's _ready(),
## next to its Global registration. Re-registering an id replaces it, which is what
## makes this survive the scene reload a load performs.
##
## `order` is both the write order and the restore order - see the vanilla numbers
## in each manager for what depends on what. A mod manager with no constraints
## should sit above every vanilla number so it restores against a finished station.
static func register_section(id: StringName, order: int, collect: Callable, apply: Callable,
		empty: Variant = {}) -> void:
	if id == &"":
		push_warning("SaveManager: refusing to register a section with no id")
		return
	for index: int in _sections.size():
		if _sections[index].id == id:
			_sections[index] = SaveSection.new(id, order, collect, apply, empty)
			return
	_sections.append(SaveSection.new(id, order, collect, apply, empty))

## Registered sections in restore order. Prunes entries whose node has been freed
## on the way past, so a removed mod manager stops being called.
static func sections_in_order() -> Array[SaveSection]:
	var live: Array[SaveSection] = []
	for section: SaveSection in _sections:
		if section.is_live():
			live.append(section)
	_sections = live
	# Explicitly tiebroken on id, since Array.sort_custom is not stable and two
	# sections at one order must not swap between runs.
	live = live.duplicate()
	live.sort_custom(func(a: SaveSection, b: SaveSection) -> bool:
		if a.order != b.order:
			return a.order < b.order
		return String(a.id) < String(b.id))
	return live

## Test seam, mirroring JobDataRegistry.clear_for_test: the registry is static and
## therefore shared by every suite in a run.
static func clear_sections_for_test() -> void:
	_sections = []

## Test seam (WI-69): redirects every slot read, write, listing and delete to
## `dir`, which must end in a slash. [StationFixture] sets it on boot and passes
## [constant SAVE_DIR] back on teardown. Nothing in the game calls this.
static func set_save_dir_for_test(dir: String) -> void:
	_save_dir = dir

static func save_dir() -> String:
	return _save_dir

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
	# The four sections SaveManager owns itself rather than delegating to a
	# manager. Numbers interleave with the managers' (see each manager's _ready):
	# resources before economy, piles before pawns, pawns before crew/events.
	register_section(&"resources", 30, _get_resources_save, _load_resources)
	register_section(&"piles", 90, _get_piles_save, _load_piles, [])
	register_section(&"pawns", 100, _get_pawns_save, _load_pawns, [])
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
	for path: String in ContentPaths.scan(ContentPaths.MODULES):
		var res: Resource = ResourceLoader.load(path)
		if res is ModuleData:
			_register_id(_module_data_by_id, (res as ModuleData).id, res, path, "ModuleData")
	for path: String in ContentPaths.scan(ContentPaths.RESOURCES):
		var res: Resource = ResourceLoader.load(path)
		if res is ResourceData:
			_register_id(_resource_data_by_id, (res as ResourceData).id, res, path, "ResourceData")

func _register_id(table: Dictionary, id: StringName, res: Resource, path: String, what: String) -> void:
	# Empty and mis-namespaced ids are rejected centrally (WI-47 M1) - two mods
	# both shipping &"crystal" would otherwise collide, and which one won would
	# depend on mod load order.
	if not ContentPaths.accept_id(id, path, what):
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
## Rebuilds a stack's variance data (WI-47 M4). The class comes from the owning
## ResourceData's instance_data_script, not from a table in here: this used to be
## a `match` naming OreInstanceData and FoodInstanceData, so any modded resource
## with has_variance = true silently lost its instance data on every save.
##
## Resolving per-resource rather than through a global type_id table also means two
## mods can both call their variance "purity" without colliding - there is no
## shared namespace to collide in.
static func instance_from_dict(resource: ResourceData, data: Dictionary) -> ItemInstanceData:
	if data.is_empty():
		return null
	var saved_type: String = String(data.get("type", ""))
	if resource == null or resource.instance_data_script == null:
		# A stack that carries variance for a resource that no longer declares any:
		# the mod that owned it is gone, or the .tres lost its script. Dropping the
		# variance keeps the stack (and its amount), which is the fail-soft choice.
		if saved_type != "":
			push_warning("Saved '%s' instance data has no instance_data_script to rebuild it on %s"
					% [saved_type, resource.id if resource != null else &"<null resource>"])
		return null
	var script := resource.instance_data_script as GDScript
	if script == null or not script.can_instantiate():
		push_warning("instance_data_script on '%s' cannot be instantiated" % resource.id)
		return null
	var instance := script.new() as ItemInstanceData
	if instance == null:
		push_warning("instance_data_script on '%s' is not an ItemInstanceData" % resource.id)
		return null
	# The tag is advisory, but a mismatch means the resource's script changed under
	# an existing save and the fields about to be read may not be the ones written.
	if saved_type != "" and saved_type != String(instance.type_id()):
		push_warning("Saved instance type '%s' on '%s' no longer matches its script ('%s') - reading anyway"
				% [saved_type, resource.id, instance.type_id()])
	instance.from_dict(data)
	return instance

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
	stack.instance_data = instance_from_dict(resource, data.get("instance", {}))
	return stack

## Whether `value` is a live instance, and complains when it is a FREED one.
##
## Why every *_ref helper takes a Variant (WI-68 F23): a typed parameter rejects
## a freed object at the call, before the body runs, so the is_instance_valid
## checks these helpers always carried were dead code for the one case they were
## written for. The script error then aborted whichever section collector was
## running - a pile tagged with a since-removed module wrote the whole `piles`
## section empty, and every pile on the station was gone on the next load. A
## freed reference now costs its own entry, never its neighbours'. The warning
## is how the dangling reference behind it gets found.
static func _live(value: Variant, what: String) -> bool:
	if is_instance_valid(value):
		return true
	if typeof(value) == TYPE_OBJECT:
		push_warning("SaveManager: skipped a reference to a freed %s" % what)
	return false

## Reference to a placed module instance: layer + root cell uniquely identify
## it (no per-instance ids needed). Null or freed module -> empty dict.
static func module_ref(module: Variant) -> Dictionary:
	if not _live(module, "module"):
		return {}
	var placed: ModuleBase = module as ModuleBase
	if placed == null or placed.module_data == null:
		return {}
	return {
		"layer": placed.module_data.interaction_layer,
		"cell": [placed.module_cell.x, placed.module_cell.y],
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
static func component_ref(component: Variant) -> Dictionary:
	if not _live(component, "component"):
		return {}
	var part: ComponentBase = component as ComponentBase
	if part == null or not is_instance_valid(part.owner_module):
		return {}
	var ref: Dictionary = module_ref(part.owner_module)
	if ref.is_empty():
		return {}
	ref["path"] = String(part.owner_module.get_path_to(part))
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
static func asteroid_ref(asteroid: Variant) -> Dictionary:
	if not _live(asteroid, "asteroid"):
		return {}
	var rock: AsteroidBase = asteroid as AsteroidBase
	return {"id": rock.asteroid_id} if rock != null else {}

static func resolve_asteroid_ref(ref: Dictionary) -> AsteroidBase:
	if ref.is_empty() or Global.asteroid_manager == null:
		return null
	return Global.asteroid_manager.get_asteroid_by_id(int(ref.get("id", -1)))

## Reference to a pawn by its stable pawn_id (WI-23 ids, WI-44 job targets).
## Pawns are restored before their jobs are rebuilt (_load_pawn_jobs runs at the
## end of the pawn section), so a resolve during job restore always sees them.
static func pawn_ref(pawn: Variant) -> Dictionary:
	if not _live(pawn, "pawn"):
		return {}
	var who: PawnBase = pawn as PawnBase
	if who == null or who.pawn_id == 0:
		return {}
	return {"pawn": who.pawn_id}

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
static func pile_ref(pile: Variant) -> Dictionary:
	if not _live(pile, "pile"):
		return {}
	var heap: ResourcePile = pile as ResourcePile
	return {"id": heap.pile_id} if heap != null else {}

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
		"sections": _collect_sections(),
	}
	DirAccess.make_dir_recursive_absolute(_save_dir)
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
	return _save_dir + slot + ".json"

## Headline stats written into the envelope. Kept to values the slot list shows -
## anything richer belongs in a section, not here.
## Every registered section, in order, plus anything the last load carried that
## nobody claimed. Unclaimed blocks go LAST and are never inspected: they belong
## to a mod that is currently disabled, and the only correct thing to do with them
## is hand them back unchanged.
func _collect_sections() -> Dictionary:
	var out: Dictionary = {
		# Difficulty (WI-37) is not a participant: it's a single id chosen before the
		# run starts and never mutated, so there is no system holding state to ask.
		# Written here as well as in meta because meta is a display summary - this is
		# the authoritative field the load path restores from.
		"difficulty": String(Global.difficulty_id()),
		# The station's name (WI-59) has exactly that shape too - chosen at setup,
		# never mutated by any system - so it travels the same way rather than
		# inventing a section with one string in it.
		"station": Global.station_name,
		# The star and planet (WI-66). Same shape again: rolled once before the
		# run and never touched afterwards, so there is no live system holding
		# state to ask for it. The RESOLVED parameters are written, not the seed -
		# see StarSystemData for why.
		"system": Global.get_star_system().to_dict(),
	}
	for section: SaveSection in sections_in_order():
		out[String(section.id)] = section.collect.call()
	for key: String in _unclaimed_sections:
		if not out.has(key):
			out[key] = _unclaimed_sections[key]
	return out

## Hands each registered section its block, in order, and remembers the rest.
func _apply_sections(sections: Dictionary) -> void:
	# Every envelope-level field must be claimed here even though no section owns
	# them: anything unclaimed is filed as a disabled mod's data and handed back
	# untouched on the next save, so an unclaimed "station" would round-trip
	# forever while the game ran nameless, and nothing would error. "system"
	# (WI-66) is under exactly the same obligation - it would round-trip while
	# every load rendered the legacy sky, silently.
	var claimed: Dictionary[String, bool] = {
		"difficulty": true, "station": true, "system": true,
	}
	for section: SaveSection in sections_in_order():
		var key: String = String(section.id)
		claimed[key] = true
		section.apply.call(sections.get(key, section.empty))
	_unclaimed_sections = {}
	for key: String in sections:
		if not claimed.has(key):
			_unclaimed_sections[key] = sections[key]
	if not _unclaimed_sections.is_empty():
		print("[save] %d section(s) belong to systems that aren't loaded (%s) - preserved untouched"
				% [_unclaimed_sections.size(), ", ".join(PackedStringArray(_unclaimed_sections.keys()))])

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
		# WI-59: so the slot browser can show the station's name without parsing
		# the (large) sections block.
		"station": Global.station_name,
		# WI-47 M11: which mods wrote this. In meta rather than a section because the
		# slot browser has to be able to mark a mismatched save BEFORE the player
		# commits to loading it, and meta exists precisely so a row can render
		# without parsing the (large) sections.
		"mods": ModManager.mod_records(),
	}

# --- mod drift (WI-47 M11) ------------------------------------------------------

## Mods this save was written with that aren't loaded now, plus mods whose version
## has changed. Pure - takes the record list rather than reading a save - so the
## slot browser and the load path share one rule.
##
## A mod present at a DIFFERENT version counts as drift too: a mod that renamed its
## ids between versions is indistinguishable from a missing one at load time.
## Extra mods installed since the save are NOT drift - additive content that wasn't
## there before is the normal, working case.
static func mod_drift(saved_records: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var loaded: Dictionary[String, String] = {}
	for record: Dictionary in ModManager.mod_records():
		loaded[String(record.get("id", ""))] = String(record.get("version", ""))
	for entry: Variant in saved_records:
		# Hand-edited or truncated saves reach here too; a malformed entry is
		# skipped rather than reported as a missing mod nobody can install.
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = entry
		var id: String = String(record.get("id", ""))
		if id == "":
			continue
		var version: String = String(record.get("version", ""))
		if not loaded.has(id):
			out.append("%s (%s) is not installed" % [id, version])
		elif loaded[id] != version:
			out.append("%s was saved at %s, installed version is %s" % [id, version, loaded[id]])
	return out

## Called on the load path. A WARNING, never a refusal (WI-47 M11): there is no way
## to know in advance how load-bearing the missing content was, and refusing would
## strand saves whose mod merely changed version. Proceeding is the player's call;
## making it silently is not.
func _warn_about_mod_drift(data: Dictionary) -> void:
	var meta: Dictionary = data.get("meta", {})
	# Absent on every pre-WI-47 save, and that has to read as "no mods", not as
	# "mods missing", or every legacy save warns.
	var drift: PackedStringArray = mod_drift(meta.get("mods", []))
	if drift.is_empty():
		return
	var summary: String = "This save used mods that aren't loaded: %s. Modules and items from them are gone, and the station may be unplayable." % ", ".join(drift)
	push_warning("[save] " + summary)
	SignalBus.station_alert.emit(summary)

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
			"schedule": Array(pawn.schedule.slots) if pawn.schedule != null else [],
			"carried": carried,
		}
		# Component blocks (WI-47 M2): needs, health, skills, traits, disease,
		# breathing and the two robot components each write their own, in the order
		# their save_order() declares. This used to name all eight by hand, which is
		# why a modded pawn component could not persist at all.
		#
		# One shape change falls out of it: a pawn with no needs component (robots,
		# visitors) no longer gets an empty "needs": {} written for it, because a
		# component that isn't there can't write a block. Nothing reads those, and
		# the load side has always tolerated the key being absent.
		_save_pawn_components(pawn, entry)
		# Robot number ("Mining Droid 2" -> 2). Saved with the name it built so a
		# robot produced after the load can't be handed a number a restored robot
		# is already wearing. Robots only, so crew entries stay unchanged.
		if pawn is RobotPawnBase:
			entry["robot_index"] = (pawn as RobotPawnBase).robot_index
		# Mining Drones need their parent
		if pawn is MiningDronePawn and (pawn as MiningDronePawn).parent_mining_component != null:
			entry["mining_comp"] = component_ref((pawn as MiningDronePawn).parent_mining_component)
		# Hauler robots (WI-27) ride the same way, referencing their Logistics Bay.
		if pawn is HaulerRobotPawn and (pawn as HaulerRobotPawn).parent_bay != null:
			entry["logistics_bay"] = component_ref((pawn as HaulerRobotPawn).parent_bay)
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

## Pawn components in restore order (WI-47 M2). Explicitly index-tiebroken because
## Array.sort_custom is not stable, and two same-order components must not swap
## between runs. Mirrors ModuleBase._components_in_save_order.
func _pawn_components_in_save_order(pawn: PawnBase) -> Array[PawnComponentBase]:
	var registration: Dictionary[PawnComponentBase, int] = {}
	for index: int in pawn.components.size():
		registration[pawn.components[index]] = index
	var ordered: Array[PawnComponentBase] = pawn.components.duplicate()
	ordered.sort_custom(func(a: PawnComponentBase, b: PawnComponentBase) -> bool:
		var order_a: int = a.save_order()
		var order_b: int = b.save_order()
		if order_a != order_b:
			return order_a < order_b
		return int(registration[a]) < int(registration[b]))
	return ordered

func _save_pawn_components(pawn: PawnBase, entry: Dictionary) -> void:
	for component: PawnComponentBase in _pawn_components_in_save_order(pawn):
		var block: Dictionary = component.get_save_data()
		if block.is_empty():
			continue
		entry[String(component.save_key())] = block

func _load_pawn_components(pawn: PawnBase, entry: Dictionary) -> void:
	for component: PawnComponentBase in _pawn_components_in_save_order(pawn):
		var key: String = String(component.save_key())
		if not entry.has(key):
			continue
		component.load_save_data(_migrate_pawn_block(key, entry[key]))

## Pre-WI-47 saves wrote traits as a bare Array of ids. The shared hook is
## Dictionary-typed - GDScript forbids narrowing an overridden parameter, so no
## single component can keep a different shape - so the legacy form is wrapped
## here, in the one place that knows it is legacy. Nothing else needs migrating.
func _migrate_pawn_block(key: String, block: Variant) -> Dictionary:
	if key == "traits" and block is Array:
		return {"ids": block}
	return block as Dictionary

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
	# The station name rides along (WI-59), and the founding crew is dropped: a
	# save restores its crew from the pawn section, so a roster left staged by a
	# half-configured New Game must not survive into the loaded game.
	Global.clear_staged_start()
	Global.set_station_name(read_station_name(data))
	# The sky rides along for the same reason difficulty does (WI-66):
	# StellarBackground builds it in its own _ready, which runs before the
	# deferred _apply_pending_load could hand it over.
	Global.stage_star_system(read_star_system(data))
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

## The station name a parsed envelope was saved with (WI-59). Same precedence as
## read_difficulty: authoritative sections field, then the meta summary, then ""
## - which is what every pre-WI-59 save (neither key present) resolves to, and
## which Global.station_display_name() renders as the default name.
static func read_station_name(data: Dictionary) -> String:
	var sections: Dictionary = data.get("sections", {})
	var from_section: String = String(sections.get("station", ""))
	if from_section != "":
		return from_section
	var meta: Dictionary = data.get("meta", {})
	return String(meta.get("station", ""))

## The star and planet a parsed envelope was played under (WI-66).
##
## A save with no `system` block - every pre-WI-66 save - gets the legacy sky
## rather than a fresh roll. That is one specific sky, the same on every load,
## which is the property that matters: it is NOT the sky that save had, and that
## one-time change is deliberate, the same bargain WI-61 struck when every
## pre-WI-61 body restored as a belt asteroid. The block is written on the next
## save, so it stops being a fallback the first time the player saves.
##
## Note SAVE_VERSION does not move for this: an absent key has a correct answer,
## which is what a migration would have had to invent.
static func read_star_system(data: Dictionary) -> StarSystemData:
	var sections: Dictionary = data.get("sections", {})
	var block: Variant = sections.get("system", null)
	if block is Dictionary and not (block as Dictionary).is_empty():
		return StarSystemData.from_dict(block as Dictionary)
	return StarSystemGenerator.legacy()

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
	var dir := DirAccess.open(_save_dir)
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
		# WI-47 M11. Absent on pre-WI-47 saves, which correctly reads as "no mods".
		"mods": meta.get("mods", []),
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

## Runs on the fresh scene, one deferred tick after every _ready(). Section order
## matters and now lives on the sections themselves (WI-47 M3) - each registrant
## carries the reason for its number. The shape of it is unchanged: time first
## (systems tick in loaded time), unlocks before world (ready_constructed applies
## global modifiers / granted-module checks), world before asteroids/piles/pawns
## (jobs restored on pawns resolve their targets - modules, asteroids, piles - so
## all three must exist first).
func _apply_pending_load() -> void:
	var data: Dictionary = _pending_load
	var slot: String = _pending_slot
	_pending_load = {}
	_pending_slot = ""
	_loading = true
	var sections: Dictionary = data.get("sections", {})
	_warn_about_mod_drift(data)
	_apply_sections(sections)
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
		var parent_node: Node = Global.world_manager.get_canvas_for_module(module)
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
		# Robot number, set before add_child for the same reason pawn_id is: _ready
		# allocates one only when it arrives unset. A save from before robots were
		# named has neither key, so its robots get numbered (and named) at _ready
		# in load order, as if they were just built.
		if pawn is RobotPawnBase:
			(pawn as RobotPawnBase).robot_index = int(entry.get("robot_index", 0))
		# Personal wallet (WI-33). Missing on pre-WI-33 saves -> 0, same as a pawn
		# that never earned. Set before add_child, like the other scalar identity.
		pawn.personal_credits = int(entry.get("personal_credits", 0))
		# Add to tree first: current_module's setter reparents, which needs a
		# parent to exist (CrewManager.spawn_crew follows the same order).
		Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.SPACE).add_child(pawn)
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
		# Component blocks (WI-47 M2), in save_order(): needs, health, skills,
		# traits, disease (which re-derives its maluses from the skills and traits
		# above it), breathing, then the robot pair. The robot components are
		# created in RobotPawnBase._ready, i.e. during the add_child above, so
		# they are already registered by the time this walks.
		_load_pawn_components(pawn, entry)
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
		_load_pawn_jobs(pawn, entry)

## Rebuilds current_job + job_queue onto a freshly restored pawn.
func _load_pawn_jobs(pawn: PawnBase, entry: Dictionary) -> void:
	# Looked up here rather than threaded down from the restore walk: a restored
	# need-job has to be re-adopted by the needs component so the need stops
	# re-queueing a duplicate, and that is the only reason this function wants it.
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	for job_data: Dictionary in entry.get("job_queue", []):
		var job: Job = Job.from_dict(job_data)
		if job != null:
			pawn.queue_job(job)
			_adopt_if_need_job(pawn, needs, job)
	var current_job: Job = Job.from_dict(entry.get("current_job", {}))
	if current_job != null:
		pawn.queue_job(current_job, true) # to front: runs before the restored queue
		# ...and before the cargo sweep, which would otherwise take the cargo this
		# job is carrying and abandon it (WI-68 F21).
		pawn.mark_restored_job(current_job)
		_adopt_if_need_job(pawn, needs, current_job)

## A restored need job must be re-linked to the component that queued it, or that
## component (which lost its pending-job pointer on load) would queue a second
## job for the same need. Covers organic needs (Eat/Sleep/Recreate), the robot
## needs (WI-28: recharge -> RobotPowerComponent, repair -> RobotIntegrityComponent),
## treatment (WI-31) and suit trips (WI-67/68: change_suit -> PawnSuitComponent).
## No-op for anything else. A component that remembers a job it queued on the
## pawn needs a branch here, or every load duplicates that job.
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
	elif job.is_type(&"change_suit"):
		# Suits (WI-67), missed until WI-68 F2: an unadopted trip made the suit
		# component post a second one, and the orphan then walked an
		# already-suited pawn to an airlock and back.
		var suit: PawnSuitComponent = pawn.get_component_by_type(PawnSuitComponent) as PawnSuitComponent
		if suit != null:
			suit.adopt_restored_trip(job)
