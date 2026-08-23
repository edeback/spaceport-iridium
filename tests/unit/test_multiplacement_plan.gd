extends GutTest

## Unit tests for the drag-placement plan (MultiplacementPlan) - the rule that
## keeps a click-drag from building an island beside the station. Pure: cells,
## verdicts and geometry go in, a build order comes out. No world, no Global.

const MODULE := WorldManager.StructureLayer.MODULE
const CORRIDOR := WorldManager.StructureLayer.CORRIDOR

# --- fixtures ----------------------------------------------------------------

## Truss: MODULE layer, connects on all four sides, one internal cell. What the
## base module scene authors, and what the docking-bay drag in the bug report used.
func _truss() -> MultiplacementPlan.Placement:
	var placement := MultiplacementPlan.Placement.new()
	placement.connection_points = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
	placement.internal_points = [Vector2i.ZERO]
	placement.connection_layer = MODULE
	placement.provisions.append(MultiplacementPlan.Provision.new(
		MODULE, Vector2i.ZERO, Vector2i.ONE, placement.connection_points, placement.internal_points))
	return placement

## Corridor: sits on the CORRIDOR layer, connects through the MODULE layer, and
## backfills truss under itself. The corridors never touch each other.
func _corridor(with_backfill: bool = true) -> MultiplacementPlan.Placement:
	var placement := MultiplacementPlan.Placement.new()
	placement.connection_points = [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]
	placement.internal_points = [Vector2i.ZERO]
	placement.connection_layer = MODULE
	placement.provisions.append(MultiplacementPlan.Provision.new(
		CORRIDOR, Vector2i.ZERO, Vector2i.ONE, placement.connection_points, placement.internal_points))
	if with_backfill:
		var truss := _truss()
		placement.provisions.append(MultiplacementPlan.Provision.new(
			MODULE, Vector2i.ZERO, Vector2i.ONE, truss.connection_points, truss.internal_points))
	return placement

func _row(start: Vector2i, count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for index: int in count:
		cells.append(start + Vector2i(index, 0))
	return cells

func _flags(count: int, indices: Array[int]) -> Array[bool]:
	var flags: Array[bool] = []
	flags.resize(count)
	for index: int in indices:
		flags[index] = true
	return flags

# --- drag geometry -----------------------------------------------------------

func test_horizontal_drag_ignores_vertical_travel() -> void:
	var cells := MultiplacementPlan.drag_cells(Vector2i(4, 4), Vector2i(7, 9),
		WorldManager.Multiplacement.HORIZONTAL)
	assert_eq(cells.size(), 4, "one cell per column, no rows")
	assert_eq(cells[0], Vector2i(4, 4), "starts at the press cell")
	assert_eq(cells[3], Vector2i(7, 4), "ends under the cursor's column, on the start row")

func test_vertical_drag_ignores_horizontal_travel() -> void:
	var cells := MultiplacementPlan.drag_cells(Vector2i(4, 4), Vector2i(9, 6),
		WorldManager.Multiplacement.VERTICAL)
	assert_eq(cells, [Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6)] as Array[Vector2i],
		"one column, top to bottom")

func test_drag_runs_backwards_from_the_press_cell() -> void:
	var cells := MultiplacementPlan.drag_cells(Vector2i(4, 4), Vector2i(1, 4),
		WorldManager.Multiplacement.HORIZONTAL)
	assert_eq(cells[0], Vector2i(4, 4), "still starts at the press cell")
	assert_eq(cells[3], Vector2i(1, 4), "and walks left to the cursor")

func test_both_axes_fill_the_rectangle_row_by_row() -> void:
	var cells := MultiplacementPlan.drag_cells(Vector2i.ZERO, Vector2i(2, 1),
		WorldManager.Multiplacement.BOTH)
	assert_eq(cells.size(), 6, "3 wide by 2 tall")
	assert_eq(cells[2], Vector2i(2, 0), "first row finishes before the second starts")
	assert_eq(cells[3], Vector2i(0, 1), "second row starts back at the left")

func test_a_drag_of_one_cell_is_one_cell() -> void:
	var cells := MultiplacementPlan.drag_cells(Vector2i(3, 3), Vector2i(3, 3),
		WorldManager.Multiplacement.BOTH)
	assert_eq(cells, [Vector2i(3, 3)] as Array[Vector2i], "a click that never moved")

# --- what links to what ------------------------------------------------------

func test_truss_links_to_its_four_neighbours() -> void:
	var links := MultiplacementPlan.link_offsets(_truss())
	assert_eq(links.size(), 4, "one per connection point")
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		assert_true(links.has(offset), "truss links to " + str(offset))

func test_corridors_link_through_the_truss_they_backfill() -> void:
	var links := MultiplacementPlan.link_offsets(_corridor())
	assert_eq(links.size(), 2, "left and right only - the corridor drag is horizontal")
	assert_true(links.has(Vector2i(1, 0)) and links.has(Vector2i(-1, 0)),
		"a corridor is held up by the truss under the next corridor")

func test_a_module_that_backfills_nothing_links_to_nothing() -> void:
	# Same corridor, minus the truss it lays: its own layer is not the layer its
	# connection test reads, so a second copy is invisible to the first.
	var links := MultiplacementPlan.link_offsets(_corridor(false))
	assert_eq(links.size(), 0, "nothing of it lands on its own connection layer")

func test_own_cell_is_not_a_link() -> void:
	# The corridor's middle connection point is its own cell (that is how it
	# connects to the module underneath), and must not read as a neighbour.
	assert_false(MultiplacementPlan.link_offsets(_corridor()).has(Vector2i.ZERO),
		"a module does not hold itself up")

# --- the plan ----------------------------------------------------------------

func test_a_clear_line_from_an_anchor_builds_whole() -> void:
	var cells := _row(Vector2i(10, 8), 5)
	var order := MultiplacementPlan.resolve(cells, _flags(5, []), _flags(5, [0]),
		MultiplacementPlan.link_offsets(_truss()))
	assert_eq(order.size(), 5, "every cell chains back to the anchored one")
	assert_eq(order[0], 0, "and the anchored one goes down first")

func test_a_blocked_cell_cuts_everything_past_it() -> void:
	# The bug: drag truss rightwards past the docking bay. Cell 2 is over the bay
	# and refused; 3 and 4 used to be built anyway, floating.
	var cells := _row(Vector2i(10, 8), 5)
	var order := MultiplacementPlan.resolve(cells, _flags(5, [2]), _flags(5, [0]),
		MultiplacementPlan.link_offsets(_truss()))
	assert_eq(Array(order), [0, 1], "only the side still attached to the station")

func test_a_cell_past_the_cut_that_touches_the_station_still_builds() -> void:
	# Same line, but cell 4 happens to touch built structure of its own. It is
	# not an island, so refusing it would be wrong.
	var cells := _row(Vector2i(10, 8), 5)
	var order := MultiplacementPlan.resolve(cells, _flags(5, [2]), _flags(5, [0, 4]),
		MultiplacementPlan.link_offsets(_truss()))
	assert_eq(Array(order), [0, 4, 1, 3], "both anchors first, then what hangs off them")

func test_a_line_touching_nothing_builds_nothing() -> void:
	var cells := _row(Vector2i(40, 40), 4)
	var order := MultiplacementPlan.resolve(cells, _flags(4, []), _flags(4, []),
		MultiplacementPlan.link_offsets(_truss()))
	assert_eq(order.size(), 0, "a drag out in empty space places nothing at all")

func test_a_blocked_anchor_does_not_seed_the_line() -> void:
	var cells := _row(Vector2i(10, 8), 3)
	var order := MultiplacementPlan.resolve(cells, _flags(3, [0]), _flags(3, [0]),
		MultiplacementPlan.link_offsets(_truss()))
	assert_eq(order.size(), 0, "the only cell touching the station is one the world refused")

func test_the_order_starts_at_the_anchor_even_when_it_is_last() -> void:
	# Dragging *towards* the station: the near end of the drag is the far end of
	# the chain. Building in drag order here would strand the whole line if the
	# credits ran out partway, which is the same island by another route.
	var cells := _row(Vector2i(10, 8), 4)
	var order := MultiplacementPlan.resolve(cells, _flags(4, []), _flags(4, [3]),
		MultiplacementPlan.link_offsets(_truss()))
	assert_eq(Array(order), [3, 2, 1, 0], "built back towards the cursor from the station")

func test_every_prefix_of_the_order_is_connected() -> void:
	# The property the order exists for: a placement that fails partway (no
	# credits left) truncates the chain rather than scattering it.
	var cells := _row(Vector2i(10, 8), 6)
	var links := MultiplacementPlan.link_offsets(_truss())
	var order := MultiplacementPlan.resolve(cells, _flags(6, []), _flags(6, [4]), links)
	var placed: Array[Vector2i] = []
	for index: int in order:
		var touches: bool = index == 4
		for offset: Vector2i in links:
			if placed.has(cells[index] + offset):
				touches = true
		assert_true(touches, "cell " + str(cells[index]) + " lands beside something already there")
		placed.append(cells[index])

func test_a_rectangle_routes_around_a_blocked_cell() -> void:
	# Truss drags in both axes, so a single blocked cell in the middle of a block
	# cuts nothing off - the chain goes around it.
	var cells := MultiplacementPlan.drag_cells(Vector2i.ZERO, Vector2i(2, 2),
		WorldManager.Multiplacement.BOTH)
	var order := MultiplacementPlan.resolve(cells, _flags(9, [4]), _flags(9, [0]),
		MultiplacementPlan.link_offsets(_truss()))
	assert_eq(order.size(), 8, "everything but the blocked middle")

func test_a_blocked_column_cuts_the_far_side_of_a_rectangle() -> void:
	# 3x3 with the whole middle column refused: the right column is an island.
	var cells := MultiplacementPlan.drag_cells(Vector2i.ZERO, Vector2i(2, 2),
		WorldManager.Multiplacement.BOTH)
	var order := MultiplacementPlan.resolve(cells, _flags(9, [1, 4, 7]), _flags(9, [0]),
		MultiplacementPlan.link_offsets(_truss()))
	assert_eq(Array(order), [0, 3, 6], "only the anchored column")

func test_corridors_chain_along_the_drag() -> void:
	# A corridor line run out into open space is legitimate - each corridor lays
	# truss under itself, and that truss is what the next corridor connects to.
	var cells := _row(Vector2i(10, 8), 4)
	var order := MultiplacementPlan.resolve(cells, _flags(4, []), _flags(4, [0]),
		MultiplacementPlan.link_offsets(_corridor()))
	assert_eq(order.size(), 4, "the whole corridor spur builds")

func test_mismatched_verdicts_are_refused_rather_than_guessed() -> void:
	var cells := _row(Vector2i.ZERO, 3)
	var order := MultiplacementPlan.resolve(cells, _flags(2, []), _flags(3, [0]),
		MultiplacementPlan.link_offsets(_truss()))
	assert_eq(order.size(), 0, "a caller that lost count builds nothing")
	assert_push_error("one verdict per candidate", "and says so rather than failing quietly")
