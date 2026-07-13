class_name UnlockNodeCard
extends PanelContainer

## One card in the global tech-tree panel, representing a single UnlockData.
## Fully code-generated (no scene) so the panel can lay these out dynamically.

var unlock: UnlockData

var _icon: TextureRect
var _name_label: Label
var _cost_label: Label
var _status_label: Label
var _button: Button

const COLOR_UNLOCKED := Color(0.25, 0.55, 0.30)
const COLOR_AVAILABLE := Color(0.24, 0.42, 0.66)
const COLOR_LOCKED := Color(0.30, 0.30, 0.34)
const COLOR_UNAFFORDABLE := Color(0.55, 0.40, 0.22)

func setup(u: UnlockData) -> void:
	unlock = u
	custom_minimum_size = Vector2(210, 0)
	# Fixed width (don't expand to fill the row) so depth columns line up.
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(48, 48)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if unlock.icon != null:
		_icon.texture = unlock.icon
	hbox.add_child(_icon)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	_name_label = Label.new()
	_name_label.text = unlock.name
	_name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_name_label)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_cost_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	_button = Button.new()
	_button.text = "Research"
	_button.pressed.connect(_on_pressed)
	vbox.add_child(_button)

	# Show the description on hover. Inner display controls are made transparent
	# to the mouse so hovering anywhere on the card surfaces the card's tooltip;
	# the button keeps its own tooltip (and stays clickable).
	if unlock.description != "":
		tooltip_text = unlock.description
		_button.tooltip_text = unlock.description
	for c: Control in [margin, hbox, vbox, _icon, _name_label, _cost_label, _status_label]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	refresh()

func _on_pressed() -> void:
	# The panel listens to global_unlock_changed and refreshes every card, so we
	# don't need to update ourselves here.
	Global.unlock_manager.try_unlock(unlock)

func refresh() -> void:
	var mgr := Global.unlock_manager
	var border_color := COLOR_LOCKED

	if mgr.is_unlocked(unlock):
		_cost_label.visible = false
		_button.visible = false
		_status_label.text = "Unlocked"
		_status_label.modulate = Color(0.7, 1.0, 0.75)
		border_color = COLOR_UNLOCKED
	else:
		_cost_label.visible = true
		_cost_label.text = _cost_text()
		_button.visible = true
		if not mgr.prerequisites_met(unlock):
			_button.disabled = true
			_status_label.text = "Requires: " + _prereq_names()
			_status_label.modulate = Color(0.7, 0.7, 0.75)
			border_color = COLOR_LOCKED
		elif not unlock.can_afford():
			_button.disabled = true
			_status_label.text = "Can't afford"
			_status_label.modulate = Color(1.0, 0.7, 0.5)
			border_color = COLOR_UNAFFORDABLE
		else:
			_button.disabled = false
			_status_label.text = ""
			border_color = COLOR_AVAILABLE

	add_theme_stylebox_override("panel", _make_style(border_color))

func _make_style(border_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.15, 0.95)
	sb.set_border_width_all(2)
	sb.border_color = border_color
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(2)
	return sb

func _cost_text() -> String:
	if unlock.cost.is_empty():
		return "Free"
	var parts: Array[String] = []
	for resource: ResourceData in unlock.cost:
		parts.append("%d %s" % [unlock.cost[resource], resource.name])
	return ", ".join(parts)

func _prereq_names() -> String:
	var parts: Array[String] = []
	for prereq: UnlockData in unlock.prerequisites:
		if prereq != null:
			parts.append(prereq.name)
	return ", ".join(parts)
