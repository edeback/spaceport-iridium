class_name CalendarValidator
extends RefCounted
## Handles validation of dates, times, and calendar structure.

var time_scale: TimeScale
var calendar_structure: CalendarStructure

func _init(p_time_scale: TimeScale, p_calendar_structure: CalendarStructure):
	time_scale = p_time_scale
	calendar_structure = p_calendar_structure

## Check a 
func validate_hours_time(p_time: HoursTime) -> bool:
	var hours_per_day = time_scale.hours_per_day
	var minutes_per_hour = time_scale.minutes_per_hour
	var seconds_per_minute = time_scale.seconds_per_minute
	var no_validation_errors = true
	
	if p_time.hours < 0 || p_time.hours >= hours_per_day:
		no_validation_errors = false
	if p_time.minutes < 0 || p_time.minutes > minutes_per_hour:
		no_validation_errors = false
	if p_time.seconds < 0 || p_time.seconds > seconds_per_minute:
		no_validation_errors = false
	return no_validation_errors

## Validates the calendars current state and returns whether it is valid or not
## Pushes an error for any issues it finds, as those need to be resolved.
func validate() -> bool:
	var issues : Array[String] = []
	if calendar_structure.years.is_empty():
		issues.append("Years was constructed without any game years at %" % self)
	for year in calendar_structure.years:
		if year.months.is_empty():
			issues.append("Year %s has no game months defined." % year)
			
	for issue in issues:
		push_error(issue)
		
	return issues.is_empty()

func validate_date(p_game_date: GameDate) -> bool:
	var game_year = calendar_structure.get_game_year(p_game_date.year)
	return p_game_date.is_valid_date(game_year)

func validate_date_time(p_date_time: DateTime) -> bool:
	var valid_date = validate_date(p_date_time.date)
	var valid_time = validate_hours_time(p_date_time.time)
	return valid_date && valid_time
