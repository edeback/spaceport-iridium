class_name CrewManager
extends Node

## Crew lifecycle (WI-07): owns starting-crew spawn, hiring (with shuttle
## arrivals), resignation departures, and the lose condition. Registers as
## Global.crew_manager; sits after the world/job managers in main.tscn's
## Managers node (tree order = ready order).
##
## The roster is a live query over the "pawn" group (drones excluded) rather
## than a stored array - pawns enter via spawn_crew()/save-load and leave via
## queue_free, and a query can't drift out of sync with either.

## How many crew a fresh station opens with. A const as well as an export
## because the New Game setup screen (WI-59) has to know how many candidates the
## player must pick before any CrewManager exists to ask.
const STARTING_CREW: int = 2

@export var crew_pawn_scene: PackedScene
@export var shuttle_scene: PackedScene
@export var starting_crew: int = STARTING_CREW
@export var arrival_delay_hours: float = 4.0
## How far off to the side of the bay the shuttle spawns and exits, in px.
@export var shuttle_approach_distance: float = 1200.0

# --- hire candidates (WI-22, rolled by CandidateRoller since WI-59) -----------
## How many candidates stand on offer at once (WI spec: 3-5).
@export var candidate_pool_size: int = 4
## The roll knobs. These initialise from [CandidateRoller]'s consts rather than
## restating the numbers: WI-59 moved the roll itself off this manager so the New
## Game screen could show a pool before main.tscn exists, and two copies of the
## band would be free to drift the moment anyone tuned one. The exports stay so
## main.tscn can still tune the in-game pool.
@export var hire_cost: int = CandidateRoller.DEFAULT_HIRE_COST
@export var skill_premium_per_level: float = CandidateRoller.DEFAULT_SKILL_PREMIUM_PER_LEVEL
## Upper bound on traits rolled per crew member; the actual count is a uniform
## 0..this. roll_set never picks two conflicting traits.
@export var max_traits_per_crew: int = CandidateRoller.DEFAULT_MAX_TRAITS
@export var candidate_base_skill_max: int = CandidateRoller.DEFAULT_BASE_SKILL_MAX
@export var candidate_standout_min: int = CandidateRoller.DEFAULT_STANDOUT_MIN
@export var candidate_standout_max: int = CandidateRoller.DEFAULT_STANDOUT_MAX
@export var candidate_standout_min_level: int = CandidateRoller.DEFAULT_STANDOUT_MIN_LEVEL
@export var candidate_standout_max_level: int = CandidateRoller.DEFAULT_STANDOUT_MAX_LEVEL
## Curated identity tints rolled per crew member at spawn. Data, not a code
## constant, so the palette is tunable without a recompile.
@export var crew_tint_palette: Array[Color] = CandidateRoller.DEFAULT_TINTS

## Paid hires with no pawn yet - through the arrival delay AND the shuttle's
## flight in, which is what keeps the lose check from ending a run whose only crew
## is on final approach. See [PendingHires].
var _pending: PendingHires = PendingHires.new()
## Standing recruitment pool; regenerated on each trader visit. Lazily filled
## on first access so a fresh game has offers the moment the window opens.
var _candidates: Array[HireCandidate] = []
var _pool_generated: bool = false
var _game_over_fired: bool = false

func _ready() -> void:
	Global.crew_manager = self
	# After world: pending hires resolve their bay by layer+cell at arrival.
	SaveManager.register_section(&"crew", 110, get_save_data, load_save_data)
	SignalBus.crew_resigned.connect(_on_crew_resigned)
	# A trader visit refreshes the recruitment offers (WI-22).
	SignalBus.trader_arrived.connect(_on_trader_arrived)
	# The starting station is spawned by WorldManager at runtime, AFTER any
	# fixed number of deferred hops - so react to the module actually
	# appearing instead of guessing at ordering.
	SignalBus.module_added.connect(_on_module_added_for_start)

var _starting_crew_spawned: bool = false

func _on_module_added_for_start(module: ModuleBase) -> void:
	if _starting_crew_spawned:
		return
	# Loaded games restore their crew from the save's pawn section instead.
	if SaveManager.is_loading() or SaveManager.has_pending_load():
		_starting_crew_spawned = true
		SignalBus.module_added.disconnect(_on_module_added_for_start)
		Global.time_manager.slow_tick.connect(_on_slow_tick)
		return
	if module.module_data == null or module.module_data.id != &"starting_module_mdata":
		return
	_starting_crew_spawned = true
	SignalBus.module_added.disconnect(_on_module_added_for_start)
	Global.time_manager.slow_tick.connect(_on_slow_tick)
	# Deferred one tick: module_added fires before on_place() assigns the
	# module's cell, and spawn positions derive from it.
	_spawn_starting_crew.call_deferred(module)

## The founding crew. The New Game setup screen (WI-59) stages the two the player
## picked; take_staged_crew() hands them over and clears them, so nothing can
## re-apply a stale founding roster later in the run.
##
## The top-up afterwards is not defensive padding: it is the path that keeps
## playing main.tscn directly from the editor working, which stages nothing at
## all. An empty staged list reproduces the pre-WI-59 behaviour exactly.
func _spawn_starting_crew(home: ModuleBase) -> void:
	if not is_instance_valid(home):
		return
	var picked: Array[HireCandidate] = Global.take_staged_crew()
	for candidate: HireCandidate in picked:
		spawn_crew(home, candidate)
	for i: int in maxi(starting_crew - picked.size(), 0):
		spawn_crew(home)

# --- roster -------------------------------------------------------------------

## All living organic crew. include_leaving = false filters out pawns that
## have already resigned and are walking to the bay.
func get_crew(include_leaving: bool = true) -> Array[PawnBase]:
	var crew: Array[PawnBase] = []
	for node: Node in get_tree().get_nodes_in_group(Groups.PAWN):
		var pawn: PawnBase = node as PawnBase
		# Robots (mining drones + hauler robots, WI-28) and visitors (WI-26
		# inspector) aren't crew: no wage, no roster.
		if pawn == null or pawn is RobotPawnBase or pawn.is_visitor or pawn.is_queued_for_deletion():
			continue
		if not include_leaving:
			var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
			if needs != null and needs.resigned:
				continue
		crew.append(pawn)
	return crew

func crew_count(include_leaving: bool = true) -> int:
	return get_crew(include_leaving).size()

## Total CREW sleeping slots across constructed pods - the hiring housing gate.
## Excludes visitor-only hotel rooms (WI-33): a hotel is not crew housing, so a
## station of hotels-and-no-bunks can't hire.
func sleep_capacity() -> int:
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group(Groups.SLEEP_COMPONENT):
		var pod: SleepComponent = node as SleepComponent
		if pod != null and not pod.visitor_only:
			total += pod.capacity
	return total

## Total VISITOR sleeping slots across constructed hotel rooms (WI-33). The
## visitor-capacity gate: guests only arrive if a free hotel bunk exists.
func visitor_sleep_capacity() -> int:
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group(Groups.SLEEP_COMPONENT):
		var pod: SleepComponent = node as SleepComponent
		if pod != null and pod.visitor_only:
			total += pod.capacity
	return total

## Count of currently-free visitor (hotel) bunks - the at-arrival capacity check.
func free_visitor_bunks() -> int:
	var free: int = 0
	for node: Node in get_tree().get_nodes_in_group(Groups.SLEEP_COMPONENT):
		var pod: SleepComponent = node as SleepComponent
		if pod != null and pod.visitor_only and pod.owner_module != null and pod.owner_module.is_complete():
			free += maxi(pod.capacity - pod.claimed_count(), 0)
	return free

func pending_hire_count() -> int:
	return _pending.count()

# --- hiring -------------------------------------------------------------------

## "" means a hire is currently allowed; otherwise a player-facing reason.
## Priced against `candidate` when given, else the base hire_cost.
func hire_block_reason(candidate: HireCandidate = null) -> String:
	if crew_count() + _pending.count() >= sleep_capacity():
		return "No free sleeping pods"
	var cost: int = candidate.price if candidate != null else hire_cost
	if Global.resource_manager.credit_resource.get_total() < cost:
		return "Not enough credits"
	return ""

## Hires `candidate` from the pool: charges its price, removes it from the
## offers, and queues the shuttle arrival. Returns false (unchanged state) if
## blocked or the candidate is stale (pool refreshed out from under the UI).
func request_hire(bay: ModuleBase, candidate: HireCandidate) -> bool:
	if bay == null or candidate == null or not _candidates.has(candidate):
		return false
	if hire_block_reason(candidate) != "":
		return false
	Global.resource_manager.credit_resource.force_withdraw(candidate.price)
	Global.economy_manager.record_external_cost(candidate.price, &"hiring") # WI-68 F4
	_candidates.erase(candidate)
	_pending.add(SaveManager.module_ref(bay), candidate.to_dict(), arrival_delay_hours)
	SignalBus.hire_candidates_changed.emit()
	return true

# --- candidate pool -----------------------------------------------------------

## The current offers, generating an initial pool on first access.
func get_candidates() -> Array[HireCandidate]:
	_ensure_pool()
	return _candidates

func _ensure_pool() -> void:
	if _pool_generated:
		return
	_pool_generated = true
	_fill_pool()

func _fill_pool() -> void:
	_candidates.clear()
	for i: int in candidate_pool_size:
		_candidates.append(_generate_candidate())
	SignalBus.hire_candidates_changed.emit()

func _on_trader_arrived(_trader: TraderData) -> void:
	_pool_generated = true
	_fill_pool()

## A roller carrying this manager's tuning (WI-59). Built per call rather than
## cached: the exports are editor-tunable and a cached roller would keep serving
## the values the manager readied with.
func make_roller() -> CandidateRoller:
	var roller := CandidateRoller.new()
	roller.hire_cost = hire_cost
	roller.skill_premium_per_level = skill_premium_per_level
	roller.max_traits_per_crew = max_traits_per_crew
	roller.base_skill_max = candidate_base_skill_max
	roller.standout_min = candidate_standout_min
	roller.standout_max = candidate_standout_max
	roller.standout_min_level = candidate_standout_min_level
	roller.standout_max_level = candidate_standout_max_level
	roller.tint_palette = crew_tint_palette
	return roller

func _generate_candidate() -> HireCandidate:
	return make_roller().roll()

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	for hire: Dictionary in _pending.advance(sim_hours):
		_arrive(hire)

## The hire's delay is up. It stays pending until it is settled here or when its
## shuttle docks - never in between, or the lose check sees an empty station.
func _arrive(hire: Dictionary) -> void:
	var bay: ModuleBase = SaveManager.resolve_module_ref(hire.get("bay", {}))
	var candidate: HireCandidate = HireCandidate.from_dict(hire.get("candidate", {}))
	if bay == null or not is_instance_valid(bay):
		_pending.settle(hire)
		_refund_hire(candidate)
		return
	if shuttle_scene == null:
		_pending.settle(hire)
		_deliver_crew(bay, candidate)
		return
	var shuttle: ArrivalShuttle = shuttle_scene.instantiate() as ArrivalShuttle
	Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.SPACE).add_child(shuttle)
	var dock: Vector2 = DockingBay.dock_position_for(bay)
	shuttle.setup(dock, dock + Vector2(DockingBay.approach_sign_for(bay) * shuttle_approach_distance, 0.0))
	shuttle.docked.connect(_on_shuttle_docked.bind(shuttle, bay, hire), CONNECT_ONE_SHOT)

## Bay deconstructed while the shuttle was inbound: refund the price paid
## (WI-07 edge case).
func _refund_hire(candidate: HireCandidate) -> void:
	var amount: int = candidate.price if candidate != null else hire_cost
	Global.resource_manager.credit_resource.change_global_total(amount)
	# Undoes the hiring cost in the books too: income, never skimmed (WI-68 F4).
	Global.economy_manager.record_refund(amount)
	AlertManager.raise_alert(&"hire_refunded", AlertData.Priority.HIGH,
		"Recruit turned back", "No docking bay · %d cr fee refunded" % amount, null, &"crew")

func _on_shuttle_docked(shuttle: ArrivalShuttle, bay: ModuleBase, hire: Dictionary) -> void:
	# A refused settle means this list no longer holds the hire - a load since
	# launch has already relaunched it - so this shuttle arrives empty.
	if _pending.settle(hire):
		var candidate: HireCandidate = HireCandidate.from_dict(hire.get("candidate", {}))
		if is_instance_valid(bay):
			_deliver_crew(bay, candidate)
		else:
			_refund_hire(candidate)
	# Wait a little bit before flying away
	await Global.time_manager.sim_seconds(Global.time_manager.SECONDS_PER_HOUR)
	shuttle.depart()

func _deliver_crew(bay: ModuleBase, candidate: HireCandidate) -> void:
	var pawn: PawnBase = spawn_crew(bay, candidate)
	SignalBus.crew_hired.emit(pawn)

## Spawns one crew pawn inside at_module. Shifts alternate with roster
## parity so hires keep covering the clock (WI-06). With a `candidate` the
## pawn takes that rolled identity (name/tint/skills/traits/price); without one
## (starting crew) it rolls a fresh identity
func spawn_crew(at_module: ModuleBase, candidate: HireCandidate = null) -> PawnBase:
	# Which KIND of crew (WI-47 M10). A hire arrives as the kind its candidate was
	# rolled as; starting crew rolls fresh. An unknown id (the mod that declared it
	# has been uninstalled between queueing the hire and its shuttle landing) and an
	# empty data/pawns/ both fall through to the authored fallback scene.
	var kind: PawnData = null
	if candidate != null and candidate.pawn_id != &"":
		kind = PawnData.by_id(candidate.pawn_id)
		if kind == null:
			push_warning("Hired pawn kind '%s' is not installed - spawning the default crew member" % candidate.pawn_id)
	if kind == null:
		kind = PawnData.roll_for_role(PawnData.Role.CREW)
	var scene: PackedScene = kind.scene if kind != null and kind.scene != null else crew_pawn_scene
	if scene == null:
		push_warning("CrewManager has no crew scene to spawn")
		return null
	var pawn: PawnBase = scene.instantiate() as PawnBase
	if pawn == null:
		push_warning("Crew scene for '%s' is not a PawnBase" % (kind.id if kind != null else &"<fallback>"))
		return null
	# First two keep their always-on schedule
	if pawn.schedule != null and crew_count() >= 2:
		if crew_count() % 2 == 1:
			pawn.schedule = ScheduleData.shift_a()
		else:
			pawn.schedule = ScheduleData.shift_b()
	# Add to tree BEFORE setting current_module: the setter reparents, which
	# needs a parent (this was the old PawnStorageComponent boot error).
	Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.SPACE).add_child(pawn)
	pawn.current_module = at_module
	pawn.global_position = Global.cell_to_world(at_module.module_cell, true)
	# Identity (WI-22). Set after add_child so the tint setter sees the resolved
	# sprite; everything here round-trips through the save's pawn section.
	if candidate != null:
		candidate.apply_to(pawn)
	else:
		# Roll a random candidate
		var random_candidate := _generate_candidate()
		random_candidate.apply_to(pawn)
		#pawn.pawn_name = NameGenerator.random_name()
		#pawn.tint = roll_tint()
		#pawn.hire_price = hire_cost
		#var traits_comp: PawnTraitsComponent = pawn.get_traits_component()
		#if traits_comp != null:
			#traits_comp.set_traits(TraitData.roll_set(randi_range(0, max_traits_per_crew)))
	return pawn

## Random tint from the curated palette (WI-22). Public so save-load migration
## of pre-identity crew can reuse the same roll.
func roll_tint() -> Color:
	return make_roller().roll_tint()

# --- departure & lose condition -------------------------------------------------

func _on_crew_resigned(pawn: PawnBase) -> void:
	# Graceful interrupt (WI-04): whatever they were doing cancels cleanly,
	# carried cargo stays with them and piles up at despawn.
	pawn.interrupt_with_job(Job.of(&"leave_station"))

## Player-initiated firing (WI-25): reuses the resignation departure but is NOT
## morale-driven. Latching `resigned` before emitting stops the pawn drawing a
## wage from the next cycle (get_crew(false) filters it out) and blocks its needs
## component from also running the misery-resignation path. The severance charge
## itself lives in EconomyManager.fire_pawn, which calls this.
func fire_crew(pawn: PawnBase) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs != null:
		needs.resigned = true
	SignalBus.crew_resigned.emit(pawn)

func _on_slow_tick(_interval: float) -> void:
	_check_lose_condition()

func _check_lose_condition() -> void:
	if _game_over_fired:
		return
	# A hire counts until its pawn is standing in the bay, shuttle flight
	# included - a station whose only crew is on final approach is not abandoned.
	if crew_count() > 0 or not _pending.is_empty():
		return
	# Roster empty AND can't afford a replacement - empty-but-solvent is
	# recoverable by hiring, so it's deliberately not game over.
	if Global.resource_manager.credit_resource.get_total() >= hire_cost:
		return
	_game_over_fired = true
	SignalBus.game_over.emit("The last of your crew has left, and you can't afford replacements.")

# --- persistence ---------------------------------------------------------------

func get_save_data() -> Dictionary:
	var candidates_out: Array = []
	for candidate: HireCandidate in _candidates:
		candidates_out.append(candidate.to_dict())
	return {
		"pending_hires": _pending.to_save(),
		"candidates": candidates_out,
		"pool_generated": _pool_generated,
	}

func load_save_data(data: Dictionary) -> void:
	_pending.load_save(data.get("pending_hires", []))
	_candidates.clear()
	for candidate_data: Dictionary in data.get("candidates", []):
		_candidates.append(HireCandidate.from_dict(candidate_data))
	# Pre-WI-22 saves lack the pool; leave it ungenerated so it fills lazily on
	# first open rather than showing an empty window.
	_pool_generated = bool(data.get("pool_generated", false))
	SignalBus.hire_candidates_changed.emit()
