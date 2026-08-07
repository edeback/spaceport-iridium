class_name RobotDesignation
extends RefCounted

## Numbered display names for robot pawns ("Mining Droid 2"). Robots are built,
## not hired, so nothing ever gave them a pawn_name - and every pawn-listing UI
## (jobs tab, alerts, info panel) falls back to a generic "Crew member" for an
## unnamed pawn, which made two drones indistinguishable from each other.
##
## Numbering is per designation and station-wide, not per bay: a second Mining
## Bay continues at 4, 5, 6 rather than restarting at 1, because the player reads
## one flat list of pawns and two "Mining Droid 1"s in it are exactly the
## ambiguity this exists to remove. Designations are independent of each other -
## a Mining Droid 1 and a Hauling Droid 1 coexist fine.
##
## Pure and set-based so the caller decides where "used" comes from (live robots,
## in practice - see RobotPawnBase._allocate_robot_index). Freed numbers are
## reused: bays rebuild destroyed drones continuously, and a monotonic counter
## would drift to "Mining Droid 214" on a station that never ran more than three.

## Lowest number >= 1 that isn't in `used`. Duplicates and non-positive entries
## (0 = unallocated) are ignored, so callers can pass raw indices unfiltered.
static func next_index(used: PackedInt32Array) -> int:
	var taken: Dictionary[int, bool] = {}
	for index: int in used:
		if index >= 1:
			taken[index] = true
	var candidate: int = 1
	while taken.has(candidate):
		candidate += 1
	return candidate

## "Mining Droid 2". A non-positive index means the robot was never allocated
## one, and the bare designation is a better name than "Mining Droid 0".
static func format_name(designation: String, index: int) -> String:
	if index < 1:
		return designation
	return "%s %d" % [designation, index]
