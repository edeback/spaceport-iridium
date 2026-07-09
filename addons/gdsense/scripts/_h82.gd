@tool
extends Control
class_name _q59
var _j84: String = ""
var _e83: CodeEdit
var _y66: Font
var _p10: int = 14
var _s51: float = 0.5
var _t78: Tween
var _f69: bool = false
func _init(_v93: CodeEdit):
	_e83 = _v93
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _e83:
		_y66 = _e83.get_theme_font("font")
		_p10 = _e83.get_theme_font_size("font_size")
		_e83.add_child(self)
		if not _e83.draw.is_connected(_t59):
			_e83.draw.connect(_t59)
func _i74(text: String):
	_j84 = text
	_f69 = true
	if _t78:
		_t78.kill()
	modulate.a = 0.0
	_t78 = create_tween()
	_t78.tween_property(self, "modulate:a", _s51, 0.2)  
	queue_redraw()
	if _e83:
		_e83.queue_redraw()
func _w61():
	_j84 = ""
	_f69 = false
	if _t78:
		_t78.kill()
	modulate.a = 0.0
	queue_redraw()
	if _e83:
		_e83.queue_redraw()
func _t59():
	if not _f69 or _j84.is_empty():
		return
	var _p99 = _e83.get_caret_line()
	var caret_column = _e83.get_caret_column()
	var _s88 = _e83.get_line_height()
	var _c89 = _e83.get_caret_draw_pos()
	var _k98 = _c89
	var _q40 = _e83.get_theme_color("font_color")
	_q40.a = modulate.a  
	if _y66:
		_e83.draw_string(_y66, _k98, _j84, HORIZONTAL_ALIGNMENT_LEFT, -1, _p10, _q40)
func _draw():
	pass
func _l11() -> bool:
	return _f69
func _o5() -> String:
	return _j84
func _o36():
	_w61()
	if _t78:
		_t78.kill()
	if _e83 and _e83.draw.is_connected(_t59):
		_e83.draw.disconnect(_t59)
	if get_parent():
		queue_free()
