@tool
class_name _j61
extends AcceptDialog

signal _t61(_j91: _w99._u22)

@onready var _n32: TabContainer = %TabContainer

@onready var _p86: Label = %_i51
@onready var _m3: ItemList = %_a60
@onready var _j98: Label = %_t12
@onready var original_code: RichTextLabel = %_x31
@onready var refactored_code: RichTextLabel = %_u35

@onready var _y73: Label = %_k54
@onready var _w50: Tree = %_t65
@onready var _x52: Label = %_j60
@onready var _t59: RichTextLabel = %_l67
@onready var _v31: RichTextLabel = %_t32

@onready var _w81: Button = %_r81
@onready var _k7: Button = %_v14
@onready var _l29: Button = %_m91

var _r38: _w99
var _f54: String = ""
var _c7: Array[_w99._u22] = []

func _ready():
	if _m3:
		_m3.item_selected.connect(_k37)
	if _w50:
		_w50.item_selected.connect(_o2)
	if _w81:
		_w81.pressed.connect(_t62)
	if _k7:
		_k7.pressed.connect(_y94)
	if _l29:
		_l29.pressed.connect(_q49)
	
	set_flag(Window.FLAG_RESIZE_DISABLED, false)
	min_size = Vector2i(800, 600)

func _g49(_t25: _w99):
	_r38 = _t25
	_f70()

func _i54(file_path: String):
	_f54 = file_path
	
	if _n32:
		_n32.current_tab = 0  
	
	_f70()
	popup_centered()
	
func _r97():
	_f54 = ""
	
	if _n32:
		_n32.current_tab = 1  
	
	_f70()
	popup_centered()
	
func _f70():
	if not _r38:
		return
	
	_s58()
	_r8()

func _s58():
	if not _r38 or not _m3 or not _p86:
		return
	
	if _f54.is_empty():
		_p86.text = "No file selected"
		_m3.clear()
		_s14()
		return
	
	var _m48 = _f54.get_file()
	_p86.text = "File: %s" % _m48
	
	_c7 = _r38._h35(_f54)
	
	_m3.clear()
	for i in range(_c7.size()):
		var _j91 = _c7[i]
		var _k13 = "%s - %s" % [_j91.function_name, _j91._s57()]
		_m3.add_item(_k13)
		_m3.set_item_tooltip(i, _j91._d86(2))
	
	_s14()

func _r8():
	if not _r38 or not _w50 or not _y73:
		return
	
	var _l95 = _r38._r80()
	var _u98 = _r38._r85()
	var _v73 = _l95.size()
	
	_y73.text = "Total entries: %d across %d files" % [_u98, _v73]
	
	_w50.clear()
	var root = _w50.create_item()
	root.set_text(0, "Refactor History")
	
	for file_path in _l95.keys():
		var _h9: Array = _l95[file_path]
		var _n59 = root.create_child()
		var _m48 = file_path.get_file()
		_n59.set_text(0, "%s (%d)" % [_m48, _h9.size()])
		_n59.set_metadata(0, {"type": "file", "path": file_path})
		
		for _j91 in _h9:
			var _e53 = _n59.create_child()
			_e53.set_text(0, "%s - %s" % [_j91.function_name, _j91._s57()])
			_e53.set_metadata(0, {"type": "entry", "entry": _j91, "path": file_path})
	
	_d59()

func _k37(index: int):
	if index < 0 or index >= _c7.size():
		return
	
	var _j91 = _c7[index]
	_o16(_j91)
	
	_t61.emit(_j91)

func _o2():
	var selected = _w50.get_selected()
	if not selected:
		return
	
	var _j3 = selected.get_metadata(0)
	if not _j3 or not _j3.has("type"):
		return
	
	if _j3.type == "entry" and _j3.has("entry"):
		var _j91: _w99._u22 = _j3._j91
		_c39(_j91)
		
		_t61.emit(_j91)
	else:
		_d59()

func _o16(_j91: _w99._u22):
	if not _j91 or not _j98 or not original_code or not refactored_code:
		return
	
	_j98.text = "Function: %s() - %s" % [_j91.function_name, _j91._s57()]
	
	var _i88 = _t98(_j91.original_code)
	var _t47 = _t98(_j91.refactored_code)
	
	original_code.text = _i88
	refactored_code.text = _t47

func _c39(_j91: _w99._u22):
	if not _j91 or not _x52 or not _t59 or not _v31:
		return
	
	_x52.text = "Function: %s() - %s - %s" % [_j91.function_name, _j91.file_path.get_file(), _j91._s57()]
	
	var _i88 = _t98(_j91.original_code)
	var _t47 = _t98(_j91.refactored_code)
	
	_t59.text = _i88
	_v31.text = _t47

func _s14():
	if _j98:
		_j98.text = "Select an entry to preview"
	if original_code:
		original_code.text = "# Select an entry to view original code"
	if refactored_code:
		refactored_code.text = "# Select an entry to view refactored code"

func _d59():
	if _x52:
		_x52.text = "Select an entry to preview"
	if _t59:
		_t59.text = "# Select an entry to view original code"
	if _v31:
		_v31.text = "# Select an entry to view refactored code"

func _t98(code: String) -> String:
	var _x87 = code
	
	_x87 = _x87.replace("[", "\\[")
	_x87 = _x87.replace("]", "\\]")
	
	var _c18 = ["func", "var", "const", "if", "else", "elif", "for", "while", "match", "return", "break", "continue", "pass", "extends", "class_name", "signal", "enum", "@tool", "@export", "@onready"]
	var _m12 = _x87.split("\n")
	
	for _f63 in range(_m12.size()):
		var line = _m12[_f63]
		
		if "[color=" in line or line.strip_edges().begins_with("#"):
			continue
		
		for keyword in _c18:
			var _c84 = "\\b" + keyword + "\\b"
			var _p69 = RegEx.new()
			_p69.compile(_c84)
			var _x71 = _p69.search_all(line)
			
			for i in range(_x71.size() - 1, -1, -1):
				var _k3 = _x71[i]
				var _u89 = _k3.get_string()
				var _o30 = _k3.get_start()
				var _z49 = _k3.get_end()
				
				line = line.substr(0, _o30) + "[color=#FF6B9D]" + _u89 + "[/color]" + line.substr(_z49)
		
		_m12[_f63] = line
	
	_x87 = "\n".join(_m12)
	
	var _h75 = RegEx.new()
	_h75.compile("\"[^\"]*\"")
	var _b33 = _h75.search_all(_x87)
	for i in range(_b33.size() - 1, -1, -1):
		var _k3 = _b33[i]
		var _u89 = _k3.get_string()
		var _o30 = _k3.get_start()
		var _z49 = _k3.get_end()
		
		if not _u89.contains("[color="):
			_x87 = _x87.substr(0, _o30) + "[color=#98FB98]" + _u89 + "[/color]" + _x87.substr(_z49)
	
	_m12 = _x87.split("\n")
	for i in range(_m12.size()):
		var line = _m12[i]
		var _f27 = line.find("#")
		if _f27 >= 0 and not line.substr(0, _f27).contains("[color="):
			var _e20 = line.substr(0, _f27)
			var _q43 = line.substr(_f27)
			if not _q43.contains("[color="):
				_m12[i] = _e20 + "[color=#87CEEB]" + _q43 + "[/color]"
	_x87 = "\n".join(_m12)
	
	return _x87

func _t62():
	if not _r38 or _f54.is_empty():
		return
	
	_r38._e58(_f54)
	_f70()
	
func _y94():
	if not _r38:
		return
	
	_r38._t7()
	_f70()
	
func _q49():
	hide()

func set_current_file(file_path: String):
	_f54 = file_path
	if is_inside_tree():
		_s58()

