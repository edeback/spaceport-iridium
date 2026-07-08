class_name ItemInstanceData
extends Resource

## Base class for optional per-stack variant data (ore richness, food
## quality, etc). Resources with no variance never create one of these - a
## stack's instance_data stays null and everything behaves exactly like a
## plain int count.
##
## Subclass this per resource family (see OreInstanceData for an example) and
## override get_primary_value() / merged_with() so ResourceStackContainer can
## decide when two stacks are close enough to combine, and pick a withdrawal
## order (best/worst first).

## Value used to decide whether two stacks are within a resource's
## merge_tolerance of each other, and as the sort key for "best/worst first"
## withdrawal strategies. Subclasses define their own scale (e.g. 0..1 for
## richness) - just be consistent within one resource type.
func get_primary_value() -> float:
	return 0.0

## Return a new ItemInstanceData representing self and other combined,
## weighted by how many units each stack has. Called when two stacks merge.
func merged_with(_other: ItemInstanceData, _self_weight: float, _other_weight: float) -> ItemInstanceData:
	return self

## Optional short label for UI (e.g. "78%", "Rich"). Default: nothing shown.
func get_display_suffix() -> String:
	return ""
