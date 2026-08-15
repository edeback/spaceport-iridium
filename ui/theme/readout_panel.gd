@tool
class_name ReadoutPanel
extends Control

## The right-column surface (WI-49): the same body treatment as [ConsolePanel]
## but with the **34px** header instead of the 56px one - a 3x14 accent bar in
## the readout's own colour, the label, a spacer, and a slot for actions
## (`HISTORY`, `CLEAR ALL`, an `M` hotkey, the inspector's close control).
##
## Used by the station map, the alert feed and the inspector.
##
## The two header heights are different **on purpose** and that difference is
## what makes the hierarchy read: a panel is a workspace, a readout is a thing
## you glance at. So this is a separate scene rather than [ConsolePanel] with a
## parameter, because a parameter is an invitation to split the difference.
##
## Unlike a mode panel, a readout does not anchor itself. Readouts stack in the
## right column and their positions are the column's business (WI-50), so this
## frame only reports the size it wants.

@export var label: String = "READOUT":
	set(value):
		label = value
		_apply_label()

## The accent bar's colour, which is how a readout says what kind of thing it
## is: LIVE for the map, ATTENTION for alerts. It is the one place a readout is
## allowed to spend colour.
@export var accent_color: Color = UIPalette.LIVE:
	set(value):
		accent_color = value
		_apply_accent()

@export var panel_width: int = UIMetrics.RIGHT_COLUMN_WIDTH:
	set(value):
		panel_width = value
		_apply_layout()

## Distance from the **right edge of the screen** to this readout's right edge.
##
## The right column sits one gutter in; the two flyouts (the resource ledger and
## the alert log) stop short of the column entirely, which is what
## [constant UIMetrics.LEDGER_RIGHT_INSET] and
## [constant UIMetrics.ALERT_HISTORY_RIGHT_INSET] encode.
##
## It exists because [member panel_width] used to be **cosmetic** for a
## right-anchored readout (WI-58): the frame reported the width as a minimum size
## but never wrote the offsets, so the real geometry was a hand-typed `-364` in
## six separate scene files. All six agreed with the design table, and all six
## would have silently stopped agreeing the moment
## [constant UIMetrics.RIGHT_COLUMN_WIDTH] moved. [ConsolePanel] has always
## written its own offsets; this is the readout half of that.
@export var right_inset: int = UIMetrics.SCREEN_GUTTER:
	set(value):
		right_inset = value
		_apply_layout()

## Fixed height of the content region. Zero means "as tall as the content asks
## for", which is what a list-shaped readout (the alert feed) wants; the map
## wants a fixed square.
@export var content_height: int = 0:
	set(value):
		content_height = value
		_apply_layout()

@export var content_padding: int = UIMetrics.READOUT_CONTENT_PAD:
	set(value):
		content_padding = value
		_apply_padding()

## Whether clicking the header folds the content away. The map has always been
## collapsible; putting it in the frame means the alert feed gets it free.
@export var collapsible: bool = false:
	set(value):
		collapsible = value
		_apply_collapse()

@export var collapsed: bool = false:
	set(value):
		collapsed = value
		_apply_collapse()

## The inspector floats over the station and needs to separate from it; the map
## and alert feed sit against the edge and do not.
@export var drop_shadow: bool = false:
	set(value):
		drop_shadow = value
		_apply_surface()

## Emitted after the header toggles the fold, so a caller can stop doing work
## for content nobody can see.
signal collapse_toggled(is_collapsed: bool)

var _body: Panel
var _highlight: ColorRect
var _header: Control
var _row: HBoxContainer
var _gradient: TextureRect
var _accent: ColorRect
var _label: Label
var _action_slot: HBoxContainer
var _header_edge: ColorRect
var _header_button: Button
var _content: MarginContainer

func _ready() -> void:
	_ensure_refs()
	if _header_button != null and not _header_button.pressed.is_connected(_on_header_pressed):
		_header_button.pressed.connect(_on_header_pressed)
	_apply_all()

## Lazy, for the same reason as [ConsolePanel]: exported setters fire during
## scene load before the children exist, and callers configure frames before
## mounting them.
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
	_header_button = get_node_or_null("Column/Header/Toggle") as Button
	_accent = get_node_or_null("Column/Header/Row/Accent") as ColorRect
	_label = get_node_or_null("Column/Header/Row/Label") as Label
	_action_slot = get_node_or_null("Column/Header/Row/ActionSlot") as HBoxContainer
	_header_edge = get_node_or_null("Column/Header/Edge") as ColorRect
	_content = get_node_or_null("Column/Content") as MarginContainer

# --- public -------------------------------------------------------------------

## Where the readout puts its own content.
func content() -> MarginContainer:
	_ensure_refs()
	return _content

## Mounts a control in the header's right-hand action slot.
func add_action(control: Control) -> void:
	_ensure_refs()
	if _action_slot == null or control == null:
		return
	_action_slot.add_child(control)

func clear_actions() -> void:
	_ensure_refs()
	if _action_slot == null:
		return
	for child: Node in _action_slot.get_children():
		child.queue_free()

func toggle_collapsed() -> void:
	collapsed = not collapsed
	collapse_toggled.emit(collapsed)

## Sets `offset_bottom` from the height the frame wants, for a readout that is
## positioned by anchors rather than laid out by a container. Anchored controls
## ignore `custom_minimum_size`, so without this a collapsed readout keeps its
## expanded rect and swallows clicks meant for the station behind it.
##
## Called automatically whenever it is unambiguously safe (see [_apply_layout]);
## public for a caller that repositions a readout by hand.
func fit_height() -> void:
	_ensure_refs()
	if _body == null:
		return
	offset_bottom = offset_top + custom_minimum_size.y

# --- appearance ---------------------------------------------------------------

func _on_header_pressed() -> void:
	if collapsible:
		toggle_collapsed()

func _apply_all() -> void:
	_apply_layout()
	_apply_label()
	_apply_accent()
	_apply_padding()
	_apply_collapse()
	_apply_surface()

func _apply_layout() -> void:
	_ensure_refs()
	if _body == null:
		return
	var height: float = float(UIMetrics.READOUT_HEADER_HEIGHT)
	if not collapsed and content_height > 0:
		height += float(content_height)
	# A zero content_height means "fit the content", so the frame reports only
	# its header and lets the VBox grow past it.
	custom_minimum_size = Vector2(float(panel_width), height)
	if _content != null:
		_content.custom_minimum_size.y = 0.0 if content_height <= 0 else float(content_height)
	if _gradient != null:
		_gradient.texture = UIPalette.readout_header_gradient()
	if _highlight != null:
		# Inset by the border on all four sides - a readout is bordered the whole
		# way round, so its inner highlight sits inside that border, not over it.
		var edge: float = float(UIMetrics.BORDER_WIDTH)
		_highlight.color = UIPalette.INNER_HIGHLIGHT
		_highlight.offset_left = edge
		_highlight.offset_right = -edge
		_highlight.offset_top = edge
		_highlight.offset_bottom = edge * 2.0
	# The scene authors structure; every number comes from [UIMetrics], so the
	# 34px header cannot drift to 36 in one readout.
	if _header != null:
		_header.custom_minimum_size.y = float(UIMetrics.READOUT_HEADER_HEIGHT)
	if _row != null:
		_row.offset_left = float(UIMetrics.READOUT_HEADER_PAD)
		_row.offset_right = -float(UIMetrics.READOUT_HEADER_PAD)
		_row.add_theme_constant_override("separation", UIMetrics.READOUT_HEADER_GAP)
	if _accent != null:
		_accent.custom_minimum_size = Vector2(
			float(UIMetrics.ACCENT_BAR_WIDTH), float(UIMetrics.READOUT_ACCENT_HEIGHT))
	if _header_edge != null:
		_header_edge.custom_minimum_size.y = float(UIMetrics.BORDER_WIDTH)
		_header_edge.offset_top = -float(UIMetrics.BORDER_WIDTH)
	# A readout pinned to a point (top and bottom anchored the same) and not
	# inside a container has nobody to give it a height, so it takes its own.
	# The stretched and container-laid-out cases are somebody else's business
	# and must not be overridden here.
	if get_parent() is Container:
		return
	_apply_horizontal_offsets()
	if is_equal_approx(anchor_top, anchor_bottom):
		fit_height()

## Writes the horizontal offsets a right-anchored readout implies, so
## [member panel_width] and [member right_inset] are the geometry rather than a
## description of it (WI-58).
##
## Only the right-anchored case, which is every readout in the design: the right
## column and the two flyouts. A readout anchored some other way was positioned
## deliberately by whoever anchored it, and this must not fight them.
func _apply_horizontal_offsets() -> void:
	if not (is_equal_approx(anchor_left, 1.0) and is_equal_approx(anchor_right, 1.0)):
		return
	offset_right = -float(right_inset)
	offset_left = -float(right_inset + panel_width)

func _apply_label() -> void:
	_ensure_refs()
	if _label == null:
		return
	_label.text = label.to_upper()

func _apply_accent() -> void:
	_ensure_refs()
	if _accent == null:
		return
	_accent.color = accent_color

func _apply_padding() -> void:
	_ensure_refs()
	if _content == null:
		return
	for side: String in ["left", "top", "right", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, content_padding)

func _apply_collapse() -> void:
	_ensure_refs()
	if _content == null:
		return
	_content.visible = not collapsed
	if _header_button != null:
		# A non-collapsible readout's header is inert, and an inert control that
		# still eats clicks is how a click-through bug gets built.
		_header_button.mouse_filter = (Control.MOUSE_FILTER_STOP if collapsible
			else Control.MOUSE_FILTER_IGNORE)
	_apply_layout()

func _apply_surface() -> void:
	_ensure_refs()
	if _body == null:
		return
	var alpha: float = UIMetrics.INSPECTOR_ALPHA if drop_shadow else UIMetrics.READOUT_ALPHA
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.tinted(UIPalette.PANEL, alpha)
	# A readout is a floating box in the right column, so unlike a mode panel it
	# wears all four borders.
	box.border_color = UIPalette.ACTIVE_BORDER if drop_shadow else UIPalette.EDGE
	box.set_border_width_all(UIMetrics.BORDER_WIDTH)
	box.set_corner_radius_all(0)
	if drop_shadow:
		box.shadow_size = UIMetrics.READOUT_SHADOW_SIZE
		box.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	_body.add_theme_stylebox_override("panel", box)
	if _header_edge != null:
		_header_edge.color = box.border_color
