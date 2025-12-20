## Current state of time within a game time system
## Owns data, triggers signals, updates properties based on analysis results.
## The incoming data for the TimeState which triggers the signals is handeled by
## a GameTimeSystem and a DayNightCycleSystem as indicated by the signal #regions below
class_name TimeState
extends Resource

## Emitted after a saved state is loaded onto the active state
## Other signals are surpressed during loads
signal state_loaded()

## Emitted when the calendar is set to a new value
signal calendar_changed(calendar : GameCalendar)

#region Game Time System Signals
## Emitted after any game time elapses
signal time_elapsed(amount : float, total : float)

## Emitted when the speed multiplayer that the time state operates on changes
signal game_speed_changed(speed_multiplier : float)

## Emitted when a new event day starts
signal event_day_started(event_day : EventDay)

## Emitted at the end of a game day
signal day_finished(finished_date : GameDate)

## Emitted when the date time is set to a new value (generally once per game tick)
signal date_time_changed(new : DateTime, old : DateTime)

## Emitted when the date changes (only once per day). Only emits when an old date was already set.
signal date_changed(event : DateChangeEvent)
#endregion

#region Day Night Cycle System Signals
## Emitted when the current TimeOfDay changes, includes reference to the last TimeOfDay
signal time_of_day_changed(time_of_day : TimeOfDay, last_time_of_day : TimeOfDay)

## Emitted when a new transition progress is set.
signal transition_progress_changed(progress : GameTimeProgress)
#endregion

## Optional ID for serialization (set manually if needed)
@export var id : String = "time_state_default":
	set(value):
		id = value

## The current DateTime within the system which includes a GameDate and HoursTime object
var date_time := DateTime.new() : 
	set(value):
		if date_time != null && date_time.matches(value):
			return

		var old : DateTime = date_time
		date_time = value

		# Emit event only if `old` is not null (meaning we have previous state to compare to)
		if old != null:
			var new_date : GameDate = date_time.date
			var old_date : GameDate = old.date
			assert(_logic != null, "Logic must not be null, call initialize on the TimeState first!")
			var days_between := _logic.get_days_between(new_date, old_date)
		
			if days_between != 0:
				var event := DateChangeEvent.new(new_date, old_date, days_between)
				event_day = _logic.get_event_day(new_date)
				
				if not _surpress_signals:
					date_changed.emit(event)
					day_finished.emit(old_date)
		
		if not _surpress_signals:
			date_time_changed.emit(date_time, old)
	get:
		return date_time

## Shared calendar object to serve as single source of truth for calendar operations on the TimeState
var calendar : GameCalendar :
	set(value):
		calendar = value
		
		if not _surpress_signals:
			calendar_changed.emit(calendar)
	get:
		return calendar

## The current time in the game measured in game seconds which
## may be faster or slower than real time depending on settings.
var game_seconds : float :
	set(value):
		var difference = value - game_seconds
		game_seconds = value
		
		if not _surpress_signals:
			time_elapsed.emit(difference, game_seconds)
	get:
		return game_seconds

## The time of day resource that marks the current time during the day
var time_of_day : TimeOfDay :
	set(value):
		if time_of_day == value:
			return

		time_of_day = value
	
		if not _surpress_signals:
			time_of_day_changed.emit(time_of_day, last_time_of_day)
	
		transition_progress = time_of_day.create_transition_progress(self)
	get:
		return time_of_day

## The TimeOfDay resource that comes directly before the current time_of_day
var last_time_of_day : TimeOfDay :
	set(value):
		last_time_of_day = value
	get:
		return last_time_of_day

## The resource associated with the game day's special events or markings (if any)
var event_day : EventDay :
	set(value):
		if event_day == value:
			return

		event_day = value

		if not _surpress_signals && event_day != null:
			event_day_started.emit(event_day)
	get:
		return event_day

## Active transition into the current time of day (if any)
var transition_progress : GameTimeProgress :
	set(value):
		transition_progress = value
		
		if not _surpress_signals:
			transition_progress_changed.emit(transition_progress)
	get:
		return transition_progress

var _surpress_signals : bool = true

var _logic : TimeStateLogic

func _init(p_calendar : GameCalendar = null):
	if p_calendar != null:
		calendar = p_calendar
		
	validate()

## Sets the needed components into the TimeState. This is needed
## if the TimeState is loaded from disk and used at runtime
func initialize(p_calendar : GameCalendar):
	calendar = p_calendar
	_logic = TimeStateLogic.new(calendar)
	state_loaded.emit()
	calendar_changed.connect(_on_calendar_changed)
	_surpress_signals = false
	
	# Post load setup
	event_day = calendar.get_event_day(date_time.date)

## Returns the TimeScale being used by the TimeState for operations
func get_scale() -> TimeScale:
	return calendar.get_scale()

## Updates the date time to the next date and optional p_desired_time HoursTime
func go_to_next_date(p_desired_time : HoursTime = null) -> void:
	var next_date_time : DateTime = calendar.get_next_date_time(date_time, p_desired_time)
	date_time = next_date_time

## Sets the time state and last time state to new resource values
func set_time_of_day(p_new : TimeOfDay, p_last : TimeOfDay):
	last_time_of_day = p_last
	time_of_day = p_new
	
## Updates total time game seconds and date time
## 
## Returns time in game seconds float
func progress_time(p_seconds : float) -> float:
	game_seconds += p_seconds
	date_time = calendar.advance_date_time(date_time, p_seconds)
	return game_seconds

## Checks the time state for any setup issues
func validate() -> bool:
	var issues : Array[String] = []
	
	if id.is_empty():
		issues.append("TimeState ID should be set at %s" % resource_path)
		
	for issue in issues:
		push_warning(issue)
	
	return issues.size() == 0

## Loads a ID keyed dictionary of data into the active TimeState object
func from_dict(p_state : Dictionary) -> void:
	_surpress_signals = true

	if not p_state.has_all(Keys.get_keys()):
		push_error("Missing required keys in dictionary for TimeState")
		return

	id = p_state.get(Keys.ID, "")
	if id == "":
		push_error("ID state is null on %s" % self)

	date_time = DateTime.new() # Ensure a new object is created
	if p_state.has(Keys.DATE_TIME):
		date_time.from_dict(p_state[Keys.DATE_TIME])
	else:
		push_error("Date time state is null on %s" % self)

	game_seconds = p_state.get(Keys.GAME_SECONDS, 0.0)

	# Recompute event_day based on current date_time
	if _logic and date_time:
		event_day = _logic.get_event_day(date_time.date)

	_surpress_signals = false
	state_loaded.emit()

## Serialize the time state for saving to file, etc
func to_dict() -> Dictionary:
	return {
		Keys.ID: id,
		Keys.DATE_TIME: date_time.to_dict(),
		Keys.GAME_SECONDS: game_seconds,
	}

## Update the calendar reference in the logic
func _on_calendar_changed(p_calendar : GameCalendar) -> void:
	if _logic:
		_logic.set_calendar(p_calendar)

class Keys: # For Serialization
	const ID = "id"
	const DATE_TIME = "date_time"
	const GAME_SECONDS = "game_seconds"

	static func get_keys() -> Array[String]:
		return [ID, DATE_TIME, GAME_SECONDS]
