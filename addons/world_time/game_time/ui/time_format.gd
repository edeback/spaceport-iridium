class_name TimeFormat
extends Resource

## Minimum number of digits to show for seconds, minute, hours time
@export var seconds = "%02d"
@export var minutes = "%02d"
@export var hours = "%02d"
@export var day = "%01d"
@export var month = "%01d"
@export var year = "%01d"
@export var time_seperator = ":"

## Format for showing GameDate
## Options {day} {month} {month_name} {year}
@export var date_format = "{day} / {month} / {year}"

## Format for showing HoursTime
## Options {hours} {minutes} {seconds}
@export var hours_time = "{hours} : {minutes} : {seconds} "

## Format for showing DateTime
## Options {day} {month} {month_name} {year} {hours} {minutes} {seconds}
@export var date_time_format = "{day} / {month} / {year} {hours} : {minutes} : {seconds}"

## Options {day} {month} {month_name} {year}
func get_formatted_date(p_date : GameDate, p_calendar : GameCalendar) -> String:
	var month_name : StringName = p_calendar.get_game_month(p_date).display_name
	var formatted = date_format.format({"day": day % p_date.day, "month": month % p_date.month, "year": year % p_date.year, "month_name": month_name})
	return formatted
