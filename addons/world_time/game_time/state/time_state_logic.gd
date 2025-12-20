## Pure logic class for a TimeState resource. Initiated at runtime.
class_name TimeStateLogic
extends RefCounted

var _calendar : GameCalendar

func _init(p_calendar : GameCalendar):
	assert(p_calendar != null, "Calendar cannot be null when initializing TimeStateLogicCalendarLogic.")
	_calendar = p_calendar

func handle_date_change(time_state : TimeState, new_date : GameDate, old_date : GameDate):
	if old_date == null || new_date.is_same_date(old_date):
		return

	#var event = DateChangeEvent.new(new_date, old_date, _calendar)
	# time_state.date_changed.emit(event)

	time_state.event_day = _calendar.get_event_day(new_date)

	var days_between = get_days_between(new_date, old_date)
	if days_between > 0:
		time_state.day_finished.emit(old_date)

## Gets the number of days between the p_old GameDate and
## the p_new GameDate
func get_days_between(p_old : GameDate, p_new : GameDate) -> int:
	if p_old is not GameDate:
		return 0

	return _calendar.get_days_between(p_old, p_new)
	
func get_event_day(p_date : GameDate) -> EventDay:
	return _calendar.get_event_day(p_date)

## Sets the game calendar after initialization if needed to inject a new one.
func set_calendar(p_calender : GameCalendar):
	_calendar = p_calender
