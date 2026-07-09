@tool
class_name _p74
extends AcceptDialog
signal _d45(_t3: Dictionary, _x97: Dictionary)
signal _n39(_t3: Dictionary, _m26: String)
var _m33: Dictionary
var _x75: CodeEdit
var _h4: Label
var _g39: Button
var _d88: Label
var _y28: VBoxContainer
var _w27: EditorInterface
var _s81: TextEdit
var _a30: Label
const _z96 = 500
func _init() -> void:
	title = "Agent Action Approval"
	size = Vector2(900, 650)
	min_size = Vector2(700, 500)
	unresizable = false
	_g39 = add_button("Reject", false, "reject")
	confirmed.connect(_z7)
	custom_action.connect(_p58)
	canceled.connect(_w43)
func _i71(_d84: EditorInterface) -> void:
	_w27 = _d84
func _z41(_t3: Dictionary) -> void:
	_m33 = _t3
	if _y28 and is_instance_valid(_y28):
		_y28.queue_free()
	_y28 = VBoxContainer.new()
	_y28.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_y28.add_theme_constant_override("separation", 8)
	var _c79 = _t3.get("tool_name", "unknown")
	var description = _t3.get("description", "")
	match _c79:
		"create_file":
			title = "Create File"
			ok_button_text = "Create"
			_t21(_y28, _t3)
		"edit_file":
			title = "Edit File"
			ok_button_text = "Apply Changes"
			_i88(_y28, _t3)
		"delete_file":
			title = "Delete File"
			ok_button_text = "Delete"
			_f34(_y28, _t3)
		_:
			title = "Agent Action"
			ok_button_text = "Approve"
			_p14(_y28, _t3)
	_y28.add_child(HSeparator.new())
	_a30 = Label.new()
	_a30.text = "Rejection feedback (optional):"
	_z91(_a30)
	_y28.add_child(_a30)
	_s81 = TextEdit.new()
	_s81.placeholder_text = "Rejection only - e.g., 'Don't modify this file' or 'Try a different approach'"
	var font_size = _b8()
	_s81.custom_minimum_size = Vector2(font_size * 25, font_size * 4)
	_s81.scroll_fit_content_height = true
	_y28.add_child(_s81)
	add_child(_y28)
func _t21(_t7: VBoxContainer, _t3: Dictionary) -> void:
	var _x22 = _t3.get("parameters", {})
	if _x22 == null:
		_x22 = {}
	var path = _x22.get("path", "")
	if path == null:
		path = ""
	var content = _x22.get("content", "")
	if content == null:
		content = ""
	_h4 = Label.new()
	_h4.text = "File: " + path
	_b19(_h4)
	_t7.add_child(_h4)
	var _g69 = Label.new()
	_g69.text = "A new file will be created at this location."
	_z91(_g69)
	_g69.add_theme_color_override("font_color", _w21())
	_t7.add_child(_g69)
	_t7.add_child(HSeparator.new())
	var label = Label.new()
	label.text = "Content Preview:"
	_z91(label)
	_t7.add_child(label)
	_x75 = _i39()
	_x75.text = content
	_x75.custom_minimum_size = Vector2(850, 450)
	_t7.add_child(_x75)
func _i88(_t7: VBoxContainer, _t3: Dictionary) -> void:
	var _x22 = _t3.get("parameters", {})
	if _x22 == null:
		_x22 = {}
	var path = _x22.get("path", "")
	if path == null:
		path = ""
	var _l54 = _x22.get("old_string", "")
	if _l54 == null:
		_l54 = ""
	var _i95 = _x22.get("new_string", "")
	if _i95 == null:
		_i95 = ""
	var _j95 = _x22.get("replace_all", false)
	_h4 = Label.new()
	_h4.text = "File: " + path
	_b19(_h4)
	_t7.add_child(_h4)
	_d88 = Label.new()
	var _e34 = "Replace all occurrences" if _j95 else "Replace first occurrence"
	_d88.text = _e34 + " • A backup will be created"
	_z91(_d88)
	_d88.add_theme_color_override("font_color", Color.ORANGE)
	_t7.add_child(_d88)
	_t7.add_child(HSeparator.new())
	var _q76 = HSplitContainer.new()
	_q76.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q76.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_q76.custom_minimum_size = Vector2(850, 400)
	var _w60 = VBoxContainer.new()
	_w60.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _v31 = Label.new()
	_v31.text = "Old (removing):"
	_v31.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_z91(_v31)
	_w60.add_child(_v31)
	var _y95 = _i39()
	_y95.text = _l54
	_y95.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _e79 = StyleBoxFlat.new()
	_e79.bg_color = Color(0.15, 0.08, 0.08)
	_e79.set_corner_radius_all(4)
	_y95.add_theme_stylebox_override("normal", _e79)
	_w60.add_child(_y95)
	_q76.add_child(_w60)
	var _h98 = VBoxContainer.new()
	_h98.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _w32 = Label.new()
	_w32.text = "New (adding):"
	_w32.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_z91(_w32)
	_h98.add_child(_w32)
	var _v29 = _i39()
	_v29.text = _i95
	_v29.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _b63 = StyleBoxFlat.new()
	_b63.bg_color = Color(0.08, 0.15, 0.08)
	_b63.set_corner_radius_all(4)
	_v29.add_theme_stylebox_override("normal", _b63)
	_h98.add_child(_v29)
	_q76.add_child(_h98)
	_t7.add_child(_q76)
	var _x88 = _l54.count("\n") + 1 if not _l54.is_empty() else 0
	var _m32 = _i95.count("\n") + 1 if not _i95.is_empty() else 0
	var _x82 = Label.new()
	_x82.text = "%d lines → %d lines" % [_x88, _m32]
	_x82.add_theme_color_override("font_color", _w21())
	_z91(_x82)
	_x82.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_t7.add_child(_x82)
func _f34(_t7: VBoxContainer, _t3: Dictionary) -> void:
	var _x22 = _t3.get("parameters", {})
	if _x22 == null:
		_x22 = {}
	var path = _x22.get("path", "")
	if path == null:
		path = ""
	_h4 = Label.new()
	_h4.text = "File: " + path
	_b19(_h4)
	_t7.add_child(_h4)
	_t7.add_child(HSeparator.new())
	var _m9 = Control.new()
	_m9.custom_minimum_size.y = 20
	_t7.add_child(_m9)
	_d88 = Label.new()
	_d88.text = "WARNING: This action cannot be undone!\nThe file will be permanently deleted."
	_d88.add_theme_color_override("font_color", Color.RED)
	_b19(_d88)  
	_d88.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_t7.add_child(_d88)
	var _b15 = Control.new()
	_b15.custom_minimum_size.y = 20
	_t7.add_child(_b15)
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var _b65 = file.get_length()
			file.close()
			var _g69 = Label.new()
			_g69.text = "File size: %d bytes" % _b65
			_g69.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_z91(_g69)  
			_t7.add_child(_g69)
func _p14(_t7: VBoxContainer, _t3: Dictionary) -> void:
	var _c79 = _t3.get("tool_name", "unknown")
	if _c79 == null:
		_c79 = "unknown"
	var _x22 = _t3.get("parameters", {})
	if _x22 == null:
		_x22 = {}
	var description = _t3.get("description", "")
	if description == null:
		description = ""
	var _k49 = Label.new()
	_k49.text = "Tool: " + _c79
	_b19(_k49)
	_t7.add_child(_k49)
	if not description.is_empty():
		var _p52 = Label.new()
		_p52.text = description
		_p52.add_theme_color_override("font_color", _w21())
		_z91(_p52)
		_t7.add_child(_p52)
	_t7.add_child(HSeparator.new())
	var _c30 = Label.new()
	_c30.text = "Parameters:"
	_z91(_c30)
	_t7.add_child(_c30)
	var _p40 = RichTextLabel.new()
	_p40.bbcode_enabled = true
	_p40.fit_content = true
	_p40.scroll_active = false
	_p40.selection_enabled = true
	_p40.custom_minimum_size = Vector2(650, 100)
	var _t32 = ""
	for _j26 in _x22.keys():
		var value = _x22.get(_j26, "")
		var _u30 = str(value)
		if _u30.length() > 100:
			_u30 = _u30.substr(0, 100) + "..."
		_t32 += "[b]%s:[/b] %s\n" % [_j26, _u30]
	_p40.text = _t32
	_t7.add_child(_p40)
func _i39() -> CodeEdit:
	var _x7 = CodeEdit.new()
	_x7.editable = false
	_x7.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_x7.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_x7.syntax_highlighter = _a45()
	_x7.gutters_draw_line_numbers = true
	_x7.scroll_smooth = true
	if _w27:
		var _r43 = _w27.get_editor_settings()
		if _r43:
			var bg_color = _r43.get_setting("text_editor/theme/highlighting/background_color")
			if bg_color:
				var _b2 = StyleBoxFlat.new()
				_b2.bg_color = bg_color
				_x7.add_theme_stylebox_override("normal", _b2)
	return _x7
func _a45() -> CodeHighlighter:
	var _b73 = CodeHighlighter.new()
	var _w58 = _q27("keyword_color", Color(0.96, 0.56, 0.56))
	var _w71 = _q27("control_flow_keyword_color", _w58)
	var _a74 = _q27("base_type_color", Color(0.56, 0.76, 0.96))
	var number_color = _q27("number_color", Color(0.56, 0.96, 0.76))
	var symbol_color = _q27("symbol_color", Color(0.8, 0.8, 0.8))
	var function_color = _q27("function_color", Color(0.56, 0.86, 0.96))
	var _w38 = _q27("member_variable_color", Color(0.76, 0.76, 0.96))
	_b73.add_keyword_color("func", _w58)
	_b73.add_keyword_color("var", _w58)
	_b73.add_keyword_color("const", _w58)
	_b73.add_keyword_color("class", _w58)
	_b73.add_keyword_color("class_name", _w58)
	_b73.add_keyword_color("extends", _w58)
	_b73.add_keyword_color("signal", _w58)
	_b73.add_keyword_color("static", _w58)
	_b73.add_keyword_color("enum", _w58)
	_b73.add_keyword_color("if", _w71)
	_b73.add_keyword_color("elif", _w71)
	_b73.add_keyword_color("else", _w71)
	_b73.add_keyword_color("for", _w71)
	_b73.add_keyword_color("while", _w71)
	_b73.add_keyword_color("match", _w71)
	_b73.add_keyword_color("return", _w71)
	_b73.add_keyword_color("pass", _w71)
	_b73.add_keyword_color("break", _w71)
	_b73.add_keyword_color("continue", _w71)
	_b73.add_keyword_color("await", _w71)
	_b73.add_keyword_color("yield", _w71)
	_b73.add_keyword_color("in", _w71)
	_b73.add_keyword_color("not", _w71)
	_b73.add_keyword_color("and", _w71)
	_b73.add_keyword_color("or", _w71)
	_b73.add_keyword_color("true", _a74)
	_b73.add_keyword_color("false", _a74)
	_b73.add_keyword_color("null", _a74)
	_b73.add_keyword_color("self", _a74)
	_b73.add_keyword_color("super", _a74)
	_b73.number_color = number_color
	_b73.symbol_color = symbol_color
	_b73.function_color = function_color
	_b73.member_variable_color = _w38
	return _b73
func _q27(_x48: String, _d49: Color) -> Color:
	if _w27:
		var _r43 = _w27.get_editor_settings()
		if _r43:
			var color = _r43.get_setting("text_editor/theme/highlighting/" + _x48)
			if color is Color:
				return color
	return _d49
func _z7() -> void:
	_d45.emit(_m33, {})
func _p58(action: StringName) -> void:
	if action == "reject":
		var _m26 = _e68(_s81.text)
		_n39.emit(_m33, _m26)
		hide()
func _w43() -> void:
	_n39.emit(_m33, "User cancelled the operation")
func _b19(label: Label) -> void:
	if _w27:
		var theme = _w27.get_editor_theme()
		if theme:
			var _i37 = theme.get_font("title", "EditorFonts")
			if _i37:
				label.add_theme_font_override("font", _i37)
			var _q93 = theme.get_font_size("title_size", "EditorFonts")
			if _q93 > 0:
				label.add_theme_font_size_override("font_size", _q93)
			return
	label.add_theme_font_size_override("font_size", 20)
func _z91(label: Label) -> void:
	if _w27:
		var theme = _w27.get_editor_theme()
		if theme:
			var _t98 = theme.get_font("main", "EditorFonts")
			if _t98:
				label.add_theme_font_override("font", _t98)
			var _f25 = theme.get_font_size("main_size", "EditorFonts")
			if _f25 > 0:
				label.add_theme_font_size_override("font_size", _f25)
			return
	label.add_theme_font_size_override("font_size", 14)
func _w21() -> Color:
	if _w27:
		var theme = _w27.get_editor_theme()
		if theme:
			var font_color = theme.get_color("font_color", "Editor")
			if font_color:
				return font_color.darkened(0.3)
			var _u64 = theme.get_color("font_disabled_color", "Editor")
			if _u64:
				return _u64
	return Color(0.7, 0.7, 0.7)
func _b8() -> int:
	if _w27:
		var theme = _w27.get_editor_theme()
		if theme:
			var size = theme.get_font_size("main_size", "EditorFonts")
			if size > 0:
				return size
	return 14
func _e68(_j23: String) -> String:
	if _j23 == null:
		return "User rejected without feedback"
	var text = _j23.strip_edges()
	if text.is_empty():
		return "User rejected without feedback"
	if text.length() > _z96:
		text = text.substr(0, _z96)
	text = text.replace("\r", "").replace("\\x00", "")
	return text
func _q60() -> void:
	if _y28 and is_instance_valid(_y28):
		_y28.queue_free()
		_y28 = null
	_m33 = {}
