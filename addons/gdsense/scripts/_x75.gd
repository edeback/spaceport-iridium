@tool
class_name _m1
extends AcceptDialog

signal _b27(_r44: String, function_name: String, _c25: String, model: String)

var _p44: String
var _m80: String
var _d50: String  
var _m16: TextEdit
var _u13: Button
var _z69: Button
var _i9: PanelContainer
var _h30: bool = false
var _g64: Timer
var _u20: Timer
var _l45: float = 0.0
var _g51: Label  
var _k59: OptionButton  
var _k87: Node = null  
var _v98: float = 1.0  

var _j75: Label
var _q48: Label
var _x46: Label
var _c2: Label
var _d63: Label
var _v66: Label
var _q97: Array = []

const _m89: Array = [

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

const _c94 = [
	"Improve readability - make the code clearer and more understandable",
	"Optimize performance - improve efficiency and speed",
	"Convert to Godot 4 idioms - use modern Godot 4 best practices",
	"Extract helper method - break down into smaller, reusable functions",
	"Replace if/else with match - use match statements where appropriate",
	"Add comments - include helpful documentation and explanations"
]

func _ready():
	get_ok_button().hide()

	if not confirmed.is_connected(_s94):
		confirmed.connect(_s94)

	_p45()
	
func _p45():
	if not is_inside_tree():
		return

	_m16 = find_child("_p9", true, false)
	_u13 = find_child("_k84", true, false)
	_z69 = find_child("_o13", true, false)
	_i9 = find_child("_l77", true, false)
	_g51 = find_child("_a44", true, false)
	_g64 = find_child("_e61", true, false)
	_u20 = find_child("_s59", true, false)

	_j75 = find_child("_s100", true, false)
	_q48 = find_child("_g10", true, false)
	_x46 = find_child("_a65", true, false)
	_c2 = find_child("_w17", true, false)
	_d63 = find_child("_g74", true, false)
	_v66 = find_child("_w7", true, false)

	_k59 = find_child("_y86", true, false)
	if _k59:
		_x10()
	else:
		pass

	_q97 = [
		find_child("_k91", true, false),
		find_child("_n87", true, false),
		find_child("_h56", true, false),
		find_child("_s4", true, false),
		find_child("_z4", true, false),
		find_child("_n73", true, false)
	]

	if _m16 and not _m16.text_changed.is_connected(_a68):
		_m16.text_changed.connect(_a68)
	if _u13 and not _u13.pressed.is_connected(_s94):
		_u13.pressed.connect(_s94)
	if _z69 and not _z69.pressed.is_connected(_j50):
		_z69.pressed.connect(_j50)
	
	if _g64 and not _g64.timeout.is_connected(_d99):
		_g64.timeout.connect(_d99)
	if _u20 and not _u20.timeout.is_connected(_l10):
		_u20.timeout.connect(_l10)

	_b77()

	for i in range(_q97.size()):
		var _e87 = _q97[i]
		if _e87 and not _e87.pressed.is_connected(_g67.bind(i)):
			_e87.pressed.connect(_g67.bind(i))

	_b52()
	_o19()

func _b52():
	var config = ConfigFile.new()
	var _i4: String = "auto"

	if config.load("user://gdsense_settings.cfg") == OK:
		_i4 = config.get_value("font_scale", "mode", "auto")

	if _i4 == "auto":
		_v98 = _d45()
	else:
		var _f1 = float(_i4)
		_f1 = clamp(_f1, 0.5, 3.0)
		if is_nan(_f1) or is_inf(_f1):
			_f1 = 1.0
		_v98 = _f1

func _d45() -> float:
	var _s14 = DisplayServer.screen_get_size()
	var height = int(_s14.y)

	if height >= 2160:  
		return 1.5
	elif height >= 1440:  
		return 1.25
	elif height >= 1080:  
		return 1.0
	else:  
		return 0.8

func _r80(_w28: int) -> int:
	var _o11 = int(_w28 * _v98)
	return max(_o11, 12)  

func _o19():
	if not is_inside_tree():
		return

	var _i19: int = 16
	var _l36: int = 18
	var _m35: int = 14
	var _o96: int = 16

	var _f80 = _r80(_i19)
	var _l21 = _r80(_l36)
	var _h76 = _r80(_m35)
	var _h24 = _r80(_o96)

	if _j75:
		_j75.add_theme_font_size_override("font_size", _l21)

	if _q48:
		_q48.add_theme_font_size_override("font_size", _f80)

	if _x46:
		_x46.add_theme_font_size_override("font_size", _f80)

	if _c2:
		_c2.add_theme_font_size_override("font_size", _f80)

	if _d63:
		_d63.add_theme_font_size_override("font_size", _h76)

	if _v66:
		_v66.add_theme_font_size_override("font_size", _f80)

	if _g51:
		_g51.add_theme_font_size_override("font_size", _h76)

	for _g72 in _q97:
		if _g72:
			_g72.add_theme_font_size_override("font_size", _h24)

	if _m16:
		_m16.add_theme_font_size_override("font_size", _f80)

	if _k59:
		_k59.add_theme_font_size_override("font_size", _f80)

	if _u13:
		_u13.add_theme_font_size_override("font_size", _h24)
	if _z69:
		_z69.add_theme_font_size_override("font_size", _h24)

func _h16(index: int) -> String:
	match index:
		0: return "• Improve readability"
		1: return "• Optimize performance"
		2: return "• Convert to Godot 4"
		3: return "• Extract helper method"
		4: return "• Replace if/else with match"
		5: return "• Add comments"
		_: return "• Unknown preset"

func _m14(function_name: String, _c25: String):
	_p44 = function_name
	_m80 = _c25
	_d50 = _c25  

	_h30 = false
	if _i9:
		_i9.visible = false
	if _u13:
		_u13.disabled = true
	if _z69:
		_z69.disabled = false
	if _m16:
		_m16.editable = true

	if is_instance_valid(_g64):
		_g64.stop()
	if is_instance_valid(_u20):
		_u20.stop()

	if _v66:
		_v66.text = "🔄 Processing refactor request..."
		_v66.remove_theme_color_override("font_color")  

	if _g51:
		_g51.text = "Elapsed time: 0.0s"
		_g51.visible = true

	if _j75:
		_j75.text = "Refactoring: %s" % function_name

	if _m16:
		_m16.text = ""
	
	_u69()
	
	if is_inside_tree():
		_b52()
		_o19()
		_b77()
		popup_centered()

		if _m16:
			_m16.grab_focus()
	else:
		_g93.call_deferred()

func _y56():
	_h30 = false

	if is_instance_valid(_g64):
		_g64.stop()
	if is_instance_valid(_u20):
		_u20.stop()
	_a98()

func _a98():
	if is_inside_tree():
		hide()

		var parent = get_parent()
		if parent:
			parent.remove_child.call_deferred(self)

func _d99():
	if not _h30:
		return
	
	if is_instance_valid(_u20):
		_u20.stop()
	
	if _v66:
		_v66.text = "⚠️ Request timed out. Please try again."

		var _c76 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
		_v66.add_theme_color_override("font_color", _c76)
	
	if is_instance_valid(_g51):
		_g51.visible = false
	
	await get_tree().create_timer(3.0).timeout
	
	if _h30:  
		_h30 = false
		if _i9:
			_i9.visible = false
		if _u13:
			_u13.disabled = false
		if _z69:
			_z69.disabled = false
		if _m16:
			_m16.editable = true

func _g67(_n23: int):
	if _n23 >= 0 and _n23 < _c94.size():
		if _m16:
			_m16.text = _c94[_n23]
		if _u13:
			_u13.disabled = false
		_u69()

		if _m16:
			if is_inside_tree():
				_m16.grab_focus()
			_m16.set_caret_line(_m16.get_line_count() - 1)
			_m16.set_caret_column(_m16.get_line(_m16.get_line_count() - 1).length())

func _a68():
	if not _m16:
		return
	var text = _m16.text.strip_edges()
	if _u13:
		_u13.disabled = text.is_empty()
	_u69()

func _g93():
	if is_inside_tree():
		_b52()
		_o19()
		_b77()
		popup_centered()
		if _m16:
			_m16.grab_focus()

func _u69():
	if _d63 and _m16:
		var _r57 = _m16.text.length()
		_d63.text = "%d/1000" % _r57

		if _r57 > 1000:
			var _c76 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
			_d63.add_theme_color_override("font_color", _c76)
		elif _r57 > 800:
			var _l12 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_d63.add_theme_color_override("font_color", _l12)
		else:
			_d63.remove_theme_color_override("font_color")  

func _s94():
	if not _m16:
		return
	var prompt = _m16.text.strip_edges()

	if prompt.is_empty() or _h30:
		return

	if prompt.length() > 1000:
		return

	_h30 = true
	_l45 = Time.get_ticks_msec() / 1000.0
	if _i9:
		_i9.visible = true
	if _u13:
		_u13.disabled = true
	if _z69:
		_z69.disabled = true
	if _m16:
		_m16.editable = false
	
	if is_instance_valid(_u20):
		_u20.start()

	else:
		pass

	if is_instance_valid(_g64):
		_g64.start()
	
	var _i62 = _y7()
	_b27.emit(prompt, _p44, _m80, _i62)

func _j50():
	if is_instance_valid(_g64):
		_g64.stop()
	if is_instance_valid(_u20):
		_u20.stop()
	_h30 = false
	hide()

func _l10():
	if not _h30:
		return
	
	var _l95 = Time.get_ticks_msec() / 1000.0
	var _x50 = _l95 - _l45
	
	if is_instance_valid(_g51):
		_g51.text = "Elapsed time: %.1fs" % _x50
	else:
		pass

func _e53() -> String:
	return _d50

func _o61() -> String:
	return _m16.text if _m16 else ""

func set_gdsense_manager(_h31: Node) -> void:
	_k87 = _h31

	if _k87:
		if not _k87._e51.is_connected(_b70):
			_k87._e51.connect(_b70)

		var _e2 = _k87._p92()
		if not _e2.is_empty() and _e2.has("tier"):
			_b70(_e2)
			return  

	_x10()

func _b70(_l15: Dictionary) -> void:
	_x10()

func _x10() -> void:
	if not _k59:
		return

	_k59.clear()

	var _j13: Array = []
	if _k87:
		_j13 = _k87._j48()

	if _j13.is_empty():
		_j13 = ["llama-3.1-8b-instant", "openai/gpt-oss-20b"]

	var _v55: int = 0
	for _a63 in _m89:
		var _f46: String = _a63[0]
		var _j52: String = _a63[1]
		if _f46 in _j13:
			_k59.add_item(_j52)
			_k59.set_item_metadata(_v55, _f46)
			_v55 += 1

	if _v55 == 0:
		_k59.add_item("Gemini Flash (Recommended)")
		_k59.set_item_metadata(0, "gemini-2.5-flash")
		_v55 = 1

	if _k59.item_count > 0:
		_k59.selected = 0

func _y7() -> String:
	if not _k59 or _k59.selected < 0:
		return "gemini-2.5-flash"  

	return _k59.get_item_metadata(_k59.selected)

func _b77():
	if not _i9:
		return

	var _q75 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _r36 = _q75.get_luminance() > 0.5

	var _x58 = StyleBoxFlat.new()

	_x58.bg_color = _q75.darkened(0.05) if _r36 else _q75.lightened(0.05)
	_x58.border_color = _q75.darkened(0.15) if _r36 else _q75.lightened(0.1)

	_x58.corner_radius_top_left = 4
	_x58.corner_radius_top_right = 4
	_x58.corner_radius_bottom_left = 4
	_x58.corner_radius_bottom_right = 4
	_x58.border_width_left = 1
	_x58.border_width_right = 1
	_x58.border_width_top = 1
	_x58.border_width_bottom = 1
	_i9.add_theme_stylebox_override("panel", _x58)

	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _v66:
		_v66.add_theme_color_override("font_color", font_color)
	if _g51:
		_g51.add_theme_color_override("font_color", font_color)

