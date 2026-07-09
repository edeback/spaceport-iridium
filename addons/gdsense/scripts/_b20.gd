@tool
class_name _v18
extends AcceptDialog
signal _z93(_l70: String, function_name: String, _w94: String, model: String)
var _p91: String
var _a66: String
var _n3: String  
var _h80: TextEdit
var _z22: Button
var _b55: Button
var _s31: PanelContainer
var _u81: bool = false
var _n31: Timer
var _b77: Timer
var _a74: float = 0.0
var _z71: Label  
var _x47: OptionButton  
var _i24: Node = null  
var _x27: float = 1.0  
var _j26: Label
var _c94: Label
var _u70: Label
var _b63: Label
var _w52: Label
var _e83: Label
var _k98: Array = []
const _l74: Array = [
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
const _x6 = [
	"Improve readability - make the code clearer and more understandable",
	"Optimize performance - improve efficiency and speed",
	"Convert to Godot 4 idioms - use modern Godot 4 best practices",
	"Extract helper method - break down into smaller, reusable functions",
	"Replace if/else with match - use match statements where appropriate",
	"Add comments - include helpful documentation and explanations"
]
func _ready():
	get_ok_button().hide()
	if not confirmed.is_connected(_r45):
		confirmed.connect(_r45)
	_d45()
func _d45():
	if not is_inside_tree():
		return
	_h80 = find_child("_d41", true, false)
	_z22 = find_child("_b95", true, false)
	_b55 = find_child("_t98", true, false)
	_s31 = find_child("_s7", true, false)
	_z71 = find_child("_j45", true, false)
	_n31 = find_child("_i85", true, false)
	_b77 = find_child("_x71", true, false)
	_j26 = find_child("_q27", true, false)
	_c94 = find_child("_z7", true, false)
	_u70 = find_child("_c5", true, false)
	_b63 = find_child("_s3", true, false)
	_w52 = find_child("_z26", true, false)
	_e83 = find_child("_l14", true, false)
	_x47 = find_child("_n9", true, false)
	if _x47:
		_u7()
	else:
		pass
	_k98 = [
		find_child("_y82", true, false),
		find_child("_p71", true, false),
		find_child("_q13", true, false),
		find_child("_b67", true, false),
		find_child("_p74", true, false),
		find_child("_a86", true, false)
	]
	if _h80 and not _h80.text_changed.is_connected(_v81):
		_h80.text_changed.connect(_v81)
	if _z22 and not _z22.pressed.is_connected(_r45):
		_z22.pressed.connect(_r45)
	if _b55 and not _b55.pressed.is_connected(_a85):
		_b55.pressed.connect(_a85)
	if _n31 and not _n31.timeout.is_connected(_q29):
		_n31.timeout.connect(_q29)
	if _b77 and not _b77.timeout.is_connected(_i72):
		_b77.timeout.connect(_i72)
	_d28()
	for i in range(_k98.size()):
		var _j75 = _k98[i]
		if _j75 and not _j75.pressed.is_connected(_h7.bind(i)):
			_j75.pressed.connect(_h7.bind(i))
	_m61()
	_s95()
func _m61():
	var config = ConfigFile.new()
	var _n11: String = "auto"
	if config.load("user://gdsense_settings.cfg") == OK:
		_n11 = config.get_value("font_scale", "mode", "auto")
	if _n11 == "auto":
		_x27 = _j5()
	else:
		var _i8 = float(_n11)
		_i8 = clamp(_i8, 0.5, 3.0)
		if is_nan(_i8) or is_inf(_i8):
			_i8 = 1.0
		_x27 = _i8
func _j5() -> float:
	var _p37 = DisplayServer.screen_get_size()
	var height = int(_p37.y)
	if height >= 2160:  
		return 1.5
	elif height >= 1440:  
		return 1.25
	elif height >= 1080:  
		return 1.0
	else:  
		return 0.8
func _k37(_l67: int) -> int:
	var _e37 = int(_l67 * _x27)
	return max(_e37, 12)  
func _s95():
	if not is_inside_tree():
		return
	var _g18: int = 16
	var _j64: int = 18
	var _r100: int = 14
	var _a33: int = 16
	var _y31 = _k37(_g18)
	var _a49 = _k37(_j64)
	var _m68 = _k37(_r100)
	var _o29 = _k37(_a33)
	if _j26:
		_j26.add_theme_font_size_override("font_size", _a49)
	if _c94:
		_c94.add_theme_font_size_override("font_size", _y31)
	if _u70:
		_u70.add_theme_font_size_override("font_size", _y31)
	if _b63:
		_b63.add_theme_font_size_override("font_size", _y31)
	if _w52:
		_w52.add_theme_font_size_override("font_size", _m68)
	if _e83:
		_e83.add_theme_font_size_override("font_size", _y31)
	if _z71:
		_z71.add_theme_font_size_override("font_size", _m68)
	for _a13 in _k98:
		if _a13:
			_a13.add_theme_font_size_override("font_size", _o29)
	if _h80:
		_h80.add_theme_font_size_override("font_size", _y31)
	if _x47:
		_x47.add_theme_font_size_override("font_size", _y31)
	if _z22:
		_z22.add_theme_font_size_override("font_size", _o29)
	if _b55:
		_b55.add_theme_font_size_override("font_size", _o29)
func _o48(index: int) -> String:
	match index:
		0: return "• Improve readability"
		1: return "• Optimize performance"
		2: return "• Convert to Godot 4"
		3: return "• Extract helper method"
		4: return "• Replace if/else with match"
		5: return "• Add comments"
		_: return "• Unknown preset"
func _t47(function_name: String, _w94: String):
	_p91 = function_name
	_a66 = _w94
	_n3 = _w94  
	_u81 = false
	if _s31:
		_s31.visible = false
	if _z22:
		_z22.disabled = true
	if _b55:
		_b55.disabled = false
	if _h80:
		_h80.editable = true
	if is_instance_valid(_n31):
		_n31.stop()
	if is_instance_valid(_b77):
		_b77.stop()
	if _e83:
		_e83.text = "🔄 Processing refactor request..."
		_e83.remove_theme_color_override("font_color")  
	if _z71:
		_z71.text = "Elapsed time: 0.0s"
		_z71.visible = true
	if _j26:
		_j26.text = "Refactoring: %s" % function_name
	if _h80:
		_h80.text = ""
	_m88()
	if is_inside_tree():
		_m61()
		_s95()
		_d28()
		popup_centered()
		if _h80:
			_h80.grab_focus()
	else:
		_e10.call_deferred()
func _e1():
	_u81 = false
	if is_instance_valid(_n31):
		_n31.stop()
	if is_instance_valid(_b77):
		_b77.stop()
	_z75()
func _z75():
	if is_inside_tree():
		hide()
		var parent = get_parent()
		if parent:
			parent.remove_child.call_deferred(self)
func _q29():
	if not _u81:
		return
	if is_instance_valid(_b77):
		_b77.stop()
	if _e83:
		_e83.text = "⚠️ Request timed out. Please try again."
		var _b46 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
		_e83.add_theme_color_override("font_color", _b46)
	if is_instance_valid(_z71):
		_z71.visible = false
	await get_tree().create_timer(3.0).timeout
	if _u81:  
		_u81 = false
		if _s31:
			_s31.visible = false
		if _z22:
			_z22.disabled = false
		if _b55:
			_b55.disabled = false
		if _h80:
			_h80.editable = true
func _h7(_p28: int):
	if _p28 >= 0 and _p28 < _x6.size():
		if _h80:
			_h80.text = _x6[_p28]
		if _z22:
			_z22.disabled = false
		_m88()
		if _h80:
			if is_inside_tree():
				_h80.grab_focus()
			_h80.set_caret_line(_h80.get_line_count() - 1)
			_h80.set_caret_column(_h80.get_line(_h80.get_line_count() - 1).length())
func _v81():
	if not _h80:
		return
	var text = _h80.text.strip_edges()
	if _z22:
		_z22.disabled = text.is_empty()
	_m88()
func _e10():
	if is_inside_tree():
		_m61()
		_s95()
		_d28()
		popup_centered()
		if _h80:
			_h80.grab_focus()
func _m88():
	if _w52 and _h80:
		var _h86 = _h80.text.length()
		_w52.text = "%d/1000" % _h86
		if _h86 > 1000:
			var _b46 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
			_w52.add_theme_color_override("font_color", _b46)
		elif _h86 > 800:
			var _e49 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_w52.add_theme_color_override("font_color", _e49)
		else:
			_w52.remove_theme_color_override("font_color")  
func _r45():
	if not _h80:
		return
	var prompt = _h80.text.strip_edges()
	if prompt.is_empty() or _u81:
		return
	if prompt.length() > 1000:
		return
	_u81 = true
	_a74 = Time.get_ticks_msec() / 1000.0
	if _s31:
		_s31.visible = true
	if _z22:
		_z22.disabled = true
	if _b55:
		_b55.disabled = true
	if _h80:
		_h80.editable = false
	if is_instance_valid(_b77):
		_b77.start()
	else:
		pass
	if is_instance_valid(_n31):
		_n31.start()
	var _w63 = _r68()
	_z93.emit(prompt, _p91, _a66, _w63)
func _a85():
	if is_instance_valid(_n31):
		_n31.stop()
	if is_instance_valid(_b77):
		_b77.stop()
	_u81 = false
	hide()
func _i72():
	if not _u81:
		return
	var _j33 = Time.get_ticks_msec() / 1000.0
	var _j21 = _j33 - _a74
	if is_instance_valid(_z71):
		_z71.text = "Elapsed time: %.1fs" % _j21
	else:
		pass
func _n79() -> String:
	return _n3
func _x26() -> String:
	return _h80.text if _h80 else ""
func set_gdsense_manager(_d19: Node) -> void:
	_i24 = _d19
	if _i24:
		if not _i24._d6.is_connected(_q16):
			_i24._d6.connect(_q16)
		var _y8 = _i24._p94()
		if not _y8.is_empty() and _y8.has("tier"):
			_q16(_y8)
			return  
	_u7()
func _q16(_d15: Dictionary) -> void:
	_u7()
func _u7() -> void:
	if not _x47:
		return
	_x47.clear()
	var _o90: Array = []
	if _i24:
		_o90 = _i24._i20()
	if _o90.is_empty():
		_o90 = ["llama-3.1-8b-instant", "openai/gpt-oss-20b"]
	var _d7: int = 0
	for _c32 in _l74:
		var _t16: String = _c32[0]
		var _m86: String = _c32[1]
		if _t16 in _o90:
			_x47.add_item(_m86)
			_x47.set_item_metadata(_d7, _t16)
			_d7 += 1
	if _d7 == 0:
		_x47.add_item("Gemini Flash (Recommended)")
		_x47.set_item_metadata(0, "gemini-2.5-flash")
		_d7 = 1
	if _x47.item_count > 0:
		_x47.selected = 0
func _r68() -> String:
	if not _x47 or _x47.selected < 0:
		return "gemini-2.5-flash"  
	return _x47.get_item_metadata(_x47.selected)
func _d28():
	if not _s31:
		return
	var _i13 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _m32 = _i13.get_luminance() > 0.5
	var _w12 = StyleBoxFlat.new()
	_w12.bg_color = _i13.darkened(0.05) if _m32 else _i13.lightened(0.05)
	_w12.border_color = _i13.darkened(0.15) if _m32 else _i13.lightened(0.1)
	_w12.corner_radius_top_left = 4
	_w12.corner_radius_top_right = 4
	_w12.corner_radius_bottom_left = 4
	_w12.corner_radius_bottom_right = 4
	_w12.border_width_left = 1
	_w12.border_width_right = 1
	_w12.border_width_top = 1
	_w12.border_width_bottom = 1
	_s31.add_theme_stylebox_override("panel", _w12)
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _e83:
		_e83.add_theme_color_override("font_color", font_color)
	if _z71:
		_z71.add_theme_color_override("font_color", font_color)
