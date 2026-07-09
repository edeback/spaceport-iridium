@tool
class_name _y3
extends AcceptDialog
signal _s24(_m7: Dictionary, _e21: Dictionary)
signal _h32(_m7: Dictionary, _q64: String)
var _q14: Dictionary
var _e83: CodeEdit
var _o35: Label
var _h47: Button
var _x89: Label
var _v19: VBoxContainer
var _r15: EditorInterface
var _t19: TextEdit
var _w68: Label
const _q44 = 500
func _init() -> void:
	title = "Agent Action Approval"
	size = Vector2(900, 650)
	min_size = Vector2(700, 500)
	unresizable = false
	_h47 = add_button("Reject", false, "reject")
	confirmed.connect(_g43)
	custom_action.connect(_w25)
	canceled.connect(_d59)
func _r95(_k71: EditorInterface) -> void:
	_r15 = _k71
func _p55(_m7: Dictionary) -> void:
	_q14 = _m7
	if _v19 and is_instance_valid(_v19):
		_v19.queue_free()
	_v19 = VBoxContainer.new()
	_v19.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_v19.add_theme_constant_override("separation", 8)
	var _u36 = _m7.get("tool_name", "unknown")
	var description = _m7.get("description", "")
	match _u36:
		"create_file":
			title = "Create File"
			ok_button_text = "Create"
			_w89(_v19, _m7)
		"edit_file":
			title = "Edit File"
			ok_button_text = "Apply Changes"
			_c42(_v19, _m7)
		"delete_file":
			title = "Delete File"
			ok_button_text = "Delete"
			_f5(_v19, _m7)
		_:
			title = "Agent Action"
			ok_button_text = "Approve"
			_b96(_v19, _m7)
	_v19.add_child(HSeparator.new())
	_w68 = Label.new()
	_w68.text = "Rejection feedback (optional):"
	_y52(_w68)
	_v19.add_child(_w68)
	_t19 = TextEdit.new()
	_t19.placeholder_text = "Rejection only - e.g., 'Don't modify this file' or 'Try a different approach'"
	var font_size = _s98()
	_t19.custom_minimum_size = Vector2(font_size * 25, font_size * 4)
	_t19.scroll_fit_content_height = true
	_v19.add_child(_t19)
	add_child(_v19)
func _w89(_c71: VBoxContainer, _m7: Dictionary) -> void:
	var _o53 = _m7.get("parameters", {})
	if _o53 == null:
		_o53 = {}
	var path = _o53.get("path", "")
	if path == null:
		path = ""
	var content = _o53.get("content", "")
	if content == null:
		content = ""
	_o35 = Label.new()
	_o35.text = "File: " + path
	_c100(_o35)
	_c71.add_child(_o35)
	var _i49 = Label.new()
	_i49.text = "A new file will be created at this location."
	_y52(_i49)
	_i49.add_theme_color_override("font_color", _f38())
	_c71.add_child(_i49)
	_c71.add_child(HSeparator.new())
	var label = Label.new()
	label.text = "Content Preview:"
	_y52(label)
	_c71.add_child(label)
	_e83 = _a82()
	_e83.text = content
	_e83.custom_minimum_size = Vector2(850, 450)
	_c71.add_child(_e83)
func _c42(_c71: VBoxContainer, _m7: Dictionary) -> void:
	var _o53 = _m7.get("parameters", {})
	if _o53 == null:
		_o53 = {}
	var path = _o53.get("path", "")
	if path == null:
		path = ""
	var _r65 = _o53.get("old_string", "")
	if _r65 == null:
		_r65 = ""
	var _k92 = _o53.get("new_string", "")
	if _k92 == null:
		_k92 = ""
	var _b46 = _o53.get("replace_all", false)
	_o35 = Label.new()
	_o35.text = "File: " + path
	_c100(_o35)
	_c71.add_child(_o35)
	_x89 = Label.new()
	var _r98 = "Replace all occurrences" if _b46 else "Replace first occurrence"
	_x89.text = _r98 + " • A backup will be created"
	_y52(_x89)
	_x89.add_theme_color_override("font_color", Color.ORANGE)
	_c71.add_child(_x89)
	_c71.add_child(HSeparator.new())
	var _i16 = HSplitContainer.new()
	_i16.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_i16.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_i16.custom_minimum_size = Vector2(850, 400)
	var _o68 = VBoxContainer.new()
	_o68.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _n48 = Label.new()
	_n48.text = "Old (removing):"
	_n48.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_y52(_n48)
	_o68.add_child(_n48)
	var _j23 = _a82()
	_j23.text = _r65
	_j23.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _n86 = StyleBoxFlat.new()
	_n86.bg_color = Color(0.15, 0.08, 0.08)
	_n86.set_corner_radius_all(4)
	_j23.add_theme_stylebox_override("normal", _n86)
	_o68.add_child(_j23)
	_i16.add_child(_o68)
	var _w87 = VBoxContainer.new()
	_w87.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _w9 = Label.new()
	_w9.text = "New (adding):"
	_w9.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_y52(_w9)
	_w87.add_child(_w9)
	var _r96 = _a82()
	_r96.text = _k92
	_r96.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _w46 = StyleBoxFlat.new()
	_w46.bg_color = Color(0.08, 0.15, 0.08)
	_w46.set_corner_radius_all(4)
	_r96.add_theme_stylebox_override("normal", _w46)
	_w87.add_child(_r96)
	_i16.add_child(_w87)
	_c71.add_child(_i16)
	var _t53 = _r65.count("\n") + 1 if not _r65.is_empty() else 0
	var _l63 = _k92.count("\n") + 1 if not _k92.is_empty() else 0
	var _z55 = Label.new()
	_z55.text = "%d lines → %d lines" % [_t53, _l63]
	_z55.add_theme_color_override("font_color", _f38())
	_y52(_z55)
	_z55.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_c71.add_child(_z55)
func _f5(_c71: VBoxContainer, _m7: Dictionary) -> void:
	var _o53 = _m7.get("parameters", {})
	if _o53 == null:
		_o53 = {}
	var path = _o53.get("path", "")
	if path == null:
		path = ""
	_o35 = Label.new()
	_o35.text = "File: " + path
	_c100(_o35)
	_c71.add_child(_o35)
	_c71.add_child(HSeparator.new())
	var _t25 = Control.new()
	_t25.custom_minimum_size.y = 20
	_c71.add_child(_t25)
	_x89 = Label.new()
	_x89.text = "WARNING: This action cannot be undone!\nThe file will be permanently deleted."
	_x89.add_theme_color_override("font_color", Color.RED)
	_c100(_x89)  
	_x89.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_c71.add_child(_x89)
	var _y60 = Control.new()
	_y60.custom_minimum_size.y = 20
	_c71.add_child(_y60)
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var _q43 = file.get_length()
			file.close()
			var _i49 = Label.new()
			_i49.text = "File size: %d bytes" % _q43
			_i49.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_y52(_i49)  
			_c71.add_child(_i49)
func _b96(_c71: VBoxContainer, _m7: Dictionary) -> void:
	var _u36 = _m7.get("tool_name", "unknown")
	if _u36 == null:
		_u36 = "unknown"
	var _o53 = _m7.get("parameters", {})
	if _o53 == null:
		_o53 = {}
	var description = _m7.get("description", "")
	if description == null:
		description = ""
	var _y15 = Label.new()
	_y15.text = "Tool: " + _u36
	_c100(_y15)
	_c71.add_child(_y15)
	if not description.is_empty():
		var _l52 = Label.new()
		_l52.text = description
		_l52.add_theme_color_override("font_color", _f38())
		_y52(_l52)
		_c71.add_child(_l52)
	_c71.add_child(HSeparator.new())
	var _y95 = Label.new()
	_y95.text = "Parameters:"
	_y52(_y95)
	_c71.add_child(_y95)
	var _f26 = RichTextLabel.new()
	_f26.bbcode_enabled = true
	_f26.fit_content = true
	_f26.scroll_active = false
	_f26.selection_enabled = true
	_f26.custom_minimum_size = Vector2(650, 100)
	var _s72 = ""
	for _i19 in _o53.keys():
		var value = _o53.get(_i19, "")
		var _c5 = str(value)
		if _c5.length() > 100:
			_c5 = _c5.substr(0, 100) + "..."
		_s72 += "[b]%s:[/b] %s\n" % [_i19, _c5]
	_f26.text = _s72
	_c71.add_child(_f26)
func _a82() -> CodeEdit:
	var _j81 = CodeEdit.new()
	_j81.editable = false
	_j81.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j81.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_j81.syntax_highlighter = _u47()
	_j81.gutters_draw_line_numbers = true
	_j81.scroll_smooth = true
	if _r15:
		var _a74 = _r15.get_editor_settings()
		if _a74:
			var bg_color = _a74.get_setting("text_editor/theme/highlighting/background_color")
			if bg_color:
				var _z56 = StyleBoxFlat.new()
				_z56.bg_color = bg_color
				_j81.add_theme_stylebox_override("normal", _z56)
	return _j81
func _u47() -> CodeHighlighter:
	var _v67 = CodeHighlighter.new()
	var _k73 = _q60("keyword_color", Color(0.96, 0.56, 0.56))
	var _k79 = _q60("control_flow_keyword_color", _k73)
	var _t95 = _q60("base_type_color", Color(0.56, 0.76, 0.96))
	var number_color = _q60("number_color", Color(0.56, 0.96, 0.76))
	var symbol_color = _q60("symbol_color", Color(0.8, 0.8, 0.8))
	var function_color = _q60("function_color", Color(0.56, 0.86, 0.96))
	var _t31 = _q60("member_variable_color", Color(0.76, 0.76, 0.96))
	_v67.add_keyword_color("func", _k73)
	_v67.add_keyword_color("var", _k73)
	_v67.add_keyword_color("const", _k73)
	_v67.add_keyword_color("class", _k73)
	_v67.add_keyword_color("class_name", _k73)
	_v67.add_keyword_color("extends", _k73)
	_v67.add_keyword_color("signal", _k73)
	_v67.add_keyword_color("static", _k73)
	_v67.add_keyword_color("enum", _k73)
	_v67.add_keyword_color("if", _k79)
	_v67.add_keyword_color("elif", _k79)
	_v67.add_keyword_color("else", _k79)
	_v67.add_keyword_color("for", _k79)
	_v67.add_keyword_color("while", _k79)
	_v67.add_keyword_color("match", _k79)
	_v67.add_keyword_color("return", _k79)
	_v67.add_keyword_color("pass", _k79)
	_v67.add_keyword_color("break", _k79)
	_v67.add_keyword_color("continue", _k79)
	_v67.add_keyword_color("await", _k79)
	_v67.add_keyword_color("yield", _k79)
	_v67.add_keyword_color("in", _k79)
	_v67.add_keyword_color("not", _k79)
	_v67.add_keyword_color("and", _k79)
	_v67.add_keyword_color("or", _k79)
	_v67.add_keyword_color("true", _t95)
	_v67.add_keyword_color("false", _t95)
	_v67.add_keyword_color("null", _t95)
	_v67.add_keyword_color("self", _t95)
	_v67.add_keyword_color("super", _t95)
	_v67.number_color = number_color
	_v67.symbol_color = symbol_color
	_v67.function_color = function_color
	_v67.member_variable_color = _t31
	return _v67
func _q60(_p65: String, _x74: Color) -> Color:
	if _r15:
		var _a74 = _r15.get_editor_settings()
		if _a74:
			var color = _a74.get_setting("text_editor/theme/highlighting/" + _p65)
			if color is Color:
				return color
	return _x74
func _g43() -> void:
	_s24.emit(_q14, {})
func _w25(action: StringName) -> void:
	if action == "reject":
		var _q64 = _x52(_t19.text)
		_h32.emit(_q14, _q64)
		hide()
func _d59() -> void:
	_h32.emit(_q14, "User cancelled the operation")
func _c100(label: Label) -> void:
	if _r15:
		var theme = _r15.get_editor_theme()
		if theme:
			var _x79 = theme.get_font("title", "EditorFonts")
			if _x79:
				label.add_theme_font_override("font", _x79)
			var _u25 = theme.get_font_size("title_size", "EditorFonts")
			if _u25 > 0:
				label.add_theme_font_size_override("font_size", _u25)
			return
	label.add_theme_font_size_override("font_size", 20)
func _y52(label: Label) -> void:
	if _r15:
		var theme = _r15.get_editor_theme()
		if theme:
			var _m13 = theme.get_font("main", "EditorFonts")
			if _m13:
				label.add_theme_font_override("font", _m13)
			var _y76 = theme.get_font_size("main_size", "EditorFonts")
			if _y76 > 0:
				label.add_theme_font_size_override("font_size", _y76)
			return
	label.add_theme_font_size_override("font_size", 14)
func _f38() -> Color:
	if _r15:
		var theme = _r15.get_editor_theme()
		if theme:
			var font_color = theme.get_color("font_color", "Editor")
			if font_color:
				return font_color.darkened(0.3)
			var _y8 = theme.get_color("font_disabled_color", "Editor")
			if _y8:
				return _y8
	return Color(0.7, 0.7, 0.7)
func _s98() -> int:
	if _r15:
		var theme = _r15.get_editor_theme()
		if theme:
			var size = theme.get_font_size("main_size", "EditorFonts")
			if size > 0:
				return size
	return 14
func _x52(_d66: String) -> String:
	if _d66 == null:
		return "User rejected without feedback"
	var text = _d66.strip_edges()
	if text.is_empty():
		return "User rejected without feedback"
	if text.length() > _q44:
		text = text.substr(0, _q44)
	text = text.replace(char(13), "").replace(char(0), "")
	return text
func _u75() -> void:
	if _v19 and is_instance_valid(_v19):
		_v19.queue_free()
		_v19 = null
	_q14 = {}
