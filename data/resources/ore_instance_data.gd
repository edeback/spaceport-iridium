class_name OreInstanceData
extends ItemInstanceData

## 0.0 - 1.0, how much of the desired element this particular batch contains.
@export_range(0.0, 1.0, 0.01) var richness: float = 0.5

func get_primary_value() -> float:
	return richness

func merged_with(other: ItemInstanceData, self_weight: float, other_weight: float) -> ItemInstanceData:
	var other_ore := other as OreInstanceData
	if other_ore == null:
		return self
	var merged := OreInstanceData.new()
	var total_weight: float = self_weight + other_weight
	if total_weight <= 0.0:
		merged.richness = richness
	else:
		merged.richness = (richness * self_weight + other_ore.richness * other_weight) / total_weight
	return merged

func get_display_suffix() -> String:
	return "%d%%" % roundi(richness * 100.0)
