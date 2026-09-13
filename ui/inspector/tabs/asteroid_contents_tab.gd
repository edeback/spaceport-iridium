class_name AsteroidContentsTab
extends VBoxContainer

## What an asteroid is made of, as a share of what mining it yields.
##
## Ore weights are *relative shares*, not counts, so they are presented as
## approximate percentages - printing the raw weights would invite the player to
## read them as chunks and be wrong every time.
##
## Code-built: the authored scene this replaces was mostly its own frame and its
## own close button, both of which the inspector now provides.

var _asteroid: AsteroidBase = null
## How much is left to mine. It was a bar in the subject block; the inverted
## inspector keeps the count on the meta line and the gauge here (2026-09-13).
var _remaining: StatBar = null
var _rows: VBoxContainer = null

func set_asteroid(asteroid: AsteroidBase) -> void:
	name = "Contents"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_asteroid = asteroid
	_remaining = StatBar.create()
	add_child(_remaining)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	add_child(_rows)
	if _asteroid != null:
		_asteroid.contents_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if _rows == null:
		return
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if _asteroid == null or not is_instance_valid(_asteroid):
		return
	_remaining.visible = _asteroid.max_resources > 0
	if _remaining.visible:
		_remaining.configure("Remaining",
			float(_asteroid.cur_resources) / float(_asteroid.max_resources),
			"%d" % _asteroid.cur_resources, UIPalette.LIVE)
	var total: float = _asteroid.resource_total_weights
	if total <= 0.0:
		var empty := Label.new()
		empty.text = "Nothing worth mining."
		empty.theme_type_variation = UIType.META_LINE
		empty.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
		_rows.add_child(empty)
		return
	for resource: ResourceData in _asteroid.resource_weighted_values:
		var row: ListRow = ListRow.create()
		row.disabled = true
		row.focus_mode = Control.FOCUS_NONE
		_rows.add_child(row)
		row.configure(resource.name, "",
			"~%d%%" % roundi(_asteroid.resource_weighted_values[resource] / total * 100.0),
			UIPalette.Row.INERT)
