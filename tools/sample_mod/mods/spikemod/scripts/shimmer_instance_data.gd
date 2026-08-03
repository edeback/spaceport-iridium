class_name SpikeShimmerData
extends ItemInstanceData

## M9 spike: a mod script that extends a VANILLA class_name (ItemInstanceData).
## The whole modding design rests on this compiling inside an exported build,
## where vanilla class names are baked into the pck's class cache but this
## script's own class_name is not.
##
## This is M4's use case too - a modded resource with has_variance = true needs
## its own ItemInstanceData subclass or the variance is meaningless.
##
## `class_name` is DECLARED here but never REFERENCED, not even by this script
## itself: the first spike run proved a self-reference is a hard compile error
## ("Identifier not found: SpikeShimmerData"). get_script() is the substitute.

@export_range(0.0, 1.0, 0.01) var shimmer: float = 0.5

func get_primary_value() -> float:
	return shimmer

func merged_with(other: ItemInstanceData, self_weight: float, other_weight: float) -> ItemInstanceData:
	# Would be `other as SpikeShimmerData` in a vanilla subclass. A mod cannot
	# name its own type, so identity is a script comparison instead.
	if other == null or other.get_script() != get_script():
		return self
	var merged: ItemInstanceData = spawn_like_me()
	var total_weight: float = self_weight + other_weight
	if total_weight <= 0.0:
		merged.set(&"shimmer", shimmer)
	else:
		var other_shimmer: float = float(other.get(&"shimmer"))
		merged.set(&"shimmer", (shimmer * self_weight + other_shimmer * other_weight) / total_weight)
	return merged

## The class_name-free way for a mod script to make another of itself.
func spawn_like_me() -> ItemInstanceData:
	var own_script := get_script() as GDScript
	return own_script.new() as ItemInstanceData

func get_display_suffix() -> String:
	return "%d%% shimmer" % roundi(shimmer * 100.0)

## WI-47 M4: the save's `"type"` tag comes from here, and the factory checks it
## against whatever instance_data_script the resource currently declares.
func type_id() -> StringName:
	return &"spikemod.shimmer"

func to_dict() -> Dictionary:
	return {"type": String(type_id()), "shimmer": shimmer}

## The other half of M4 - reading the block back is the subclass's own job now,
## rather than a hardcoded `match` on the type tag inside SaveManager.
func from_dict(data: Dictionary) -> void:
	shimmer = float(data.get("shimmer", 0.5))
