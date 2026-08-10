@tool
class_name ModeButton
extends Button

## One console button (WI-50): a 70x74 target with a 22px glyph over a 9px caps
## label, its hotkey in the corner, and three adornments the design distinguishes
## very carefully.
##
## [b]They are three different signals and must not collapse into one
## "notification" concept:[/b]
##
##   - [member active] - LIVE-tinted fill and a LIVE border. This mode's panel is
##     the one that is open. Nothing else in the HUD says which panel is open, so
##     nothing else needs a second cue.
##   - [member bar] - a cyan bar under the button: "something this mode controls
##     is live even though its panel is shut". Only Overlays uses it today,
##     because only the overlay tint outlives its panel.
##   - [member dot] - a 7px LIVE dot: "there is something here you can do now".
##     An affordable unlock, a docked trader, an idle crew member.
##   - [member badge] - an amber count: unread items. Comms.
##
## A mode can wear the active fill and an adornment at once; that is the point.
##
## The glyphs are authored SVGs in `ui/icons/console/` rather than `_draw()`
## calls, for the same reason WI-35's minimap is the one thing headless
## verification cannot see: a shape drawn in code can only be checked by looking
## at it.

## Height of the "live even though the panel is shut" bar.
const BAR_HEIGHT: int = 3
## Diameter of the readiness dot.
const DOT_SIZE: int = 7
## The badge is a fixed pill so a two-digit count does not resize the button.
const BADGE_SIZE := Vector2(17, 16)

@export var glyph: Texture2D = null:
	set(value):
		glyph = value
		_apply_glyph()

## Caption under the glyph. Rendered in caps here, so no caller upper-cases it.
@export var caption: String = "MODE":
	set(value):
		caption = value
		_apply_caption()

## Printed so the console teaches its own hotkeys. Empty hides the corner label -
## AIDE and SYS both have one, but a mode whose action is unbound has none.
@export var hotkey: String = "":
	set(value):
		hotkey = value
		_apply_hotkey()

## True while this mode's panel is the open one.
##
## These four state setters all guard on an unchanged value. The console rewrites
## every button's adornments once a second and every button's `active` on every
## mode change, so without the guard the strip would re-apply theme overrides -
## and force a redraw - dozens of times a second to express state that moves a
## few times a minute.
@export var active: bool = false:
	set(value):
		if active == value:
			return
		active = value
		_apply_state()

## "An overlay is painted even though the Overlays panel is closed."
@export var bar: bool = false:
	set(value):
		if bar == value:
			return
		bar = value
		_apply_adornments()

## "There is something here you can do now."
@export var dot: bool = false:
	set(value):
		if dot == value:
			return
		dot = value
		_apply_adornments()

## Unread count. Zero hides the badge.
@export var badge: int = 0:
	set(value):
		var clamped: int = maxi(value, 0)
		if badge == clamped:
			return
		badge = clamped
		_apply_adornments()

var _column: VBoxContainer
var _glyph_rect: TextureRect
var _label: Label
var _hotkey_label: Label
var _dot_panel: Panel
var _badge_panel: Panel
var _badge_count: Label
var _bar_rect: ColorRect

## Loaded rather than preloaded: the scene sets this script, so a `preload` here
## would be a cyclic resource inclusion. Same shape as the WI-49 widgets.
const SCENE_PATH: String = "res://ui/console/mode_button.tscn"

## The console is code-built (program decision 8), so the button needs a one-call
## instantiation path.
static func create() -> ModeButton:
	return load(SCENE_PATH).instantiate() as ModeButton

func _ready() -> void:
	_ensure_refs()
	_apply_all()

## Lazy for the same reason as [ConsolePanel]'s: the exported setters run during
## scene load, before the children exist, and the console configures a button
## before mounting it.
func _ensure_refs() -> void:
	if _column != null:
		return
	_column = get_node_or_null("Column") as VBoxContainer
	if _column == null:
		return
	_glyph_rect = get_node_or_null("Column/Glyph") as TextureRect
	_label = get_node_or_null("Column/Label") as Label
	_hotkey_label = get_node_or_null("Hotkey") as Label
	_dot_panel = get_node_or_null("Dot") as Panel
	_badge_panel = get_node_or_null("Badge") as Panel
	_badge_count = get_node_or_null("Badge/Count") as Label
	_bar_rect = get_node_or_null("Bar") as ColorRect

func _apply_all() -> void:
	_apply_layout()
	_apply_glyph()
	_apply_caption()
	_apply_hotkey()
	_apply_adornments()
	_apply_state()

func _apply_layout() -> void:
	_ensure_refs()
	if _column == null:
		return
	custom_minimum_size = UIMetrics.MODE_BUTTON
	if _dot_panel != null:
		_dot_panel.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		_dot_panel.offset_right = _dot_panel.offset_left + float(DOT_SIZE)
		_dot_panel.offset_bottom = _dot_panel.offset_top + float(DOT_SIZE)
	if _badge_panel != null:
		_badge_panel.custom_minimum_size = BADGE_SIZE
		_badge_panel.offset_left = -BADGE_SIZE.x - 5.0
		_badge_panel.offset_right = -5.0
		_badge_panel.offset_bottom = _badge_panel.offset_top + BADGE_SIZE.y
	if _bar_rect != null:
		_bar_rect.offset_top = -float(BAR_HEIGHT)
		_bar_rect.color = UIPalette.LIVE
	# The dot and badge boxes never change - only whether they are shown does -
	# so they are built here rather than in _apply_adornments, which the console
	# calls once a second for every button.
	if _dot_panel != null:
		_dot_panel.add_theme_stylebox_override("panel", _dot_style())
	if _badge_panel != null:
		_badge_panel.add_theme_stylebox_override("panel", _badge_style())
	if _badge_count != null:
		_badge_count.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)

func _apply_glyph() -> void:
	_ensure_refs()
	if _glyph_rect == null:
		return
	_glyph_rect.texture = glyph

func _apply_caption() -> void:
	_ensure_refs()
	if _label == null:
		return
	# Caps is a content decision (Godot has no text-transform), made once in the
	# widget that owns the label rather than by every caller.
	_label.text = caption.to_upper()

func _apply_hotkey() -> void:
	_ensure_refs()
	if _hotkey_label == null:
		return
	_hotkey_label.text = hotkey
	_hotkey_label.visible = not hotkey.is_empty()

func _apply_adornments() -> void:
	_ensure_refs()
	if _column == null:
		return
	if _bar_rect != null:
		_bar_rect.visible = bar
	if _dot_panel != null:
		_dot_panel.visible = dot
	if _badge_panel != null:
		_badge_panel.visible = badge > 0
	if _badge_count != null:
		# Past 9 the pill would have to grow and shove the dot off the corner;
		# "9+" is the number the player needs anyway.
		_badge_count.text = "9+" if badge > 9 else str(badge)

## The active fill and border. Applied as overrides on top of the theme's Button
## rather than as a fourth stylebox in the theme, because "active" here is a
## state this widget owns, not a Button variation any caller could ask for.
func _apply_state() -> void:
	_ensure_refs()
	if _column == null:
		return
	if not active:
		for state: StringName in [&"normal", &"hover", &"pressed"]:
			remove_theme_stylebox_override(state)
	else:
		add_theme_stylebox_override(&"normal", _active_style())
		# Hover and pressed share one box: an active button has nowhere brighter
		# to go on press, and two identical StyleBoxes would just be two.
		add_theme_stylebox_override(&"hover", _active_hover_style())
		add_theme_stylebox_override(&"pressed", _active_hover_style())
	# self_modulate multiplies the theme's font colour rather than setting it
	# (WI-49 trap), so text colour goes through the override channel.
	if _label != null:
		_label.add_theme_color_override("font_color",
			UIPalette.TEXT_ON_LIVE if active else UIPalette.TEXT_SECONDARY)
	if _glyph_rect != null:
		# A TextureRect has no font colour, so modulate is the right channel here.
		_glyph_rect.modulate = UIPalette.LIVE_BRIGHT if active else UIPalette.TEXT_SECONDARY
	if _hotkey_label != null:
		_hotkey_label.add_theme_color_override("font_color",
			UIPalette.LIVE if active else UIPalette.TEXT_META)
	if disabled:
		_apply_disabled_tint()

## A disabled slot (STORES until WI-56) still renders - a disabled button that
## says why is better than a hidden one, and it proves the console layout at full
## width from day one.
func _apply_disabled_tint() -> void:
	if _label != null:
		_label.add_theme_color_override("font_color", UIPalette.TEXT_META)
	if _glyph_rect != null:
		_glyph_rect.modulate = UIPalette.tinted(UIPalette.TEXT_META, 0.6)
	if _hotkey_label != null:
		_hotkey_label.add_theme_color_override("font_color",
			UIPalette.tinted(UIPalette.TEXT_META, 0.6))

func set_disabled_with_reason(reason: String) -> void:
	disabled = true
	tooltip_text = reason
	_apply_state()

## The inverse, for a slot that gains its panel (STORES, at WI-56).
func set_enabled(tooltip: String) -> void:
	disabled = false
	tooltip_text = tooltip
	_apply_state()

## The active fill at rest and under the cursor. Built once and shared by every
## button, the way [UIPalette] shares its row styles - they are immutable and
## the console re-applies them on every mode change.
static var _cached_active: StyleBoxFlat = null
static var _cached_active_hover: StyleBoxFlat = null

static func _active_style() -> StyleBoxFlat:
	if _cached_active == null:
		_cached_active = _make_active_style(UIPalette.ROW_LIVE_ALPHA)
	return _cached_active

static func _active_hover_style() -> StyleBoxFlat:
	if _cached_active_hover == null:
		_cached_active_hover = _make_active_style(UIPalette.ROW_LIVE_ALPHA * 2.0)
	return _cached_active_hover

static func _make_active_style(fill_alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.tinted(UIPalette.LIVE, fill_alpha)
	# The button's border is LIVE where the panel it opens wears the dimmer
	# ACTIVE_BORDER: the design gives the console button the brighter of the two
	# on purpose, because it is the smaller target.
	box.border_color = UIPalette.LIVE
	box.set_border_width_all(UIMetrics.BORDER_WIDTH)
	box.set_corner_radius_all(0)
	return box

static func _dot_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.LIVE
	box.set_corner_radius_all(DOT_SIZE / 2)
	# The dot is the one thing in the HUD allowed to glow, per the palette table.
	box.shadow_color = UIPalette.tinted(UIPalette.LIVE, 0.55)
	box.shadow_size = 4
	return box

static func _badge_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.tinted(UIPalette.ATTENTION, 0.22)
	box.border_color = UIPalette.ATTENTION_BORDER
	box.set_border_width_all(UIMetrics.BORDER_WIDTH)
	box.set_corner_radius_all(0)
	return box
