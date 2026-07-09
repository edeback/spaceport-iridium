@tool
extends RefCounted
class_name _i25
signal _d16()
var _x63: Timer
var _z1: int = 800  
var _b6: bool = false
var _e69: CodeEdit
var _q54: int = 0
var _o94: int = 3000  
var _d38: String = ""
var _e24: int = -1
func _init(_x7: CodeEdit):
	_e69 = _x7
	_x63 = Timer.new()
	_x63.wait_time = _z1 / 1000.0
	_x63.one_shot = true
	_x63.timeout.connect(_l13)
	if _e69:
		_e69.add_child(_x63)
func _d58():
	if _e69:
		if not _e69.text_changed.is_connected(_d6):
			_e69.text_changed.connect(_d6)
		if not _e69.caret_changed.is_connected(_j65):
			_e69.caret_changed.connect(_j65)
		if not _e69.gui_input.is_connected(_l18):
			_e69.gui_input.connect(_l18)
func _h83():
	if _e69:
		if _e69.text_changed.is_connected(_d6):
			_e69.text_changed.disconnect(_d6)
		if _e69.caret_changed.is_connected(_j65):
			_e69.caret_changed.disconnect(_j65)
		if _e69.gui_input.is_connected(_l18):
			_e69.gui_input.disconnect(_l18)
	_s96()
func _d6():
	_g78()
func _j65():
	_g78()
func _l18(_x58: InputEvent):
	if _x58 is InputEventKey or _x58 is InputEventMouseButton or _x58 is InputEventMouseMotion:
		_g78()
func _g78():
	_b6 = false
	_x63.stop()
	_x63.wait_time = _z1 / 1000.0
	_x63.start()
func _s96():
	_b6 = false
	_x63.stop()
func _l13():
	_b6 = true
	var _v50 = Time.get_ticks_msec()
	if _v50 - _q54 < _o94:
		return
	if _e69:
		var _r45 = _e69.text
		var _c1 = _e69.get_caret_column()
		if _r45 == _d38 and _c1 == _e24:
			return
		_d38 = _r45
		_e24 = _c1
	_q54 = _v50
	_d16.emit()
func set_delay(_c3: int):
	_z1 = _c3
	_x63.wait_time = _z1 / 1000.0
func _n71():
	_q54 = 0
func _r68(_l94: int):
	_o94 = _l94
func _q60():
	_h83()
	if _x63 and _x63.get_parent():
		_x63.queue_free()
