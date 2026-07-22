class_name WeaponComponentUI
extends ModuleComponentUI

## Info-panel tab for a laser turret (WI-32). Lists the turret's live, computed
## combat stats (damage / fire interval / range - after upgrades) and whether
## it's currently engaging. Built in code, polled while open (stats can shift
## with local upgrades), mirroring MiningComponentUI's poll-refresh style.

var _weapon: WeaponComponent
var _damage: Label
var _interval: Label
var _range: Label
var _status: Label

func setup(weapon: WeaponComponent) -> void:
	_weapon = weapon
	name = "Weapon"
	var vbox := VBoxContainer.new()
	add_child(vbox)
	var title := Label.new()
	title.text = "Laser Turret"
	title.add_theme_color_override("font_color", Color(0.9, 0.55, 0.4))
	vbox.add_child(title)
	_damage = Label.new()
	vbox.add_child(_damage)
	_interval = Label.new()
	vbox.add_child(_interval)
	_range = Label.new()
	vbox.add_child(_range)
	_status = Label.new()
	vbox.add_child(_status)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		return
	_damage.text = "Damage per shot: %.0f" % _weapon.effective_damage()
	var interval: float = _weapon.effective_fire_interval()
	var dps: float = _weapon.effective_damage() / interval if interval > 0.0 else 0.0
	_interval.text = "Fire interval: %.2fs  (%.0f dps)" % [interval, dps]
	_range.text = "Range: %.0f" % _weapon.effective_range()
	if not _weapon.is_powered():
		_status.text = "Status: unpowered — holding fire"
	elif _weapon._engaging:
		_status.text = "Status: engaging"
	else:
		_status.text = "Status: standby"
