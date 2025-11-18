class_name PowerGenerationComponentUI
extends ModuleComponentUI

@export var power_production_label: Label
@export var input_consumption_label: Label

const POWER_PRODUCTION_FORMAT: String = "Produces %d power"
const INPUT_CONSUMPTION_FORMAT: String = "Consumes %.2f %s per second"

func set_power_generation_component(component: PowerGenerationComponent) -> void:
	power_production_label.text = POWER_PRODUCTION_FORMAT % component.power_output
	if component.resource_consumed != null and component.resource_consumption_per_second != 0:
		input_consumption_label.text = INPUT_CONSUMPTION_FORMAT % [component.resource_consumption_per_second, component.resource_consumed.name]
	else:
		input_consumption_label.visible = false
