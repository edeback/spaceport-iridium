extends GutTest

## Unit tests for WI-49's pure chrome design system: UIPalette (value -> colour /
## StyleBox rules) and UIMetrics (the geometry table and its derived values).
## Both are static, no nodes, no Global.

# --- sign_color ---------------------------------------------------------------

func test_sign_color_positive_is_live() -> void:
	assert_eq(UIPalette.sign_color(1.0), UIPalette.LIVE, "a rising number reads cyan")
	assert_eq(UIPalette.sign_color(0.0001), UIPalette.LIVE, "a barely rising number still reads cyan")
	assert_eq(UIPalette.sign_color(9999.0), UIPalette.LIVE, "magnitude does not change the sign colour")

func test_sign_color_negative_is_attention() -> void:
	assert_eq(UIPalette.sign_color(-1.0), UIPalette.ATTENTION, "a falling number reads amber")
	assert_eq(UIPalette.sign_color(-0.0001), UIPalette.ATTENTION, "a barely falling number still reads amber")

func test_sign_color_zero_is_meta() -> void:
	assert_eq(UIPalette.sign_color(0.0), UIPalette.TEXT_META, "a flat number is not a state")

## Godot's float zero has a signed variant, and `-0.0 < 0.0` is false - so a
## computed rate that lands on negative zero must read as flat, not as falling.
func test_sign_color_negative_zero_is_meta() -> void:
	assert_eq(UIPalette.sign_color(-0.0), UIPalette.TEXT_META, "negative zero is still zero")

## The three sign colours must be distinguishable, or the rule buys nothing.
func test_sign_colors_are_distinct() -> void:
	assert_ne(UIPalette.sign_color(1.0), UIPalette.sign_color(-1.0), "up and down differ")
	assert_ne(UIPalette.sign_color(1.0), UIPalette.sign_color(0.0), "up and flat differ")
	assert_ne(UIPalette.sign_color(-1.0), UIPalette.sign_color(0.0), "down and flat differ")

# --- tinted -------------------------------------------------------------------

func test_tinted_keeps_rgb_and_sets_alpha() -> void:
	var c: Color = UIPalette.tinted(UIPalette.LIVE, 0.06)
	assert_almost_eq(c.r, UIPalette.LIVE.r, 0.0001, "red preserved")
	assert_almost_eq(c.g, UIPalette.LIVE.g, 0.0001, "green preserved")
	assert_almost_eq(c.b, UIPalette.LIVE.b, 0.0001, "blue preserved")
	assert_almost_eq(c.a, 0.06, 0.0001, "alpha applied")

func test_tinted_clamps_alpha() -> void:
	assert_almost_eq(UIPalette.tinted(UIPalette.LIVE, 5.0).a, 1.0, 0.0001, "alpha above 1 clamps")
	assert_almost_eq(UIPalette.tinted(UIPalette.LIVE, -2.0).a, 0.0, 0.0001, "alpha below 0 clamps")

func test_tinted_does_not_mutate_the_source_constant() -> void:
	var before: Color = UIPalette.LIVE
	var _ignored: Color = UIPalette.tinted(UIPalette.LIVE, 0.5)
	assert_eq(UIPalette.LIVE, before, "the palette constant is untouched")

# --- contrast (WI-58) ----------------------------------------------------------

## WCAG 2.1 relative luminance. Local to the suite rather than on [UIPalette],
## because nothing in the game computes a contrast ratio at runtime - this is a
## drift guard over a hand-picked table, and the table is what has to hold.
func _luminance(color: Color) -> float:
	var channels: Array[float] = [color.r, color.g, color.b]
	var weights: Array[float] = [0.2126, 0.7152, 0.0722]
	var total: float = 0.0
	for index: int in 3:
		var channel: float = channels[index]
		var linear: float = (channel / 12.92 if channel <= 0.03928
			else pow((channel + 0.055) / 1.055, 2.4))
		total += linear * weights[index]
	return total

func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## `over` composites a translucent fill onto an opaque surface, which is what a
## tinted row or a disabled button fill actually is.
func _over(fill: Color, surface: Color) -> Color:
	return Color(
		fill.r * fill.a + surface.r * (1.0 - fill.a),
		fill.g * fill.a + surface.g * (1.0 - fill.a),
		fill.b * fill.a + surface.b * (1.0 - fill.a))

## The floor. 4.5:1 is WCAG AA for body text, and every one of these styles is
## body-sized or smaller.
const MIN_RATIO: float = 4.5

## Every text token has to clear the floor on every surface it actually lands on.
## TEXT_META is the one that motivated the item - it was 3.44:1, at 11px, on the
## most-used style in the HUD.
func test_text_tokens_clear_the_contrast_floor_on_every_surface() -> void:
	var surfaces: Dictionary[String, Color] = {
		"PANEL": UIPalette.PANEL,
		"CONSOLE": UIPalette.CONSOLE,
		"CONTROL_FILL": UIPalette.CONTROL_FILL,
	}
	var tokens: Dictionary[String, Color] = {
		"TEXT": UIPalette.TEXT,
		"TEXT_EMPHASIS": UIPalette.TEXT_EMPHASIS,
		"TEXT_SECONDARY": UIPalette.TEXT_SECONDARY,
		"TEXT_META": UIPalette.TEXT_META,
		"TEXT_DISABLED": UIPalette.TEXT_DISABLED,
	}
	for token: String in tokens:
		for surface: String in surfaces:
			assert_gte(_contrast(tokens[token], surfaces[surface]), MIN_RATIO,
				"%s on %s" % [token, surface])

## The disabled label is where WI-57's "a blocked action names its blocker on its
## own control" rule lands, so it has to be readable on the *filled* primary
## button as well as on the flat ones.
func test_disabled_label_is_readable_on_the_primary_button_fill() -> void:
	var fill: Color = _over(UIPalette.tinted(UIPalette.LIVE, 0.088), UIPalette.PANEL)
	assert_gte(_contrast(UIPalette.TEXT_DISABLED, fill), MIN_RATIO,
		"a disabled ActionPrimary still reads its own sentence")

## A tinted row's text and meta line have to clear the floor over the wash, not
## just over the bare panel.
func test_row_text_clears_the_floor_over_its_own_wash() -> void:
	var washes: Dictionary[UIPalette.Row, Color] = {
		UIPalette.Row.INERT: UIPalette.PANEL,
		UIPalette.Row.LIVE: _over(UIPalette.tinted(UIPalette.LIVE, UIPalette.ROW_LIVE_ALPHA),
			UIPalette.PANEL),
		UIPalette.Row.AMBER: _over(UIPalette.tinted(UIPalette.ATTENTION, UIPalette.ROW_AMBER_ALPHA),
			UIPalette.PANEL),
	}
	for kind: UIPalette.Row in washes:
		assert_gte(_contrast(UIPalette.row_text(kind), washes[kind]), MIN_RATIO,
			"row %d name" % kind)
		assert_gte(_contrast(UIPalette.row_meta(kind), washes[kind]), MIN_RATIO,
			"row %d meta" % kind)

## The dim ladder has to stay in order, or lifting one token to fix its contrast
## silently makes "meta" brighter than "secondary".
func test_the_text_dimness_ladder_stays_ordered() -> void:
	var meta: float = _contrast(UIPalette.TEXT_META, UIPalette.PANEL)
	var secondary: float = _contrast(UIPalette.TEXT_SECONDARY, UIPalette.PANEL)
	var body: float = _contrast(UIPalette.TEXT, UIPalette.PANEL)
	var emphasis: float = _contrast(UIPalette.TEXT_EMPHASIS, UIPalette.PANEL)
	assert_lt(meta, secondary, "meta is dimmer than secondary")
	assert_lt(secondary, body, "secondary is dimmer than body")
	assert_lt(body, emphasis, "body is dimmer than emphasis")

# --- row treatments -----------------------------------------------------------

func test_the_three_row_treatments_are_distinct() -> void:
	var inert: StyleBoxFlat = UIPalette.inert_row()
	var live: StyleBoxFlat = UIPalette.live_row()
	var amber: StyleBoxFlat = UIPalette.amber_row()
	assert_ne(inert.bg_color, live.bg_color, "inert and live fills differ")
	assert_ne(live.bg_color, amber.bg_color, "live and amber fills differ")
	assert_ne(inert.border_color, amber.border_color, "inert and amber borders differ")

func test_inert_row_has_no_fill() -> void:
	assert_almost_eq(UIPalette.inert_row().bg_color.a, 0.0, 0.0001,
		"an inert row is a border, not a surface")

func test_tinted_rows_are_a_wash_not_a_button() -> void:
	# A row fill heavy enough to read as a pressed control would fight the
	# selection state it is supposed to support.
	assert_lt(UIPalette.live_row().bg_color.a, 0.2, "live wash stays light")
	assert_lt(UIPalette.amber_row().bg_color.a, 0.2, "amber wash stays light")

func test_row_left_border_is_the_accent_width() -> void:
	for kind: UIPalette.Row in [UIPalette.Row.INERT, UIPalette.Row.LIVE, UIPalette.Row.AMBER]:
		var box: StyleBoxFlat = UIPalette.row_style(kind)
		assert_eq(box.border_width_left, UIPalette.ROW_ACCENT_WIDTH, "left edge is the accent bar")
		assert_eq(box.border_width_top, UIPalette.ROW_BORDER_WIDTH, "other edges are hairlines")
		assert_eq(box.border_width_right, UIPalette.ROW_BORDER_WIDTH, "other edges are hairlines")
		assert_eq(box.border_width_bottom, UIPalette.ROW_BORDER_WIDTH, "other edges are hairlines")

## Row styles are cached and shared, so a widget that mutates one would restyle
## every list in the game. The contract is "duplicate() to mutate"; this pins
## the sharing so a future change to it is a deliberate one.
func test_row_styles_are_shared_instances() -> void:
	assert_same(UIPalette.live_row(), UIPalette.live_row(), "the same box comes back")
	assert_same(UIPalette.row_style(UIPalette.Row.AMBER), UIPalette.amber_row(),
		"the enum and the named accessor agree")

func test_row_accent_matches_the_row_state() -> void:
	assert_eq(UIPalette.row_accent(UIPalette.Row.LIVE), UIPalette.LIVE, "live accent is cyan")
	assert_eq(UIPalette.row_accent(UIPalette.Row.AMBER), UIPalette.ATTENTION, "amber accent is amber")
	assert_eq(UIPalette.row_accent(UIPalette.Row.INERT), UIPalette.INERT_ACCENT, "inert accent is dim")

func test_row_text_and_meta_differ_within_a_row() -> void:
	for kind: UIPalette.Row in [UIPalette.Row.INERT, UIPalette.Row.LIVE, UIPalette.Row.AMBER]:
		assert_ne(UIPalette.row_text(kind), UIPalette.row_meta(kind),
			"a row's name and its meta line are not the same colour")

# --- the amber budget (WI-58) --------------------------------------------------

## Invariant 5 charters amber for four things: a breach, a falling vital, an
## unread transmission, and ARC. It only holds if there is one place to check how
## many things spend it - which is what these pin. The same shape WI-56 gave
## `PawnStatus`'s tone set (contract 1).

## A gauge under full is a *level*, not an alarm. "Anything below 1.0" was the
## rule in three places, and it meant a module one point down from full, a drone
## that had done a day's work, and every progress bar in the inspector all read
## as emergencies.
func test_a_nearly_full_gauge_is_not_an_alarm() -> void:
	assert_eq(UIPalette.gauge_tint(1.0), UIPalette.LIVE, "full is live")
	assert_eq(UIPalette.gauge_tint(0.99), UIPalette.LIVE, "a scratch is not a falling vital")
	assert_eq(UIPalette.gauge_tint(0.5), UIPalette.LIVE, "half is a level")

func test_a_genuinely_low_gauge_still_earns_amber() -> void:
	assert_eq(UIPalette.gauge_tint(0.1), UIPalette.ATTENTION, "nearly gone is a falling vital")
	assert_eq(UIPalette.gauge_tint(0.0), UIPalette.ATTENTION, "gone certainly is")

## The threshold has to be a real minority of the bar, or "low" means "most of
## the time" and the budget is spent again by another name.
func test_the_gauge_threshold_is_a_minority_of_the_bar() -> void:
	assert_lt(UIPalette.GAUGE_LOW, 0.5, "amber is the exception, not the default")
	assert_gt(UIPalette.GAUGE_LOW, 0.0, "and it is reachable")

## A schedule cell is on-duty or off-duty. Neither is an alarm, so neither may
## spend amber - and the two surfaces that paint this grid now share the rule.
func test_no_shift_cell_spends_amber() -> void:
	for working: bool in [true, false]:
		for is_now: bool in [true, false]:
			var cell: Color = UIPalette.shift_cell(working, is_now)
			assert_ne(Color(cell.r, cell.g, cell.b), UIPalette.ATTENTION,
				"a duty roster is not an emergency")

func test_a_shift_cell_distinguishes_on_duty_from_off_and_now_from_later() -> void:
	assert_ne(UIPalette.shift_cell(true), UIPalette.shift_cell(false), "on and off differ")
	assert_ne(UIPalette.shift_cell(true, true), UIPalette.shift_cell(true, false),
		"the now-marker reads")
	assert_ne(UIPalette.shift_cell(false, true), UIPalette.shift_cell(false, false),
		"and it reads off-shift too")

# --- gradients ----------------------------------------------------------------

func test_header_gradients_run_top_to_bottom() -> void:
	for texture: GradientTexture2D in [
		UIPalette.panel_header_gradient(), UIPalette.readout_header_gradient()]:
		assert_eq(texture.fill_from, Vector2(0.0, 0.0), "gradient starts at the top")
		assert_eq(texture.fill_to, Vector2(0.0, 1.0), "gradient ends at the bottom")

func test_the_two_header_gradients_are_different() -> void:
	# The panel header being warmer than the readout header is half of what makes
	# the 56/34 hierarchy read; a shared gradient would flatten it.
	var panel: Gradient = UIPalette.panel_header_gradient().gradient
	var readout: Gradient = UIPalette.readout_header_gradient().gradient
	assert_ne(panel.get_color(0), readout.get_color(0), "the two header tops differ")

func test_header_gradients_are_shared_instances() -> void:
	assert_same(UIPalette.panel_header_gradient(), UIPalette.panel_header_gradient(),
		"one texture serves every panel header")

# --- UIMetrics: the table ------------------------------------------------------

func test_panel_widths_match_the_program_table() -> void:
	assert_eq(UIMetrics.PANEL_OVERLAYS_WIDTH, 360, "Overlays")
	assert_eq(UIMetrics.PANEL_BUILD_WIDTH, 356, "Build rail")
	assert_eq(UIMetrics.PANEL_BUILD_FLYOUT_WIDTH, 340, "Build flyout")
	assert_eq(UIMetrics.PANEL_COMMS_WIDTH, 620, "Comms")
	assert_eq(UIMetrics.PANEL_CREW_WIDTH, 660, "Crew")
	assert_eq(UIMetrics.PANEL_STORES_WIDTH, 1080, "Stores")
	assert_eq(UIMetrics.PANEL_TRADE_WIDTH, 1180, "Trade")
	assert_eq(UIMetrics.PANEL_RD_WIDTH, 1400, "R&D")

## The build rail plus its flyout is quoted as 696 total in the program doc.
func test_build_rail_plus_flyout_is_696() -> void:
	assert_eq(UIMetrics.PANEL_BUILD_WIDTH + UIMetrics.PANEL_BUILD_FLYOUT_WIDTH, 696,
		"rail + flyout")

## Every panel has to fit on the design resolution with the right column and its
## gutter still visible, or invariant 3 (opening a panel shifts nothing on the
## right) is unenforceable.
func test_the_widest_panel_still_clears_the_right_column() -> void:
	var right_edge: int = UIMetrics.SCREEN_SIZE.x - UIMetrics.INSPECTOR_WIDTH - UIMetrics.SCREEN_GUTTER
	assert_lt(UIMetrics.PANEL_RD_WIDTH, right_edge, "R&D does not reach the inspector")

func test_header_heights_differ() -> void:
	assert_gt(UIMetrics.PANEL_HEADER_HEIGHT, UIMetrics.READOUT_HEADER_HEIGHT,
		"the panel header is the taller of the two, on purpose")

# --- UIMetrics: derived --------------------------------------------------------

func test_panel_bottom_is_screen_height_minus_console() -> void:
	assert_eq(UIMetrics.panel_bottom(), 1080 - 112, "panel bottom at the design resolution")
	assert_eq(UIMetrics.panel_bottom(1440), 1440 - 112, "and at any other height")

func test_panel_content_height_excludes_the_header() -> void:
	assert_eq(UIMetrics.panel_content_height(),
		UIMetrics.panel_height() - UIMetrics.PANEL_HEADER_HEIGHT,
		"content is what is left below the 56px header")

func test_inspector_top_leaves_a_gutter_above_the_console() -> void:
	var top: int = UIMetrics.inspector_top(300)
	assert_eq(top, 1080 - 112 - 20 - 300, "inspector top at the design resolution")
	assert_eq(top + 300, UIMetrics.panel_bottom() - UIMetrics.SCREEN_GUTTER,
		"its foot sits one gutter above the console")

func test_inspector_bottom_offset_is_console_plus_gutter() -> void:
	assert_eq(UIMetrics.inspector_bottom_offset(),
		UIMetrics.CONSOLE_HEIGHT + UIMetrics.SCREEN_GUTTER,
		"the offset the inspector anchors at does not depend on its content")

func test_mode_zone_width_counts_gaps_between_not_after() -> void:
	assert_eq(UIMetrics.mode_zone_width(0), 0.0, "no buttons take no room")
	assert_eq(UIMetrics.mode_zone_width(1), UIMetrics.MODE_BUTTON.x, "one button has no gap")
	assert_eq(UIMetrics.mode_zone_width(2),
		UIMetrics.MODE_BUTTON.x * 2.0 + UIMetrics.MODE_BUTTON_GAP, "two buttons, one gap")

## Nine console buttons (seven modes, two utilities) plus the divider between
## them have to fit the reserved 715px zone.
func test_nine_mode_buttons_fit_the_console_zone() -> void:
	assert_lt(UIMetrics.mode_zone_width(9), float(UIMetrics.CONSOLE_MODES_WIDTH),
		"the console's mode zone holds every button")

func test_mode_button_fits_inside_the_console() -> void:
	assert_lt(UIMetrics.MODE_BUTTON.y, float(UIMetrics.CONSOLE_HEIGHT),
		"a 74px button inside a 112px console leaves room to breathe")

# --- UIMetrics: the right column budget (WI-58) --------------------------------

## The whole point of the item. Reconstructs the worst realistic stack - map,
## raid readout, feed at its cap - and asserts the inspector still has room for
## its own chrome plus a page, rather than the zero it used to compute.
func _top_limit_for(raid_visible: bool) -> int:
	var y: int = UIMetrics.SCREEN_GUTTER + UIMetrics.STATION_MAP_HEIGHT + UIMetrics.SCREEN_GUTTER
	if raid_visible:
		y += UIMetrics.ALERT_RAID_HEIGHT + UIMetrics.SCREEN_GUTTER
	return y + UIMetrics.alert_feed_max_height(raid_visible) + UIMetrics.SCREEN_GUTTER

func test_inspector_survives_a_raid_with_a_full_alert_feed() -> void:
	var top: int = _top_limit_for(true)
	var content: int = UIMetrics.inspector_max_content_height(UIMetrics.SCREEN_SIZE.y, top)
	assert_gte(content, UIMetrics.INSPECTOR_MIN_CONTENT_HEIGHT,
		"a raid plus a capped feed still leaves the inspector its floor")

func test_inspector_survives_a_full_alert_feed_with_no_raid() -> void:
	var top: int = _top_limit_for(false)
	var content: int = UIMetrics.inspector_max_content_height(UIMetrics.SCREEN_SIZE.y, top)
	assert_gte(content, UIMetrics.INSPECTOR_MIN_CONTENT_HEIGHT,
		"the ordinary column leaves the inspector its floor too")

## The floor has to clear a realistic crew subject's chrome (~152px) with room
## left for content, or it is a floor that still renders an empty box.
func test_the_inspector_floor_clears_its_own_chrome() -> void:
	assert_gt(UIMetrics.INSPECTOR_MIN_CONTENT_HEIGHT, 160,
		"the floor is chrome plus content, not chrome alone")

## The raid readout takes room out of the feed and not out of the inspector.
func test_the_feed_is_the_readout_that_yields_to_a_raid() -> void:
	var quiet: int = UIMetrics.alert_feed_max_height(false)
	var raiding: int = UIMetrics.alert_feed_max_height(true)
	assert_lt(raiding, quiet, "the raid readout comes out of the feed's budget")
	assert_eq(quiet - raiding, UIMetrics.ALERT_RAID_HEIGHT + UIMetrics.SCREEN_GUTTER,
		"exactly the raid readout and its gutter, nothing else")

## The alert log flyout hangs beside the right column and must clear its widest
## tenant - the inspector is wider than the column, and a selection pulls it up
## beside the feed the flyout hangs from.
func test_the_alert_log_flyout_clears_the_inspector() -> void:
	var gutter: int = UIMetrics.SCREEN_GUTTER
	assert_gte(UIMetrics.ALERT_HISTORY_RIGHT_INSET, UIMetrics.INSPECTOR_WIDTH + gutter * 2,
		"the flyout stops a gutter short of the inspector's left edge")
	assert_gte(UIMetrics.ALERT_HISTORY_RIGHT_INSET, UIMetrics.RIGHT_COLUMN_WIDTH + gutter * 2,
		"and of the column's")
	assert_lte(UIMetrics.ALERT_HISTORY_RIGHT_INSET + UIMetrics.ALERT_HISTORY_WIDTH,
		UIMetrics.SCREEN_SIZE.x, "and still fits on the reference screen")

## `AlertRules.FEED_CAP` rows plus the `+ n more` line have to render in the
## ordinary column without an inner scrollbar - the agreement WI-53 wrote down
## and WI-58 turned from a constant into a derivation.
func test_the_quiet_feed_budget_still_renders_the_row_cap() -> void:
	# A ListRow is its two text lines plus the style box's 11px content margins;
	# 59px is the measured height at the design's type scale. FEED_CAP rows, the
	# overflow row, the gaps between them and the readout's own padding and header.
	var row: int = 59
	var needed: int = (AlertRules.FEED_CAP + 1) * row \
		+ AlertRules.FEED_CAP * UIMetrics.ROW_GAP \
		+ UIMetrics.READOUT_CONTENT_PAD * 2 + UIMetrics.READOUT_HEADER_HEIGHT
	assert_gte(UIMetrics.alert_feed_max_height(false), needed,
		"four rows plus the overflow line fit the quiet column")

## A smaller screen must not produce a negative budget that a caller then uses as
## a height.
func test_feed_budget_never_goes_negative() -> void:
	assert_gte(UIMetrics.alert_feed_max_height(true, 600), 0, "clamped at zero")
	assert_gte(UIMetrics.alert_feed_max_content_height(true, 480), 0, "content clamped too")

func test_feed_content_budget_excludes_its_own_header() -> void:
	assert_eq(UIMetrics.alert_feed_max_content_height(false),
		UIMetrics.alert_feed_max_height(false) - UIMetrics.READOUT_HEADER_HEIGHT,
		"the content region is the budget less the 34px header")
