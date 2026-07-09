@tool
class_name _n55
extends AcceptDialog
signal _f66(_x74: _z30._n40)
@onready var _v82: TabContainer = %TabContainer
@onready var _h36: Label = %_u77
@onready var _t66: ItemList = %_l26
@onready var _w17: Label = %_g62
@onready var original_code: RichTextLabel = %_w82
@onready var refactored_code: RichTextLabel = %_g32
@onready var _o8: Label = %_n64
@onready var _m11: Tree = %_t40
@onready var _m28: Label = %_l77
@onready var _b5: RichTextLabel = %_s62
@onready var _z2: RichTextLabel = %_n57
@onready var _y23: Button = %_w61
@onready var _l94: Button = %_y76
@onready var _j84: Button = %_m37
var _t28: _z30
var _o13: String = ""
var _d17: Array[_z30._n40] = []
func _ready():
	if _t66:
		_t66.item_selected.connect(_u50)
	if _m11:
		_m11.item_selected.connect(_u35)
	if _y23:
		_y23.pressed.connect(_w16)
	if _l94:
		_l94.pressed.connect(_s85)
	if _j84:
		_j84.pressed.connect(_q34)
	set_flag(Window.FLAG_RESIZE_DISABLED, false)
	min_size = Vector2i(800, 600)
func _r76(_q40: _z30):
	_t28 = _q40
	_z68()
func _s93(file_path: String):
	_o13 = file_path
	if _v82:
		_v82.current_tab = 0  
	_z68()
	popup_centered()
func _u64():
	_o13 = ""
	if _v82:
		_v82.current_tab = 1  
	_z68()
	popup_centered()
func _z68():
	if not _t28:
		return
	_a35()
	_m2()
func _a35():
	if not _t28 or not _t66 or not _h36:
		return
	if _o13.is_empty():
		_h36.text = "No file selected"
		_t66.clear()
		_l71()
		return
	var _s80 = _o13.get_file()
	_h36.text = "File: %s" % _s80
	_d17 = _t28._b2(_o13)
	_t66.clear()
	for i in range(_d17.size()):
		var _x74 = _d17[i]
		var _g7 = "%s - %s" % [_x74.function_name, _x74._s37()]
		_t66.add_item(_g7)
		_t66.set_item_tooltip(i, _x74._v80(2))
	_l71()
func _m2():
	if not _t28 or not _m11 or not _o8:
		return
	var _o84 = _t28._l90()
	var _u15 = _t28._b82()
	var _e59 = _o84.size()
	_o8.text = "Total entries: %d across %d files" % [_u15, _e59]
	_m11.clear()
	var root = _m11.create_item()
	root.set_text(0, "Refactor History")
	for file_path in _o84.keys():
		var _g95: Array = _o84[file_path]
		var _m93 = root.create_child()
		var _s80 = file_path.get_file()
		_m93.set_text(0, "%s (%d)" % [_s80, _g95.size()])
		_m93.set_metadata(0, {"type": "file", "path": file_path})
		for _x74 in _g95:
			var _p42 = _m93.create_child()
			_p42.set_text(0, "%s - %s" % [_x74.function_name, _x74._s37()])
			_p42.set_metadata(0, {"type": "entry", "entry": _x74, "path": file_path})
	_i77()
func _u50(index: int):
	if index < 0 or index >= _d17.size():
		return
	var _x74 = _d17[index]
	_i32(_x74)
	_f66.emit(_x74)
func _u35():
	var selected = _m11.get_selected()
	if not selected:
		return
	var _e71 = selected.get_metadata(0)
	if not _e71 or not _e71.has("type"):
		return
	if _e71.type == "entry" and _e71.has("entry"):
		var _x74: _z30._n40 = _e71._x74
		_u99(_x74)
		_f66.emit(_x74)
	else:
		_i77()
func _i32(_x74: _z30._n40):
	if not _x74 or not _w17 or not original_code or not refactored_code:
		return
	_w17.text = "Function: %s() - %s" % [_x74.function_name, _x74._s37()]
	var _d3 = _u61(_x74.original_code)
	var _c88 = _u61(_x74.refactored_code)
	original_code.text = _d3
	refactored_code.text = _c88
func _u99(_x74: _z30._n40):
	if not _x74 or not _m28 or not _b5 or not _z2:
		return
	_m28.text = "Function: %s() - %s - %s" % [_x74.function_name, _x74.file_path.get_file(), _x74._s37()]
	var _d3 = _u61(_x74.original_code)
	var _c88 = _u61(_x74.refactored_code)
	_b5.text = _d3
	_z2.text = _c88
func _l71():
	if _w17:
		_w17.text = "Select an entry to preview"
	if original_code:
		original_code.text = "# Select an entry to view original code"
	if refactored_code:
		refactored_code.text = "# Select an entry to view refactored code"
func _i77():
	if _m28:
		_m28.text = "Select an entry to preview"
	if _b5:
		_b5.text = "# Select an entry to view original code"
	if _z2:
		_z2.text = "# Select an entry to view refactored code"
func _u61(code: String) -> String:
	var _q71 = code
	_q71 = _q71.replace("[", "\\[")
	_q71 = _q71.replace("]", "\\]")
	var _h30 = ["func", "var", "const", "if", "else", "elif", "for", "while", "match", "return", "break", "continue", "pass", "extends", "class_name", "signal", "enum", "@tool", "@export", "@onready"]
	var _a62 = _q71.split("\n")
	for _h16 in range(_a62.size()):
		var line = _a62[_h16]
		if "[color=" in line or line.strip_edges().begins_with("#"):
			continue
		for keyword in _h30:
			var _a45 = "\\b" + keyword + "\\b"
			var _s2 = RegEx.new()
			_s2.compile(_a45)
			var _e14 = _s2.search_all(line)
			for i in range(_e14.size() - 1, -1, -1):
				var _n37 = _e14[i]
				var _o5 = _n37.get_string()
				var _w51 = _n37.get_start()
				var _r10 = _n37.get_end()
				line = line.substr(0, _w51) + "[color=#FF6B9D]" + _o5 + "[/color]" + line.substr(_r10)
		_a62[_h16] = line
	_q71 = "\n".join(_a62)
	var _e57 = RegEx.new()
	_e57.compile("\"[^\"]*\"")
	var _q14 = _e57.search_all(_q71)
	for i in range(_q14.size() - 1, -1, -1):
		var _n37 = _q14[i]
		var _o5 = _n37.get_string()
		var _w51 = _n37.get_start()
		var _r10 = _n37.get_end()
		if not _o5.contains("[color="):
			_q71 = _q71.substr(0, _w51) + "[color=#98FB98]" + _o5 + "[/color]" + _q71.substr(_r10)
	_a62 = _q71.split("\n")
	for i in range(_a62.size()):
		var line = _a62[i]
		var _e18 = line.find("#")
		if _e18 >= 0 and not line.substr(0, _e18).contains("[color="):
			var _l69 = line.substr(0, _e18)
			var _c20 = line.substr(_e18)
			if not _c20.contains("[color="):
				_a62[i] = _l69 + "[color=#87CEEB]" + _c20 + "[/color]"
	_q71 = "\n".join(_a62)
	return _q71
func _w16():
	if not _t28 or _o13.is_empty():
		return
	_t28._z63(_o13)
	_z68()
func _s85():
	if not _t28:
		return
	_t28._z5()
	_z68()
func _q34():
	hide()
func set_current_file(file_path: String):
	_o13 = file_path
	if is_inside_tree():
		_a35()
