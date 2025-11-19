class_name PowerConsumptionComponentUI
extends ModuleComponentUI

@export var power_consumption_label: Label
@export var force_shutdown_button: Button

var power_consumption_component: PowerConsumptionComponent

const POWER_CONSUMPTION_FORMAT: String = "Requires %d power"

func set_power_consumption_component(component: PowerConsumptionComponent) -> void:
	power_consumption_component = component
	power_consumption_label.text = POWER_CONSUMPTION_FORMAT % component.power_consumption
	force_shutdown_button.set_pressed_no_signal(component.force_off)


func _on_button_toggled(toggled_on: bool) -> void:
	power_consumption_component.force_off = toggled_on
