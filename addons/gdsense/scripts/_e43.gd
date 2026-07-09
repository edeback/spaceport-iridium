@tool
extends Control
class_name _i5
var _m27: String = ""
var _e79: CodeEdit
var _m97: Font
var _o99: int = 14
var _e44: float = 0.5
var _u65: Tween
var _z98: bool = false
func _init(_t5: CodeEdit):
	_e79 = _t5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _e79:
		_m97 = _e79.get_theme_font("font")
		_o99 = _e79.get_theme_font_size("font_size")
		_e79.add_child(self)
		if not _e79.draw.is_connected(_h27):
			_e79.draw.connect(_h27)
func _h85(text: String):
	_m27 = text
	_z98 = true
	if _u65:
		_u65.kill()
	modulate.a = 0.0
	_u65 = create_tween()
	_u65.tween_property(self, "modulate:a", _e44, 0.2)  
	queue_redraw()
	if _e79:
		_e79.queue_redraw()
func _o2():
	_m27 = ""
	_z98 = false
	if _u65:
		_u65.kill()
	modulate.a = 0.0
	queue_redraw()
	if _e79:
		_e79.queue_redraw()
func _h27():
	if not _z98 or _m27.is_empty():
		return
	var _e26 = _e79.get_caret_line()
	var caret_column = _e79.get_caret_column()
	var _g71 = _e79.get_line_height()
	var _x46 = _e79.get_caret_draw_pos()
	var _v90 = _x46
	var _m44 = _e79.get_theme_color("font_color")
	_m44.a = modulate.a  
	if _m97:
		_e79.draw_string(_m97, _v90, _m27, HORIZONTAL_ALIGNMENT_LEFT, -1, _o99, _m44)
func _draw():
	pass
func _s71() -> bool:
	return _z98
func _g41() -> String:
	return _m27
func _h41():
	_o2()
	if _u65:
		_u65.kill()
	if _e79 and _e79.draw.is_connected(_h27):
		_e79.draw.disconnect(_h27)
	if get_parent():
		queue_free()
