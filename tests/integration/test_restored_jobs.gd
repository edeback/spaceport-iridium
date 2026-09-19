extends GutTest

## Jobs restored by a load pick up where they left off (WI-69 §4). Two WI-68
## regressions, each first seen only in a scratch-copy probe:
##
## - **F2 / R7:** a crew member saved mid-way to an airlock to suit up. The trip
##   pointer was not re-linked on load, so the component posted a second trip and
##   the orphaned first walked an already-suited crew member back to an airlock.
##   Pinned as "one trip, never two at once, suited once", with a no-reload
##   control run through the same scenario.
## - **F21:** a pawn restored mid-haul put its cargo away before resuming the
##   haul that cargo belonged to. Pinned as "the first job begun after the load is
##   the restored one".

## Generous: the control suits up in about seven sim-seconds on this station.
const SUIT_UP_WITHIN: float = 30.0

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

# --- F2: the suit trip across a reload ----------------------------------------

func test_control_a_crew_member_suits_up_at_the_airlock() -> void:
	var walker: PawnBase = await _crew_walking_to_suit_up()
	assert_not_null(walker, "a crew member set off for the airlock")
	if walker == null:
		return
	var trips: Dictionary[int, bool] = {}
	var most_at_once: Array[int] = [0]
	var suited: bool = await fx.tick_until(func() -> bool:
		_count_trips(walker, trips, most_at_once)
		return _suit(walker).suited, SUIT_UP_WITHIN, 0.1)
	assert_true(suited, "suited within %.0f sim-seconds" % SUIT_UP_WITHIN)
	assert_eq(most_at_once[0], 1, "never two trips at once")
	assert_eq(trips.size(), 1, "one trip")

func test_a_suit_trip_saved_mid_walk_finishes_once_after_the_load() -> void:
	var walker: PawnBase = await _crew_walking_to_suit_up()
	assert_not_null(walker, "a crew member set off for the airlock")
	if walker == null:
		return
	var walker_id: int = walker.pawn_id
	assert_true(await fx.save_and_reload())
	walker = _crew_by_id(walker_id)
	assert_not_null(walker, "the walker came back")
	if walker == null:
		return
	var suit: PawnSuitComponent = _suit(walker)
	assert_false(suit.suited, "restored unsuited, mid-trip")
	assert_true(suit.has_live_trip(), "and the component knows about the restored trip (F2)")
	var suited_count: Array[int] = [0]
	suit.suit_changed.connect(func(now_suited: bool) -> void:
		if now_suited:
			suited_count[0] += 1)
	var trips: Dictionary[int, bool] = {}
	var most_at_once: Array[int] = [0]
	var suited: bool = await fx.tick_until(func() -> bool:
		_count_trips(walker, trips, most_at_once)
		return suit.suited, SUIT_UP_WITHIN, 0.1)
	assert_true(suited, "suited within %.0f sim-seconds of the load" % SUIT_UP_WITHIN)
	assert_eq(most_at_once[0], 1, "never two trips at once")
	assert_eq(trips.size(), 1, "one trip - the restored one")
	# Past the point where the orphaned duplicate used to set off again.
	assert_true(await fx.tick(10.0))
	_count_trips(walker, trips, most_at_once)
	assert_eq(trips.size(), 1, "and no second trip afterwards")
	assert_eq(suited_count[0], 1, "suited exactly once")

## Tier 2 (suits are no longer mandatory), wait for the crew to change out of
## them, then vent the whole station. Returns the first crew member with a live
## trip who is still walking, or null.
func _crew_walking_to_suit_up() -> PawnBase:
	Global.unlock_manager.advance_tier()
	var unsuited: bool = await fx.tick_until(func() -> bool:
		for pawn: PawnBase in _crew():
			var suit: PawnSuitComponent = _suit(pawn)
			if suit.suited or suit.has_live_trip():
				return false
		return true, 120.0)
	assert_true(unsuited, "at Tier 2 the crew change out of their suits")
	for module: ModuleBase in fx.modules():
		var air: AtmosphereComponent = Global.atmosphere_manager.get_component(module)
		if air != null:
			air.o2 = 0.0
	var walker: Array[PawnBase] = [null]
	await fx.tick_until(func() -> bool:
		for pawn: PawnBase in _crew():
			var suit: PawnSuitComponent = _suit(pawn)
			if suit.has_live_trip() and not suit.suited and pawn.current_job != null \
					and pawn.current_job.is_type(PawnSuitComponent.CHANGE_SUIT_JOB) \
					and pawn.current_job.action_index() > 0:
				walker[0] = pawn
				return true
		return false, 10.0, 0.05)
	return walker[0]

func _count_trips(pawn: PawnBase, trips: Dictionary[int, bool], most_at_once: Array[int]) -> void:
	var live: int = 0
	var jobs: Array[Job] = pawn.job_queue.duplicate()
	if pawn.current_job != null:
		jobs.append(pawn.current_job)
	for job: Job in jobs:
		if job.is_type(PawnSuitComponent.CHANGE_SUIT_JOB) and not job.is_ended():
			live += 1
			trips[job.get_instance_id()] = true
	most_at_once[0] = maxi(most_at_once[0], live)

# --- F21: a restored job runs before the cargo sweep ---------------------------

func test_a_pawn_restored_mid_haul_resumes_the_haul_before_sweeping_its_cargo() -> void:
	# A blueprint beside the station pulls steel out of the Command Center.
	fx.place(&"small_storage", Vector2i(14, 8), false)
	var hauler: Array[PawnBase] = [null]
	var found: bool = await fx.tick_until(func() -> bool:
		for pawn: PawnBase in _crew():
			if pawn.current_job != null and pawn.current_job.is_type(&"haul_resource") \
					and not pawn.inventory_component.is_empty():
				hauler[0] = pawn
				return true
		return false, 60.0, 0.05)
	assert_true(found, "a crew member is carrying a haul")
	if not found:
		return
	var hauler_id: int = hauler[0].pawn_id
	assert_true(await fx.save_and_reload())
	var restored: PawnBase = _crew_by_id(hauler_id)
	assert_not_null(restored)
	if restored == null:
		return
	assert_false(restored.inventory_component.is_empty(), "restored with the cargo")
	var begun: Array[StringName] = []
	restored.job_changed.connect(func() -> void:
		if restored.current_job != null:
			begun.append(restored.current_job.data.id))
	await fx.tick_until(func() -> bool: return not begun.is_empty(), 5.0, 0.05)
	assert_eq(begun.slice(0, 1), [&"haul_resource"] as Array[StringName],
		"the first job begun after the load is the restored haul, not a store_inventory sweep")

# --- helpers ------------------------------------------------------------------

func _crew() -> Array[PawnBase]:
	return Global.crew_manager.get_crew()

func _crew_by_id(pawn_id: int) -> PawnBase:
	for pawn: PawnBase in _crew():
		if pawn.pawn_id == pawn_id:
			return pawn
	return null

static func _suit(pawn: PawnBase) -> PawnSuitComponent:
	return pawn.get_component_by_type(PawnSuitComponent) as PawnSuitComponent
