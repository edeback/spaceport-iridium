class_name DateChangeRandomizer
extends Node
## Abstract base for a script makes a random selection and acts on DateChangeEvents

@export var time_state : TimeState:
	set(value):
		if time_state != null:
			time_state.date_changed.disconnect(_on_date_changed)
		
		time_state = value
		
		if time_state != null:
			time_state.date_changed.connect(_on_date_changed)

## Whether a random option is allowed to be enabled even on event days
@export var allow_on_event_days : bool = false

## Whether to make a random selection as soon as the script loads
@export var select_on_ready : bool = false

var rng = RandomNumberGenerator.new()

func _ready():
	if time_state == null:
		push_error("DateChangeRandomizer: time_state must be set before ready. Node: %s" % get_path())
		assert(false, "DateChangeRandomizer: time_state must be set before ready.")
	if select_on_ready:
		act(time_state.date_time.date)
		
## Perform the randomized action for a given game date
func act(p_date : GameDate):
	push_warning("%s is an abstract class. Implement act in extended script." % get_path())

func get_random_selection(p_option_weights : Dictionary) -> Variant:
	if p_option_weights.is_empty():
		push_warning("There are no options in option_weights. Selection not made at %s" % get_path())
		return null
	
	var total_weight = get_total_weight(p_option_weights)
	var random_num = rng.randf_range(0.0, total_weight)
	var weight_passed = 0.0
	
	for option in p_option_weights:
		var weight = p_option_weights[option]
		weight_passed += weight
		
		if weight_passed >= random_num:
			return option
		
	push_error("No selection made. Should not be possible.")
	return null
	
func get_total_weight(p_weight_dictionary : Dictionary):
	var total : float = 0.0

	for value in p_weight_dictionary.values():
		total += value
		
	return total
	
## Whether the randomizer is allowed to make a selection for the given date
func is_selection_allowed(new : GameDate) -> bool:
	if allow_on_event_days: return true
	
	var event_day : EventDay = time_state.calendar.get_event_day(new)
	
	if event_day == null:
		return true
	else:
		return false

func _on_date_changed(event : DateChangeEvent):
	act(event.new)
