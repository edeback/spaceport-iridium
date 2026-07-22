class_name RaidTargeting
extends RefCounted

## Pure grid ray-march for pirate targeting (WI-32). Steps from `from` toward
## `to` in world space, sampling one grid cell per step, and returns the first
## cell for which `is_occupied` reports true - the exposed hull cell along the
## fire line, so raiders never shoot interior modules through the hull. Returns
## NONE when the line reaches `to` without hitting anything occupied.
##
## Deliberately free of Global / WorldManager: PirateShip wraps it with the real
## per-layer cell lookup, but the geometry unit-tests against a plain callable
## (see tests/unit/test_raid_targeting.gd).

## Sentinel for "no occupied cell on the line" - a cell no station ever occupies.
const NONE := Vector2i(-2147483648, -2147483648)

## `is_occupied`: Callable(cell: Vector2i) -> bool. `cell_size` matches
## Global.CELL_SIZE; cells are floor-divided exactly as Global.world_to_cell
## does, so a returned cell is directly usable as a WorldManager map key.
static func first_occupied_cell(from: Vector2, to: Vector2, cell_size: Vector2i, is_occupied: Callable) -> Vector2i:
	var delta: Vector2 = to - from
	var distance: float = delta.length()
	if distance <= 0.0:
		var here: Vector2i = to_cell(from, cell_size)
		return here if is_occupied.call(here) else NONE
	# Half a cell per step never skips a cell along an axis-ish line; diagonal
	# corner-clipping is acceptable for v1 (the beam is a fat visual anyway).
	var step_len: float = maxf(mini(cell_size.x, cell_size.y) * 0.5, 1.0)
	var steps: int = int(ceil(distance / step_len))
	var last_cell: Vector2i = NONE
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		var point: Vector2 = from + delta * t
		var cell: Vector2i = to_cell(point, cell_size)
		if cell == last_cell:
			continue
		last_cell = cell
		if is_occupied.call(cell):
			return cell
	return NONE

static func to_cell(point: Vector2, cell_size: Vector2i) -> Vector2i:
	return Vector2i(floori(point.x / float(cell_size.x)), floori(point.y / float(cell_size.y)))
