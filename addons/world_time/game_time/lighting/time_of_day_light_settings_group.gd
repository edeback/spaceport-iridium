class_name TimeOfDayLightSettingsGroup
extends Resource

## Sharable group of light settings resources that can be reused
## between lights or other objects & nodes

## The light settings corresponding with each time of day.
## As a time of day is entered, the light settings should be applied
## for the settings that match the entered time of day.
@export var settings : Array[TimeOfDayLightSettings]

## Finds the matching time of day to the light settings
func get_setting(p_time_of_day : TimeOfDay) -> TimeOfDayLightSettings:
	if p_time_of_day == null:
		return null
		
	var matching_settings = settings.filter(
		func(setting): 
			var found_match = setting.time_of_day == p_time_of_day
			return found_match
	)
		
	if matching_settings.is_empty():
		push_error("Light settings not found for time of day %s. Check light time_settings." % str(p_time_of_day))
		return null
		
	return matching_settings[0]
