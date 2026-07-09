@tool
extends Control
class_name _l71
var _t73: String = ""
var _e69: CodeEdit
var _v5: Font
var _s87: int = 14
var _l30: float = 0.5
var _u90: Tween
var _p27: bool = false
func _init(_x7: CodeEdit):
	_e69 = _x7
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _e69:
		_v5 = _e69.get_theme_font("font")
		_s87 = _e69.get_theme_font_size("font_size")
		_e69.add_child(self)
		if not _e69.draw.is_connected(_z97):
			_e69.draw.connect(_z97)
func _f83(text: String):
	_t73 = text
	_p27 = true
	if _u90:
		_u90.kill()
	modulate.a = 0.0
	_u90 = create_tween()
	_u90.tween_property(self, "modulate:a", _l30, 0.2)  
	queue_redraw()
	if _e69:
		_e69.queue_redraw()
func _x36():
	_t73 = ""
	_p27 = false
	if _u90:
		_u90.kill()
	modulate.a = 0.0
	queue_redraw()
	if _e69:
		_e69.queue_redraw()
func _z97():
	if not _p27 or _t73.is_empty():
		return
	var _c88 = _e69.get_caret_line()
	var caret_column = _e69.get_caret_column()
	var _q34 = _e69.get_line_height()
	var _h88 = _e69.get_caret_draw_pos()
	var _d15 = _h88
	var _x4 = _e69.get_theme_color("font_color")
	_x4.a = modulate.a  
	if _v5:
		_e69.draw_string(_v5, _d15, _t73, HORIZONTAL_ALIGNMENT_LEFT, -1, _s87, _x4)
func _draw():
	pass
func _n30() -> bool:
	return _p27
func _e26() -> String:
	return _t73
func _q60():
	_x36()
	if _u90:
		_u90.kill()
	if _e69 and _e69.draw.is_connected(_z97):
		_e69.draw.disconnect(_z97)
	if get_parent():
		queue_free()
