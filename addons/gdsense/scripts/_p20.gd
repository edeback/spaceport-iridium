@tool
class_name _y96
extends AcceptDialog
signal _u37(_o38: String, function_name: String, _w13: String, model: String)
var _j78: String
var _q74: String
var _x70: String  
var _v48: TextEdit
var _r6: Button
var _u99: Button
var _x52: PanelContainer
var _b100: bool = false
var _y50: Timer
var _j53: Timer
var _g81: float = 0.0
var _f67: Label  
var _x83: OptionButton  
var _k26: Node = null  
var _p78: float = 1.0  
var _s46: Label
var _s60: Label
var _n33: Label
var _q24: Label
var _m54: Label
var _w22: Label
var _l20: Array = []
const _d4: Array = [
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
const _b38 = [
	"Improve readability - make the code clearer and more understandable",
	"Optimize performance - improve efficiency and speed",
	"Convert to Godot 4 idioms - use modern Godot 4 best practices",
	"Extract helper method - break down into smaller, reusable functions",
	"Replace if/else with match - use match statements where appropriate",
	"Add comments - include helpful documentation and explanations"
]
func _ready():
	get_ok_button().hide()
	if not confirmed.is_connected(_v53):
		confirmed.connect(_v53)
	_y66()
func _y66():
	if not is_inside_tree():
		return
	_v48 = find_child("_b41", true, false)
	_r6 = find_child("_z71", true, false)
	_u99 = find_child("_m44", true, false)
	_x52 = find_child("_o79", true, false)
	_f67 = find_child("_z74", true, false)
	_y50 = find_child("_r17", true, false)
	_j53 = find_child("_r72", true, false)
	_s46 = find_child("_m30", true, false)
	_s60 = find_child("_w14", true, false)
	_n33 = find_child("_v44", true, false)
	_q24 = find_child("_e36", true, false)
	_m54 = find_child("_z53", true, false)
	_w22 = find_child("_y18", true, false)
	_x83 = find_child("_i26", true, false)
	if _x83:
		_h77()
	else:
		pass
	_l20 = [
		find_child("_j92", true, false),
		find_child("_l14", true, false),
		find_child("_g89", true, false),
		find_child("_x66", true, false),
		find_child("_c82", true, false),
		find_child("_v34", true, false)
	]
	if _v48 and not _v48.text_changed.is_connected(_a27):
		_v48.text_changed.connect(_a27)
	if _r6 and not _r6.pressed.is_connected(_v53):
		_r6.pressed.connect(_v53)
	if _u99 and not _u99.pressed.is_connected(_m8):
		_u99.pressed.connect(_m8)
	if _y50 and not _y50.timeout.is_connected(_x25):
		_y50.timeout.connect(_x25)
	if _j53 and not _j53.timeout.is_connected(_c69):
		_j53.timeout.connect(_c69)
	_s62()
	for i in range(_l20.size()):
		var _x2 = _l20[i]
		if _x2 and not _x2.pressed.is_connected(_n4.bind(i)):
			_x2.pressed.connect(_n4.bind(i))
	_m70()
	_p99()
func _m70():
	var config = ConfigFile.new()
	var _t4: String = "auto"
	if config.load("user://gdsense_settings.cfg") == OK:
		_t4 = config.get_value("font_scale", "mode", "auto")
	if _t4 == "auto":
		_p78 = _s27()
	else:
		var _g94 = float(_t4)
		_g94 = clamp(_g94, 0.5, 3.0)
		if is_nan(_g94) or is_inf(_g94):
			_g94 = 1.0
		_p78 = _g94
func _s27() -> float:
	var _e95 = DisplayServer.screen_get_size()
	var height = int(_e95.y)
	if height >= 2160:  
		return 1.5
	elif height >= 1440:  
		return 1.25
	elif height >= 1080:  
		return 1.0
	else:  
		return 0.8
func _m34(_e58: int) -> int:
	var _b16 = int(_e58 * _p78)
	return max(_b16, 12)  
func _p99():
	if not is_inside_tree():
		return
	var _e71: int = 16
	var _f24: int = 18
	var _x51: int = 14
	var _d10: int = 16
	var _g3 = _m34(_e71)
	var _v41 = _m34(_f24)
	var _z51 = _m34(_x51)
	var _d12 = _m34(_d10)
	if _s46:
		_s46.add_theme_font_size_override("font_size", _v41)
	if _s60:
		_s60.add_theme_font_size_override("font_size", _g3)
	if _n33:
		_n33.add_theme_font_size_override("font_size", _g3)
	if _q24:
		_q24.add_theme_font_size_override("font_size", _g3)
	if _m54:
		_m54.add_theme_font_size_override("font_size", _z51)
	if _w22:
		_w22.add_theme_font_size_override("font_size", _g3)
	if _f67:
		_f67.add_theme_font_size_override("font_size", _z51)
	for _x27 in _l20:
		if _x27:
			_x27.add_theme_font_size_override("font_size", _d12)
	if _v48:
		_v48.add_theme_font_size_override("font_size", _g3)
	if _x83:
		_x83.add_theme_font_size_override("font_size", _g3)
	if _r6:
		_r6.add_theme_font_size_override("font_size", _d12)
	if _u99:
		_u99.add_theme_font_size_override("font_size", _d12)
func _z83(index: int) -> String:
	match index:
		0: return "• Improve readability"
		1: return "• Optimize performance"
		2: return "• Convert to Godot 4"
		3: return "• Extract helper method"
		4: return "• Replace if/else with match"
		5: return "• Add comments"
		_: return "• Unknown preset"
func _s56(function_name: String, _w13: String):
	_j78 = function_name
	_q74 = _w13
	_x70 = _w13  
	_b100 = false
	if _x52:
		_x52.visible = false
	if _r6:
		_r6.disabled = true
	if _u99:
		_u99.disabled = false
	if _v48:
		_v48.editable = true
	if is_instance_valid(_y50):
		_y50.stop()
	if is_instance_valid(_j53):
		_j53.stop()
	if _w22:
		_w22.text = "🔄 Processing refactor request..."
		_w22.remove_theme_color_override("font_color")  
	if _f67:
		_f67.text = "Elapsed time: 0.0s"
		_f67.visible = true
	if _s46:
		_s46.text = "Refactoring: %s" % function_name
	if _v48:
		_v48.text = ""
	_z17()
	if is_inside_tree():
		_m70()
		_p99()
		_s62()
		popup_centered()
		if _v48:
			_v48.grab_focus()
	else:
		_k1.call_deferred()
func _f91():
	_b100 = false
	if is_instance_valid(_y50):
		_y50.stop()
	if is_instance_valid(_j53):
		_j53.stop()
	_c96()
func _c96():
	if is_inside_tree():
		hide()
		var parent = get_parent()
		if parent:
			parent.remove_child.call_deferred(self)
func _x25():
	if not _b100:
		return
	if is_instance_valid(_j53):
		_j53.stop()
	if _w22:
		_w22.text = "⚠️ Request timed out. Please try again."
		var _r42 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
		_w22.add_theme_color_override("font_color", _r42)
	if is_instance_valid(_f67):
		_f67.visible = false
	await get_tree().create_timer(3.0).timeout
	if _b100:  
		_b100 = false
		if _x52:
			_x52.visible = false
		if _r6:
			_r6.disabled = false
		if _u99:
			_u99.disabled = false
		if _v48:
			_v48.editable = true
func _n4(_j30: int):
	if _j30 >= 0 and _j30 < _b38.size():
		if _v48:
			_v48.text = _b38[_j30]
		if _r6:
			_r6.disabled = false
		_z17()
		if _v48:
			if is_inside_tree():
				_v48.grab_focus()
			_v48.set_caret_line(_v48.get_line_count() - 1)
			_v48.set_caret_column(_v48.get_line(_v48.get_line_count() - 1).length())
func _a27():
	if not _v48:
		return
	var text = _v48.text.strip_edges()
	if _r6:
		_r6.disabled = text.is_empty()
	_z17()
func _k1():
	if is_inside_tree():
		_m70()
		_p99()
		_s62()
		popup_centered()
		if _v48:
			_v48.grab_focus()
func _z17():
	if _m54 and _v48:
		var _g13 = _v48.text.length()
		_m54.text = "%d/1000" % _g13
		if _g13 > 1000:
			var _r42 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
			_m54.add_theme_color_override("font_color", _r42)
		elif _g13 > 800:
			var _x44 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_m54.add_theme_color_override("font_color", _x44)
		else:
			_m54.remove_theme_color_override("font_color")  
func _v53():
	if not _v48:
		return
	var prompt = _v48.text.strip_edges()
	if prompt.is_empty() or _b100:
		return
	if prompt.length() > 1000:
		return
	_b100 = true
	_g81 = Time.get_ticks_msec() / 1000.0
	if _x52:
		_x52.visible = true
	if _r6:
		_r6.disabled = true
	if _u99:
		_u99.disabled = true
	if _v48:
		_v48.editable = false
	if is_instance_valid(_j53):
		_j53.start()
	else:
		pass
	if is_instance_valid(_y50):
		_y50.start()
	var _h82 = _v19()
	_u37.emit(prompt, _j78, _q74, _h82)
func _m8():
	if is_instance_valid(_y50):
		_y50.stop()
	if is_instance_valid(_j53):
		_j53.stop()
	_b100 = false
	hide()
func _c69():
	if not _b100:
		return
	var _v50 = Time.get_ticks_msec() / 1000.0
	var _s6 = _v50 - _g81
	if is_instance_valid(_f67):
		_f67.text = "Elapsed time: %.1fs" % _s6
	else:
		pass
func _p77() -> String:
	return _x70
func _d54() -> String:
	return _v48.text if _v48 else ""
func set_gdsense_manager(_b44: Node) -> void:
	_k26 = _b44
	if _k26:
		if not _k26._a7.is_connected(_h97):
			_k26._a7.connect(_h97)
		var _g30 = _k26._y64()
		if not _g30.is_empty() and _g30.has("tier"):
			_h97(_g30)
			return  
	_h77()
func _h97(_a88: Dictionary) -> void:
	_h77()
func _h77() -> void:
	if not _x83:
		return
	_x83.clear()
	var _w25: Array = []
	if _k26:
		_w25 = _k26._h58()
	if _w25.is_empty():
		_w25 = ["llama-3.1-8b-instant", "openai/gpt-oss-20b"]
	var _q23: int = 0
	for _b72 in _d4:
		var _h80: String = _b72[0]
		var _a2: String = _b72[1]
		if _h80 in _w25:
			_x83.add_item(_a2)
			_x83.set_item_metadata(_q23, _h80)
			_q23 += 1
	if _q23 == 0:
		_x83.add_item("Gemini Flash (Recommended)")
		_x83.set_item_metadata(0, "gemini-2.5-flash")
		_q23 = 1
	if _x83.item_count > 0:
		_x83.selected = 0
func _v19() -> String:
	if not _x83 or _x83.selected < 0:
		return "gemini-2.5-flash"  
	return _x83.get_item_metadata(_x83.selected)
func _s62():
	if not _x52:
		return
	var _z13 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _q53 = _z13.get_luminance() > 0.5
	var _e98 = StyleBoxFlat.new()
	_e98.bg_color = _z13.darkened(0.05) if _q53 else _z13.lightened(0.05)
	_e98.border_color = _z13.darkened(0.15) if _q53 else _z13.lightened(0.1)
	_e98.corner_radius_top_left = 4
	_e98.corner_radius_top_right = 4
	_e98.corner_radius_bottom_left = 4
	_e98.corner_radius_bottom_right = 4
	_e98.border_width_left = 1
	_e98.border_width_right = 1
	_e98.border_width_top = 1
	_e98.border_width_bottom = 1
	_x52.add_theme_stylebox_override("panel", _e98)
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _w22:
		_w22.add_theme_color_override("font_color", font_color)
	if _f67:
		_f67.add_theme_color_override("font_color", font_color)
