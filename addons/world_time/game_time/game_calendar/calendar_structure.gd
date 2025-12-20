## Manages the structure of the game calendar, including years and months.
class_name CalendarStructure
extends RefCounted

## Cycle of years within the calendar. Loops after reaching end of array.
var years: Array[GameYear] = []

func _init(p_years : Array[GameYear]):
	years = p_years
	
	assert(not years.is_empty(), "CalendarStructure requires at least one game year.")

func set_years(p_years: Array[GameYear]) -> void:
	years = p_years

func get_days_into_year(p_date: GameDate) -> int:
	var game_year: GameYear = get_game_year(p_date.year)
	var days_occured = 0
	
	for month_index in range(0, p_date.month):
		var days_in_month = game_year.months[month_index].days
		if month_index == p_date.month - 1:
			days_occured += p_date.day
		else:
			days_occured += days_in_month
	
	return days_occured

func get_game_month(date: GameDate) -> GameMonth:
	var year: GameYear = get_game_year(date.year)
	return year.months[date.month - 1]

func get_game_year(year_number: int, start_year: int = 1) -> GameYear:
	var years_count = years.size()
	if years_count <= 0:
		return null
	var remainder = (year_number - start_year) % years_count
	if remainder < 0:
		remainder += years_count
	return years[remainder]

func get_days_until_end_of_year(p_date: GameDate) -> int:
	var game_year = get_game_year(p_date.year)
	var days_left = 0
	
	for month_index in range(p_date.month - 1, game_year.months.size()):
		var days_in_month = game_year.months[month_index].days
		days_left += days_in_month
		if month_index == p_date.month - 1:
			days_left -= p_date.day
			
	return days_left

func get_days_per_full_calendar_cycle() -> int:
	var total = 0
	for year in years:
		total += year.get_days_count()
	return total

func get_event_day(p_game_date: GameDate) -> EventDay:
	var month = get_game_month(p_game_date)
	if month.event_days.has(p_game_date.day):
		return month.event_days[p_game_date.day]
	return null
