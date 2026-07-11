class_name UI_TimeScaleSelect
extends MarginContainer


func _on_timescale_spin_box_value_changed(value: float) -> void:
	Engine.time_scale = value


func _on_pause_button_toggled(toggled_on: bool) -> void:
	get_tree().paused = toggled_on
