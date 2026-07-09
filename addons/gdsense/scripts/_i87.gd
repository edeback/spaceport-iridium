@tool
extends Control
class_name _b87

var _y2: String = ""
var _c63: CodeEdit
var _c42: Font
var _o20: int = 14
var _s75: float = 0.5
var _j77: Tween
var _n76: bool = false

func _init(_g95: CodeEdit):
	_c63 = _g95
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	if _c63:
		_c42 = _c63.get_theme_font("font")
		_o20 = _c63.get_theme_font_size("font_size")
		
		_c63.add_child(self)
		
		if not _c63.draw.is_connected(_p62):
			_c63.draw.connect(_p62)

func _i60(text: String):
	_y2 = text
	_n76 = true
	
	if _j77:
		_j77.kill()
	
	modulate.a = 0.0
	_j77 = create_tween()
	_j77.tween_property(self, "modulate:a", _s75, 0.2)  
	
	queue_redraw()
	if _c63:
		_c63.queue_redraw()

func _a53():
	_y2 = ""
	_n76 = false
	
	if _j77:
		_j77.kill()
	
	modulate.a = 0.0
	queue_redraw()
	if _c63:
		_c63.queue_redraw()

func _p62():
	if not _n76 or _y2.is_empty():
		return
	
	var _i77 = _c63.get_caret_line()
	var caret_column = _c63.get_caret_column()
	
	var _e18 = _c63.get_line_height()
	var _i18 = _c63.get_caret_draw_pos()
	
	var _q48 = _i18
	
	var _m44 = _c63.get_theme_color("font_color")
	_m44.a = modulate.a  
	
	if _c42:
		_c63.draw_string(_c42, _q48, _y2, HORIZONTAL_ALIGNMENT_LEFT, -1, _o20, _m44)

func _draw():
	pass

func _t35() -> bool:
	return _n76

func _p53() -> String:
	return _y2

func _k63():
	_a53()
	if _j77:
		_j77.kill()

	if _c63 and _c63.draw.is_connected(_p62):
		_c63.draw.disconnect(_p62)
	if get_parent():
		queue_free()

