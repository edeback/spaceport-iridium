class_name UIPalette
extends RefCounted

## The chrome palette for the console UI (WI-49). Every colour the HUD draws
## comes from here; nothing else in `ui/` may name a hex literal.
##
## The authority for these values is `04_UI_Rework_Program.md`'s palette table.
## Invariant 5 is the reason this is a named list rather than a pile of literals:
## "amber is a budget, not a colour" only holds if there is one place to check
## how many things spend it.
##
## This is deliberately NOT `OverlayPalette` (WI-35). That one maps *gameplay
## values* to the station tint; this one is chrome. They answer different
## questions and a shared cyan would be a coincidence, not a relationship.
##
## Pure: static, no nodes, no Global. The StyleBox/Gradient builders allocate,
## and the ones that are shared cache a single instance - see `_cached_*`.

# --- surfaces -----------------------------------------------------------------

## Play-area base. The nebula is a radial gradient over this, never a texture.
const VOID := Color("05080e")
## Every panel surface. Panels that float over the station run this at 0.94-0.98.
const PANEL := Color("0b111b")
## Console gradient top; CONSOLE_BOTTOM is its foot. The console is the only
## surface allowed a cyan top border.
const CONSOLE := Color("0d1420")
const CONSOLE_BOTTOM := Color("080d15")
## Fill behind an interactive control (button, chip, vital tile, tab).
const CONTROL_FILL := Color("111b27")
## Slightly darker control fill, used for secondary buttons and speed pills.
const CONTROL_FILL_DIM := Color("101a26")
## The track a StatBar's fill sits in - darker than PANEL so the bar reads.
const GAUGE_TRACK := Color("070c14")

# --- edges --------------------------------------------------------------------

## The only border on an inert panel.
const EDGE := Color("1d2c40")
## Internal dividers *inside* a panel (row separators, header rules).
const DIVIDER := Color("16222f")
## Border of an interactive control at rest.
const CONTROL_BORDER := Color("24384f")
## The border a panel wears while it is the active mode, and the border of an
## active tab. Reads as "this one, right now".
const ACTIVE_BORDER := Color("2f6b80")
## Left accent of an inert list row - present so every row has one, dim enough
## that it never competes with a live or amber row.
const INERT_ACCENT := Color("2e4256")
## 1px inner top highlight every panel carries, so a surface reads as lit from
## above rather than as a flat hole.
const INNER_HIGHLIGHT := Color(0.471, 0.745, 0.882, 0.07) # rgba(120,190,225,.07)

# --- states -------------------------------------------------------------------

## Active mode, selection, affordable, positive rate.
const LIVE := Color("4fbfd9")
## The brighter cyan used for text and glyphs sitting on a LIVE-tinted fill,
## where LIVE itself would be too dim to read.
const LIVE_BRIGHT := Color("7fdcef")
## Breach, falling vital, unread transmission, ARC. Budgeted - see invariant 5.
const ATTENTION := Color("e5a34a")
## Amber text on an amber-tinted row (ATTENTION itself is too saturated to read
## as body text).
const ATTENTION_TEXT := Color("f2c377")
## The meta line under ATTENTION_TEXT.
const ATTENTION_META := Color("a68242")
## Border of an amber-tinted row or vital tile.
const ATTENTION_BORDER := Color("8a6524")
## Built modules, biomass, researched tech. Never a UI *state* - a green button
## would collide with "this thing grew".
const GROWTH := Color("4fbf7a")
## Demolish and fire. Outline only, never a filled button (invariant, encoded in
## `ActionButton`).
const DESTRUCTIVE := Color("d4614f")

# --- text ---------------------------------------------------------------------

## Primary body text.
const TEXT := Color("9db9c9")
## Emphasis: entity names, metrics, the value the row is about.
const TEXT_EMPHASIS := Color("eaf6fb")
## Secondary: labels beside a value, inactive tabs.
const TEXT_SECONDARY := Color("738fa5")
## Meta: hotkey hints, timestamps, units, "N MIN AGO".
##
## The most-used style in the HUD - every [ListRow] meta line, every timestamp,
## every panel `footer_text`, every hotkey hint - and at 11px it has to be read,
## not merely noticed. WI-58 lifted it (and TEXT_SECONDARY with it, so the
## dim/dimmer ladder does not invert): the pair used to compute 3.44:1 and 4.37:1
## against [constant PANEL], both under the 4.5:1 floor. They now clear it on
## PANEL, on CONSOLE and on CONTROL_FILL, which are the three surfaces meta text
## actually lands on. `test_ui_palette.gd` pins the ratios.
const TEXT_META := Color("5e88a5")
## The label on a **disabled** control.
##
## Its own token rather than TEXT_META (WI-58), because a disabled control is
## where the design deliberately puts a sentence the player must read: WI-57's
## rule is "a blocked action names its blocker on its own control", so CONTACT
## ARC, HIRE and a contract's ACCEPT all render their reason *as the disabled
## label*. Sharing TEXT_META put that sentence at 3.01:1 on the ActionPrimary
## disabled fill - the least readable text in the build, in the one place the
## design most needs read. Dim enough to still say "you cannot press this".
const TEXT_DISABLED := Color("6d93ad")
## Emphasis text sitting on a LIVE-tinted fill (active tab, selected row).
const TEXT_ON_LIVE := Color("dff1f8")
## Secondary text sitting on a LIVE-tinted fill.
const TEXT_ON_LIVE_DIM := Color("6f93a8")

# --- header gradients ---------------------------------------------------------

## Panel header (56px): warmer and more saturated than the readout header, which
## is half of what makes the two header heights read as a hierarchy.
const PANEL_HEADER_TOP := Color("17303d")
const PANEL_HEADER_BOTTOM := Color("0e1c26")
## Readout header (34px).
const READOUT_HEADER_TOP := Color("152436")
const READOUT_HEADER_BOTTOM := Color("0e1826")

# --- row treatments -----------------------------------------------------------

## The three list-row treatments. Every list in the design is one of these, so
## widgets take the enum rather than three booleans.
enum Row {
	## No fill, dim border, dim left accent. The default for anything reported.
	INERT,
	## Cyan wash - selected, live, affordable, in progress.
	LIVE,
	## Amber wash - breach, falling vital, ARC. Budgeted.
	AMBER,
}

## Fill alpha of a tinted row. Low on purpose: a row is a wash, not a button.
const ROW_LIVE_ALPHA: float = 0.06
const ROW_AMBER_ALPHA: float = 0.10
## Width of a row's left accent bar, and of the border on its other three sides.
const ROW_ACCENT_WIDTH: int = 3
const ROW_BORDER_WIDTH: int = 1

# StyleBoxes and gradients are immutable once built and are shared by every
# widget that asks, so they are built once. A caller that needs to mutate one
# must duplicate() it - documented on each accessor.
static var _cached_rows: Dictionary[Row, StyleBoxFlat] = {}
static var _cached_panel_gradient: GradientTexture2D = null
static var _cached_readout_gradient: GradientTexture2D = null
static var _cached_rule_gradient: GradientTexture2D = null
static var _cached_console_gradient: GradientTexture2D = null

# --- helpers ------------------------------------------------------------------

## `color` at `alpha`, for the rgba(...,.06) washes the design uses constantly.
## Alpha is clamped, so a caller that computes it from a ratio cannot produce an
## invalid Color.
static func tinted(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))

## The colour a signed number is drawn in: cyan when it is going up, amber when
## it is going down, meta grey when it is not moving.
##
## Used by the ledger, the trade table, the stores stepper and the economy tab.
## It lives here because it is exactly the sort of rule that drifts if four
## panels each write their own `if value > 0`.
##
## Zero is compared exactly, and that is deliberate: a rate of 0.0001/cycle is
## genuinely positive and should read as such rather than being rounded into
## "stable" by a threshold the player cannot see. Callers that want a deadband
## round the value first.
static func sign_color(value: float) -> Color:
	if value > 0.0:
		return LIVE
	if value < 0.0:
		return ATTENTION
	return TEXT_META

## Vertical gradient for the 56px panel header. Shared - do not mutate.
static func panel_header_gradient() -> GradientTexture2D:
	if _cached_panel_gradient == null:
		_cached_panel_gradient = _make_gradient(PANEL_HEADER_TOP, PANEL_HEADER_BOTTOM)
	return _cached_panel_gradient

## Vertical gradient for the 34px readout header. Shared - do not mutate.
static func readout_header_gradient() -> GradientTexture2D:
	if _cached_readout_gradient == null:
		_cached_readout_gradient = _make_gradient(READOUT_HEADER_TOP, READOUT_HEADER_BOTTOM)
	return _cached_readout_gradient

## The console strip (WI-50): CONSOLE at the top down to CONSOLE_BOTTOM at the
## foot. The console is the only surface in the game that also wears a cyan top
## border, which is what welds it to the bottom edge instead of floating.
## Shared - do not mutate.
static func console_gradient() -> GradientTexture2D:
	if _cached_console_gradient == null:
		_cached_console_gradient = _make_gradient(CONSOLE, CONSOLE_BOTTOM)
	return _cached_console_gradient

## The rule that trails off to the right of a section label: a hairline that
## fades from a dim cyan into nothing, so a section reads as opening rather than
## as being boxed off. Shared - do not mutate.
static func section_rule_gradient() -> GradientTexture2D:
	if _cached_rule_gradient == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color("1d3f52"))
		gradient.set_color(1, Color(0.113, 0.247, 0.322, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 64
		texture.height = 1
		texture.fill_from = Vector2(0.0, 0.0)
		texture.fill_to = Vector2(1.0, 0.0)
		_cached_rule_gradient = texture
	return _cached_rule_gradient

## Top-to-bottom two-stop gradient texture, 1px wide - callers stretch it.
static func _make_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1
	texture.height = 64
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture

## Inert list row: no fill, dim border, dim left accent. Shared - duplicate() to
## mutate.
static func inert_row() -> StyleBoxFlat:
	return row_style(Row.INERT)

## Live list row: cyan wash, control border, LIVE left accent.
static func live_row() -> StyleBoxFlat:
	return row_style(Row.LIVE)

## Amber list row: amber wash, amber border, ATTENTION left accent.
static func amber_row() -> StyleBoxFlat:
	return row_style(Row.AMBER)

## Row treatment by kind, so widgets can take the enum straight from their
## caller instead of branching over three functions. Shared - duplicate() to
## mutate.
static func row_style(kind: Row) -> StyleBoxFlat:
	if not _cached_rows.has(kind):
		_cached_rows[kind] = _make_row(kind)
	return _cached_rows[kind]

static func _make_row(kind: Row) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	match kind:
		Row.LIVE:
			box.bg_color = tinted(LIVE, ROW_LIVE_ALPHA)
			box.border_color = CONTROL_BORDER
		Row.AMBER:
			box.bg_color = tinted(ATTENTION, ROW_AMBER_ALPHA)
			box.border_color = ATTENTION_BORDER
		_:
			box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			box.border_color = DIVIDER
	box.set_border_width_all(ROW_BORDER_WIDTH)
	box.border_width_left = ROW_ACCENT_WIDTH
	box.set_content_margin_all(11.0)
	box.content_margin_left = 11.0 + float(ROW_ACCENT_WIDTH)
	# Godot draws a single border colour per box, so the left accent - which is a
	# different colour from the other three sides in the design - is drawn by the
	# widget as a child ColorRect. `row_accent()` is that colour.
	return box

# --- gauges (WI-58) -------------------------------------------------------------

## Where a gauge stops being a *level* and starts being a falling vital.
##
## Amber is a budget (invariant 5), and "anything under 1.0" is not a spend of
## it - it is every module that has ever been scratched, every drone that has
## done a day's work, every bar in the inspector. A module at 99% integrity is
## not an alarm; one at 20% is.
const GAUGE_LOW: float = 0.35

## The tint a gauge fill takes for `fraction`, and the only place that rule
## lives.
##
## Callers with a **real predicate** for "this needs attention" should use it
## instead and pass the answer to [StatBar] directly -
## `RobotPowerComponent.wants_recharge()` and
## `RobotIntegrityComponent.wants_repair()` are both better than a threshold,
## because they are the same test the pawn itself acts on. This is for the gauges
## that have no such predicate to borrow.
static func gauge_tint(fraction: float) -> Color:
	return ATTENTION if fraction < GAUGE_LOW else LIVE

# --- shift grids (WI-58) --------------------------------------------------------

## A schedule cell: on duty, off duty, and the now-marker for each.
##
## One vocabulary for one fact. The Crew panel's SHIFT ROTA and the inspector's
## per-pawn schedule editor paint the identical on/off-shift grid one keypress
## apart, and until WI-58 they did it in two different colour languages - the
## editor named `Color(0.29, 0.55, 0.85)` and `Color(0.22, 0.22, 0.28)` as raw
## floats, which is the palette's own rule broken in the file the player is most
## likely to compare against the panel next door.
static func shift_cell(working: bool, is_now: bool = false) -> Color:
	if is_now:
		# The one cell that says where in the cycle we are, so a grid of two shifts
		# is legible without reading the ruler.
		return LIVE if working else CONTROL_BORDER
	return tinted(LIVE, 0.55) if working else tinted(EDGE, 0.9)

## The colour of a row's left accent bar, which is brighter than the row's other
## three borders and therefore cannot live in the StyleBox.
static func row_accent(kind: Row) -> Color:
	match kind:
		Row.LIVE:
			return LIVE
		Row.AMBER:
			return ATTENTION
		_:
			return INERT_ACCENT

## Primary text colour inside a row of this kind.
static func row_text(kind: Row) -> Color:
	match kind:
		Row.LIVE:
			return TEXT_ON_LIVE
		Row.AMBER:
			return ATTENTION_TEXT
		_:
			return TEXT

## Meta-line colour inside a row of this kind.
static func row_meta(kind: Row) -> Color:
	match kind:
		Row.LIVE:
			return TEXT_ON_LIVE_DIM
		Row.AMBER:
			return ATTENTION_META
		_:
			return TEXT_META
