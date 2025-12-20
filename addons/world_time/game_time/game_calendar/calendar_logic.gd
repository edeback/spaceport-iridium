# Handles runtime logic operations for a GameCalendar
class_name CalendarLogic
extends RefCounted

var _calendar_structure: CalendarStructure
var _time_date_calculator: TimeDateCalculator
var _week_manager: WeekManager
var _validator: CalendarValidator

var days_per_week: int
var start_day_of_week_index: int
var time_scale: TimeScale
var start_date: GameDate

# Constructor for initializing CalendarLogic
func _init(p_time_scale: TimeScale, p_start_date: GameDate, p_years: Array[GameYear], p_days_per_week: int, p_start_day_of_week_index: int) -> void:
	_calendar_structure = CalendarStructure.new(p_years)
	_time_date_calculator = TimeDateCalculator.new(p_time_scale, p_start_date, _calendar_structure)
	_validator = CalendarValidator.new(p_time_scale, _calendar_structure)
	_week_manager = WeekManager.new(_time_date_calculator, p_days_per_week, p_start_day_of_week_index)
	
	self.days_per_week = p_days_per_week
	self.start_day_of_week_index = p_start_day_of_week_index
	self.time_scale = p_time_scale
	self.start_date = p_start_date
	
	_week_manager.days_per_week = p_days_per_week
	_week_manager.start_day_of_week_index = p_start_day_of_week_index

	_validate_internal_state()

# Methods handling the calendar's runtime logic
func advance_date_time(p_start_date_time: DateTime, p_advance_seconds: float) -> DateTime:
	return _time_date_calculator.advance_date_time(p_start_date_time, p_advance_seconds)

## Get the next date from the current date, optionally change the resulting time to p_desired_time
func get_next_date_time(p_current : DateTime, p_desired_time : HoursTime = null) -> DateTime:
	return _time_date_calculator.get_next_date_time(p_current, p_desired_time)

func get_game_year(year_number: int) -> GameYear:
	return _calendar_structure.get_game_year(year_number)

func get_game_month(date: GameDate) -> GameMonth:
	return _calendar_structure.get_game_month(date)

func get_day_of_week_index(p_date: GameDate) -> int:
	return _week_manager.get_day_of_week_index(p_date)
	
func get_days_between(p_old : GameDate, p_new : GameDate) -> int:
	return _time_date_calculator.get_days_between(p_old, p_new)

## Gets the number of days that a GameDate is into it's year
func get_days_into_year(p_date : GameDate) -> int:
	return _calendar_structure.get_days_into_year(p_date)

## Gets the game seconds that represents the last time the p_moment occured, given a p_current_dt DateTime
func get_last_hours_time_as_secs(p_moment : HoursTime, p_current_dt : DateTime) -> float:
	return _time_date_calculator.get_last_hours_time_as_secs(p_moment, p_current_dt)
	
## Gets the DateTime that represents the last time the p_moment occured, given a p_current_dt DateTime
func get_last_hours_time_as_date_time(p_moment : HoursTime, p_current_dt : DateTime) -> DateTime:
	return _time_date_calculator.get_last_hours_time_as_date_time(p_moment, p_current_dt)

## Get the GameDate that comes directly after the passed p_date
func get_next_day(p_date : GameDate) -> GameDate:
	return _time_date_calculator.get_next_day(p_date)
	
func get_previous_date(p_date : GameDate) -> GameDate:
	return _time_date_calculator.get_previous_date(p_date)

# Gets the event day object for the given p_date GameDay, if any
func get_event_day(p_date : GameDate) -> EventDay:
	return _calendar_structure.get_event_day(p_date)

## Get the number of seconds that represents the start of a game date
func get_seconds_from_date(p_date : GameDate) -> float:
	return _time_date_calculator.get_seconds_from_date(p_date)
	
func validate_runtime() -> bool:
	return _validator.validate()

func get_scale() -> TimeScale:
	return _time_date_calculator.time_scale

func get_seconds_from_date_time(p_date_time: DateTime) -> float:
	return _time_date_calculator.get_seconds_from_date_time(p_date_time)

# Internal state validation
func _validate_internal_state() -> void:
	assert(_calendar_structure != null, "CalendarLogic: _calendar_structure was not initialized.")
	assert(_time_date_calculator != null, "CalendarLogic: _time_date_calculator was not initialized.")
	assert(_week_manager != null, "CalendarLogic: _week_manager was not initialized.")
	assert(_validator != null, "CalendarLogic: _validator was not initialized.")
