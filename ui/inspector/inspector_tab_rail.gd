class_name InspectorTabRail
extends MarginContainer

## The inverted inspector's tabs (2026-09-13): a thin rail of folder tabs standing
## on the identity strip, with the detail box rising out of whichever one is open.
##
## Not a [TabStrip], and deliberately so. A strip is a *selector* - something is
## always selected, and it emits when that changes. This rail is a **toggle**:
## nothing open is its resting state, and pressing the open tab closes it. The
## rule for what a press means is [method InspectorTabPlan.tab_after_click]; the
## rail only reports the press and draws whatever the panel tells it is open.
##
## The look, from the design:
## - a closed tab is a PANEL tab with an EDGE border on three sides and none on
##   the bottom, so it reads as standing on the strip below it;
## - the open tab loses its side borders' dimness (ACTIVE_BORDER), gains a cyan
##   wash and a 2px LIVE cap, and stands 2px taller, so the tab and the box above
##   it read as one shape;
## - while a tab is open the whole rail is filled, side borders included, so the
##   box, the rail and the strip read as one column. The design filled only the
##   lower half and left the rest see-through; in play that read as a notch cut
##   out of the panel beside the tabs (2026-09-13). At rest there is no box above
##   to join, so the rail stays clear and the tabs stand on the strip alone.

## The player pressed a tab. Whether that opens or closes it is the panel's rule,
## not the rail's.
signal tab_pressed(id: StringName)

var _flow: HFlowContainer
var _fill: Panel
var _open: StringName = &""
var _ids: Array[StringName] = []

func _init() -> void:
	name = "Rail"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, 0)

	# The fill behind the tabs while one is open: the panel surface with the box's
	# side borders carried down through it, so the column's two edges run unbroken
	# from the top of the box to the strip. A [MarginContainer] lays it over the
	# whole rail, and it catches the mouse there - a solid surface must not let a
	# click fall through to the station behind it.
	_fill = Panel.new()
	_fill.name = "Fill"
	_fill.visible = false
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = UIPalette.tinted(UIPalette.PANEL, UIMetrics.INSPECTOR_ALPHA)
	fill_box.border_color = UIPalette.ACTIVE_BORDER
	fill_box.border_width_left = UIMetrics.BORDER_WIDTH
	fill_box.border_width_right = UIMetrics.BORDER_WIDTH
	fill_box.border_width_top = 0
	fill_box.border_width_bottom = 0
	_fill.add_theme_stylebox_override("panel", fill_box)
	add_child(_fill)

	var inset := MarginContainer.new()
	inset.name = "Inset"
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inset on the left only. The tabs are left-aligned, so a right inset would only
	# ever matter at the moment of wrapping - where it would push the last tab onto
	# a second row a dozen pixels early.
	inset.add_theme_constant_override("margin_left", UIMetrics.INSPECTOR_RAIL_INSET)
	inset.add_theme_constant_override("margin_right", 0)
	inset.add_theme_constant_override("margin_top", 0)
	inset.add_theme_constant_override("margin_bottom", 0)
	add_child(inset)

	# A flow, so a module with more tabs than 420px holds wraps onto a second row
	# rather than running off the panel - a mod's components land here too.
	_flow = HFlowContainer.new()
	_flow.name = "Tabs"
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flow.add_theme_constant_override("h_separation", UIMetrics.INSPECTOR_TAB_GAP)
	_flow.add_theme_constant_override("v_separation", 0)
	inset.add_child(_flow)

# --- public -------------------------------------------------------------------

## `defs` is an array of `{id: StringName, text: String}`. Nothing is open after a
## rebuild; the panel says what is with [method set_open].
func set_tabs(defs: Array) -> void:
	for child: Node in _flow.get_children():
		_flow.remove_child(child)
		child.queue_free()
	_ids.clear()
	_open = &""
	for def: Variant in defs:
		var entry: Dictionary = def as Dictionary
		if entry == null or not entry.has("id"):
			continue
		var id: StringName = StringName(entry["id"])
		_ids.append(id)
		_flow.add_child(_make_tab(id, str(entry.get("text", id))))
	_apply_open()

## Draws `id` as the open tab, or none for `&""`. Emits nothing: the panel is the
## one deciding, and it calls this after it has.
func set_open(id: StringName) -> void:
	_open = id if _ids.has(id) else &""
	_apply_open()

func open_tab() -> StringName:
	return _open

func tab_ids() -> Array[StringName]:
	return _ids.duplicate()

func is_empty() -> bool:
	return _ids.is_empty()

# --- building -----------------------------------------------------------------

func _make_tab(id: StringName, text: String) -> Button:
	var tab := Button.new()
	tab.name = String(id)
	tab.text = text.to_upper()
	tab.focus_mode = Control.FOCUS_NONE
	# Tabs of different heights (the open one stands taller) sit on one baseline:
	# the strip under them.
	tab.size_flags_vertical = Control.SIZE_SHRINK_END
	tab.pressed.connect(func() -> void: tab_pressed.emit(id))

	# The open tab's wash, drawn *behind* the button so its borders and label land
	# on top of it. Hidden on a closed tab.
	var wash := TextureRect.new()
	wash.name = "Wash"
	wash.texture = UIPalette.open_tab_gradient()
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.show_behind_parent = true
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab.add_child(wash)

	# The 2px cap. A child rather than a border because a [StyleBoxFlat] draws one
	# border colour, and the cap is LIVE where the sides are ACTIVE_BORDER - the
	# same reason a list row's left accent is a child rect.
	var cap := ColorRect.new()
	cap.name = "Cap"
	cap.color = UIPalette.LIVE
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cap.offset_bottom = float(UIMetrics.INSPECTOR_TAB_CAP)
	tab.add_child(cap)
	return tab

func _apply_open() -> void:
	_fill.visible = _open != &""
	for child: Node in _flow.get_children():
		var tab: Button = child as Button
		if tab == null:
			continue
		var open: bool = StringName(tab.name) == _open
		# The theme supplies the 11px face and a closed tab's colours; the open tab's
		# label is lifted here, and the boxes are this rail's own, because a folder
		# tab is a different shape from the strip's underlined one.
		tab.theme_type_variation = UIType.INSPECTOR_TAB
		for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
			if open:
				tab.add_theme_color_override(color_name, UIPalette.TEXT_ON_LIVE)
			else:
				tab.remove_theme_color_override(color_name)
		var wash: TextureRect = tab.get_node_or_null("Wash") as TextureRect
		if wash != null:
			wash.visible = open
		var cap: ColorRect = tab.get_node_or_null("Cap") as ColorRect
		if cap != null:
			cap.visible = open
		var rest: StyleBoxFlat = _open_box() if open else _closed_box(false)
		var hover: StyleBoxFlat = _open_box() if open else _closed_box(true)
		tab.add_theme_stylebox_override("normal", rest)
		tab.add_theme_stylebox_override("pressed", rest)
		tab.add_theme_stylebox_override("hover", hover)
		tab.add_theme_stylebox_override("hover_pressed", hover)
		tab.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## A closed tab: a surface of its own with three borders, none on the bottom.
## Hover lifts it to the control fill and border, the way every other button in
## the HUD answers a hover.
func _closed_box(hover: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.CONTROL_FILL if hover \
		else UIPalette.tinted(UIPalette.PANEL, UIMetrics.INSPECTOR_ALPHA)
	box.border_color = UIPalette.CONTROL_BORDER if hover else UIPalette.EDGE
	box.border_width_left = UIMetrics.BORDER_WIDTH
	box.border_width_right = UIMetrics.BORDER_WIDTH
	box.border_width_top = UIMetrics.BORDER_WIDTH
	box.border_width_bottom = 0
	_pad(box, UIMetrics.BORDER_WIDTH)
	return box

## The open tab: no fill of its own (the wash is behind it), ACTIVE_BORDER sides,
## and room at the top for the cap, which is what makes it stand 2px taller.
func _open_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = UIPalette.ACTIVE_BORDER
	box.border_width_left = UIMetrics.BORDER_WIDTH
	box.border_width_right = UIMetrics.BORDER_WIDTH
	box.border_width_top = 0
	box.border_width_bottom = 0
	_pad(box, UIMetrics.INSPECTOR_TAB_CAP + UIMetrics.BORDER_WIDTH)
	return box

## Content margins: the tab padding, plus whatever the top edge spends, plus the
## tracked label's centring nudge on the left (see
## [method UIMetrics.nudge_content_box]).
func _pad(box: StyleBoxFlat, top_edge: int) -> void:
	box.content_margin_left = float(UIMetrics.INSPECTOR_TAB_PAD_H + UIMetrics.TRACKING_TAB_LABEL)
	box.content_margin_right = float(UIMetrics.INSPECTOR_TAB_PAD_H)
	box.content_margin_top = float(UIMetrics.INSPECTOR_TAB_PAD_V + top_edge)
	box.content_margin_bottom = float(UIMetrics.INSPECTOR_TAB_PAD_V)
