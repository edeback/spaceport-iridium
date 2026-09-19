class_name TradeResourceRow
extends PanelContainer

## One commodity line of the Trade panel's order table (WI-55):
## `COMMODITY · BUY @ · SELL @ · HELD · AVAIL · TRADE`.
##
## **One signed [Stepper], not two spin boxes.** WI-08's row carried a buy box
## and a sell box with nothing stopping both being non-zero, and a hand-written
## "setting one zeroes the other" rule in two handlers to paper over it. One
## signed number makes that state unrepresentable, which is also why there are no
## buy/sell tabs or radio pairs to keep in sync.
##
## The sign counts **goods**: positive buys in, negative sells out, the same
## direction the HELD and AVAIL columns beside it will move. Credits go the other
## way and are totalled separately, in the summary bar.
##
## **`AVAIL` is the column that earns the table.** HELD is stock; AVAIL is what no
## hauler has already claimed ([method ResourceData.available_unreserved]).
## Selling into a reservation - committing ore a construction site is already
## waiting on - is the mistake this row exists to prevent, so the stepper's
## negative limit comes from AVAIL rather than from HELD.
##
## The row holds no rules: [TradeOffer] owns the caps and the arithmetic, and the
## panel owns which state (docked or not) is being shown. This is the view.

const SCENE_PATH: String = "res://ui/windows/trade/trade_resource_row.tscn"

## Column widths, shared with the header [method make_header] builds so the two
## line up. Fixed rather than content-sized: a price gaining a digit must not
## shunt every other column sideways, which is the same argument
## [constant UIMetrics.VITALS_CHIP_WIDTH] makes in the console strip.
const ICON_SIZE: int = 20
const NAME_MIN_WIDTH: int = 120
const PRICE_COLUMN: int = 54
const STOCK_COLUMN: int = 54
## The [Stepper] scene's own width (26 + 1 + 52 + 1 + 26).
const TRADE_COLUMN: int = 106
const COLUMN_GAP: int = 8

## Emitted once the player has stopped moving the stepper - [Stepper]'s commit
## rule, not its preview. The panel writes standing orders in response, so a hold
## from 0 to 60 must produce one write, not sixty.
signal amount_changed(row: TradeResourceRow)

var resource: ResourceData = null
## Signed: positive buys, negative sells - goods, not credits.
var amount: int = 0

var _icon: TextureRect
var _name: Label
var _buy: Label
var _sell: Label
var _held: Label
var _avail: Label
var _stepper: Stepper

static func create() -> TradeResourceRow:
	return (load(SCENE_PATH) as PackedScene).instantiate() as TradeResourceRow

func _ready() -> void:
	_ensure_refs()
	_apply_columns()
	set_kind(UIPalette.Row.INERT)

func _ensure_refs() -> void:
	if _name != null:
		return
	_icon = get_node_or_null("Row/Icon") as TextureRect
	_name = get_node_or_null("Row/Name") as Label
	_buy = get_node_or_null("Row/Buy") as Label
	_sell = get_node_or_null("Row/Sell") as Label
	_held = get_node_or_null("Row/Held") as Label
	_avail = get_node_or_null("Row/Avail") as Label
	if _stepper == null:
		_stepper = Stepper.create()
		_stepper.show_sign = true
		_stepper.sign_colored = true
		_stepper.value_changed.connect(_on_stepper_committed)
		get_node("Row").add_child(_stepper)

## Every number from [UIMetrics]/the constants above rather than from the scene,
## the WI-49 split: a `.tscn` must not be able to hold a column width that
## disagrees with the header built beside it.
func _apply_columns() -> void:
	_icon.custom_minimum_size = Vector2(float(ICON_SIZE), float(ICON_SIZE))
	_name.custom_minimum_size.x = float(NAME_MIN_WIDTH)
	_buy.custom_minimum_size.x = float(PRICE_COLUMN)
	_sell.custom_minimum_size.x = float(PRICE_COLUMN)
	_held.custom_minimum_size.x = float(STOCK_COLUMN)
	_avail.custom_minimum_size.x = float(STOCK_COLUMN)
	var row: HBoxContainer = get_node("Row") as HBoxContainer
	row.add_theme_constant_override("separation", COLUMN_GAP)

# --- public -------------------------------------------------------------------

func set_up(trade_resource: ResourceData) -> void:
	_ensure_refs()
	resource = trade_resource
	_name.text = trade_resource.name
	_icon.texture = trade_resource.icon
	_icon.visible = trade_resource.icon != null
	tooltip_text = trade_resource.name

## Repaints the whole line. `limit_buy` and `limit_sell` are positive magnitudes
## from [TradeOffer]; `clamped` says the incoming amount had to be trimmed to fit
## them, which is a thing the player is told rather than a silent correction.
##
## Skips the stepper entirely while the player is working it: a `slow_tick`
## refresh landing mid-drag would otherwise snatch the number back to whatever the
## sim last agreed with.
func refresh(buy_price: int, sell_price: int, held: int, avail: int,
		new_amount: int, limit_buy: int, limit_sell: int, editable: bool,
		clamped: bool = false) -> void:
	_ensure_refs()
	_buy.text = str(buy_price)
	_sell.text = str(sell_price)
	_held.text = str(held)
	_avail.text = str(avail)
	# AVAIL goes amber the moment it is short of HELD: something has been spoken
	# for, and that is precisely when the column has something to say.
	_avail.add_theme_color_override("font_color",
		UIPalette.ATTENTION_TEXT if avail < held else UIPalette.TEXT)
	_stepper.editable = editable
	if not _stepper.is_editing():
		amount = new_amount
		# Buy is the upper bound and sell the lower one: the number counts goods,
		# so the end that adds stock is the positive end.
		_stepper.configure(new_amount, -limit_sell, limit_buy, 1, true)
	_apply_kind(clamped)

## The line's own treatment: cyan while it is set, amber while it has been
## clamped by somebody else's claim, inert while it is not a trade. Direction does
## not enter into it - a sell is not a warning - which is why this is keyed on
## `amount != 0` and not on its sign.
func _apply_kind(clamped: bool) -> void:
	if clamped:
		set_kind(UIPalette.Row.AMBER)
	elif amount != 0:
		set_kind(UIPalette.Row.LIVE)
	else:
		set_kind(UIPalette.Row.INERT)

func set_kind(kind: UIPalette.Row) -> void:
	_ensure_refs()
	add_theme_stylebox_override("panel", UIPalette.row_style(kind))
	_name.add_theme_color_override("font_color", UIPalette.row_text(kind))
	for label: Label in [_buy, _sell, _held]:
		label.add_theme_color_override("font_color", UIPalette.row_meta(kind))

func _on_stepper_committed(value: int) -> void:
	amount = value
	amount_changed.emit(self)

# --- header -------------------------------------------------------------------

## The column captions, built from the same constants the rows are, plus the row
## style's own content insets so the captions sit over their columns rather than
## eight pixels to the left of them.
static func make_header() -> Control:
	var box: StyleBoxFlat = UIPalette.row_style(UIPalette.Row.INERT)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", int(box.content_margin_left))
	pad.add_theme_constant_override("margin_right", int(box.content_margin_right))
	pad.add_theme_constant_override("margin_bottom", UIMetrics.TRADE_ROW_PAD_BOTTOM)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", COLUMN_GAP)
	pad.add_child(row)

	# An empty stand-in for the icon column, so "COMMODITY" starts over the names.
	var icon_gap := Control.new()
	icon_gap.custom_minimum_size.x = float(ICON_SIZE)
	icon_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_gap)

	row.add_child(_caption("Commodity", NAME_MIN_WIDTH, true))
	row.add_child(_caption("Buy @", PRICE_COLUMN))
	row.add_child(_caption("Sell @", PRICE_COLUMN))
	row.add_child(_caption("Held", STOCK_COLUMN))
	row.add_child(_caption("Avail", STOCK_COLUMN))
	row.add_child(_caption("Trade", TRADE_COLUMN, false, HORIZONTAL_ALIGNMENT_CENTER))
	return pad

static func _caption(text: String, width: int, expand: bool = false,
		alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.theme_type_variation = UIType.READOUT_LABEL
	label.add_theme_color_override("font_color", UIPalette.TEXT_META)
	label.custom_minimum_size.x = float(width)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if expand else alignment
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
