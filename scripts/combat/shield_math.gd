class_name ShieldMath
extends RefCounted

## Pure shield-absorption math (WI-32). Two decisions live here, both kept free
## of live nodes so they unit-test directly (tests/unit/test_shield_math.gd):
##
##  - select_absorber(): which shield eats an incoming hit. Among the online
##    bubbles that COVER the impact point (impact within radius), the one with
##    the most charge wins - a deterministic, documented overlap rule. A bubble
##    absorbs even when its charge is less than the hit (it's overwhelmed, drops
##    to empty, and goes offline); coverage + online is all selection needs.
##
##  - next_online(): the capacitor's hysteresis. A bubble that hits empty goes
##    offline and stays offline until it recharges past a re-engage fraction of
##    capacity, so a barely-charged emitter doesn't flicker on for one hit and
##    collapse again.

## A shield bubble snapshot for selection. Plain fields, no node coupling.
class Bubble:
	extends RefCounted
	var center: Vector2
	var radius: float
	var charge: float
	var online: bool

	func _init(p_center: Vector2, p_radius: float, p_charge: float, p_online: bool) -> void:
		center = p_center
		radius = p_radius
		charge = p_charge
		online = p_online

## Index into `bubbles` of the shield that should absorb a hit at `impact`, or
## -1 if none is online AND covering (the hit then lands on the module). Ties on
## charge resolve to the earliest index for determinism.
static func select_absorber(bubbles: Array, impact: Vector2) -> int:
	var best: int = -1
	var best_charge: float = 0.0
	for i: int in bubbles.size():
		var bubble: Bubble = bubbles[i]
		if not bubble.online or bubble.charge <= 0.0:
			continue
		if impact.distance_squared_to(bubble.center) > bubble.radius * bubble.radius:
			continue
		if best == -1 or bubble.charge > best_charge:
			best = i
			best_charge = bubble.charge
	return best

## Parametric t in [0,1] where the segment from->to first crosses into the
## circle, or -1 if it never does. Used to terminate an absorbed laser beam on
## the shield bubble's surface instead of at the module behind it. For our case
## `from` (the ship) is outside and `to` (the module) is inside, so this is the
## single entry crossing.
static func segment_circle_entry(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	var d: Vector2 = to - from
	var a: float = d.dot(d)
	if a <= 0.0:
		return -1.0
	var f: Vector2 = from - center
	var b: float = 2.0 * f.dot(d)
	var c: float = f.dot(f) - radius * radius
	var disc: float = b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var sq: float = sqrt(disc)
	var t_entry: float = (-b - sq) / (2.0 * a)
	if t_entry >= 0.0 and t_entry <= 1.0:
		return t_entry
	var t_exit: float = (-b + sq) / (2.0 * a)
	if t_exit >= 0.0 and t_exit <= 1.0:
		return t_exit
	return -1.0

## Hysteresis state transition for one bubble. Offline emitters only re-engage
## once charge climbs back to `reengage_fraction` * capacity; online emitters go
## offline the moment they hit empty.
static func next_online(was_online: bool, charge: float, capacity: float, reengage_fraction: float) -> bool:
	if charge <= 0.0:
		return false
	if was_online:
		return true
	return charge >= capacity * reengage_fraction
