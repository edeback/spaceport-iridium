class_name ShopComponentUI
extends ModuleComponentUI

## Info-panel UI for a ShopComponent (WI-33). Lets the player pick the storefront's
## type (the processor-recipe-selection pattern) and shows its price band, draw,
## and flavor. No stock to strand, so switching type applies immediately.

@export var type_selector: OptionButton
@export var type_label: Label
@export var stats_label: Label
@export var flavor_label: Label

var shop_component: ShopComponent
## Parallel to the selector's item order so item index -> type id is O(1).
var _types: Array[ShopTypeData] = []

func set_shop_component(component: ShopComponent) -> void:
	shop_component = component
	_types = ShopTypeData.all()
	for shop_type: ShopTypeData in _types:
		type_selector.add_item(shop_type.display_name)
	var current_index: int = _types.find(component.shop_type)
	if current_index >= 0:
		type_selector.select(current_index)
	type_selector.item_selected.connect(_on_type_selected)
	component.shop_type_changed.connect(_on_shop_type_changed)
	_refresh()

func _on_type_selected(index: int) -> void:
	if index >= 0 and index < _types.size():
		shop_component.select_type(_types[index].id)

func _on_shop_type_changed(new_type: ShopTypeData) -> void:
	var index: int = _types.find(new_type)
	if index >= 0 and type_selector.selected != index:
		type_selector.select(index)
	_refresh()

func _refresh() -> void:
	var shop_type: ShopTypeData = shop_component.shop_type
	if shop_type == null:
		type_label.text = "Unassigned storefront"
		stats_label.text = ""
		flavor_label.text = ""
		return
	type_label.text = shop_type.display_name
	stats_label.text = "Visit: %d–%d cr    Fun: %.0f/hr" % [shop_type.price_min, shop_type.price_max, shop_type.recreation_per_hour]
	flavor_label.text = shop_type.flavor
