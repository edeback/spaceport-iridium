class_name TurboshaftCabsTab
extends VBoxContainer

## Cab purchase and removal, the shaft-wide force shutdown, and live cab
## positions (WI-11, moved into the inspector by WI-51).
##
## The position readout genuinely does need a per-frame refresh - a cab moves
## continuously and this is the only place its floor is reported - so this is one
## of the few UI `_process` handlers in the project. It runs on wall-clock, like
## all UI: a cab frozen by a pause should read as parked, not as a stale panel.

var _shaft: TurboliftShaft = null
var _count: Label = null
var _add: ActionButton = null
var _remove: ActionButton = null
var _shutdown: CheckButton = null
var _status: Label = null

func set_shaft(shaft: TurboliftShaft) -> void:
	name = "Cabs"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_shaft = shaft

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	add_child(row)
	_count = Label.new()
	_count.theme_type_variation = UIType.METRIC
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_count)
	_remove = ActionButton.create("−")
	_remove.pressed.connect(_on_remove)
	row.add_child(_remove)
	_add = ActionButton.create("+", ActionButton.Weight.PRIMARY)
	_add.pressed.connect(_on_add)
	row.add_child(_add)

	_shutdown = CheckButton.new()
	_shutdown.text = "Force shutdown"
	_shutdown.focus_mode = Control.FOCUS_NONE
	_shutdown.toggled.connect(_on_shutdown_toggled)
	add_child(_shutdown)

	_status = Label.new()
	_status.theme_type_variation = UIType.META_LINE
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
	add_child(_status)

	if _shaft != null:
		_shutdown.set_pressed_no_signal(_shaft.force_shutdown)
	refresh()

func _process(_delta: float) -> void:
	if visible:
		refresh()

func refresh() -> void:
	if _shaft == null or _count == null:
		return
	var cost: int = Global.turbolift_manager.cab_cost
	_count.text = "Max cabs: %d" % _shaft.max_cabs
	_add.set_label("+ (%d cr)" % cost)
	_add.disabled = Global.resource_manager.credit_resource.get_total() < cost
	_remove.disabled = _shaft.max_cabs <= 1
	var lines: PackedStringArray = []
	for index: int in _shaft.cabs.size():
		var cab: TurboliftCab = _shaft.cabs[index]
		var cab_floor: ModuleTurbolift = _shaft.get_floor_module(
			Global.world_to_cell(cab.get_apparent_position()).y)
		var floor_text: String = str(TurboshaftTabSet.floor_number(_shaft, cab_floor)) \
			if cab_floor != null else "?"
		lines.append("Cab %d: floor %s — %s" % [index + 1, floor_text, _cab_state_name(cab)])
	_status.text = "\n".join(lines) if not lines.is_empty() \
		else "No cabs yet (the first ride creates one)"

func _cab_state_name(cab: TurboliftCab) -> String:
	match cab.state:
		TurboliftCab.CabState.MOVING:
			return "moving up" if cab.moving_up() else "moving down"
		TurboliftCab.CabState.ARRIVED, TurboliftCab.CabState.DOORS_OPENING:
			return "doors opening"
		TurboliftCab.CabState.BOARDING:
			return "boarding"
		_:
			return "idle"

func _on_add() -> void:
	if _shaft != null:
		_shaft.buy_cab()
		refresh()

func _on_remove() -> void:
	if _shaft != null:
		_shaft.remove_cab()
		refresh()

func _on_shutdown_toggled(toggled_on: bool) -> void:
	if _shaft != null:
		_shaft.set_force_shutdown(toggled_on)
