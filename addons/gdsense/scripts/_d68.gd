@tool
extends Control
class_name _x92

var _k65: String = ""
var _b60: CodeEdit
var _h53: Font
var _l57: int = 14
var _u11: float = 0.5
var _e25: Tween
var _d96: bool = false

func _init(_v78: CodeEdit):
	_b60 = _v78
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	if _b60:
		_h53 = _b60.get_theme_font("font")
		_l57 = _b60.get_theme_font_size("font_size")
		
		_b60.add_child(self)
		
		if not _b60.draw.is_connected(_n17):
			_b60.draw.connect(_n17)

func _l11(text: String):
	_k65 = text
	_d96 = true
	
	if _e25:
		_e25.kill()
	
	modulate.a = 0.0
	_e25 = create_tween()
	_e25.tween_property(self, "modulate:a", _u11, 0.2)  
	
	queue_redraw()
	if _b60:
		_b60.queue_redraw()

func _d91():
	_k65 = ""
	_d96 = false
	
	if _e25:
		_e25.kill()
	
	modulate.a = 0.0
	queue_redraw()
	if _b60:
		_b60.queue_redraw()

func _n17():
	if not _d96 or _k65.is_empty():
		return
	
	var _w9 = _b60.get_caret_line()
	var caret_column = _b60.get_caret_column()
	
	var _w41 = _b60.get_line_height()
	var _a76 = _b60.get_caret_draw_pos()
	
	var _w53 = _a76
	
	var _v16 = _b60.get_theme_color("font_color")
	_v16.a = modulate.a  
	
	if _h53:
		_b60.draw_string(_h53, _w53, _k65, HORIZONTAL_ALIGNMENT_LEFT, -1, _l57, _v16)

func _draw():
	pass

func _v8() -> bool:
	return _d96

func _d56() -> String:
	return _k65

func _q17():
	_d91()
	if _e25:
		_e25.kill()

	if _b60 and _b60.draw.is_connected(_n17):
		_b60.draw.disconnect(_n17)
	if get_parent():
		queue_free()

