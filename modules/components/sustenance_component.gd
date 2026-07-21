class_name SustenanceComponent
extends ComponentBase

@export var storage_bay: StorageComponent
@export var sustenance_max: int = 500
@export var sustenance_available: int = 0
@export var sustenance_per_food: int = 100
@export var sustenance_resource: ResourceData

## Food quality (WI-29). Withdrawn food melts into the sustenance pool, so its
## quality melts in too: pool_quality is the amount-weighted average of the food
## currently pooled here. Job_Eat reads it as the quality of the meal it serves.
## Only meaningful while sustenance_available > 0 (reset to DEFAULT on empty).
const DEFAULT_QUALITY: float = FoodInstanceData.DEFAULT_QUALITY
var pool_quality: float = DEFAULT_QUALITY

## Eating balance (WI-29), read by Job_Eat off the component it ate from. Kept
## here (data-tunable) rather than as code constants. Nourishment scales
## lerp(min..max) with quality; a meal at/above good_meal_band grants a timed
## happiness bonus, at/below bad_meal_band a malus, between = neutral.
@export_group("Food Quality")
@export var min_nourish_mult: float = 0.7
@export var max_nourish_mult: float = 1.3
@export_range(0.0, 1.0, 0.01) var good_meal_band: float = 0.7
@export_range(0.0, 1.0, 0.01) var bad_meal_band: float = 0.3
@export var good_meal_mood: float = 0.08
@export var bad_meal_mood: float = -0.08
@export var meal_mood_duration_hours: float = 8.0
@export_group("")

var override_ui: bool = false

signal sustenance_stored_changed(new_amount: int)

func _ready() -> void:
	super()

func ready_preview() -> void:
	override_ui = false
	set_process(false)

func ready_blueprint() -> void:
	override_ui = false
	set_process(false)

func ready_constructed() -> void:
	override_ui = true
	add_to_group("sustenance_component")
	set_process(true)

func _process(delta: float) -> void:
	if Global.time_manager.scale(delta) <= 0.0:
		return
	if sustenance_available <= sustenance_max - sustenance_per_food:
		# Stack-aware withdraw (WI-29) so the food's quality comes along; blend it
		# into the pool amount-weighted before bumping the count.
		var stacks: Array[ResourceStack] = storage_bay.withdraw_stacks(sustenance_resource, 1)
		if not stacks.is_empty():
			var added_quality: float = _stacks_quality(stacks)
			var prev: int = sustenance_available
			var added: int = sustenance_per_food
			pool_quality = (pool_quality * prev + added_quality * added) / float(prev + added)
			sustenance_available += added
			sustenance_stored_changed.emit(sustenance_available)

## Amount-weighted average quality of the withdrawn stacks; food without instance
## data reads as DEFAULT_QUALITY (grandfathered / trader-bought / debug stock).
func _stacks_quality(stacks: Array[ResourceStack]) -> float:
	var total: int = 0
	var weighted: float = 0.0
	for stack: ResourceStack in stacks:
		var q: float = stack.instance_data.get_primary_value() if stack.instance_data != null else DEFAULT_QUALITY
		weighted += q * stack.amount
		total += stack.amount
	return weighted / total if total > 0 else DEFAULT_QUALITY

## Returns {"amount": units actually consumed, "quality": their quality}. Quality
## is snapshotted before any empty-pool reset, so the caller always gets the
## quality of the food actually eaten. Returned explicitly (rather than the caller
## re-reading pool_quality) so this stays correct if the pool ever stops being a
## uniform average - e.g. FIFO by stack rather than a blended pool. Today the pool
## is uniform, so consuming leaves the average unchanged except when it empties.
func consume_sustenance(amount: int) -> Dictionary:
	var amount_to_consume := maxi(mini(amount, sustenance_available), 0)
	var consumed_quality: float = pool_quality
	sustenance_available -= amount_to_consume
	if sustenance_available <= 0:
		pool_quality = DEFAULT_QUALITY
	sustenance_stored_changed.emit(sustenance_available)
	return {"amount": amount_to_consume, "quality": consumed_quality}

# --- persistence (WI-29) ------------------------------------------------------
# The pooled amount AND its quality round-trip. Pre-WI-29 saves have neither key;
# the module then keeps its export default (empty pool at DEFAULT quality) and
# refills from the saved storage bay, exactly as before this component saved.

func get_save_data() -> Dictionary:
	return {"available": sustenance_available, "quality": pool_quality}

func load_save_data(data: Dictionary) -> void:
	sustenance_available = int(data.get("available", sustenance_available))
	pool_quality = float(data.get("quality", DEFAULT_QUALITY))
	sustenance_stored_changed.emit(sustenance_available)

func has_ui() -> bool:
	return override_ui

func get_ui() -> ModuleComponentUI:
	var ui: UISustenanceComponent = ui_info_panel_element.instantiate() as UISustenanceComponent
	ui.set_sustenance_component(self)
	return ui
