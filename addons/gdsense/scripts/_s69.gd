@tool
class_name _o88
extends AcceptDialog
signal _w53(_b87: Dictionary, _s61: Dictionary)
signal _j69(_b87: Dictionary, _e1: String)
var _k54: Dictionary
var _k99: CodeEdit
var _y84: Label
var _j49: Button
var _o61: Label
var _a15: VBoxContainer
var _f21: EditorInterface
var _i72: TextEdit
var _g61: Label
const _x56 = 500
func _init() -> void:
	title = "Agent Action Approval"
	size = Vector2(900, 650)
	min_size = Vector2(700, 500)
	unresizable = false
	_j49 = add_button("Reject", false, "reject")
	confirmed.connect(_r34)
	custom_action.connect(_t7)
	canceled.connect(_b60)
func _o81(_i13: EditorInterface) -> void:
	_f21 = _i13
func _e35(_b87: Dictionary) -> void:
	_k54 = _b87
	if _a15 and is_instance_valid(_a15):
		_a15.queue_free()
	_a15 = VBoxContainer.new()
	_a15.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_a15.add_theme_constant_override("separation", 8)
	var _h10 = _b87.get("tool_name", "unknown")
	var description = _b87.get("description", "")
	match _h10:
		"create_file":
			title = "Create File"
			ok_button_text = "Create"
			_n8(_a15, _b87)
		"edit_file":
			title = "Edit File"
			ok_button_text = "Apply Changes"
			_b78(_a15, _b87)
		"delete_file":
			title = "Delete File"
			ok_button_text = "Delete"
			_x20(_a15, _b87)
		_:
			title = "Agent Action"
			ok_button_text = "Approve"
			_j64(_a15, _b87)
	_a15.add_child(HSeparator.new())
	_g61 = Label.new()
	_g61.text = "Rejection feedback (optional):"
	_w60(_g61)
	_a15.add_child(_g61)
	_i72 = TextEdit.new()
	_i72.placeholder_text = "Rejection only - e.g., 'Don't modify this file' or 'Try a different approach'"
	var font_size = _v7()
	_i72.custom_minimum_size = Vector2(font_size * 25, font_size * 4)
	_i72.scroll_fit_content_height = true
	_a15.add_child(_i72)
	add_child(_a15)
func _n8(_o30: VBoxContainer, _b87: Dictionary) -> void:
	var _j90 = _b87.get("parameters", {})
	if _j90 == null:
		_j90 = {}
	var path = _j90.get("path", "")
	if path == null:
		path = ""
	var content = _j90.get("content", "")
	if content == null:
		content = ""
	_y84 = Label.new()
	_y84.text = "File: " + path
	_m27(_y84)
	_o30.add_child(_y84)
	var _w52 = Label.new()
	_w52.text = "A new file will be created at this location."
	_w60(_w52)
	_w52.add_theme_color_override("font_color", _q42())
	_o30.add_child(_w52)
	_o30.add_child(HSeparator.new())
	var label = Label.new()
	label.text = "Content Preview:"
	_w60(label)
	_o30.add_child(label)
	_k99 = _l99()
	_k99.text = content
	_k99.custom_minimum_size = Vector2(850, 450)
	_o30.add_child(_k99)
func _b78(_o30: VBoxContainer, _b87: Dictionary) -> void:
	var _j90 = _b87.get("parameters", {})
	if _j90 == null:
		_j90 = {}
	var path = _j90.get("path", "")
	if path == null:
		path = ""
	var _e60 = _j90.get("old_string", "")
	if _e60 == null:
		_e60 = ""
	var _p94 = _j90.get("new_string", "")
	if _p94 == null:
		_p94 = ""
	var _b55 = _j90.get("replace_all", false)
	_y84 = Label.new()
	_y84.text = "File: " + path
	_m27(_y84)
	_o30.add_child(_y84)
	_o61 = Label.new()
	var _w15 = "Replace all occurrences" if _b55 else "Replace first occurrence"
	_o61.text = _w15 + " • A backup will be created"
	_w60(_o61)
	_o61.add_theme_color_override("font_color", Color.ORANGE)
	_o30.add_child(_o61)
	_o30.add_child(HSeparator.new())
	var _k79 = HSplitContainer.new()
	_k79.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_k79.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_k79.custom_minimum_size = Vector2(850, 400)
	var _l18 = VBoxContainer.new()
	_l18.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _z62 = Label.new()
	_z62.text = "Old (removing):"
	_z62.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_w60(_z62)
	_l18.add_child(_z62)
	var _d61 = _l99()
	_d61.text = _e60
	_d61.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _d42 = StyleBoxFlat.new()
	_d42.bg_color = Color(0.15, 0.08, 0.08)
	_d42.set_corner_radius_all(4)
	_d61.add_theme_stylebox_override("normal", _d42)
	_l18.add_child(_d61)
	_k79.add_child(_l18)
	var _f60 = VBoxContainer.new()
	_f60.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _q61 = Label.new()
	_q61.text = "New (adding):"
	_q61.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_w60(_q61)
	_f60.add_child(_q61)
	var _o16 = _l99()
	_o16.text = _p94
	_o16.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _y6 = StyleBoxFlat.new()
	_y6.bg_color = Color(0.08, 0.15, 0.08)
	_y6.set_corner_radius_all(4)
	_o16.add_theme_stylebox_override("normal", _y6)
	_f60.add_child(_o16)
	_k79.add_child(_f60)
	_o30.add_child(_k79)
	var _x44 = _e60.count("\n") + 1 if not _e60.is_empty() else 0
	var _b65 = _p94.count("\n") + 1 if not _p94.is_empty() else 0
	var _k77 = Label.new()
	_k77.text = "%d lines → %d lines" % [_x44, _b65]
	_k77.add_theme_color_override("font_color", _q42())
	_w60(_k77)
	_k77.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_o30.add_child(_k77)
func _x20(_o30: VBoxContainer, _b87: Dictionary) -> void:
	var _j90 = _b87.get("parameters", {})
	if _j90 == null:
		_j90 = {}
	var path = _j90.get("path", "")
	if path == null:
		path = ""
	_y84 = Label.new()
	_y84.text = "File: " + path
	_m27(_y84)
	_o30.add_child(_y84)
	_o30.add_child(HSeparator.new())
	var _j79 = Control.new()
	_j79.custom_minimum_size.y = 20
	_o30.add_child(_j79)
	_o61 = Label.new()
	_o61.text = "WARNING: This action cannot be undone!\nThe file will be permanently deleted."
	_o61.add_theme_color_override("font_color", Color.RED)
	_m27(_o61)  
	_o61.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_o30.add_child(_o61)
	var _b58 = Control.new()
	_b58.custom_minimum_size.y = 20
	_o30.add_child(_b58)
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var _l43 = file.get_length()
			file.close()
			var _w52 = Label.new()
			_w52.text = "File size: %d bytes" % _l43
			_w52.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_w60(_w52)  
			_o30.add_child(_w52)
func _j64(_o30: VBoxContainer, _b87: Dictionary) -> void:
	var _h10 = _b87.get("tool_name", "unknown")
	if _h10 == null:
		_h10 = "unknown"
	var _j90 = _b87.get("parameters", {})
	if _j90 == null:
		_j90 = {}
	var description = _b87.get("description", "")
	if description == null:
		description = ""
	var _s90 = Label.new()
	_s90.text = "Tool: " + _h10
	_m27(_s90)
	_o30.add_child(_s90)
	if not description.is_empty():
		var _j93 = Label.new()
		_j93.text = description
		_j93.add_theme_color_override("font_color", _q42())
		_w60(_j93)
		_o30.add_child(_j93)
	_o30.add_child(HSeparator.new())
	var _h2 = Label.new()
	_h2.text = "Parameters:"
	_w60(_h2)
	_o30.add_child(_h2)
	var _b91 = RichTextLabel.new()
	_b91.bbcode_enabled = true
	_b91.fit_content = true
	_b91.scroll_active = false
	_b91.selection_enabled = true
	_b91.custom_minimum_size = Vector2(650, 100)
	var _e49 = ""
	for _y40 in _j90.keys():
		var value = _j90.get(_y40, "")
		var _b88 = str(value)
		if _b88.length() > 100:
			_b88 = _b88.substr(0, 100) + "..."
		_e49 += "[b]%s:[/b] %s\n" % [_y40, _b88]
	_b91.text = _e49
	_o30.add_child(_b91)
func _l99() -> CodeEdit:
	var _v93 = CodeEdit.new()
	_v93.editable = false
	_v93.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_v93.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_v93.syntax_highlighter = _w23()
	_v93.gutters_draw_line_numbers = true
	_v93.scroll_smooth = true
	if _f21:
		var _f13 = _f21.get_editor_settings()
		if _f13:
			var bg_color = _f13.get_setting("text_editor/theme/highlighting/background_color")
			if bg_color:
				var _g43 = StyleBoxFlat.new()
				_g43.bg_color = bg_color
				_v93.add_theme_stylebox_override("normal", _g43)
	return _v93
func _w23() -> CodeHighlighter:
	var _w71 = CodeHighlighter.new()
	var _r31 = _y60("keyword_color", Color(0.96, 0.56, 0.56))
	var _q47 = _y60("control_flow_keyword_color", _r31)
	var _p70 = _y60("base_type_color", Color(0.56, 0.76, 0.96))
	var number_color = _y60("number_color", Color(0.56, 0.96, 0.76))
	var symbol_color = _y60("symbol_color", Color(0.8, 0.8, 0.8))
	var function_color = _y60("function_color", Color(0.56, 0.86, 0.96))
	var _a18 = _y60("member_variable_color", Color(0.76, 0.76, 0.96))
	_w71.add_keyword_color("func", _r31)
	_w71.add_keyword_color("var", _r31)
	_w71.add_keyword_color("const", _r31)
	_w71.add_keyword_color("class", _r31)
	_w71.add_keyword_color("class_name", _r31)
	_w71.add_keyword_color("extends", _r31)
	_w71.add_keyword_color("signal", _r31)
	_w71.add_keyword_color("static", _r31)
	_w71.add_keyword_color("enum", _r31)
	_w71.add_keyword_color("if", _q47)
	_w71.add_keyword_color("elif", _q47)
	_w71.add_keyword_color("else", _q47)
	_w71.add_keyword_color("for", _q47)
	_w71.add_keyword_color("while", _q47)
	_w71.add_keyword_color("match", _q47)
	_w71.add_keyword_color("return", _q47)
	_w71.add_keyword_color("pass", _q47)
	_w71.add_keyword_color("break", _q47)
	_w71.add_keyword_color("continue", _q47)
	_w71.add_keyword_color("await", _q47)
	_w71.add_keyword_color("yield", _q47)
	_w71.add_keyword_color("in", _q47)
	_w71.add_keyword_color("not", _q47)
	_w71.add_keyword_color("and", _q47)
	_w71.add_keyword_color("or", _q47)
	_w71.add_keyword_color("true", _p70)
	_w71.add_keyword_color("false", _p70)
	_w71.add_keyword_color("null", _p70)
	_w71.add_keyword_color("self", _p70)
	_w71.add_keyword_color("super", _p70)
	_w71.number_color = number_color
	_w71.symbol_color = symbol_color
	_w71.function_color = function_color
	_w71.member_variable_color = _a18
	return _w71
func _y60(_d60: String, _a92: Color) -> Color:
	if _f21:
		var _f13 = _f21.get_editor_settings()
		if _f13:
			var color = _f13.get_setting("text_editor/theme/highlighting/" + _d60)
			if color is Color:
				return color
	return _a92
func _r34() -> void:
	_w53.emit(_k54, {})
func _t7(action: StringName) -> void:
	if action == "reject":
		var _e1 = _d16(_i72.text)
		_j69.emit(_k54, _e1)
		hide()
func _b60() -> void:
	_j69.emit(_k54, "User cancelled the operation")
func _m27(label: Label) -> void:
	if _f21:
		var theme = _f21.get_editor_theme()
		if theme:
			var _y2 = theme.get_font("title", "EditorFonts")
			if _y2:
				label.add_theme_font_override("font", _y2)
			var _x29 = theme.get_font_size("title_size", "EditorFonts")
			if _x29 > 0:
				label.add_theme_font_size_override("font_size", _x29)
			return
	label.add_theme_font_size_override("font_size", 20)
func _w60(label: Label) -> void:
	if _f21:
		var theme = _f21.get_editor_theme()
		if theme:
			var _z33 = theme.get_font("main", "EditorFonts")
			if _z33:
				label.add_theme_font_override("font", _z33)
			var _g68 = theme.get_font_size("main_size", "EditorFonts")
			if _g68 > 0:
				label.add_theme_font_size_override("font_size", _g68)
			return
	label.add_theme_font_size_override("font_size", 14)
func _q42() -> Color:
	if _f21:
		var theme = _f21.get_editor_theme()
		if theme:
			var font_color = theme.get_color("font_color", "Editor")
			if font_color:
				return font_color.darkened(0.3)
			var _l42 = theme.get_color("font_disabled_color", "Editor")
			if _l42:
				return _l42
	return Color(0.7, 0.7, 0.7)
func _v7() -> int:
	if _f21:
		var theme = _f21.get_editor_theme()
		if theme:
			var size = theme.get_font_size("main_size", "EditorFonts")
			if size > 0:
				return size
	return 14
func _d16(_i31: String) -> String:
	if _i31 == null:
		return "User rejected without feedback"
	var text = _i31.strip_edges()
	if text.is_empty():
		return "User rejected without feedback"
	if text.length() > _x56:
		text = text.substr(0, _x56)
	text = text.replace(_q64(13), "").replace(_q64(0), "")
	return text
func _o36() -> void:
	if _a15 and is_instance_valid(_a15):
		_a15.queue_free()
		_a15 = null
	_k54 = {}
