@tool
class_name _o22
extends AcceptDialog

signal _u32(_z7: Dictionary, _v42: Dictionary)
signal _y81(_z7: Dictionary, _g45: String)

var _n44: Dictionary
var _g46: CodeEdit
var _y51: Label
var _q37: Button
var _g80: Label
var _g78: VBoxContainer
var _z76: EditorInterface
var _d78: TextEdit
var _i55: Label
const _k2 = 500

func _init() -> void:
	title = "Agent Action Approval"
	size = Vector2(900, 650)
	min_size = Vector2(700, 500)
	unresizable = false

	_q37 = add_button("Reject", false, "reject")

	confirmed.connect(_h42)
	custom_action.connect(_k11)
	canceled.connect(_i77)

func _a87(_i86: EditorInterface) -> void:
	_z76 = _i86

func _u41(_z7: Dictionary) -> void:
	_n44 = _z7

	if _g78 and is_instance_valid(_g78):
		_g78.queue_free()

	_g78 = VBoxContainer.new()
	_g78.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g78.add_theme_constant_override("separation", 8)

	var _w25 = _z7.get("tool_name", "unknown")
	var description = _z7.get("description", "")

	match _w25:
		"create_file":
			title = "Create File"
			ok_button_text = "Create"
			_o56(_g78, _z7)
		"edit_file":
			title = "Edit File"
			ok_button_text = "Apply Changes"
			_x43(_g78, _z7)
		"delete_file":
			title = "Delete File"
			ok_button_text = "Delete"
			_e83(_g78, _z7)
		_:
			title = "Agent Action"
			ok_button_text = "Approve"
			_d27(_g78, _z7)

	_g78.add_child(HSeparator.new())

	_i55 = Label.new()
	_i55.text = "Rejection feedback (optional):"
	_i6(_i55)
	_g78.add_child(_i55)

	_d78 = TextEdit.new()
	_d78.placeholder_text = "Rejection only - e.g., 'Don't modify this file' or 'Try a different approach'"
	var font_size = _b74()
	_d78.custom_minimum_size = Vector2(font_size * 25, font_size * 4)
	_d78.scroll_fit_content_height = true
	_g78.add_child(_d78)

	add_child(_g78)

func _o56(_i69: VBoxContainer, _z7: Dictionary) -> void:
	var _o82 = _z7.get("parameters", {})
	if _o82 == null:
		_o82 = {}
	var path = _o82.get("path", "")
	if path == null:
		path = ""
	var content = _o82.get("content", "")
	if content == null:
		content = ""

	_y51 = Label.new()
	_y51.text = "File: " + path
	_h29(_y51)
	_i69.add_child(_y51)

	var _w12 = Label.new()
	_w12.text = "A new file will be created at this location."
	_i6(_w12)
	_w12.add_theme_color_override("font_color", _t77())
	_i69.add_child(_w12)

	_i69.add_child(HSeparator.new())

	var label = Label.new()
	label.text = "Content Preview:"
	_i6(label)
	_i69.add_child(label)

	_g46 = _f6()
	_g46.text = content
	_g46.custom_minimum_size = Vector2(850, 450)
	_i69.add_child(_g46)

func _x43(_i69: VBoxContainer, _z7: Dictionary) -> void:
	var _o82 = _z7.get("parameters", {})
	if _o82 == null:
		_o82 = {}
	var path = _o82.get("path", "")
	if path == null:
		path = ""
	var _q28 = _o82.get("old_string", "")
	if _q28 == null:
		_q28 = ""
	var _d70 = _o82.get("new_string", "")
	if _d70 == null:
		_d70 = ""
	var _b30 = _o82.get("replace_all", false)

	_y51 = Label.new()
	_y51.text = "File: " + path
	_h29(_y51)
	_i69.add_child(_y51)

	_g80 = Label.new()
	var _b4 = "Replace all occurrences" if _b30 else "Replace first occurrence"
	_g80.text = _b4 + " • A backup will be created"
	_i6(_g80)
	_g80.add_theme_color_override("font_color", Color.ORANGE)
	_i69.add_child(_g80)

	_i69.add_child(HSeparator.new())

	var _y35 = HSplitContainer.new()
	_y35.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_y35.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_y35.custom_minimum_size = Vector2(850, 400)

	var _e40 = VBoxContainer.new()
	_e40.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _z55 = Label.new()
	_z55.text = "Old (removing):"
	_z55.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_i6(_z55)
	_e40.add_child(_z55)

	var _o29 = _f6()
	_o29.text = _q28
	_o29.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var _z38 = StyleBoxFlat.new()
	_z38.bg_color = Color(0.15, 0.08, 0.08)
	_z38.set_corner_radius_all(4)
	_o29.add_theme_stylebox_override("normal", _z38)
	_e40.add_child(_o29)

	_y35.add_child(_e40)

	var _m60 = VBoxContainer.new()
	_m60.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _j6 = Label.new()
	_j6.text = "New (adding):"
	_j6.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_i6(_j6)
	_m60.add_child(_j6)

	var _f13 = _f6()
	_f13.text = _d70
	_f13.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var _g97 = StyleBoxFlat.new()
	_g97.bg_color = Color(0.08, 0.15, 0.08)
	_g97.set_corner_radius_all(4)
	_f13.add_theme_stylebox_override("normal", _g97)
	_m60.add_child(_f13)

	_y35.add_child(_m60)

	_i69.add_child(_y35)

	var _h25 = _q28.count("\n") + 1 if not _q28.is_empty() else 0
	var _e19 = _d70.count("\n") + 1 if not _d70.is_empty() else 0
	var _u19 = Label.new()
	_u19.text = "%d lines → %d lines" % [_h25, _e19]
	_u19.add_theme_color_override("font_color", _t77())
	_i6(_u19)
	_u19.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_i69.add_child(_u19)

func _e83(_i69: VBoxContainer, _z7: Dictionary) -> void:
	var _o82 = _z7.get("parameters", {})
	if _o82 == null:
		_o82 = {}
	var path = _o82.get("path", "")
	if path == null:
		path = ""

	_y51 = Label.new()
	_y51.text = "File: " + path
	_h29(_y51)
	_i69.add_child(_y51)

	_i69.add_child(HSeparator.new())

	var _f90 = Control.new()
	_f90.custom_minimum_size.y = 20
	_i69.add_child(_f90)

	_g80 = Label.new()
	_g80.text = "WARNING: This action cannot be undone!\nThe file will be permanently deleted."
	_g80.add_theme_color_override("font_color", Color.RED)
	_h29(_g80)  
	_g80.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_i69.add_child(_g80)

	var _b98 = Control.new()
	_b98.custom_minimum_size.y = 20
	_i69.add_child(_b98)

	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var _q1 = file.get_length()
			file.close()

			var _w12 = Label.new()
			_w12.text = "File size: %d bytes" % _q1
			_w12.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_i6(_w12)  
			_i69.add_child(_w12)

func _d27(_i69: VBoxContainer, _z7: Dictionary) -> void:
	var _w25 = _z7.get("tool_name", "unknown")
	if _w25 == null:
		_w25 = "unknown"
	var _o82 = _z7.get("parameters", {})
	if _o82 == null:
		_o82 = {}
	var description = _z7.get("description", "")
	if description == null:
		description = ""

	var _e99 = Label.new()
	_e99.text = "Tool: " + _w25
	_h29(_e99)
	_i69.add_child(_e99)

	if not description.is_empty():
		var _x67 = Label.new()
		_x67.text = description
		_x67.add_theme_color_override("font_color", _t77())
		_i6(_x67)
		_i69.add_child(_x67)

	_i69.add_child(HSeparator.new())

	var _x69 = Label.new()
	_x69.text = "Parameters:"
	_i6(_x69)
	_i69.add_child(_x69)

	var _x68 = RichTextLabel.new()
	_x68.bbcode_enabled = true
	_x68.fit_content = true
	_x68.scroll_active = false
	_x68.selection_enabled = true
	_x68.custom_minimum_size = Vector2(650, 100)

	var _o55 = ""
	for _m15 in _o82.keys():
		var value = _o82.get(_m15, "")
		var _t66 = str(value)
		if _t66.length() > 100:
			_t66 = _t66.substr(0, 100) + "..."
		_o55 += "[b]%s:[/b] %s\n" % [_m15, _t66]

	_x68.text = _o55
	_i69.add_child(_x68)

func _f6() -> CodeEdit:
	var _o58 = CodeEdit.new()
	_o58.editable = false
	_o58.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o58.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_o58.syntax_highlighter = _h80()
	_o58.gutters_draw_line_numbers = true
	_o58.scroll_smooth = true

	if _z76:
		var _f80 = _z76.get_editor_settings()
		if _f80:
			var bg_color = _f80.get_setting("text_editor/theme/highlighting/background_color")
			if bg_color:
				var _f54 = StyleBoxFlat.new()
				_f54.bg_color = bg_color
				_o58.add_theme_stylebox_override("normal", _f54)

	return _o58

func _h80() -> CodeHighlighter:
	var _z4 = CodeHighlighter.new()

	var _r65 = _x34("keyword_color", Color(0.96, 0.56, 0.56))
	var _v93 = _x34("control_flow_keyword_color", _r65)
	var _i91 = _x34("base_type_color", Color(0.56, 0.76, 0.96))
	var number_color = _x34("number_color", Color(0.56, 0.96, 0.76))
	var symbol_color = _x34("symbol_color", Color(0.8, 0.8, 0.8))
	var function_color = _x34("function_color", Color(0.56, 0.86, 0.96))
	var _l41 = _x34("member_variable_color", Color(0.76, 0.76, 0.96))

	_z4.add_keyword_color("func", _r65)
	_z4.add_keyword_color("var", _r65)
	_z4.add_keyword_color("const", _r65)
	_z4.add_keyword_color("class", _r65)
	_z4.add_keyword_color("class_name", _r65)
	_z4.add_keyword_color("extends", _r65)
	_z4.add_keyword_color("signal", _r65)
	_z4.add_keyword_color("static", _r65)
	_z4.add_keyword_color("enum", _r65)

	_z4.add_keyword_color("if", _v93)
	_z4.add_keyword_color("elif", _v93)
	_z4.add_keyword_color("else", _v93)
	_z4.add_keyword_color("for", _v93)
	_z4.add_keyword_color("while", _v93)
	_z4.add_keyword_color("match", _v93)
	_z4.add_keyword_color("return", _v93)
	_z4.add_keyword_color("pass", _v93)
	_z4.add_keyword_color("break", _v93)
	_z4.add_keyword_color("continue", _v93)
	_z4.add_keyword_color("await", _v93)
	_z4.add_keyword_color("yield", _v93)
	_z4.add_keyword_color("in", _v93)
	_z4.add_keyword_color("not", _v93)
	_z4.add_keyword_color("and", _v93)
	_z4.add_keyword_color("or", _v93)

	_z4.add_keyword_color("true", _i91)
	_z4.add_keyword_color("false", _i91)
	_z4.add_keyword_color("null", _i91)
	_z4.add_keyword_color("self", _i91)
	_z4.add_keyword_color("super", _i91)

	_z4.number_color = number_color
	_z4.symbol_color = symbol_color
	_z4.function_color = function_color
	_z4.member_variable_color = _l41

	return _z4

func _x34(_x33: String, _e66: Color) -> Color:
	if _z76:
		var _f80 = _z76.get_editor_settings()
		if _f80:
			var color = _f80.get_setting("text_editor/theme/highlighting/" + _x33)
			if color is Color:
				return color
	return _e66

func _h42() -> void:
	_u32.emit(_n44, {})

func _k11(action: StringName) -> void:
	if action == "reject":
		var _g45 = _u4(_d78.text)
		_y81.emit(_n44, _g45)
		hide()

func _i77() -> void:
	_y81.emit(_n44, "User cancelled the operation")

func _h29(label: Label) -> void:
	if _z76:
		var theme = _z76.get_editor_theme()
		if theme:
			var _b27 = theme.get_font("title", "EditorFonts")
			if _b27:
				label.add_theme_font_override("font", _b27)
			var _t96 = theme.get_font_size("title_size", "EditorFonts")
			if _t96 > 0:
				label.add_theme_font_size_override("font_size", _t96)
			return

	label.add_theme_font_size_override("font_size", 20)

func _i6(label: Label) -> void:
	if _z76:
		var theme = _z76.get_editor_theme()
		if theme:
			var _c10 = theme.get_font("main", "EditorFonts")
			if _c10:
				label.add_theme_font_override("font", _c10)
			var _d85 = theme.get_font_size("main_size", "EditorFonts")
			if _d85 > 0:
				label.add_theme_font_size_override("font_size", _d85)
			return

	label.add_theme_font_size_override("font_size", 14)

func _t77() -> Color:
	if _z76:
		var theme = _z76.get_editor_theme()
		if theme:
			var font_color = theme.get_color("font_color", "Editor")
			if font_color:
				return font_color.darkened(0.3)

			var _b46 = theme.get_color("font_disabled_color", "Editor")
			if _b46:
				return _b46

	return Color(0.7, 0.7, 0.7)

func _b74() -> int:
	if _z76:
		var theme = _z76.get_editor_theme()
		if theme:
			var size = theme.get_font_size("main_size", "EditorFonts")
			if size > 0:
				return size
	return 14

func _u4(_i83: String) -> String:
	if _i83 == null:
		return "User rejected without feedback"
	var text = _i83.strip_edges()
	if text.is_empty():
		return "User rejected without feedback"
	if text.length() > _k2:
		text = text.substr(0, _k2)

	text = text.replace(char(13), "").replace(char(0), "")
	return text

func _o76() -> void:
	if _g78 and is_instance_valid(_g78):
		_g78.queue_free()
		_g78 = null

	_n44 = {}

