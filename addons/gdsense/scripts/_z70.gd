@tool
extends RefCounted
class_name _n72

signal _z2()

var _v14: Timer
var _m91: int = 800  
var _z56: bool = false
var _b60: CodeEdit
var _r10: int = 0
var _t61: int = 3000  
var _h23: String = ""
var _e12: int = -1

func _init(_v78: CodeEdit):
	_b60 = _v78
	
	_v14 = Timer.new()
	_v14.wait_time = _m91 / 1000.0
	_v14.one_shot = true
	_v14.timeout.connect(_s36)
	
	if _b60:
		_b60.add_child(_v14)

func _q15():
	if _b60:
		if not _b60.text_changed.is_connected(_u29):
			_b60.text_changed.connect(_u29)
		if not _b60.caret_changed.is_connected(_g29):
			_b60.caret_changed.connect(_g29)
		if not _b60.gui_input.is_connected(_e18):
			_b60.gui_input.connect(_e18)

func _j39():
	if _b60:
		if _b60.text_changed.is_connected(_u29):
			_b60.text_changed.disconnect(_u29)
		if _b60.caret_changed.is_connected(_g29):
			_b60.caret_changed.disconnect(_g29)
		if _b60.gui_input.is_connected(_e18):
			_b60.gui_input.disconnect(_e18)
	_w72()

func _u29():
	_s95()

func _g29():
	_s95()

func _e18(_x1: InputEvent):
	if _x1 is InputEventKey or _x1 is InputEventMouseButton or _x1 is InputEventMouseMotion:
		_s95()

func _s95():
	_z56 = false
	_v14.stop()
	_v14.wait_time = _m91 / 1000.0
	_v14.start()

func _w72():
	_z56 = false
	_v14.stop()

func _s36():
	_z56 = true
	
	var _l95 = Time.get_ticks_msec()
	if _l95 - _r10 < _t61:
		return
	
	if _b60:
		var _d25 = _b60.text
		var _o14 = _b60.get_caret_column()
		
		if _d25 == _h23 and _o14 == _e12:
			return
		
		_h23 = _d25
		_e12 = _o14
	
	_r10 = _l95
	_z2.emit()

func set_delay(_j62: int):
	_m91 = _j62
	_v14.wait_time = _m91 / 1000.0

func _y20():
	_r10 = 0

func _n22(_c60: int):
	_t61 = _c60

func _q17():
	_j39()
	if _v14 and _v14.get_parent():
		_v14.queue_free()

