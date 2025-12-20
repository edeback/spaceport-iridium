class_name AddAfterGameSeconds
extends Node
## Adds a int value to a target node with add(int) method when
## a number of game seconds have elapsed on the TimeStateLogic [br][br]
## You can stop this node from executing by setting process_mode to disabled

## Where to receive updates to the current date time from
@export var time_state : TimeState :
	set(value):
		if time_state == value:
			return
		
		time_state = value
		last_update_secs = time_state.game_seconds

@export var add_target : Node

## Add this to the add_target per period
@export var amount = 1

## Number of age values per increase
@export var interval : GameTimeDuration :
	set(value):
		interval = value
		
		if is_instance_valid(interval):
			interval_secs = interval.as_game_seconds(time_state.calendar.time_scale)

## Accrued time that has no been used in adding value to the target node yet
var remainder_secs : float

## The last time in seconds that this component was updated
var last_update_secs = 0.0

## The amount of secs that should elapse between adds
var interval_secs : float

## Total number of times this component has called add on the target(s)
var total_adds = 0

func _init(p_target : Node = null, 
		p_time_state : TimeState = null,
		p_interval : GameTimeDuration = null,
		p_amount : int = amount):
	add_target = p_target
	time_state = p_time_state
	interval = p_interval
	amount = p_amount

func _ready():
	time_state.time_elapsed.connect(_on_time_elapsed)
	
func _on_time_elapsed(_p_change : float, p_total : float):
	update(p_total)

## Processes adding of game seconds change to this component
## and any add function calls that may be needed on the add target
## as a result
func update(p_game_seconds : float) :
	if process_mode == PROCESS_MODE_DISABLED:
		return 0
		
	var valid_target = is_instance_valid(add_target)
	
	if not valid_target:
		push_error("No targets set. Returning 0 for no adds completed")
		return 0
		
	var process_seconds = p_game_seconds - last_update_secs + remainder_secs
	
	var times_to_add = int(process_seconds / interval_secs)
	remainder_secs = process_seconds - (times_to_add * interval_secs)
	
	var times_added = 0
	
	for i in times_to_add:
		if valid_target:
			add_target.add(amount)
			
		times_added += 1
		
	last_update_secs = p_game_seconds
	total_adds += times_added

	return times_to_add
