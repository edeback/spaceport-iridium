@tool
class_name _c47
extends AcceptDialog
signal _t63(_v36: String, function_name: String, _j46: String, model: String)
var _g66: String
var _n7: String
var _r16: String  
var _h52: TextEdit
var _u45: Button
var _d8: Button
var _f30: PanelContainer
var _l28: bool = false
var _q82: Timer
var _n99: Timer
var _u79: float = 0.0
var _l29: Label  
var _u59: OptionButton  
var _r78: Node = null  
var _t35: float = 1.0  
var _j30: Label
var _t46: Label
var _d52: Label
var _c25: Label
var _g74: Label
var _h30: Label
var _g96: Array = []
const _e91: Array = [
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
const _m2 = [
	"Improve readability - make the code clearer and more understandable",
	"Optimize performance - improve efficiency and speed",
	"Convert to Godot 4 idioms - use modern Godot 4 best practices",
	"Extract helper method - break down into smaller, reusable functions",
	"Replace if/else with match - use match statements where appropriate",
	"Add comments - include helpful documentation and explanations"
]
func _ready():
	get_ok_button().hide()
	if not confirmed.is_connected(_h7):
		confirmed.connect(_h7)
	_b18()
func _b18():
	if not is_inside_tree():
		return
	_h52 = find_child("_q62", true, false)
	_u45 = find_child("_r22", true, false)
	_d8 = find_child("_g71", true, false)
	_f30 = find_child("_j73", true, false)
	_l29 = find_child("_b86", true, false)
	_q82 = find_child("_l69", true, false)
	_n99 = find_child("_t57", true, false)
	_j30 = find_child("_p51", true, false)
	_t46 = find_child("_g72", true, false)
	_d52 = find_child("_c18", true, false)
	_c25 = find_child("_l48", true, false)
	_g74 = find_child("_p98", true, false)
	_h30 = find_child("_b7", true, false)
	_u59 = find_child("_a68", true, false)
	if _u59:
		_b38()
	else:
		pass
	_g96 = [
		find_child("_j89", true, false),
		find_child("_t90", true, false),
		find_child("_c71", true, false),
		find_child("_j54", true, false),
		find_child("_k22", true, false),
		find_child("_s66", true, false)
	]
	if _h52 and not _h52.text_changed.is_connected(_a9):
		_h52.text_changed.connect(_a9)
	if _u45 and not _u45.pressed.is_connected(_h7):
		_u45.pressed.connect(_h7)
	if _d8 and not _d8.pressed.is_connected(_b50):
		_d8.pressed.connect(_b50)
	if _q82 and not _q82.timeout.is_connected(_q52):
		_q82.timeout.connect(_q52)
	if _n99 and not _n99.timeout.is_connected(_c69):
		_n99.timeout.connect(_c69)
	_l4()
	for i in range(_g96.size()):
		var _l100 = _g96[i]
		if _l100 and not _l100.pressed.is_connected(_z59.bind(i)):
			_l100.pressed.connect(_z59.bind(i))
	_x71()
	_u10()
func _x71():
	var config = ConfigFile.new()
	var _h68: String = "auto"
	if config.load("user://gdsense_settings.cfg") == OK:
		_h68 = config.get_value("font_scale", "mode", "auto")
	if _h68 == "auto":
		_t35 = _e87()
	else:
		var _z55 = float(_h68)
		_z55 = clamp(_z55, 0.5, 3.0)
		if is_nan(_z55) or is_inf(_z55):
			_z55 = 1.0
		_t35 = _z55
func _e87() -> float:
	var _g26 = DisplayServer.screen_get_size()
	var height = int(_g26.y)
	if height >= 2160:  
		return 1.5
	elif height >= 1440:  
		return 1.25
	elif height >= 1080:  
		return 1.0
	else:  
		return 0.8
func _e84(_u5: int) -> int:
	var _d95 = int(_u5 * _t35)
	return max(_d95, 12)  
func _u10():
	if not is_inside_tree():
		return
	var _x86: int = 16
	var _v61: int = 18
	var _o44: int = 14
	var _u32: int = 16
	var _c72 = _e84(_x86)
	var _s87 = _e84(_v61)
	var _t50 = _e84(_o44)
	var _s55 = _e84(_u32)
	if _j30:
		_j30.add_theme_font_size_override("font_size", _s87)
	if _t46:
		_t46.add_theme_font_size_override("font_size", _c72)
	if _d52:
		_d52.add_theme_font_size_override("font_size", _c72)
	if _c25:
		_c25.add_theme_font_size_override("font_size", _c72)
	if _g74:
		_g74.add_theme_font_size_override("font_size", _t50)
	if _h30:
		_h30.add_theme_font_size_override("font_size", _c72)
	if _l29:
		_l29.add_theme_font_size_override("font_size", _t50)
	for _v59 in _g96:
		if _v59:
			_v59.add_theme_font_size_override("font_size", _s55)
	if _h52:
		_h52.add_theme_font_size_override("font_size", _c72)
	if _u59:
		_u59.add_theme_font_size_override("font_size", _c72)
	if _u45:
		_u45.add_theme_font_size_override("font_size", _s55)
	if _d8:
		_d8.add_theme_font_size_override("font_size", _s55)
func _d70(index: int) -> String:
	match index:
		0: return "• Improve readability"
		1: return "• Optimize performance"
		2: return "• Convert to Godot 4"
		3: return "• Extract helper method"
		4: return "• Replace if/else with match"
		5: return "• Add comments"
		_: return "• Unknown preset"
func _c20(function_name: String, _j46: String):
	_g66 = function_name
	_n7 = _j46
	_r16 = _j46  
	_l28 = false
	if _f30:
		_f30.visible = false
	if _u45:
		_u45.disabled = true
	if _d8:
		_d8.disabled = false
	if _h52:
		_h52.editable = true
	if is_instance_valid(_q82):
		_q82.stop()
	if is_instance_valid(_n99):
		_n99.stop()
	if _h30:
		_h30.text = "🔄 Processing refactor request..."
		_h30.remove_theme_color_override("font_color")  
	if _l29:
		_l29.text = "Elapsed time: 0.0s"
		_l29.visible = true
	if _j30:
		_j30.text = "Refactoring: %s" % function_name
	if _h52:
		_h52.text = ""
	_r15()
	if is_inside_tree():
		_x71()
		_u10()
		_l4()
		popup_centered()
		if _h52:
			_h52.grab_focus()
	else:
		_p11.call_deferred()
func _b22():
	_l28 = false
	if is_instance_valid(_q82):
		_q82.stop()
	if is_instance_valid(_n99):
		_n99.stop()
	_o13()
func _o13():
	if is_inside_tree():
		hide()
		var parent = get_parent()
		if parent:
			parent.remove_child.call_deferred(self)
func _q52():
	if not _l28:
		return
	if is_instance_valid(_n99):
		_n99.stop()
	if _h30:
		_h30.text = "⚠️ Request timed out. Please try again."
		var _t32 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
		_h30.add_theme_color_override("font_color", _t32)
	if is_instance_valid(_l29):
		_l29.visible = false
	await get_tree().create_timer(3.0).timeout
	if _l28:  
		_l28 = false
		if _f30:
			_f30.visible = false
		if _u45:
			_u45.disabled = false
		if _d8:
			_d8.disabled = false
		if _h52:
			_h52.editable = true
func _z59(_i50: int):
	if _i50 >= 0 and _i50 < _m2.size():
		if _h52:
			_h52.text = _m2[_i50]
		if _u45:
			_u45.disabled = false
		_r15()
		if _h52:
			if is_inside_tree():
				_h52.grab_focus()
			_h52.set_caret_line(_h52.get_line_count() - 1)
			_h52.set_caret_column(_h52.get_line(_h52.get_line_count() - 1).length())
func _a9():
	if not _h52:
		return
	var text = _h52.text.strip_edges()
	if _u45:
		_u45.disabled = text.is_empty()
	_r15()
func _p11():
	if is_inside_tree():
		_x71()
		_u10()
		_l4()
		popup_centered()
		if _h52:
			_h52.grab_focus()
func _r15():
	if _g74 and _h52:
		var _g25 = _h52.text.length()
		_g74.text = "%d/1000" % _g25
		if _g25 > 1000:
			var _t32 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
			_g74.add_theme_color_override("font_color", _t32)
		elif _g25 > 800:
			var _z36 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_g74.add_theme_color_override("font_color", _z36)
		else:
			_g74.remove_theme_color_override("font_color")  
func _h7():
	if not _h52:
		return
	var prompt = _h52.text.strip_edges()
	if prompt.is_empty() or _l28:
		return
	if prompt.length() > 1000:
		return
	_l28 = true
	_u79 = Time.get_ticks_msec() / 1000.0
	if _f30:
		_f30.visible = true
	if _u45:
		_u45.disabled = true
	if _d8:
		_d8.disabled = true
	if _h52:
		_h52.editable = false
	if is_instance_valid(_n99):
		_n99.start()
	else:
		pass
	if is_instance_valid(_q82):
		_q82.start()
	var _h29 = _s35()
	_t63.emit(prompt, _g66, _n7, _h29)
func _b50():
	if is_instance_valid(_q82):
		_q82.stop()
	if is_instance_valid(_n99):
		_n99.stop()
	_l28 = false
	hide()
func _c69():
	if not _l28:
		return
	var _n75 = Time.get_ticks_msec() / 1000.0
	var _j48 = _n75 - _u79
	if is_instance_valid(_l29):
		_l29.text = "Elapsed time: %.1fs" % _j48
	else:
		pass
func _e95() -> String:
	return _r16
func _b11() -> String:
	return _h52.text if _h52 else ""
func set_gdsense_manager(_a82: Node) -> void:
	_r78 = _a82
	if _r78:
		if not _r78._n20.is_connected(_z46):
			_r78._n20.connect(_z46)
		var _z95 = _r78._f61()
		if not _z95.is_empty() and _z95.has("tier"):
			_z46(_z95)
			return  
	_b38()
func _z46(_k18: Dictionary) -> void:
	_b38()
func _b38() -> void:
	if not _u59:
		return
	_u59.clear()
	var _d34: Array = []
	if _r78:
		_d34 = _r78._w81()
	if _d34.is_empty():
		_d34 = ["llama-3.1-8b-instant", "openai/gpt-oss-20b"]
	var _f22: int = 0
	for _r44 in _e91:
		var _l33: String = _r44[0]
		var _p87: String = _r44[1]
		if _l33 in _d34:
			_u59.add_item(_p87)
			_u59.set_item_metadata(_f22, _l33)
			_f22 += 1
	if _f22 == 0:
		_u59.add_item("Gemini Flash (Recommended)")
		_u59.set_item_metadata(0, "gemini-2.5-flash")
		_f22 = 1
	if _u59.item_count > 0:
		_u59.selected = 0
func _s35() -> String:
	if not _u59 or _u59.selected < 0:
		return "gemini-2.5-flash"  
	return _u59.get_item_metadata(_u59.selected)
func _l4():
	if not _f30:
		return
	var _f9 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _b35 = _f9.get_luminance() > 0.5
	var _w78 = StyleBoxFlat.new()
	_w78.bg_color = _f9.darkened(0.05) if _b35 else _f9.lightened(0.05)
	_w78.border_color = _f9.darkened(0.15) if _b35 else _f9.lightened(0.1)
	_w78.corner_radius_top_left = 4
	_w78.corner_radius_top_right = 4
	_w78.corner_radius_bottom_left = 4
	_w78.corner_radius_bottom_right = 4
	_w78.border_width_left = 1
	_w78.border_width_right = 1
	_w78.border_width_top = 1
	_w78.border_width_bottom = 1
	_f30.add_theme_stylebox_override("panel", _w78)
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _h30:
		_h30.add_theme_color_override("font_color", font_color)
	if _l29:
		_l29.add_theme_color_override("font_color", font_color)
