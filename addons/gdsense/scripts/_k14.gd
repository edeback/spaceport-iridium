@tool
class_name _m59
extends AcceptDialog

signal _g26(_n1: String, function_name: String, _g33: String, model: String)

var _t40: String
var _t9: String
var _y46: String  
var _n9: TextEdit
var _r82: Button
var _g58: Button
var _n17: PanelContainer
var _u19: bool = false
var _k70: Timer
var _p99: Timer
var _w92: float = 0.0
var _v21: Label  
var _g86: OptionButton  
var _a12: Node = null  
var _g83: float = 1.0  

var _h12: Label
var _a13: Label
var _c81: Label
var _c80: Label
var _n24: Label
var _d96: Label
var _n69: Array = []

const _f15: Array = [

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

const _s12 = [
	"Improve readability - make the code clearer and more understandable",
	"Optimize performance - improve efficiency and speed",
	"Convert to Godot 4 idioms - use modern Godot 4 best practices",
	"Extract helper method - break down into smaller, reusable functions",
	"Replace if/else with match - use match statements where appropriate",
	"Add comments - include helpful documentation and explanations"
]

func _ready():
	get_ok_button().hide()

	if not confirmed.is_connected(_x1):
		confirmed.connect(_x1)

	_i29()
	
func _i29():
	if not is_inside_tree():
		return

	_n9 = find_child("_e36", true, false)
	_r82 = find_child("_f26", true, false)
	_g58 = find_child("_f33", true, false)
	_n17 = find_child("_h53", true, false)
	_v21 = find_child("_n44", true, false)
	_k70 = find_child("_u85", true, false)
	_p99 = find_child("_g77", true, false)

	_h12 = find_child("_k74", true, false)
	_a13 = find_child("_h94", true, false)
	_c81 = find_child("_a94", true, false)
	_c80 = find_child("_i92", true, false)
	_n24 = find_child("_c55", true, false)
	_d96 = find_child("_w93", true, false)

	_g86 = find_child("_a22", true, false)
	if _g86:
		_m2()
	else:
		pass

	_n69 = [
		find_child("_d11", true, false),
		find_child("_k43", true, false),
		find_child("_j53", true, false),
		find_child("_t2", true, false),
		find_child("_s26", true, false),
		find_child("_w1", true, false)
	]

	if _n9 and not _n9.text_changed.is_connected(_p28):
		_n9.text_changed.connect(_p28)
	if _r82 and not _r82.pressed.is_connected(_x1):
		_r82.pressed.connect(_x1)
	if _g58 and not _g58.pressed.is_connected(_s47):
		_g58.pressed.connect(_s47)
	
	if _k70 and not _k70.timeout.is_connected(_u38):
		_k70.timeout.connect(_u38)
	if _p99 and not _p99.timeout.is_connected(_p42):
		_p99.timeout.connect(_p42)

	_k11()

	for i in range(_n69.size()):
		var _i32 = _n69[i]
		if _i32 and not _i32.pressed.is_connected(_m6.bind(i)):
			_i32.pressed.connect(_m6.bind(i))

	_m8()
	_v92()

func _m8():
	var config = ConfigFile.new()
	var _w39: String = "auto"

	if config.load("user://gdsense_settings.cfg") == OK:
		_w39 = config.get_value("font_scale", "mode", "auto")

	if _w39 == "auto":
		_g83 = _o85()
	else:
		var _i28 = float(_w39)
		_i28 = clamp(_i28, 0.5, 3.0)
		if is_nan(_i28) or is_inf(_i28):
			_i28 = 1.0
		_g83 = _i28

func _o85() -> float:
	var _t53 = DisplayServer.screen_get_size()
	var height = int(_t53.y)

	if height >= 2160:  
		return 1.5
	elif height >= 1440:  
		return 1.25
	elif height >= 1080:  
		return 1.0
	else:  
		return 0.8

func _i68(_g6: int) -> int:
	var _y84 = int(_g6 * _g83)
	return max(_y84, 12)  

func _v92():
	if not is_inside_tree():
		return

	var _m11: int = 16
	var _x99: int = 18
	var _g9: int = 14
	var _s66: int = 16

	var _c13 = _i68(_m11)
	var _h67 = _i68(_x99)
	var _x18 = _i68(_g9)
	var _b3 = _i68(_s66)

	if _h12:
		_h12.add_theme_font_size_override("font_size", _h67)

	if _a13:
		_a13.add_theme_font_size_override("font_size", _c13)

	if _c81:
		_c81.add_theme_font_size_override("font_size", _c13)

	if _c80:
		_c80.add_theme_font_size_override("font_size", _c13)

	if _n24:
		_n24.add_theme_font_size_override("font_size", _x18)

	if _d96:
		_d96.add_theme_font_size_override("font_size", _c13)

	if _v21:
		_v21.add_theme_font_size_override("font_size", _x18)

	for _w34 in _n69:
		if _w34:
			_w34.add_theme_font_size_override("font_size", _b3)

	if _n9:
		_n9.add_theme_font_size_override("font_size", _c13)

	if _g86:
		_g86.add_theme_font_size_override("font_size", _c13)

	if _r82:
		_r82.add_theme_font_size_override("font_size", _b3)
	if _g58:
		_g58.add_theme_font_size_override("font_size", _b3)

func _e90(index: int) -> String:
	match index:
		0: return "• Improve readability"
		1: return "• Optimize performance"
		2: return "• Convert to Godot 4"
		3: return "• Extract helper method"
		4: return "• Replace if/else with match"
		5: return "• Add comments"
		_: return "• Unknown preset"

func _m52(function_name: String, _g33: String):
	_t40 = function_name
	_t9 = _g33
	_y46 = _g33  

	_u19 = false
	if _n17:
		_n17.visible = false
	if _r82:
		_r82.disabled = true
	if _g58:
		_g58.disabled = false
	if _n9:
		_n9.editable = true

	if is_instance_valid(_k70):
		_k70.stop()
	if is_instance_valid(_p99):
		_p99.stop()

	if _d96:
		_d96.text = "🔄 Processing refactor request..."
		_d96.remove_theme_color_override("font_color")  

	if _v21:
		_v21.text = "Elapsed time: 0.0s"
		_v21.visible = true

	if _h12:
		_h12.text = "Refactoring: %s" % function_name

	if _n9:
		_n9.text = ""
	
	_g90()
	
	if is_inside_tree():
		_m8()
		_v92()
		_k11()
		popup_centered()

		if _n9:
			_n9.grab_focus()
	else:
		_s81.call_deferred()

func _f37():
	_u19 = false

	if is_instance_valid(_k70):
		_k70.stop()
	if is_instance_valid(_p99):
		_p99.stop()
	_h22()

func _h22():
	if is_inside_tree():
		hide()

		var parent = get_parent()
		if parent:
			parent.remove_child.call_deferred(self)

func _u38():
	if not _u19:
		return
	
	if is_instance_valid(_p99):
		_p99.stop()
	
	if _d96:
		_d96.text = "⚠️ Request timed out. Please try again."

		var _p52 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
		_d96.add_theme_color_override("font_color", _p52)
	
	if is_instance_valid(_v21):
		_v21.visible = false
	
	await get_tree().create_timer(3.0).timeout
	
	if _u19:  
		_u19 = false
		if _n17:
			_n17.visible = false
		if _r82:
			_r82.disabled = false
		if _g58:
			_g58.disabled = false
		if _n9:
			_n9.editable = true

func _m6(_a28: int):
	if _a28 >= 0 and _a28 < _s12.size():
		if _n9:
			_n9.text = _s12[_a28]
		if _r82:
			_r82.disabled = false
		_g90()

		if _n9:
			if is_inside_tree():
				_n9.grab_focus()
			_n9.set_caret_line(_n9.get_line_count() - 1)
			_n9.set_caret_column(_n9.get_line(_n9.get_line_count() - 1).length())

func _p28():
	if not _n9:
		return
	var text = _n9.text.strip_edges()
	if _r82:
		_r82.disabled = text.is_empty()
	_g90()

func _s81():
	if is_inside_tree():
		_m8()
		_v92()
		_k11()
		popup_centered()
		if _n9:
			_n9.grab_focus()

func _g90():
	if _n24 and _n9:
		var _g81 = _n9.text.length()
		_n24.text = "%d/1000" % _g81

		if _g81 > 1000:
			var _p52 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
			_n24.add_theme_color_override("font_color", _p52)
		elif _g81 > 800:
			var _q36 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_n24.add_theme_color_override("font_color", _q36)
		else:
			_n24.remove_theme_color_override("font_color")  

func _x1():
	if not _n9:
		return
	var prompt = _n9.text.strip_edges()

	if prompt.is_empty() or _u19:
		return

	if prompt.length() > 1000:
		return

	_u19 = true
	_w92 = Time.get_ticks_msec() / 1000.0
	if _n17:
		_n17.visible = true
	if _r82:
		_r82.disabled = true
	if _g58:
		_g58.disabled = true
	if _n9:
		_n9.editable = false
	
	if is_instance_valid(_p99):
		_p99.start()

	else:
		pass

	if is_instance_valid(_k70):
		_k70.start()
	
	var _p26 = _x38()
	_g26.emit(prompt, _t40, _t9, _p26)

func _s47():
	if is_instance_valid(_k70):
		_k70.stop()
	if is_instance_valid(_p99):
		_p99.stop()
	_u19 = false
	hide()

func _p42():
	if not _u19:
		return
	
	var _t19 = Time.get_ticks_msec() / 1000.0
	var _x53 = _t19 - _w92
	
	if is_instance_valid(_v21):
		_v21.text = "Elapsed time: %.1fs" % _x53
	else:
		pass

func _u27() -> String:
	return _y46

func _n70() -> String:
	return _n9.text if _n9 else ""

func set_gdsense_manager(_b4: Node) -> void:
	_a12 = _b4

	if _a12:
		if not _a12._w60.is_connected(_h15):
			_a12._w60.connect(_h15)

		var _v58 = _a12._r47()
		if not _v58.is_empty() and _v58.has("tier"):
			_h15(_v58)
			return  

	_m2()

func _h15(_i57: Dictionary) -> void:
	_m2()

func _m2() -> void:
	if not _g86:
		return

	_g86.clear()

	var _m76: Array = []
	if _a12:
		_m76 = _a12._n25()

	if _m76.is_empty():
		_m76 = ["llama-3.1-8b-instant", "openai/gpt-oss-20b"]

	var _t77: int = 0
	for _i12 in _f15:
		var _t50: String = _i12[0]
		var _j4: String = _i12[1]
		if _t50 in _m76:
			_g86.add_item(_j4)
			_g86.set_item_metadata(_t77, _t50)
			_t77 += 1

	if _t77 == 0:
		_g86.add_item("Gemini Flash (Recommended)")
		_g86.set_item_metadata(0, "gemini-2.5-flash")
		_t77 = 1

	if _g86.item_count > 0:
		_g86.selected = 0

func _x38() -> String:
	if not _g86 or _g86.selected < 0:
		return "gemini-2.5-flash"  

	return _g86.get_item_metadata(_g86.selected)

func _k11():
	if not _n17:
		return

	var _t29 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _r46 = _t29.get_luminance() > 0.5

	var _o97 = StyleBoxFlat.new()

	_o97.bg_color = _t29.darkened(0.05) if _r46 else _t29.lightened(0.05)
	_o97.border_color = _t29.darkened(0.15) if _r46 else _t29.lightened(0.1)

	_o97.corner_radius_top_left = 4
	_o97.corner_radius_top_right = 4
	_o97.corner_radius_bottom_left = 4
	_o97.corner_radius_bottom_right = 4
	_o97.border_width_left = 1
	_o97.border_width_right = 1
	_o97.border_width_top = 1
	_o97.border_width_bottom = 1
	_n17.add_theme_stylebox_override("panel", _o97)

	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _d96:
		_d96.add_theme_color_override("font_color", font_color)
	if _v21:
		_v21.add_theme_color_override("font_color", font_color)

