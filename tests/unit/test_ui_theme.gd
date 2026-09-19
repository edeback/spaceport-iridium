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

## The two dim text styles are the theme's copies of [UIPalette]'s tokens, and
## WI-58 retuned both - a `.tres` that kept the old values would silently undo
## the contrast lift for every meta line and every inactive tab.
func test_dim_text_styles_match_the_palette() -> void:
	assert_eq(_theme.get_color(&"font_color", UIType.META_LINE), UIPalette.TEXT_META,
		"the meta line is TEXT_META")
	assert_eq(_theme.get_color(&"font_color", UIType.HOTKEY), UIPalette.TEXT_META,
		"a hotkey hint is TEXT_META")
	assert_eq(_theme.get_color(&"font_color", UIType.TAB_INACTIVE), UIPalette.TEXT_SECONDARY,
		"an inactive tab is TEXT_SECONDARY")

## A disabled control carries a sentence the player has to read (WI-57's "a
## blocked action names its blocker on its own control"), so the disabled label
## has its own token rather than sharing the dimmest one in the palette.
func test_disabled_labels_use_the_disabled_token_everywhere() -> void:
	for type: StringName in [&"Button", &"CheckBox", &"CheckButton", UIType.ACTION_PRIMARY,
			UIType.ACTION_SECONDARY, UIType.ACTION_DESTRUCTIVE]:
		assert_eq(_theme.get_color(&"font_disabled_color", type), UIPalette.TEXT_DISABLED,
			"%s disables to TEXT_DISABLED" % type)

func test_the_disabled_token_is_not_the_meta_token() -> void:
	assert_ne(UIPalette.TEXT_DISABLED, UIPalette.TEXT_META,
		"they were the same colour, and that is the defect WI-58 fixed")

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
		UIType.ENTITY_NAME_LARGE, UIType.METRIC, UIType.METRIC_LARGE, UIType.CLOCK,
		UIType.META_LINE, UIType.MODE_LABEL, UIType.HOTKEY, UIType.TAB_LABEL,
		UIType.BODY, UIType.ACTION_PRIMARY, UIType.ACTION_SECONDARY,
		UIType.ACTION_DESTRUCTIVE, UIType.TAB_ACTIVE, UIType.TAB_INACTIVE,
		UIType.INSPECTOR_TAB,
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
			UIType.ACTION_DESTRUCTIVE, UIType.TAB_ACTIVE, UIType.TAB_INACTIVE,
			UIType.INSPECTOR_TAB]:
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
		UIType.INSPECTOR_TAB: UIMetrics.TRACKING_TAB_LABEL,
	}
	for name: StringName in expected:
		var font: FontVariation = _theme.get_font(&"font", name) as FontVariation
		assert_not_null(font, "%s uses a FontVariation, the only thing that can track" % name)
		assert_eq(font.spacing_glyph, expected[name], "%s tracking" % name)
		assert_not_null(font.base_font, "%s tracking sits on a real face" % name)

## Numbers and names are not tracked - tracking a mono metric makes columns of
## digits stop lining up with each other.
func test_untracked_variations_are_plain_fonts() -> void:
	for name: StringName in [UIType.METRIC, UIType.METRIC_LARGE, UIType.CLOCK,
			UIType.ENTITY_NAME, UIType.ENTITY_NAME_LARGE, UIType.HOTKEY, UIType.BODY]:
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

# --- the scene sweep (WI-58) ---------------------------------------------------

## The missing half of the drift guard.
##
## Everything above reads the theme *resource*, which makes it structurally blind
## to the scenes. WI-57 §8's sweep found "zero `add_theme_font_size_override`
## calls in the console UI" and was literally true - while 28 scene-authored
## `theme_override_font_sizes` sat in `.tscn` files, six of them at 10px, under
## the design's own 11px floor, on live inspector tabs. A `.tscn` form of a font
## size, a colour or a type variation is the same violation as its code form; the
## code form was the only one anything checked.
##
## `ui/` is scanned as text rather than by loading each scene: a `.tscn` is the
## authoring surface, and reading the file is what catches a value that a loaded
## scene would have already resolved away.

## Scenes allowed their own type and colour. Two are deliberately outside the
## console's design system - the main menu predates it, the game-over screen is a
## full-bleed takeover - and `preview_module` draws in world space, not on the HUD.
##
## `event_card.tscn` was the fourth and is gone (WI-62): the dialogue balloon
## replaced it, and `ui/dialogue/balloon.tscn` is **inside** the design system.
## It is swept like everything else and must never be added here.
const OVERRIDE_EXEMPT: Array[String] = [
	"res://ui/menus/", "res://ui/game_over_screen.tscn",
	"res://ui/preview_module.tscn",
]

func _scene_paths() -> PackedStringArray:
	var out := PackedStringArray()
	_collect_scenes("res://ui", out)
	return out

func _collect_scenes(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_scenes(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _is_exempt(path: String) -> bool:
	for prefix: String in OVERRIDE_EXEMPT:
		if path.begins_with(prefix):
			return true
	return false

func test_the_sweep_actually_finds_scenes() -> void:
	# A guard whose scan silently returned nothing would pass every test below.
	assert_gt(_scene_paths().size(), 20, "the scene sweep sees the ui/ tree")

## Every size in the HUD comes from a [UIType] variation. A scene-authored size
## is the same violation as `add_theme_font_size_override`, and it is the one the
## code-only sweep could not see.
func test_no_scene_authors_a_font_size() -> void:
	for path: String in _scene_paths():
		if _is_exempt(path):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		assert_false(text.contains("theme_override_font_sizes"),
			"%s takes its size from a UIType variation" % path)

## Nothing in `ui/` may name a hex literal (WI-49). A `Color(...)` in a `.tscn`
## is exactly that, spelled as floats.
func test_no_scene_authors_a_colour() -> void:
	for path: String in _scene_paths():
		if _is_exempt(path):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		for needle: String in ["theme_override_colors/", "= Color(", "self_modulate"]:
			assert_false(text.contains(needle),
				"%s takes its colour from UIPalette, not from `%s`" % [path, needle])

## A type variation is a bare string on both sides of a contract, so a
## misspelling renders the control as its plain base type and nobody notices
## until a screenshot. Every name a scene assigns has to be one [UIType] declares.
func test_every_scene_type_variation_is_a_declared_ui_type() -> void:
	var declared: Array[String] = []
	for name: StringName in _all_variations():
		declared.append(String(name))
	var pattern := RegEx.create_from_string('theme_type_variation = &"([^"]*)"')
	var seen: int = 0
	for path: String in _scene_paths():
		var text: String = FileAccess.get_file_as_string(path)
		for match: RegExMatch in pattern.search_all(text):
			var variation: String = match.get_string(1)
			if variation.is_empty():
				continue # explicitly cleared, which is the base type on purpose
			seen += 1
			assert_true(declared.has(variation),
				"%s assigns `%s`, which UIType does not declare" % [path, variation])
	assert_gt(seen, 30, "the sweep actually read the assignments")

# --- the script sweep (WI-68 F6) ---------------------------------------------------

## The other missing half. WI-58 added the scene sweep above because a `.tscn`
## literal is the same violation as its code form - and the code form was left
## to a one-off grep. By the 2026-09-18 audit about forty geometry numbers and ten
## colours had crept back into `ui/**.gd`. This is that grep, made permanent.

## Scripts allowed their own numbers. The out-of-game menus and the game-over
## takeover (the same exemption the scenes get), `ui/theme/` - where the tokens
## are defined - and the files that draw in world space rather than on the HUD.
const SCRIPT_EXEMPT: Array[String] = [
	"res://ui/menus/", "res://ui/game_over_screen.gd", "res://ui/theme/",
	"res://ui/preview_module.gd", "res://ui/selection_brackets.gd",
	"res://ui/overlay_flow_layer.gd", "res://ui/click_cycler.gd", "res://ui/overlay_palette.gd",
]

## What a script may not spell out, each with the token it should use instead.
## Zero is allowed on purpose: "no gap" isn't a geometry choice. Named engine
## constants (`Color.TRANSPARENT`, `Color.WHITE`) are allowed; they aren't literals.
const SCRIPT_LITERALS: Dictionary[String, String] = {
	'add_theme_font_size_override\\([^,]+,\\s*-?\\d': "a UIType variation",
	'add_theme_constant_override\\([^,]+,\\s*-?[1-9]': "a UIMetrics token",
	'\\bColor\\(\\s*[-0-9.]': "a UIPalette colour",
	'\\bColor\\(\\s*"': "a UIPalette colour",
	'\\bColor\\.(html|hex|hex64)\\(': "a UIPalette colour",
	# A number that IS an argument, or is added to one (`side + 12`) - never a
	# multiplier: `INSET * 2` is "both sides", not a size.
	'custom_minimum_size\\s*=\\s*Vector2i?\\((?:[^)]*[(,+\\-]\\s*|\\s*)[1-9]': "a UIMetrics size",
	'custom_minimum_size\\.[xy]\\s*=\\s*[1-9]': "a UIMetrics size",
	'theme_type_variation\\s*=\\s*&?"': "a UIType constant",
}

func _script_paths() -> PackedStringArray:
	var out := PackedStringArray()
	_collect_scripts("res://ui", out)
	return out

func _collect_scripts(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_scripts(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _script_exempt(path: String) -> bool:
	for prefix: String in SCRIPT_EXEMPT:
		if path.begins_with(prefix):
			return true
	return false

func test_the_script_sweep_actually_finds_scripts() -> void:
	assert_gt(_script_paths().size(), 80, "the script sweep sees the ui/ tree")

## Nothing in `ui/` may name a hex literal, a geometry number or a type-variation
## string - in a script any more than in a scene. One assertion per offending
## line, so the failure lists every site to fix.
func test_no_ui_script_spells_out_a_colour_size_or_variation() -> void:
	var patterns: Dictionary[RegEx, String] = {}
	for source: String in SCRIPT_LITERALS:
		patterns[RegEx.create_from_string(source)] = SCRIPT_LITERALS[source]
	var checked: int = 0
	for path: String in _script_paths():
		if _script_exempt(path):
			continue
		checked += 1
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			var line: String = lines[index]
			if line.strip_edges().begins_with("#"):
				continue # prose may quote an old value
			for pattern: RegEx in patterns:
				if pattern.search(line) != null:
					fail_test("%s:%d spells out what should be %s:  %s"
						% [path, index + 1, patterns[pattern], line.strip_edges()])
	assert_gt(checked, 80, "and read them")

## `SpinBox extends Range`, not `LineEdit`, so it inherits **nothing** from this
## theme - its arrows come from Godot's default *light* theme. Two of them were
## the only un-skinned controls in the HUD until WI-58 replaced both with
## [Stepper]. If one ever comes back, the theme owes it a skin.
func test_no_spinbox_survives_without_the_theme_skinning_it() -> void:
	var offenders: Array[String] = []
	for path: String in _scene_paths():
		if _is_exempt(path):
			continue
		if FileAccess.get_file_as_string(path).contains('type="SpinBox"'):
			offenders.append(path)
	assert_true(offenders.is_empty() or _theme.has_stylebox(&"normal", &"SpinBox"),
		"a SpinBox survives in %s, so the theme has to skin it" % ", ".join(offenders))
