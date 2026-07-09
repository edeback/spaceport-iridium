@tool
class_name _c59
extends AcceptDialog
signal _k61(_p42: _n17._f84)
@onready var _y23: TabContainer = %TabContainer
@onready var _a48: Label = %_v62
@onready var _f38: ItemList = %_n36
@onready var _w26: Label = %_a19
@onready var original_code: RichTextLabel = %_a46
@onready var refactored_code: RichTextLabel = %_i49
@onready var _v66: Label = %_h18
@onready var _v68: Tree = %_e92
@onready var _s34: Label = %_p43
@onready var _j42: RichTextLabel = %_y13
@onready var _f6: RichTextLabel = %_z93
@onready var _a65: Button = %_e23
@onready var _e53: Button = %_q91
@onready var _r84: Button = %_y81
var _f72: _n17
var _f19: String = ""
var _f27: Array[_n17._f84] = []
func _ready():
	if _f38:
		_f38.item_selected.connect(_d46)
	if _v68:
		_v68.item_selected.connect(_c68)
	if _a65:
		_a65.pressed.connect(_o47)
	if _e53:
		_e53.pressed.connect(_x31)
	if _r84:
		_r84.pressed.connect(_g20)
	set_flag(Window.FLAG_RESIZE_DISABLED, false)
	min_size = Vector2i(800, 600)
func _s5(_z40: _n17):
	_f72 = _z40
	_b77()
func _u76(file_path: String):
	_f19 = file_path
	if _y23:
		_y23.current_tab = 0  
	_b77()
	popup_centered()
func _d55():
	_f19 = ""
	if _y23:
		_y23.current_tab = 1  
	_b77()
	popup_centered()
func _b77():
	if not _f72:
		return
	_h94()
	_j81()
func _h94():
	if not _f72 or not _f38 or not _a48:
		return
	if _f19.is_empty():
		_a48.text = "No file selected"
		_f38.clear()
		_k8()
		return
	var _f63 = _f19.get_file()
	_a48.text = "File: %s" % _f63
	_f27 = _f72._l91(_f19)
	_f38.clear()
	for i in range(_f27.size()):
		var _p42 = _f27[i]
		var _w7 = "%s - %s" % [_p42.function_name, _p42._s30()]
		_f38.add_item(_w7)
		_f38.set_item_tooltip(i, _p42._x69(2))
	_k8()
func _j81():
	if not _f72 or not _v68 or not _v66:
		return
	var _z66 = _f72._n94()
	var _a85 = _f72._y25()
	var _v58 = _z66.size()
	_v66.text = "Total entries: %d across %d files" % [_a85, _v58]
	_v68.clear()
	var root = _v68.create_item()
	root.set_text(0, "Refactor History")
	for file_path in _z66.keys():
		var _x43: Array = _z66[file_path]
		var _r31 = root.create_child()
		var _f63 = file_path.get_file()
		_r31.set_text(0, "%s (%d)" % [_f63, _x43.size()])
		_r31.set_metadata(0, {"type": "file", "path": file_path})
		for _p42 in _x43:
			var _b25 = _r31.create_child()
			_b25.set_text(0, "%s - %s" % [_p42.function_name, _p42._s30()])
			_b25.set_metadata(0, {"type": "entry", "entry": _p42, "path": file_path})
	_h35()
func _d46(index: int):
	if index < 0 or index >= _f27.size():
		return
	var _p42 = _f27[index]
	_x11(_p42)
	_k61.emit(_p42)
func _c68():
	var selected = _v68.get_selected()
	if not selected:
		return
	var _m15 = selected.get_metadata(0)
	if not _m15 or not _m15.has("type"):
		return
	if _m15.type == "entry" and _m15.has("entry"):
		var _p42: _n17._f84 = _m15._p42
		_h53(_p42)
		_k61.emit(_p42)
	else:
		_h35()
func _x11(_p42: _n17._f84):
	if not _p42 or not _w26 or not original_code or not refactored_code:
		return
	_w26.text = "Function: %s() - %s" % [_p42.function_name, _p42._s30()]
	var _x85 = _t49(_p42.original_code)
	var _s90 = _t49(_p42.refactored_code)
	original_code.text = _x85
	refactored_code.text = _s90
func _h53(_p42: _n17._f84):
	if not _p42 or not _s34 or not _j42 or not _f6:
		return
	_s34.text = "Function: %s() - %s - %s" % [_p42.function_name, _p42.file_path.get_file(), _p42._s30()]
	var _x85 = _t49(_p42.original_code)
	var _s90 = _t49(_p42.refactored_code)
	_j42.text = _x85
	_f6.text = _s90
func _k8():
	if _w26:
		_w26.text = "Select an entry to preview"
	if original_code:
		original_code.text = "# Select an entry to view original code"
	if refactored_code:
		refactored_code.text = "# Select an entry to view refactored code"
func _h35():
	if _s34:
		_s34.text = "Select an entry to preview"
	if _j42:
		_j42.text = "# Select an entry to view original code"
	if _f6:
		_f6.text = "# Select an entry to view refactored code"
func _t49(code: String) -> String:
	var _h81 = code
	_h81 = _h81.replace("[", "\\[")
	_h81 = _h81.replace("]", "\\]")
	var _q51 = ["func", "var", "const", "if", "else", "elif", "for", "while", "match", "return", "break", "continue", "pass", "extends", "class_name", "signal", "enum", "@tool", "@export", "@onready"]
	var _j90 = _h81.split("\n")
	for _n21 in range(_j90.size()):
		var line = _j90[_n21]
		if "[color=" in line or line.strip_edges().begins_with("#"):
			continue
		for keyword in _q51:
			var _y99 = "\\b" + keyword + "\\b"
			var _v54 = RegEx.new()
			_v54.compile(_y99)
			var _x1 = _v54.search_all(line)
			for i in range(_x1.size() - 1, -1, -1):
				var _x97 = _x1[i]
				var _k93 = _x97.get_string()
				var _v98 = _x97.get_start()
				var _s69 = _x97.get_end()
				line = line.substr(0, _v98) + "[color=#FF6B9D]" + _k93 + "[/color]" + line.substr(_s69)
		_j90[_n21] = line
	_h81 = "\n".join(_j90)
	var _l34 = RegEx.new()
	_l34.compile("\"[^\"]*\"")
	var _j32 = _l34.search_all(_h81)
	for i in range(_j32.size() - 1, -1, -1):
		var _x97 = _j32[i]
		var _k93 = _x97.get_string()
		var _v98 = _x97.get_start()
		var _s69 = _x97.get_end()
		if not _k93.contains("[color="):
			_h81 = _h81.substr(0, _v98) + "[color=#98FB98]" + _k93 + "[/color]" + _h81.substr(_s69)
	_j90 = _h81.split("\n")
	for i in range(_j90.size()):
		var line = _j90[i]
		var _y75 = line.find("#")
		if _y75 >= 0 and not line.substr(0, _y75).contains("[color="):
			var _q86 = line.substr(0, _y75)
			var _o15 = line.substr(_y75)
			if not _o15.contains("[color="):
				_j90[i] = _q86 + "[color=#87CEEB]" + _o15 + "[/color]"
	_h81 = "\n".join(_j90)
	return _h81
func _o47():
	if not _f72 or _f19.is_empty():
		return
	_f72._k91(_f19)
	_b77()
func _x31():
	if not _f72:
		return
	_f72._x77()
	_b77()
func _g20():
	hide()
func set_current_file(file_path: String):
	_f19 = file_path
	if is_inside_tree():
		_h94()
