## After the ageing component's age_state increased a number of times,
## call add(int) on a target node and/or resource
## to add some value to those targets
class_name AddWhenAgeing
extends Node

## Context for the AgeState. Can set path in inspector or defaults to parent node.
@export var ageing_component : AgeingComponent

func _disconnect_from_age_state(state : AgeState):
	if state != null && state.age_reached.is_connected(_on_age_reached):
		state.age_reached.disconnect(_on_age_reached)

## Helper function to connect the signal for age_reached
func _connect_to_age_state(state : AgeState) -> void:
	if state != null && not state.age_reached.is_connected(_on_age_reached):
		state.age_reached.connect(_on_age_reached)
		last_update_age = state.current

## The receipient of add(amount : float) function calls
## It must implement some version of add(amount : float)
@export var target_node : Node

## Target that is a resource instead of a node.
## The receipient must implement add(amount : float)
@export var target_resource : Resource

## Add this value to the target_node and / or target_resource when the period
## elapses
@export var amount : float = 1.0

## Number of age increases that must occur between add calls
@export var period : int = 1

## The last age_state that this component used to calculate adds
var last_update_age : float = 0.0

## Number of adds this component has performed
var total_adds = 0

func _init(
	p_ageing_component : AgeingComponent = null, 
	p_target_node : Node = null, 
	p_amount : float = 1.0, 
	p_period : int = 1):
		ageing_component = p_ageing_component
		target_node = p_target_node
		amount = p_amount
		period = p_period
		
func _ready():
	if ageing_component == null:
		ageing_component = get_parent()
	
	assert(ageing_component, "Must be set or the parent of this node.")
	
	ageing_component.age_state_changed.connect(_on_age_state_changed)
	if ageing_component.age_state:
		_connect_to_age_state(ageing_component.age_state)

func _exit_tree() -> void:
	if ageing_component:
		if ageing_component.age_state_changed.is_connected(_on_age_state_changed):
			ageing_component.age_state_changed.disconnect(_on_age_state_changed)
	
		_connect_to_age_state(ageing_component.age_state)

func _on_age_reached(total):
	handle_total_age_changed(total)
		
## Calculates the number of times to add based on the change of age_state since this was called last
## and returns the number of times add is called on the target_node
func handle_total_age_changed(total_age : float) -> int:
	if process_mode == PROCESS_MODE_DISABLED:
		return 0
		
	var target_node_set = is_instance_valid(target_node)
	var target_resource_set = is_instance_valid(target_resource)
	
	if not target_node_set && not target_resource_set:
		push_error("No targets set. Returning 0 for no adds completed")
		return 0
	
	var ages_since_update = total_age - last_update_age
	var times_to_add = int(ages_since_update / period)
	var num_times_added = 0
	
	for i in times_to_add:
		if target_node_set:

			target_node.add(amount)
		
		if target_resource_set:
			target_resource.add(amount)
			
		num_times_added += 1
		last_update_age += period
	
	total_adds += num_times_added
	
	return num_times_added

## Update connects for the new AgeState
func _on_age_state_changed(new_state: AgeState, old_state: AgeState) -> void:
	if old_state:
		_disconnect_from_age_state(old_state)
	if new_state:
		last_update_age = new_state.total
		_connect_to_age_state(new_state)
