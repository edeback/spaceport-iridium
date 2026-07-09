@tool
class_name _i36
extends AcceptDialog

signal _g20(_h5: _b26._n2)

@onready var _b49: TabContainer = %TabContainer

@onready var _h42: Label = %_w36
@onready var _q87: ItemList = %_j84
@onready var _n84: Label = %_p14
@onready var original_code: RichTextLabel = %_v46
@onready var refactored_code: RichTextLabel = %_c13

@onready var _a61: Label = %_w97
@onready var _m48: Tree = %_f59
@onready var _o63: Label = %_n93
@onready var _z50: RichTextLabel = %_i74
@onready var _r74: RichTextLabel = %_p58

@onready var _q3: Button = %_x53
@onready var _l63: Button = %_d67
@onready var _a49: Button = %_h8

var _p47: _b26
var _q20: String = ""
var _w77: Array[_b26._n2] = []

func _ready():
	if _q87:
		_q87.item_selected.connect(_n18)
	if _m48:
		_m48.item_selected.connect(_p56)
	if _q3:
		_q3.pressed.connect(_n4)
	if _l63:
		_l63.pressed.connect(_u40)
	if _a49:
		_a49.pressed.connect(_v6)
	
	set_flag(Window.FLAG_RESIZE_DISABLED, false)
	min_size = Vector2i(800, 600)

func _b53(_q89: _b26):
	_p47 = _q89
	_p28()

func _l46(file_path: String):
	_q20 = file_path
	
	if _b49:
		_b49.current_tab = 0  
	
	_p28()
	popup_centered()
	
func _q70():
	_q20 = ""
	
	if _b49:
		_b49.current_tab = 1  
	
	_p28()
	popup_centered()
	
func _p28():
	if not _p47:
		return
	
	_u16()
	_c7()

func _u16():
	if not _p47 or not _q87 or not _h42:
		return
	
	if _q20.is_empty():
		_h42.text = "No file selected"
		_q87.clear()
		_x69()
		return
	
	var _x87 = _q20.get_file()
	_h42.text = "File: %s" % _x87
	
	_w77 = _p47._o92(_q20)
	
	_q87.clear()
	for i in range(_w77.size()):
		var _h5 = _w77[i]
		var _h17 = "%s - %s" % [_h5.function_name, _h5._l34()]
		_q87.add_item(_h17)
		_q87.set_item_tooltip(i, _h5._e45(2))
	
	_x69()

func _c7():
	if not _p47 or not _m48 or not _a61:
		return
	
	var _f42 = _p47._w78()
	var _h28 = _p47._v87()
	var _j76 = _f42.size()
	
	_a61.text = "Total entries: %d across %d files" % [_h28, _j76]
	
	_m48.clear()
	var root = _m48.create_item()
	root.set_text(0, "Refactor History")
	
	for file_path in _f42.keys():
		var _r7: Array = _f42[file_path]
		var _g66 = root.create_child()
		var _x87 = file_path.get_file()
		_g66.set_text(0, "%s (%d)" % [_x87, _r7.size()])
		_g66.set_metadata(0, {"type": "file", "path": file_path})
		
		for _h5 in _r7:
			var _v48 = _g66.create_child()
			_v48.set_text(0, "%s - %s" % [_h5.function_name, _h5._l34()])
			_v48.set_metadata(0, {"type": "entry", "entry": _h5, "path": file_path})
	
	_o8()

func _n18(index: int):
	if index < 0 or index >= _w77.size():
		return
	
	var _h5 = _w77[index]
	_e36(_h5)
	
	_g20.emit(_h5)

func _p56():
	var selected = _m48.get_selected()
	if not selected:
		return
	
	var _e78 = selected.get_metadata(0)
	if not _e78 or not _e78.has("type"):
		return
	
	if _e78.type == "entry" and _e78.has("entry"):
		var _h5: _b26._n2 = _e78._h5
		_x20(_h5)
		
		_g20.emit(_h5)
	else:
		_o8()

func _e36(_h5: _b26._n2):
	if not _h5 or not _n84 or not original_code or not refactored_code:
		return
	
	_n84.text = "Function: %s() - %s" % [_h5.function_name, _h5._l34()]
	
	var _x28 = _b15(_h5.original_code)
	var _j34 = _b15(_h5.refactored_code)
	
	original_code.text = _x28
	refactored_code.text = _j34

func _x20(_h5: _b26._n2):
	if not _h5 or not _o63 or not _z50 or not _r74:
		return
	
	_o63.text = "Function: %s() - %s - %s" % [_h5.function_name, _h5.file_path.get_file(), _h5._l34()]
	
	var _x28 = _b15(_h5.original_code)
	var _j34 = _b15(_h5.refactored_code)
	
	_z50.text = _x28
	_r74.text = _j34

func _x69():
	if _n84:
		_n84.text = "Select an entry to preview"
	if original_code:
		original_code.text = "# Select an entry to view original code"
	if refactored_code:
		refactored_code.text = "# Select an entry to view refactored code"

func _o8():
	if _o63:
		_o63.text = "Select an entry to preview"
	if _z50:
		_z50.text = "# Select an entry to view original code"
	if _r74:
		_r74.text = "# Select an entry to view refactored code"

func _b15(code: String) -> String:
	var _j9 = code
	
	_j9 = _j9.replace("[", "\\[")
	_j9 = _j9.replace("]", "\\]")
	
	var _l16 = ["func", "var", "const", "if", "else", "elif", "for", "while", "match", "return", "break", "continue", "pass", "extends", "class_name", "signal", "enum", "@tool", "@export", "@onready"]
	var _d41 = _j9.split("\n")
	
	for _q73 in range(_d41.size()):
		var line = _d41[_q73]
		
		if "[color=" in line or line.strip_edges().begins_with("#"):
			continue
		
		for keyword in _l16:
			var _t30 = "\\b" + keyword + "\\b"
			var _g88 = RegEx.new()
			_g88.compile(_t30)
			var _i2 = _g88.search_all(line)
			
			for i in range(_i2.size() - 1, -1, -1):
				var _x97 = _i2[i]
				var _t1 = _x97.get_string()
				var _z37 = _x97.get_start()
				var _g15 = _x97.get_end()
				
				line = line.substr(0, _z37) + "[color=#FF6B9D]" + _t1 + "[/color]" + line.substr(_g15)
		
		_d41[_q73] = line
	
	_j9 = "\n".join(_d41)
	
	var _q64 = RegEx.new()
	_q64.compile("\"[^\"]*\"")
	var _e28 = _q64.search_all(_j9)
	for i in range(_e28.size() - 1, -1, -1):
		var _x97 = _e28[i]
		var _t1 = _x97.get_string()
		var _z37 = _x97.get_start()
		var _g15 = _x97.get_end()
		
		if not _t1.contains("[color="):
			_j9 = _j9.substr(0, _z37) + "[color=#98FB98]" + _t1 + "[/color]" + _j9.substr(_g15)
	
	_d41 = _j9.split("\n")
	for i in range(_d41.size()):
		var line = _d41[i]
		var _y37 = line.find("#")
		if _y37 >= 0 and not line.substr(0, _y37).contains("[color="):
			var _p13 = line.substr(0, _y37)
			var _l13 = line.substr(_y37)
			if not _l13.contains("[color="):
				_d41[i] = _p13 + "[color=#87CEEB]" + _l13 + "[/color]"
	_j9 = "\n".join(_d41)
	
	return _j9

func _n4():
	if not _p47 or _q20.is_empty():
		return
	
	_p47._a90(_q20)
	_p28()
	
func _u40():
	if not _p47:
		return
	
	_p47._f4()
	_p28()
	
func _v6():
	hide()

func set_current_file(file_path: String):
	_q20 = file_path
	if is_inside_tree():
		_u16()

