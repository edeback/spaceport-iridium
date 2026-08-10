@tool
class_name Chip
extends PanelContainer

## Swatch + text + optional value, in one of the three row treatments (WI-49).
## Storage contents, trade categories, filter pills.
##
## A chip is the smallest thing in the design that can carry a state, which is
## why it takes a [enum UIPalette.Row] rather than a colour: "this one is
## selected" and "this one is over budget" have to look the same everywhere or
## the three treatments stop meaning anything.

const SCENE_PATH: String = "res://ui/theme/widgets/chip.tscn"

## Side of the colour swatch, matching the design's 12px chip square.
const SWATCH_SIZE: int = 12

var _swatch: ColorRect
var _icon: TextureRect
var _label: Label
var _value: Label

static func create() -> Chip:
	return load(SCENE_PATH).instantiate() as Chip

func _ready() -> void:
	_ensure_refs()

func _ensure_refs() -> void:
	if _label != null:
		return
	_swatch = get_node_or_null("Row/Swatch") as ColorRect
	_icon = get_node_or_null("Row/Icon") as TextureRect
	_label = get_node_or_null("Row/Label") as Label
	_value = get_node_or_null("Row/Value") as Label

## An empty `value_text` hides the value; a fully transparent `swatch` hides the
## swatch. Both are common - a filter pill is text alone.
func configure(label_text: String, value_text: String = "",
		swatch: Color = Color(0.0, 0.0, 0.0, 0.0),
		kind: UIPalette.Row = UIPalette.Row.INERT) -> void:
	_ensure_refs()
	if _label == null:
		return
	_label.text = label_text
	_label.add_theme_color_override("font_color", UIPalette.row_text(kind))
	_value.text = value_text
	_value.visible = not value_text.is_empty()
	_value.add_theme_color_override("font_color", UIPalette.row_meta(kind))
	_swatch.color = swatch
	_swatch.visible = swatch.a > 0.0
	_swatch.custom_minimum_size = Vector2(float(SWATCH_SIZE), float(SWATCH_SIZE))
	set_kind(kind)

## A chip's icon replaces its swatch - a resource has one or the other, never
## both, or the row turns into a toolbar.
func set_icon(texture: Texture2D) -> void:
	_ensure_refs()
	if _icon == null:
		return
	_icon.texture = texture
	_icon.visible = texture != null
	if texture != null:
		_swatch.visible = false

func set_kind(kind: UIPalette.Row) -> void:
	_ensure_refs()
	if _label == null:
		return
	# The shared row styles carry list-row padding, which is far too generous
	# for a chip, so this is one of the documented duplicate()-to-mutate cases.
	var box: StyleBoxFlat = UIPalette.row_style(kind).duplicate() as StyleBoxFlat
	box.border_width_left = UIPalette.ROW_BORDER_WIDTH
	box.set_content_margin_all(6.0)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	if kind == UIPalette.Row.INERT:
		# An inert chip is a control, not a reported row, so unlike an inert list
		# row it gets the control fill rather than nothing.
		box.bg_color = UIPalette.CONTROL_FILL
		box.border_color = UIPalette.CONTROL_BORDER
	add_theme_stylebox_override("panel", box)
	_label.add_theme_color_override("font_color", UIPalette.row_text(kind))
	_value.add_theme_color_override("font_color", UIPalette.row_meta(kind))
