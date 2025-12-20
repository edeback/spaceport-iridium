## Handles conversions between units of game time
class_name GameCalendar
extends Resource

## UI-friendly display name for the calender resource
@export var display_name : StringName = &""

## The year objects that the calendar represents. After reaching the end
## of the years array, years will be recycled in sequence. Must
## have a minumum of one game year defined for the calendar to function.
@export var years: Array[GameYear] = [] :
	set(value):
		years = value
		
		if years.is_empty():
			push_warning("Game calendar %s must have at least one game year set." % resource_name)

@export var days_per_week: int = 7

## The array index that the first day of the week starts at
@export var start_day_of_week_index: int = 0

## Defines the conversions between time units.
@export var time_scale: TimeScale = TimeScale.new()

var start_date = GameDate.new(1, 1, 1) :
	set(value):
		if not is_instance_valid(start_date):
			start_date = value
			notify_property_list_changed()
		else:
			push_error("Start date is read-only and cannot be changed after the script starts.")

# Private _calendar_logic variable that will be lazily initialized
var CalendarLogic := load("uid://csjbu3feao827")

func _init(p_years : Array[GameYear] = [], p_time_scale : TimeScale = null):
	if not p_years.is_empty():
		years = p_years
		
	if p_time_scale:
		time_scale = p_time_scale

var _calendar_logic: CalendarLogic : 
	get:
		if _calendar_logic == null: # Lazy initialization. Intended for game runtime.
			assert(years.size() > 0, "Calendar logic requires the years to have at least one year set to function.")
			_calendar_logic = CalendarLogic.new(time_scale, start_date, years, days_per_week, start_day_of_week_index)
			
		return _calendar_logic

## Progress the time by a number of game seconds
func advance_date_time(p_start_date_time: DateTime, p_advance_seconds: float) -> DateTime:
	return _calendar_logic.advance_date_time(p_start_date_time, p_advance_seconds)

## Get the GameYear object associated with the year number
func get_game_year(year_number: int) -> GameYear:
	return _calendar_logic.get_game_year(year_number)

## Get the Game Month associated with the current GameDate (Year / Month values)
func get_game_month(date: GameDate) -> GameMonth:
	return _calendar_logic.get_game_month(date)
	
func get_event_day(p_date : GameDate) -> EventDay:
	return _calendar_logic.get_event_day(p_date)

## Get the day of the week index based on the GameDate object
func get_day_of_week_index(p_date: GameDate) -> int:
	return _calendar_logic.get_day_of_week_index(p_date)

## Get the number of days per week
func get_days_per_week() -> int:
	return _calendar_logic.days_per_week

func get_days_between(p_old : GameDate, p_new : GameDate) -> int:
	return _calendar_logic.get_days_between(p_old, p_new)

## Gets the number of days that a GameDate is into it's year
func get_days_into_year(p_date : GameDate) -> int:
	return _calendar_logic.get_days_into_year(p_date)
	
## Get the GameDate that comes directly after the passed p_date
func get_next_day(p_date : GameDate) -> GameDate:
	return _calendar_logic.get_next_day(p_date)
	
## Gets a DateTime that is the next day from the current day, optionally at a p_desired_time during that date (like a day start time)
func get_next_date_time(p_current : DateTime, p_desired_time : HoursTime = null) -> DateTime:
	return _calendar_logic.get_next_date_time(p_current, p_desired_time)
	
func get_previous_date(p_date : GameDate) -> GameDate:
	return _calendar_logic.get_previous_date(p_date)

## Get the number of seconds that represents the start of a game date
func get_seconds_from_date(p_date : GameDate) -> float:
	return _calendar_logic.get_seconds_from_date(p_date)
	
## Gets the game seconds that represents the last time the p_moment occured, given a p_current_dt DateTime
func get_last_hours_time_as_secs(p_moment : HoursTime, p_current_dt : DateTime) -> float:
	return _calendar_logic.get_last_hours_time_as_secs(p_moment, p_current_dt)
	
func get_last_hours_time_as_date_time(p_moment : HoursTime, p_current_dt : DateTime) -> DateTime:
	return _calendar_logic.get_last_hours_time_as_date_time(p_moment, p_current_dt)

## Validate the calendar object
func validate_runtime() -> bool:
	return _calendar_logic.validate_runtime()

## Get the active time scale on the calendar
func get_scale() -> TimeScale:
	return _calendar_logic.get_scale()

## Get the number of game seconds from a DateTime object
func get_seconds_from_date_time(p_date_time: DateTime) -> float:
	return _calendar_logic.get_seconds_from_date_time(p_date_time)
