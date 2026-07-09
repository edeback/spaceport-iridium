@tool
class_name _e42
extends AcceptDialog
signal _e17(_y92: _z98._c40)
@onready var _h17: TabContainer = %TabContainer
@onready var _y55: Label = %_y71
@onready var _l3: ItemList = %_j100
@onready var _q95: Label = %_k59
@onready var original_code: RichTextLabel = %_e19
@onready var refactored_code: RichTextLabel = %_n82
@onready var _b63: Label = %_w80
@onready var _k78: Tree = %_c7
@onready var _h98: Label = %_h4
@onready var _z3: RichTextLabel = %_j41
@onready var _v45: RichTextLabel = %_v34
@onready var _x18: Button = %_i46
@onready var _f43: Button = %_p39
@onready var _c95: Button = %_d41
var _q66: _z98
var _c53: String = ""
var _l41: Array[_z98._c40] = []
func _ready():
	if _l3:
		_l3.item_selected.connect(_l86)
	if _k78:
		_k78.item_selected.connect(_d58)
	if _x18:
		_x18.pressed.connect(_s24)
	if _f43:
		_f43.pressed.connect(_k1)
	if _c95:
		_c95.pressed.connect(_s13)
	set_flag(Window.FLAG_RESIZE_DISABLED, false)
	min_size = Vector2i(800, 600)
func _f28(_k10: _z98):
	_q66 = _k10
	_o82()
func _o67(file_path: String):
	_c53 = file_path
	if _h17:
		_h17.current_tab = 0  
	_o82()
	popup_centered()
func _r81():
	_c53 = ""
	if _h17:
		_h17.current_tab = 1  
	_o82()
	popup_centered()
func _o82():
	if not _q66:
		return
	_y11()
	_g37()
func _y11():
	if not _q66 or not _l3 or not _y55:
		return
	if _c53.is_empty():
		_y55.text = "No file selected"
		_l3.clear()
		_s96()
		return
	var _y38 = _c53.get_file()
	_y55.text = "File: %s" % _y38
	_l41 = _q66._z48(_c53)
	_l3.clear()
	for i in range(_l41.size()):
		var _y92 = _l41[i]
		var _z94 = "%s - %s" % [_y92.function_name, _y92._q22()]
		_l3.add_item(_z94)
		_l3.set_item_tooltip(i, _y92._i49(2))
	_s96()
func _g37():
	if not _q66 or not _k78 or not _b63:
		return
	var _l17 = _q66._c80()
	var _v90 = _q66._o10()
	var _x88 = _l17.size()
	_b63.text = "Total entries: %d across %d files" % [_v90, _x88]
	_k78.clear()
	var root = _k78.create_item()
	root.set_text(0, "Refactor History")
	for file_path in _l17.keys():
		var _n41: Array = _l17[file_path]
		var _u30 = root.create_child()
		var _y38 = file_path.get_file()
		_u30.set_text(0, "%s (%d)" % [_y38, _n41.size()])
		_u30.set_metadata(0, {"type": "file", "path": file_path})
		for _y92 in _n41:
			var _b96 = _u30.create_child()
			_b96.set_text(0, "%s - %s" % [_y92.function_name, _y92._q22()])
			_b96.set_metadata(0, {"type": "entry", "entry": _y92, "path": file_path})
	_c34()
func _l86(index: int):
	if index < 0 or index >= _l41.size():
		return
	var _y92 = _l41[index]
	_s15(_y92)
	_e17.emit(_y92)
func _d58():
	var selected = _k78.get_selected()
	if not selected:
		return
	var _w76 = selected.get_metadata(0)
	if not _w76 or not _w76.has("type"):
		return
	if _w76.type == "entry" and _w76.has("entry"):
		var _y92: _z98._c40 = _w76._y92
		_z29(_y92)
		_e17.emit(_y92)
	else:
		_c34()
func _s15(_y92: _z98._c40):
	if not _y92 or not _q95 or not original_code or not refactored_code:
		return
	_q95.text = "Function: %s() - %s" % [_y92.function_name, _y92._q22()]
	var _r67 = _q34(_y92.original_code)
	var _k31 = _q34(_y92.refactored_code)
	original_code.text = _r67
	refactored_code.text = _k31
func _z29(_y92: _z98._c40):
	if not _y92 or not _h98 or not _z3 or not _v45:
		return
	_h98.text = "Function: %s() - %s - %s" % [_y92.function_name, _y92.file_path.get_file(), _y92._q22()]
	var _r67 = _q34(_y92.original_code)
	var _k31 = _q34(_y92.refactored_code)
	_z3.text = _r67
	_v45.text = _k31
func _s96():
	if _q95:
		_q95.text = "Select an entry to preview"
	if original_code:
		original_code.text = "# Select an entry to view original code"
	if refactored_code:
		refactored_code.text = "# Select an entry to view refactored code"
func _c34():
	if _h98:
		_h98.text = "Select an entry to preview"
	if _z3:
		_z3.text = "# Select an entry to view original code"
	if _v45:
		_v45.text = "# Select an entry to view refactored code"
func _q34(code: String) -> String:
	var _h79 = code
	_h79 = _h79.replace("[", "\\[")
	_h79 = _h79.replace("]", "\\]")
	var _y4 = ["func", "var", "const", "if", "else", "elif", "for", "while", "match", "return", "break", "continue", "pass", "extends", "class_name", "signal", "enum", "@tool", "@export", "@onready"]
	var _t70 = _h79.split("\n")
	for _o69 in range(_t70.size()):
		var line = _t70[_o69]
		if "[color=" in line or line.strip_edges().begins_with("#"):
			continue
		for keyword in _y4:
			var _s76 = "\\b" + keyword + "\\b"
			var _r9 = RegEx.new()
			_r9.compile(_s76)
			var _a90 = _r9.search_all(line)
			for i in range(_a90.size() - 1, -1, -1):
				var _s61 = _a90[i]
				var _q44 = _s61.get_string()
				var _u98 = _s61.get_start()
				var _o6 = _s61.get_end()
				line = line.substr(0, _u98) + "[color=#FF6B9D]" + _q44 + "[/color]" + line.substr(_o6)
		_t70[_o69] = line
	_h79 = "\n".join(_t70)
	var _c51 = RegEx.new()
	_c51.compile("\"[^\"]*\"")
	var _v91 = _c51.search_all(_h79)
	for i in range(_v91.size() - 1, -1, -1):
		var _s61 = _v91[i]
		var _q44 = _s61.get_string()
		var _u98 = _s61.get_start()
		var _o6 = _s61.get_end()
		if not _q44.contains("[color="):
			_h79 = _h79.substr(0, _u98) + "[color=#98FB98]" + _q44 + "[/color]" + _h79.substr(_o6)
	_t70 = _h79.split("\n")
	for i in range(_t70.size()):
		var line = _t70[i]
		var _h23 = line.find("#")
		if _h23 >= 0 and not line.substr(0, _h23).contains("[color="):
			var _y15 = line.substr(0, _h23)
			var _y19 = line.substr(_h23)
			if not _y19.contains("[color="):
				_t70[i] = _y15 + "[color=#87CEEB]" + _y19 + "[/color]"
	_h79 = "\n".join(_t70)
	return _h79
func _s24():
	if not _q66 or _c53.is_empty():
		return
	_q66._m29(_c53)
	_o82()
func _k1():
	if not _q66:
		return
	_q66._k46()
	_o82()
func _s13():
	hide()
func set_current_file(file_path: String):
	_c53 = file_path
	if is_inside_tree():
		_y11()
