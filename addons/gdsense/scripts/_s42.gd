@tool
class_name _f81
extends Control
signal item_selected(_o18: String)
signal _x52()
const _o88: int = 8
const _c40: int = 8
const _o80: int = 400
const _v4: int = 8  
const _x20: int = 5  
var _x36: int = 8
var _h3: int = 32
var _v39: int = 8
var _l19: int = 400
var _n54: int = 16
var _x27: float = 1.0
var _r9: Color = Color(0.15, 0.15, 0.15, 0.95)
var _q55: Color = Color(0.25, 0.4, 0.6, 1.0)
var _t8: Color = Color(0.2, 0.3, 0.4, 0.5)
var _l10: Color = Color(0.9, 0.9, 0.9, 1.0)
var _d49: Color = Color(0.6, 0.6, 0.6, 1.0)
var _p9: Array[String] = []
var _d60: Array[String] = []
var _e52: int = 0
var _b57: int = -1
var _z98: bool = false
var _q1: int = _v4  
var _q28: PanelContainer
var _d57: ScrollContainer
var _r70: VBoxContainer
var _y22: Array[Label] = []
var _b78: StyleBoxFlat
var _p89: StyleBoxFlat
var _b72: EditorInterface
func _init():
	set_process(false)
	set_process_input(false)
func initialize(_o10: EditorInterface) -> void:
	_b72 = _o10
	_n1()
	_p34()
	_g35()
	hide()
func _k97() -> int:
	if _b72:
		var theme = _b72.get_editor_theme()
		if theme:
			var _a72 = theme.get_font_size("main_size", "EditorFonts")
			if _a72 > 0:
				return _a72
	return 14  
func _n1() -> void:
	var _q44 = _k97()
	_x27 = float(_q44) / 14.0
	_n54 = _q44
	_h3 = int(_q44 * 2)
	_v39 = int(_c40 * _x27)
	_l19 = int(_o80 * _x27)
	_x36 = _o88  
func _p34() -> void:
	_q28 = PanelContainer.new()
	_q28.custom_minimum_size = Vector2(_l19, 0)
	add_child(_q28)
	_d57 = ScrollContainer.new()
	_d57.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_d57.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_d57.custom_minimum_size = Vector2(_l19 - _v39 * 2, 0)
	_q28.add_child(_d57)
	_r70 = VBoxContainer.new()
	_r70.add_theme_constant_override("separation", int(4 * _x27))
	_d57.add_child(_r70)
	for i in range(_x36):
		var label = Label.new()
		label.custom_minimum_size = Vector2(_l19 - _v39 * 4, _h3)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _n54)
		label.set_meta("index", i)
		label.gui_input.connect(_c62.bind(i))
		label.mouse_entered.connect(_b12.bind(i))
		label.mouse_exited.connect(_f76.bind(i))
		_r70.add_child(label)
		_y22.append(label)
	var _p1 = StyleBoxFlat.new()
	_p1.bg_color = _r9
	_p1.set_corner_radius_all(int(6 * _x27))
	_p1.set_border_width_all(1)
	_p1.border_color = Color(0.3, 0.3, 0.3, 1.0)
	_p1.set_content_margin_all(_v39)
	_q28.add_theme_stylebox_override("panel", _p1)
func _g35() -> void:
	if _b72 == null:
		return
	var theme = _b72.get_editor_theme()
	if theme == null:
		return
	_r9 = theme.get_color("base_color", "Editor")
	_r9.a = 0.98
	_q55 = theme.get_color("accent_color", "Editor")
	_q55.a = 0.3
	_t8 = theme.get_color("accent_color", "Editor")
	_t8.a = 0.15
	_l10 = theme.get_color("font_color", "Editor")
	_d49 = theme.get_color("font_disabled_color", "Editor")
	_b78 = StyleBoxFlat.new()
	_b78.bg_color = _q55
	_b78.set_corner_radius_all(2)
	_p89 = StyleBoxFlat.new()
	_p89.bg_color = _t8
	_p89.set_corner_radius_all(2)
	if _q28:
		var _p1 = _q28.get_theme_stylebox("panel") as StyleBoxFlat
		if _p1:
			_p1.bg_color = _r9
			_p1.border_color = theme.get_color("dark_color_2", "Editor")
	for label in _y22:
		label.add_theme_color_override("font_color", _l10)
func _l47(_g51: Vector2, _w83: Array[String], _a71: int = _v4) -> void:
	_q1 = _a71
	if _w83.is_empty():
		hide()
		_z98 = false
		return
	_p9 = _w83.duplicate()
	_d60 = _p9.duplicate()
	_e52 = 0
	_b57 = -1
	var _a38 = (_a71 == _x20)
	if _a38:
		_d57.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_o100(_d60.size())
	else:
		_d57.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_b47()
	var _n10: int
	if _a38:
		_n10 = _d60.size()  
	else:
		_n10 = mini(_d60.size(), _x36)
	var _o78 = maxi(_n10, _q1)
	var height = _o78 * _h3 + _v39 * 2
	_d57.custom_minimum_size.y = _o78 * _h3
	_q28.custom_minimum_size.y = height
	position = _g51
	show()
	_z98 = true
func _o100(count: int) -> void:
	while _y22.size() < count:
		var label = Label.new()
		label.custom_minimum_size = Vector2(_l19 - _v39 * 4, _h3)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _n54)
		label.add_theme_color_override("font_color", _l10)
		var _d35 = _y22.size()
		label.set_meta("index", _d35)
		label.gui_input.connect(_c62.bind(_d35))
		label.mouse_entered.connect(_b12.bind(_d35))
		label.mouse_exited.connect(_f76.bind(_d35))
		_r70.add_child(label)
		_y22.append(label)
func _o52(_k81: String) -> void:
	if _k81.is_empty():
		_d60 = _p9.duplicate()
	else:
		_d60.clear()
		var _p21 = _k81.to_lower()
		for _o18 in _p9:
			if _o18.to_lower().contains(_p21):
				_d60.append(_o18)
	_e52 = 0
	_b47()
func _q57() -> void:
	if _d60.is_empty():
		return
	_e52 -= 1
	if _e52 < 0:
		_e52 = _d60.size() - 1
	_b47()
	_e24()
func _r30() -> void:
	if _d60.is_empty():
		return
	_e52 += 1
	if _e52 >= _d60.size():
		_e52 = 0
	_b47()
	_e24()
func _w92() -> void:
	if _d60.is_empty():
		_p10()
		return
	if _e52 >= 0 and _e52 < _d60.size():
		var _n28 = _d60[_e52]
		hide()
		_z98 = false
		item_selected.emit(_n28)
func _p10() -> void:
	hide()
	_z98 = false
	_b57 = -1
	_d60.clear()
	_x52.emit()
func _s71() -> bool:
	return _z98
func get_item_count() -> int:
	return _d60.size()
func _b47() -> void:
	var _a38 = (_q1 == _x20)
	for i in range(_y22.size()):
		var label = _y22[i]
		if i < _d60.size():
			label.text = _d60[i]
			label.visible = true
			if i == _e52:
				label.add_theme_stylebox_override("normal", _b78)
			elif i == _b57:
				label.add_theme_stylebox_override("normal", _p89)
			else:
				label.remove_theme_stylebox_override("normal")
		else:
			label.visible = false
	var _n10: int
	if _a38:
		_n10 = _d60.size()
	else:
		_n10 = mini(_d60.size(), _x36)
	var _o78 = maxi(_n10, _q1)
	_d57.custom_minimum_size.y = _o78 * _h3
func _e24() -> void:
	if _e52 < 0 or _d60.is_empty():
		return
	var _j41 = _d57.scroll_vertical
	var _o21 = _e52 * _h3
	var _z13 = _o21 + _h3
	var _b27 = _d57.custom_minimum_size.y
	if _o21 < _j41:
		_d57.scroll_vertical = _o21
	elif _z13 > _j41 + _b27:
		_d57.scroll_vertical = _z13 - _b27
func _c62(_v53: InputEvent, index: int) -> void:
	if _v53 is InputEventMouseButton:
		var _l20 = _v53 as InputEventMouseButton
		if _l20.button_index == MOUSE_BUTTON_LEFT and _l20.pressed:
			if index < _d60.size():
				_e52 = index
				_w92()
func _b12(index: int) -> void:
	if index < _d60.size():
		_b57 = index
		_b47()
func _f76(index: int) -> void:
	if _b57 == index:
		_b57 = -1
		_b47()
func _h41() -> void:
	_p10()
	for label in _y22:
		if is_instance_valid(label):
			label.queue_free()
	_y22.clear()
	if is_instance_valid(_r70):
		_r70.queue_free()
	if is_instance_valid(_d57):
		_d57.queue_free()
	if is_instance_valid(_q28):
		_q28.queue_free()
