class_name DateChangeRandomToggler
extends DateChangeRandomizer
## Whenever date changes select one option from the list of triggerable nodes

## Odds of each node being triggered when the date changes compared to other node weights in the dictionary
@export var option_weights : Dictionary[Node, float]

## Property to toggle off or on depending on random selection
@export var toggle_property : StringName

## When the property is considered on, it should be set to this value
@export var on_value : bool = true

## Turns on the toggle_property for the selection and off for all other option nodes
func toggle_selection(p_selection : Node, p_options : Array[Node]):
	for option in p_options:
		if option == null:
			continue
		
		if p_selection == option:
			option.set(toggle_property, on_value)
		else:
			option.set(toggle_property, not on_value)

func _on_date_changed(event : DateChangeEvent):
	act(event.new)

## Makes a weighted randomized selection on the node to set the toggle_property on off for.
## Sets the select on and others off
func act(p_new_date : GameDate):
	var selection = null
	
	if is_selection_allowed(p_new_date):
		selection = get_random_selection(option_weights)
	
	toggle_selection(selection, option_weights.keys())
