@tool
class_name _g64
extends Control
signal item_selected(_d48: String)
signal _b99()
const _p50: int = 8
const _n24: int = 8
const _t87: int = 400
const _g49: int = 8  
const _w20: int = 5  
var _m19: int = 8
var _m37: int = 32
var _i63: int = 8
var _j61: int = 400
var _t93: int = 16
var _v32: float = 1.0
var _s90: Color = Color(0.15, 0.15, 0.15, 0.95)
var _g10: Color = Color(0.25, 0.4, 0.6, 1.0)
var _p79: Color = Color(0.2, 0.3, 0.4, 0.5)
var _b60: Color = Color(0.9, 0.9, 0.9, 1.0)
var _n60: Color = Color(0.6, 0.6, 0.6, 1.0)
var _l6: Array[String] = []
var _w58: Array[String] = []
var _k93: int = 0
var _j45: int = -1
var _k53: bool = false
var _g92: int = _g49  
var _e95: PanelContainer
var _w19: ScrollContainer
var _a5: VBoxContainer
var _x64: Array[Label] = []
var _w97: StyleBoxFlat
var _h76: StyleBoxFlat
var _r15: EditorInterface
func _init():
	set_process(false)
	set_process_input(false)
func initialize(_k71: EditorInterface) -> void:
	_r15 = _k71
	_k57()
	_k40()
	_l8()
	hide()
func _s98() -> int:
	if _r15:
		var theme = _r15.get_editor_theme()
		if theme:
			var _b87 = theme.get_font_size("main_size", "EditorFonts")
			if _b87 > 0:
				return _b87
	return 14  
func _k57() -> void:
	var _w21 = _s98()
	_v32 = float(_w21) / 14.0
	_t93 = _w21
	_m37 = int(_w21 * 2)
	_i63 = int(_n24 * _v32)
	_j61 = int(_t87 * _v32)
	_m19 = _p50  
func _k40() -> void:
	_e95 = PanelContainer.new()
	_e95.custom_minimum_size = Vector2(_j61, 0)
	add_child(_e95)
	_w19 = ScrollContainer.new()
	_w19.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_w19.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_w19.custom_minimum_size = Vector2(_j61 - _i63 * 2, 0)
	_e95.add_child(_w19)
	_a5 = VBoxContainer.new()
	_a5.add_theme_constant_override("separation", int(4 * _v32))
	_w19.add_child(_a5)
	for i in range(_m19):
		var label = Label.new()
		label.custom_minimum_size = Vector2(_j61 - _i63 * 4, _m37)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _t93)
		label.set_meta("index", i)
		label.gui_input.connect(_a35.bind(i))
		label.mouse_entered.connect(_n4.bind(i))
		label.mouse_exited.connect(_b70.bind(i))
		_a5.add_child(label)
		_x64.append(label)
	var _c4 = StyleBoxFlat.new()
	_c4.bg_color = _s90
	_c4.set_corner_radius_all(int(6 * _v32))
	_c4.set_border_width_all(1)
	_c4.border_color = Color(0.3, 0.3, 0.3, 1.0)
	_c4.set_content_margin_all(_i63)
	_e95.add_theme_stylebox_override("panel", _c4)
func _l8() -> void:
	if _r15 == null:
		return
	var theme = _r15.get_editor_theme()
	if theme == null:
		return
	_s90 = theme.get_color("base_color", "Editor")
	_s90.a = 0.98
	_g10 = theme.get_color("accent_color", "Editor")
	_g10.a = 0.3
	_p79 = theme.get_color("accent_color", "Editor")
	_p79.a = 0.15
	_b60 = theme.get_color("font_color", "Editor")
	_n60 = theme.get_color("font_disabled_color", "Editor")
	_w97 = StyleBoxFlat.new()
	_w97.bg_color = _g10
	_w97.set_corner_radius_all(2)
	_h76 = StyleBoxFlat.new()
	_h76.bg_color = _p79
	_h76.set_corner_radius_all(2)
	if _e95:
		var _c4 = _e95.get_theme_stylebox("panel") as StyleBoxFlat
		if _c4:
			_c4.bg_color = _s90
			_c4.border_color = theme.get_color("dark_color_2", "Editor")
	for label in _x64:
		label.add_theme_color_override("font_color", _b60)
func _g20(_u81: Vector2, _c12: Array[String], _a100: int = _g49) -> void:
	_g92 = _a100
	if _c12.is_empty():
		hide()
		_k53 = false
		return
	_l6 = _c12.duplicate()
	_w58 = _l6.duplicate()
	_k93 = 0
	_j45 = -1
	var _m28 = (_a100 == _w20)
	if _m28:
		_w19.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_g87(_w58.size())
	else:
		_w19.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_m54()
	var _n31: int
	if _m28:
		_n31 = _w58.size()  
	else:
		_n31 = mini(_w58.size(), _m19)
	var _p41 = maxi(_n31, _g92)
	var height = _p41 * _m37 + _i63 * 2
	_w19.custom_minimum_size.y = _p41 * _m37
	_e95.custom_minimum_size.y = height
	position = _u81
	show()
	_k53 = true
func _g87(count: int) -> void:
	while _x64.size() < count:
		var label = Label.new()
		label.custom_minimum_size = Vector2(_j61 - _i63 * 4, _m37)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _t93)
		label.add_theme_color_override("font_color", _b60)
		var _d41 = _x64.size()
		label.set_meta("index", _d41)
		label.gui_input.connect(_a35.bind(_d41))
		label.mouse_entered.connect(_n4.bind(_d41))
		label.mouse_exited.connect(_b70.bind(_d41))
		_a5.add_child(label)
		_x64.append(label)
func _d7(_g90: String) -> void:
	if _g90.is_empty():
		_w58 = _l6.duplicate()
	else:
		_w58.clear()
		var _s30 = _g90.to_lower()
		for _d48 in _l6:
			if _d48.to_lower().contains(_s30):
				_w58.append(_d48)
	_k93 = 0
	_m54()
func _i86() -> void:
	if _w58.is_empty():
		return
	_k93 -= 1
	if _k93 < 0:
		_k93 = _w58.size() - 1
	_m54()
	_m99()
func _w7() -> void:
	if _w58.is_empty():
		return
	_k93 += 1
	if _k93 >= _w58.size():
		_k93 = 0
	_m54()
	_m99()
func _q54() -> void:
	if _w58.is_empty():
		_z77()
		return
	if _k93 >= 0 and _k93 < _w58.size():
		var _h94 = _w58[_k93]
		hide()
		_k53 = false
		item_selected.emit(_h94)
func _z77() -> void:
	hide()
	_k53 = false
	_j45 = -1
	_w58.clear()
	_b99.emit()
func _e25() -> bool:
	return _k53
func get_item_count() -> int:
	return _w58.size()
func _m54() -> void:
	var _m28 = (_g92 == _w20)
	for i in range(_x64.size()):
		var label = _x64[i]
		if i < _w58.size():
			label.text = _w58[i]
			label.visible = true
			if i == _k93:
				label.add_theme_stylebox_override("normal", _w97)
			elif i == _j45:
				label.add_theme_stylebox_override("normal", _h76)
			else:
				label.remove_theme_stylebox_override("normal")
		else:
			label.visible = false
	var _n31: int
	if _m28:
		_n31 = _w58.size()
	else:
		_n31 = mini(_w58.size(), _m19)
	var _p41 = maxi(_n31, _g92)
	_w19.custom_minimum_size.y = _p41 * _m37
func _m99() -> void:
	if _k93 < 0 or _w58.is_empty():
		return
	var _m72 = _w19.scroll_vertical
	var _f73 = _k93 * _m37
	var _e97 = _f73 + _m37
	var _h21 = _w19.custom_minimum_size.y
	if _f73 < _m72:
		_w19.scroll_vertical = _f73
	elif _e97 > _m72 + _h21:
		_w19.scroll_vertical = _e97 - _h21
func _a35(_t27: InputEvent, index: int) -> void:
	if _t27 is InputEventMouseButton:
		var _t100 = _t27 as InputEventMouseButton
		if _t100.button_index == MOUSE_BUTTON_LEFT and _t100.pressed:
			if index < _w58.size():
				_k93 = index
				_q54()
func _n4(index: int) -> void:
	if index < _w58.size():
		_j45 = index
		_m54()
func _b70(index: int) -> void:
	if _j45 == index:
		_j45 = -1
		_m54()
func _u75() -> void:
	_z77()
	for label in _x64:
		if is_instance_valid(label):
			label.queue_free()
	_x64.clear()
	if is_instance_valid(_a5):
		_a5.queue_free()
	if is_instance_valid(_w19):
		_w19.queue_free()
	if is_instance_valid(_e95):
		_e95.queue_free()
