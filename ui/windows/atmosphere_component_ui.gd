class_name AtmosphereComponentUI
extends ModuleComponentUI

## The AIR section of a module's Status tab (WI-17, folded into Status by WI-64):
## total pressure, O2/CO2 partials, breach countdown.
##
## Read-only. It carried a "Cause Breach" button until WI-64, which was survivable
## while it sat behind an Air tab and stopped being so once Status became the page
## a player lands on. That affordance is `Global.cheats.breach_module(cell, hours)`
## now, with `seal_breach(cell)` beside it.
##
## Polls in _process - UI runs at real time regardless of sim speed/pause.

@export var pressure_label: Label
@export var o2_label: Label
@export var co2_label: Label
@export var breach_label: Label

var atmosphere_component: AtmosphereComponent

func set_atmosphere_component(component: AtmosphereComponent) -> void:
	name = "Atmosphere"
	atmosphere_component = component
	# A breach is one of amber's four sanctioned spends (invariant 5), so it takes
	# the palette's amber rather than the scene-authored `Color(1, 0.35, 0.3, 1)`
	# it wore until WI-58 - which was neither the palette's red nor its amber.
	breach_label.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)
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
