class_name SaveManager
extends Node

## Central save/load: the orchestration. Each system contributes a section,
## registered with [method register_section] in its own _ready and ordered by
## [constant SECTION_ORDER]; this manager owns the envelope, the id->definition
## lookups, the load orchestration, and the three sections that belong to no
## other manager - resources, piles and pawns.
##
## Two things it used to be as well live next door since WI-73 §4: the files
## themselves - paths, reading, writing, listing, summaries, migration - are
## [SaveSlots], and the way a save names a live object it cannot hold is
## [SaveRefs].
##
## Load strategy is full teardown -> rebuild: load_slot() stashes the parsed
## save in a static (so it survives the scene swap), reloads main.tscn, and
## the fresh SaveManager applies the sections once the new tree is ready.
## In-flight jobs on pawns are saved and resume on the action they were on
## (WI-21, WI-44, WI-70); jobs waiting unclaimed on the board are not, and
## their owners re-derive them.

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

# --- section registry (WI-47 M3) ------------------------------------------------

## Every vanilla section's order, in one table (WI-73 §2). It is both the write
## order and the restore order, and each registrant reads its own number from here
## rather than passing a literal.
##
## The reason a section needs its number stays a comment at its registration,
## beside the load code the reason is about. The constraints BETWEEN sections are
## pinned as pairs by test_save_section_order.gd, so renumbering a row here fails a
## test rather than somebody's load. Leave gaps: a new section, or a mod wanting to
## sit between two vanilla ones, needs somewhere to go.
##
## Mods are not in this table and do not read from it. They keep passing their own
## integer to [method register_section], as WI-47 M3 promised them, and one that
## lands on a vanilla number ties on id exactly as it always has.
const SECTION_ORDER: Dictionary[StringName, int] = {
	&"time": 10,
	&"unlocks": 20,
	&"resources": 30,
	&"market": 40,
	&"economy": 50,
	&"world": 60,
	&"asteroids": 70,
	&"turbolifts": 80,
	&"piles": 90,
	&"pawns": 100,
	&"crew": 110,
	&"traders": 120,
	&"events": 130,
	&"story": 135,
	&"contracts": 140,
	&"raid": 150,
	&"visitors": 160,
	&"tutorial": 170,
	&"vitals": 200,
	&"alerts": 210,
	&"transmissions": 215,
}

## Declares a top-level save section. Call from the contributing system's _ready(),
## next to its Global registration. Re-registering an id replaces it, which is what
## makes this survive the scene reload a load performs.
##
## `order` is both the write order and the restore order - see [constant
## SECTION_ORDER] for the vanilla numbers, and each registrant's comment for what
## it depends on. A mod manager with no constraints should sit above every vanilla
## number so it restores against a finished station.
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
	# The three sections SaveManager owns itself rather than delegating to a
	# manager. Their numbers interleave with the managers' (see SECTION_ORDER):
	# resources before economy, which restores its ledger against the balances;
	# piles after world, since a pile re-links to the module it sits in, and
	# before pawns, whose restored collect jobs are handed back to their pile;
	# pawns after world, asteroids and piles, which their restored jobs target.
	register_section(&"resources", SECTION_ORDER[&"resources"], _get_resources_save, _load_resources)
	register_section(&"piles", SECTION_ORDER[&"piles"], _get_piles_save, _load_piles, [])
	register_section(&"pawns", SECTION_ORDER[&"pawns"], _get_pawns_save, _load_pawns, [])
	_build_lookups()
	_reset_resource_runtime_state()
	if has_pending_load():
		# Deferred so the entire new scene tree (managers AND UI) is ready
		# before sections start mutating state.
		call_deferred("_apply_pending_load")

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.save_manager)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.save_manager == self:
		Global.save_manager = null

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

# --- save --------------------------------------------------------------------

func save_slot(slot: String) -> Error:
	var data: Dictionary = {
		"version": SaveSlots.SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		# Cheap headline stats for the slot list (WI-36), so the menus never have
		# to parse the (large) sections just to render a row.
		"meta": _get_meta(),
		"sections": _collect_sections(),
	}
	var error: Error = SaveSlots.write_slot(slot, data)
	if error != OK:
		return error
	print("Saved '%s' at %s" % [slot, Global.time_manager.format_time()])
	game_saved.emit(slot)
	return OK

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

## Called on the load path. A WARNING, never a refusal (WI-47 M11): there is no way
## to know in advance how load-bearing the missing content was, and refusing would
## strand saves whose mod merely changed version. Proceeding is the player's call;
## making it silently is not.
func _warn_about_mod_drift(data: Dictionary) -> void:
	var meta: Dictionary = data.get("meta", {})
	# Absent on every pre-WI-47 save, and that has to read as "no mods", not as
	# "mods missing", or every legacy save warns.
	var drift: PackedStringArray = SaveSlots.mod_drift(meta.get("mods", []))
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
				"stacks": SaveRefs.stacks_to_dicts(pile.contents[resource].stacks),
			})
		out.append({
			"id": pile.pile_id,
			"position": [pile.global_position.x, pile.global_position.y],
			"module": SaveRefs.module_ref(pile.parent_module),
			"contents": contents,
		})
	return out

func _get_pawns_save() -> Array:
	var out: Array = []
	for node: Node in get_tree().get_nodes_in_group(Groups.PAWN):
		var pawn: PawnBase = node as PawnBase
		# Every pawn is saved unless its kind says otherwise - the ARC inspector
		# does (see InspectorPawn.is_saved).
		if pawn == null or not pawn.is_saved():
			continue
		var carried: Array = []
		if pawn.inventory_component != null:
			for resource: ResourceData in pawn.inventory_component.get_carried_resources():
				if resource.id == &"":
					continue
				carried.append({
					"resource": String(resource.id),
					"stacks": SaveRefs.stacks_to_dicts(pawn.inventory_component.carried[resource].stacks),
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
			"module": SaveRefs.module_ref(save_module),
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
		# What this pawn's kind adds (WI-73 §3): a robot's number, a drone's or a
		# hauler's bay, a guest's visit. This used to be an `is` branch per kind
		# here, which a modded pawn kind had no way to join.
		pawn.save_kind_data(entry)
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
	var parsed: Dictionary = SaveSlots.read_slot(slot)
	if parsed.is_empty():
		return false
	var data: Dictionary = SaveSlots.migrate(parsed)
	if int(data.get("version", 0)) != SaveSlots.SAVE_VERSION:
		push_warning("Save version %s can't be migrated to %d, load aborted"
			% [str(data.get("version")), SaveSlots.SAVE_VERSION])
		return false
	_pending_load = data
	_pending_slot = slot
	# Difficulty (WI-37) is staged HERE, not in _apply_pending_load: managers read
	# it from _ready onward (RaidManager's gate, every needs component's mood
	# modifier), and _ready runs a deferred tick before the sections apply. Staging
	# at read time also overwrites whatever the main menu's picker left behind, so
	# loading a Hard save after a Peaceful run can't inherit the menu leftover.
	Global.set_difficulty(SaveSlots.read_difficulty(data))
	# The station name rides along (WI-59), and the founding crew is dropped: a
	# save restores its crew from the pawn section, so a roster left staged by a
	# half-configured New Game must not survive into the loaded game.
	Global.clear_staged_start()
	Global.set_station_name(SaveSlots.read_station_name(data))
	# The sky rides along for the same reason difficulty does (WI-66):
	# StellarBackground builds it in its own _ready, which runs before the
	# deferred _apply_pending_load could hand it over.
	Global.stage_star_system(SaveSlots.read_star_system(data))
	return true

## Runs on the fresh scene, one deferred tick after every _ready(). Section order
## matters, and it is [constant SECTION_ORDER]: each registrant carries the reason
## for its number, and test_save_section_order.gd pins the pairs. The shape of it:
## time first (systems tick in loaded time), unlocks before world
## (ready_constructed applies global modifiers / granted-module checks), world,
## asteroids and piles before pawns (jobs restored on pawns resolve their targets -
## modules, asteroids, piles - so all three must exist first).
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
		var module: ModuleBase = SaveRefs.resolve_module_ref(entry.get("module", {}))
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
				stacks.append(SaveRefs.stack_from_dict(resource, stack_dict))
			# Restored without posting (WI-70): pawns load after piles, and a collect
			# job a crew member was on has to be handed back to the pile first, or it
			# finds the slot taken by a fresh job and runs beside it (F26).
			pile.add_stacks(resource, stacks, false)
		# Once the load is done - by then every restored collector has been adopted,
		# and this posts only for what nobody was already fetching.
		pile.ensure_collection_jobs.call_deferred()
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
		# Whatever of the kind's own fields _ready has to see - a robot's number,
		# which _ready allocates only when it arrives unset (WI-73 §3).
		pawn.load_kind_data_before_tree(entry)
		# Add to tree first: current_module's setter reparents, which needs a
		# parent to exist (CrewManager.spawn_crew follows the same order).
		Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.SPACE).add_child(pawn)
		var pos_arr: Array = entry.get("position", [0, 0])
		pawn.global_position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
		# Missing module (deleted mid-save / in-transit pawn) -> stays in
		# space at their last position and paths home via an airlock.
		var module: ModuleBase = SaveRefs.resolve_module_ref(entry.get("module", {}))
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
				stacks.append(SaveRefs.stack_from_dict(resource, stack_dict))
			pawn.inventory_component.add_stacks(resource, stacks)
		# The rest of the kind's own fields (WI-73 §3): a drone or a hauler
		# re-registers with its bay, a guest gets its visit back. Before the jobs,
		# so an owner a robot re-registers with is in place when its job is offered
		# back to that owner.
		pawn.load_kind_data(entry)
		# Jobs last (WI-21): module, components, inventory and the kind's fields
		# are all in place, so the restored job's claims - re-taken when it
		# resumes on the pawn's first start_job() tick, not here - see the true
		# world. Queue in saved order, then the current job to the front, marked
		# to resume ahead of the cargo sweep (WI-68 F21) on the action it was
		# saved on (WI-70 F40). Jobs whose targets are gone deserialize to null
		# and are dropped. A target that is another pawn resolves only if that
		# pawn loaded first; no job type targets a pawn today.
		_load_pawn_jobs(pawn, entry)

## Rebuilds current_job + job_queue onto a freshly restored pawn, and hands each
## restored job back to whoever posted it (WI-70 §3).
##
## That hand-back used to be an if-chain here, one branch per job type a pawn
## component remembered, and it only ever knew about the pawn side: no module,
## storage or pile was re-linked to its restored job, so every load posted those
## owners a duplicate (F26). F2 was a pawn-side branch nobody had added. A job's
## owner is now declared on its JobData (`origin`) and adoption asks that owner,
## so a new job type - or a mod's - needs no edit here.
func _load_pawn_jobs(pawn: PawnBase, entry: Dictionary) -> void:
	for job_data: Dictionary in entry.get("job_queue", []):
		var job: Job = Job.from_dict(job_data)
		if job != null:
			pawn.queue_job(job)
			job.offer_to_owner(pawn)
	var current_job: Job = Job.from_dict(entry.get("current_job", {}))
	if current_job != null:
		pawn.queue_job(current_job, true) # to front: runs before the restored queue
		# ...and before the cargo sweep, which would otherwise take the cargo this
		# job is carrying and abandon it (WI-68 F21).
		pawn.mark_restored_job(current_job)
		current_job.offer_to_owner(pawn)
