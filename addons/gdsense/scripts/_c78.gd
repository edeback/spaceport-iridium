@tool
extends Control
class_name _i44
var _g31: String = ""
var _w10: CodeEdit
var _l22: Font
var _e18: int = 14
var _y46: float = 0.5
var _h36: Tween
var _k53: bool = false
func _init(_j81: CodeEdit):
	_w10 = _j81
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _w10:
		_l22 = _w10.get_theme_font("font")
		_e18 = _w10.get_theme_font_size("font_size")
		_w10.add_child(self)
		if not _w10.draw.is_connected(_d86):
			_w10.draw.connect(_d86)
func _v43(text: String):
	_g31 = text
	_k53 = true
	if _h36:
		_h36.kill()
	modulate.a = 0.0
	_h36 = create_tween()
	_h36.tween_property(self, "modulate:a", _y46, 0.2)  
	queue_redraw()
	if _w10:
		_w10.queue_redraw()
func _f31():
	_g31 = ""
	_k53 = false
	if _h36:
		_h36.kill()
	modulate.a = 0.0
	queue_redraw()
	if _w10:
		_w10.queue_redraw()
func _d86():
	if not _k53 or _g31.is_empty():
		return
	var _t41 = _w10.get_caret_line()
	var caret_column = _w10.get_caret_column()
	var _h72 = _w10.get_line_height()
	var _v69 = _w10.get_caret_draw_pos()
	var _v88 = _v69
	var _o93 = _w10.get_theme_color("font_color")
	_o93.a = modulate.a  
	if _l22:
		_w10.draw_string(_l22, _v88, _g31, HORIZONTAL_ALIGNMENT_LEFT, -1, _e18, _o93)
func _draw():
	pass
func _e25() -> bool:
	return _k53
func _z69() -> String:
	return _g31
func _u75():
	_f31()
	if _h36:
		_h36.kill()
	if _w10 and _w10.draw.is_connected(_d86):
		_w10.draw.disconnect(_d86)
	if get_parent():
		queue_free()
