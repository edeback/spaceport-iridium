@tool
class_name ConsolePanel
extends Control

## The left-mounted mode panel frame (WI-49). Exactly one implementation, used
## by all seven modes - invariant 6 says most of what looks unfinished today is
## frame inconsistency, and one frame is how that stops being true.
##
## Anatomy, top to bottom:
##   - a 1px inner top highlight, so the surface reads as lit from above;
##   - a 56px header: a 3x20 LIVE accent bar, the title, an optional divider and
##     subtitle (the "6 ABOARD - 4 BUNKS" slot every panel has), a flex spacer,
##     a slot for one header control, and the hotkey hint right-aligned;
##   - a content region the panel fills.
##
## The panel runs from the top of the screen to the top of the console, takes
## its width from [UIMetrics], and carries a right border that goes cyan while
## it is the active mode. It anchors itself: a mode panel is never laid out by a
## container, and a panel that took its width from its parent would be 60% of an
## ultrawide and unreadable.
##
## Deliberately provides **no scrolling**. Panels differ on whether their header
## row scrolls with the content, so each adds its own [ScrollContainer] where it
## wants one.
##
## [ReadoutPanel] is the right-column counterpart and is a separate scene on
## purpose - the 56/34 header-height difference is what makes the hierarchy
## read, so it must not be this frame with a parameter.

## Shown right-aligned in the header when a panel does not override it. Esc
## closes every panel (WI-50 owns the arbitration), so this is the honest
## default rather than a per-panel decision.
const DEFAULT_HOTKEY: String = "ESC"

@export var title: String = "PANEL":
	set(value):
		title = value
		_apply_title()

## The "6 ABOARD - 4 BUNKS" / "2 UNREAD" slot. Empty hides it and its divider.
@export var subtitle: String = "":
	set(value):
		subtitle = value
		_apply_subtitle()

@export var hotkey: String = DEFAULT_HOTKEY:
	set(value):
		hotkey = value
		_apply_hotkey()

## One of [UIMetrics]' per-panel widths. Fixed pixels, never a fraction.
@export var panel_width: int = UIMetrics.PANEL_CREW_WIDTH:
	set(value):
		panel_width = value
		_apply_layout()

## Padding inside the content region. Zero by default because the panels that
## run edge-to-edge lists (Build's rail, Stores' rows) are the common case.
@export var content_padding: int = 0:
	set(value):
		content_padding = value
		_apply_padding()

## True while this panel is the open mode: its right edge goes cyan. False is
## for a panel that is mounted but not the one being looked at.
@export var active: bool = true:
	set(value):
		active = value
		_apply_active()

var _body: Panel
var _highlight: ColorRect
var _header: Control
var _row: HBoxContainer
var _accent: ColorRect
var _title_label: Label
var _divider: ColorRect
var _subtitle_label: Label
var _header_slot: HBoxContainer
var _hotkey_label: Label
var _header_edge: ColorRect
var _content: MarginContainer
var _gradient: TextureRect

func _ready() -> void:
	_ensure_refs()
	_apply_all()

## Node lookups are lazy rather than `@onready` because the exported setters run
## during scene load, before the children exist, and because a caller may
## configure this frame before adding it to the tree. Every accessor goes
## through here so the order the caller happens to use cannot matter - the
## WI-48 lesson, applied to the frame every later panel is built on.
func _ensure_refs() -> void:
	if _body != null:
		return
	_body = get_node_or_null("Body") as Panel
	if _body == null:
		return
	_highlight = get_node_or_null("Highlight") as ColorRect
	_header = get_node_or_null("Column/Header") as Control
	_row = get_node_or_null("Column/Header/Row") as HBoxContainer
	_gradient = get_node_or_null("Column/Header/Gradient") as TextureRect
	_accent = get_node_or_null("Column/Header/Row/Accent") as ColorRect
	_title_label = get_node_or_null("Column/Header/Row/Title") as Label
	_divider = get_node_or_null("Column/Header/Row/Divider") as ColorRect
	_subtitle_label = get_node_or_null("Column/Header/Row/Subtitle") as Label
	_header_slot = get_node_or_null("Column/Header/Row/HeaderSlot") as HBoxContainer
	_hotkey_label = get_node_or_null("Column/Header/Row/Hotkey") as Label
	_header_edge = get_node_or_null("Column/Header/Edge") as ColorRect
	_content = get_node_or_null("Column/Content") as MarginContainer

# --- public -------------------------------------------------------------------

## Where a panel puts its own content. Never add children to the panel itself -
## they would land as siblings of the frame and draw over the header.
func content() -> MarginContainer:
	_ensure_refs()
	return _content

## Mounts one control in the header's right-hand slot, beside the hotkey hint
## (R&D's balance chip is the motivating case). Panels that need two are asking
## for a toolbar, which belongs in the content region.
func add_header_control(control: Control) -> void:
	_ensure_refs()
	if _header_slot == null or control == null:
		return
	_header_slot.add_child(control)

## Clears the header's control slot - for a panel whose header control depends
## on state that can go away.
func clear_header_controls() -> void:
	_ensure_refs()
	if _header_slot == null:
		return
	for child: Node in _header_slot.get_children():
		child.queue_free()

# --- appearance ---------------------------------------------------------------

func _apply_all() -> void:
	_apply_layout()
	_apply_title()
	_apply_subtitle()
	_apply_hotkey()
	_apply_padding()
	_apply_active()
	_apply_static_colors()

## The colours that never change. Set in code rather than in the scene so the
## palette stays the single authority - a scene-authored Color is a hex literal
## that no longer tracks [UIPalette].
func _apply_static_colors() -> void:
	_ensure_refs()
	if _body == null:
		return
	if _highlight != null:
		_highlight.color = UIPalette.INNER_HIGHLIGHT
	if _accent != null:
		_accent.color = UIPalette.LIVE
	if _divider != null:
		_divider.color = UIPalette.CONTROL_BORDER
	if _gradient != null:
		_gradient.texture = UIPalette.panel_header_gradient()

## Left-anchored, top of the screen to the top of the console, fixed width.
##
## The scene authors the *structure*; every number comes from [UIMetrics] here,
## so a scene file can never hold a header height that disagrees with the design
## system. That split is the whole reason the frame is one implementation.
func _apply_layout() -> void:
	_ensure_refs()
	if _body == null:
		return
	set_anchors_preset(Control.PRESET_LEFT_WIDE, true)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = float(panel_width)
	offset_bottom = -float(UIMetrics.CONSOLE_HEIGHT)
	custom_minimum_size = Vector2(float(panel_width), 0.0)
	if _header != null:
		_header.custom_minimum_size.y = float(UIMetrics.PANEL_HEADER_HEIGHT)
	if _row != null:
		_row.offset_left = float(UIMetrics.PANEL_HEADER_PAD)
		_row.offset_right = -float(UIMetrics.PANEL_HEADER_PAD)
		_row.add_theme_constant_override("separation", UIMetrics.PANEL_HEADER_GAP)
	if _accent != null:
		_accent.custom_minimum_size = Vector2(
			float(UIMetrics.ACCENT_BAR_WIDTH), float(UIMetrics.PANEL_ACCENT_HEIGHT))
	if _divider != null:
		_divider.custom_minimum_size = Vector2(
			float(UIMetrics.BORDER_WIDTH), float(UIMetrics.PANEL_ACCENT_HEIGHT) - 2.0)
	if _header_edge != null:
		_header_edge.custom_minimum_size.y = float(UIMetrics.BORDER_WIDTH)
		_header_edge.offset_top = -float(UIMetrics.BORDER_WIDTH)
	if _highlight != null:
		# The panel's other three edges sit against the viewport, so its highlight
		# runs the full width at y=0 rather than being inset like a readout's.
		_highlight.offset_top = 0.0
		_highlight.offset_bottom = float(UIMetrics.BORDER_WIDTH)

func _apply_title() -> void:
	_ensure_refs()
	if _title_label == null:
		return
	# Caps is a content decision, not a font one - Godot has no text-transform -
	# so the widget that owns the label does it, once, here.
	_title_label.text = title.to_upper()

func _apply_subtitle() -> void:
	_ensure_refs()
	if _subtitle_label == null:
		return
	var has_subtitle: bool = not subtitle.strip_edges().is_empty()
	_subtitle_label.text = subtitle.to_upper()
	_subtitle_label.visible = has_subtitle
	if _divider != null:
		_divider.visible = has_subtitle

func _apply_hotkey() -> void:
	_ensure_refs()
	if _hotkey_label == null:
		return
	_hotkey_label.text = hotkey
	_hotkey_label.visible = not hotkey.is_empty()

func _apply_padding() -> void:
	_ensure_refs()
	if _content == null:
		return
	for side: String in ["left", "top", "right", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, content_padding)

## The active panel's right edge and header underline go cyan; an inactive one
## wears the inert EDGE. This is the only place the two states differ, which is
## why "which panel is open" never needs a second visual cue.
func _apply_active() -> void:
	_ensure_refs()
	if _body == null:
		return
	var edge: Color = UIPalette.ACTIVE_BORDER if active else UIPalette.EDGE
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.tinted(UIPalette.PANEL, UIMetrics.PANEL_ALPHA)
	box.border_color = edge
	box.set_border_width_all(0)
	# Only the right edge is ever on screen - the other three sit against the
	# viewport edges - so the panel wears one border, not four.
	box.border_width_right = UIMetrics.BORDER_WIDTH
	box.set_corner_radius_all(0)
	box.shadow_size = UIMetrics.PANEL_SHADOW_SIZE
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	_body.add_theme_stylebox_override("panel", box)
	if _header_edge != null:
		_header_edge.color = edge
