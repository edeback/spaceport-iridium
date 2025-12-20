## Name Displayer Resource
##
## A simple resource for displaying names in the manipulation system.
## Used for test configurations and UI display purposes.
class_name NameDisplayer
extends Resource

## The display name to show
@export var display_name: String = ""

## Whether to show the display name
@export var show_name: bool = true

## Font size for the display
@export var font_size: int = 12

## Text color for the display
@export var text_color: Color = Color.WHITE

func _init(p_display_name: String = "", p_show_name: bool = true, p_font_size: int = 12, p_text_color: Color = Color.WHITE) -> void:
	display_name = p_display_name
	show_name = p_show_name
	font_size = p_font_size
	text_color = p_text_color

## Get the formatted display name
func get_formatted_name() -> String:
	if not show_name or display_name.is_empty():
		return ""
	return "[%s]" % display_name

## Check if the displayer has a valid name to show
func has_valid_name() -> bool:
	return show_name and not display_name.is_empty()