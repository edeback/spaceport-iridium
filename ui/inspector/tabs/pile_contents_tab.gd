class_name PileContentsTab
extends VBoxContainer

## What is lying in a debris pile.
##
## Piles are where resources go when a job cannot put them anywhere else, so this
## is the surface that makes "nothing is silently lost" checkable: whatever came
## out of a cancelled haul or a destroyed module is listed here by name and
## amount, with the average instance value for anything that carries one (ore
## richness, food quality).

var _pile: ResourcePile = null
var _rows: VBoxContainer = null

func set_resource_pile(pile: ResourcePile) -> void:
	name = "Contents"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_pile = pile
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", UIMetrics.LINE_GAP)
	add_child(_rows)
	if _pile != null:
		# Rebuilt wholesale rather than patched per resource: a pile holds a
		# handful of stacks, and the old per-row bookkeeping existed only because
		# the panel could not afford to rebuild while following the pile around.
		_pile.pile_changed.connect(_on_pile_changed)
	refresh()

func _on_pile_changed(_resource: ResourceData, _amount: int) -> void:
	refresh()

func refresh() -> void:
	if _rows == null:
		return
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if _pile == null or not is_instance_valid(_pile):
		return
	var contents: Array[ResourceData] = _pile.get_contained_resources()
	if contents.is_empty():
		var empty := Label.new()
		empty.text = "Empty."
		empty.theme_type_variation = UIType.META_LINE
		empty.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
		_rows.add_child(empty)
		return
	for resource: ResourceData in contents:
		var amount: int = _pile.get_total(resource)
		if amount <= 0:
			continue
		var row: ListRow = ListRow.create()
		row.disabled = true
		row.focus_mode = Control.FOCUS_NONE
		_rows.add_child(row)
		row.configure(resource.name, _quality_text(resource), str(amount), UIPalette.Row.INERT)

## The average instance value of a variance-carrying resource - ore richness,
## food quality - or nothing at all for a plain one.
func _quality_text(resource: ResourceData) -> String:
	if not resource.has_variance:
		return ""
	var container: ResourceStackContainer = _pile.contents.get(resource)
	if container == null:
		return ""
	var average: float = container.average_instance_value()
	if average < 0.0:
		return ""
	return "avg %d%%" % roundi(average * 100.0)
