class_name WeekManager
extends RefCounted
## Manages day-of-week calculations.

var days_per_week: int = 7
var start_day_of_week_index: int = 0
var date_calculator: TimeDateCalculator

func _init(p_date_calculator: TimeDateCalculator, p_days_per_week : int, p_start_day_of_week_index : int):
	date_calculator = p_date_calculator
	days_per_week = p_days_per_week
	start_day_of_week_index = p_start_day_of_week_index

func get_day_of_week_index(p_date: GameDate) -> int:
	var day_number = date_calculator.get_days_between(date_calculator.start_date, p_date)
	var offset_day_number = day_number + start_day_of_week_index
	var array_pos = offset_day_number % days_per_week
	if array_pos < 0:
		array_pos += days_per_week
	return array_pos
