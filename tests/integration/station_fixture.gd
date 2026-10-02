class_name StationFixture
extends RefCounted

## Boots the real `main.tscn` headless under a [GutTest], drives the sim, saves
## and reloads, and checks the station's invariants (WI-69).
##
## Unit suites construct pure classes and never touch [Global]. This is the other
## half: behaviour **between** systems - a job and its owner, a save and the load
## that re-links it - which the extraction rule cannot reach, because the rule is
## what the fault is between. Every finding from F2 to F38 lived there, and each
## was found by a scratch-copy probe that was run once and thrown away. This is
## that probe, kept.
##
## ## Usage
##
## [codeblock]
## var fx: StationFixture
##
## func before_each() -> void:
##     fx = StationFixture.new(self)
##     await fx.boot()
##
## func after_each() -> void:
##     await fx.finish()
## [/codeblock]
##
## [method finish] checks [method invariants] on whatever is still standing, tears
## the scene down, and fails the test on any error raised outside the test body -
## a boot in `before_each`, a teardown in `after_each` - which GUT's own error
## tracker does not attribute to any test.
##
## ## The quiet world
##
## [method boot] starts on **Peaceful** (no raids), with the **onboarding
## skipped** (which also spends every tutorial hint), **natural events off** and
## the **critical-alert pause off**. Each can be switched back on through
## `options`. The reason is the one silent failure a soak has: a pause hold. A new
## game's onboarding takes the balloon's `&"dialogue"` hold and the sim never
## advances; the 2026-09-19 F38 probe measured nothing for exactly that reason.
## [method tick] now fails loudly, naming the holders, if the sim is stopped on
## any frame - so a test that turns events back on and draws a balloon finds out.
##
## ## What a test may assume
##
## - **Nothing about statics.** [SaveManager]'s section registry, the pawn and pile
##   id counters and the content registries carry across fixtures exactly as they
##   carry across a Quit to Menu in the game. Never assume a fresh id counter.
## - **`--fixed-fps 60`.** Every frame is 1/60 s whatever the wall clock does,
##   which is what makes [method tick] deterministic. [method boot] fails the
##   test if the flag is missing.
## - **Never `SaveManager.load_slot`.** It calls `reload_current_scene`, and under
##   GUT there is no current scene - the test runner is the root's child. Use
##   [method save_and_reload].

const MAIN_SCENE: String = "res://main.tscn"
## The fixture's own save directory, deleted by [method teardown]. Never the
## player's `user://saves/`.
const SAVE_DIR: String = "user://gut_saves/"
const SLOT: String = "fixture"
## Where the quiet defaults are applied, before the scene enters the tree - so
## they hold from the first frame rather than from whenever boot got round to it.
const ALERT_MANAGER_PATH: NodePath = ^"Managers/AlertManager"
const EVENT_MANAGER_PATH: NodePath = ^"Managers/EventManager"
## Frames to wait for `game_bootstrapped` before calling the boot failed. A new
## game bootstraps inside `add_child`; a load does it one deferred call later.
const BOOT_TIMEOUT_FRAMES: int = 300
const FRAME_SECONDS: float = 1.0 / 60.0
## 4x is the game's own ceiling. 8x still resolves door and ride timing; don't go
## higher without checking that it does.
const DEFAULT_SPEED: float = 4.0

## The running `main.tscn`, or null between [method teardown] and the next boot.
var scene: Node = null

## Where failures go. [method GutTest.fail_test] by default; the self-check suite
## swaps in a collector so it can assert on the message a failure *would* carry.
var on_failure: Callable

var _test: GutTest
var _options: Dictionary = {}
var _errors: ErrorLog = null
## Pawn instance id -> instance id of the ended job it held at the last sample.
## A pawn clears an ended `current_job` in its own next `_process`, so the same
## ended job on two consecutive frames is a pawn that stopped noticing.
var _ended_last_frame: Dictionary[int, int] = {}
## Sentences for strandings seen by [method tick], reported by [method invariants].
var _stranded: PackedStringArray = []

func _init(test: GutTest) -> void:
	_test = test
	on_failure = test.fail_test

# --- lifecycle ----------------------------------------------------------------

## Stages a new game and boots it. `options`, all optional:
## - `difficulty` (StringName, default `&"peaceful"`);
## - `onboarding` (bool, default false): run the new-game onboarding;
## - `events` (bool, default false): natural random events;
## - `critical_pause` (bool, default false): criticals hold the sim.
##
## Returns once the starting crew has spawned. Fails the test and returns false
## if the scene never bootstraps.
func boot(options: Dictionary = {}) -> bool:
	if scene != null:
		_fail("StationFixture.boot: a scene is already running; teardown() first")
		return false
	_options = options
	if _errors == null:
		_errors = ErrorLog.new()
		OS.add_logger(_errors)
	SaveSlots.set_save_dir_for_test(SAVE_DIR)
	_delete_save_dir()
	SaveManager.clear_pending_load()
	Global.clear_staged_start()
	Global.set_difficulty(StringName(options.get("difficulty", &"peaceful")))
	Global.set_skip_onboarding(not bool(options.get("onboarding", false)))
	if not await _instance():
		return false
	# `tick` is only deterministic at 1/60 s a frame. Checked on a real frame
	# rather than trusted, because nothing else would notice the flag missing:
	# every test would still pass, at whatever deltas the wall clock produced.
	# One frame also lets the station settle: the founding crew spawns deferred
	# (CrewManager waits for the starting module's cell).
	await _frame()
	var delta: float = _test.get_process_delta_time()
	if absf(delta - FRAME_SECONDS) > 0.0001:
		_fail("StationFixture: frames are %.5f s, not 1/60 s. Run the integration suite with --fixed-fps 60." % delta)
		return false
	return true

## Saves to the fixture's slot, frees the scene, stages the load and boots it -
## the same staging the main menu's Load does. Returns false (and fails the
## test) if any step does.
##
## The staging is the game's own: [method SaveManager.stage_load] restores the
## difficulty and station name and clears the rest, including the skip-onboarding
## flag, so a reloaded game's tutorial state is whatever its save says. Only the
## quiet defaults, which are node exports rather than saved state, are
## re-applied.
func save_and_reload() -> bool:
	if not save():
		return false
	await _free_scene()
	if not SaveManager.stage_load(SLOT):
		_fail("StationFixture.save_and_reload: stage_load refused the fixture slot")
		return false
	return await _instance()

## Frees the scene and loads the slot written by the last [method save], without
## saving again. With it a test can fork one save: carry the live game on, then
## come back to the moment of the save and run the same stretch again from the
## load (WI-75's "a reload changes nothing").
func reload_saved() -> bool:
	if not SaveSlots.slot_exists(SLOT):
		_fail("StationFixture.reload_saved: nothing has been saved")
		return false
	await _free_scene()
	if not SaveManager.stage_load(SLOT):
		_fail("StationFixture.reload_saved: stage_load refused the fixture slot")
		return false
	return await _instance()

## Writes the fixture slot. Public so a test can save without reloading.
func save() -> bool:
	if scene == null:
		_fail("StationFixture.save: nothing is running")
		return false
	var error: Error = Global.save_manager.save_slot(SLOT)
	if error != OK:
		_fail("StationFixture.save: save_slot returned %s" % error_string(error))
		return false
	return true

## The fixture slot's parsed envelope, or {} if nothing has been saved.
func read_save() -> Dictionary:
	if not SaveSlots.slot_exists(SLOT):
		return {}
	return SaveSlots.read_slot(SLOT)

## Errors raised outside any test body since boot - what [method finish] will
## report. The self-check suite reads this to prove the path works.
func errors_outside_test() -> PackedStringArray:
	return _errors.outside_test() if _errors != null else PackedStringArray()

## Forgets the out-of-body errors recorded so far, for a test that planted one on
## purpose and has asserted on it.
func clear_errors_outside_test() -> void:
	if _errors != null:
		_errors.clear()

## Frees the scene, deletes the fixture's save directory, and puts every static
## it staged back: the save directory, the pending load, and [Global]'s staging.
func teardown() -> void:
	await _free_scene()
	_delete_save_dir()
	SaveSlots.set_save_dir_for_test(SaveSlots.SAVE_DIR)
	SaveManager.clear_pending_load()
	Global.clear_staged_start()
	Global.clear_difficulty()

## The `after_each` helper: invariants on whatever is still standing, then
## [method teardown], then any error raised outside the test body.
func finish() -> void:
	if scene != null:
		for problem: String in invariants():
			_fail("invariant: " + problem)
	await teardown()
	if _errors != null:
		OS.remove_logger(_errors)
		for problem: String in _errors.outside_test():
			_fail("error outside the test body: " + problem)
		_errors = null

# --- driving the sim ----------------------------------------------------------

## Runs the sim for `sim_seconds` at `speed`, a frame at a time. Fails the test,
## naming the holders, the first time the sim is paused on a frame - a soak over
## a stopped game measures nothing, silently, and that is the failure this
## fixture exists to rule out. Returns false if it stopped early.
func tick(sim_seconds: float, speed: float = DEFAULT_SPEED) -> bool:
	var time: TimeManager = Global.time_manager
	if time == null:
		_fail("StationFixture.tick: no TimeManager - is the scene booted?")
		return false
	time.speed = speed
	var target: float = time.total_sim_seconds + sim_seconds
	# Frames the tick should need, plus slack. Only a stall exceeds it.
	var budget: int = ceili(sim_seconds / (speed * FRAME_SECONDS)) + 10
	var frames: int = 0
	while time.total_sim_seconds < target - 0.000001:
		if time.is_paused():
			_fail("StationFixture.tick: the sim is paused after %.2f of %.2f sim-seconds - %s"
				% [sim_seconds - (target - time.total_sim_seconds), sim_seconds, describe_pause(time)])
			return false
		if frames > budget:
			_fail("StationFixture.tick: %d frames did not advance %.2f sim-seconds" % [frames, sim_seconds])
			return false
		await _frame()
		frames += 1
		_sample_pawn_jobs()
	return true

## Ticks in `step` slices until `condition` is true or `max_sim_seconds` have
## passed. Returns whether the condition came true; fails nothing by itself, so a
## test says what it was waiting for.
func tick_until(condition: Callable, max_sim_seconds: float, step: float = 0.25,
		speed: float = DEFAULT_SPEED) -> bool:
	# Measured on the clock, not by summing steps: a tick overshoots by up to a
	# frame, which at 4x and small steps is a third again.
	var start: float = Global.time_manager.total_sim_seconds
	while not bool(condition.call()):
		if Global.time_manager.total_sim_seconds - start >= max_sim_seconds:
			return false
		if not await tick(step, speed):
			return false
	return true

## Why the sim is stopped, as a sentence naming each source.
static func describe_pause(time: TimeManager) -> String:
	var parts: PackedStringArray = []
	if time.paused:
		parts.append("the player's pause flag is set")
	var holders: Array[StringName] = time.pause_holders()
	if not holders.is_empty():
		var names: PackedStringArray = []
		for holder: StringName in holders:
			names.append(String(holder))
		parts.append("held by " + ", ".join(names))
	return "; ".join(parts) if not parts.is_empty() else "not paused"

# --- building the station -----------------------------------------------------

## Places `module_id` at `cell` through [method WorldManager.add_module]: built
## outright with `built` (force_complete), or as a blueprint without.
##
## **Not the player's path.** There is no connectivity check, no cost and no
## multiplacement plan, so a module placed away from the station is simply an
## island - which is what several tests want. A module only joins the pawn path
## graph where its doors meet a complete module on its own layer.
func place(module_id: StringName, cell: Vector2i, built: bool = true, flipped: bool = false) -> ModuleBase:
	var data: ModuleData = Global.save_manager.get_module_data_by_id(module_id)
	if data == null:
		_fail("StationFixture.place: no module '%s'" % module_id)
		return null
	var module: ModuleBase = Global.world_manager.add_module(data, cell, flipped, false, built)
	if module == null:
		_fail("StationFixture.place: '%s' does not fit at %s" % [module_id, cell])
	return module

## Lays a built hallway on every cell of `row` from `from_x` to `to_x` that has no
## corridor yet. A module's door places a corridor on its own cell only, so a row
## of modules placed side by side is a row of islands until this joins them.
func corridor(row: int, from_x: int, to_x: int) -> void:
	for x: int in range(mini(from_x, to_x), maxi(from_x, to_x) + 1):
		var cell := Vector2i(x, row)
		if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.CORRIDOR, cell) == null:
			place(&"hallway_mdata", cell)

## A storeroom, a manned silicon furnace at (10, 7) - three cells tall, so its
## door is on row 9 with everyone else's - a mining bay, a bunk and power, west
## of the starting station along its corridor row: a station with hauling, INPUT
## and OUTPUT slots and a robot workforce all running. The furnace was the ore
## processor until 2026-10-02; it is the processor that touches no steel, which
## the soak's conservation check depends on.
func build_production_line() -> void:
	place(&"large_storage", Vector2i(12, 8))
	place(&"silicon_furnace_mdata", Vector2i(10, 7))
	place(&"mining_bay_mdata", Vector2i(8, 8))
	place(&"sleeping_pod_mdata", Vector2i(7, 9))
	place(&"debug_power", Vector2i(6, 9))
	corridor(9, 6, 15)

func resource(resource_id: StringName) -> ResourceData:
	var found: ResourceData = Global.save_manager.get_resource_by_id(resource_id)
	if found == null:
		_fail("StationFixture: no resource '%s'" % resource_id)
	return found

## Every living crew member, robot and visitor.
func pawns() -> Array[PawnBase]:
	var out: Array[PawnBase] = []
	for node: Node in _test.get_tree().get_nodes_in_group(Groups.PAWN):
		var pawn: PawnBase = node as PawnBase
		if pawn != null and not pawn.is_queued_for_deletion():
			out.append(pawn)
	return out

func piles() -> Array[ResourcePile]:
	var out: Array[ResourcePile] = []
	for node: Node in _test.get_tree().get_nodes_in_group(Groups.RESOURCE_DEBRIS):
		var pile: ResourcePile = node as ResourcePile
		if pile != null and not pile.is_queued_for_deletion():
			out.append(pile)
	return out

## Every placed module, in placement order.
func modules() -> Array[ModuleBase]:
	var out: Array[ModuleBase] = []
	for module: ModuleBase in Global.world_manager.id_to_module.values():
		if is_instance_valid(module):
			out.append(module)
	return out

## Every storage component on every placed module - construction bins and
## deconstruction refunds included, whether or not they are in the storage group.
func storages() -> Array[StorageComponent]:
	var out: Array[StorageComponent] = []
	for module: ModuleBase in modules():
		for component: ComponentBase in module.components:
			var storage: StorageComponent = component as StorageComponent
			if storage != null:
				out.append(storage)
	return out

# --- measuring ----------------------------------------------------------------

## How much of `resource_id` exists: every module's storages, every pile, every
## pawn's inventory and the global store. The F38 probe's helper. Stock on a
## conveyor belt or aboard a ship in flight is not counted.
func world_total(resource_id: StringName) -> int:
	var tracked: ResourceData = resource(resource_id)
	if tracked == null:
		return 0
	var total: int = tracked.global_total if tracked.has_global_store else 0
	for storage: StorageComponent in storages():
		var data: StorageData = storage.storage_data.get(tracked)
		if data != null:
			total += data.stored
	for pile: ResourcePile in piles():
		total += pile.get_total(tracked)
	for pawn: PawnBase in pawns():
		if pawn.inventory_component != null:
			total += pawn.inventory_component.get_carried_amount(tracked)
	return total

## Live jobs of `type_id` aimed at `target` (a module, component, pile or pawn),
## wherever they are: waiting on the board, held by a pawn, or in a pawn's queue.
## The F26 question - "how many jobs does this owner have?" - asked of the whole
## station rather than of the owner's own pointer, which is what goes wrong.
func live_jobs(type_id: StringName, target: Object) -> Array[Job]:
	var candidates: Array[Job] = Global.job_manager.get_board_snapshot()
	for pawn: PawnBase in pawns():
		if pawn.current_job != null:
			candidates.append(pawn.current_job)
		candidates.append_array(pawn.job_queue)
	var out: Array[Job] = []
	var seen: Dictionary[int, bool] = {}
	for job: Job in candidates:
		if job.is_ended() or not job.is_type(type_id) or seen.has(job.get_instance_id()):
			continue
		for slot: JobTarget in [job.target_a, job.target_b, job.target_c]:
			if slot != null and target_object(slot) == target:
				seen[job.get_instance_id()] = true
				out.append(job)
				break
	return out

## The object a job target names, whatever its kind; null for a cell or a freed
## object.
static func target_object(slot: JobTarget) -> Object:
	match slot.kind:
		JobTarget.Kind.MODULE:
			return slot.module()
		JobTarget.Kind.COMPONENT:
			return slot.component()
		JobTarget.Kind.PILE:
			return slot.pile()
		JobTarget.Kind.PAWN:
			return slot.pawn()
		JobTarget.Kind.ASTEROID:
			return slot.asteroid()
	return null

## Every place two parsed-JSON values differ, as `path: a != b` lines; empty when
## they are equal. Dictionaries compare by key, arrays by index, and numbers by
## value (JSON has one number type, so `6` and `6.0` are the same).
static func diff(a: Variant, b: Variant, path: String = "") -> PackedStringArray:
	var out: PackedStringArray = []
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		for key: Variant in da:
			if not db.has(key):
				out.append("%s/%s: only in the first" % [path, key])
			else:
				out.append_array(diff(da[key], db[key], "%s/%s" % [path, key]))
		for key: Variant in db:
			if not da.has(key):
				out.append("%s/%s: only in the second" % [path, key])
		return out
	if a is Array and b is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			out.append("%s: %d entries != %d" % [path, aa.size(), ab.size()])
		for index: int in mini(aa.size(), ab.size()):
			out.append_array(diff(aa[index], ab[index], "%s[%d]" % [path, index]))
		return out
	var numeric: Array[int] = [TYPE_INT, TYPE_FLOAT]
	if numeric.has(typeof(a)) and numeric.has(typeof(b)):
		if float(a) != float(b):
			out.append("%s: %s != %s" % [path, a, b])
		return out
	if typeof(a) != typeof(b) or a != b:
		out.append("%s: %s != %s" % [path, a, b])
	return out

## A live save's sections rewritten into the form a load produces: each pawn's
## current job moved to the head of its queue, where a load restores it to resume
## first (WI-68 F21). The one documented way a save written straight after a load
## differs from the save that was loaded - R4's equivalence, and WI-75's.
static func restored_form(sections: Dictionary) -> Dictionary:
	var out: Dictionary = sections.duplicate(true)
	for entry: Dictionary in out.get("pawns", []):
		if not entry.has("current_job"):
			continue
		var queue: Array = [entry["current_job"]]
		queue.append_array(entry.get("job_queue", []))
		entry.erase("current_job")
		entry["job_queue"] = queue
	return out

## Objects that are neither Nodes nor Resources - the first audit's leak metric
## (F1, F3). Growth that survives a teardown is a cycle or an unfreed Object.
static func loose_objects() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT)
		- Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		- Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

# --- invariants ---------------------------------------------------------------

## Every broken invariant as a sentence; empty means clean. What CLAUDE.md claims
## and the first audit's R5 soak measured:
## - **reservations reconcile:** every [StorageData]'s `reserved_withdraw` and
##   `reserved_deposit` equal what [ClaimRegistry] holds against it;
## - **capacity holds:** no pool over `max_stored` or `output_capacity`, and no
##   INPUT slot over its `desired`;
## - **no stranded jobs:** no pawn held an ended `current_job` on two
##   consecutive frames of a [method tick].
func invariants() -> PackedStringArray:
	var out: PackedStringArray = []
	var registry: ClaimRegistry = Global.claim_registry
	for storage: StorageComponent in storages():
		var where: String = describe_storage(storage)
		for resource_data: ResourceData in storage.storage_data:
			var data: StorageData = storage.storage_data[resource_data]
			var claimed_out: int = registry.claimed_amount(data, ClaimSpec.Kind.STORAGE_WITHDRAW)
			if data.reserved_withdraw != claimed_out:
				out.append("%s: %s reserved_withdraw is %d but the registry holds %d"
					% [where, resource_data.id, data.reserved_withdraw, claimed_out])
			var claimed_in: int = registry.claimed_amount(data, ClaimSpec.Kind.STORAGE_DEPOSIT)
			if data.reserved_deposit != claimed_in:
				out.append("%s: %s reserved_deposit is %d but the registry holds %d"
					% [where, resource_data.id, data.reserved_deposit, claimed_in])
			if data.role == StorageData.Role.INPUT and data.stored > data.desired:
				out.append("%s: INPUT slot %s holds %d over its cap of %d"
					% [where, resource_data.id, data.stored, data.desired])
		var intake: int = storage.space_available(false, StorageData.Role.GENERAL)
		if intake < 0:
			out.append("%s: intake pool is %d over max_stored %d" % [where, -intake, storage.max_stored])
		var output: int = storage.space_available(false, StorageData.Role.OUTPUT)
		if output < 0:
			out.append("%s: output pool is %d over output_capacity %d" % [where, -output, storage.output_capacity])
	out.append_array(_stranded)
	return out

## Fails the test once per broken invariant. Returns whether the station was
## clean.
func check_invariants(context: String = "") -> bool:
	var problems: PackedStringArray = invariants()
	for problem: String in problems:
		_fail(("%s: " % context if context != "" else "") + "invariant: " + problem)
	return problems.is_empty()

static func describe_storage(storage: StorageComponent) -> String:
	var module: ModuleBase = storage.owner_module
	if module == null:
		return String(storage.name)
	var module_name: String = module.module_data.name if module.module_data != null else String(module.name)
	return "%s at %s (%s)" % [module_name, module.module_cell, storage.name]

func _sample_pawn_jobs() -> void:
	var seen: Dictionary[int, int] = {}
	for pawn: PawnBase in pawns():
		var job: Job = pawn.current_job
		if job == null or not job.is_ended():
			continue
		var pawn_id: int = pawn.get_instance_id()
		var job_id: int = job.get_instance_id()
		if _ended_last_frame.get(pawn_id, 0) == job_id:
			var sentence: String = "%s still holds an ended %s job" % [pawn.pawn_name, job.data.id]
			if not _stranded.has(sentence):
				_stranded.append(sentence)
		seen[pawn_id] = job_id
	_ended_last_frame = seen

# --- internals ----------------------------------------------------------------

## Instances `main.tscn` and returns in the **same frame** it bootstraps, before
## the sim has run a single frame on the result.
##
## That is what makes "a save written straight after a load" mean what it says.
## Polling for the signal resumed one frame late, and at 4x one frame is enough
## sim to move every asteroid, need and clock in the save (measured: 23 fields).
func _instance() -> bool:
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	var instance: Node = packed.instantiate()
	_apply_quiet_defaults(instance)
	var waiter := BootWaiter.new(BOOT_TIMEOUT_FRAMES)
	_test.add_child(waiter)
	# DEFERRED, and that is the whole trick. A new game emits game_bootstrapped
	# inside add_child and a load emits it from a deferred call, and either way a
	# direct connection made here would run *first* - before TutorialManager,
	# EconomyManager and the rest have had their own game_bootstrapped handlers.
	# Deferred, it runs once the emit has finished, still in that frame's flush.
	SignalBus.game_bootstrapped.connect(waiter.on_bootstrapped, CONNECT_DEFERRED)
	scene = instance
	_test.add_child(instance)
	if not waiter.settled:
		await waiter.done
	SignalBus.game_bootstrapped.disconnect(waiter.on_bootstrapped)
	var bootstrapped: bool = waiter.bootstrapped
	waiter.queue_free()
	_ended_last_frame.clear()
	if not bootstrapped:
		_fail("StationFixture: main.tscn did not bootstrap within %d frames" % BOOT_TIMEOUT_FRAMES)
		return false
	return true

func _apply_quiet_defaults(instance: Node) -> void:
	var alerts: AlertManager = instance.get_node(ALERT_MANAGER_PATH) as AlertManager
	alerts.pause_on_critical = bool(_options.get("critical_pause", false))
	if not bool(_options.get("events", false)):
		# 0 is what EventManager._natural_roll already reads as "off".
		var events: EventManager = instance.get_node(EVENT_MANAGER_PATH) as EventManager
		events.expected_cycles_between_events = 0.0

## Frees the scene and waits for every NOTIFICATION_PREDELETE to run, so two sets
## of managers never fight over [Global].
func _free_scene() -> void:
	if scene == null:
		return
	if is_instance_valid(scene):
		scene.queue_free()
	scene = null
	await _frame()
	await _frame()

func _frame() -> void:
	await _test.get_tree().process_frame

func _delete_save_dir() -> void:
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(SAVE_DIR)

func _fail(message: String) -> void:
	on_failure.call(message)

## Resolves a boot: `done` fires once, either from `game_bootstrapped` (so the
## awaiting coroutine resumes inside that frame's deferred flush) or after
## `timeout_frames` frames without it.
class BootWaiter extends Node:
	signal done
	var settled: bool = false
	var bootstrapped: bool = false
	var _frames_left: int

	func _init(timeout_frames: int) -> void:
		_frames_left = timeout_frames

	func on_bootstrapped() -> void:
		if settled:
			return
		bootstrapped = true
		settled = true
		done.emit()

	func _process(_delta: float) -> void:
		if settled:
			return
		_frames_left -= 1
		if _frames_left <= 0:
			settled = true
			done.emit()

## Records every error raised while a fixture is alive, and remembers which ones
## GUT had no test to pin on.
##
## GUT's own tracker fails a test for an engine error or a `push_error` raised
## inside the test *body*. `before_each` and `after_each` run outside that window,
## so an error during a boot there, or during the teardown that frees the whole
## station, would print and fail nothing. Those are exactly the errors a freed-
## object bug raises. This logger keeps them and [method StationFixture.finish]
## reports them.
##
## Reads GUT 9.7's `GutErrorTracker._current_test_id` to tell the two apart; the
## self-check suite fails if a GUT upgrade renames it.
class ErrorLog extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _outside: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		if in_test_body():
			return # GUT's tracker has it, and fails the test itself
		var text: String = rationale if rationale != "" else code
		_mutex.lock()
		_outside.append("%s (%s:%d in %s)" % [text, file, line, function])
		_mutex.unlock()

	func outside_test() -> PackedStringArray:
		_mutex.lock()
		var out: PackedStringArray = _outside.duplicate()
		_mutex.unlock()
		return out

	func clear() -> void:
		_mutex.lock()
		_outside.clear()
		_mutex.unlock()

	static func in_test_body() -> bool:
		var tracker: GutErrorTracker = GutUtils.get_error_tracker() as GutErrorTracker
		return tracker != null and str(tracker._current_test_id) != GutUtils.NO_TEST
