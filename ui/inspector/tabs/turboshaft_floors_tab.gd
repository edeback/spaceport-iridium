class_name TurboshaftFloorsTab
extends VBoxContainer

## Which floors of a shaft the lift will stop at (WI-11, moved into the inspector
## by WI-51). One toggle per floor, top floor first - `TurboliftShaft.floors` is
## sorted by cell Y, so the list reads the way the shaft looks.

var _shaft: TurboliftShaft = null
var _rows: Dictionary[ModuleTurbolift, CheckButton] = {}

func set_shaft(shaft: TurboliftShaft) -> void:
	name = "Floors"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.LINE_GAP)
	_shaft = shaft
	rebuild()

func rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rows.clear()
	if _shaft == null:
		return
	for lift: ModuleTurbolift in _shaft.floors:
		var row := CheckButton.new()
		row.text = "Floor %d" % TurboshaftTabSet.floor_number(_shaft, lift)
		row.focus_mode = Control.FOCUS_NONE
		row.set_pressed_no_signal(lift.floor_enabled)
		row.toggled.connect(func(toggled_on: bool) -> void: lift.floor_enabled = toggled_on)
		add_child(row)
		_rows[lift] = row
