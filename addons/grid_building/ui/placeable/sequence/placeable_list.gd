## Scrollable list managing PlaceableListEntry nodes, providing selection & keyboard nav.
@tool
class_name PlaceableList
extends Control

signal selection_changed(entry)

@export var entry_scene: PackedScene

var _scroll: ScrollContainer
var _vbox: VBoxContainer
var _entries: Array = []
var _selected_entry: Node = null


func _ready():
	_wire()
	focus_mode = Control.FOCUS_ALL


func _wire():
	_scroll = $Scroll if has_node("Scroll") else null
	_vbox = $Scroll/Entries if has_node("Scroll/Entries") else null


func clear():
	for e in _entries:
		if is_instance_valid(e):
			e.queue_free()
	_entries.clear()
	_selected_entry = null


func add_sequence(sequence: Resource):
	if entry_scene == null:
		push_warning("PlaceableList: entry_scene not set")
		return null
	if sequence == null:
		push_warning("PlaceableList: add_sequence called with null sequence")
		return null
	var entry = entry_scene.instantiate()
	_vbox.add_child(entry)
	entry.sequence = sequence
	entry.selected.connect(_on_entry_selected)
	entry.variant_changed.connect(_on_entry_variant_changed)
	_entries.append(entry)
	if _selected_entry == null:
		_select_entry(entry)
	return entry


func _on_entry_selected(entry):
	_select_entry(entry)


func _on_entry_variant_changed(entry, _idx: int):
	if entry == _selected_entry:
		selection_changed.emit(entry)


func _select_entry(entry):
	if _selected_entry and is_instance_valid(_selected_entry):
		_selected_entry.set_selected(false)
	_selected_entry = entry
	if _selected_entry:
		_selected_entry.set_selected(true)
		selection_changed.emit(_selected_entry)


func get_selected_entry():
	return _selected_entry


func _unhandled_input(event):
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_move_selection(-1)
			KEY_DOWN:
				_move_selection(1)


func _move_selection(delta: int):
	if _entries.is_empty():
		return
	var idx := _entries.find(_selected_entry)
	if idx == -1:
		idx = 0
	idx = clamp(idx + delta, 0, _entries.size() - 1)
	_select_entry(_entries[idx])
	_ensure_visible(_entries[idx])


func _ensure_visible(entry):
	if _scroll == null:
		return
	var rect = entry.get_global_rect()
	var srect = _scroll.get_global_rect()
	if rect.position.y < srect.position.y:
		_scroll.scroll_vertical -= int(srect.position.y - rect.position.y)
	elif rect.position.y + rect.size.y > srect.position.y + srect.size.y:
		_scroll.scroll_vertical += int(
			(rect.position.y + rect.size.y) - (srect.position.y + srect.size.y)
		)
