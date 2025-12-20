class_name TimeEventMessenger
extends Resource

## Generated log
signal message_created(message : String)

## Toggle for controlling if messages are emitted or skipped. [br]
## Use for controlling at what time messenges should be active in your time.
@export var active: bool = true:
	set(value):
		if active == value:
			return
		active = value
		if time_state != null:
			if active:
				_connect_signals(time_state)
			else:
				_disconnect_signals(time_state)

## The messenger will be using this to generate messages from the TimeState signals
@export var time_state : TimeState:
	set(value):
		if time_state != null:
			_disconnect_signals(time_state)
		
		time_state = value

		if time_state != null and active:
			_connect_signals(time_state)

## Defines how the time should be displayed for date & time
@export var time_format : TimeFormat

## Whether to log the messages generated to the console as a print
@export var log_to_console = false

## Whether to send messages for the current date whenever the time_state is set
@export var send_current_day_events_on_load = true

@export_category("Signals")
## Whether to show date_changed signal events from the time state
@export var show_date_changed = true

@export var date_changed_message = "The date is %s"

## Whether to show day_finished signal events from the time state
@export var show_day_finished = true
@export var day_finished_message = "Day %s is finished"

## Whether to show event_day_started signal events from the time state
@export var show_event_day_started = true
@export var event_day_started_message = "Today is the %s"

## Whether to show date_time_changed signal events from the time state
## Warning: This will print a lot of data
@export var show_date_time_changed = false

@export var state_loaded_message = "The date is %s"

func _init() -> void:
	message_created.connect(_on_message_created)
	validate.call_deferred()


func validate() -> bool:
	var issues : Array[String] = []
	
	if time_state == null:
		issues.append("There is no TimeStateLogic set in the project globals. TimeEventMessenger %s will not generate any messages" % self)
		
	if time_format == null:
		issues.append("There is no time_format set on %s at path %s. It cannot convert time to strings without it." % [self, resource_path])
		
	for issue in issues:
		push_warning(issue)
		
	return issues.size() == 0

func _on_date_changed(event : DateChangeEvent):
	if not active or not show_date_changed:
		return

	var message = date_changed_message % event.new.as_formatted(time_format)
	message_created.emit(message)

func _on_day_finished(p_finished_date : GameDate):
	if not active or not show_day_finished:
		return
		
	var message = day_finished_message % p_finished_date.day
	message_created.emit(message)
	
func _on_event_day_started(p_event_day : EventDay):
	if not active or not show_event_day_started or p_event_day == null:
		return
		
	var message = event_day_started_message % p_event_day.display_name
	message_created.emit(message)

func _on_date_time_changed(p_new : DateTime, p_old : DateTime):
	if not active or not show_date_time_changed:
		return

	# Ensure valid dates for get_days_between
	if p_old != null:
		var days_between = time_state.calendar.get_days_between(p_new.date, p_old.date)
		var date_change_event = DateChangeEvent.new(p_new.date, p_old.date, days_between)
		_on_date_changed(date_change_event)

	# Handle event day started if applicable
	if time_state.event_day != null:
		_on_event_day_started(time_state.event_day)

	var message = str(p_new)
	message_created.emit(message)
	
func _on_message_created(p_message : String):
	if log_to_console:
		print(p_message)
		
func _on_state_loaded() -> void:
	var message : String = state_loaded_message % time_state.date_time.date.as_formatted(time_format)
	message_created.emit(message)
		
## Connects from connected signals on the TimeStateLogic
func _disconnect_signals(p_time_state : TimeState):
	p_time_state.date_changed.disconnect(_on_date_changed)
	p_time_state.day_finished.disconnect(_on_day_finished)
	p_time_state.event_day_started.disconnect(_on_event_day_started)
	p_time_state.date_time_changed.disconnect(_on_date_time_changed)
	p_time_state.state_loaded.disconnect(_on_state_loaded)
	
## Connects to several signals on the TimeStateLogic
func _connect_signals(p_time_state : TimeState):
	p_time_state.date_changed.connect(_on_date_changed)
	p_time_state.day_finished.connect(_on_day_finished)
	p_time_state.event_day_started.connect(_on_event_day_started)
	p_time_state.date_time_changed.connect(_on_date_time_changed)
	p_time_state.state_loaded.connect(_on_state_loaded)
