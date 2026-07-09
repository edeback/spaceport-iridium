@tool
class_name _m65
extends AcceptDialog

signal _k44(_w90: _o9._c71)

@onready var _q61: TabContainer = %TabContainer

@onready var _k73: Label = %_f88
@onready var _r54: ItemList = %_h53
@onready var _u2: Label = %_h55
@onready var original_code: RichTextLabel = %_v97
@onready var refactored_code: RichTextLabel = %_r14

@onready var _i67: Label = %_q97
@onready var _v78: Tree = %_r74
@onready var _j74: Label = %_g23
@onready var _y65: RichTextLabel = %_z100
@onready var _b12: RichTextLabel = %_i10

@onready var _l38: Button = %_t98
@onready var _b55: Button = %_e57
@onready var _x98: Button = %_a73

var _q51: _o9
var _x36: String = ""
var _r11: Array[_o9._c71] = []

func _ready():
	if _r54:
		_r54.item_selected.connect(_y46)
	if _v78:
		_v78.item_selected.connect(_q2)
	if _l38:
		_l38.pressed.connect(_b24)
	if _b55:
		_b55.pressed.connect(_g99)
	if _x98:
		_x98.pressed.connect(_k84)
	
	set_flag(Window.FLAG_RESIZE_DISABLED, false)
	min_size = Vector2i(800, 600)

func _s42(_a50: _o9):
	_q51 = _a50
	_g37()

func _z54(file_path: String):
	_x36 = file_path
	
	if _q61:
		_q61.current_tab = 0  
	
	_g37()
	popup_centered()
	
func _z57():
	_x36 = ""
	
	if _q61:
		_q61.current_tab = 1  
	
	_g37()
	popup_centered()
	
func _g37():
	if not _q51:
		return
	
	_i52()
	_j80()

func _i52():
	if not _q51 or not _r54 or not _k73:
		return
	
	if _x36.is_empty():
		_k73.text = "No file selected"
		_r54.clear()
		_t47()
		return
	
	var _p88 = _x36.get_file()
	_k73.text = "File: %s" % _p88
	
	_r11 = _q51._s37(_x36)
	
	_r54.clear()
	for i in range(_r11.size()):
		var _w90 = _r11[i]
		var _p36 = "%s - %s" % [_w90.function_name, _w90._c45()]
		_r54.add_item(_p36)
		_r54.set_item_tooltip(i, _w90._k12(2))
	
	_t47()

func _j80():
	if not _q51 or not _v78 or not _i67:
		return
	
	var _v88 = _q51._n70()
	var _w28 = _q51._e63()
	var _q21 = _v88.size()
	
	_i67.text = "Total entries: %d across %d files" % [_w28, _q21]
	
	_v78.clear()
	var root = _v78.create_item()
	root.set_text(0, "Refactor History")
	
	for file_path in _v88.keys():
		var _p45: Array = _v88[file_path]
		var _n66 = root.create_child()
		var _p88 = file_path.get_file()
		_n66.set_text(0, "%s (%d)" % [_p88, _p45.size()])
		_n66.set_metadata(0, {"type": "file", "path": file_path})
		
		for _w90 in _p45:
			var _n4 = _n66.create_child()
			_n4.set_text(0, "%s - %s" % [_w90.function_name, _w90._c45()])
			_n4.set_metadata(0, {"type": "entry", "entry": _w90, "path": file_path})
	
	_e2()

func _y46(index: int):
	if index < 0 or index >= _r11.size():
		return
	
	var _w90 = _r11[index]
	_a24(_w90)
	
	_k44.emit(_w90)

func _q2():
	var selected = _v78.get_selected()
	if not selected:
		return
	
	var _s56 = selected.get_metadata(0)
	if not _s56 or not _s56.has("type"):
		return
	
	if _s56.type == "entry" and _s56.has("entry"):
		var _w90: _o9._c71 = _s56._w90
		_f94(_w90)
		
		_k44.emit(_w90)
	else:
		_e2()

func _a24(_w90: _o9._c71):
	if not _w90 or not _u2 or not original_code or not refactored_code:
		return
	
	_u2.text = "Function: %s() - %s" % [_w90.function_name, _w90._c45()]
	
	var _z34 = _d35(_w90.original_code)
	var _z23 = _d35(_w90.refactored_code)
	
	original_code.text = _z34
	refactored_code.text = _z23

func _f94(_w90: _o9._c71):
	if not _w90 or not _j74 or not _y65 or not _b12:
		return
	
	_j74.text = "Function: %s() - %s - %s" % [_w90.function_name, _w90.file_path.get_file(), _w90._c45()]
	
	var _z34 = _d35(_w90.original_code)
	var _z23 = _d35(_w90.refactored_code)
	
	_y65.text = _z34
	_b12.text = _z23

func _t47():
	if _u2:
		_u2.text = "Select an entry to preview"
	if original_code:
		original_code.text = "# Select an entry to view original code"
	if refactored_code:
		refactored_code.text = "# Select an entry to view refactored code"

func _e2():
	if _j74:
		_j74.text = "Select an entry to preview"
	if _y65:
		_y65.text = "# Select an entry to view original code"
	if _b12:
		_b12.text = "# Select an entry to view refactored code"

func _d35(code: String) -> String:
	var _b68 = code
	
	_b68 = _b68.replace("[", "\\[")
	_b68 = _b68.replace("]", "\\]")
	
	var _l46 = ["func", "var", "const", "if", "else", "elif", "for", "while", "match", "return", "break", "continue", "pass", "extends", "class_name", "signal", "enum", "@tool", "@export", "@onready"]
	var _b26 = _b68.split("\n")
	
	for _g20 in range(_b26.size()):
		var line = _b26[_g20]
		
		if "[color=" in line or line.strip_edges().begins_with("#"):
			continue
		
		for keyword in _l46:
			var _v48 = "\\b" + keyword + "\\b"
			var _t20 = RegEx.new()
			_t20.compile(_v48)
			var _u10 = _t20.search_all(line)
			
			for i in range(_u10.size() - 1, -1, -1):
				var _v42 = _u10[i]
				var _t94 = _v42.get_string()
				var _v57 = _v42.get_start()
				var _v54 = _v42.get_end()
				
				line = line.substr(0, _v57) + "[color=#FF6B9D]" + _t94 + "[/color]" + line.substr(_v54)
		
		_b26[_g20] = line
	
	_b68 = "\n".join(_b26)
	
	var _o8 = RegEx.new()
	_o8.compile("\"[^\"]*\"")
	var _c93 = _o8.search_all(_b68)
	for i in range(_c93.size() - 1, -1, -1):
		var _v42 = _c93[i]
		var _t94 = _v42.get_string()
		var _v57 = _v42.get_start()
		var _v54 = _v42.get_end()
		
		if not _t94.contains("[color="):
			_b68 = _b68.substr(0, _v57) + "[color=#98FB98]" + _t94 + "[/color]" + _b68.substr(_v54)
	
	_b26 = _b68.split("\n")
	for i in range(_b26.size()):
		var line = _b26[i]
		var _s79 = line.find("#")
		if _s79 >= 0 and not line.substr(0, _s79).contains("[color="):
			var _d93 = line.substr(0, _s79)
			var _l70 = line.substr(_s79)
			if not _l70.contains("[color="):
				_b26[i] = _d93 + "[color=#87CEEB]" + _l70 + "[/color]"
	_b68 = "\n".join(_b26)
	
	return _b68

func _b24():
	if not _q51 or _x36.is_empty():
		return
	
	_q51._f9(_x36)
	_g37()
	
func _g99():
	if not _q51:
		return
	
	_q51._g81()
	_g37()
	
func _k84():
	hide()

func set_current_file(file_path: String):
	_x36 = file_path
	if is_inside_tree():
		_i52()

