@tool
class_name VitalsChip
extends PanelContainer

## One tile in the console's pinned vitals strip (WI-52): an icon or swatch, the
## value, an optional suffix, and the name underneath.
##
## Fixed width by construction ([constant UIMetrics.VITALS_CHIP_WIDTH]). The
## strip re-lays out only when the pin list changes; a value that gains a digit
## must not move its neighbours, which is why the chip does not size to content
## and why large numbers get [method LedgerModel.format_compact] rather than more
## pixels.
##
## Takes a [enum UIPalette.Row] like every other widget in the library, so
## "falling vital" looks the same here as "over budget" does in a list. That amber
## is one of the four sanctioned spends of it (invariant 5), and it is the whole
## reason the strip is worth having: `FOOD 12 ▼` in amber is the early-warning
## system.

const SCENE_PATH: String = "res://ui/console/vitals_chip.tscn"

## The glyph a falling vital carries beside its value.
const FALLING_GLYPH: String = "▼"

## Side of the colour swatch, matching [Chip]'s 12px square.
const SWATCH_SIZE: int = 12

static func create() -> VitalsChip:
	return load(SCENE_PATH).instantiate() as VitalsChip

## What this chip is pinned as - a resource id, or one of [LedgerModel]'s
## `derived:` ids. The strip keys its rebuild diff on this.
var chip_id: StringName = &""

var _swatch: ColorRect
var _icon: TextureRect
var _value: Label
var _suffix: Label
var _caption: Label

func _ready() -> void:
	_ensure_refs()
	_apply_layout()
	set_kind(UIPalette.Row.INERT)

## Lazy for the same reason every WI-49 frame's are: the strip configures a chip
## before mounting it.
func _ensure_refs() -> void:
	if _value != null:
		return
	_swatch = get_node_or_null("Margin/Column/Top/Swatch") as ColorRect
	_icon = get_node_or_null("Margin/Column/Top/Icon") as TextureRect
	_value = get_node_or_null("Margin/Column/Top/Value") as Label
	_suffix = get_node_or_null("Margin/Column/Top/Suffix") as Label
	_caption = get_node_or_null("Margin/Column/Caption") as Label

func _apply_layout() -> void:
	_ensure_refs()
	custom_minimum_size = Vector2(
		float(UIMetrics.VITALS_CHIP_WIDTH), float(UIMetrics.CONSOLE_TILE_HEIGHT))
	if _swatch != null:
		_swatch.custom_minimum_size = Vector2(float(SWATCH_SIZE), float(SWATCH_SIZE))
	if _icon != null:
		_icon.custom_minimum_size = Vector2(float(SWATCH_SIZE) + 2.0, float(SWATCH_SIZE) + 2.0)
	if _value != null:
		# The scene authors the structure; the number is [UIMetrics]'. See that
		# constant for why the reserve exists rather than the labels simply being
		# allowed to ask for what they need.
		_value.custom_minimum_size.x = float(UIMetrics.VITALS_VALUE_WIDTH)

# --- public -------------------------------------------------------------------

## The identity half of the chip: what it is and how it is marked. Called once,
## when the strip builds the chip.
##
## A texture wins over the swatch - a chip has one or the other, never both, or
## the strip turns into a toolbar (the same rule [Chip] follows).
func configure(id: StringName, caption: String, icon: Texture2D = null,
		swatch: Color = UIPalette.INERT_ACCENT) -> void:
	_ensure_refs()
	chip_id = id
	if _caption != null:
		_caption.text = caption.to_upper()
	if _icon != null:
		_icon.texture = icon
		_icon.visible = icon != null
	if _swatch != null:
		_swatch.color = swatch
		_swatch.visible = icon == null and swatch.a > 0.0
	tooltip_text = caption

## The value half, refreshed in place. `suffix` carries the `/max` and the
## falling glyph; pass "" for a bare number.
func set_value(value_text: String, suffix_text: String = "",
		kind: UIPalette.Row = UIPalette.Row.INERT) -> void:
	_ensure_refs()
	if _value == null:
		return
	_value.text = value_text
	_suffix.text = suffix_text
	_suffix.visible = not suffix_text.is_empty()
	set_kind(kind)

func set_kind(kind: UIPalette.Row) -> void:
	_ensure_refs()
	if _value == null:
		return
	# The shared row styles carry list-row padding, which is far too generous for a
	# 52px tile - the documented duplicate()-to-mutate case.
	var box: StyleBoxFlat = UIPalette.row_style(kind).duplicate() as StyleBoxFlat
	box.set_content_margin_all(0.0)
	if kind == UIPalette.Row.INERT:
		# An inert chip is a control on the console gradient, not a reported row,
		# so it takes the control fill rather than nothing - same call [Chip] makes.
		box.bg_color = UIPalette.CONTROL_FILL
		box.border_color = UIPalette.CONTROL_BORDER
	add_theme_stylebox_override("panel", box)
	_value.add_theme_color_override("font_color", UIPalette.row_text(kind))
	_suffix.add_theme_color_override("font_color", UIPalette.row_meta(kind))
	_caption.add_theme_color_override("font_color", UIPalette.row_meta(kind))
