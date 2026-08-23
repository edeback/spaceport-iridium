class_name TutorialManager
extends Node

## SAI's whole job (WI-63 §6): run the introduction once, and give one piece of
## advice per mistake the station can walk into.
##
## A node in `main.tscn` under `Managers/`. Tree order is ready order and is
## load-bearing as always: **after [DialogueRunner]** (it calls `run`), after
## [AsteroidManager] and [CrewManager] (it subscribes to their signals), and
## **before [SaveManager]**, whose deferred load must find this manager's section
## already registered.
##
## It owns five things:
##
## - **The ledger** ([TutorialLedger]) - what has been given, and whether the
##   introduction ran.
## - **The hint table**, scanned from [constant ContentPaths.TUTORIAL].
## - **The watchers**, armed once the world is up and **disconnected** as each
##   hint spends itself. That is a rule rather than an optimisation: a tutorial
##   that keeps scanning the station forever to teach a lesson it already taught
##   is a tax on every save that ever ran it.
## - **The bridge** ([TutorialBridge]) and the `guide` alias it is registered
##   under, which is what a `.dialogue` file reaches to point at the interface.
## - **The coach mark** ([TutorialCoach]), mounted under [UIMain].
##
## ## Two decisions worth reading before changing anything here
##
## **The onboarding runs on new games only.** [signal SignalBus.game_bootstrapped]
## fires from `main.gd` for a new game and from [method
## SaveManager._apply_pending_load] for a load, and by the time it fires neither
## `has_pending_load()` nor `is_loading()` can still tell them apart - both are
## cleared first. So the answer is captured in `_ready`, which runs before the
## deferred load begins, using the same guard `main.gd` itself uses.
##
## **An absent save section means the tutorial is complete.** See [method
## TutorialLedger.mark_legacy]. A save that predates this feature belongs to
## somebody who already knows how to play, and stopping their two-hundred-module
## station to explain what a corridor is would be the worse failure by far.

## Which [SpeakerData] does the talking. Read from content rather than hardcoded
## anywhere else, so a mod that replaces the station AI replaces it everywhere -
## the balloon's face, the coach mark's plate, the Comms sender.
const SPEAKER_ID: StringName = &"sai"

## The introduction. One file with no `.tres`, because there is exactly one of it
## and nobody will ever author a second.
const ONBOARDING_PATH: String = "res://data/dialogue/tutorial/onboarding.dialogue"
const ONBOARDING_CUE: String = "intro"

## What the Comms feed files SAI's advice under.
const HINT_FAMILY: StringName = &"advisory"

const SAVE_SECTION: StringName = &"tutorial"
## Above every vanilla section (visitors is 160): the watchers arm against a
## finished station, so everything they scan has to be back first.
const SAVE_ORDER: int = 170

## The alias a `.dialogue` file reaches the interface through.
const GUIDE_CONTEXT: String = "guide"

## How long a module must stay broken before SAI mentions it, in sim-hours.
##
## This is the whole of those two watchers' correctness. `powered_changed(false)`
## fires on every brownout - a passing solar dip, a reactor mid-repair - and a
## blueprint placed one second before the corridor that connects it is a build
## order, not a mistake. Two hours of *continuous* trouble is a forgotten corridor.
@export var hint_grace_hours: float = 2.0

var ledger: TutorialLedger = TutorialLedger.new()
var triggers: TutorialTriggers = TutorialTriggers.new()
var bridge: TutorialBridge
var coach: TutorialCoach

## id -> definition, discovered from every content root.
var _hints: Dictionary[StringName, TutorialHintData] = {}
## trigger id -> the hints watching it, so a fired hint's watcher can be dropped
## when it was the last one on that trigger.
var _by_trigger: Dictionary[StringName, Array] = {}

## Captured in `_ready`, before the deferred load runs - see the class comment.
var _is_new_game: bool = false
## Set by the New Game screen's checkbox, staged on [Global] before the swap.
var _skip_requested: bool = false
## Whether the periodic module scan is currently subscribed.
var _scanning: bool = false
## Module **instance id** -> continuous sim-hours in trouble, per watcher. Runtime
## only; a save taken mid-grace restarts the clock, which is the forgiving
## direction.
##
## Keyed by id rather than by the node, and that is not a style choice. A
## `Dictionary[ModuleBase, float]` cannot even be **iterated** once one of its
## keys has been freed: `keys()` hands each entry to a typed loop variable, and
## assigning a dangling instance to one errors with *"Trying to assign invalid
## previously freed instance"* - before any `is_instance_valid` guard inside the
## loop can run. Demolishing a module the tutorial was timing therefore turned the
## prune into a per-tick error storm. An `int` key cannot dangle.
var _unreachable_for: Dictionary[int, float] = {}
var _unpowered_for: Dictionary[int, float] = {}

func _ready() -> void:
	Global.tutorial_manager = self
	# Before SaveManager's deferred `_apply_pending_load` clears the staged save.
	_is_new_game = not SaveManager.has_pending_load()
	_skip_requested = Global.skip_onboarding()
	_load_hints()
	_build_bridge()
	SaveManager.register_section(SAVE_SECTION, SAVE_ORDER, get_save_data, load_save_data,
		# A missing section is not an empty one. The marker is explicit so the
		# migration decision is readable at the registration site rather than
		# inferred from a dictionary that happens to have no keys.
		{"legacy": true})
	SignalBus.game_bootstrapped.connect(_on_game_bootstrapped)

func _exit_tree() -> void:
	_unregister_context()
	if Global.tutorial_manager == self:
		Global.tutorial_manager = null

func _load_hints() -> void:
	for path: String in ContentPaths.scan(ContentPaths.TUTORIAL):
		var hint: TutorialHintData = ResourceLoader.load(path) as TutorialHintData
		if hint == null:
			continue
		if not ContentPaths.accept_id(hint.id, path, "TutorialHintData"):
			continue
		if not _validate(hint, path):
			continue
		_hints[hint.id] = hint
		if not _by_trigger.has(hint.trigger):
			_by_trigger[hint.trigger] = []
		_by_trigger[hint.trigger].append(hint)

## Everything that would otherwise fail silently at fire time, checked at load
## while the file name is still in hand. A hint that fires, spends itself and
## shows nothing is unrepeatable, so none of these may be discovered late.
func _validate(hint: TutorialHintData, path: String) -> bool:
	if not triggers.is_declared(hint.trigger):
		push_error("TutorialHintData '%s': undeclared trigger '%s' (%s)"
			% [hint.id, hint.trigger, path])
		return false
	if not hint.trigger_filter.is_empty() and not triggers.takes_filter(hint.trigger):
		push_error("TutorialHintData '%s': trigger '%s' takes no filter, got '%s' (%s)"
			% [hint.id, hint.trigger, hint.trigger_filter, path])
		return false
	var problem: String = hint.script_problem()
	if not problem.is_empty():
		push_error("TutorialHintData '%s' %s (%s)" % [hint.id, problem, path])
		return false
	return true

# --- the `guide` context --------------------------------------------------------

## Registers the third alias. WI-62 registers `station` and `story` from
## [DialogueRunner]; `guide` is registered here instead, because the runner has no
## business knowing the tutorial exists. The runner's access filter still has to
## allow [TutorialBridge] through - that is the one line this costs it.
func _build_bridge() -> void:
	bridge = TutorialBridge.new()
	add_child(bridge)
	var manager: Node = Engine.get_singleton("DialogueManager") as Node
	if manager == null:
		push_error("TutorialManager: the DialogueManager autoload is missing")
		return
	manager.call(&"register_state_context", GUIDE_CONTEXT, bridge)

func _unregister_context() -> void:
	var manager: Node = Engine.get_singleton("DialogueManager") as Node
	if manager != null:
		manager.call(&"unregister_state_context", GUIDE_CONTEXT)

# --- bring-up -------------------------------------------------------------------

## The world is up, every section has been applied, and the HUD exists. This is
## the first moment the coach can be mounted and the first at which the ledger is
## authoritative.
func _on_game_bootstrapped() -> void:
	_mount_coach()
	bridge.bind_sources()
	if _skip_requested:
		# The New Game checkbox. Recorded rather than merely obeyed, so a save
		# taken later knows the player opted out and AIDE can say so.
		skip_tutorial()
		return
	_arm_watchers()
	if _is_new_game and not ledger.onboarding_done:
		# Deferred so the first frame has been drawn: the balloon mounts under
		# UIMain, and a conversation opened inside another node's `_ready` chain
		# would race the HUD's own layout pass.
		_run_onboarding.call_deferred()

func _mount_coach() -> void:
	if coach != null and is_instance_valid(coach):
		return
	var host: Node = Global.ui_main
	if host == null or not is_instance_valid(host):
		return # headless probe: the waits work, there is nothing to draw on
	coach = TutorialCoach.create()
	coach.skip_pressed.connect(_on_skip_pressed)
	host.add_child(coach)
	bridge.coach = coach

func _on_skip_pressed() -> void:
	# Through the bridge rather than straight to [method skip_tutorial]: the
	# bridge has to set its own latch and release whatever gate is suspended, and
	# it calls back here once it has.
	bridge.abandon()

# --- the onboarding -------------------------------------------------------------

func _run_onboarding() -> void:
	var resource: DialogueResource = load(ONBOARDING_PATH) as DialogueResource
	if resource == null:
		push_error("TutorialManager: cannot load %s" % ONBOARDING_PATH)
		ledger.complete_onboarding()
		return
	if Global.dialogue_runner == null:
		return
	bridge.reset()
	bridge.subject = null
	Global.dialogue_runner.run(resource, ONBOARDING_CUE, [], _on_onboarding_finished)

func _on_onboarding_finished() -> void:
	if coach != null and is_instance_valid(coach):
		coach.clear_mark()
	# Abandoning already recorded the skip; reaching the end records completion.
	# Both leave `onboarding_done` true, which is what stops it re-running.
	if not bridge.was_abandoned():
		ledger.complete_onboarding()

## Runs the introduction again, from AIDE or from a cheat. Does not touch the
## ledger: a replay is not a first run and must not un-spend anything.
func replay_onboarding() -> void:
	_run_onboarding()

# --- watchers -------------------------------------------------------------------

## Subscribes each trigger that still has an unspent hint on it. Everything is
## routed through [method _fire] which spends first, so a signal that arrives
## twice in a tick cannot produce two conversations.
func _arm_watchers() -> void:
	if _is_armed(&"trader_arrived") and not SignalBus.trader_arrived.is_connected(_on_trader_arrived):
		SignalBus.trader_arrived.connect(_on_trader_arrived)
	if _is_armed(&"space_body_arrived") \
			and not SignalBus.space_body_arrived.is_connected(_on_space_body_arrived):
		SignalBus.space_body_arrived.connect(_on_space_body_arrived)
	if _is_armed(&"crew_resigning") and not SignalBus.crew_resigning.is_connected(_on_crew_resigning):
		SignalBus.crew_resigning.connect(_on_crew_resigning)
	if _is_armed(&"need_critical") \
			and not SignalBus.pawn_critical_need.is_connected(_on_critical_need):
		SignalBus.pawn_critical_need.connect(_on_critical_need)
	_update_scan()

## The two module watchers share one periodic scan, because they share a grace
## window and because two scans over the same module list would be two of the
## same tax. It is subscribed only while at least one of them is unspent.
func _update_scan() -> void:
	var wanted: bool = _is_armed(&"module_unreachable") or _is_armed(&"module_unpowered")
	if wanted == _scanning:
		return
	_scanning = wanted
	var time: TimeManager = Global.time_manager
	if time == null:
		return
	if wanted:
		time.slow_tick.connect(_on_slow_tick)
	elif time.slow_tick.is_connected(_on_slow_tick):
		time.slow_tick.disconnect(_on_slow_tick)
		_unreachable_for.clear()
		_unpowered_for.clear()

## True while some hint on `trigger` has not been given yet.
func _is_armed(trigger: StringName) -> bool:
	for hint: TutorialHintData in _by_trigger.get(trigger, []):
		if not ledger.is_spent(hint.id):
			return true
	return false

## Drops every watcher whose last hint has just been spent. Rule: a fired hint
## costs nothing.
func _disarm_spent() -> void:
	if not _is_armed(&"trader_arrived") and SignalBus.trader_arrived.is_connected(_on_trader_arrived):
		SignalBus.trader_arrived.disconnect(_on_trader_arrived)
	if not _is_armed(&"space_body_arrived") \
			and SignalBus.space_body_arrived.is_connected(_on_space_body_arrived):
		SignalBus.space_body_arrived.disconnect(_on_space_body_arrived)
	if not _is_armed(&"crew_resigning") and SignalBus.crew_resigning.is_connected(_on_crew_resigning):
		SignalBus.crew_resigning.disconnect(_on_crew_resigning)
	if not _is_armed(&"need_critical") \
			and SignalBus.pawn_critical_need.is_connected(_on_critical_need):
		SignalBus.pawn_critical_need.disconnect(_on_critical_need)
	_update_scan()

func _on_trader_arrived(_trader: TraderData) -> void:
	_fire_for(&"trader_arrived", &"", null)

func _on_space_body_arrived(profile: SpaceBodyProfile) -> void:
	if profile == null:
		return
	_fire_for(&"space_body_arrived", profile.id, null)

func _on_crew_resigning(pawn: PawnBase, _grace_hours: float) -> void:
	_fire_for(&"crew_resigning", &"", pawn)

func _on_critical_need(pawn: PawnBase, need: StringName) -> void:
	_fire_for(&"need_critical", need, pawn)

## The shared grace-window scan behind `module_unreachable` and
## `module_unpowered`. Both accumulate continuous sim-hours in trouble and reset
## the instant the module recovers, so a transient never accrues.
func _on_slow_tick(interval: float) -> void:
	var hours: float = interval / TimeManager.SECONDS_PER_HOUR
	var check_path: bool = _is_armed(&"module_unreachable")
	var check_power: bool = _is_armed(&"module_unpowered")
	var anchor: ModuleBase = _station_core()
	# Every module still standing this tick. Anything holding a clock and missing
	# from this set has been demolished, deconstructed or otherwise gone - see
	# [method _prune].
	var seen: Dictionary[int, bool] = {}
	for node: Node in get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null or module.build_state == ModuleBase.BuildState.Preview:
			continue
		var id: int = module.get_instance_id()
		seen[id] = true
		if check_path and anchor != null and _is_worth_naming(module):
			if _accrue(_unreachable_for, id, hours, _is_cut_off(anchor, module)):
				_fire_for(&"module_unreachable", &"", module)
				check_path = false
		if check_power:
			if _accrue(_unpowered_for, id, hours, _is_dark(module)):
				_fire_for(&"module_unpowered", &"", module)
				check_power = false
	_prune(_unreachable_for, seen)
	_prune(_unpowered_for, seen)

## Adds to (or clears) one module's clock and reports whether it has just crossed
## the grace window. Crossing sets the clock past the threshold rather than
## resetting it, so a hint that failed to fire does not immediately re-arm.
func _accrue(clocks: Dictionary[int, float], id: int,
		hours: float, in_trouble: bool) -> bool:
	if not in_trouble:
		clocks.erase(id)
		return false
	var elapsed: float = float(clocks.get(id, 0.0)) + hours
	clocks[id] = elapsed
	return elapsed >= hint_grace_hours

## Drops the clocks of modules that were not standing during this tick's walk.
##
## Membership in `seen` rather than `is_instance_valid`, for two reasons. It is
## exact - a module deconstructed out of [constant Groups.MODULE] is as gone as a
## freed one, and only the walk knows that. And it never has to look at a
## potentially dangling reference at all, which is the whole point: see
## [member _unreachable_for] for why a dictionary keyed on the node could not be
## iterated safely once one of those nodes had been freed.
func _prune(clocks: Dictionary[int, float], seen: Dictionary[int, bool]) -> void:
	for id: int in clocks.keys():
		if not seen.has(id):
			clocks.erase(id)

## The one module the station is guaranteed to have and the one the crew actually
## live in. A station that has lost its core has larger problems than a hint, so
## the check is skipped rather than guessed at.
func _station_core() -> ModuleBase:
	var world: WorldManager = Global.world_manager
	if world == null or world.start_module == null:
		return null
	var cores: Array = world.get_modules_by_type(world.start_module)
	return cores.front() if not cores.is_empty() else null

## Whether this is a module the advisory should blame by name.
##
## Placing anything puts a **corridor segment on the same cell** (one cell holds a
## module, a corridor and a turbolift at once), and removing anything backfills
## **truss**. Both are on the group, both read as cut off whenever the thing they
## serve is, and the scan takes the first match it finds - so a player who built a
## detached Mess Hall was told their *Corridor* was unreachable, and then advised
## to build a corridor. Circular, and it names the wrong thing.
##
## So: MODULE-layer only (drops corridors and turbolifts), and never the truss
## placeholder. Compared against [member WorldManager.replacement_module] rather
## than a hardcoded id, so a mod that swaps the backfill is covered.
##
## The cost is that a lone detached corridor with nothing attached says nothing.
## That is the right trade: this advisory exists for "you built a room and forgot
## to connect it", and a bare corridor going nowhere is both rarer and far more
## obvious on screen.
func _is_worth_naming(module: ModuleBase) -> bool:
	var data: ModuleData = module.module_data
	if data == null:
		return false
	if data.interaction_layer != WorldManager.StructureLayer.MODULE:
		return false
	var world: WorldManager = Global.world_manager
	return world == null or data != world.replacement_module

func _is_cut_off(anchor: ModuleBase, module: ModuleBase) -> bool:
	if module == anchor or Global.path_manager == null:
		return false
	return not Global.path_manager.is_reachable(anchor, module)

## Dark, and not dark because the player switched it off. Firing "your module has
## no power" at somebody who just pressed Force Shutdown is worse than noise.
func _is_dark(module: ModuleBase) -> bool:
	var consumer: PowerConsumptionComponent = module.get_component_by_type(
		PowerConsumptionComponent) as PowerConsumptionComponent
	if consumer == null or consumer.force_off:
		return false
	return not consumer.powered

# --- firing ---------------------------------------------------------------------

## The first unspent hint on `trigger` whose filter matches, if any.
func _fire_for(trigger: StringName, filter: StringName, subject: Node) -> void:
	for hint: TutorialHintData in _by_trigger.get(trigger, []):
		if ledger.is_spent(hint.id):
			continue
		if triggers.takes_filter(trigger) and hint.trigger_filter != filter:
			continue
		fire(hint.id, subject)
		return

## Gives one advisory, spending it. Public because the cheat console drives it and
## because AIDE replays through [method replay_hint].
func fire(id: StringName, subject: Node = null) -> void:
	var hint: TutorialHintData = _hints.get(id)
	if hint == null:
		push_error("TutorialManager: no such hint '%s'" % id)
		return
	# An advisory about a specific pawn or module, with neither, would read "that
	# has not eaten" - and would have spent itself to say it. Leave it armed: the
	# advice has not been given, so the next occurrence should still get it.
	if hint.has_subject and (subject == null or not is_instance_valid(subject)):
		push_warning("TutorialManager: '%s' needs a subject and got none - staying armed"
			% hint.id)
		return
	# Spend **first**. Two triggers racing in one tick would otherwise both pass
	# the is_spent check and queue two identical conversations.
	if not ledger.spend(hint.id):
		return
	_disarm_spent()
	_transmit(hint)
	_open(hint, subject)

## Runs a hint's conversation again without touching the ledger or the log. A
## replay is not a first run.
func replay_hint(id: StringName) -> void:
	var hint: TutorialHintData = _hints.get(id)
	if hint == null:
		push_error("TutorialManager: no such hint '%s'" % id)
		return
	_open(hint, null)

func _open(hint: TutorialHintData, subject: Node) -> void:
	if Global.dialogue_runner == null:
		return
	bridge.reset()
	bridge.subject = subject
	bridge.expects_subject = hint.has_subject
	Global.dialogue_runner.run(hint.dialogue, hint.cue, [], _on_hint_finished)

func _on_hint_finished() -> void:
	if coach != null and is_instance_valid(coach):
		coach.clear_mark()
	bridge.subject = null
	bridge.expects_subject = false

## The durable copy. A hint fires once and never again, so a player who was
## mid-placement when it appeared and clicked through it has lost it otherwise -
## which is exactly what WI-57 built the transmission log for.
func _transmit(hint: TutorialHintData) -> void:
	if Global.alert_manager == null or hint.body.is_empty():
		return
	var sender: String = "SAI"
	var speaker: SpeakerData = _speaker()
	if speaker != null and not speaker.display_name.is_empty():
		sender = speaker.display_name
	var subject: String = hint.title if not hint.title.is_empty() else "Advisory"
	Global.alert_manager.post_transmission(HINT_FAMILY, sender, subject, hint.body)

func _speaker() -> SpeakerData:
	var runner: DialogueRunner = Global.dialogue_runner
	return runner.speaker(SPEAKER_ID) if runner != null else null

# --- skipping -------------------------------------------------------------------

## The New Game checkbox and the coach mark's skip control land here, and they
## mean the same thing: stop teaching. Every hint is spent, every watcher is
## dropped, and AIDE keeps all of it replayable.
func skip_tutorial() -> void:
	ledger.skip(hint_ids())
	_disarm_spent()
	if coach != null and is_instance_valid(coach):
		coach.clear_mark()
	if Global.dialogue_runner != null and Global.dialogue_runner.is_busy():
		Global.dialogue_runner.abandon()

# --- queries --------------------------------------------------------------------

func hint(id: StringName) -> TutorialHintData:
	return _hints.get(id)

## Every hint id there is, in scan order. What [method TutorialLedger.skip] and
## [method TutorialLedger.mark_legacy] are handed.
func hint_ids() -> Array[StringName]:
	var out: Array[StringName] = _hints.keys()
	return out

func hint_count() -> int:
	return _hints.size()

## Advisories already given, newest first - the AIDE archive's order.
func given_hints() -> Array[TutorialHintData]:
	var out: Array[TutorialHintData] = []
	var spent: Array[StringName] = ledger.spent_hints()
	spent.reverse()
	for id: StringName in spent:
		var found: TutorialHintData = _hints.get(id)
		if found != null:
			out.append(found)
	return out

func unseen_count() -> int:
	return maxi(0, _hints.size() - ledger.spent_count())

## For `dump_tutorial()` and the probe.
func describe() -> String:
	var lines := PackedStringArray()
	lines.append("onboarding_done=%s skipped=%s new_game=%s"
		% [ledger.onboarding_done, ledger.skipped, _is_new_game])
	lines.append("hints %d/%d given, scan=%s, waiting_on='%s'"
		% [ledger.spent_count(), _hints.size(), _scanning, bridge.waiting_for()])
	for id: StringName in _hints:
		lines.append("  %s [%s] %s" % [id, _hints[id].trigger,
			"given" if ledger.is_spent(id) else "armed"])
	return "\n".join(lines)

# --- persistence ----------------------------------------------------------------

func get_save_data() -> Dictionary:
	return ledger.to_save()

## The `legacy` marker is what [method SaveManager.register_section]'s `empty`
## argument hands back when the save has no `tutorial` section at all - see the
## class comment for why that means "complete" rather than "fresh".
func load_save_data(data: Dictionary) -> void:
	if bool(data.get("legacy", false)):
		ledger.clear()
		ledger.mark_legacy(hint_ids())
		return
	ledger.from_save(data, hint_ids())
