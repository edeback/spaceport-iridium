class_name FoodInstanceData
extends ItemInstanceData

## Per-stack food quality (WI-29) - the food analogue of OreInstanceData's
## richness, riding the same has_variance / ItemInstanceData machinery. 0..1:
## better food nourishes more per meal and nudges mood up, worse food the
## reverse. food_type is an optional cosmetic tag (meat/vegetables/slime/...)
## that travels with the stack; v1 stores it but never branches on it.

## Quality assumed for a food stack that carries no instance data: food produced
## before this system existed, trader-bought generic food, debug-spawned stock.
## Mirrors ProcessorComponent.DEFAULT_RICHNESS so every existing save and recipe
## grandfathers in at neutral quality with no migration.
const DEFAULT_QUALITY: float = 0.5

@export_range(0.0, 1.0, 0.01) var quality: float = DEFAULT_QUALITY
@export var food_type: StringName = &""

func get_primary_value() -> float:
	return quality

func merged_with(other: ItemInstanceData, self_weight: float, other_weight: float) -> ItemInstanceData:
	var other_food := other as FoodInstanceData
	if other_food == null:
		return self
	var merged := FoodInstanceData.new()
	# Keep our own food_type on merge: it's cosmetic and blending two tags is
	# meaningless. Coarser merge_tolerance already keeps distinct foods apart.
	merged.food_type = food_type
	var total_weight: float = self_weight + other_weight
	if total_weight <= 0.0:
		merged.quality = quality
	else:
		merged.quality = (quality * self_weight + other_food.quality * other_weight) / total_weight
	return merged

func get_display_suffix() -> String:
	return "%d%%" % roundi(quality * 100.0)

func to_dict() -> Dictionary:
	return {"type": "food", "quality": quality, "food_type": String(food_type)}

# --- pure quality -> effect mappings (WI-29) ----------------------------------
# Static so Job_Eat and the GUT suite share one implementation without needing a
# live SustenanceComponent or Global. Band edges / mult range are passed in by
# the caller (exported on SustenanceComponent) to keep balance numbers in data.

## Nourishment multiplier for a meal of `quality`: lerp(min_mult, max_mult) so a
## good meal fills hunger further per unit eaten and a poor one less.
static func nourishment_mult(quality: float, min_mult: float, max_mult: float) -> float:
	return lerpf(min_mult, max_mult, clampf(quality, 0.0, 1.0))

## Which mood band a meal of `quality` falls in: 1 = good (>= good_band),
## -1 = bad (<= bad_band), 0 = neutral (strictly between). Callers map the sign
## onto the timed good_meal / bad_meal happiness modifiers.
static func meal_mood_band(quality: float, bad_band: float, good_band: float) -> int:
	if quality >= good_band:
		return 1
	if quality <= bad_band:
		return -1
	return 0
