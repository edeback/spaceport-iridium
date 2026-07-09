@tool
extends RefCounted
class_name _e98
signal _a99()
var _g24: Timer
var _x38: int = 800  
var _u74: bool = false
var _w10: CodeEdit
var _i17: int = 0
var _s15: int = 3000  
var _g65: String = ""
var _i94: int = -1
func _init(_j81: CodeEdit):
	_w10 = _j81
	_g24 = Timer.new()
	_g24.wait_time = _x38 / 1000.0
	_g24.one_shot = true
	_g24.timeout.connect(_e9)
	if _w10:
		_w10.add_child(_g24)
func _x97():
	if _w10:
		if not _w10.text_changed.is_connected(_b45):
			_w10.text_changed.connect(_b45)
		if not _w10.caret_changed.is_connected(_l80):
			_w10.caret_changed.connect(_l80)
		if not _w10.gui_input.is_connected(_b82):
			_w10.gui_input.connect(_b82)
func _d87():
	if _w10:
		if _w10.text_changed.is_connected(_b45):
			_w10.text_changed.disconnect(_b45)
		if _w10.caret_changed.is_connected(_l80):
			_w10.caret_changed.disconnect(_l80)
		if _w10.gui_input.is_connected(_b82):
			_w10.gui_input.disconnect(_b82)
	_k7()
func _b45():
	_g84()
func _l80():
	_g84()
func _b82(_t27: InputEvent):
	if _t27 is InputEventKey or _t27 is InputEventMouseButton or _t27 is InputEventMouseMotion:
		_g84()
func _g84():
	_u74 = false
	_g24.stop()
	_g24.wait_time = _x38 / 1000.0
	_g24.start()
func _k7():
	_u74 = false
	_g24.stop()
func _e9():
	_u74 = true
	var _s36 = Time.get_ticks_msec()
	if _s36 - _i17 < _s15:
		return
	if _w10:
		var _q92 = _w10.text
		var _u43 = _w10.get_caret_column()
		if _q92 == _g65 and _u43 == _i94:
			return
		_g65 = _q92
		_i94 = _u43
	_i17 = _s36
	_a99.emit()
func set_delay(_q15: int):
	_x38 = _q15
	_g24.wait_time = _x38 / 1000.0
func _l54():
	_i17 = 0
func _i93(_a70: int):
	_s15 = _a70
func _u75():
	_d87()
	if _g24 and _g24.get_parent():
		_g24.queue_free()
