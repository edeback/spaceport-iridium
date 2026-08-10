class_name PileTabSet
extends InspectorTabSet

## The PILE tab set (WI-51). A single-tab set, ported from
## `component_ui_panels/resource_pile_inventory_tab.tscn`.

const TAB_CONTENTS: StringName = &"contents"

var _pile: ResourcePile = null

func kind_label() -> String:
	return "DEBRIS"

func bind(subject: Variant) -> void:
	_pile = subject as ResourcePile
	if _pile == null:
		return
	_pile.pile_changed.connect(_on_pile_changed)
	_pile.despawning.connect(_on_gone)

func is_alive() -> bool:
	return _pile != null and is_instance_valid(_pile)

func camera_target() -> Node2D:
	return _pile

func subject_name() -> String:
	return "Debris pile"

func meta_text() -> String:
	if not is_alive():
		return ""
	var kinds: int = 0
	var total: int = 0
	for resource: ResourceData in _pile.get_contained_resources():
		var amount: int = _pile.get_total(resource)
		if amount > 0:
			kinds += 1
			total += amount
	return "%d item%s · %d kind%s" % [total, "" if total == 1 else "s",
		kinds, "" if kinds == 1 else "s"]

func icon_color() -> Color:
	return UIPalette.tinted(UIPalette.ATTENTION, 0.5) if is_alive() else Color(0.0, 0.0, 0.0, 0.0)

func tabs() -> Array[Dictionary]:
	return [{"id": TAB_CONTENTS, "text": "Contents"}]

func make_page(id: StringName) -> Control:
	if id != TAB_CONTENTS or not is_alive():
		return null
	var page := PileContentsTab.new()
	page.set_resource_pile(_pile)
	return page

func _on_pile_changed(_resource: ResourceData, _amount: int) -> void:
	subject_changed.emit()

func _on_gone() -> void:
	subject_lost.emit()
