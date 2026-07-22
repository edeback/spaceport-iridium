extends GutTest

## Unit tests for WI-32 pirate targeting geometry: the pure RaidTargeting grid
## ray-march. The point of the march is that raiders hit the FIRST (exposed) cell
## on the fire line and never shoot interior modules through the hull, so these
## verify exactly that, plus the cell mapping and the empty-line sentinel. No
## Global / WorldManager - the occupancy check is a plain callable.

const CELL := Vector2i(64, 64)

func _occupied(cells: Dictionary) -> Callable:
	return func(c: Vector2i) -> bool: return cells.has(c)

func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL.x + CELL.x / 2, cell.y * CELL.y + CELL.y / 2)

func test_to_cell_matches_floor_division() -> void:
	assert_eq(RaidTargeting.to_cell(Vector2(70.0, -10.0), CELL), Vector2i(1, -1),
		"floor-divides like Global.world_to_cell")
	assert_eq(RaidTargeting.to_cell(Vector2(0.0, 0.0), CELL), Vector2i(0, 0), "origin cell")

func test_returns_first_occupied_cell_on_the_line() -> void:
	# Two occupied cells on the same row; the march from the left must return the
	# NEAR one - the exposed hull - not the far one behind it.
	var cells := {Vector2i(2, 0): true, Vector2i(4, 0): true}
	var hit: Vector2i = RaidTargeting.first_occupied_cell(
		_center(Vector2i(-5, 0)), _center(Vector2i(6, 0)), CELL, _occupied(cells))
	assert_eq(hit, Vector2i(2, 0), "nearest occupied cell on the line wins")

func test_does_not_shoot_through_the_hull() -> void:
	# A solid outer hull cell shields a valuable interior cell directly behind it.
	var cells := {Vector2i(0, 0): true, Vector2i(3, 0): true}
	var hit: Vector2i = RaidTargeting.first_occupied_cell(
		_center(Vector2i(-4, 0)), _center(Vector2i(3, 0)), CELL, _occupied(cells))
	assert_eq(hit, Vector2i(0, 0), "hits the hull, never the interior behind it")

func test_empty_line_returns_none() -> void:
	var hit: Vector2i = RaidTargeting.first_occupied_cell(
		_center(Vector2i(-4, 0)), _center(Vector2i(4, 0)), CELL, _occupied({}))
	assert_eq(hit, RaidTargeting.NONE, "no occupied cell -> NONE sentinel")

func test_diagonal_line_finds_a_target() -> void:
	var cells := {Vector2i(2, 2): true}
	var hit: Vector2i = RaidTargeting.first_occupied_cell(
		_center(Vector2i(0, 0)), _center(Vector2i(4, 4)), CELL, _occupied(cells))
	assert_eq(hit, Vector2i(2, 2), "diagonal march lands on the occupied cell")

func test_degenerate_zero_length_line() -> void:
	var on_cell: Vector2i = RaidTargeting.first_occupied_cell(
		_center(Vector2i(1, 1)), _center(Vector2i(1, 1)), CELL, _occupied({Vector2i(1, 1): true}))
	assert_eq(on_cell, Vector2i(1, 1), "from==to on an occupied cell returns it")
	var off_cell: Vector2i = RaidTargeting.first_occupied_cell(
		_center(Vector2i(1, 1)), _center(Vector2i(1, 1)), CELL, _occupied({}))
	assert_eq(off_cell, RaidTargeting.NONE, "from==to on empty space -> NONE")
