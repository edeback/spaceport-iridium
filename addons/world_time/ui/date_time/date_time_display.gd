class_name DateTimeDisplay
extends Control
## Shows the current date time represented in text labels

# Resource where to connect to date time signals from
@export var time_format : TimeFormat

## Defaults to global if unset
@export var time_state : TimeState :
	set(value):
		if time_state != null:
			time_state.date_time_changed.disconnect(_on_date_time_changed)

		time_state = value

		if time_state != null:
			time_state.date_time_changed.connect(_on_date_time_changed)

@export var show_seconds = true

@export_group("Internal Nodes")
@export var time_label : Label
@export var date_label : Label

func update_time_label(p_hours_time : HoursTime):
	time_label.text = (
		time_format.hours % p_hours_time.hours + " : " + time_format.minutes % p_hours_time.minutes
	)
	
	if show_seconds:
		time_label.text += " %s %s" % [time_format.time_seperator, time_format.seconds % p_hours_time.seconds]
	
func update_date_label(p_game_date : GameDate):
	var formatted = time_format.get_formatted_date(p_game_date, time_state.calendar)
	date_label.text = formatted

func _on_date_time_changed(p_new : DateTime, p_old : DateTime):
	update_time_label(p_new.time)
	update_date_label(p_new.date)

func validate() -> bool:
	var no_problems = true
	
	if not is_instance_valid(TimeStateLogic):
		push_warning("%s cannot work without reference to the active TimeStateLogic resource - Path: %s" % [name, get_path()])
		no_problems = false
	
	return no_problems
