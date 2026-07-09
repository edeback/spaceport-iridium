@tool
class_name _y17
extends Control
signal item_selected(_s38: String)
signal _g21()
const _f65: int = 8
const _s75: int = 8
const _j53: int = 400
const _l30: int = 8  
const _l51: int = 5  
var _m89: int = 8
var _q14: int = 32
var _x57: int = 8
var _u41: int = 400
var _u29: int = 16
var _t35: float = 1.0
var _z90: Color = Color(0.15, 0.15, 0.15, 0.95)
var _t65: Color = Color(0.25, 0.4, 0.6, 1.0)
var _q8: Color = Color(0.2, 0.3, 0.4, 0.5)
var _t41: Color = Color(0.9, 0.9, 0.9, 1.0)
var _u7: Color = Color(0.6, 0.6, 0.6, 1.0)
var _m34: Array[String] = []
var _u46: Array[String] = []
var _b98: int = 0
var _f6: int = -1
var _f69: bool = false
var _c28: int = _l30  
var _e93: PanelContainer
var _z61: ScrollContainer
var _w74: VBoxContainer
var _e77: Array[Label] = []
var _c56: StyleBoxFlat
var _x39: StyleBoxFlat
var _f21: EditorInterface
func _init():
	set_process(false)
	set_process_input(false)
func initialize(_i13: EditorInterface) -> void:
	_f21 = _i13
	_q6()
	_o58()
	_j43()
	hide()
func _v7() -> int:
	if _f21:
		var theme = _f21.get_editor_theme()
		if theme:
			var _t34 = theme.get_font_size("main_size", "EditorFonts")
			if _t34 > 0:
				return _t34
	return 14  
func _q6() -> void:
	var _f96 = _v7()
	_t35 = float(_f96) / 14.0
	_u29 = _f96
	_q14 = int(_f96 * 2)
	_x57 = int(_s75 * _t35)
	_u41 = int(_j53 * _t35)
	_m89 = _f65  
func _o58() -> void:
	_e93 = PanelContainer.new()
	_e93.custom_minimum_size = Vector2(_u41, 0)
	add_child(_e93)
	_z61 = ScrollContainer.new()
	_z61.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_z61.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_z61.custom_minimum_size = Vector2(_u41 - _x57 * 2, 0)
	_e93.add_child(_z61)
	_w74 = VBoxContainer.new()
	_w74.add_theme_constant_override("separation", int(4 * _t35))
	_z61.add_child(_w74)
	for i in range(_m89):
		var label = Label.new()
		label.custom_minimum_size = Vector2(_u41 - _x57 * 4, _q14)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _u29)
		label.set_meta("index", i)
		label.gui_input.connect(_f37.bind(i))
		label.mouse_entered.connect(_y68.bind(i))
		label.mouse_exited.connect(_t28.bind(i))
		_w74.add_child(label)
		_e77.append(label)
	var _u49 = StyleBoxFlat.new()
	_u49.bg_color = _z90
	_u49.set_corner_radius_all(int(6 * _t35))
	_u49.set_border_width_all(1)
	_u49.border_color = Color(0.3, 0.3, 0.3, 1.0)
	_u49.set_content_margin_all(_x57)
	_e93.add_theme_stylebox_override("panel", _u49)
func _j43() -> void:
	if _f21 == null:
		return
	var theme = _f21.get_editor_theme()
	if theme == null:
		return
	_z90 = theme.get_color("base_color", "Editor")
	_z90.a = 0.98
	_t65 = theme.get_color("accent_color", "Editor")
	_t65.a = 0.3
	_q8 = theme.get_color("accent_color", "Editor")
	_q8.a = 0.15
	_t41 = theme.get_color("font_color", "Editor")
	_u7 = theme.get_color("font_disabled_color", "Editor")
	_c56 = StyleBoxFlat.new()
	_c56.bg_color = _t65
	_c56.set_corner_radius_all(2)
	_x39 = StyleBoxFlat.new()
	_x39.bg_color = _q8
	_x39.set_corner_radius_all(2)
	if _e93:
		var _u49 = _e93.get_theme_stylebox("panel") as StyleBoxFlat
		if _u49:
			_u49.bg_color = _z90
			_u49.border_color = theme.get_color("dark_color_2", "Editor")
	for label in _e77:
		label.add_theme_color_override("font_color", _t41)
func _e94(_k28: Vector2, _x61: Array[String], _w31: int = _l30) -> void:
	_c28 = _w31
	if _x61.is_empty():
		hide()
		_f69 = false
		return
	_m34 = _x61.duplicate()
	_u46 = _m34.duplicate()
	_b98 = 0
	_f6 = -1
	var _d90 = (_w31 == _l51)
	if _d90:
		_z61.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_i9(_u46.size())
	else:
		_z61.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_x47()
	var _n13: int
	if _d90:
		_n13 = _u46.size()  
	else:
		_n13 = mini(_u46.size(), _m89)
	var _r26 = maxi(_n13, _c28)
	var height = _r26 * _q14 + _x57 * 2
	_z61.custom_minimum_size.y = _r26 * _q14
	_e93.custom_minimum_size.y = height
	position = _k28
	show()
	_f69 = true
func _i9(count: int) -> void:
	while _e77.size() < count:
		var label = Label.new()
		label.custom_minimum_size = Vector2(_u41 - _x57 * 4, _q14)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _u29)
		label.add_theme_color_override("font_color", _t41)
		var _z30 = _e77.size()
		label.set_meta("index", _z30)
		label.gui_input.connect(_f37.bind(_z30))
		label.mouse_entered.connect(_y68.bind(_z30))
		label.mouse_exited.connect(_t28.bind(_z30))
		_w74.add_child(label)
		_e77.append(label)
func _b56(_q57: String) -> void:
	if _q57.is_empty():
		_u46 = _m34.duplicate()
	else:
		_u46.clear()
		var _j5 = _q57.to_lower()
		for _s38 in _m34:
			if _s38.to_lower().contains(_j5):
				_u46.append(_s38)
	_b98 = 0
	_x47()
func _s31() -> void:
	if _u46.is_empty():
		return
	_b98 -= 1
	if _b98 < 0:
		_b98 = _u46.size() - 1
	_x47()
	_b37()
func _j11() -> void:
	if _u46.is_empty():
		return
	_b98 += 1
	if _b98 >= _u46.size():
		_b98 = 0
	_x47()
	_b37()
func _m67() -> void:
	if _u46.is_empty():
		_x36()
		return
	if _b98 >= 0 and _b98 < _u46.size():
		var _a88 = _u46[_b98]
		hide()
		_f69 = false
		item_selected.emit(_a88)
func _x36() -> void:
	hide()
	_f69 = false
	_f6 = -1
	_u46.clear()
	_g21.emit()
func _l11() -> bool:
	return _f69
func get_item_count() -> int:
	return _u46.size()
func _x47() -> void:
	var _d90 = (_c28 == _l51)
	for i in range(_e77.size()):
		var label = _e77[i]
		if i < _u46.size():
			label.text = _u46[i]
			label.visible = true
			if i == _b98:
				label.add_theme_stylebox_override("normal", _c56)
			elif i == _f6:
				label.add_theme_stylebox_override("normal", _x39)
			else:
				label.remove_theme_stylebox_override("normal")
		else:
			label.visible = false
	var _n13: int
	if _d90:
		_n13 = _u46.size()
	else:
		_n13 = mini(_u46.size(), _m89)
	var _r26 = maxi(_n13, _c28)
	_z61.custom_minimum_size.y = _r26 * _q14
func _b37() -> void:
	if _b98 < 0 or _u46.is_empty():
		return
	var _z58 = _z61.scroll_vertical
	var _z14 = _b98 * _q14
	var _g81 = _z14 + _q14
	var _m91 = _z61.custom_minimum_size.y
	if _z14 < _z58:
		_z61.scroll_vertical = _z14
	elif _g81 > _z58 + _m91:
		_z61.scroll_vertical = _g81 - _m91
func _f37(_x75: InputEvent, index: int) -> void:
	if _x75 is InputEventMouseButton:
		var _p52 = _x75 as InputEventMouseButton
		if _p52.button_index == MOUSE_BUTTON_LEFT and _p52.pressed:
			if index < _u46.size():
				_b98 = index
				_m67()
func _y68(index: int) -> void:
	if index < _u46.size():
		_f6 = index
		_x47()
func _t28(index: int) -> void:
	if _f6 == index:
		_f6 = -1
		_x47()
func _o36() -> void:
	_x36()
	for label in _e77:
		if is_instance_valid(label):
			label.queue_free()
	_e77.clear()
	if is_instance_valid(_w74):
		_w74.queue_free()
	if is_instance_valid(_z61):
		_z61.queue_free()
	if is_instance_valid(_e93):
		_e93.queue_free()
