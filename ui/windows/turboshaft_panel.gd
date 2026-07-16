class_name TurboshaftPanel
extends Control

## One management panel per turboshaft (WI-11): selecting any lift module in a
## shaft opens this instead of the module info panel. Floor toggles, cab
## purchase/removal, shaft-wide force shutdown, and live cab positions (text v1).

@export var title_label: Label
@export var floor_list: VBoxContainer
@export var cab_count_label: Label
@export var add_cab_button: Button
@export var remove_cab_button: Button
@export var shutdown_button: CheckButton
@export var cab_status_label: Label

var viewed_module: ModuleTurbolift = null
## Tracked separately from viewed_module.shaft so a merge/split while the
## panel is open is noticed in _process and triggers a rebuild.
var _viewed_shaft: TurboliftShaft = null
var _floor_rows: Dictionary[ModuleTurbolift, CheckButton] = {}

func _ready() -> void:
	SignalBus.module_removed.connect(_on_module_removed)
	add_cab_button.pressed.connect(_on_add_cab_pressed)
	remove_cab_button.pressed.connect(_on_remove_cab_pressed)
	shutdown_button.toggled.connect(_on_shutdown_toggled)

func toggle_for(module: ModuleTurbolift) -> void:
	if visible and _viewed_shaft != null and module.shaft == _viewed_shaft:
		close()
	else:
		open_for(module)

func open_for(module: ModuleTurbolift) -> void:
	if viewed_module != null:
		viewed_module.selected = false
	viewed_module = module
	viewed_module.selected = true
	visible = true
	_rebuild()

func close() -> void:
	if viewed_module != null:
		viewed_module.selected = false
	viewed_module = null
	_viewed_shaft = null
	visible = false

func _on_module_removed(module: ModuleBase) -> void:
	if not visible:
		return
	if module == viewed_module:
		close()
	elif module is ModuleTurbolift and _floor_rows.has(module):
		# Shaft membership settles after the removal (split/merge), so rebuild
		# once the current call stack unwinds.
		call_deferred("_rebuild")

func _process(_delta: float) -> void:
	# Pure UI - runs on wall clock, per the TimeManager rules.
	if not visible:
		return
	if viewed_module == null or not is_instance_valid(viewed_module) or viewed_module.shaft == null:
		close()
		return
	if viewed_module.shaft != _viewed_shaft:
		_rebuild()
	_update_live_state()

func _rebuild() -> void:
	if viewed_module == null or not is_instance_valid(viewed_module) or viewed_module.shaft == null:
		close()
		return
	_viewed_shaft = viewed_module.shaft
	for child: Node in floor_list.get_children():
		floor_list.remove_child(child)
		child.queue_free()
	_floor_rows.clear()
	# floors is sorted by cell y (topmost first) - show top floor at the top.
	for lift: ModuleTurbolift in _viewed_shaft.floors:
		var row := CheckButton.new()
		row.text = "Floor %d" % _floor_number(lift)
		row.set_pressed_no_signal(lift.floor_enabled)
		row.toggled.connect(func(toggled_on: bool) -> void: lift.floor_enabled = toggled_on)
		floor_list.add_child(row)
		_floor_rows[lift] = row
	shutdown_button.set_pressed_no_signal(_viewed_shaft.force_shutdown)
	_update_live_state()

## Numbered relative to the shaft's lowest floor: bottom = 1, counting up.
func _floor_number(lift: ModuleTurbolift) -> int:
	if _viewed_shaft == null or _viewed_shaft.floors.is_empty():
		return 1
	var bottom_y: int = _viewed_shaft.floors[_viewed_shaft.floors.size() - 1].module_cell.y
	return bottom_y - lift.module_cell.y + 1

func _update_live_state() -> void:
	var cost: int = Global.turbolift_manager.cab_cost
	cab_count_label.text = "Max Cabs: %d" % _viewed_shaft.max_cabs
	add_cab_button.text = "+ (%d cr)" % cost
	add_cab_button.disabled = Global.resource_manager.credit_resource.get_total() < cost
	remove_cab_button.disabled = _viewed_shaft.max_cabs <= 1
	var lines: PackedStringArray = []
	for index: int in _viewed_shaft.cabs.size():
		var cab: TurboliftCab = _viewed_shaft.cabs[index]
		var cab_floor: ModuleTurbolift = _viewed_shaft.get_floor_module(Global.world_to_cell(cab.get_apparent_position()).y)
		var floor_text: String = str(_floor_number(cab_floor)) if cab_floor != null else "?"
		lines.append("Cab %d: floor %s - %s" % [index + 1, floor_text, _cab_state_name(cab)])
	if lines.is_empty():
		cab_status_label.text = "No cabs yet (first ride creates one)"
	else:
		cab_status_label.text = "\n".join(lines)

func _cab_state_name(cab: TurboliftCab) -> String:
	match cab.state:
		TurboliftCab.CabState.MOVING:
			return "moving up" if cab.moving_up() else "moving down"
		TurboliftCab.CabState.DOORS_OPEN, TurboliftCab.CabState.WAITING:
			return "doors open"
		_:
			return "idle"

func _on_add_cab_pressed() -> void:
	if _viewed_shaft != null:
		_viewed_shaft.buy_cab()
		_update_live_state()

func _on_remove_cab_pressed() -> void:
	if _viewed_shaft != null:
		_viewed_shaft.remove_cab()
		_update_live_state()

func _on_shutdown_toggled(toggled_on: bool) -> void:
	if _viewed_shaft != null:
		_viewed_shaft.set_force_shutdown(toggled_on)

func _on_exit_button_pressed() -> void:
	close()
