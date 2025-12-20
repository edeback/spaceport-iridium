class_name GameYear
extends Resource
## Defines the layout for a year of game time

@export var months : Array[GameMonth]

func _init(p_months : Array[GameMonth] = []):
	months = p_months

## Calculates and returns the number of days in a year by
## adding the days in each month
func get_days_count():
	if not validate_months(months): return
	
	var total : int = 0
	
	for month in months:
		total += month.days
	
	return total
	
## Uses the day to find the associated month in the year
## The day passed must be between 0 and the days in the year
func get_month_index_from_day(p_day_of_year : int):
	if not validate_day_of_year(p_day_of_year): return
	
	var day_remainder = p_day_of_year
	var month_num
	
	for i in range(0, months.size(), 1):
		var month = months[i]
		
		if(day_remainder <= month.days):
			month_num = i
			break
		
		day_remainder -= month.days
			
	if month_num < 0:
		push_error("Correct month index not found for day of year " + str(p_day_of_year))
		return
	
	return month_num
	
## Counts the number of days in all of the months that come before the specific month's index
func get_days_before_start_of_month(p_month_index : int) -> int:
	var days_before_month = 0
	
	for i in range(0, p_month_index, 1): # Do not count current month
		days_before_month += months[i].days
		
	return days_before_month

## Calculates the number of days into the game year thaat a month and day is
## Note::: that the first day of the month is 0 days into the month because it just started
## Returns the days calculation
func get_days_into_year(p_day_of_month : int, p_month_index : int) -> int:
	var days_into_month = p_day_of_month - 1
	var days_before_start_of_month = get_days_before_start_of_month(p_month_index)
	var days_into_year = days_before_start_of_month + days_into_month
	return days_into_year
	
func validate() -> bool:
	var no_problems = true
	
	if not validate_months(months):
		no_problems = false
	
	return no_problems
	
func validate_months(p_months : Array[GameMonth]) -> bool:
	var no_problems = true
	
	if p_months.is_empty():
		push_error("Months must be defined in game year. " + resource_path)
		no_problems = false
	
	
	for month_idx in months.size():
		var month : GameMonth = months[month_idx]
		
		if month == null:
			push_error("Null month at index %d" % month_idx)
			no_problems = false
		
	return no_problems

## Makes sure the day of the year actually exists in the year.
## [br][br]
## Returns true if it does or false if it doesn't.
func validate_day_of_year(p_day_of_year : int) -> bool:
	if p_day_of_year <= 0:
		return false
	if p_day_of_year > get_days_count():
		return false
		
	return true
