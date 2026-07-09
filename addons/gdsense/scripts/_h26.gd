@tool
class_name _c43
extends AcceptDialog

signal _a66(_n33: Dictionary, _k3: Dictionary)
signal _e21(_n33: Dictionary, _o23: String)

var _b36: Dictionary
var _o28: CodeEdit
var _z8: Label
var _d27: Button
var _x27: Label
var _z35: VBoxContainer
var _q86: EditorInterface
var _j88: TextEdit
var _e23: Label
const _n88 = 500

func _init() -> void:
	title = "Agent Action Approval"
	size = Vector2(900, 650)
	min_size = Vector2(700, 500)
	unresizable = false

	_d27 = add_button("Reject", false, "reject")

	confirmed.connect(_c50)
	custom_action.connect(_f72)
	canceled.connect(_w9)

func _k94(_t15: EditorInterface) -> void:
	_q86 = _t15

func _j38(_n33: Dictionary) -> void:
	_b36 = _n33

	if _z35 and is_instance_valid(_z35):
		_z35.queue_free()

	_z35 = VBoxContainer.new()
	_z35.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_z35.add_theme_constant_override("separation", 8)

	var _d89 = _n33.get("tool_name", "unknown")
	var description = _n33.get("description", "")

	match _d89:
		"create_file":
			title = "Create File"
			ok_button_text = "Create"
			_l62(_z35, _n33)
		"edit_file":
			title = "Edit File"
			ok_button_text = "Apply Changes"
			_y32(_z35, _n33)
		"delete_file":
			title = "Delete File"
			ok_button_text = "Delete"
			_b84(_z35, _n33)
		_:
			title = "Agent Action"
			ok_button_text = "Approve"
			_g42(_z35, _n33)

	_z35.add_child(HSeparator.new())

	_e23 = Label.new()
	_e23.text = "Rejection feedback (optional):"
	_m14(_e23)
	_z35.add_child(_e23)

	_j88 = TextEdit.new()
	_j88.placeholder_text = "Rejection only - e.g., 'Don't modify this file' or 'Try a different approach'"
	var font_size = _c77()
	_j88.custom_minimum_size = Vector2(font_size * 25, font_size * 4)
	_j88.scroll_fit_content_height = true
	_z35.add_child(_j88)

	add_child(_z35)

func _l62(_m49: VBoxContainer, _n33: Dictionary) -> void:
	var _h60 = _n33.get("parameters", {})
	if _h60 == null:
		_h60 = {}
	var path = _h60.get("path", "")
	if path == null:
		path = ""
	var content = _h60.get("content", "")
	if content == null:
		content = ""

	_z8 = Label.new()
	_z8.text = "File: " + path
	_u83(_z8)
	_m49.add_child(_z8)

	var _m73 = Label.new()
	_m73.text = "A new file will be created at this location."
	_m14(_m73)
	_m73.add_theme_color_override("font_color", _p45())
	_m49.add_child(_m73)

	_m49.add_child(HSeparator.new())

	var label = Label.new()
	label.text = "Content Preview:"
	_m14(label)
	_m49.add_child(label)

	_o28 = _j62()
	_o28.text = content
	_o28.custom_minimum_size = Vector2(850, 450)
	_m49.add_child(_o28)

func _y32(_m49: VBoxContainer, _n33: Dictionary) -> void:
	var _h60 = _n33.get("parameters", {})
	if _h60 == null:
		_h60 = {}
	var path = _h60.get("path", "")
	if path == null:
		path = ""
	var _l47 = _h60.get("old_string", "")
	if _l47 == null:
		_l47 = ""
	var _g50 = _h60.get("new_string", "")
	if _g50 == null:
		_g50 = ""
	var _w14 = _h60.get("replace_all", false)

	_z8 = Label.new()
	_z8.text = "File: " + path
	_u83(_z8)
	_m49.add_child(_z8)

	_x27 = Label.new()
	var _m95 = "Replace all occurrences" if _w14 else "Replace first occurrence"
	_x27.text = _m95 + " • A backup will be created"
	_m14(_x27)
	_x27.add_theme_color_override("font_color", Color.ORANGE)
	_m49.add_child(_x27)

	_m49.add_child(HSeparator.new())

	var _i24 = HSplitContainer.new()
	_i24.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_i24.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_i24.custom_minimum_size = Vector2(850, 400)

	var _m86 = VBoxContainer.new()
	_m86.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _v38 = Label.new()
	_v38.text = "Old (removing):"
	_v38.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_m14(_v38)
	_m86.add_child(_v38)

	var _j14 = _j62()
	_j14.text = _l47
	_j14.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var _k6 = StyleBoxFlat.new()
	_k6.bg_color = Color(0.15, 0.08, 0.08)
	_k6.set_corner_radius_all(4)
	_j14.add_theme_stylebox_override("normal", _k6)
	_m86.add_child(_j14)

	_i24.add_child(_m86)

	var _r84 = VBoxContainer.new()
	_r84.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _j16 = Label.new()
	_j16.text = "New (adding):"
	_j16.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_m14(_j16)
	_r84.add_child(_j16)

	var _s1 = _j62()
	_s1.text = _g50
	_s1.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var _t24 = StyleBoxFlat.new()
	_t24.bg_color = Color(0.08, 0.15, 0.08)
	_t24.set_corner_radius_all(4)
	_s1.add_theme_stylebox_override("normal", _t24)
	_r84.add_child(_s1)

	_i24.add_child(_r84)

	_m49.add_child(_i24)

	var _r27 = _l47.count("\n") + 1 if not _l47.is_empty() else 0
	var _k75 = _g50.count("\n") + 1 if not _g50.is_empty() else 0
	var _k38 = Label.new()
	_k38.text = "%d lines → %d lines" % [_r27, _k75]
	_k38.add_theme_color_override("font_color", _p45())
	_m14(_k38)
	_k38.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_m49.add_child(_k38)

func _b84(_m49: VBoxContainer, _n33: Dictionary) -> void:
	var _h60 = _n33.get("parameters", {})
	if _h60 == null:
		_h60 = {}
	var path = _h60.get("path", "")
	if path == null:
		path = ""

	_z8 = Label.new()
	_z8.text = "File: " + path
	_u83(_z8)
	_m49.add_child(_z8)

	_m49.add_child(HSeparator.new())

	var _w73 = Control.new()
	_w73.custom_minimum_size.y = 20
	_m49.add_child(_w73)

	_x27 = Label.new()
	_x27.text = "WARNING: This action cannot be undone!\nThe file will be permanently deleted."
	_x27.add_theme_color_override("font_color", Color.RED)
	_u83(_x27)  
	_x27.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_m49.add_child(_x27)

	var _u28 = Control.new()
	_u28.custom_minimum_size.y = 20
	_m49.add_child(_u28)

	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var _b9 = file.get_length()
			file.close()

			var _m73 = Label.new()
			_m73.text = "File size: %d bytes" % _b9
			_m73.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_m14(_m73)  
			_m49.add_child(_m73)

func _g42(_m49: VBoxContainer, _n33: Dictionary) -> void:
	var _d89 = _n33.get("tool_name", "unknown")
	if _d89 == null:
		_d89 = "unknown"
	var _h60 = _n33.get("parameters", {})
	if _h60 == null:
		_h60 = {}
	var description = _n33.get("description", "")
	if description == null:
		description = ""

	var _j28 = Label.new()
	_j28.text = "Tool: " + _d89
	_u83(_j28)
	_m49.add_child(_j28)

	if not description.is_empty():
		var _n41 = Label.new()
		_n41.text = description
		_n41.add_theme_color_override("font_color", _p45())
		_m14(_n41)
		_m49.add_child(_n41)

	_m49.add_child(HSeparator.new())

	var _d81 = Label.new()
	_d81.text = "Parameters:"
	_m14(_d81)
	_m49.add_child(_d81)

	var _u69 = RichTextLabel.new()
	_u69.bbcode_enabled = true
	_u69.fit_content = true
	_u69.scroll_active = false
	_u69.selection_enabled = true
	_u69.custom_minimum_size = Vector2(650, 100)

	var _d67 = ""
	for _y48 in _h60.keys():
		var value = _h60.get(_y48, "")
		var _z20 = str(value)
		if _z20.length() > 100:
			_z20 = _z20.substr(0, 100) + "..."
		_d67 += "[b]%s:[/b] %s\n" % [_y48, _z20]

	_u69.text = _d67
	_m49.add_child(_u69)

func _j62() -> CodeEdit:
	var _g95 = CodeEdit.new()
	_g95.editable = false
	_g95.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g95.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_g95.syntax_highlighter = _e72()
	_g95.gutters_draw_line_numbers = true
	_g95.scroll_smooth = true

	if _q86:
		var _e45 = _q86.get_editor_settings()
		if _e45:
			var bg_color = _e45.get_setting("text_editor/theme/highlighting/background_color")
			if bg_color:
				var _b28 = StyleBoxFlat.new()
				_b28.bg_color = bg_color
				_g95.add_theme_stylebox_override("normal", _b28)

	return _g95

func _e72() -> CodeHighlighter:
	var _t23 = CodeHighlighter.new()

	var _x5 = _z45("keyword_color", Color(0.96, 0.56, 0.56))
	var _z76 = _z45("control_flow_keyword_color", _x5)
	var _z13 = _z45("base_type_color", Color(0.56, 0.76, 0.96))
	var number_color = _z45("number_color", Color(0.56, 0.96, 0.76))
	var symbol_color = _z45("symbol_color", Color(0.8, 0.8, 0.8))
	var function_color = _z45("function_color", Color(0.56, 0.86, 0.96))
	var _l70 = _z45("member_variable_color", Color(0.76, 0.76, 0.96))

	_t23.add_keyword_color("func", _x5)
	_t23.add_keyword_color("var", _x5)
	_t23.add_keyword_color("const", _x5)
	_t23.add_keyword_color("class", _x5)
	_t23.add_keyword_color("class_name", _x5)
	_t23.add_keyword_color("extends", _x5)
	_t23.add_keyword_color("signal", _x5)
	_t23.add_keyword_color("static", _x5)
	_t23.add_keyword_color("enum", _x5)

	_t23.add_keyword_color("if", _z76)
	_t23.add_keyword_color("elif", _z76)
	_t23.add_keyword_color("else", _z76)
	_t23.add_keyword_color("for", _z76)
	_t23.add_keyword_color("while", _z76)
	_t23.add_keyword_color("match", _z76)
	_t23.add_keyword_color("return", _z76)
	_t23.add_keyword_color("pass", _z76)
	_t23.add_keyword_color("break", _z76)
	_t23.add_keyword_color("continue", _z76)
	_t23.add_keyword_color("await", _z76)
	_t23.add_keyword_color("yield", _z76)
	_t23.add_keyword_color("in", _z76)
	_t23.add_keyword_color("not", _z76)
	_t23.add_keyword_color("and", _z76)
	_t23.add_keyword_color("or", _z76)

	_t23.add_keyword_color("true", _z13)
	_t23.add_keyword_color("false", _z13)
	_t23.add_keyword_color("null", _z13)
	_t23.add_keyword_color("self", _z13)
	_t23.add_keyword_color("super", _z13)

	_t23.number_color = number_color
	_t23.symbol_color = symbol_color
	_t23.function_color = function_color
	_t23.member_variable_color = _l70

	return _t23

func _z45(_m27: String, _q84: Color) -> Color:
	if _q86:
		var _e45 = _q86.get_editor_settings()
		if _e45:
			var color = _e45.get_setting("text_editor/theme/highlighting/" + _m27)
			if color is Color:
				return color
	return _q84

func _c50() -> void:
	_a66.emit(_b36, {})

func _f72(action: StringName) -> void:
	if action == "reject":
		var _o23 = _u70(_j88.text)
		_e21.emit(_b36, _o23)
		hide()

func _w9() -> void:
	_e21.emit(_b36, "User cancelled the operation")

func _u83(label: Label) -> void:
	if _q86:
		var theme = _q86.get_editor_theme()
		if theme:
			var _y6 = theme.get_font("title", "EditorFonts")
			if _y6:
				label.add_theme_font_override("font", _y6)
			var _v91 = theme.get_font_size("title_size", "EditorFonts")
			if _v91 > 0:
				label.add_theme_font_size_override("font_size", _v91)
			return

	label.add_theme_font_size_override("font_size", 20)

func _m14(label: Label) -> void:
	if _q86:
		var theme = _q86.get_editor_theme()
		if theme:
			var _v82 = theme.get_font("main", "EditorFonts")
			if _v82:
				label.add_theme_font_override("font", _v82)
			var _b7 = theme.get_font_size("main_size", "EditorFonts")
			if _b7 > 0:
				label.add_theme_font_size_override("font_size", _b7)
			return

	label.add_theme_font_size_override("font_size", 14)

func _p45() -> Color:
	if _q86:
		var theme = _q86.get_editor_theme()
		if theme:
			var font_color = theme.get_color("font_color", "Editor")
			if font_color:
				return font_color.darkened(0.3)

			var _o61 = theme.get_color("font_disabled_color", "Editor")
			if _o61:
				return _o61

	return Color(0.7, 0.7, 0.7)

func _c77() -> int:
	if _q86:
		var theme = _q86.get_editor_theme()
		if theme:
			var size = theme.get_font_size("main_size", "EditorFonts")
			if size > 0:
				return size
	return 14

func _u70(_d61: String) -> String:
	if _d61 == null:
		return "User rejected without feedback"
	var text = _d61.strip_edges()
	if text.is_empty():
		return "User rejected without feedback"
	if text.length() > _n88:
		text = text.substr(0, _n88)

	text = text.replace(char(13), "").replace(char(0), "")
	return text

func _k63() -> void:
	if _z35 and is_instance_valid(_z35):
		_z35.queue_free()
		_z35 = null

	_b36 = {}

