@tool
class_name _c16
extends AcceptDialog
signal _z85(_r10: _z9._l87)
@onready var _b5: TabContainer = %TabContainer
@onready var _w3: Label = %_u32
@onready var _z98: ItemList = %_z59
@onready var _v5: Label = %_x32
@onready var original_code: RichTextLabel = %_a29
@onready var refactored_code: RichTextLabel = %_f91
@onready var _f13: Label = %_y4
@onready var _n58: Tree = %_h92
@onready var _q55: Label = %_l62
@onready var _o24: RichTextLabel = %_b35
@onready var _z14: RichTextLabel = %_t72
@onready var _y33: Button = %_q85
@onready var _k42: Button = %_b53
@onready var _x24: Button = %_y17
var _m6: _z9
var _k50: String = ""
var _g29: Array[_z9._l87] = []
func _ready():
	if _z98:
		_z98.item_selected.connect(_z99)
	if _n58:
		_n58.item_selected.connect(_h78)
	if _y33:
		_y33.pressed.connect(_w56)
	if _k42:
		_k42.pressed.connect(_i54)
	if _x24:
		_x24.pressed.connect(_o58)
	set_flag(Window.FLAG_RESIZE_DISABLED, false)
	min_size = Vector2i(800, 600)
func _f92(_t63: _z9):
	_m6 = _t63
	_k58()
func _k82(file_path: String):
	_k50 = file_path
	if _b5:
		_b5.current_tab = 0  
	_k58()
	popup_centered()
func _q25():
	_k50 = ""
	if _b5:
		_b5.current_tab = 1  
	_k58()
	popup_centered()
func _k58():
	if not _m6:
		return
	_k95()
	_u33()
func _k95():
	if not _m6 or not _z98 or not _w3:
		return
	if _k50.is_empty():
		_w3.text = "No file selected"
		_z98.clear()
		_f62()
		return
	var _g95 = _k50.get_file()
	_w3.text = "File: %s" % _g95
	_g29 = _m6._f87(_k50)
	_z98.clear()
	for i in range(_g29.size()):
		var _r10 = _g29[i]
		var _l26 = "%s - %s" % [_r10.function_name, _r10._v7()]
		_z98.add_item(_l26)
		_z98.set_item_tooltip(i, _r10._c59(2))
	_f62()
func _u33():
	if not _m6 or not _n58 or not _f13:
		return
	var _z65 = _m6._g33()
	var _d44 = _m6._b42()
	var _m25 = _z65.size()
	_f13.text = "Total entries: %d across %d files" % [_d44, _m25]
	_n58.clear()
	var root = _n58.create_item()
	root.set_text(0, "Refactor History")
	for file_path in _z65.keys():
		var _r94: Array = _z65[file_path]
		var _h46 = root.create_child()
		var _g95 = file_path.get_file()
		_h46.set_text(0, "%s (%d)" % [_g95, _r94.size()])
		_h46.set_metadata(0, {"type": "file", "path": file_path})
		for _r10 in _r94:
			var _b68 = _h46.create_child()
			_b68.set_text(0, "%s - %s" % [_r10.function_name, _r10._v7()])
			_b68.set_metadata(0, {"type": "entry", "entry": _r10, "path": file_path})
	_r11()
func _z99(index: int):
	if index < 0 or index >= _g29.size():
		return
	var _r10 = _g29[index]
	_b19(_r10)
	_z85.emit(_r10)
func _h78():
	var selected = _n58.get_selected()
	if not selected:
		return
	var _o27 = selected.get_metadata(0)
	if not _o27 or not _o27.has("type"):
		return
	if _o27.type == "entry" and _o27.has("entry"):
		var _r10: _z9._l87 = _o27._r10
		_k5(_r10)
		_z85.emit(_r10)
	else:
		_r11()
func _b19(_r10: _z9._l87):
	if not _r10 or not _v5 or not original_code or not refactored_code:
		return
	_v5.text = "Function: %s() - %s" % [_r10.function_name, _r10._v7()]
	var _a97 = _h25(_r10.original_code)
	var _e72 = _h25(_r10.refactored_code)
	original_code.text = _a97
	refactored_code.text = _e72
func _k5(_r10: _z9._l87):
	if not _r10 or not _q55 or not _o24 or not _z14:
		return
	_q55.text = "Function: %s() - %s - %s" % [_r10.function_name, _r10.file_path.get_file(), _r10._v7()]
	var _a97 = _h25(_r10.original_code)
	var _e72 = _h25(_r10.refactored_code)
	_o24.text = _a97
	_z14.text = _e72
func _f62():
	if _v5:
		_v5.text = "Select an entry to preview"
	if original_code:
		original_code.text = "# Select an entry to view original code"
	if refactored_code:
		refactored_code.text = "# Select an entry to view refactored code"
func _r11():
	if _q55:
		_q55.text = "Select an entry to preview"
	if _o24:
		_o24.text = "# Select an entry to view original code"
	if _z14:
		_z14.text = "# Select an entry to view refactored code"
func _h25(code: String) -> String:
	var _s62 = code
	_s62 = _s62.replace("[", "\\[")
	_s62 = _s62.replace("]", "\\]")
	var _w76 = ["func", "var", "const", "if", "else", "elif", "for", "while", "match", "return", "break", "continue", "pass", "extends", "class_name", "signal", "enum", "@tool", "@export", "@onready"]
	var _p91 = _s62.split("\n")
	for _f71 in range(_p91.size()):
		var line = _p91[_f71]
		if "[color=" in line or line.strip_edges().begins_with("#"):
			continue
		for keyword in _w76:
			var _j73 = "\\b" + keyword + "\\b"
			var _x62 = RegEx.new()
			_x62.compile(_j73)
			var _g27 = _x62.search_all(line)
			for i in range(_g27.size() - 1, -1, -1):
				var _e21 = _g27[i]
				var _q2 = _e21.get_string()
				var _q33 = _e21.get_start()
				var _x67 = _e21.get_end()
				line = line.substr(0, _q33) + "[color=#FF6B9D]" + _q2 + "[/color]" + line.substr(_x67)
		_p91[_f71] = line
	_s62 = "\n".join(_p91)
	var _h45 = RegEx.new()
	_h45.compile("\"[^\"]*\"")
	var _d39 = _h45.search_all(_s62)
	for i in range(_d39.size() - 1, -1, -1):
		var _e21 = _d39[i]
		var _q2 = _e21.get_string()
		var _q33 = _e21.get_start()
		var _x67 = _e21.get_end()
		if not _q2.contains("[color="):
			_s62 = _s62.substr(0, _q33) + "[color=#98FB98]" + _q2 + "[/color]" + _s62.substr(_x67)
	_p91 = _s62.split("\n")
	for i in range(_p91.size()):
		var line = _p91[i]
		var _m78 = line.find("#")
		if _m78 >= 0 and not line.substr(0, _m78).contains("[color="):
			var _t69 = line.substr(0, _m78)
			var _r66 = line.substr(_m78)
			if not _r66.contains("[color="):
				_p91[i] = _t69 + "[color=#87CEEB]" + _r66 + "[/color]"
	_s62 = "\n".join(_p91)
	return _s62
func _w56():
	if not _m6 or _k50.is_empty():
		return
	_m6._t8(_k50)
	_k58()
func _i54():
	if not _m6:
		return
	_m6._c91()
	_k58()
func _o58():
	hide()
func set_current_file(file_path: String):
	_k50 = file_path
	if is_inside_tree():
		_k95()
