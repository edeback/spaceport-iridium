class_name GameDate
extends Resource
## Represents the day, month, and year for gameplay needs

## The day of the month
@export_range(0, 30, 1, "or_greater") var day : int = 1

## The month of the year
@export_range(0, 12, 1, "or_greater") var month : int = 1

## The year number for the given date
@export_range(0, 10000, 1, "or_greater") var year : int = 1

func _init(p_day = 1, p_month = 1, p_year = 1):
	day = p_day
	month = p_month
	year = p_year

## Checks day, month, year on both GameDates to see if they have the same values
##
## Returns true if the same in all cases
func is_same_date(p_date : GameDate) -> bool:
	var same_day = day == p_date.day
	var same_month = month == p_date.month
	var same_year = year == p_date.year
	return same_day && same_month && same_year

## Count the total number of days that the date represents
func get_days_count(game_year : GameYear) -> int:
	return year * game_year.get_days_count() + game_year.get_days_into_year(day, month)

## Determine whether the game date is valid for a given game year
func is_valid_date(p_game_year : GameYear) -> bool:
	var error_free = true
	var month_i = month - 1
	var month_days
	
	if month_i < p_game_year.months.size():
		month_days = p_game_year.months[month_i].days

	if month_days == null :
		push_error("Month " + str(month) + " is not within game year " + p_game_year.resource_name + " : Year months count : " + str(p_game_year.months.size()))
		error_free = false
	elif day < 0 || day > month_days:
		push_error("Day is not between valid month days of 0 && " + str(month_days) + " Actual: " + str(day))
		error_free = false
	
	return error_free

## Converts the date to a dictionary for saving
## Returns a dictionary with the day, month, and year
func to_dict() -> Dictionary:
	return {
		"day" : day,
		"month" : month,
		"year" : year
	}

## Loads a dictionary state into the date object
func from_dict(p_state : Dictionary) -> void:
	if p_state.has("day"):
		day = p_state["day"]
	else:
		push_error("Day state is null on " + str(get_path))
	if p_state.has("month"):
		month = p_state["month"]
	else:
		push_error("Month state is null on " + str(get_path))
	if p_state.has("year"):
		year = p_state["year"]
	else:
		push_error("Year state is null on " + str(get_path))

## Returns the date as a formatted string based on p_format settings
func as_formatted(p_format : TimeFormat) -> String:
	return p_format.date_format.format({"day" : day, "month" : month, "year" : year})
