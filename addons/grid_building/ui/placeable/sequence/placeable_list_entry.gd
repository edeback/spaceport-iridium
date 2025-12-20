## Rich, keyboard- and mouse-friendly list entry for selecting a Placeable or sequence variant.
##
## Purpose
## - Drop-in UI cell meant to replace a plain `ItemList` row with a richer control
##   that shows an icon, name, and optional variant index with left/right arrows.
## - Works either with a single `placeable` Resource or with a `sequence` of variants
##   (for example a `PlaceableSequence` containing multiple `Placeable` resources).
##
## Key Features
## - Emits `selected` when the user clicks or presses Enter/Space.
## - Emits `variant_changed` when cycling variants via arrow buttons or Left/Right keys.
## - Provides public getters so documentation and examples never rely on private helpers:
##   - `get_active_placeable()` returns the currently active resource in this entry.
##   - `get_active_variant_index()` returns the active variant index.
##   - `get_active_display_name()` resolves a display name from the active object.
##
## Input and Accessibility
## - Mouse: left click selects; on-screen left/right buttons cycle variants.
## - Keyboard: when focused, Left/Right cycle variants; Enter/Space select.
##
## Data requirements
## - The active object should provide a `display_name: String` and optional `icon: Texture2D`.
## - When `sequence` is used, it should expose `count()` and `get_variant(index)`.
@tool
class_name PlaceableListEntry
extends HBoxContainer

## Emitted when this entry is selected by the user.
signal selected(entry: PlaceableListEntry)
## Emitted after cycling to a different variant. Use `variant_index` to query the active object.
signal variant_changed(entry: PlaceableListEntry, variant_index: int)

## Single placeable resource to display/select when no sequence is provided.
@export var placeable: Resource:
	set(value):
		placeable = value
		_current_variant_index = 0
		_update_view()

## Optional sequence wrapper providing variants (e.g. `PlaceableSequence`).
## Should implement `count()` and `get_variant(index)`.
@export var sequence: Resource:
	set(value):
		sequence = value
		_current_variant_index = 0
		_update_variant_visibility()
		_update_view()

@export var icon_size: Vector2 = Vector2(48, 48):
	set(value):
		icon_size = value
		if _icon_rect:
			_icon_rect.custom_minimum_size = icon_size

@export_group("Sizing Settings")
## Fixed height for list entries to maintain consistent sizing.[br][br]
## When set to a positive value, enforces a fixed height regardless of content.[br]
## When set to 0, height enforcement is disabled and the entry will size naturally.[br]
## Default: 56 pixels to match template standard sizing.
@export var fixed_entry_height : int = 56

var _current_variant_index: int = 0
var _icon_rect: TextureRect
var _name_label: Label
var _variant_label: Label
var _left_button: Button
var _right_button: Button
var _container: HBoxContainer
var _main_panel: PanelContainer
var _selected: bool = false
var _ui_interaction: PlaceableUIInteraction


func _ready():
	_wire_nodes()
	_init_interaction()
	_update_variant_visibility()
	_update_view()
	focus_mode = Control.FOCUS_ALL
	_enforce_entry_height()


func _init_interaction():
	_ui_interaction = PlaceableUIInteraction.new()
	_ui_interaction.init(_main_panel)  # Apply interaction to MainPanel only
	_ui_interaction.clicked.connect(_on_clicked)

func _on_clicked():
	selected.emit(self)


func _wire_nodes():
	_main_panel = $MainPanel if has_node("MainPanel") else null
	_container = $MainPanel/HBox if has_node("MainPanel/HBox") else null
	_icon_rect = $MainPanel/HBox/Icon if has_node("MainPanel/HBox/Icon") else null
	_name_label = $MainPanel/HBox/Center/Name if has_node("MainPanel/HBox/Center/Name") else null
	_variant_label = $MainPanel/HBox/Center/Variant if has_node("MainPanel/HBox/Center/Variant") else null
	_left_button = $Left if has_node("Left") else null
	_right_button = $Right if has_node("Right") else null
	if _left_button:
		_left_button.pressed.connect(func(): _cycle_variant(-1))
	if _right_button:
		_right_button.pressed.connect(func(): _cycle_variant(1))


func set_selected(v: bool):
	_selected = v
	# Note: Visual selection state is now handled by PlaceableUIInteraction
	# This method just tracks the logical selection state
	if _name_label:
		_name_label.add_theme_color_override(
			"font_color", Color(1, 1, 1, 1) if v else Color(1, 1, 1, 0.9)
		)


func is_selected() -> bool:
	return _selected


func _gui_input(event):
	# Handle keyboard navigation only - mouse clicks are handled by PlaceableUIInteraction
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				if _sequence_has_variants():
					_cycle_variant(-1)
					accept_event()
			KEY_RIGHT:
				if _sequence_has_variants():
					_cycle_variant(1)
					accept_event()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				selected.emit(self)
				accept_event()


func _cycle_variant(direction: int):
	var total = _sequence_count()
	if total <= 1:
		return
	_current_variant_index = (_current_variant_index + direction) % total
	if _current_variant_index < 0:
		_current_variant_index = total - 1
	_update_view()
	variant_changed.emit(self, _current_variant_index)


## Internal: compute the active object given `sequence` and current index.
func _active_object() -> Resource:
	if sequence and sequence.has_method("get_variant"):
		return sequence.get_variant(_current_variant_index)
	return placeable

## Returns the currently active placeable resource for this entry.
func get_active_placeable() -> Resource:
	return _active_object()

## Returns the active variant index (0-based) within the sequence.
func get_active_variant_index() -> int:
	return _current_variant_index

## Returns a display name for the active variant.
func get_active_display_name() -> String:
	var obj := _active_object()
	if obj == null:
		return ""
	var dn = _get_property(obj, "display_name")
	if dn != null:
		return str(dn)
	var nprop = _get_property(obj, "name")
	if nprop != null:
		return str(nprop)
	return ""


func _update_variant_visibility():
	var show_variants := _sequence_count() > 1
	if _left_button:
		_left_button.visible = show_variants
	if _right_button:
		_right_button.visible = show_variants
	if _variant_label:
		_variant_label.visible = show_variants


func _get_property(obj: Object, name: String):
	for d in obj.get_property_list():
		if d.name == name:
			return obj.get(name)
	return null


func _update_view():
	if not is_inside_tree():
		return
	var obj := _active_object()
	if obj == null:
		return
	var name_text := "<Unnamed>"
	var icon_tex: Texture2D = null
	if obj is Object:
		var dn = _get_property(obj, "display_name")
		if dn != null:
			name_text = str(dn)
		else:
			var nprop = _get_property(obj, "name")
			if nprop != null:
				name_text = str(nprop)
		var it = _get_property(obj, "icon")
		if it != null and it is Texture2D:
			icon_tex = it
	if _name_label:
		_name_label.text = name_text
	var total = _sequence_count()
	if _variant_label:
		_variant_label.visible = total > 1
		if total > 1:
			_variant_label.text = "%d/%d" % [_current_variant_index + 1, total]
	if _icon_rect:
		_icon_rect.custom_minimum_size = icon_size
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.texture = icon_tex
	var total_variants = _sequence_count()
	tooltip_text = (
		name_text
		if total_variants <= 1
		else "%s (Variant %d/%d)" % [name_text, _current_variant_index + 1, total_variants]
	)
	# Ensure height enforcement is maintained when content changes
	_enforce_entry_height()


func _sequence_count() -> int:
	if sequence and sequence.has_method("count"):
		return int(sequence.count())
	return 0


func _sequence_has_variants() -> bool:
	return _sequence_count() > 1


## Enforces fixed height for consistent sizing when fixed_entry_height > 0
func _enforce_entry_height() -> void:
	if fixed_entry_height > 0:
		custom_minimum_size.y = fixed_entry_height
		size.y = fixed_entry_height
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		# Reset to natural sizing when height enforcement is disabled
		custom_minimum_size.y = 0
		size_flags_vertical = Control.SIZE_EXPAND_FILL
