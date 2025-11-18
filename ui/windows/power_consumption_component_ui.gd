class_name PowerConsumptionComponentUI
extends ModuleComponentUI

@export var power_consumption_label: Label

const POWER_CONSUMPTION_FORMAT: String = "Requires %d power"

func set_power_consumption_component(component: PowerConsumptionComponent) -> void:
	power_consumption_label.text = POWER_CONSUMPTION_FORMAT % component.power_consumption
