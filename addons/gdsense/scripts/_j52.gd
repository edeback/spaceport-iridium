@tool
class_name _c54
extends Control

signal item_selected(_o32: String)
signal _h83()

const _a39: int = 8
const _q26: int = 8
const _s96: int = 400
const _z37: int = 8  
const _f58: int = 5  

var _o81: int = 8
var _p51: int = 32
var _t43: int = 8
var _g76: int = 400
var _w49: int = 16
var _a31: float = 1.0

var _o34: Color = Color(0.15, 0.15, 0.15, 0.95)
var _q13: Color = Color(0.25, 0.4, 0.6, 1.0)
var _y18: Color = Color(0.2, 0.3, 0.4, 0.5)
var _p49: Color = Color(0.9, 0.9, 0.9, 1.0)
var _t33: Color = Color(0.6, 0.6, 0.6, 1.0)

var _c72: Array[String] = []
var _j100: Array[String] = []
var _a4: int = 0
var _y48: int = -1
var _e74: bool = false
var _v82: int = _z37  

var _k46: PanelContainer
var _g73: ScrollContainer
var _z30: VBoxContainer
var _o91: Array[Label] = []

var _k6: StyleBoxFlat
var _y57: StyleBoxFlat

var _z76: EditorInterface

func _init():
	set_process(false)
	set_process_input(false)

func initialize(_i86: EditorInterface) -> void:
	_z76 = _i86
	_x92()
	_s44()
	_r100()
	hide()

func _b74() -> int:
	if _z76:
		var theme = _z76.get_editor_theme()
		if theme:
			var _n62 = theme.get_font_size("main_size", "EditorFonts")
			if _n62 > 0:
				return _n62
	return 14  

func _x92() -> void:
	var _l9 = _b74()

	_a31 = float(_l9) / 14.0

	_w49 = _l9

	_p51 = int(_l9 * 2)

	_t43 = int(_q26 * _a31)
	_g76 = int(_s96 * _a31)
	_o81 = _a39  

func _s44() -> void:
	_k46 = PanelContainer.new()
	_k46.custom_minimum_size = Vector2(_g76, 0)
	add_child(_k46)

	_g73 = ScrollContainer.new()
	_g73.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_g73.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_g73.custom_minimum_size = Vector2(_g76 - _t43 * 2, 0)
	_k46.add_child(_g73)

	_z30 = VBoxContainer.new()
	_z30.add_theme_constant_override("separation", int(4 * _a31))
	_g73.add_child(_z30)

	for i in range(_o81):
		var label = Label.new()
		label.custom_minimum_size = Vector2(_g76 - _t43 * 4, _p51)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _w49)

		label.set_meta("index", i)
		label.gui_input.connect(_n57.bind(i))
		label.mouse_entered.connect(_e52.bind(i))
		label.mouse_exited.connect(_h81.bind(i))
		_z30.add_child(label)
		_o91.append(label)

	var _r20 = StyleBoxFlat.new()
	_r20.bg_color = _o34
	_r20.set_corner_radius_all(int(6 * _a31))
	_r20.set_border_width_all(1)
	_r20.border_color = Color(0.3, 0.3, 0.3, 1.0)
	_r20.set_content_margin_all(_t43)
	_k46.add_theme_stylebox_override("panel", _r20)

func _r100() -> void:
	if _z76 == null:
		return

	var theme = _z76.get_editor_theme()
	if theme == null:
		return

	_o34 = theme.get_color("base_color", "Editor")
	_o34.a = 0.98
	_q13 = theme.get_color("accent_color", "Editor")
	_q13.a = 0.3
	_y18 = theme.get_color("accent_color", "Editor")
	_y18.a = 0.15
	_p49 = theme.get_color("font_color", "Editor")
	_t33 = theme.get_color("font_disabled_color", "Editor")

	_k6 = StyleBoxFlat.new()
	_k6.bg_color = _q13
	_k6.set_corner_radius_all(2)

	_y57 = StyleBoxFlat.new()
	_y57.bg_color = _y18
	_y57.set_corner_radius_all(2)

	if _k46:
		var _r20 = _k46.get_theme_stylebox("panel") as StyleBoxFlat
		if _r20:
			_r20.bg_color = _o34
			_r20.border_color = theme.get_color("dark_color_2", "Editor")

	for label in _o91:
		label.add_theme_color_override("font_color", _p49)

func _i82(_x2: Vector2, _y34: Array[String], _x42: int = _z37) -> void:
	_v82 = _x42

	if _y34.is_empty():
		hide()
		_e74 = false
		return

	_c72 = _y34.duplicate()
	_j100 = _c72.duplicate()
	_a4 = 0
	_y48 = -1

	var _t23 = (_x42 == _f58)

	if _t23:
		_g73.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

		_h6(_j100.size())
	else:
		_g73.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	_i44()

	var _i39: int
	if _t23:
		_i39 = _j100.size()  
	else:
		_i39 = mini(_j100.size(), _o81)

	var _v39 = maxi(_i39, _v82)
	var height = _v39 * _p51 + _t43 * 2
	_g73.custom_minimum_size.y = _v39 * _p51
	_k46.custom_minimum_size.y = height

	position = _x2

	show()
	_e74 = true

func _h6(count: int) -> void:
	while _o91.size() < count:
		var label = Label.new()
		label.custom_minimum_size = Vector2(_g76 - _t43 * 4, _p51)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _w49)
		label.add_theme_color_override("font_color", _p49)
		var _t3 = _o91.size()
		label.set_meta("index", _t3)
		label.gui_input.connect(_n57.bind(_t3))
		label.mouse_entered.connect(_e52.bind(_t3))
		label.mouse_exited.connect(_h81.bind(_t3))
		_z30.add_child(label)
		_o91.append(label)

func _x7(_z58: String) -> void:
	if _z58.is_empty():
		_j100 = _c72.duplicate()
	else:
		_j100.clear()
		var _t54 = _z58.to_lower()
		for _o32 in _c72:
			if _o32.to_lower().contains(_t54):
				_j100.append(_o32)

	_a4 = 0

	_i44()

func _k22() -> void:
	if _j100.is_empty():
		return

	_a4 -= 1
	if _a4 < 0:
		_a4 = _j100.size() - 1

	_i44()
	_t39()

func _z32() -> void:
	if _j100.is_empty():
		return

	_a4 += 1
	if _a4 >= _j100.size():
		_a4 = 0

	_i44()
	_t39()

func _n92() -> void:
	if _j100.is_empty():
		_j9()
		return

	if _a4 >= 0 and _a4 < _j100.size():
		var _s62 = _j100[_a4]

		hide()
		_e74 = false
		item_selected.emit(_s62)

func _j9() -> void:
	hide()
	_e74 = false
	_y48 = -1
	_j100.clear()
	_h83.emit()

func _m66() -> bool:
	return _e74

func get_item_count() -> int:
	return _j100.size()

func _i44() -> void:
	var _t23 = (_v82 == _f58)

	for i in range(_o91.size()):
		var label = _o91[i]

		if i < _j100.size():
			label.text = _j100[i]
			label.visible = true

			if i == _a4:
				label.add_theme_stylebox_override("normal", _k6)
			elif i == _y48:
				label.add_theme_stylebox_override("normal", _y57)
			else:
				label.remove_theme_stylebox_override("normal")
		else:
			label.visible = false

	var _i39: int
	if _t23:
		_i39 = _j100.size()
	else:
		_i39 = mini(_j100.size(), _o81)

	var _v39 = maxi(_i39, _v82)
	_g73.custom_minimum_size.y = _v39 * _p51

func _t39() -> void:
	if _a4 < 0 or _j100.is_empty():
		return

	var _d50 = _g73.scroll_vertical
	var _t70 = _a4 * _p51
	var _u54 = _t70 + _p51
	var _r72 = _g73.custom_minimum_size.y

	if _t70 < _d50:
		_g73.scroll_vertical = _t70
	elif _u54 > _d50 + _r72:
		_g73.scroll_vertical = _u54 - _r72

func _n57(_p91: InputEvent, index: int) -> void:
	if _p91 is InputEventMouseButton:
		var _y63 = _p91 as InputEventMouseButton
		if _y63.button_index == MOUSE_BUTTON_LEFT and _y63.pressed:
			if index < _j100.size():
				_a4 = index
				_n92()

func _e52(index: int) -> void:
	if index < _j100.size():
		_y48 = index
		_i44()

func _h81(index: int) -> void:
	if _y48 == index:
		_y48 = -1
		_i44()

func _o76() -> void:
	_j9()
	for label in _o91:
		if is_instance_valid(label):
			label.queue_free()
	_o91.clear()

	if is_instance_valid(_z30):
		_z30.queue_free()
	if is_instance_valid(_g73):
		_g73.queue_free()
	if is_instance_valid(_k46):
		_k46.queue_free()

