class_name PowerGenerationComponentUI
extends ModuleComponentUI

@export var power_production_label: Label
@export var input_consumption_label: Label
@export var force_shutdown_button: Button

var power_generation_component: PowerGenerationComponent

const POWER_PRODUCTION_FORMAT: String = "Produces %d power"
const INPUT_CONSUMPTION_FORMAT: String = "Consumes %.2f %s per second"

func set_power_generation_component(component: PowerGenerationComponent) -> void:
	power_generation_component = component
	power_production_label.text = POWER_PRODUCTION_FORMAT % component.power_output
	force_shutdown_button.set_pressed_no_signal(component.force_off)
	if component.resource_consumed != null and component.resource_consumption_per_second != 0:
		input_consumption_label.text = INPUT_CONSUMPTION_FORMAT % [component.resource_consumption_per_second, component.resource_consumed.name]
	else:
		input_consumption_label.visible = false

func _on_button_toggled(toggled_on: bool) -> void:
	power_generation_component.force_off = toggled_on
