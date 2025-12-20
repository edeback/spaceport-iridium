class_name TimeOfDayDirectionalLight2D
extends DirectionalLight2D
## Transitions between light settings when times of day switches on the day-night system

@export var time_state : TimeState :
	set(value):
		if time_state != null:
			time_state.transition_progress_changed.disconnect(_on_transition_progress_changed)

		time_state = value
		
		if time_state != null:
			time_state.transition_progress_changed.connect(_on_transition_progress_changed)

## The settings group defining what light settings should be at given time of days
@export var lighting_group : TimeOfDayLightSettingsGroup

## Optional. The amount transitioned between light settings against time percent done during
## the transition. 
@export var transition_curve : Curve

## Whether to print extra debug messages to console (should only be used for debugging)
@export var print_debug = false

## The progress that controls how far along the
## light values are in switching from the last time of day
## to the current one. 
## transition_progress.progress is represented between 0.0 and 1.0
var transition_progress : GameTimeProgress :
	set(value):
		if transition_progress != null:
			transition_progress.updated.disconnect(_on_transition_progress_updated)
			
		transition_progress = value
		
		if transition_progress != null:
			set_current_light_values(last_settings, current_settings, value.progress)
			transition_progress.updated.connect(_on_transition_progress_updated)
		
var current_settings : TimeOfDayLightSettings
var last_settings : TimeOfDayLightSettings

func _init(p_lighting_group : TimeOfDayLightSettingsGroup = null, p_time_state : TimeState = null):
	lighting_group = p_lighting_group
	time_state = p_time_state

func _ready():
	for problem in validate():
		push_warning(problem)

	if time_state != null and time_state.transition_progress != null:
		start_light_transition(time_state.time_of_day, time_state.last_time_of_day, time_state.transition_progress)
		
func start_light_transition(p_next : TimeOfDay, p_last : TimeOfDay, p_transition_progress : GameTimeProgress):
	if not _validate_times_of_day(p_next, p_last).is_empty(): return
	
	current_settings = get_lighting_setting(p_next)
	last_settings = get_lighting_setting(p_last)
	transition_progress = p_transition_progress
	
	if transition_progress == null && current_settings != null:
		color = current_settings.color
		energy = current_settings.energy
		height = current_settings.height
	
	for problem in _validate_light_settings():
		push_error(problem)
	
func get_lighting_setting(p_tod : TimeOfDay) -> TimeOfDayLightSettings:
	for setting in lighting_group.settings:
		if setting.time_of_day == p_tod:
			return setting
			
	return null

## Set light values at a value between two settings
func set_current_light_values(
	starting : TimeOfDayLightSettings, 
	ending : TimeOfDayLightSettings,
	progress : float):
		
	if not is_instance_valid(starting) || not is_instance_valid(ending):
		push_error("Must have valid starting and ending TimeOfDayLightSettings")
		return
	
	# Use curve to get adjusted transition progress value if curve is set
	var adjusted_progress = progress
		
	if transition_curve:
		adjusted_progress = transition_curve.sample(progress)
		
	color = get_progress_color(adjusted_progress)
	energy = lerpf(energy, ending.energy, adjusted_progress)
	height = lerpf(height, ending.height, adjusted_progress)
	
	if print_debug:
		prints("%s color %s" % [name, color])

## Given a progress ratio from 0.0 to 1.0
## Calculate the color between the last_settings color and the current_settings color
## [br][br]
## Returns the calculated color
func get_progress_color(p_progress : float) -> Color:
	return lerp(last_settings.color, current_settings.color, p_progress)

## Ensures that there are no problems in the setup of the light
func validate() -> Array[String]:
	var problems : Array[String] = []
	
	if time_state == null:
		problems.append("No time signal bus set on " + str(get_path()))
		
	return problems
	
## Make light intensity and color transition between settings
## when the day transition progresses
func _on_transition_progress_updated(ratio_done : float):
	set_current_light_values(last_settings, current_settings, ratio_done)

func _on_transition_progress_changed(p_transition_progress : GameTimeProgress):
	start_light_transition(time_state.time_of_day, time_state.last_time_of_day, p_transition_progress)

## Ensures that there are a valid p_next and p_last in the transition
func _validate_times_of_day(p_next : TimeOfDay, p_last : TimeOfDay) -> Array[String]:
	var problems : Array[String] = []
	
	if p_next == null:
		problems.append("Trying to start light transition but p_next TimeOfDay is null.")
	
	if p_last == null:
		problems.append("Trying to start light transition but p_last TimeOfDay is null. Be sure last time of day is set before the next time of day!")
	
	return problems

## Makes sure that the current_settings and last_settings exist on this light when needed
func _validate_light_settings() -> Array[String]:
	var problems : Array[String] = []
		
	if current_settings == null:
		problems.append("[current_settings] TimeOfDayLightSettings is null.")
		
	if last_settings == null:
		problems.append("[last_settings] TimeOfDayLightSettings is null.")
	
	return problems
