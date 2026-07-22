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

## Hysteresis state transition for one bubble. Offline emitters only re-engage
## once charge climbs back to `reengage_fraction` * capacity; online emitters go
## offline the moment they hit empty.
static func next_online(was_online: bool, charge: float, capacity: float, reengage_fraction: float) -> bool:
	if charge <= 0.0:
		return false
	if was_online:
		return true
	return charge >= capacity * reengage_fraction
