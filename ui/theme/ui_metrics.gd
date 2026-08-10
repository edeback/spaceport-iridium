class_name UIMetrics
extends RefCounted

## The console UI's geometry table as code (WI-49). Authority is
## `04_UI_Rework_Program.md`'s geometry table.
##
## These are `const`, not exported vars, on purpose. Balance numbers belong in
## `.tres` (standing project invariant) - but these are not balance, they are a
## design system: a panel whose width can be edited per-instance is a panel that
## ends up 358px wide in one scene and 356 in the other eight, and invariant 6
## says frame inconsistency is most of what looks unfinished.
##
## The project runs a 1920x1080 viewport with stretch mode "viewport" and aspect
## "expand" (project.godot), so these pixel values map 1:1 to viewport
## coordinates with no scaling maths. "expand" hands a wider display extra
## *width*, which is why panels take a fixed width from this table and anchor to
## an edge rather than taking a fraction of the screen: a 1180px Trade table
## reflowed to 60% of an ultrawide would be unreadable.
##
## Pure: static, no nodes, no Global.

## Design resolution. The derived helpers default to this; they take an explicit
## height so they stay pure and testable.
const SCREEN_SIZE := Vector2i(1920, 1080)

# --- console ------------------------------------------------------------------

## Console strip: full width, welded to the bottom edge.
const CONSOLE_HEIGHT: int = 112
## One mode button. Nine of them (seven modes, a divider, two utilities).
const MODE_BUTTON := Vector2(70, 74)
const MODE_BUTTON_GAP: int = 5
## Console zones: modes / vitals (flex) / time.
const CONSOLE_MODES_WIDTH: int = 715
const CONSOLE_TIME_WIDTH: int = 247
## Height of a vitals tile and of the ledger chip in the console strip.
const CONSOLE_TILE_HEIGHT: int = 52

# --- panels -------------------------------------------------------------------

## Left-mounted mode panels. Fixed widths, one per mode.
const PANEL_OVERLAYS_WIDTH: int = 360
const PANEL_BUILD_WIDTH: int = 356
## The Build panel's flyout sits beside the rail, not inside it (696 total).
const PANEL_BUILD_FLYOUT_WIDTH: int = 340
const PANEL_COMMS_WIDTH: int = 620
const PANEL_CREW_WIDTH: int = 660
const PANEL_STORES_WIDTH: int = 1080
const PANEL_TRADE_WIDTH: int = 1180
const PANEL_RD_WIDTH: int = 1400

## The 56px panel header and the 34px readout header are different heights on
## purpose - that difference is what makes the hierarchy read, which is why
## `ReadoutPanel` is not `ConsolePanel` with a parameter.
const PANEL_HEADER_HEIGHT: int = 56
const READOUT_HEADER_HEIGHT: int = 34

## Horizontal padding inside each header.
const PANEL_HEADER_PAD: int = 16
const READOUT_HEADER_PAD: int = 12
## Gap between items in a header row.
const PANEL_HEADER_GAP: int = 12
const READOUT_HEADER_GAP: int = 10

## The accent bar that opens every header: 3px wide, taller in the panel header.
const ACCENT_BAR_WIDTH: int = 3
const PANEL_ACCENT_HEIGHT: int = 20
const READOUT_ACCENT_HEIGHT: int = 14

## Outward drop shadow so a panel reads as floating over the station.
const PANEL_SHADOW_SIZE: int = 28
const READOUT_SHADOW_SIZE: int = 18

## Panels float over the station, so they are not fully opaque. The inspector
## sits closest to the player's attention and is the least transparent.
const PANEL_ALPHA: float = 0.96
const READOUT_ALPHA: float = 0.94
const INSPECTOR_ALPHA: float = 0.97

# --- right column -------------------------------------------------------------

## Map, alerts and inspector own the right edge permanently (invariant 3).
const RIGHT_COLUMN_WIDTH: int = 344
## Gap from the screen edge, and between stacked readouts.
const SCREEN_GUTTER: int = 20
## The inspector is wider than the rest of the right column - it carries tab
## sets, not a single readout.
const INSPECTOR_WIDTH: int = 420

# --- shared spacing -----------------------------------------------------------

const BORDER_WIDTH: int = 1
## Padding inside a panel's content region.
const CONTENT_PAD: int = 16
## Padding inside a readout's content region - tighter, they are smaller.
const READOUT_CONTENT_PAD: int = 10
## Vertical gap between rows in a list.
const ROW_GAP: int = 6
## Vertical gap between sections in a panel.
const SECTION_GAP: int = 14

# --- type ---------------------------------------------------------------------

## Tracking, in pixels, for each tracked type variation. Godot's [Font] has no
## letter-spacing, so the design's em-relative tracking is baked into the
## theme's [FontVariation]s as `spacing_glyph` - an integer pixel value. These
## constants are what the theme is built from and what widgets compensate
## against; see [UIType].
##
## .18em at 15px.
const TRACKING_PANEL_TITLE: int = 3
## .20em at 11px.
const TRACKING_READOUT_LABEL: int = 2
## .06em at 11px, rounded up - one pixel is the smallest tracking there is.
const TRACKING_META: int = 1
## .10em at 9px / 12px.
const TRACKING_MODE_LABEL: int = 1
const TRACKING_TAB_LABEL: int = 1
## Buttons carry the same light tracking as tab labels.
const TRACKING_BUTTON: int = 1

## `spacing_glyph` adds space *after* every glyph, including the last, so a
## centred tracked label sits visibly left of centre by half the tracking. A
## widget that centres such a label shifts it right by this much rather than
## every caller nudging its own label.
static func tracking_center_nudge(tracking: int) -> float:
	return float(tracking) * 0.5

# --- derived ------------------------------------------------------------------

## Y of the bottom edge of a left panel: it runs from the top of the screen to
## the top of the console.
static func panel_bottom(screen_height: int = SCREEN_SIZE.y) -> int:
	return screen_height - CONSOLE_HEIGHT

## Full height of a left panel.
static func panel_height(screen_height: int = SCREEN_SIZE.y) -> int:
	return panel_bottom(screen_height)

## Height of a left panel's content region, below its 56px header.
static func panel_content_height(screen_height: int = SCREEN_SIZE.y) -> int:
	return panel_height(screen_height) - PANEL_HEADER_HEIGHT

## Y of the top of the inspector, which is bottom-anchored one gutter above the
## console. Its height varies with its tab set, so it is a parameter.
static func inspector_top(inspector_height: int, screen_height: int = SCREEN_SIZE.y) -> int:
	return screen_height - CONSOLE_HEIGHT - SCREEN_GUTTER - inspector_height

## Distance from the bottom of the screen to the bottom of the inspector - the
## offset the inspector anchors at, and the value that does not change when its
## content does.
static func inspector_bottom_offset() -> int:
	return CONSOLE_HEIGHT + SCREEN_GUTTER

## Width of the mode-button zone actually consumed by `count` buttons plus their
## gaps (no trailing gap). The console reserves CONSOLE_MODES_WIDTH; this is what
## fits inside it.
static func mode_zone_width(count: int) -> float:
	if count <= 0:
		return 0.0
	return MODE_BUTTON.x * float(count) + MODE_BUTTON_GAP * float(count - 1)
