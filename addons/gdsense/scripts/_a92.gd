@tool
extends Control
class_name _o13

var _m12: String = ""
var _w89: CodeEdit
var _d3: Font
var _o6: int = 14
var _a84: float = 0.5
var _l8: Tween
var _e74: bool = false

func _init(_o58: CodeEdit):
	_w89 = _o58
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	if _w89:
		_d3 = _w89.get_theme_font("font")
		_o6 = _w89.get_theme_font_size("font_size")
		
		_w89.add_child(self)
		
		if not _w89.draw.is_connected(_i30):
			_w89.draw.connect(_i30)

func _z36(text: String):
	_m12 = text
	_e74 = true
	
	if _l8:
		_l8.kill()
	
	modulate.a = 0.0
	_l8 = create_tween()
	_l8.tween_property(self, "modulate:a", _a84, 0.2)  
	
	queue_redraw()
	if _w89:
		_w89.queue_redraw()

func _n5():
	_m12 = ""
	_e74 = false
	
	if _l8:
		_l8.kill()
	
	modulate.a = 0.0
	queue_redraw()
	if _w89:
		_w89.queue_redraw()

func _i30():
	if not _e74 or _m12.is_empty():
		return
	
	var _n63 = _w89.get_caret_line()
	var caret_column = _w89.get_caret_column()
	
	var _i40 = _w89.get_line_height()
	var _k81 = _w89.get_caret_draw_pos()
	
	var _t84 = _k81
	
	var _u18 = _w89.get_theme_color("font_color")
	_u18.a = modulate.a  
	
	if _d3:
		_w89.draw_string(_d3, _t84, _m12, HORIZONTAL_ALIGNMENT_LEFT, -1, _o6, _u18)

func _draw():
	pass

func _m66() -> bool:
	return _e74

func _i29() -> String:
	return _m12

func _o76():
	_n5()
	if _l8:
		_l8.kill()

	if _w89 and _w89.draw.is_connected(_i30):
		_w89.draw.disconnect(_i30)
	if get_parent():
		queue_free()

