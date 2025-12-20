## UI view for a single placeable used in selection lists.
##
## Renders a placeable's icon and display name in a horizontal layout with configurable sizing and padding.
## Emits [signal placeable_selected] when the user clicks on the view.
##
## [b]Usage:[/b]
## [codeblock]
## var view = PlaceableView.new()
## view.placeable = my_placeable
## view.fixed_view_height = 48
## view.fixed_icon_size = 40
## view.placeable_selected.connect(_on_placeable_selected)
## [/codeblock]
@tool
class_name PlaceableView
extends PanelContainer

## Emitted when the user clicks on this placeable view to select it.
## [br][br]
## [param placeable] The placeable object associated with this view.
signal placeable_selected(placeable: Placeable)

@export_group("Sizing Settings")
## Fixed height for placeable views to maintain consistent sizing.[br][br]
## When set to a positive value, enforces a fixed height regardless of content.[br]
## When set to 0, height enforcement is disabled and the view will size naturally.[br]
## Default: 48 pixels to match template standard sizing.
@export var fixed_view_height : int = 48

## Fixed icon size for consistent icon dimensions across all placeable views.[br][br]
## When set to a positive value, enforces both width and height of icon TextureRect.[br]
## When set to 0, icon sizing is not enforced and will use scene file settings.[br]
## Default: 40 pixels to match standard icon sizing.
@export var fixed_icon_size : int = 40

## The placeable object displayed by this view.[br][br]
## When set, updates the icon and label to reflect the placeable's display name and icon texture.
@export var placeable: Placeable:
	set(value):
		placeable = value
		_update_view()

## Icon texture display node (child of HBox)
var _icon_rect: TextureRect
## Label display node for placeable name (child of HBox)
var _label: Label
## Handles click/hover interactions for this view
var _ui_interaction: PlaceableUIInteraction

## Called when the node enters the scene tree.[br]
## Initializes the view by wiring child nodes, setting up interaction, and enforcing sizing.
func _ready():
	_wire_nodes()
	_init_interaction()
	_update_view()
	_enforce_view_height()
	_enforce_icon_size()

## Initializes UI interaction handling for click and hover events.
func _init_interaction():
	_ui_interaction = PlaceableUIInteraction.new()
	_ui_interaction.init(self)
	_ui_interaction.clicked.connect(_on_clicked)

## Called when the user clicks on this view. Emits [signal placeable_selected].
func _on_clicked():
	placeable_selected.emit(placeable)

## Wires up references to child nodes (Icon TextureRect and Label).
func _wire_nodes():
	_icon_rect = $HBox/Icon if has_node("HBox/Icon") else null
	_label = $HBox/Label if has_node("HBox/Label") else null

## Updates the view's icon and label to reflect the current placeable.[br]
## Clears the view if placeable is null.
func _update_view():
	if placeable == null:
		if _label:
			_label.text = ""
		if _icon_rect:
			_icon_rect.texture = null
		tooltip_text = ""
		return
	
	if _label:
		_label.text = placeable.display_name
	if _icon_rect:
		_icon_rect.texture = placeable.icon if placeable.icon else null
	tooltip_text = placeable.display_name
	_enforce_view_height()
	_enforce_icon_size()

## Enforces fixed height for consistent sizing when [member fixed_view_height] > 0.[br]
## When disabled (0), allows the view to size naturally based on content.
func _enforce_view_height() -> void:
	if fixed_view_height > 0:
		custom_minimum_size.y = fixed_view_height
		size.y = fixed_view_height
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		# Reset to natural sizing when height enforcement is disabled
		custom_minimum_size.y = 0
		size_flags_vertical = Control.SIZE_EXPAND_FILL

## Enforces fixed icon size for consistent icon dimensions when [member fixed_icon_size] > 0.[br]
## Constrains icon to a square boundary (fixed_icon_size x fixed_icon_size) while maintaining[br]
## aspect ratio. The larger dimension is scaled to fit fixed_icon_size, and the smaller dimension[br]
## scales proportionally. Icon is centered within the bounds.[br]
## When disabled (0), icon sizing is not enforced and will use scene file settings.
func _enforce_icon_size() -> void:
	if _icon_rect and fixed_icon_size > 0:
		var icon_vector := Vector2(fixed_icon_size, fixed_icon_size)
		_icon_rect.custom_minimum_size = icon_vector
		_icon_rect.size = icon_vector
		# EXPAND_IGNORE_SIZE + STRETCH_KEEP_ASPECT_CENTERED ensures the texture
		# fits within the bounds while maintaining aspect ratio
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	elif _icon_rect:
		# Reset to natural sizing when icon size enforcement is disabled
		_icon_rect.custom_minimum_size = Vector2.ZERO
