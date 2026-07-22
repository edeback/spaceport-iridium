class_name ShieldComponentUI
extends ModuleComponentUI

## Info-panel tab for a shield generator (WI-32). Shows the capacitor's current /
## max absorption with a fill bar and the online/offline (recharging) status.
## Built in code and polled while open, mirroring MiningComponentUI.

var _shield: ShieldComponent
var _absorb: Label
var _bar: ProgressBar
var _status: Label

func setup(shield: ShieldComponent) -> void:
	_shield = shield
	name = "Shield"
	var vbox := VBoxContainer.new()
	add_child(vbox)
	var title := Label.new()
	title.text = "Shield Generator"
	title.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	vbox.add_child(title)
	_absorb = Label.new()
	vbox.add_child(_absorb)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(140, 12)
	vbox.add_child(_bar)
	_status = Label.new()
	vbox.add_child(_status)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if _shield == null or not is_instance_valid(_shield):
		return
	var cap: float = _shield.effective_capacity()
	_absorb.text = "Absorption: %.0f / %.0f" % [_shield.charge(), cap]
	_bar.value = _shield.charge() / cap if cap > 0.0 else 0.0
	if _shield.is_online():
		_status.text = "Status: online"
		_status.remove_theme_color_override("font_color")
	else:
		_status.text = "Status: offline — recharging"
		_status.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
