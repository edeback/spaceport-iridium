extends GutTest

## Unit tests for ModuleQueue (scripts/utility/module_queue.gd) - the binary
## min-heap behind ModuleGraph's pathfinding frontier.
##
## Untested until WI-68, which is how a leak lived in it: it was a bare Object,
## allocated once per pathfinding query and never freed (F1). The last test pins
## that it is now released like any other RefCounted.
##
## Vertices are bare ModuleGraphVertex instances; the queue only ever hands them
## back, so they need no node or graph behind them.

func _vertex() -> ModuleGraphVertex:
	return ModuleGraphVertex.new()

## Inserts one fresh vertex per cost and returns them in insertion order, so a
## test can map each extracted vertex back to the cost it went in with.
func _fill(queue: ModuleQueue, costs: Array[float]) -> Array[ModuleGraphVertex]:
	var out: Array[ModuleGraphVertex] = []
	for cost: float in costs:
		var vertex: ModuleGraphVertex = _vertex()
		queue.insert(vertex, cost)
		out.append(vertex)
	return out

func _drain(queue: ModuleQueue) -> Array[ModuleGraphVertex]:
	var out: Array[ModuleGraphVertex] = []
	while not queue.is_empty():
		out.append(queue.extract())
	return out

# --- ordering ------------------------------------------------------------------

func test_extracts_in_ascending_cost_order() -> void:
	var queue := ModuleQueue.new()
	var costs: Array[float] = [5.0, 1.0, 4.0, 2.0, 3.0, 0.5, 9.0, 7.0]
	var inserted: Array[ModuleGraphVertex] = _fill(queue, costs)
	var drained: Array[ModuleGraphVertex] = _drain(queue)
	assert_eq(drained.size(), costs.size(), "every inserted vertex comes back out")
	var previous: float = -INF
	for vertex: ModuleGraphVertex in drained:
		var cost: float = costs[inserted.find(vertex)]
		assert_true(cost >= previous, "cost %.1f came out after %.1f" % [cost, previous])
		previous = cost

func test_equal_costs_each_come_out_exactly_once() -> void:
	var queue := ModuleQueue.new()
	var costs: Array[float] = [2.0, 2.0, 1.0, 2.0, 3.0, 1.0]
	var inserted: Array[ModuleGraphVertex] = _fill(queue, costs)
	var drained: Array[ModuleGraphVertex] = _drain(queue)
	for vertex: ModuleGraphVertex in inserted:
		assert_eq(drained.count(vertex), 1, "a tied vertex is neither lost nor duplicated")

func test_interleaved_insert_and_extract_keeps_the_minimum_on_top() -> void:
	# A* interleaves the two, so the heap has to stay valid between them.
	var queue := ModuleQueue.new()
	var costs: Array[float] = [4.0, 6.0, 5.0]
	var inserted: Array[ModuleGraphVertex] = _fill(queue, costs)
	assert_eq(queue.extract(), inserted[0], "4 is the cheapest of 4/6/5")
	var cheaper: ModuleGraphVertex = _vertex()
	queue.insert(cheaper, 1.0)
	assert_eq(queue.extract(), cheaper, "a later, cheaper insert jumps the queue")
	assert_eq(queue.extract(), inserted[2], "then 5")
	assert_eq(queue.extract(), inserted[1], "then 6")

# --- emptiness -----------------------------------------------------------------

func test_a_new_queue_is_empty() -> void:
	assert_true(ModuleQueue.new().is_empty())

func test_extracting_from_an_empty_queue_returns_null() -> void:
	assert_null(ModuleQueue.new().extract(), "an empty frontier yields null, not an error")

func test_a_drained_queue_is_empty_and_returns_null() -> void:
	var queue := ModuleQueue.new()
	var costs: Array[float] = [1.0, 2.0]
	_fill(queue, costs)
	_drain(queue)
	assert_true(queue.is_empty(), "draining leaves it empty")
	assert_null(queue.extract(), "and extracting again is still safe")

# --- lifetime (WI-68 F1) ---------------------------------------------------------

func test_a_dropped_queue_is_freed() -> void:
	# ModuleGraph builds one per pathfinding query and simply lets it go out of
	# scope. As an Object that leaked on every query; as a RefCounted it must be
	# gone the moment the last reference is.
	var queue := ModuleQueue.new()
	queue.insert(_vertex(), 1.0)
	var ref: WeakRef = weakref(queue)
	queue = null
	assert_null(ref.get_ref(), "a queue nothing references any more has been freed")
