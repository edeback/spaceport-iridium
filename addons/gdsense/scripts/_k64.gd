@tool
extends RefCounted
class_name _p65
signal _l23()
var _y54: Timer
var _b6: int = 800  
var _p74: bool = false
var _e83: CodeEdit
var _h39: int = 0
var _n15: int = 3000  
var _h78: String = ""
var _a7: int = -1
func _init(_v93: CodeEdit):
	_e83 = _v93
	_y54 = Timer.new()
	_y54.wait_time = _b6 / 1000.0
	_y54.one_shot = true
	_y54.timeout.connect(_u55)
	if _e83:
		_e83.add_child(_y54)
func _a91():
	if _e83:
		if not _e83.text_changed.is_connected(_g28):
			_e83.text_changed.connect(_g28)
		if not _e83.caret_changed.is_connected(_k55):
			_e83.caret_changed.connect(_k55)
		if not _e83.gui_input.is_connected(_o32):
			_e83.gui_input.connect(_o32)
func _b5():
	if _e83:
		if _e83.text_changed.is_connected(_g28):
			_e83.text_changed.disconnect(_g28)
		if _e83.caret_changed.is_connected(_k55):
			_e83.caret_changed.disconnect(_k55)
		if _e83.gui_input.is_connected(_o32):
			_e83.gui_input.disconnect(_o32)
	_c59()
func _g28():
	_j60()
func _k55():
	_j60()
func _o32(_x75: InputEvent):
	if _x75 is InputEventKey or _x75 is InputEventMouseButton or _x75 is InputEventMouseMotion:
		_j60()
func _j60():
	_p74 = false
	_y54.stop()
	_y54.wait_time = _b6 / 1000.0
	_y54.start()
func _c59():
	_p74 = false
	_y54.stop()
func _u55():
	_p74 = true
	var _n75 = Time.get_ticks_msec()
	if _n75 - _h39 < _n15:
		return
	if _e83:
		var _d86 = _e83.text
		var _t3 = _e83.get_caret_column()
		if _d86 == _h78 and _t3 == _a7:
			return
		_h78 = _d86
		_a7 = _t3
	_h39 = _n75
	_l23.emit()
func set_delay(_c87: int):
	_b6 = _c87
	_y54.wait_time = _b6 / 1000.0
func _f90():
	_h39 = 0
func _u34(_r70: int):
	_n15 = _r70
func _o36():
	_b5()
	if _y54 and _y54.get_parent():
		_y54.queue_free()
