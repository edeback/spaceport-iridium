class_name MonthTableSettings
extends Resource
## Settings for a MonthTable UI display

## Setup so that first day of your 'week' is the first item in the array
@export var column_titles : Array[String] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

## Whether to show the event day titles in the text of the tree item or not
@export var append_event_day_titles = false

## Wrapper for the event day number text. %d will be replaced with the day number
@export var event_day_number_text = "[%d]"

@export var current_day_bg_color = Color("#711131")
