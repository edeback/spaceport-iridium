class_name SpaceGeometry
extends RefCounted

## Pure geometry for placing and moving things in the space around the station
## (WI-61). All static, no Global, no SignalBus, no nodes - callers hand in the
## module positions they already have, so this unit-tests directly.
##
## This started as three private functions inside [EventEffectSpawnSalvage],
## which needed "somewhere just outside the station" to drop salvage piles.
## Comets need the same answer for a different reason - where a crossing body
## enters and where it has finally cleared the far side - and two independent
## definitions of "outside the station" would drift the first time either was
## tuned.
##
## Deliberately NOT included here: gathering the module positions. That needs the
## SceneTree and Global.cell_to_world, and pulling either in would cost this file
## the property that makes it testable. The two callers each do their own
## five-line gather; that duplication is the price of purity and is cheaper than
## the alternative.

## One rolled crossing: where the body appears, which way it travels, and how far
## it goes before it has definitively cleared the station.
class Crossing extends RefCounted:
	var entry: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var distance: float = 0.0

## World-space AABB spanning every position handed in. An empty list gives a
## zero-size rect at the origin; every function here treats that as "the station
## has no extent yet" rather than as an error, so a caller with no modules gets
## sane numbers instead of a crash - though [AsteroidManager] declines to spawn
## a crossing body in that state anyway, since there is nothing to cross.
static func station_bounds(positions: Array[Vector2]) -> Rect2:
	if positions.is_empty():
		return Rect2()
	var bounds := Rect2(positions[0], Vector2.ZERO)
	for i: int in range(1, positions.size()):
		bounds = bounds.expand(positions[i])
	return bounds

## The box's support radius along `direction`: how far from the centre its
## boundary lies on that heading. This is the exact expression the salvage
## effect used inline, kept intact so its spawn distances do not shift.
static func half_extent(bounds: Rect2, direction: Vector2) -> float:
	return absf(direction.x) * bounds.size.x * 0.5 + absf(direction.y) * bounds.size.y * 0.5

## A point `margin` px outside the box, on the `direction` heading from its
## centre. The salvage effect's `_roll_position` rule, now shared.
static func outward_point(bounds: Rect2, direction: Vector2, margin: float) -> Vector2:
	return bounds.get_center() + direction * (half_extent(bounds, direction) + margin)

## Rolls one straight crossing of the station.
##
## `angle` picks the side it comes in from; `lateral` (-1 … 1) slides the point
## it aims at sideways across the station, so a value of 0 cuts through the
## centre and ±1 grazes the edge. A body that always bisected the station would
## read as scripted within two arrivals, which is the whole reason this parameter
## exists.
##
## `distance` is measured from `entry` and is deliberately generous: it runs to
## the aim point, then far enough along the travel heading to clear the box from
## there, then `exit_margin` beyond. Overshooting costs a few seconds of a body
## drifting off-screen; undershooting despawns it in front of the player.
static func crossing(bounds: Rect2, angle: float, lateral: float,
		entry_margin: float, exit_margin: float) -> Crossing:
	var result := Crossing.new()
	var inbound: Vector2 = Vector2.from_angle(angle)
	var centre: Vector2 = bounds.get_center()
	result.entry = outward_point(bounds, inbound, entry_margin)
	var across: Vector2 = inbound.orthogonal()
	var aim: Vector2 = centre + across * (lateral * half_extent(bounds, across))
	var to_aim: Vector2 = aim - result.entry
	# Degenerate only if the station has no extent AND both margins are zero, in
	# which case entry, centre and aim are the same point. Fall back to straight
	# through, so a caller can never end up with a zero direction.
	result.direction = to_aim.normalized() if to_aim.length() > 0.001 else -inbound
	# From `aim`, the centre may still be ahead of us (when aim sits on the near
	# side); that leg plus the box radius on this heading clears the far face.
	# Clamped at zero because once we are past the centre the box radius alone is
	# already enough.
	var to_centre_ahead: float = maxf((centre - aim).dot(result.direction), 0.0)
	result.distance = to_aim.length() + to_centre_ahead \
			+ half_extent(bounds, result.direction) + exit_margin
	return result
