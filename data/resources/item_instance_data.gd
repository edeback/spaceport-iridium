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

## Short, stable tag written into the save as `"type"` and checked on the way back
## (WI-47 M4). It keeps saves human-readable and catches a resource whose
## instance_data_script has been swapped for an incompatible one.
##
## Namespace it like any other mod id: `mymod.purity`, not `purity`.
func type_id() -> StringName:
	return &"generic"

## Save-file form. Subclasses add their own fields; the "type" tag comes from
## type_id() so the two can't drift apart.
func to_dict() -> Dictionary:
	return {"type": String(type_id())}

## Read back what to_dict() wrote. This used to be a hardcoded `match` on the type
## tag inside SaveManager, naming OreInstanceData and FoodInstanceData directly -
## which meant a modded resource with has_variance = true silently lost its
## instance data on save, i.e. lost the entire point of the variance. The factory
## now resolves the script from the owning ResourceData and calls this.
func from_dict(_data: Dictionary) -> void:
	pass
