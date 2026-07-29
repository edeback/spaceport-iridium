class_name ShopComponent
extends RecreationProviderComponent

## A storefront (WI-33). Extends RecreationProviderComponent for the slot-claim +
## per-hour-recreation machinery, but is customized by a ShopTypeData the player
## picks (like a processor's recipe) and charges a per-visit fee that returns to
## station income. Crucially it joins the "shop" group, NOT "recreation_provider":
## Job_Recreate must not treat a paid storefront as free entertainment, so
## Job_Shop is the only job that visits shops and it pays at the register.
##
## One shop scene + this component covers every storefront; the picked type drives
## price, recreation rate, mood lift, and the sprite tint. The selection is the
## only saved state - everything else re-derives from the resolved type.

## The type a freshly-placed shop opens as; empty = the first scanned type. The
## player can switch it any time from the panel (no stock, so switching is free).
@export var default_type_id: StringName = &""
## Optional power gate: an unpowered shop is closed (no recreation, no sales),
## mirroring the holodeck. Null = the shop never needs power.
@export var power_consumption_component: PowerConsumptionComponent

## The currently selected type; null only before the first _resolve (previews).
var shop_type: ShopTypeData = null

## Emitted when the selected type changes (panel refresh).
signal shop_type_changed(new_type: ShopTypeData)

func ready_preview() -> void:
	_ensure_type()
	_apply_visuals()

func ready_blueprint() -> void:
	_ensure_type()
	_apply_visuals()

func ready_constructed() -> void:
	add_to_group(Groups.SHOP)
	_ensure_type()
	_apply_visuals()

## Resolves shop_type from default_type_id (or the first scanned type) if unset.
func _ensure_type() -> void:
	if shop_type != null:
		return
	if default_type_id != &"":
		shop_type = ShopTypeData.by_id(default_type_id)
	if shop_type == null:
		var all: Array[ShopTypeData] = ShopTypeData.all()
		if not all.is_empty():
			shop_type = all[0]

## Player-facing type switch (panel). No stock to strand, so it applies at once.
func select_type(type_id: StringName) -> void:
	var next: ShopTypeData = ShopTypeData.by_id(type_id)
	if next == null or next == shop_type:
		return
	shop_type = next
	_apply_visuals()
	shop_type_changed.emit(shop_type)

## Tint the storefront and label it with the picked type so it reads at a glance.
func _apply_visuals() -> void:
	if owner_module == null or shop_type == null:
		return
	var sprite: Sprite2D = owner_module.get_sprite()
	if sprite != null:
		sprite.modulate = shop_type.modulate
	if owner_module.nameplate != null:
		owner_module.nameplate.text = shop_type.display_name

## Open for business = a type is selected and (if power-gated) powered.
func is_open() -> bool:
	if shop_type == null:
		return false
	if power_consumption_component != null and not power_consumption_component.powered:
		return false
	return true

## Provider rate (before the base's vibration multiplier). 0 when closed, so
## Job_Shop leaves and the recreation need re-queues on its own.
func _raw_recreation_per_hour(_pawn: PawnBase) -> float:
	if not is_open() or shop_type == null:
		return 0.0
	return shop_type.recreation_per_hour

## The cheapest this shop can charge - the gate Job_Shop checks before walking a
## customer over (so a visit can't fail on price after the trip).
func min_visit_price() -> int:
	return shop_type.min_visit_price() if shop_type != null else 0

## Rolls one visit's price within the type's band.
func roll_visit_price() -> int:
	return shop_type.visit_price() if shop_type != null else 0

## Books a completed sale of `amount` credits as station income under "shops"
## (levy applies once here - crew are spending station-paid wages back, taxed once
## at the register, never double-taxed through the wallet). The customer's wallet
## was already debited by Job_Shop. No-op with no economy manager (headless tests).
func record_sale(amount: int) -> void:
	if amount <= 0:
		return
	if Global.economy_manager != null:
		# record_income books the ledger + skims the levy and returns the NET; the
		# station banks that net (the WI-25 call-site contract - never re-read gross).
		Global.resource_manager.credit_resource.change_global_total(Global.economy_manager.record_income(amount, &"shops"))

## WI-44 adapter: the uniform name Action_Pay calls once the customer has actually
## handed over `amount`. Books the sale and applies whatever else the vendor does
## on a completed visit, so the action stays a generic "charge the register" step
## and the shop-specific consequences live here.
func complete_sale(pawn: PawnBase, amount: int) -> void:
	record_sale(amount)
	# A satisfying visit lifts mood a little (WI-33), nudging reputation for
	# visitors and just cheering crew. Timed, so it fades like a good meal.
	if shop_type == null or is_zero_approx(shop_type.visit_mood_bonus) or pawn == null:
		return
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs != null:
		needs.add_modifier(&"good_shopping", shop_type.visit_mood_bonus,
			shop_type.visit_mood_duration_hours)

# --- persistence --------------------------------------------------------------
# Only the selected type id round-trips; capacity/claims are runtime-only.

func get_save_data() -> Dictionary:
	if shop_type == null:
		return {}
	return {"type": String(shop_type.id)}

func load_save_data(data: Dictionary) -> void:
	var type_str: String = String(data.get("type", ""))
	if type_str != "":
		var restored: ShopTypeData = ShopTypeData.by_id(StringName(type_str))
		if restored != null:
			shop_type = restored
			_apply_visuals()

func has_ui() -> bool:
	return owner_module != null and owner_module.is_complete()

func get_ui() -> ModuleComponentUI:
	if ui_info_panel_element == null:
		return null
	var ui: ShopComponentUI = ui_info_panel_element.instantiate() as ShopComponentUI
	ui.set_shop_component(self)
	return ui
