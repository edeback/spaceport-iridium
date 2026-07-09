@tool
class_name _p76
extends Control

signal item_selected(_y98: String)
signal _w51()

const _l25: int = 8
const _z13: int = 8
const _n62: int = 400
const _e52: int = 8  
const _t43: int = 5  

var _t38: int = 8
var _z84: int = 32
var _j83: int = 8
var _i13: int = 400
var _x76: int = 16
var _v98: float = 1.0

var _z55: Color = Color(0.15, 0.15, 0.15, 0.95)
var _r14: Color = Color(0.25, 0.4, 0.6, 1.0)
var _s39: Color = Color(0.2, 0.3, 0.4, 0.5)
var _g83: Color = Color(0.9, 0.9, 0.9, 1.0)
var _j61: Color = Color(0.6, 0.6, 0.6, 1.0)

var _k10: Array[String] = []
var _w54: Array[String] = []
var _l39: int = 0
var _d36: int = -1
var _d96: bool = false
var _v49: int = _e52  

var _w66: PanelContainer
var _q36: ScrollContainer
var _h40: VBoxContainer
var _i96: Array[Label] = []

var _e80: StyleBoxFlat
var _z32: StyleBoxFlat

var _b58: EditorInterface

func _init():
	set_process(false)
	set_process_input(false)

func initialize(_f28: EditorInterface) -> void:
	_b58 = _f28
	_j37()
	_z18()
	_m73()
	hide()

func _x7() -> int:
	if _b58:
		var theme = _b58.get_editor_theme()
		if theme:
			var _v97 = theme.get_font_size("main_size", "EditorFonts")
			if _v97 > 0:
				return _v97
	return 14  

func _j37() -> void:
	var _p67 = _x7()

	_v98 = float(_p67) / 14.0

	_x76 = _p67

	_z84 = int(_p67 * 2)

	_j83 = int(_z13 * _v98)
	_i13 = int(_n62 * _v98)
	_t38 = _l25  

func _z18() -> void:
	_w66 = PanelContainer.new()
	_w66.custom_minimum_size = Vector2(_i13, 0)
	add_child(_w66)

	_q36 = ScrollContainer.new()
	_q36.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_q36.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_q36.custom_minimum_size = Vector2(_i13 - _j83 * 2, 0)
	_w66.add_child(_q36)

	_h40 = VBoxContainer.new()
	_h40.add_theme_constant_override("separation", int(4 * _v98))
	_q36.add_child(_h40)

	for i in range(_t38):
		var label = Label.new()
		label.custom_minimum_size = Vector2(_i13 - _j83 * 4, _z84)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _x76)

		label.set_meta("index", i)
		label.gui_input.connect(_w74.bind(i))
		label.mouse_entered.connect(_p79.bind(i))
		label.mouse_exited.connect(_z100.bind(i))
		_h40.add_child(label)
		_i96.append(label)

	var _r89 = StyleBoxFlat.new()
	_r89.bg_color = _z55
	_r89.set_corner_radius_all(int(6 * _v98))
	_r89.set_border_width_all(1)
	_r89.border_color = Color(0.3, 0.3, 0.3, 1.0)
	_r89.set_content_margin_all(_j83)
	_w66.add_theme_stylebox_override("panel", _r89)

func _m73() -> void:
	if _b58 == null:
		return

	var theme = _b58.get_editor_theme()
	if theme == null:
		return

	_z55 = theme.get_color("base_color", "Editor")
	_z55.a = 0.98
	_r14 = theme.get_color("accent_color", "Editor")
	_r14.a = 0.3
	_s39 = theme.get_color("accent_color", "Editor")
	_s39.a = 0.15
	_g83 = theme.get_color("font_color", "Editor")
	_j61 = theme.get_color("font_disabled_color", "Editor")

	_e80 = StyleBoxFlat.new()
	_e80.bg_color = _r14
	_e80.set_corner_radius_all(2)

	_z32 = StyleBoxFlat.new()
	_z32.bg_color = _s39
	_z32.set_corner_radius_all(2)

	if _w66:
		var _r89 = _w66.get_theme_stylebox("panel") as StyleBoxFlat
		if _r89:
			_r89.bg_color = _z55
			_r89.border_color = theme.get_color("dark_color_2", "Editor")

	for label in _i96:
		label.add_theme_color_override("font_color", _g83)

func _q40(_e93: Vector2, _t99: Array[String], _a72: int = _e52) -> void:
	_v49 = _a72

	if _t99.is_empty():
		hide()
		_d96 = false
		return

	_k10 = _t99.duplicate()
	_w54 = _k10.duplicate()
	_l39 = 0
	_d36 = -1

	var _i64 = (_a72 == _t43)

	if _i64:
		_q36.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

		_i98(_w54.size())
	else:
		_q36.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	_n29()

	var _u22: int
	if _i64:
		_u22 = _w54.size()  
	else:
		_u22 = mini(_w54.size(), _t38)

	var _h85 = maxi(_u22, _v49)
	var height = _h85 * _z84 + _j83 * 2
	_q36.custom_minimum_size.y = _h85 * _z84
	_w66.custom_minimum_size.y = height

	position = _e93

	show()
	_d96 = true

func _i98(count: int) -> void:
	while _i96.size() < count:
		var label = Label.new()
		label.custom_minimum_size = Vector2(_i13 - _j83 * 4, _z84)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _x76)
		label.add_theme_color_override("font_color", _g83)
		var _m17 = _i96.size()
		label.set_meta("index", _m17)
		label.gui_input.connect(_w74.bind(_m17))
		label.mouse_entered.connect(_p79.bind(_m17))
		label.mouse_exited.connect(_z100.bind(_m17))
		_h40.add_child(label)
		_i96.append(label)

func _e92(_q68: String) -> void:
	if _q68.is_empty():
		_w54 = _k10.duplicate()
	else:
		_w54.clear()
		var _h60 = _q68.to_lower()
		for _y98 in _k10:
			if _y98.to_lower().contains(_h60):
				_w54.append(_y98)

	_l39 = 0

	_n29()

func _s9() -> void:
	if _w54.is_empty():
		return

	_l39 -= 1
	if _l39 < 0:
		_l39 = _w54.size() - 1

	_n29()
	_r100()

func _c28() -> void:
	if _w54.is_empty():
		return

	_l39 += 1
	if _l39 >= _w54.size():
		_l39 = 0

	_n29()
	_r100()

func _z99() -> void:
	if _w54.is_empty():
		_m34()
		return

	if _l39 >= 0 and _l39 < _w54.size():
		var _r66 = _w54[_l39]

		hide()
		_d96 = false
		item_selected.emit(_r66)

func _m34() -> void:
	hide()
	_d96 = false
	_d36 = -1
	_w54.clear()
	_w51.emit()

func _v8() -> bool:
	return _d96

func get_item_count() -> int:
	return _w54.size()

func _n29() -> void:
	var _i64 = (_v49 == _t43)

	for i in range(_i96.size()):
		var label = _i96[i]

		if i < _w54.size():
			label.text = _w54[i]
			label.visible = true

			if i == _l39:
				label.add_theme_stylebox_override("normal", _e80)
			elif i == _d36:
				label.add_theme_stylebox_override("normal", _z32)
			else:
				label.remove_theme_stylebox_override("normal")
		else:
			label.visible = false

	var _u22: int
	if _i64:
		_u22 = _w54.size()
	else:
		_u22 = mini(_w54.size(), _t38)

	var _h85 = maxi(_u22, _v49)
	_q36.custom_minimum_size.y = _h85 * _z84

func _r100() -> void:
	if _l39 < 0 or _w54.is_empty():
		return

	var _a59 = _q36.scroll_vertical
	var _w27 = _l39 * _z84
	var _s44 = _w27 + _z84
	var _u2 = _q36.custom_minimum_size.y

	if _w27 < _a59:
		_q36.scroll_vertical = _w27
	elif _s44 > _a59 + _u2:
		_q36.scroll_vertical = _s44 - _u2

func _w74(_x1: InputEvent, index: int) -> void:
	if _x1 is InputEventMouseButton:
		var _s81 = _x1 as InputEventMouseButton
		if _s81.button_index == MOUSE_BUTTON_LEFT and _s81.pressed:
			if index < _w54.size():
				_l39 = index
				_z99()

func _p79(index: int) -> void:
	if index < _w54.size():
		_d36 = index
		_n29()

func _z100(index: int) -> void:
	if _d36 == index:
		_d36 = -1
		_n29()

func _q17() -> void:
	_m34()
	for label in _i96:
		if is_instance_valid(label):
			label.queue_free()
	_i96.clear()

	if is_instance_valid(_h40):
		_h40.queue_free()
	if is_instance_valid(_q36):
		_q36.queue_free()
	if is_instance_valid(_w66):
		_w66.queue_free()

