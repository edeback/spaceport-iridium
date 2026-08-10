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
