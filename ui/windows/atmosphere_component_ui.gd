class_name AtmosphereComponentUI
extends ModuleComponentUI

## Module info tab (WI-17): total pressure, O2/CO2 partials, breach countdown.
## Polls in _process - UI runs at real time regardless of sim speed/pause.

@export var pressure_label: Label
@export var o2_label: Label
@export var co2_label: Label
@export var breach_label: Label

var atmosphere_component: AtmosphereComponent

func set_atmosphere_component(component: AtmosphereComponent) -> void:
	name = "Atmosphere"
	atmosphere_component = component
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if atmosphere_component == null or not is_instance_valid(atmosphere_component):
		return
	pressure_label.text = "%.0f kPa" % atmosphere_component.pressure()
	o2_label.text = "%.0f kPa" % atmosphere_component.o2_partial()
	co2_label.text = "%.0f kPa" % atmosphere_component.co2_partial()
	if atmosphere_component.is_breached():
		breach_label.visible = true
		breach_label.text = "BREACHED - seals in %.1f h" % atmosphere_component.breach_remaining_hours
	else:
		breach_label.visible = false


func _on_breach_button_pressed() -> void:
	if is_instance_valid(atmosphere_component):
		atmosphere_component.start_breach(1.0)
