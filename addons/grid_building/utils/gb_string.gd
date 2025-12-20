class_name GBString

## Enum for separator types used in string utilities
enum SeparatorType {
	NONE = 0,
	SPACE = 1,
	UNDERSCORE = 2,
	DASH = 3
}

## Converts a Node.name to a human readable display_name string.
## Stops processing when it encounters the project's naming separator.[br][br]
## [code]p_node_name[/code]: [i]String[/i] - The node name to convert to readable format
static func convert_name_to_readable(p_node_name: String) -> String:
	var num_seperator = ProjectSettings.get_setting("editor/naming/node_name_num_separator")
	var separator_string = GBString.get_separator_string(num_seperator)
	var display_name: String = ""

	for char in p_node_name:
		if char == separator_string:
			break  # End because it hit the separator

		if char >= "A" && char <= "Z" && not display_name.is_empty():
			display_name += " "

		display_name += char

	return display_name

## Checks if a character matches the project's node name number separator setting.[br][br]
## [code]p_char[/code]: [i]String[/i] - The character to check[br]
## [code]p_seperator_enum[/code]: [i]int[/i] - The separator enum value from project settings
static func match_num_seperator(p_char: String, p_seperator_enum: int) -> bool:
	match p_seperator_enum:
		0:  # None
			return false
		1:  # Space
			return p_char.begins_with(" ")
		2:  # Underscore
			return p_char.begins_with("_")
		3:  # Dash
			return p_char.begins_with("-")
		_:
			push_error("Non existant enum Node Number Seperator %d" % p_seperator_enum)
			return false

## Gets the separator string for the given enum value.[br][br]
## [code]p_seperator_enum[/code]: [i]int[/i] - The separator enum value from project settings
static func get_separator_string(p_seperator_enum: int) -> String:
	match p_seperator_enum:
		0:  # None
			return ""
		1:  # Space
			return " "
		2:  # Underscore
			return "_"
		3:  # Dash
			return "-"
		_:
			push_error("Non existant enum Node Number Seperator %d" % p_seperator_enum)
			return ""
