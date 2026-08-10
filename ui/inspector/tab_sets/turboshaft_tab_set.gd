class_name TurboshaftTabSet
extends InspectorTabSet

## The TURBOSHAFT tab set (WI-51): `windows/turboshaft_panel.tscn` as a tab set
## rather than a panel of its own.
##
## Turbolifts are managed **per shaft**, not per module (WI-11), so clicking one
## lift used to silently open a different panel from the one clicking any other
## module opened. It now swaps the tab set on the same surface and the header
## says `SELECTED · TURBOSHAFT`, which is the point the design makes: you are
## looking at the shaft, not the cab you clicked.
##
## The shaft is watched rather than assumed. Removing a lift can split a shaft in
## two or merge it with a neighbour, and the shaft the panel is showing can stop
## being the shaft the selected module belongs to - which is why the identity is
## re-checked rather than cached once.

const TAB_FLOORS: StringName = &"floors"
const TAB_CABS: StringName = &"cabs"

var _lift: ModuleTurbolift = null
## Tracked separately from `_lift.shaft` so a merge or split while the panel is
## open is noticed and rebuilds the pages.
var _shaft: TurboliftShaft = null

func kind_label() -> String:
	return "TURBOSHAFT"

func bind(subject: Variant) -> void:
	_lift = subject as ModuleTurbolift
	if _lift == null:
		return
	_lift.selected = true
	_shaft = _lift.shaft
	SignalBus.module_removed.connect(_on_module_removed)
	# Shaft membership settles after a removal, and nothing signals the settle -
	# so identity is re-checked on the slow tick rather than per frame.
	Global.time_manager.slow_tick.connect(_on_slow_tick)

func _exit_tree() -> void:
	if _lift != null and is_instance_valid(_lift):
		_lift.selected = false

func is_alive() -> bool:
	return _lift != null and is_instance_valid(_lift) and _lift.shaft != null

func camera_target() -> Node2D:
	return _lift

func subject_name() -> String:
	return "Turboshaft"

func meta_text() -> String:
	if not is_alive():
		return ""
	var enabled: int = 0
	for lift: ModuleTurbolift in _shaft.floors:
		if lift.floor_enabled:
			enabled += 1
	return "%d floors (%d served) · %d/%d cabs" % [
		_shaft.floors.size(), enabled, _shaft.cabs.size(), _shaft.max_cabs]

func status_text() -> String:
	if is_alive() and _shaft.force_shutdown:
		return "Shut down — no rides will run."
	return ""

func icon_color() -> Color:
	if not is_alive():
		return Color(0.0, 0.0, 0.0, 0.0)
	return UIPalette.ATTENTION if _shaft.force_shutdown else UIPalette.tinted(UIPalette.LIVE, 0.6)

func tabs() -> Array[Dictionary]:
	return [
		{"id": TAB_FLOORS, "text": "Floors"},
		{"id": TAB_CABS, "text": "Cabs"},
	]

func make_page(id: StringName) -> Control:
	if not is_alive():
		return null
	match id:
		TAB_FLOORS:
			var floors := TurboshaftFloorsTab.new()
			floors.set_shaft(_shaft)
			return floors
		TAB_CABS:
			var cabs := TurboshaftCabsTab.new()
			cabs.set_shaft(_shaft)
			return cabs
	return null

## Floors numbered from the shaft's lowest: bottom = 1, counting up. Static
## because both pages print it and neither owns the rule.
static func floor_number(shaft: TurboliftShaft, lift: ModuleTurbolift) -> int:
	if shaft == null or lift == null or shaft.floors.is_empty():
		return 1
	var bottom_y: int = shaft.floors[shaft.floors.size() - 1].module_cell.y
	return bottom_y - lift.module_cell.y + 1

func _on_module_removed(module: ModuleBase) -> void:
	if module == _lift:
		subject_lost.emit()
		return
	if module is ModuleTurbolift and _shaft != null and _shaft.floors.has(module):
		# The shaft's membership settles after the removal call unwinds.
		_recheck_shaft.call_deferred()

func _on_slow_tick(_interval: float) -> void:
	_recheck_shaft()

func _recheck_shaft() -> void:
	if not is_alive():
		subject_lost.emit()
		return
	if _lift.shaft != _shaft:
		_shaft = _lift.shaft
		tabs_changed.emit()
	subject_changed.emit()
