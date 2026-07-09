@tool
class_name _v33
extends AcceptDialog

signal _s25(_d59: Dictionary, _x97: Dictionary)
signal _o44(_d59: Dictionary, _x68: String)

var _b51: Dictionary
var _t70: CodeEdit
var _a50: Label
var _a35: Button
var _k80: Label
var _g69: VBoxContainer
var _b58: EditorInterface
var _x37: TextEdit
var _x26: Label
const _j92 = 500

func _init() -> void:
	title = "Agent Action Approval"
	size = Vector2(900, 650)
	min_size = Vector2(700, 500)
	unresizable = false

	_a35 = add_button("Reject", false, "reject")

	confirmed.connect(_e81)
	custom_action.connect(_i83)
	canceled.connect(_t20)

func _h21(_f28: EditorInterface) -> void:
	_b58 = _f28

func _t12(_d59: Dictionary) -> void:
	_b51 = _d59

	if _g69 and is_instance_valid(_g69):
		_g69.queue_free()

	_g69 = VBoxContainer.new()
	_g69.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g69.add_theme_constant_override("separation", 8)

	var _i10 = _d59.get("tool_name", "unknown")
	var description = _d59.get("description", "")

	match _i10:
		"create_file":
			title = "Create File"
			ok_button_text = "Create"
			_g26(_g69, _d59)
		"edit_file":
			title = "Edit File"
			ok_button_text = "Apply Changes"
			_k72(_g69, _d59)
		"delete_file":
			title = "Delete File"
			ok_button_text = "Delete"
			_k62(_g69, _d59)
		_:
			title = "Agent Action"
			ok_button_text = "Approve"
			_t17(_g69, _d59)

	_g69.add_child(HSeparator.new())

	_x26 = Label.new()
	_x26.text = "Rejection feedback (optional):"
	_v43(_x26)
	_g69.add_child(_x26)

	_x37 = TextEdit.new()
	_x37.placeholder_text = "Rejection only - e.g., 'Don't modify this file' or 'Try a different approach'"
	var font_size = _x7()
	_x37.custom_minimum_size = Vector2(font_size * 25, font_size * 4)
	_x37.scroll_fit_content_height = true
	_g69.add_child(_x37)

	add_child(_g69)

func _g26(_x14: VBoxContainer, _d59: Dictionary) -> void:
	var _x13 = _d59.get("parameters", {})
	if _x13 == null:
		_x13 = {}
	var path = _x13.get("path", "")
	if path == null:
		path = ""
	var content = _x13.get("content", "")
	if content == null:
		content = ""

	_a50 = Label.new()
	_a50.text = "File: " + path
	_d33(_a50)
	_x14.add_child(_a50)

	var _z87 = Label.new()
	_z87.text = "A new file will be created at this location."
	_v43(_z87)
	_z87.add_theme_color_override("font_color", _b24())
	_x14.add_child(_z87)

	_x14.add_child(HSeparator.new())

	var label = Label.new()
	label.text = "Content Preview:"
	_v43(label)
	_x14.add_child(label)

	_t70 = _y30()
	_t70.text = content
	_t70.custom_minimum_size = Vector2(850, 450)
	_x14.add_child(_t70)

func _k72(_x14: VBoxContainer, _d59: Dictionary) -> void:
	var _x13 = _d59.get("parameters", {})
	if _x13 == null:
		_x13 = {}
	var path = _x13.get("path", "")
	if path == null:
		path = ""
	var _h19 = _x13.get("old_string", "")
	if _h19 == null:
		_h19 = ""
	var _a82 = _x13.get("new_string", "")
	if _a82 == null:
		_a82 = ""
	var _t87 = _x13.get("replace_all", false)

	_a50 = Label.new()
	_a50.text = "File: " + path
	_d33(_a50)
	_x14.add_child(_a50)

	_k80 = Label.new()
	var _b10 = "Replace all occurrences" if _t87 else "Replace first occurrence"
	_k80.text = _b10 + " • A backup will be created"
	_v43(_k80)
	_k80.add_theme_color_override("font_color", Color.ORANGE)
	_x14.add_child(_k80)

	_x14.add_child(HSeparator.new())

	var _x4 = HSplitContainer.new()
	_x4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_x4.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_x4.custom_minimum_size = Vector2(850, 400)

	var _k90 = VBoxContainer.new()
	_k90.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _g82 = Label.new()
	_g82.text = "Old (removing):"
	_g82.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_v43(_g82)
	_k90.add_child(_g82)

	var _p85 = _y30()
	_p85.text = _h19
	_p85.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var _e23 = StyleBoxFlat.new()
	_e23.bg_color = Color(0.15, 0.08, 0.08)
	_e23.set_corner_radius_all(4)
	_p85.add_theme_stylebox_override("normal", _e23)
	_k90.add_child(_p85)

	_x4.add_child(_k90)

	var _j18 = VBoxContainer.new()
	_j18.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _y54 = Label.new()
	_y54.text = "New (adding):"
	_y54.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_v43(_y54)
	_j18.add_child(_y54)

	var _j94 = _y30()
	_j94.text = _a82
	_j94.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var _x54 = StyleBoxFlat.new()
	_x54.bg_color = Color(0.08, 0.15, 0.08)
	_x54.set_corner_radius_all(4)
	_j94.add_theme_stylebox_override("normal", _x54)
	_j18.add_child(_j94)

	_x4.add_child(_j18)

	_x14.add_child(_x4)

	var _y33 = _h19.count("\n") + 1 if not _h19.is_empty() else 0
	var _o79 = _a82.count("\n") + 1 if not _a82.is_empty() else 0
	var _a41 = Label.new()
	_a41.text = "%d lines → %d lines" % [_y33, _o79]
	_a41.add_theme_color_override("font_color", _b24())
	_v43(_a41)
	_a41.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_x14.add_child(_a41)

func _k62(_x14: VBoxContainer, _d59: Dictionary) -> void:
	var _x13 = _d59.get("parameters", {})
	if _x13 == null:
		_x13 = {}
	var path = _x13.get("path", "")
	if path == null:
		path = ""

	_a50 = Label.new()
	_a50.text = "File: " + path
	_d33(_a50)
	_x14.add_child(_a50)

	_x14.add_child(HSeparator.new())

	var _w33 = Control.new()
	_w33.custom_minimum_size.y = 20
	_x14.add_child(_w33)

	_k80 = Label.new()
	_k80.text = "WARNING: This action cannot be undone!\nThe file will be permanently deleted."
	_k80.add_theme_color_override("font_color", Color.RED)
	_d33(_k80)  
	_k80.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_x14.add_child(_k80)

	var _u79 = Control.new()
	_u79.custom_minimum_size.y = 20
	_x14.add_child(_u79)

	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var _g9 = file.get_length()
			file.close()

			var _z87 = Label.new()
			_z87.text = "File size: %d bytes" % _g9
			_z87.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_v43(_z87)  
			_x14.add_child(_z87)

func _t17(_x14: VBoxContainer, _d59: Dictionary) -> void:
	var _i10 = _d59.get("tool_name", "unknown")
	if _i10 == null:
		_i10 = "unknown"
	var _x13 = _d59.get("parameters", {})
	if _x13 == null:
		_x13 = {}
	var description = _d59.get("description", "")
	if description == null:
		description = ""

	var _m36 = Label.new()
	_m36.text = "Tool: " + _i10
	_d33(_m36)
	_x14.add_child(_m36)

	if not description.is_empty():
		var _u44 = Label.new()
		_u44.text = description
		_u44.add_theme_color_override("font_color", _b24())
		_v43(_u44)
		_x14.add_child(_u44)

	_x14.add_child(HSeparator.new())

	var _c43 = Label.new()
	_c43.text = "Parameters:"
	_v43(_c43)
	_x14.add_child(_c43)

	var _c98 = RichTextLabel.new()
	_c98.bbcode_enabled = true
	_c98.fit_content = true
	_c98.scroll_active = false
	_c98.selection_enabled = true
	_c98.custom_minimum_size = Vector2(650, 100)

	var _e38 = ""
	for _t90 in _x13.keys():
		var value = _x13.get(_t90, "")
		var _x70 = str(value)
		if _x70.length() > 100:
			_x70 = _x70.substr(0, 100) + "..."
		_e38 += "[b]%s:[/b] %s\n" % [_t90, _x70]

	_c98.text = _e38
	_x14.add_child(_c98)

func _y30() -> CodeEdit:
	var _v78 = CodeEdit.new()
	_v78.editable = false
	_v78.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_v78.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_v78.syntax_highlighter = _d57()
	_v78.gutters_draw_line_numbers = true
	_v78.scroll_smooth = true

	if _b58:
		var _x61 = _b58.get_editor_settings()
		if _x61:
			var bg_color = _x61.get_setting("text_editor/theme/highlighting/background_color")
			if bg_color:
				var _j88 = StyleBoxFlat.new()
				_j88.bg_color = bg_color
				_v78.add_theme_stylebox_override("normal", _j88)

	return _v78

func _d57() -> CodeHighlighter:
	var _n12 = CodeHighlighter.new()

	var _m78 = _k29("keyword_color", Color(0.96, 0.56, 0.56))
	var _a9 = _k29("control_flow_keyword_color", _m78)
	var _o82 = _k29("base_type_color", Color(0.56, 0.76, 0.96))
	var number_color = _k29("number_color", Color(0.56, 0.96, 0.76))
	var symbol_color = _k29("symbol_color", Color(0.8, 0.8, 0.8))
	var function_color = _k29("function_color", Color(0.56, 0.86, 0.96))
	var _p12 = _k29("member_variable_color", Color(0.76, 0.76, 0.96))

	_n12.add_keyword_color("func", _m78)
	_n12.add_keyword_color("var", _m78)
	_n12.add_keyword_color("const", _m78)
	_n12.add_keyword_color("class", _m78)
	_n12.add_keyword_color("class_name", _m78)
	_n12.add_keyword_color("extends", _m78)
	_n12.add_keyword_color("signal", _m78)
	_n12.add_keyword_color("static", _m78)
	_n12.add_keyword_color("enum", _m78)

	_n12.add_keyword_color("if", _a9)
	_n12.add_keyword_color("elif", _a9)
	_n12.add_keyword_color("else", _a9)
	_n12.add_keyword_color("for", _a9)
	_n12.add_keyword_color("while", _a9)
	_n12.add_keyword_color("match", _a9)
	_n12.add_keyword_color("return", _a9)
	_n12.add_keyword_color("pass", _a9)
	_n12.add_keyword_color("break", _a9)
	_n12.add_keyword_color("continue", _a9)
	_n12.add_keyword_color("await", _a9)
	_n12.add_keyword_color("yield", _a9)
	_n12.add_keyword_color("in", _a9)
	_n12.add_keyword_color("not", _a9)
	_n12.add_keyword_color("and", _a9)
	_n12.add_keyword_color("or", _a9)

	_n12.add_keyword_color("true", _o82)
	_n12.add_keyword_color("false", _o82)
	_n12.add_keyword_color("null", _o82)
	_n12.add_keyword_color("self", _o82)
	_n12.add_keyword_color("super", _o82)

	_n12.number_color = number_color
	_n12.symbol_color = symbol_color
	_n12.function_color = function_color
	_n12.member_variable_color = _p12

	return _n12

func _k29(_f61: String, _r96: Color) -> Color:
	if _b58:
		var _x61 = _b58.get_editor_settings()
		if _x61:
			var color = _x61.get_setting("text_editor/theme/highlighting/" + _f61)
			if color is Color:
				return color
	return _r96

func _e81() -> void:
	_s25.emit(_b51, {})

func _i83(action: StringName) -> void:
	if action == "reject":
		var _x68 = _t36(_x37.text)
		_o44.emit(_b51, _x68)
		hide()

func _t20() -> void:
	_o44.emit(_b51, "User cancelled the operation")

func _d33(label: Label) -> void:
	if _b58:
		var theme = _b58.get_editor_theme()
		if theme:
			var _f81 = theme.get_font("title", "EditorFonts")
			if _f81:
				label.add_theme_font_override("font", _f81)
			var _u94 = theme.get_font_size("title_size", "EditorFonts")
			if _u94 > 0:
				label.add_theme_font_size_override("font_size", _u94)
			return

	label.add_theme_font_size_override("font_size", 20)

func _v43(label: Label) -> void:
	if _b58:
		var theme = _b58.get_editor_theme()
		if theme:
			var _z38 = theme.get_font("main", "EditorFonts")
			if _z38:
				label.add_theme_font_override("font", _z38)
			var _a54 = theme.get_font_size("main_size", "EditorFonts")
			if _a54 > 0:
				label.add_theme_font_size_override("font_size", _a54)
			return

	label.add_theme_font_size_override("font_size", 14)

func _b24() -> Color:
	if _b58:
		var theme = _b58.get_editor_theme()
		if theme:
			var font_color = theme.get_color("font_color", "Editor")
			if font_color:
				return font_color.darkened(0.3)

			var _v91 = theme.get_color("font_disabled_color", "Editor")
			if _v91:
				return _v91

	return Color(0.7, 0.7, 0.7)

func _x7() -> int:
	if _b58:
		var theme = _b58.get_editor_theme()
		if theme:
			var size = theme.get_font_size("main_size", "EditorFonts")
			if size > 0:
				return size
	return 14

func _t36(_h70: String) -> String:
	if _h70 == null:
		return "User rejected without feedback"
	var text = _h70.strip_edges()
	if text.is_empty():
		return "User rejected without feedback"
	if text.length() > _j92:
		text = text.substr(0, _j92)
	text = text.replace("\r", "").replace("\\x00", "")
	return text

func _q17() -> void:
	if _g69 and is_instance_valid(_g69):
		_g69.queue_free()
		_g69 = null

	_b51 = {}
