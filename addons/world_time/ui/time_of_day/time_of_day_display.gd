extends Control
## Shows the current time of day in a label

## Where to receive signals for time of day
@export var time_state : TimeState : 
	set(value):
		if time_state != null:
			time_state.time_of_day_changed.disconnect(_on_time_of_day_changed)
			
		time_state = value
		
		if time_state != null:
			time_state.time_of_day_changed.connect(_on_time_of_day_changed)

@export_group("Internal Nodes")
@export var bg_rect : ColorRect
@export var time_of_day_label : Label

func _on_time_of_day_changed(p_tod : TimeOfDay, _p_last : TimeOfDay):
	# Set label text and colors
	time_of_day_label.text = p_tod.display_name
	bg_rect.color = p_tod.color

func _on_state_changed(p_state : TimeState):
	time_state = p_state
