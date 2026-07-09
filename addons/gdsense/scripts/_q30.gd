@tool
extends RefCounted
class_name _g85

signal _l10()

var _x44: Timer
var _k39: int = 800  
var _m94: bool = false
var _w89: CodeEdit
var _e60: int = 0
var _l84: int = 3000  
var _c1: String = ""
var _d53: int = -1

func _init(_o58: CodeEdit):
	_w89 = _o58
	
	_x44 = Timer.new()
	_x44.wait_time = _k39 / 1000.0
	_x44.one_shot = true
	_x44.timeout.connect(_y14)
	
	if _w89:
		_w89.add_child(_x44)

func _g47():
	if _w89:
		if not _w89.text_changed.is_connected(_j1):
			_w89.text_changed.connect(_j1)
		if not _w89.caret_changed.is_connected(_m5):
			_w89.caret_changed.connect(_m5)
		if not _w89.gui_input.is_connected(_l52):
			_w89.gui_input.connect(_l52)

func _q32():
	if _w89:
		if _w89.text_changed.is_connected(_j1):
			_w89.text_changed.disconnect(_j1)
		if _w89.caret_changed.is_connected(_m5):
			_w89.caret_changed.disconnect(_m5)
		if _w89.gui_input.is_connected(_l52):
			_w89.gui_input.disconnect(_l52)
	_q4()

func _j1():
	_i89()

func _m5():
	_i89()

func _l52(_p91: InputEvent):
	if _p91 is InputEventKey or _p91 is InputEventMouseButton or _p91 is InputEventMouseMotion:
		_i89()

func _i89():
	_m94 = false
	_x44.stop()
	_x44.wait_time = _k39 / 1000.0
	_x44.start()

func _q4():
	_m94 = false
	_x44.stop()

func _y14():
	_m94 = true
	
	var _y68 = Time.get_ticks_msec()
	if _y68 - _e60 < _l84:
		return
	
	if _w89:
		var _u33 = _w89.text
		var _t9 = _w89.get_caret_column()
		
		if _u33 == _c1 and _t9 == _d53:
			return
		
		_c1 = _u33
		_d53 = _t9
	
	_e60 = _y68
	_l10.emit()

func set_delay(_o16: int):
	_k39 = _o16
	_x44.wait_time = _k39 / 1000.0

func _h93():
	_e60 = 0

func _w41(_y44: int):
	_l84 = _y44

func _o76():
	_q32()
	if _x44 and _x44.get_parent():
		_x44.queue_free()

