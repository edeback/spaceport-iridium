@tool
class_name _w60
extends AcceptDialog

signal _g24(_r76: String, function_name: String, _z29: String, model: String)

var _k54: String
var _k90: String
var _h70: String  
var _n21: TextEdit
var _c78: Button
var _e67: Button
var _a2: PanelContainer
var _u45: bool = false
var _f30: Timer
var _o37: Timer
var _z17: float = 0.0
var _m4: Label  
var _a56: OptionButton  
var _u56: Node = null  
var _a31: float = 1.0  

var _o40: Label
var _c63: Label
var _v74: Label
var _u71: Label
var _d24: Label
var _x23: Label
var _m68: Array = []

const _n49: Array = [

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

const _u11 = [
	"Improve readability - make the code clearer and more understandable",
	"Optimize performance - improve efficiency and speed",
	"Convert to Godot 4 idioms - use modern Godot 4 best practices",
	"Extract helper method - break down into smaller, reusable functions",
	"Replace if/else with match - use match statements where appropriate",
	"Add comments - include helpful documentation and explanations"
]

func _ready():
	get_ok_button().hide()

	if not confirmed.is_connected(_t18):
		confirmed.connect(_t18)

	_x97()
	
func _x97():
	if not is_inside_tree():
		return

	_n21 = find_child("_h22", true, false)
	_c78 = find_child("_q66", true, false)
	_e67 = find_child("_r99", true, false)
	_a2 = find_child("_w17", true, false)
	_m4 = find_child("_f25", true, false)
	_f30 = find_child("_r79", true, false)
	_o37 = find_child("_m90", true, false)

	_o40 = find_child("_g13", true, false)
	_c63 = find_child("_o63", true, false)
	_v74 = find_child("_m86", true, false)
	_u71 = find_child("_t4", true, false)
	_d24 = find_child("_o51", true, false)
	_x23 = find_child("_m64", true, false)

	_a56 = find_child("_p95", true, false)
	if _a56:
		_z70()
	else:
		pass

	_m68 = [
		find_child("_v7", true, false),
		find_child("_s46", true, false),
		find_child("_i81", true, false),
		find_child("_m91", true, false),
		find_child("_t79", true, false),
		find_child("_s3", true, false)
	]

	if _n21 and not _n21.text_changed.is_connected(_m33):
		_n21.text_changed.connect(_m33)
	if _c78 and not _c78.pressed.is_connected(_t18):
		_c78.pressed.connect(_t18)
	if _e67 and not _e67.pressed.is_connected(_l47):
		_e67.pressed.connect(_l47)
	
	if _f30 and not _f30.timeout.is_connected(_a22):
		_f30.timeout.connect(_a22)
	if _o37 and not _o37.timeout.is_connected(_p44):
		_o37.timeout.connect(_p44)

	_c19()

	for i in range(_m68.size()):
		var _c65 = _m68[i]
		if _c65 and not _c65.pressed.is_connected(_g36.bind(i)):
			_c65.pressed.connect(_g36.bind(i))

	_s54()
	_t67()

func _s54():
	var config = ConfigFile.new()
	var _v66: String = "auto"

	if config.load("user://gdsense_settings.cfg") == OK:
		_v66 = config.get_value("font_scale", "mode", "auto")

	if _v66 == "auto":
		_a31 = _t83()
	else:
		var _g25 = float(_v66)
		_g25 = clamp(_g25, 0.5, 3.0)
		if is_nan(_g25) or is_inf(_g25):
			_g25 = 1.0
		_a31 = _g25

func _t83() -> float:
	var _a77 = DisplayServer.screen_get_size()
	var height = int(_a77.y)

	if height >= 2160:  
		return 1.5
	elif height >= 1440:  
		return 1.25
	elif height >= 1080:  
		return 1.0
	else:  
		return 0.8

func _n36(_u61: int) -> int:
	var _u13 = int(_u61 * _a31)
	return max(_u13, 12)  

func _t67():
	if not is_inside_tree():
		return

	var _y94: int = 16
	var _f11: int = 18
	var _v98: int = 14
	var _p38: int = 16

	var _z79 = _n36(_y94)
	var _r88 = _n36(_f11)
	var _u31 = _n36(_v98)
	var _a78 = _n36(_p38)

	if _o40:
		_o40.add_theme_font_size_override("font_size", _r88)

	if _c63:
		_c63.add_theme_font_size_override("font_size", _z79)

	if _v74:
		_v74.add_theme_font_size_override("font_size", _z79)

	if _u71:
		_u71.add_theme_font_size_override("font_size", _z79)

	if _d24:
		_d24.add_theme_font_size_override("font_size", _u31)

	if _x23:
		_x23.add_theme_font_size_override("font_size", _z79)

	if _m4:
		_m4.add_theme_font_size_override("font_size", _u31)

	for _u96 in _m68:
		if _u96:
			_u96.add_theme_font_size_override("font_size", _a78)

	if _n21:
		_n21.add_theme_font_size_override("font_size", _z79)

	if _a56:
		_a56.add_theme_font_size_override("font_size", _z79)

	if _c78:
		_c78.add_theme_font_size_override("font_size", _a78)
	if _e67:
		_e67.add_theme_font_size_override("font_size", _a78)

func _j70(index: int) -> String:
	match index:
		0: return "• Improve readability"
		1: return "• Optimize performance"
		2: return "• Convert to Godot 4"
		3: return "• Extract helper method"
		4: return "• Replace if/else with match"
		5: return "• Add comments"
		_: return "• Unknown preset"

func _k60(function_name: String, _z29: String):
	_k54 = function_name
	_k90 = _z29
	_h70 = _z29  

	_u45 = false
	if _a2:
		_a2.visible = false
	if _c78:
		_c78.disabled = true
	if _e67:
		_e67.disabled = false
	if _n21:
		_n21.editable = true

	if is_instance_valid(_f30):
		_f30.stop()
	if is_instance_valid(_o37):
		_o37.stop()

	if _x23:
		_x23.text = "🔄 Processing refactor request..."
		_x23.remove_theme_color_override("font_color")  

	if _m4:
		_m4.text = "Elapsed time: 0.0s"
		_m4.visible = true

	if _o40:
		_o40.text = "Refactoring: %s" % function_name

	if _n21:
		_n21.text = ""
	
	_j49()
	
	if is_inside_tree():
		_s54()
		_t67()
		_c19()
		popup_centered()

		if _n21:
			_n21.grab_focus()
	else:
		_m41.call_deferred()

func _a10():
	_u45 = false

	if is_instance_valid(_f30):
		_f30.stop()
	if is_instance_valid(_o37):
		_o37.stop()
	_p24()

func _p24():
	if is_inside_tree():
		hide()

		var parent = get_parent()
		if parent:
			parent.remove_child.call_deferred(self)

func _a22():
	if not _u45:
		return
	
	if is_instance_valid(_o37):
		_o37.stop()
	
	if _x23:
		_x23.text = "⚠️ Request timed out. Please try again."

		var _q77 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
		_x23.add_theme_color_override("font_color", _q77)
	
	if is_instance_valid(_m4):
		_m4.visible = false
	
	await get_tree().create_timer(3.0).timeout
	
	if _u45:  
		_u45 = false
		if _a2:
			_a2.visible = false
		if _c78:
			_c78.disabled = false
		if _e67:
			_e67.disabled = false
		if _n21:
			_n21.editable = true

func _g36(_m43: int):
	if _m43 >= 0 and _m43 < _u11.size():
		if _n21:
			_n21.text = _u11[_m43]
		if _c78:
			_c78.disabled = false
		_j49()

		if _n21:
			if is_inside_tree():
				_n21.grab_focus()
			_n21.set_caret_line(_n21.get_line_count() - 1)
			_n21.set_caret_column(_n21.get_line(_n21.get_line_count() - 1).length())

func _m33():
	if not _n21:
		return
	var text = _n21.text.strip_edges()
	if _c78:
		_c78.disabled = text.is_empty()
	_j49()

func _m41():
	if is_inside_tree():
		_s54()
		_t67()
		_c19()
		popup_centered()
		if _n21:
			_n21.grab_focus()

func _j49():
	if _d24 and _n21:
		var _a68 = _n21.text.length()
		_d24.text = "%d/1000" % _a68

		if _a68 > 1000:
			var _q77 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3)
			_d24.add_theme_color_override("font_color", _q77)
		elif _a68 > 800:
			var _r37 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_d24.add_theme_color_override("font_color", _r37)
		else:
			_d24.remove_theme_color_override("font_color")  

func _t18():
	if not _n21:
		return
	var prompt = _n21.text.strip_edges()

	if prompt.is_empty() or _u45:
		return

	if prompt.length() > 1000:
		return

	_u45 = true
	_z17 = Time.get_ticks_msec() / 1000.0
	if _a2:
		_a2.visible = true
	if _c78:
		_c78.disabled = true
	if _e67:
		_e67.disabled = true
	if _n21:
		_n21.editable = false
	
	if is_instance_valid(_o37):
		_o37.start()

	else:
		pass

	if is_instance_valid(_f30):
		_f30.start()
	
	var _o71 = _c64()
	_g24.emit(prompt, _k54, _k90, _o71)

func _l47():
	if is_instance_valid(_f30):
		_f30.stop()
	if is_instance_valid(_o37):
		_o37.stop()
	_u45 = false
	hide()

func _p44():
	if not _u45:
		return
	
	var _y68 = Time.get_ticks_msec() / 1000.0
	var _e39 = _y68 - _z17
	
	if is_instance_valid(_m4):
		_m4.text = "Elapsed time: %.1fs" % _e39
	else:
		pass

func _n82() -> String:
	return _h70

func _g48() -> String:
	return _n21.text if _n21 else ""

func set_gdsense_manager(_r18: Node) -> void:
	_u56 = _r18

	if _u56:
		if not _u56._p47.is_connected(_n37):
			_u56._p47.connect(_n37)

		var _u74 = _u56._b18()
		if not _u74.is_empty() and _u74.has("tier"):
			_n37(_u74)
			return  

	_z70()

func _n37(_c89: Dictionary) -> void:
	_z70()

func _z70() -> void:
	if not _a56:
		return

	_a56.clear()

	var _v29: Array = []
	if _u56:
		_v29 = _u56._s69()

	if _v29.is_empty():
		_v29 = ["llama-3.1-8b-instant", "openai/gpt-oss-20b"]

	var _b66: int = 0
	for _t88 in _n49:
		var _z3: String = _t88[0]
		var _l15: String = _t88[1]
		if _z3 in _v29:
			_a56.add_item(_l15)
			_a56.set_item_metadata(_b66, _z3)
			_b66 += 1

	if _b66 == 0:
		_a56.add_item("Gemini Flash (Recommended)")
		_a56.set_item_metadata(0, "gemini-2.5-flash")
		_b66 = 1

	if _a56.item_count > 0:
		_a56.selected = 0

func _c64() -> String:
	if not _a56 or _a56.selected < 0:
		return "gemini-2.5-flash"  

	return _a56.get_item_metadata(_a56.selected)

func _c19():
	if not _a2:
		return

	var _m31 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _o90 = _m31.get_luminance() > 0.5

	var _f36 = StyleBoxFlat.new()

	_f36.bg_color = _m31.darkened(0.05) if _o90 else _m31.lightened(0.05)
	_f36.border_color = _m31.darkened(0.15) if _o90 else _m31.lightened(0.1)

	_f36.corner_radius_top_left = 4
	_f36.corner_radius_top_right = 4
	_f36.corner_radius_bottom_left = 4
	_f36.corner_radius_bottom_right = 4
	_f36.border_width_left = 1
	_f36.border_width_right = 1
	_f36.border_width_top = 1
	_f36.border_width_bottom = 1
	_a2.add_theme_stylebox_override("panel", _f36)

	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _x23:
		_x23.add_theme_color_override("font_color", font_color)
	if _m4:
		_m4.add_theme_color_override("font_color", font_color)

