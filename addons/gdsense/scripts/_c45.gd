@tool
extends RefCounted
class_name _m22
signal _p23()
var _b60: Timer
var _u62: int = 800  
var _l36: bool = false
var _e79: CodeEdit
var _v43: int = 0
var _m24: int = 3000  
var _z54: String = ""
var _m90: int = -1
func _init(_t5: CodeEdit):
	_e79 = _t5
	_b60 = Timer.new()
	_b60.wait_time = _u62 / 1000.0
	_b60.one_shot = true
	_b60.timeout.connect(_k2)
	if _e79:
		_e79.add_child(_b60)
func _k87():
	if _e79:
		if not _e79.text_changed.is_connected(_w3):
			_e79.text_changed.connect(_w3)
		if not _e79.caret_changed.is_connected(_x61):
			_e79.caret_changed.connect(_x61)
		if not _e79.gui_input.is_connected(_j48):
			_e79.gui_input.connect(_j48)
func _q68():
	if _e79:
		if _e79.text_changed.is_connected(_w3):
			_e79.text_changed.disconnect(_w3)
		if _e79.caret_changed.is_connected(_x61):
			_e79.caret_changed.disconnect(_x61)
		if _e79.gui_input.is_connected(_j48):
			_e79.gui_input.disconnect(_j48)
	_q39()
func _w3():
	_w45()
func _x61():
	_w45()
func _j48(_v53: InputEvent):
	if _v53 is InputEventKey or _v53 is InputEventMouseButton or _v53 is InputEventMouseMotion:
		_w45()
func _w45():
	_l36 = false
	_b60.stop()
	_b60.wait_time = _u62 / 1000.0
	_b60.start()
func _q39():
	_l36 = false
	_b60.stop()
func _k2():
	_l36 = true
	var _j33 = Time.get_ticks_msec()
	if _j33 - _v43 < _m24:
		return
	if _e79:
		var _r34 = _e79.text
		var _i62 = _e79.get_caret_column()
		if _r34 == _z54 and _i62 == _m90:
			return
		_z54 = _r34
		_m90 = _i62
	_v43 = _j33
	_p23.emit()
func set_delay(_j86: int):
	_u62 = _j86
	_b60.wait_time = _u62 / 1000.0
func _i74():
	_v43 = 0
func _p3(_t19: int):
	_m24 = _t19
func _h41():
	_q68()
	if _b60 and _b60.get_parent():
		_b60.queue_free()
