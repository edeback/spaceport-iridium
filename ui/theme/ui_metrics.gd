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

# --- vitals & ledger (WI-52) --------------------------------------------------

## One pinned vitals chip. Fixed, not content-sized: a chip that grew when its
## number gained a digit would re-lay the whole strip out several times a second
## and visibly jitter. The number gets a compact form instead
## ([method LedgerModel.format_compact]).
const VITALS_CHIP_WIDTH: int = 108
const VITALS_CHIP_GAP: int = 6
## The fixed right-hand `LEDGER · 18 ▸` control. Wider than a vitals chip because
## it carries a word rather than a number.
const LEDGER_CHIP_WIDTH: int = 132

## The ledger flyout: four columns above the console, stopping short of the right
## column.
const LEDGER_WIDTH: int = 760
const LEDGER_COLUMN_WIDTH: int = 176
const LEDGER_COLUMN_GAP: int = 8
## Distance from the right edge of the screen the flyout must stop at, so it
## never opens over the map, the alert feed or the inspector: the right column
## plus its own gutter plus one more.
const LEDGER_RIGHT_INSET: int = RIGHT_COLUMN_WIDTH + SCREEN_GUTTER * 2
## Tallest the flyout may become before its columns start scrolling. Leaves the
## station map and one gutter untouched above it, same budget the inspector uses.
const LEDGER_TOP_LIMIT: int = 280

## Room the console's flex zone actually has for chips, at a given screen width.
## The two zone dividers are 1px each.
static func vitals_zone_width(screen_width: int = SCREEN_SIZE.x) -> float:
	return float(screen_width - CONSOLE_MODES_WIDTH - CONSOLE_TIME_WIDTH - BORDER_WIDTH * 2
		- CONTENT_PAD * 2)

## Width `count` vitals chips plus the ledger chip consume, gaps included. The
## strip asserts this against [method vitals_zone_width] when it builds, so a
## seventh pin cannot silently push the ledger chip off the edge.
static func vitals_strip_width(count: int) -> float:
	if count <= 0:
		return float(LEDGER_CHIP_WIDTH)
	return float(VITALS_CHIP_WIDTH * count + VITALS_CHIP_GAP * count + LEDGER_CHIP_WIDTH)

## Tallest the ledger flyout's content region may become.
static func ledger_max_content_height(screen_height: int = SCREEN_SIZE.y) -> int:
	return maxi(0, screen_height - CONSOLE_HEIGHT - SCREEN_GUTTER - LEDGER_TOP_LIMIT
		- READOUT_HEADER_HEIGHT)

# --- panels -------------------------------------------------------------------

## Left-mounted mode panels. Fixed widths, one per mode.
const PANEL_OVERLAYS_WIDTH: int = 360
const PANEL_BUILD_WIDTH: int = 356
## The Build panel's flyout sits beside the rail, not inside it (696 total).
const PANEL_BUILD_FLYOUT_WIDTH: int = 340
## X the flyout's own frame starts at: flush against the rail panel's right edge,
## so the two borders read as one seam and the pair measures exactly 696.
const PANEL_BUILD_FLYOUT_LEFT: int = PANEL_BUILD_WIDTH

## Build's four icon sizes, all square by construction. The rail and the row
## icons differ because a rail entry is a heading and a module row is a line
## item; the selected row's is larger again because it heads its own block.
const BUILD_RAIL_ICON: int = 34
const BUILD_ROW_ICON: int = 38
const BUILD_SELECTED_ICON: int = 44
## The recent strip is icon-only, so its square is the whole control.
const BUILD_RECENT_ICON: int = 40
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

## Padding inside the full-bleed footer strip some panels carry (WI-54) - the
## "CLICK TO HOLD · ESC CANCEL" line under Build's flyout and the "the overlay
## keeps painting" line under Overlays. Tighter vertically than the content pad
## because it is one line of meta text, not a region.
const PANEL_FOOTER_PAD_H: int = 16
const PANEL_FOOTER_PAD_V: int = 13

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

## Height of the station map readout, the first thing in the right column.
const STATION_MAP_HEIGHT: int = 240

## Y the inspector's top edge may never cross (WI-51), when the readouts above it
## are at their shortest. The inspector is bottom-anchored and grows *upward*
## with its content, so a module with eight component tabs would otherwise climb
## into the readouts above.
##
## This is the **floor**, not the answer. WI-53 stacked a second readout under
## the map and a third (the raid readout) that comes and goes, so the live limit
## is whatever the column's bottom edge currently is - [UIMain] measures the
## stack and pushes it into [member InspectorPanel.top_limit]. Baking a worst
## case into the constant instead would have cost the inspector 300px
## permanently, on a station that mostly has an empty alert feed.
const INSPECTOR_TOP_LIMIT: int = SCREEN_GUTTER + STATION_MAP_HEIGHT + SCREEN_GUTTER

## Side of the subject block's icon.
const INSPECTOR_ICON_SIZE: int = 50

## Tallest the inspector may become before its tab content starts scrolling
## inside itself instead of pushing the panel further up the screen.
static func inspector_max_height(screen_height: int = SCREEN_SIZE.y,
		top_limit: int = INSPECTOR_TOP_LIMIT) -> int:
	return maxi(0, screen_height - CONSOLE_HEIGHT - SCREEN_GUTTER - top_limit)

## The same, less the 34px readout header - the budget the tab set's content
## region actually has to fit into.
static func inspector_max_content_height(screen_height: int = SCREEN_SIZE.y,
		top_limit: int = INSPECTOR_TOP_LIMIT) -> int:
	return maxi(0, inspector_max_height(screen_height, top_limit) - READOUT_HEADER_HEIGHT)

# --- alerts (WI-53) -------------------------------------------------------------

## Tallest the alert feed may become. Bounded because the feed shares the right
## column with the inspector: an unbounded feed on a bad cycle would squeeze the
## selection surface to nothing exactly when the player most wants to click
## something.
##
## Sized to hold [constant AlertRules.FEED_CAP] rows plus the `+ n more` line
## without an inner scrollbar. The two limits must agree; see that constant.
const ALERT_FEED_MAX_HEIGHT: int = 400

## The live-raid readout that replaced WI-32's top-centre banner. Fixed, because
## it appears and disappears mid-fight and a box that also *resized* under the
## player's cursor would be worse than the banner it replaces.
const ALERT_RAID_HEIGHT: int = 96

## The history flyout, opened from the feed's HISTORY action. It sits to the left
## of the right column and never over it - the same rule
## [constant LEDGER_RIGHT_INSET] encodes for the console's flyouts.
const ALERT_HISTORY_WIDTH: int = 480
const ALERT_HISTORY_MAX_HEIGHT: int = 560
## Distance from the right edge the flyout must stop at: the right column plus
## its own gutter plus one more.
const ALERT_HISTORY_RIGHT_INSET: int = RIGHT_COLUMN_WIDTH + SCREEN_GUTTER * 2

## Tallest the feed's content region may become.
static func alert_feed_max_content_height() -> int:
	return maxi(0, ALERT_FEED_MAX_HEIGHT - READOUT_HEADER_HEIGHT)

## Tallest the history flyout's content region may become.
static func alert_history_max_content_height() -> int:
	return maxi(0, ALERT_HISTORY_MAX_HEIGHT - READOUT_HEADER_HEIGHT)

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
