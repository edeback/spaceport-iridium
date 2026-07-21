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

@export var crew_pawn_scene: PackedScene
@export var shuttle_scene: PackedScene
@export var starting_crew: int = 2
@export var hire_cost: int = 400
@export var arrival_delay_hours: float = 4.0
## How far off to the side of the bay the shuttle spawns and exits, in px.
@export var shuttle_approach_distance: float = 1200.0
## Curated identity tints (WI-22) rolled per crew member at spawn. Deliberately
## light and low-saturation: modulate multiplies the sprite art, so full-random
## colours muddy it - these keep the pawn readable against module interiors.
## Data, not a code constant, so the palette is tunable without a recompile.
@export var crew_tint_palette: PackedColorArray = PackedColorArray([
	Color(1.0, 0.76, 0.72),   # salmon
	Color(0.98, 0.85, 0.68),  # tan
	Color(0.98, 0.92, 0.70),  # gold
	Color(0.86, 0.94, 0.70),  # chartreuse
	Color(0.78, 0.94, 0.76),  # sage
	Color(0.72, 0.92, 0.86),  # aqua
	Color(0.74, 0.90, 0.98),  # sky
	Color(0.78, 0.82, 0.98),  # periwinkle
	Color(0.87, 0.79, 0.97),  # lavender
	Color(0.98, 0.80, 0.92),  # rose
	Color(0.88, 0.85, 0.80),  # warm grey
	Color(0.74, 0.83, 0.88),  # slate
])
## Upper bound on traits rolled per crew member (WI-22); the actual count is a
## uniform 0..this. roll_set never picks two conflicting traits.
@export var max_traits_per_crew: int = 2

# --- hire candidates (WI-22) --------------------------------------------------
## How many candidates stand on offer at once (WI spec: 3-5).
@export var candidate_pool_size: int = 4
## Price = hire_cost x (1 + total_skill_levels * this) x trait price modifiers.
## Monotonic in total skill so a two-standout roll is never cheaper than one.
@export var skill_premium_per_level: float = 0.08
## Candidate skill roll: every skill starts a low 0..base_max, then a few
## standouts are bumped into the standout band.
@export var candidate_base_skill_max: int = 2
@export var candidate_standout_min: int = 1
@export var candidate_standout_max: int = 2
@export var candidate_standout_min_level: int = 4
@export var candidate_standout_max_level: int = 9

## Pending hires: {"remaining": sim-hours left, "bay": module ref Dictionary
## (layer+cell, JSON-safe - resolved at arrival so a deconstructed bay can
## refund instead of dangling), "candidate": HireCandidate.to_dict()}.
var _pending_hires: Array[Dictionary] = []
## Standing recruitment pool; regenerated on each trader visit. Lazily filled
## on first access so a fresh game has offers the moment the window opens.
var _candidates: Array[HireCandidate] = []
var _pool_generated: bool = false
var _game_over_fired: bool = false

func _ready() -> void:
	Global.crew_manager = self
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

func _spawn_starting_crew(home: ModuleBase) -> void:
	if not is_instance_valid(home):
		return
	for i: int in starting_crew:
		spawn_crew(home)

# --- roster -------------------------------------------------------------------

## All living organic crew. include_leaving = false filters out pawns that
## have already resigned and are walking to the bay.
func get_crew(include_leaving: bool = true) -> Array[PawnBase]:
	var crew: Array[PawnBase] = []
	for node: Node in get_tree().get_nodes_in_group("pawn"):
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

## Total sleeping slots across constructed pods - the housing capacity gate.
func sleep_capacity() -> int:
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group("sleep_component"):
		total += (node as SleepComponent).capacity
	return total

func pending_hire_count() -> int:
	return _pending_hires.size()

# --- hiring -------------------------------------------------------------------

## "" means a hire is currently allowed; otherwise a player-facing reason.
## Priced against `candidate` when given, else the base hire_cost.
func hire_block_reason(candidate: HireCandidate = null) -> String:
	if crew_count() + _pending_hires.size() >= sleep_capacity():
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
	_candidates.erase(candidate)
	_pending_hires.append({
		"remaining": arrival_delay_hours,
		"bay": SaveManager.module_ref(bay),
		"candidate": candidate.to_dict(),
	})
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

func _generate_candidate() -> HireCandidate:
	var candidate := HireCandidate.new()
	candidate.pawn_name = NameGenerator.random_name()
	candidate.tint = roll_tint()
	candidate.skills = _roll_candidate_skills()
	for trait_data: TraitData in TraitData.roll_set(randi_range(0, max_traits_per_crew)):
		candidate.trait_ids.append(trait_data.id)
	candidate.price = _compute_price(candidate)
	return candidate

## Every skill low (0..base_max), then 1-2 standouts bumped high - "mostly low
## with a couple of strengths".
func _roll_candidate_skills() -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	var all_skills: Array[SkillData] = SkillData.all()
	for skill: SkillData in all_skills:
		out[skill.id] = randi_range(0, candidate_base_skill_max)
	var pool: Array[SkillData] = all_skills.duplicate()
	pool.shuffle()
	var standouts: int = randi_range(candidate_standout_min, candidate_standout_max)
	for i: int in mini(standouts, pool.size()):
		out[pool[i].id] = randi_range(candidate_standout_min_level, candidate_standout_max_level)
	return out

## Base cost scaled by a skill premium (monotonic in total levels) and the
## product of the candidate's trait price modifiers (good up, bad down).
func _compute_price(candidate: HireCandidate) -> int:
	var trait_mod: float = 1.0
	for tid: StringName in candidate.trait_ids:
		var trait_data: TraitData = TraitData.by_id(tid)
		if trait_data != null:
			trait_mod *= trait_data.price_modifier
	return compute_price(hire_cost, candidate.total_skill_levels(), trait_mod, skill_premium_per_level)

## Pure pricing arithmetic (WI-22), extracted so it can be unit-tested without
## Global. Strictly increasing in total_skill_levels for a fixed trait modifier,
## which guarantees a higher-skilled roll is never cheaper (the "no elite for
## free" edge case).
static func compute_price(base_cost: int, total_skill_levels: int, trait_price_mod: float, premium_per_level: float) -> int:
	var skill_premium: float = 1.0 + float(total_skill_levels) * premium_per_level
	return int(round(float(base_cost) * skill_premium * trait_price_mod))

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	for i: int in range(_pending_hires.size() - 1, -1, -1):
		_pending_hires[i]["remaining"] = float(_pending_hires[i]["remaining"]) - sim_hours
		if float(_pending_hires[i]["remaining"]) <= 0.0:
			var hire: Dictionary = _pending_hires[i]
			_pending_hires.remove_at(i)
			_arrive(hire)

func _arrive(hire: Dictionary) -> void:
	var bay: ModuleBase = SaveManager.resolve_module_ref(hire.get("bay", {}))
	var candidate: HireCandidate = HireCandidate.from_dict(hire.get("candidate", {}))
	if bay == null or not is_instance_valid(bay):
		_refund_hire(candidate)
		return
	if shuttle_scene == null:
		_deliver_crew(bay, candidate)
		return
	var shuttle: ArrivalShuttle = shuttle_scene.instantiate() as ArrivalShuttle
	Global.world_manager.pawn_layer.add_child(shuttle)
	var dock: Vector2 = DockingBay.dock_position_for(bay)
	shuttle.setup(dock, dock + Vector2(DockingBay.approach_sign_for(bay) * shuttle_approach_distance, 0.0))
	shuttle.docked.connect(_on_shuttle_docked.bind(shuttle, bay, candidate), CONNECT_ONE_SHOT)

## Bay deconstructed while the shuttle was inbound: refund the price paid
## (WI-07 edge case).
func _refund_hire(candidate: HireCandidate) -> void:
	var amount: int = candidate.price if candidate != null else hire_cost
	Global.resource_manager.credit_resource.change_global_total(amount)
	SignalBus.station_alert.emit("Recruit had nowhere to dock — fee refunded")

func _on_shuttle_docked(shuttle: ArrivalShuttle, bay: ModuleBase, candidate: HireCandidate) -> void:
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
	var pawn: PawnBase = crew_pawn_scene.instantiate() as PawnBase
	# First two keep their always-on schedule
	if pawn.schedule != null and crew_count() >= 2:
		if crew_count() % 2 == 1:
			pawn.schedule = ScheduleData.shift_a()
		else:
			pawn.schedule = ScheduleData.shift_b()
	# Add to tree BEFORE setting current_module: the setter reparents, which
	# needs a parent (this was the old PawnStorageComponent boot error).
	Global.world_manager.pawn_layer.add_child(pawn)
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
	if crew_tint_palette.is_empty():
		return Color.WHITE
	return crew_tint_palette[randi() % crew_tint_palette.size()]

# --- departure & lose condition -------------------------------------------------

func _on_crew_resigned(pawn: PawnBase) -> void:
	# Graceful interrupt (WI-04): whatever they were doing cancels cleanly,
	# carried cargo stays with them and piles up at despawn.
	pawn.interrupt_with_job(Job_LeaveStation.new())

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
	if crew_count() > 0 or not _pending_hires.is_empty():
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
		"pending_hires": _pending_hires.duplicate(true),
		"candidates": candidates_out,
		"pool_generated": _pool_generated,
	}

func load_save_data(data: Dictionary) -> void:
	_pending_hires.clear()
	for entry in data.get("pending_hires", []):
		var hire: Dictionary = entry
		_pending_hires.append({
			"remaining": float(hire.get("remaining", 0.0)),
			"bay": hire.get("bay", {}),
			"candidate": hire.get("candidate", {}),
		})
	_candidates.clear()
	for candidate_data: Dictionary in data.get("candidates", []):
		_candidates.append(HireCandidate.from_dict(candidate_data))
	# Pre-WI-22 saves lack the pool; leave it ungenerated so it fills lazily on
	# first open rather than showing an empty window.
	_pool_generated = bool(data.get("pool_generated", false))
	SignalBus.hire_candidates_changed.emit()
