class_name EngineTimeScaleSlider
extends Slider
## Slider for controlling the process / physics process delta time of the game

## Time scale values for ticks in the slider
@export var slider_time_multipliers : Array[float] = [0, .5, .75, 1.0, 1.25, 1.5, 2, 3]

## Will make the label text have fancy bb code for high speeds at or above this threshold
@export var crazy_bb_code_theshold : int = 6

@export var speed_prefix = "Game Speed: "

## Set the time scale value on load
@export var set_on_load = false

## Speed of the engine scale on loading this script if set_on_load is set true
@export var on_load_speed : float = 1.0

@export_group("Internal Nodes")
@export var label : RichTextLabel

func _ready() -> void:
	if set_on_load:
		Engine.time_scale = on_load_speed
	
	var current_speed = Engine.time_scale
	
	
	min_value = 0
	max_value = slider_time_multipliers.size() - 1
	tick_count = slider_time_multipliers.size()
	value_changed.connect(_on_value_changed)
		
	var multiplier_idx = slider_time_multipliers.find(current_speed)
	value = multiplier_idx
	set_label(value)

func _on_value_changed(new_value : float):
	# Get multiplier associated with tick
	var new_multiplier = slider_time_multipliers[new_value]
	
	Engine.time_scale = new_multiplier
	set_label(new_value)

func set_label(slider_index : int):
	label.clear()
	
	label.append_text(speed_prefix)
	
	if label.bbcode_enabled && slider_index >= crazy_bb_code_theshold:
		label.append_text("[shake rate=20.0 level=20 connected=1]")
		label.append_text("[rainbow freq=1.0 sat=0.8 val=0.8]")
		
	label.append_text(str(slider_time_multipliers[value]) + "x")

class Serialize:
	const TIME_SCALE := "engine_time_scale"

func to_dict() -> Dictionary:
	var dict := {}
	dict[Serialize.TIME_SCALE] = Engine.time_scale
	return dict

func from_dict(data: Dictionary) -> void:
	if data.has(Serialize.TIME_SCALE):
		var saved_scale = data[Serialize.TIME_SCALE]
		Engine.time_scale = saved_scale
		# Update slider to match the loaded value if possible
		var idx = slider_time_multipliers.find(saved_scale)
		if idx != -1:
			value = idx
			set_label(idx)
		else:
			# If not found, set to closest value
			var closest_idx = 0
			var min_diff = abs(slider_time_multipliers[0] - saved_scale)
			for i in range(1, slider_time_multipliers.size()):
				var diff = abs(slider_time_multipliers[i] - saved_scale)
				if diff < min_diff:
					min_diff = diff
					closest_idx = i
			value = closest_idx
			set_label(closest_idx)
