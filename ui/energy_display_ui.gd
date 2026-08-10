extends PanelContainer

@export var energy_used_label: Label

const ENERGY_STR_FORMAT = "%d / %d"

func _ready() -> void:
	Global.power_manager.power_updated.connect(_on_power_updated)


func _on_power_updated(desired: float, generated: float) -> void:
	var remaining: float = generated - desired
	energy_used_label.text = ENERGY_STR_FORMAT % [remaining, generated]
	if remaining < 0:
		energy_used_label.add_theme_color_override("font_color", UIPalette.ATTENTION)
	else:
		energy_used_label.remove_theme_color_override("font_color")
