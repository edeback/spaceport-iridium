class_name WeightedPick
extends RefCounted

## One implementation of "roll a weighted choice" (WI-47). Shared by ShipData's
## raider variants and PawnData's pawn kinds, which both select from a scanned
## pool by weight, and by anything that follows them.
##
## Pure and index-based rather than generic, because GDScript has no generics and
## an Array[Variant] API would lose the callers' typing. The subtle part is the
## boundaries - a roll of exactly 0.0 (which randf() does return) and a roll at or
## past 1.0 (which floating-point accumulation can produce) must both land on a
## real entry - so it is worth having in exactly one place.

## Index into `weights` for `roll` in [0, 1), or -1 when nothing is selectable
## (empty, or every weight <= 0). Negative weights count as zero.
static func index_for(weights: PackedFloat32Array, roll: float) -> int:
	if weights.is_empty():
		return -1
	var total: float = 0.0
	for weight: float in weights:
		total += maxf(weight, 0.0)
	if total <= 0.0:
		return -1
	# Clamped just below 1.0 so a roll of exactly 1.0 can't fall past the last
	# bucket and return -1.
	var target: float = clampf(roll, 0.0, 0.999999) * total
	var running: float = 0.0
	for index: int in weights.size():
		running += maxf(weights[index], 0.0)
		if target < running:
			return index
	# Only reachable through float drift in the accumulation above; the last
	# positive-weight entry is the honest answer.
	for index: int in range(weights.size() - 1, -1, -1):
		if weights[index] > 0.0:
			return index
	return -1
