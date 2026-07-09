@tool
class_name _d15
extends Control

signal item_selected(_c53: String)
signal _x100()

const _f60: int = 8
const _z54: int = 8
const _m61: int = 400
const _y4: int = 8  
const _u13: int = 5  

var _v47: int = 8
var _c44: int = 32
var _w95: int = 8
var _u66: int = 400
var _s34: int = 16
var _g83: float = 1.0

var _g94: Color = Color(0.15, 0.15, 0.15, 0.95)
var _x37: Color = Color(0.25, 0.4, 0.6, 1.0)
var _q14: Color = Color(0.2, 0.3, 0.4, 0.5)
var _r57: Color = Color(0.9, 0.9, 0.9, 1.0)
var _g89: Color = Color(0.6, 0.6, 0.6, 1.0)

var _g4: Array[String] = []
var _f99: Array[String] = []
var _t52: int = 0
var _r14: int = -1
var _n76: bool = false
var _w38: int = _y4  

var _q22: PanelContainer
var _f14: ScrollContainer
var _l30: VBoxContainer
var _y78: Array[Label] = []

var _i48: StyleBoxFlat
var _s62: StyleBoxFlat

var _q86: EditorInterface

func _init():
	set_process(false)
	set_process_input(false)

func initialize(_t15: EditorInterface) -> void:
	_q86 = _t15
	_p74()
	_x47()
	_n57()
	hide()

func _c77() -> int:
	if _q86:
		var theme = _q86.get_editor_theme()
		if theme:
			var _z95 = theme.get_font_size("main_size", "EditorFonts")
			if _z95 > 0:
				return _z95
	return 14  

func _p74() -> void:
	var _r90 = _c77()

	_g83 = float(_r90) / 14.0

	_s34 = _r90

	_c44 = int(_r90 * 2)

	_w95 = int(_z54 * _g83)
	_u66 = int(_m61 * _g83)
	_v47 = _f60  

func _x47() -> void:
	_q22 = PanelContainer.new()
	_q22.custom_minimum_size = Vector2(_u66, 0)
	add_child(_q22)

	_f14 = ScrollContainer.new()
	_f14.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_f14.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_f14.custom_minimum_size = Vector2(_u66 - _w95 * 2, 0)
	_q22.add_child(_f14)

	_l30 = VBoxContainer.new()
	_l30.add_theme_constant_override("separation", int(4 * _g83))
	_f14.add_child(_l30)

	for i in range(_v47):
		var label = Label.new()
		label.custom_minimum_size = Vector2(_u66 - _w95 * 4, _c44)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _s34)

		label.set_meta("index", i)
		label.gui_input.connect(_f23.bind(i))
		label.mouse_entered.connect(_a2.bind(i))
		label.mouse_exited.connect(_q65.bind(i))
		_l30.add_child(label)
		_y78.append(label)

	var _x67 = StyleBoxFlat.new()
	_x67.bg_color = _g94
	_x67.set_corner_radius_all(int(6 * _g83))
	_x67.set_border_width_all(1)
	_x67.border_color = Color(0.3, 0.3, 0.3, 1.0)
	_x67.set_content_margin_all(_w95)
	_q22.add_theme_stylebox_override("panel", _x67)

func _n57() -> void:
	if _q86 == null:
		return

	var theme = _q86.get_editor_theme()
	if theme == null:
		return

	_g94 = theme.get_color("base_color", "Editor")
	_g94.a = 0.98
	_x37 = theme.get_color("accent_color", "Editor")
	_x37.a = 0.3
	_q14 = theme.get_color("accent_color", "Editor")
	_q14.a = 0.15
	_r57 = theme.get_color("font_color", "Editor")
	_g89 = theme.get_color("font_disabled_color", "Editor")

	_i48 = StyleBoxFlat.new()
	_i48.bg_color = _x37
	_i48.set_corner_radius_all(2)

	_s62 = StyleBoxFlat.new()
	_s62.bg_color = _q14
	_s62.set_corner_radius_all(2)

	if _q22:
		var _x67 = _q22.get_theme_stylebox("panel") as StyleBoxFlat
		if _x67:
			_x67.bg_color = _g94
			_x67.border_color = theme.get_color("dark_color_2", "Editor")

	for label in _y78:
		label.add_theme_color_override("font_color", _r57)

func _h90(_l5: Vector2, _l64: Array[String], _o42: int = _y4) -> void:
	_w38 = _o42

	if _l64.is_empty():
		hide()
		_n76 = false
		return

	_g4 = _l64.duplicate()
	_f99 = _g4.duplicate()
	_t52 = 0
	_r14 = -1

	var _z85 = (_o42 == _u13)

	if _z85:
		_f14.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

		_l97(_f99.size())
	else:
		_f14.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	_i4()

	var _f62: int
	if _z85:
		_f62 = _f99.size()  
	else:
		_f62 = mini(_f99.size(), _v47)

	var _x97 = maxi(_f62, _w38)
	var height = _x97 * _c44 + _w95 * 2
	_f14.custom_minimum_size.y = _x97 * _c44
	_q22.custom_minimum_size.y = height

	position = _l5

	show()
	_n76 = true

func _l97(count: int) -> void:
	while _y78.size() < count:
		var label = Label.new()
		label.custom_minimum_size = Vector2(_u66 - _w95 * 4, _c44)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_font_size_override("font_size", _s34)
		label.add_theme_color_override("font_color", _r57)
		var _x40 = _y78.size()
		label.set_meta("index", _x40)
		label.gui_input.connect(_f23.bind(_x40))
		label.mouse_entered.connect(_a2.bind(_x40))
		label.mouse_exited.connect(_q65.bind(_x40))
		_l30.add_child(label)
		_y78.append(label)

func _y63(_e33: String) -> void:
	if _e33.is_empty():
		_f99 = _g4.duplicate()
	else:
		_f99.clear()
		var _m97 = _e33.to_lower()
		for _c53 in _g4:
			if _c53.to_lower().contains(_m97):
				_f99.append(_c53)

	_t52 = 0

	_i4()

func _c49() -> void:
	if _f99.is_empty():
		return

	_t52 -= 1
	if _t52 < 0:
		_t52 = _f99.size() - 1

	_i4()
	_h43()

func _a43() -> void:
	if _f99.is_empty():
		return

	_t52 += 1
	if _t52 >= _f99.size():
		_t52 = 0

	_i4()
	_h43()

func _m92() -> void:
	if _f99.is_empty():
		_n73()
		return

	if _t52 >= 0 and _t52 < _f99.size():
		var _k34 = _f99[_t52]

		hide()
		_n76 = false
		item_selected.emit(_k34)

func _n73() -> void:
	hide()
	_n76 = false
	_r14 = -1
	_f99.clear()
	_x100.emit()

func _t35() -> bool:
	return _n76

func get_item_count() -> int:
	return _f99.size()

func _i4() -> void:
	var _z85 = (_w38 == _u13)

	for i in range(_y78.size()):
		var label = _y78[i]

		if i < _f99.size():
			label.text = _f99[i]
			label.visible = true

			if i == _t52:
				label.add_theme_stylebox_override("normal", _i48)
			elif i == _r14:
				label.add_theme_stylebox_override("normal", _s62)
			else:
				label.remove_theme_stylebox_override("normal")
		else:
			label.visible = false

	var _f62: int
	if _z85:
		_f62 = _f99.size()
	else:
		_f62 = mini(_f99.size(), _v47)

	var _x97 = maxi(_f62, _w38)
	_f14.custom_minimum_size.y = _x97 * _c44

func _h43() -> void:
	if _t52 < 0 or _f99.is_empty():
		return

	var _a76 = _f14.scroll_vertical
	var _a63 = _t52 * _c44
	var _b91 = _a63 + _c44
	var _q15 = _f14.custom_minimum_size.y

	if _a63 < _a76:
		_f14.scroll_vertical = _a63
	elif _b91 > _a76 + _q15:
		_f14.scroll_vertical = _b91 - _q15

func _f23(_n74: InputEvent, index: int) -> void:
	if _n74 is InputEventMouseButton:
		var _o76 = _n74 as InputEventMouseButton
		if _o76.button_index == MOUSE_BUTTON_LEFT and _o76.pressed:
			if index < _f99.size():
				_t52 = index
				_m92()

func _a2(index: int) -> void:
	if index < _f99.size():
		_r14 = index
		_i4()

func _q65(index: int) -> void:
	if _r14 == index:
		_r14 = -1
		_i4()

func _k63() -> void:
	_n73()
	for label in _y78:
		if is_instance_valid(label):
			label.queue_free()
	_y78.clear()

	if is_instance_valid(_l30):
		_l30.queue_free()
	if is_instance_valid(_f14):
		_f14.queue_free()
	if is_instance_valid(_q22):
		_q22.queue_free()

