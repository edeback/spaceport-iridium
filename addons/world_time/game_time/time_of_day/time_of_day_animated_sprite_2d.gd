class_name TimeOfDayAnimatedSprite2D
extends AnimatedSprite2D
## Changes animation at designated time of days

## Matching the TimeOfDay with the animation name that should play
## when those TimeOfDays are entered
@export var animations : Dictionary[TimeOfDay, StringName]

## Time state to read current TimeOfDay changes from
@export var time_state : TimeState :
	set(value):
		if time_state != null:
			time_state.time_of_day_changed.disconnect(_on_time_of_day_changed)
		
		time_state = value
		
		if time_state != null:
			time_state.time_of_day_changed.connect(_on_time_of_day_changed)

## Warns that there is no animation defined in the dictionary for the current time of day
## Helpful if you expect an animation to be set for every time of day for this object
@export var warn_no_animation = false

## Play the matching time of day when time of day is entered
func _on_time_of_day_changed(p_new : TimeOfDay, _p_old : TimeOfDay):
	play_for_time_of_day(p_new)

## Plays the animation associated with the time of day in the animations dictionary
func play_for_time_of_day(p_tod : TimeOfDay):
	if animations.has(p_tod):
		var animation_to_play = animations[p_tod]
		self.play(animation_to_play)
	elif warn_no_animation:
		push_warning("There is no animation defined in animations dictionary for %s at %s" % [p_tod, get_path()])
