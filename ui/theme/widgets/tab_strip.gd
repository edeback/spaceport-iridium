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

## Emitted when the player picks a tab, and when [method select] changes the
## selection. Not emitted by [method set_tabs] restoring a selection, because
## rebuilding a strip is not the player choosing anything.
signal tab_selected(id: StringName)

var _row: HBoxContainer
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

func _ensure_refs() -> void:
	if _row != null:
		return
	_row = get_node_or_null("Row") as HBoxContainer
	_underline = get_node_or_null("Underline") as ColorRect

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
		tab.theme_type_variation = (UIType.TAB_ACTIVE if StringName(tab.name) == _selected
			else UIType.TAB_INACTIVE)
