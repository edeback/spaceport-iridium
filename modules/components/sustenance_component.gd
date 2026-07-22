class_name SustenanceComponent
extends ComponentBase

@export var storage_bay: StorageComponent
@export var sustenance_max: int = 500
@export var sustenance_available: int = 0
@export var sustenance_per_food: int = 100
@export var sustenance_resource: ResourceData

## --- visitor dining (WI-33) --------------------------------------------------
## Credits a visitor pays for a meal here (wallet -> station income "dining",
## clamped to the wallet). Crew eat free; only visitors are billed.
@export var visitor_meal_price: int = 6
## Crew get served first when stock is low: a visitor may only eat while the pool
## is ABOVE this reserve, so paying guests can't starve the crew (the paid meal is
## a surplus product). Crew ignore the reserve entirely.
@export var crew_priority_reserve: int = 120

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
	add_to_group(Groups.SUSTENANCE_COMPONENT)
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
## Whether this module will serve `pawn` right now (WI-33). Crew are served
## whenever there's any food; a visitor is served only while the pool sits above
## the crew-priority reserve, so guests never eat the crew's last rations.
func can_serve(pawn: PawnBase) -> bool:
	if sustenance_available <= 0:
		return false
	if pawn != null and pawn.is_visitor:
		return sustenance_available > crew_priority_reserve
	return true

## Bills a visitor for their meal (WI-33): clamped to the wallet, booked as income
## "dining". No-op for crew. Returns the amount actually charged.
func charge_meal(pawn: PawnBase) -> int:
	if pawn == null or not pawn.is_visitor or visitor_meal_price <= 0:
		return 0
	var charge: int = mini(visitor_meal_price, pawn.personal_credits)
	if charge <= 0:
		return 0
	pawn.spend_credits(charge)
	if Global.economy_manager != null:
		# The station banks the net after the levy (WI-25 call-site contract).
		Global.resource_manager.credit_resource.change_global_total(Global.economy_manager.record_income(charge, &"dining"))
	return charge

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
