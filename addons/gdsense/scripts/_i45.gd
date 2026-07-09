@tool
extends RefCounted
class_name _c51

signal _a32()

var _n42: Timer
var _p78: int = 800  
var _s7: bool = false
var _c63: CodeEdit
var _f7: int = 0
var _o19: int = 3000  
var _y40: String = ""
var _h5: int = -1

func _init(_g95: CodeEdit):
	_c63 = _g95
	
	_n42 = Timer.new()
	_n42.wait_time = _p78 / 1000.0
	_n42.one_shot = true
	_n42.timeout.connect(_x62)
	
	if _c63:
		_c63.add_child(_n42)

func _e10():
	if _c63:
		if not _c63.text_changed.is_connected(_z28):
			_c63.text_changed.connect(_z28)
		if not _c63.caret_changed.is_connected(_c62):
			_c63.caret_changed.connect(_c62)
		if not _c63.gui_input.is_connected(_o52):
			_c63.gui_input.connect(_o52)

func _t89():
	if _c63:
		if _c63.text_changed.is_connected(_z28):
			_c63.text_changed.disconnect(_z28)
		if _c63.caret_changed.is_connected(_c62):
			_c63.caret_changed.disconnect(_c62)
		if _c63.gui_input.is_connected(_o52):
			_c63.gui_input.disconnect(_o52)
	_x61()

func _z28():
	_r15()

func _c62():
	_r15()

func _o52(_n74: InputEvent):
	if _n74 is InputEventKey or _n74 is InputEventMouseButton or _n74 is InputEventMouseMotion:
		_r15()

func _r15():
	_s7 = false
	_n42.stop()
	_n42.wait_time = _p78 / 1000.0
	_n42.start()

func _x61():
	_s7 = false
	_n42.stop()

func _x62():
	_s7 = true
	
	var _t19 = Time.get_ticks_msec()
	if _t19 - _f7 < _o19:
		return
	
	if _c63:
		var _n98 = _c63.text
		var _v49 = _c63.get_caret_column()
		
		if _n98 == _y40 and _v49 == _h5:
			return
		
		_y40 = _n98
		_h5 = _v49
	
	_f7 = _t19
	_a32.emit()

func set_delay(_v19: int):
	_p78 = _v19
	_n42.wait_time = _p78 / 1000.0

func _b1():
	_f7 = 0

func _b26(_k29: int):
	_o19 = _k29

func _k63():
	_t89()
	if _n42 and _n42.get_parent():
		_n42.queue_free()

