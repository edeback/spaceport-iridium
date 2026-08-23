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
## Widened from 108 in WI-58: at the old width a two-reactor station's energy
## chip ("3200" over "/4000") measured past the tile and the chip - a
## [PanelContainer], so its minimum is `max(custom_minimum_size, children)` -
## grew and re-laid the whole strip out. Exactly the jitter this constant and
## `vitals_chip.gd`'s class docs both assert cannot happen.
const VITALS_CHIP_WIDTH: int = 124
const VITALS_CHIP_GAP: int = 6

## Room reserved inside a chip for the value itself. The suffix takes what is
## left, so there is one number to retune rather than two that have to add up.
##
## Reserving it is what makes the fixed chip width structural rather than
## aspirational: both labels carry an overrun behaviour, which drops a [Label]'s
## reported minimum width to ~1, and a [BoxContainer] with no expanding child
## hands every child exactly its minimum - so without a reserve the numbers
## would collapse instead of the tile growing. Wide enough for four mono digits
## at [constant UIType.METRIC_LARGE]; past that
## [method LedgerModel.format_compact] shortens the number rather than the tile
## widening.
const VITALS_VALUE_WIDTH: int = 42
## The fixed right-hand `LEDGER · 18 ▸` control. Wider than a vitals chip because
## it carries a word rather than a number.
const LEDGER_CHIP_WIDTH: int = 132

## The ledger flyout: four columns above the console, stopping short of the right
## column.
##
## Widened in WI-58. At 760 the arithmetic left each column 178px, and a
## [ListRow] spends 25 of that on its content margins, 24 on the icon, 20 on two
## separators and the rest of its slack on the right-hand rate - which left the
## name and its meta line about **72px**, against roughly 78 for "Iridium Ore"
## alone. Every resource name in the ledger was ellipsed. There is room: the only
## hard constraint is [constant LEDGER_RIGHT_INSET], and the flyout is allowed to
## float over an open mode panel (it already did).
const LEDGER_WIDTH: int = 1080
const LEDGER_COLUMN_WIDTH: int = 254
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
## AIDE (WI-63). The same 620 as Comms, deliberately: both are lists of things
## somebody said, and two reading surfaces of different widths in the same console
## would read as an accident rather than a decision.
const PANEL_AIDE_WIDTH: int = PANEL_COMMS_WIDTH
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

## The floor the selection surface may never be squeezed under (WI-58).
##
## Sized to the inspector's own chrome - subject block, tab strip, footer - plus
## roughly two rows of whatever tab is open. It exists because the right column
## has three tenants and only the inspector has nowhere to overflow to: the feed
## has a `+ n more` row and a history flyout, the map folds, and the raid readout
## is temporary, but a squeezed inspector simply stops showing the thing the
## player just clicked.
##
## What it fixes: with the feed's old fixed 400px cap plus the 96px raid readout
## above it, the inspector's budget computed to 98px against 152px of its own
## chrome, so the tab content region resolved to exactly **zero** and the subject
## block, strip and footer overflowed the frame's rect. The feed yields to this
## instead - see [method alert_feed_max_height].
const INSPECTOR_MIN_CONTENT_HEIGHT: int = 220

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

## Tallest the alert feed may become, with the raid readout stacked above it or
## not (WI-58).
##
## Derived rather than a constant, because the feed is the readout that **yields**.
## The right column is map / raid / feed / inspector, and the raid readout comes
## and goes mid-fight - so a fixed feed cap has to be right for both stacks or
## wrong for one. WI-53's 400px was chosen for the two-readout column and never
## revisited when the raid readout landed above it, which is how the inspector
## ended up with a zero-height content region during a raid.
##
## The subtraction runs bottom-up from the screen: the console, the gutter above
## it, the inspector's floor plus its own 34px header, the gutter above the
## inspector, then the readouts stacked above the feed and their gutters. What is
## left is the feed's.
##
## **This and [constant AlertRules.FEED_CAP] must still agree** in the ordinary
## no-raid column: the cap is 4 rows plus the `+ n more` line, and the height
## returned here has to render them without an inner scrollbar or the two
## disagree about how many rows are hidden. During a raid the feed deliberately
## drops below that and scrolls - it is the tenant with somewhere to put the
## overflow, and the inspector is not.
static func alert_feed_max_height(raid_visible: bool,
		screen_height: int = SCREEN_SIZE.y) -> int:
	# Everything the column owes the tenants above and below the feed.
	var used: int = SCREEN_GUTTER + STATION_MAP_HEIGHT + SCREEN_GUTTER
	if raid_visible:
		used += ALERT_RAID_HEIGHT + SCREEN_GUTTER
	used += SCREEN_GUTTER + READOUT_HEADER_HEIGHT + INSPECTOR_MIN_CONTENT_HEIGHT
	return maxi(0, screen_height - CONSOLE_HEIGHT - SCREEN_GUTTER - used)

## Tallest the feed's content region may become - the same budget less its own
## 34px header.
static func alert_feed_max_content_height(raid_visible: bool,
		screen_height: int = SCREEN_SIZE.y) -> int:
	return maxi(0, alert_feed_max_height(raid_visible, screen_height) - READOUT_HEADER_HEIGHT)

## Tallest the history flyout's content region may become.
static func alert_history_max_content_height() -> int:
	return maxi(0, ALERT_HISTORY_MAX_HEIGHT - READOUT_HEADER_HEIGHT)

# --- dialogue -----------------------------------------------------------------

## The dialogue balloon (`ui/dialogue/balloon.tscn`). Fixed width for the same
## reason every panel width here is fixed: the balloon is a reading surface, and
## prose reflowed to the width of an ultrawide is a worse read, not a better one.
const DIALOGUE_WIDTH: int = 800

## Side of the speaker portrait. Square by construction - the portrait art is
## square, and a rect that is not would letterbox it.
const DIALOGUE_PORTRAIT: int = 128

## The "press to continue" chevron under the text. One constant for both the
## triangle the balloon builds and the space reserved for it, so the glyph and
## its slot cannot disagree.
const DIALOGUE_INDICATOR := Vector2(20, 10)

# --- the coach mark -----------------------------------------------------------
# WI-63 §3. The overlay that points at a piece of the interface - the fourth kind
# of surface, after the mode panel, the readout and the modal.

## Width of the instruction plate. Narrower than the balloon on purpose: the
## plate carries one imperative sentence, and a wide plate would read as prose
## and cover the control it is pointing at.
const COACH_PLATE_WIDTH: int = 320

## Side of SAI's face on the plate. A quarter of [constant DIALOGUE_PORTRAIT] -
## the plate identifies the speaker, it does not present them.
const COACH_PORTRAIT: int = 48

## Border of the ring drawn around the marked control. Two pixels rather than
## [constant BORDER_WIDTH]: the ring sits on top of controls that already carry a
## 1px edge, and a ring the same weight as the thing under it does not read.
const COACH_RING_WIDTH: int = 2

## How far outside the marked control the ring sits, so it frames rather than
## overlaps.
const COACH_RING_PAD: int = 4

## Gap between the ring and the plate beside it.
const COACH_PLATE_GAP: int = 12

## Seconds for one full pulse of the ring, and the alpha range it travels.
##
## **Real seconds, not sim seconds.** The tutorial runs entirely while the sim is
## held, and [method TimeManager.animation_speed] returns 0 while paused - a pulse
## driven off sim time would sit frozen for the whole onboarding.
const COACH_PULSE_PERIOD: float = 1.6
const COACH_PULSE_MIN_ALPHA: float = 0.35
const COACH_PULSE_MAX_ALPHA: float = 1.0

# --- shared spacing -----------------------------------------------------------

const BORDER_WIDTH: int = 1
## Padding inside a panel's content region.
const CONTENT_PAD: int = 16
## Padding inside a readout's content region - tighter, they are smaller.
const READOUT_CONTENT_PAD: int = 10
## Vertical gap between rows in a list.
const ROW_GAP: int = 6

## Width reserved for a [ListRow]'s right-hand action slot - "JUMP ▸", "+12.4/C",
## "RESUME ▸".
##
## Both halves matter (WI-58). Without a *reserved* width the slot is laid out at
## its text's own minimum, so a long verb eats the expanding name/meta block
## before anything else gives; without an *overrun behaviour* on the same label
## that minimum is the full string, so the slot could not be capped at all. The
## pair is why a resource name now gets the column's slack and a long verb
## ellipses instead.
const LIST_ROW_ACTION_WIDTH: int = 72
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

## Applies [method tracking_center_nudge] to a control's content box.
##
## Godot gives a [Label] and a [Button] no text-offset property at all, so the
## style box's content margins are the only lever. Adding to **one** side moves
## a centred text by half what you added - so the whole tracking goes on the
## left, and the resulting shift is exactly the half-tracking the nudge is. The
## symmetry is not a coincidence; it is the same "one trailing gap, split two
## ways" arithmetic in both directions.
##
## A negative right margin would be the other obvious way to do it and does not
## work: [StyleBox] reads a negative content margin as "unset" and falls back to
## the style's own, so the value is silently discarded.
##
## Callers hand in the box because a tab's fill and border live in that same box
## and have to survive the nudge.
static func nudge_content_box(box: StyleBox, tracking: int) -> StyleBox:
	var shifted: StyleBox = box.duplicate() as StyleBox
	shifted.content_margin_left = box.get_content_margin(SIDE_LEFT) + float(tracking)
	shifted.content_margin_right = box.get_content_margin(SIDE_RIGHT)
	shifted.content_margin_top = box.get_content_margin(SIDE_TOP)
	shifted.content_margin_bottom = box.get_content_margin(SIDE_BOTTOM)
	return shifted

## The nudge for a control with no box of its own - a bare centred [Label]. An
## empty box carries nothing but the margins, so overriding `normal` with it
## costs the label no appearance.
static func tracking_center_box(tracking: int) -> StyleBoxEmpty:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = float(tracking)
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	return box

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
