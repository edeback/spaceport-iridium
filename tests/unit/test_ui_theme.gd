extends GutTest

## Drift guard for WI-49's theme (`ui/themes/base_theme.tres`).
##
## The theme is a resource and the palette is code, and they have to agree: a
## `.tres` colour that no longer matches [UIPalette] is exactly the "local
## override that agrees with the theme" problem in reverse - the next person to
## retune the palette will not find it. This suite pins the agreement, pins the
## type-variation surface named by [UIType], and pins the two inheritance traps
## that a Godot theme sets for you.
##
## It loads a resource but touches no node, no Global and no SignalBus.

const THEME_PATH: String = "res://ui/themes/base_theme.tres"

var _theme: Theme

func before_all() -> void:
	_theme = load(THEME_PATH) as Theme

func test_theme_loads() -> void:
	assert_not_null(_theme, "the project theme resource loads")

## project.godot points `gui/theme/custom` at this uid; a regenerated theme that
## lost it would silently un-skin the entire game.
func test_theme_is_the_one_project_godot_points_at() -> void:
	var settings_uid: String = str(ProjectSettings.get_setting("gui/theme/custom", ""))
	assert_eq(ResourceUID.id_to_text(ResourceLoader.get_resource_uid(THEME_PATH)), settings_uid,
		"the project's custom theme is this file")

# --- defaults -----------------------------------------------------------------

func test_default_font_and_size() -> void:
	assert_not_null(_theme.default_font, "a default font is set, so no control falls back to Godot's")
	assert_eq(_theme.default_font_size, 13, "body text is 13px")

## The design's floor is "9px labels, 11px everything else". Nothing in the
## theme may sit under it.
func test_no_type_is_smaller_than_the_design_minimum() -> void:
	for type: StringName in _theme.get_font_size_type_list():
		for item: StringName in _theme.get_font_size_list(type):
			var size: int = _theme.get_font_size(item, type)
			assert_gte(size, 9, "%s/%s is at least the 9px floor" % [type, item])

# --- palette agreement --------------------------------------------------------

func test_label_color_is_the_palette_text_color() -> void:
	assert_eq(_theme.get_color(&"font_color", &"Label"), UIPalette.TEXT,
		"body text uses the palette's TEXT")

func test_button_fill_and_border_come_from_the_palette() -> void:
	var normal: StyleBoxFlat = _theme.get_stylebox(&"normal", &"Button") as StyleBoxFlat
	assert_not_null(normal, "Button has a flat normal style")
	assert_eq(normal.bg_color, UIPalette.CONTROL_FILL, "control fill")
	assert_eq(normal.border_color, UIPalette.CONTROL_BORDER, "control border")

func test_panel_surface_and_edge_come_from_the_palette() -> void:
	for type: StringName in [&"Panel", &"PanelContainer"]:
		var panel: StyleBoxFlat = _theme.get_stylebox(&"panel", type) as StyleBoxFlat
		assert_not_null(panel, "%s has a flat panel style" % type)
		assert_eq(panel.bg_color, UIPalette.PANEL, "%s surface is PANEL" % type)
		assert_eq(panel.border_color, UIPalette.EDGE, "%s border is EDGE" % type)

func test_gauge_track_and_fill_come_from_the_palette() -> void:
	var back: StyleBoxFlat = _theme.get_stylebox(&"background", &"ProgressBar") as StyleBoxFlat
	var fill: StyleBoxFlat = _theme.get_stylebox(&"fill", &"ProgressBar") as StyleBoxFlat
	assert_eq(back.bg_color, UIPalette.GAUGE_TRACK, "gauge track")
	assert_eq(fill.bg_color, UIPalette.LIVE, "a filling bar is live")

## Nothing in the chrome is rounded - the design is square throughout, and one
## rounded control reads as a control from a different game.
func test_nothing_in_the_theme_has_a_corner_radius() -> void:
	for type: StringName in _theme.get_stylebox_type_list():
		for item: StringName in _theme.get_stylebox_list(type):
			var box: StyleBoxFlat = _theme.get_stylebox(item, type) as StyleBoxFlat
			if box == null:
				continue
			assert_eq(box.corner_radius_top_left, 0, "%s/%s is square" % [type, item])
			assert_eq(box.corner_radius_bottom_right, 0, "%s/%s is square" % [type, item])

# --- type variations ----------------------------------------------------------

func _all_variations() -> Array[StringName]:
	return [
		UIType.PANEL_TITLE, UIType.READOUT_LABEL, UIType.ENTITY_NAME,
		UIType.ENTITY_NAME_LARGE, UIType.METRIC, UIType.METRIC_LARGE,
		UIType.META_LINE, UIType.MODE_LABEL, UIType.HOTKEY, UIType.TAB_LABEL,
		UIType.BODY, UIType.ACTION_PRIMARY, UIType.ACTION_SECONDARY,
		UIType.ACTION_DESTRUCTIVE, UIType.TAB_ACTIVE, UIType.TAB_INACTIVE,
	]

## Every name [UIType] hands out has to exist as a variation, or a control that
## sets it renders as its plain base type and the miss is invisible.
func test_every_ui_type_variation_exists() -> void:
	var registered: PackedStringArray = _theme.get_type_variation_list(&"Label")
	registered.append_array(_theme.get_type_variation_list(&"Button"))
	for name: StringName in _all_variations():
		assert_true(registered.has(String(name)), "%s is a registered type variation" % name)
		assert_ne(_theme.get_type_variation_base(name), StringName(),
			"%s declares a base type" % name)

func test_label_variations_carry_a_font_and_a_size() -> void:
	for name: StringName in _all_variations():
		assert_true(_theme.has_font(&"font", name), "%s sets a font" % name)
		assert_true(_theme.has_font_size(&"font_size", name), "%s sets a size" % name)

func test_the_button_variations_are_buttons_and_the_rest_are_labels() -> void:
	for name: StringName in [UIType.ACTION_PRIMARY, UIType.ACTION_SECONDARY,
			UIType.ACTION_DESTRUCTIVE, UIType.TAB_ACTIVE, UIType.TAB_INACTIVE]:
		assert_eq(_theme.get_type_variation_base(name), StringName("Button"),
			"%s varies Button" % name)
	for name: StringName in [UIType.PANEL_TITLE, UIType.READOUT_LABEL, UIType.METRIC,
			UIType.META_LINE, UIType.MODE_LABEL, UIType.HOTKEY, UIType.BODY]:
		assert_eq(_theme.get_type_variation_base(name), StringName("Label"),
			"%s varies Label" % name)

## Tracking is the whole reason the type scale is theme variations rather than
## per-label overrides. If `spacing_glyph` ever comes back zero on these, the
## caps labels have silently lost their letter-spacing.
func test_tracked_variations_actually_carry_tracking() -> void:
	var expected: Dictionary[StringName, int] = {
		UIType.PANEL_TITLE: UIMetrics.TRACKING_PANEL_TITLE,
		UIType.READOUT_LABEL: UIMetrics.TRACKING_READOUT_LABEL,
		UIType.META_LINE: UIMetrics.TRACKING_META,
		UIType.MODE_LABEL: UIMetrics.TRACKING_MODE_LABEL,
		UIType.TAB_LABEL: UIMetrics.TRACKING_TAB_LABEL,
	}
	for name: StringName in expected:
		var font: FontVariation = _theme.get_font(&"font", name) as FontVariation
		assert_not_null(font, "%s uses a FontVariation, the only thing that can track" % name)
		assert_eq(font.spacing_glyph, expected[name], "%s tracking" % name)
		assert_not_null(font.base_font, "%s tracking sits on a real face" % name)

## Numbers and names are not tracked - tracking a mono metric makes columns of
## digits stop lining up with each other.
func test_untracked_variations_are_plain_fonts() -> void:
	for name: StringName in [UIType.METRIC, UIType.METRIC_LARGE, UIType.ENTITY_NAME,
			UIType.ENTITY_NAME_LARGE, UIType.HOTKEY, UIType.BODY]:
		var variation: FontVariation = _theme.get_font(&"font", name) as FontVariation
		var tracking: int = variation.spacing_glyph if variation != null else 0
		assert_eq(tracking, 0, "%s is untracked" % name)

func test_the_two_metric_sizes_and_two_name_sizes_differ() -> void:
	assert_lt(_theme.get_font_size(&"font_size", UIType.METRIC),
		_theme.get_font_size(&"font_size", UIType.METRIC_LARGE), "a headline number is bigger")
	assert_lt(_theme.get_font_size(&"font_size", UIType.ENTITY_NAME),
		_theme.get_font_size(&"font_size", UIType.ENTITY_NAME_LARGE),
		"the inspector's subject is bigger than a row's")

## Invariant: destructive is outline only, never a filled button. Encoded in
## `ActionButton`, pinned here so the theme cannot quietly give it a fill.
func test_destructive_button_has_no_fill() -> void:
	var normal: StyleBoxFlat = _theme.get_stylebox(&"normal", UIType.ACTION_DESTRUCTIVE) as StyleBoxFlat
	assert_almost_eq(normal.bg_color.a, 0.0, 0.0001, "destructive is an outline")
	assert_eq(normal.border_color, UIPalette.DESTRUCTIVE, "and the outline is the destructive red")

func test_primary_button_is_filled_and_live() -> void:
	var normal: StyleBoxFlat = _theme.get_stylebox(&"normal", UIType.ACTION_PRIMARY) as StyleBoxFlat
	assert_gt(normal.bg_color.a, 0.0, "primary is filled")
	assert_eq(normal.border_color, UIPalette.LIVE, "primary is bordered LIVE")

## The active tab sits ON the strip's rule rather than being boxed off from the
## page below it, which is the whole reason it reads as connected.
func test_active_tab_has_no_bottom_border() -> void:
	var box: StyleBoxFlat = _theme.get_stylebox(&"normal", UIType.TAB_ACTIVE) as StyleBoxFlat
	assert_eq(box.border_width_bottom, 0, "no bottom edge on the active tab")
	assert_gt(box.border_width_top, 0, "but the other three edges are there")

# --- inheritance traps ---------------------------------------------------------

## Godot resolves a theme item by walking the control's *class chain*, so
## CheckBox and CheckButton find `Button/styles/normal` unless they have their
## own. Without these entries a checkbox renders as a filled button with a tick
## glued to it. This is the trap that makes "just style Button" wrong.
func test_toggles_do_not_inherit_the_button_fill() -> void:
	for type: StringName in [&"CheckBox", &"CheckButton"]:
		assert_true(_theme.has_stylebox(&"normal", type),
			"%s has its own normal style rather than inheriting Button's" % type)
		var box: StyleBoxFlat = _theme.get_stylebox(&"normal", type) as StyleBoxFlat
		assert_null(box, "%s is flat-less: an empty box, not a filled one" % type)

func test_button_has_every_interaction_state() -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		assert_true(_theme.has_stylebox(state, &"Button"), "Button defines %s" % state)

## A themed control with no `focus` style is a control the keyboard cannot be
## seen on. Everything focusable gets one.
func test_focusable_controls_have_a_focus_style() -> void:
	for type: StringName in [&"Button", &"CheckBox", &"CheckButton", &"LineEdit"]:
		assert_true(_theme.has_stylebox(&"focus", type), "%s shows focus" % type)

func test_scroll_container_panel_is_invisible() -> void:
	var box: StyleBoxFlat = _theme.get_stylebox(&"panel", &"ScrollContainer") as StyleBoxFlat
	assert_null(box, "a scroll container is a viewport, not a surface")
