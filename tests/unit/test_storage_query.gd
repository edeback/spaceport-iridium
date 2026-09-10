extends GutTest

## Unit tests for WI-40's storage routing rules (StorageQuery).
##
## The queries themselves read Global.path_manager / Global.world_to_cell and
## so can't be constructed here - but the scoring is where the four copies of
## this logic actually drifted apart (WI-38 A5), and that part is pure. The
## statics are tested directly; the scorers are driven exactly the way the
## real walk drives them, with `best` tracking the last candidate whose
## offer() returned true and -1 standing in for "returned null".

# --- walk simulation ----------------------------------------------------------

## Candidates are (priority, dist) for sinks and (amount, dist) for sources,
## offered in scan order. Returns the winning index, or -1 for no winner.
func _run_sink(candidates: Array[Vector2i]) -> int:
	var scorer := StorageQuery.SinkScorer.new()
	var best: int = -1
	for i: int in candidates.size():
		if scorer.offer(candidates[i].x, candidates[i].y):
			best = i
	return best

func _run_source(candidates: Array[Vector2i], cap: int) -> int:
	var scorer := StorageQuery.SourceScorer.new(cap)
	var best: int = -1
	for i: int in candidates.size():
		if scorer.offer(candidates[i].x, candidates[i].y):
			best = i
	return best

# --- sink_beats ---------------------------------------------------------------

func test_sink_priority_dominates_distance() -> void:
	assert_true(StorageQuery.sink_beats(5, 9999, 1, 0), "higher priority wins from any distance")
	assert_false(StorageQuery.sink_beats(1, 0, 5, 9999), "lower priority loses even when adjacent")

func test_sink_distance_breaks_priority_ties() -> void:
	assert_true(StorageQuery.sink_beats(3, 10, 3, 20), "same priority, nearer wins")
	assert_false(StorageQuery.sink_beats(3, 20, 3, 10), "same priority, farther loses")

func test_sink_full_tie_keeps_the_incumbent() -> void:
	# Strict comparisons on both axes: the first bin scanned holds the slot.
	assert_false(StorageQuery.sink_beats(3, 10, 3, 10), "a dead tie does not displace the incumbent")

func test_sink_handles_negative_priorities() -> void:
	# Deconstruction exports sit at -99; a +1 general bin must still outrank them.
	assert_true(StorageQuery.sink_beats(1, 500, -99, 0), "+1 bin beats a -99 export bin")

# --- source_beats_partial -----------------------------------------------------

func test_source_partial_stock_dominates_distance() -> void:
	assert_true(StorageQuery.source_beats_partial(40, 9999, 5, 0), "more stock wins from any distance")
	assert_false(StorageQuery.source_beats_partial(5, 0, 40, 9999), "less stock loses even when adjacent")

func test_source_partial_distance_breaks_stock_ties() -> void:
	assert_true(StorageQuery.source_beats_partial(10, 4, 10, 25), "same stock, nearer wins")
	assert_false(StorageQuery.source_beats_partial(10, 25, 10, 4), "same stock, farther loses")
	assert_false(StorageQuery.source_beats_partial(10, 4, 10, 4), "a dead tie does not displace the incumbent")

# --- sink walk ----------------------------------------------------------------

func test_sink_empty_candidate_set_returns_nothing() -> void:
	var empty: Array[Vector2i] = []
	assert_eq(_run_sink(empty), -1, "no candidates means no sink")

func test_sink_first_candidate_always_wins_initially() -> void:
	assert_eq(_run_sink([Vector2i(-99, 400)] as Array[Vector2i]), 0, "even a lone -99 bin is the best so far")

func test_sink_picks_highest_priority_then_nearest() -> void:
	# (priority, dist): a far +9 beats a near +1; among the two +9s, the nearer.
	var candidates: Array[Vector2i] = [
		Vector2i(1, 1),
		Vector2i(9, 900),
		Vector2i(9, 100),
		Vector2i(4, 0),
	]
	assert_eq(_run_sink(candidates), 2, "highest priority, nearest among equals")

func test_sink_equal_priority_and_distance_does_not_flip() -> void:
	# Two identical bins: the scan order decides, and it decides the same way
	# every tick - which is what stops a haul oscillating between them.
	var candidates: Array[Vector2i] = [Vector2i(5, 50), Vector2i(5, 50), Vector2i(5, 50)]
	assert_eq(_run_sink(candidates), 0, "the first of several identical bins keeps the slot")

# --- source walk --------------------------------------------------------------

func test_source_empty_candidate_set_returns_nothing() -> void:
	var empty: Array[Vector2i] = []
	assert_eq(_run_source(empty, 10), -1, "no candidates means no source")

func test_source_fills_the_trip_outranks_any_partial() -> void:
	# (amount, dist), cap 10. The 9-unit bin next door loses to a 10-unit bin
	# across the station: one trip beats two.
	var candidates: Array[Vector2i] = [Vector2i(9, 1), Vector2i(10, 5000)]
	assert_eq(_run_source(candidates, 10), 1, "a source that fills the trip wins outright")

func test_source_full_found_first_is_not_displaced_by_a_bigger_partial() -> void:
	var candidates: Array[Vector2i] = [Vector2i(10, 5000), Vector2i(9, 1)]
	assert_eq(_run_source(candidates, 10), 0, "a later partial never unseats a full source")

func test_source_partial_updates_stay_silent_under_a_full_source() -> void:
	# The partial tier keeps improving internally, but the overall winner - the
	# only thing the walk records - must not move.
	var candidates: Array[Vector2i] = [Vector2i(2, 90), Vector2i(20, 0), Vector2i(9, 1), Vector2i(9, 0)]
	assert_eq(_run_source(candidates, 20), 1, "partial improvements below a full source change nothing")

func test_source_picks_nearest_among_full_sources() -> void:
	var candidates: Array[Vector2i] = [Vector2i(50, 900), Vector2i(12, 100), Vector2i(80, 400)]
	assert_eq(_run_source(candidates, 10), 1, "all three fill the trip, nearest wins")

func test_source_falls_back_to_most_stock_then_nearest() -> void:
	# Nothing reaches the cap of 30, so empty the fullest bin - and among two
	# equally-full bins, the nearer one.
	var candidates: Array[Vector2i] = [Vector2i(5, 0), Vector2i(20, 800), Vector2i(20, 300)]
	assert_eq(_run_source(candidates, 30), 2, "most stock, nearest among equals")

func test_source_treats_exactly_cap_as_full() -> void:
	# `available >= trip_cap`, not `>`: a bin holding exactly the trip size
	# fills the trip.
	var candidates: Array[Vector2i] = [Vector2i(25, 0), Vector2i(7, 900)]
	assert_eq(_run_source(candidates, 7), 0, "the cap boundary is inclusive on both")
	assert_eq(_run_source([Vector2i(7, 900), Vector2i(25, 0)] as Array[Vector2i], 7), 1,
		"a nearer full source still displaces a farther one")

# --- sentinel -----------------------------------------------------------------

func test_any_priority_sentinel_sits_below_every_real_priority() -> void:
	# Both filters compare against real bin priorities; the sentinel must never
	# collide with one. -99/+99 are the routing extremes the game actually uses.
	assert_lt(StorageQuery.ANY_PRIORITY, -99, "sentinel is below the lowest routing band")
	assert_lt(StorageQuery.ANY_PRIORITY, 0, "sentinel is not a usable priority")

# --- the qualifying filters ----------------------------------------------------------

func _bin(priority: int) -> StorageComponent:
	var component: StorageComponent = autofree(StorageComponent.new())
	component.include_in_stats = false
	component.priority = priority
	return component

func _resource(id: StringName) -> ResourceData:
	var resource := ResourceData.new()
	resource.id = id
	resource.name = String(id)
	return resource

## The regression. A mining bay's merged bin keeps a `priority` of +1, but its ore
## is OUTPUT and ships at the floor. The push finder compared storerooms against
## the raw +1 - and every storeroom is authored at 0 - so mined ore had nowhere to
## go, and neither did any refinery's product.
func test_a_push_from_an_output_slot_clears_a_storeroom_at_zero() -> void:
	var bay: StorageComponent = _bin(1)
	bay.max_stored = 0
	bay.output_capacity = 80
	var ore: ResourceData = _resource(&"iron_ore")
	bay.add_stored_resource(ore, StorageData.Role.OUTPUT)
	var storeroom: StorageComponent = _bin(0)
	storeroom.allow_any_resource = true
	assert_true(StorageQuery.sink_qualifies(storeroom.import_priority(ore), bay.export_priority(ore)),
		"a storeroom at 0 out-ranks ore shipping at the floor")
	assert_false(StorageQuery.sink_qualifies(storeroom.import_priority(ore), bay.priority),
		"which the bin's raw priority field refuses - the bug, pinned")

## The same rule from the pull side: a forge at +1 may draw iron out of a
## smelter's product bay even though the smelter's own field is also +1.
func test_a_pull_into_an_input_slot_draws_on_a_product_bay() -> void:
	var iron: ResourceData = _resource(&"iron")
	var smelter: StorageComponent = _bin(1)
	smelter.add_stored_resource(iron, StorageData.Role.OUTPUT)
	var forge: StorageComponent = _bin(1)
	forge.add_stored_resource(iron, StorageData.Role.INPUT)
	assert_true(StorageQuery.source_qualifies(smelter.export_priority(iron), forge.import_priority(iron)),
		"product at the floor feeds an ingredient at +1")
	assert_false(StorageQuery.source_qualifies(smelter.priority, forge.import_priority(iron)),
		"where the raw fields tie and the strict filter refuses")

func test_the_filters_are_strict() -> void:
	assert_false(StorageQuery.sink_qualifies(3, 3), "equal priorities would flip-flop")
	assert_false(StorageQuery.source_qualifies(3, 3), "in either direction")
	assert_true(StorageQuery.sink_qualifies(4, 3))
	assert_true(StorageQuery.source_qualifies(2, 3))

func test_any_priority_admits_every_real_priority() -> void:
	for priority: int in [StoresModel.PRIORITY_MIN, 0, StoresModel.PRIORITY_MAX]:
		assert_true(StorageQuery.sink_qualifies(priority, StorageQuery.ANY_PRIORITY),
			"a sweep accepts a sink at %d" % priority)
		assert_true(StorageQuery.source_qualifies(priority, StorageQuery.ANY_PRIORITY),
			"a pile accepts a source at %d" % priority)

## REFUSED on either end disqualifies, and is never read as a number - above all
## not as a sky-high ceiling that would admit every source for a destination that
## no longer takes the resource.
func test_refused_never_qualifies_on_either_end() -> void:
	var refused: int = StorageComponent.REFUSED
	assert_false(StorageQuery.sink_qualifies(refused, StorageQuery.ANY_PRIORITY),
		"a refusing sink, even for a sweep")
	assert_false(StorageQuery.source_qualifies(refused, StorageQuery.ANY_PRIORITY),
		"a refusing source, even for a pile")
	assert_false(StorageQuery.source_qualifies(StoresModel.PRIORITY_MIN, refused),
		"a destination that refuses the resource has no legitimate source")
	assert_false(StorageQuery.sink_qualifies(StoresModel.PRIORITY_MAX, refused),
		"and a source that refuses to ship it has no legitimate sink")
