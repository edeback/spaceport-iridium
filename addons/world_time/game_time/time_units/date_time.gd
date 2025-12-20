class_name DateTime
extends Resource
## The game date and time represented as a resource composed of GameDate and HoursTime

## The date day, month, year
## Correlates with a particular game calendar that calculated it
## and not necessarily the real world calendar
@export var date : GameDate

## The time representation of the current day's hours, minutes, and seconds
@export var time : HoursTime

func _init(p_date : GameDate = GameDate.new(), p_hours_time : HoursTime = HoursTime.new()):
	date = p_date
	time = p_hours_time
	validate()
	
## Creates a DateTime instance from individual year, month, day, hours, minutes, and seconds
static func from_components(year: int, month: int, day: int, hours: int, minutes: int, seconds: float) -> DateTime:
	var new_date = GameDate.new(day, month, year)
	var new_time = HoursTime.new(hours, minutes, seconds)
	return DateTime.new(new_date, new_time)
	
## Checks if the GameDate and HoursTime are the same values
##
## Returns true if all time values match
func matches(p_date_time : DateTime) -> bool:
	var same_date = p_date_time.date.is_same_date(date)
	var same_time = p_date_time.time.is_same_time(time)
	var same = same_date && same_time
	return same

func validate() -> bool:
	var no_problems = true
	
	if(date == null):
		push_warning("Trying to set date time with null date on " + str(get_path))
		no_problems = false
		
	if(time == null):
		push_warning("Trying to set null time HoursTIme on " + str(get_path))
		no_problems = false
	
	return no_problems

## Converts the date and time to a dictionary for saving
## Returns a dictionary with the date and time values
func to_dict() -> Dictionary:
	return {
		"date" : date.to_dict(),
		"time" : time.to_dict()
	}

## Loads the saved Dictionary state into the date time object
func from_dict(p_state : Dictionary) -> void:
	if p_state.has("date"):
		date.from_dict(p_state["date"])
	else:
		push_error("Date state is null on " + str(get_path))

	if p_state.has("time"):
		time.from_dict(p_state["time"])
	else:
		push_error("Time state is null on " + str(get_path))

func as_formatted(format : TimeFormat) -> String:
	return format.date_time_format.format({"hours" : time.hours, "minutes" : time.minutes, "seconds" : time.seconds as int, "day" : date.day, "month" : date.month, "year" : date.year})
