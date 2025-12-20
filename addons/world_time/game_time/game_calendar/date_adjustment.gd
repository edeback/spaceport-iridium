## Used for calculating a new date from a calendar structure based on number of days to shift and direction.
class_name DateAdjustment
extends RefCounted

var start_date: GameDate
var adjusted_date: GameDate
var days_change: int
var direction: int # Sign direction +/- 1
var calendar_structure: CalendarStructure
var _remaining: int

func _init(p_start_date: GameDate, p_days_change: int, p_calendar_structure: CalendarStructure):
	start_date = p_start_date
	days_change = p_days_change
	direction = sign(p_days_change)
	calendar_structure = p_calendar_structure
	adjusted_date = start_date
	_remaining = 0

## Calculates an adjusted date using the stored calendar structure and this object's parameters.
## Returns and sets adjusted_date after calculation.
func calculate_adjusted() -> GameDate:
	_remaining = abs(days_change)
	adjusted_date = start_date
	_adjust_to_start_of_year()
	_adjust_by_calendar_cycles()
	_adjust_by_years()
	_adjust_by_months()
	_adjust_by_days()
	return adjusted_date

## Adjusts the date to the start of the year, accounting for direction.
func _adjust_to_start_of_year() -> void:
	var days_into_year = calendar_structure.get_days_into_year(adjusted_date) - 1 # Account for start of year
	_remaining += days_into_year * direction
	adjusted_date = GameDate.new(1, 1, adjusted_date.year)

## Quickly jumps over entire calendar cycles with simple math.
func _adjust_by_calendar_cycles() -> void:
	var total_cal_days: int = 0
	var total_cal_years: int = 0
	
	for year in calendar_structure.years:
		total_cal_days += year.get_days_count()
		total_cal_years += 1
	
	var total_cycles_to_jump: int = _remaining / total_cal_days
	adjusted_date.year += total_cycles_to_jump * total_cal_years * direction
	_remaining -= total_cycles_to_jump * total_cal_days

## Adjusts years by _remaining days until the following year does not fit into the _remainder days.
func _adjust_by_years() -> void:
	var days_of_year = 0
	
	while days_of_year < _remaining:
		var current_year = calendar_structure.get_game_year(adjusted_date.year)
		days_of_year = current_year.get_days_count()
		
		if days_of_year <= _remaining || sign(direction) == -1: # When traveling negative, _remaining should end negative before adjusting for months
			adjusted_date.year += 1 * direction
			_remaining -= days_of_year
			
	_remaining = abs(_remaining) # Ensure remaining days are positive for months/days functions

## Adjusts months by _remaining days until the following month does not fit into the _remainder days.
## Should be called after _adjust_by_years.
func _adjust_by_months() -> void:
	var year = calendar_structure.get_game_year(adjusted_date.year)
	for month in year.months:
		var month_days = month.days
		
		if _remaining >= month_days:
			_remaining -= month_days
			adjusted_date.month += 1
		else:
			break

## Adds _remaining days to the date.
## Should be called after _adjust_by_months.
func _adjust_by_days() -> void:
	adjusted_date.day += _remaining
	_remaining = 0

## Returns whether all days have been handled in the latest calculation for adjusted date.
func is_finished() -> bool:
	return _remaining == 0