@tool
class_name ListRow
extends Button

## The recurring "swatch / name over meta line / right-aligned metric or action"
## row, in the three row treatments (WI-49).
##
## Alerts, comms, crew, stores and trade rows are all this row. It is a [Button]
## rather than a panel plus a click handler so hover, press, focus and keyboard
## navigation come from the theme rather than from five hand-rolled
## reimplementations.
##
## The left accent bar is a child rather than the style box's left border,
## because Godot draws one border colour per box and the design's accent is
## brighter than the row's other three edges. See [method UIPalette.row_accent].
##
## The name and meta labels are authored with `text_overrun_behavior` set to
## ellipsis, and that is load-bearing rather than cosmetic (found in WI-53): a
## non-autowrapping [Label] reports its **full text width** as its minimum size,
## which propagates up to the inner `Row` - and that `Row` is anchored with
## `grow_horizontal = BOTH`, so an over-long row does not merely overflow to the
## right, it grows out of *both* sides of its own panel. Setting an overrun
## behaviour drops the reported minimum width to 1 while leaving the height
## intact, which is what keeps a long alert detail inside a 344px readout.
##
## The **action** label got the same treatment plus a reserved width in WI-58,
## for the mirror-image reason: it had no overrun behaviour, so it reported its
## full text as its minimum and took that room out of the expanding name/meta
## block first. See [constant UIMetrics.LIST_ROW_ACTION_WIDTH].

const SCENE_PATH: String = "res://ui/theme/widgets/list_row.tscn"

const SWATCH_SIZE: int = 24

var _accent: ColorRect
var _swatch: ColorRect
var _icon: TextureRect
var _name_label: Label
var _meta_label: Label
var _action_label: Label

var _kind: UIPalette.Row = UIPalette.Row.INERT
var _row: HBoxContainer

static func create() -> ListRow:
	return load(SCENE_PATH).instantiate() as ListRow

func _ready() -> void:
	_ensure_refs()
	if _row != null and not _row.minimum_size_changed.is_connected(_refit):
		_row.minimum_size_changed.connect(_refit)
	set_kind(_kind)
	_refit()

## Gives the row a height that fits its two lines of text.
##
## The content is laid out by anchors inside the button rather than by a
## container, so nothing derives a height for it: every row would render at the
## button's own 28px minimum with the meta line spilling out the bottom. The
## obvious fix - overriding `_get_minimum_size()` - does **not** work here,
## because [Button] overrides `get_minimum_size()` in C++ and never consults the
## script virtual. `custom_minimum_size` is the one channel that gets through.
##
## Only the height is set. A minimum width would fight the panel that owns the
## row, which is the thing that actually knows how wide the list is.
func _refit() -> void:
	_ensure_refs()
	if _row == null:
		return
	var box: StyleBoxFlat = UIPalette.row_style(_kind)
	if _action_label != null:
		# The scene authors the structure; the number comes from [UIMetrics], so a
		# row's action slot cannot drift to 64px in one list and 80 in another.
		_action_label.custom_minimum_size.x = float(UIMetrics.LIST_ROW_ACTION_WIDTH)
	custom_minimum_size.y = _row.get_combined_minimum_size().y \
		+ box.content_margin_top + box.content_margin_bottom

func _ensure_refs() -> void:
	if _name_label != null:
		return
	_row = get_node_or_null("Row") as HBoxContainer
	_accent = get_node_or_null("Accent") as ColorRect
	_swatch = get_node_or_null("Row/Swatch") as ColorRect
	_icon = get_node_or_null("Row/Icon") as TextureRect
	_name_label = get_node_or_null("Row/Text/Name") as Label
	_meta_label = get_node_or_null("Row/Text/Meta") as Label
	_action_label = get_node_or_null("Row/Action") as Label

## `meta_text` is upper-cased (it is the design's caps meta line); the name is
## not, because names are proper nouns. An empty `action_text` hides the
## right-hand slot.
func configure(name_text: String, meta_text: String = "", action_text: String = "",
		kind: UIPalette.Row = UIPalette.Row.INERT) -> void:
	_ensure_refs()
	if _name_label == null:
		return
	_name_label.text = name_text
	_meta_label.text = meta_text.to_upper()
	_meta_label.visible = not meta_text.is_empty()
	_action_label.text = action_text.to_upper()
	_action_label.visible = not action_text.is_empty()
	set_kind(kind)
	_refit()

## A coloured square on the left - a resource swatch, a module tag colour.
##
## `size` overrides the list-item square, the same way [method set_icon]'s does
## and for a related reason: Comms' transmission rows reserve a 34px **avatar**
## slot (WI-57), sized now so that dropping a faction portrait into it later does
## not re-lay the list out. The row grows to fit it, because [method _refit]
## measures the content.
func set_swatch(color: Color, size: int = SWATCH_SIZE) -> void:
	_ensure_refs()
	if _swatch == null:
		return
	_swatch.color = color
	_swatch.custom_minimum_size = Vector2(float(size), float(size))
	_swatch.visible = color.a > 0.0
	if _swatch.visible and _icon != null:
		_icon.visible = false

## `size` overrides the list-item square for a row that is a *heading* rather
## than a line item - Build's category rail is the motivating case, where the
## design gives each entry a 34px tile. The row grows to fit it, because
## [method _refit] measures the content.
func set_icon(texture: Texture2D, size: int = SWATCH_SIZE) -> void:
	_ensure_refs()
	if _icon == null:
		return
	_icon.texture = texture
	_icon.custom_minimum_size = Vector2(float(size), float(size))
	_icon.visible = texture != null
	if _icon.visible and _swatch != null:
		_swatch.visible = false

## Tints the row's glyph. The authored icons are white strokes (the console
## convention, WI-50), so anything that wants a coloured one recolours it here
## rather than shipping a second SVG per colour. Call after [method set_icon].
func set_icon_color(color: Color) -> void:
	_ensure_refs()
	if _icon != null:
		_icon.modulate = color

## Recolours the right-hand slot on its own, for the rows whose metric carries a
## sign - the ledger's per-cycle rate, the trade table's margin, the economy
## tab's ledger lines. Call it *after* [method configure], which resets the slot
## to the row treatment's own text colour.
##
## Deliberately not a parameter of `configure`: the row treatment says what kind
## of row this is, and a sign colour says which way one number is going. Folding
## them together is how "amber means falling" and "amber means breached" would
## end up sharing a code path (invariant 5).
func set_action_color(color: Color) -> void:
	_ensure_refs()
	if _action_label == null:
		return
	_action_label.add_theme_color_override("font_color", color)

func set_kind(kind: UIPalette.Row) -> void:
	_ensure_refs()
	_kind = kind
	if _name_label == null:
		return
	var normal: StyleBoxFlat = UIPalette.row_style(kind)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	# Hover and press lift the row rather than restyling it, so a row's state
	# still reads through the interaction.
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = UIPalette.tinted(UIPalette.LIVE,
		maxf(normal.bg_color.a, 0.0) + UIPalette.ROW_LIVE_ALPHA)
	add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = UIPalette.tinted(UIPalette.LIVE,
		maxf(normal.bg_color.a, 0.0) + UIPalette.ROW_LIVE_ALPHA * 2.0)
	add_theme_stylebox_override("pressed", pressed)
	if _accent != null:
		_accent.color = UIPalette.row_accent(kind)
		_accent.custom_minimum_size.x = float(UIPalette.ROW_ACCENT_WIDTH)
	if _row != null:
		# The content insets come from the style box too, so padding is stated
		# once rather than in the scene and again in _refit().
		_row.offset_left = normal.content_margin_left
		_row.offset_right = -normal.content_margin_right
		_row.offset_top = normal.content_margin_top
		_row.offset_bottom = -normal.content_margin_bottom
		_refit()
	_name_label.add_theme_color_override("font_color", UIPalette.row_text(kind))
	_meta_label.add_theme_color_override("font_color", UIPalette.row_meta(kind))
	_action_label.add_theme_color_override("font_color", UIPalette.row_text(kind))
