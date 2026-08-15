@tool
class_name TabStrip
extends Control

## The design's tab row: an active tab with a LIVE-tinted fill and no bottom
## edge, sitting on a 1px EDGE underline (WI-49).
##
## **It does not own its pages, and that is the whole point.** [TabContainer]
## couples the strip to its children and shows them by index - which is what
## made WI-48's deferred `set_tab_hidden` bug possible, and what makes a
## per-component tab set (the module inspector, whose tabs come from whichever
## components a module happens to carry) awkward to express. Here the strip
## emits [signal tab_selected] and the panel swaps its own pages, so a tab set
## that changes shape is a `set_tabs()` call rather than an index-juggling
## exercise.
##
## A strip with no tabs is legal and renders as an empty rule - the inspector's
## nothing-selected state and a module with no component UIs both hit it.

const SCENE_PATH: String = "res://ui/theme/widgets/tab_strip.tscn"

## One row of tabs. The strip grows past this when its tabs wrap.
const MIN_HEIGHT: int = 32

## Emitted when the player picks a tab, and when [method select] changes the
## selection. Not emitted by [method set_tabs] restoring a selection, because
## rebuilding a strip is not the player choosing anything.
signal tab_selected(id: StringName)

var _row: HFlowContainer
var _underline: ColorRect

## Tab ids in strip order, so a rebuild can restore the selection and an index
## can be turned back into an id.
var _ids: Array[StringName] = []
var _selected: StringName = &""

static func create() -> TabStrip:
	return load(SCENE_PATH).instantiate() as TabStrip

func _ready() -> void:
	_ensure_refs()
	if _underline != null:
		_underline.color = UIPalette.EDGE
	if _row != null and not _row.minimum_size_changed.is_connected(_refit):
		_row.minimum_size_changed.connect(_refit)
	_refit()

func _ensure_refs() -> void:
	if _row != null:
		return
	_row = get_node_or_null("Row") as HFlowContainer
	_underline = get_node_or_null("Underline") as ColorRect

## Gives the strip a height that fits however many rows its tabs wrapped onto.
##
## The row is an [HFlowContainer], so a set of tabs wider than the panel wraps
## instead of running off the edge - the module tab set can reach eight tabs on a
## 420px inspector. Flow containers derive their minimum height from their
## current *width*, which is only known after a layout pass, so this re-runs on
## `minimum_size_changed` rather than measuring once (the WI-48 lesson).
func _refit() -> void:
	_ensure_refs()
	if _row == null:
		return
	custom_minimum_size.y = maxf(float(MIN_HEIGHT),
		_row.get_combined_minimum_size().y + float(UIMetrics.BORDER_WIDTH))

# --- public -------------------------------------------------------------------

## `defs` is an array of `{id: StringName, text: String}` dictionaries, with an
## optional `badge: String` for the count the design puts on unread Comms tabs.
##
## The previously selected tab stays selected if it survives the rebuild; if it
## does not, the first tab is selected and [signal tab_selected] fires, because
## the caller's page is now showing something that no longer exists.
func set_tabs(defs: Array) -> void:
	_ensure_refs()
	if _row == null:
		return
	var previous: StringName = _selected
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_ids.clear()
	for def: Variant in defs:
		var entry: Dictionary = def as Dictionary
		if entry == null or not entry.has("id"):
			continue
		var id: StringName = StringName(entry["id"])
		_ids.append(id)
		_row.add_child(_make_tab(id, str(entry.get("text", id)), str(entry.get("badge", ""))))
	if _ids.has(previous):
		_selected = previous
		_apply_selection()
		return
	_selected = _ids[0] if not _ids.is_empty() else &""
	_apply_selection()
	if _selected != &"":
		tab_selected.emit(_selected)

## The currently selected tab, or `&""` when the strip is empty.
func selected() -> StringName:
	return _selected

## Selects a tab by id. A no-op for an id the strip does not hold, so a caller
## restoring a saved selection does not have to check first.
func select(id: StringName) -> void:
	if id == _selected or not _ids.has(id):
		return
	_selected = id
	_apply_selection()
	tab_selected.emit(id)

func is_empty() -> bool:
	return _ids.is_empty()

# --- building -----------------------------------------------------------------

func _make_tab(id: StringName, text: String, badge: String) -> Button:
	var tab := Button.new()
	tab.name = String(id)
	tab.focus_mode = Control.FOCUS_NONE
	tab.text = text.to_upper() if badge.is_empty() else "%s  %s" % [text.to_upper(), badge]
	tab.pressed.connect(func() -> void: select(id))
	return tab

func _apply_selection() -> void:
	_ensure_refs()
	if _row == null:
		return
	for child: Node in _row.get_children():
		var tab: Button = child as Button
		if tab == null:
			continue
		var variation: StringName = (UIType.TAB_ACTIVE if StringName(tab.name) == _selected
			else UIType.TAB_INACTIVE)
		tab.theme_type_variation = variation
		_nudge_tracking(tab, variation)

## A tab's label is tracked and centred, so its glyphs sit half a tracking unit
## left of the tab's own centre (WI-58). The shift goes through the tab's style
## boxes rather than a position write, because a [Button] has no text offset -
## which is why the variation's boxes are read and *duplicated* rather than
## replaced: the active tab's LIVE fill and its missing bottom edge live in them.
##
## **The override has to be cleared before the box is read.**
## [method Control.get_theme_stylebox] consults the control's own overrides
## whenever the type it is asked for is the one the control is currently wearing -
## so on the second call it hands back the box this function wrote last time
## instead of the new variation's, and the tab keeps the fill it had. That shipped
## briefly as "the tab text changes but the highlight stays where it was", which
## is the whole visible state of a tab strip failing to move.
func _nudge_tracking(tab: Button, variation: StringName) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		tab.remove_theme_stylebox_override(state)
		var box: StyleBox = tab.get_theme_stylebox(state, variation)
		if box == null:
			continue
		tab.add_theme_stylebox_override(state,
			UIMetrics.nudge_content_box(box, UIMetrics.TRACKING_TAB_LABEL))
