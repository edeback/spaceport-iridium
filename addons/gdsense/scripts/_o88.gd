@tool
class_name _s4
extends AcceptDialog
signal _e86(_r2: String, function_name: String, _k94: String, model: String)
var _j57: String
var _z94: String
var _c96: String  
var _z58: TextEdit
var _n67: Button
var _b40: Button
var _i34: PanelContainer
var _i60: bool = false
var _h56: Timer
var _t24: Timer
var _i57: float = 0.0
var _j37: Label  
var _h85: OptionButton  
var _x34: Node = null  
var _v32: float = 1.0  
var _p57: Label
var _b93: Label
var _n3: Label
var _f52: Label
var _p29: Label
var _i66: Label
var _i72: Array = []
const _e14: Array = [
	["openai/gpt-oss-20b", "GPT OSS-20B (0.5x)"],
	["llama-3.1-8b-instant", "Llama 3.1 8B (0.5x)"],
	["gpt-5-nano", "GPT-5 Nano (0.75x)"],
	["gemini-2.5-flash-lite", "Flash-Lite (0.75x)"],
	["gemini-2.5-flash", "Gemini Flash (2.5x)"],
	["gpt-5.1-codex-mini", "GPT-5.1 Codex Mini (2.5x)"],
	["moonshotai/kimi-k2-instruct-0905", "Kimi K2 (5x)"],
	["gemini-3-flash-preview", "Gemini 3 Flash (5x)"],
	["gemini-2.5-pro", "Gemini Pro (10x)"],
	["gpt-5.1-codex", "GPT-5.1 Codex (10x)"],
	["gemini-3-pro-preview", "Gemini 3 Pro (12x)"]
]
const _h11 = [
	"Improve readability - make the code clearer and more understandable",
	"Optimize performance - improve efficiency and speed",
	"Convert to Godot 4 idioms - use modern Godot 4 best practices",
	"Extract helper method - break down into smaller, reusable functions",
	"Replace if/else with match - use match statements where appropriate",
	"Add comments - include helpful documentation and explanations"
]
func _ready():
	get_ok_button().hide()
	if not confirmed.is_connected(_v2):
		confirmed.connect(_v2)
	_x75()
func _x75():
	if not is_inside_tree():
		return
	_z58 = find_child("_w39", true, false)
	_n67 = find_child("_m47", true, false)
	_b40 = find_child("_t20", true, false)
	_i34 = find_child("_l79", true, false)
	_j37 = find_child("_o12", true, false)
	_h56 = find_child("_q6", true, false)
	_t24 = find_child("_z16", true, false)
	_p57 = find_child("_o26", true, false)
	_b93 = find_child("_u97", true, false)
	_n3 = find_child("_h69", true, false)
	_f52 = find_child("_q29", true, false)
	_p29 = find_child("_l82", true, false)
	_i66 = find_child("_z30", true, false)
	_h85 = find_child("_p76", true, false)
	if _h85:
		_t29()
	else:
		pass
	_i72 = [
		find_child("_v39", true, false),
		find_child("_j62", true, false),
		find_child("_q35", true, false),
		find_child("_e7", true, false),
		find_child("_p96", true, false),
		find_child("_r24", true, false)
	]
	if _z58 and not _z58.text_changed.is_connected(_g97):
		_z58.text_changed.connect(_g97)
	if _n67 and not _n67.pressed.is_connected(_v2):
		_n67.pressed.connect(_v2)
	if _b40 and not _b40.pressed.is_connected(_v71):
		_b40.pressed.connect(_v71)
	if _h56 and not _h56.timeout.is_connected(_l11):
		_h56.timeout.connect(_l11)
	if _t24 and not _t24.timeout.is_connected(_q70):
		_t24.timeout.connect(_q70)
	_q57()
	for i in range(_i72.size()):
		var _d75 = _i72[i]
		if _d75 and not _d75.pressed.is_connected(_q74.bind(i)):
			_d75.pressed.connect(_q74.bind(i))
	_v11()
	_n63()
func _v11():
	var config = ConfigFile.new()
	var _k30: String = "auto"
	if config.load("user://gdsense_settings.cfg") == OK:
		_k30 = config.get_value("font_scale", "mode", "auto")
	if _k30 == "auto":
		_v32 = _k44()
	else:
		var _n89 = float(_k30)
		_n89 = clamp(_n89, 0.5, 3.0)
		if is_nan(_n89) or is_inf(_n89):
			_n89 = 1.0
		_v32 = _n89
func _k44() -> float:
	var _k38 = DisplayServer.screen_get_size()
	var height = int(_k38.y)
	if height >= 2160:  
		return 1.5
	elif height >= 1440:  
		return 1.25
	elif height >= 1080:  
		return 1.0
	else:  
		return 0.8
func _d43(_g7: int) -> int:
	var _m40 = int(_g7 * _v32)
	return max(_m40, 12)  
func _n63():
	if not is_inside_tree():
		return
	var _i32: int = 16
	var _x27: int = 18
	var _b54: int = 14
	var _h1: int = 16
	var _l38 = _d43(_i32)
	var _e42 = _d43(_x27)
	var _r19 = _d43(_b54)
	var _b49 = _d43(_h1)
	if _p57:
		_p57.add_theme_font_size_override("font_size", _e42)
	if _b93:
		_b93.add_theme_font_size_override("font_size", _l38)
	if _n3:
		_n3.add_theme_font_size_override("font_size", _l38)
	if _f52:
		_f52.add_theme_font_size_override("font_size", _l38)
	if _p29:
		_p29.add_theme_font_size_override("font_size", _r19)
	if _i66:
		_i66.add_theme_font_size_override("font_size", _l38)
	if _j37:
		_j37.add_theme_font_size_override("font_size", _r19)
	for _t68 in _i72:
		if _t68:
			_t68.add_theme_font_size_override("font_size", _b49)
	if _z58:
		_z58.add_theme_font_size_override("font_size", _l38)
	if _h85:
		_h85.add_theme_font_size_override("font_size", _l38)
	if _n67:
		_n67.add_theme_font_size_override("font_size", _b49)
	if _b40:
		_b40.add_theme_font_size_override("font_size", _b49)
func _d71(index: int) -> String:
	match index:
		0: return "• Improve readability"
		1: return "• Optimize performance"
		2: return "• Convert to Godot 4"
		3: return "• Extract helper method"
		4: return "• Replace if/else with match"
		5: return "• Add comments"
		_: return "• Unknown preset"
func _o33(function_name: String, _k94: String):
	_j57 = function_name
	_z94 = _k94
	_c96 = _k94  
	_i60 = false
	if _i34:
		_i34.visible = false
	if _n67:
		_n67.disabled = true
	if _b40:
		_b40.disabled = false
	if _z58:
		_z58.editable = true
	if is_instance_valid(_h56):
		_h56.stop()
	if is_instance_valid(_t24):
		_t24.stop()
	if _i66:
		_i66.text = "🔄 Processing refactor request..."
		_i66.remove_theme_color_override("font_color")  
	if _j37:
		_j37.text = "Elapsed time: 0.0s"
		_j37.visible = true
	if _p57:
		_p57.text = "Refactoring: %s" % function_name
	if _z58:
		_z58.text = ""
	_q40()
	if is_inside_tree():
		_v11()
		_n63()
		_q57()
		popup_centered()
		if _z58:
			_z58.grab_focus()
	else:
		_c13.call_deferred()
func _b94():
	_i60 = false
	if is_instance_valid(_h56):
		_h56.stop()
	if is_instance_valid(_t24):
		_t24.stop()
	_i4()
func _i4():
	if is_inside_tree():
		hide()
		var parent = get_parent()
		if parent:
			parent.remove_child.call_deferred(self)
func _l11():
	if not _i60:
		return
	if is_instance_valid(_t24):
		_t24.stop()
	if _i66:
		_i66.text = "⚠️ Request timed out. Please try again."
		var _f41 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
		_i66.add_theme_color_override("font_color", _f41)
	if is_instance_valid(_j37):
		_j37.visible = false
	await get_tree().create_timer(3.0).timeout
	if _i60:  
		_i60 = false
		if _i34:
			_i34.visible = false
		if _n67:
			_n67.disabled = false
		if _b40:
			_b40.disabled = false
		if _z58:
			_z58.editable = true
func _q74(_a62: int):
	if _a62 >= 0 and _a62 < _h11.size():
		if _z58:
			_z58.text = _h11[_a62]
		if _n67:
			_n67.disabled = false
		_q40()
		if _z58:
			if is_inside_tree():
				_z58.grab_focus()
			_z58.set_caret_line(_z58.get_line_count() - 1)
			_z58.set_caret_column(_z58.get_line(_z58.get_line_count() - 1).length())
func _g97():
	if not _z58:
		return
	var text = _z58.text.strip_edges()
	if _n67:
		_n67.disabled = text.is_empty()
	_q40()
func _c13():
	if is_inside_tree():
		_v11()
		_n63()
		_q57()
		popup_centered()
		if _z58:
			_z58.grab_focus()
func _q40():
	if _p29 and _z58:
		var _d5 = _z58.text.length()
		_p29.text = "%d/1000" % _d5
		if _d5 > 1000:
			var _f41 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
			_p29.add_theme_color_override("font_color", _f41)
		elif _d5 > 800:
			var _r91 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_p29.add_theme_color_override("font_color", _r91)
		else:
			_p29.remove_theme_color_override("font_color")  
func _v2():
	if not _z58:
		return
	var prompt = _z58.text.strip_edges()
	if prompt.is_empty() or _i60:
		return
	if prompt.length() > 1000:
		return
	_i60 = true
	_i57 = Time.get_ticks_msec() / 1000.0
	if _i34:
		_i34.visible = true
	if _n67:
		_n67.disabled = true
	if _b40:
		_b40.disabled = true
	if _z58:
		_z58.editable = false
	if is_instance_valid(_t24):
		_t24.start()
	else:
		pass
	if is_instance_valid(_h56):
		_h56.start()
	var _n20 = _i77()
	_e86.emit(prompt, _j57, _z94, _n20)
func _v71():
	if is_instance_valid(_h56):
		_h56.stop()
	if is_instance_valid(_t24):
		_t24.stop()
	_i60 = false
	hide()
func _q70():
	if not _i60:
		return
	var _s36 = Time.get_ticks_msec() / 1000.0
	var _r45 = _s36 - _i57
	if is_instance_valid(_j37):
		_j37.text = "Elapsed time: %.1fs" % _r45
	else:
		pass
func _k78() -> String:
	return _c96
func _y68() -> String:
	return _z58.text if _z58 else ""
func set_gdsense_manager(_v55: Node) -> void:
	_x34 = _v55
	if _x34:
		if not _x34._d99.is_connected(_n52):
			_x34._d99.connect(_n52)
		var _j27 = _x34._m90()
		if not _j27.is_empty() and _j27.has("tier"):
			_n52(_j27)
			return  
	_t29()
func _n52(_k89: Dictionary) -> void:
	_t29()
func _t29() -> void:
	if not _h85:
		return
	_h85.clear()
	var _x88: Array = []
	if _x34:
		_x88 = _x34._k12()
	if _x88.is_empty():
		_x88 = ["llama-3.1-8b-instant", "openai/gpt-oss-20b"]
	var _b9: int = 0
	for _c33 in _e14:
		var _i21: String = _c33[0]
		var _r69: String = _c33[1]
		if _i21 in _x88:
			_h85.add_item(_r69)
			_h85.set_item_metadata(_b9, _i21)
			_b9 += 1
	if _b9 == 0:
		_h85.add_item("Gemini Flash (Recommended)")
		_h85.set_item_metadata(0, "gemini-2.5-flash")
		_b9 = 1
	if _h85.item_count > 0:
		_h85.selected = 0
func _i77() -> String:
	if not _h85 or _h85.selected < 0:
		return "gemini-2.5-flash"  
	return _h85.get_item_metadata(_h85.selected)
func _q57():
	if not _i34:
		return
	var _v22 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _b21 = _v22.get_luminance() > 0.5
	var _e79 = StyleBoxFlat.new()
	_e79.bg_color = _v22.darkened(0.05) if _b21 else _v22.lightened(0.05)
	_e79.border_color = _v22.darkened(0.15) if _b21 else _v22.lightened(0.1)
	_e79.corner_radius_top_left = 4
	_e79.corner_radius_top_right = 4
	_e79.corner_radius_bottom_left = 4
	_e79.corner_radius_bottom_right = 4
	_e79.border_width_left = 1
	_e79.border_width_right = 1
	_e79.border_width_top = 1
	_e79.border_width_bottom = 1
	_i34.add_theme_stylebox_override("panel", _e79)
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _i66:
		_i66.add_theme_color_override("font_color", font_color)
	if _j37:
		_j37.add_theme_color_override("font_color", font_color)
