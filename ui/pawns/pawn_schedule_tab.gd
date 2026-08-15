class_name PawnScheduleTab
extends PanelContainer

## 24-cell WORK/REST schedule editor (WI-06). Click a cell to toggle it,
## hold and drag to paint the clicked value across cells. Edits mutate the
## pawn's own duplicated ScheduleData and apply at the next job selection -
## never mid-job.
##
## **WI-58 folded it into the design system.** It painted the same on/off-shift
## fact as the Crew panel's SHIFT ROTA - one keypress away - in a colour language
## of its own (`Color(0.29, 0.55, 0.85)` and `Color(0.22, 0.22, 0.28)` as raw
## floats), and its hour ticks and legend sat at 10px, under the design's own
## 11px floor, on a live inspector tab. Both colours are
## [method UIPalette.shift_cell] now and the type comes from [UIType].

## One paint cell. The original 11x22 was under any reasonable hit target for a
## control the player is expected to *drag* across.
##
## The height went to 24 - the design's list-item square - and the width did not,
## because it cannot: twenty-four hours at 24px is 599px of cells inside a 420px
## inspector, and a page wider than the panel does not clip, it **widens the
## panel**. A first pass at 24 square pushed the whole selection surface out to
## ~515px, which a screenshot caught and no headless check could have.
##
## So this is a floor, not a size: the cells are `SIZE_EXPAND_FILL` and share
## whatever the tab is given, which is about 15px each at the design resolution.
const CELL := Vector2(14, 24)

var pawn: PawnBase = null
var _cells: Array[ColorRect] = []
var _painting: bool = false
var _paint_value: int = ScheduleData.Slot.WORK

func set_pawn(_pawn: PawnBase) -> void:
	pawn = _pawn
	var has_schedule: bool = pawn != null and pawn.schedule != null
	%NoScheduleLabel.visible = not has_schedule
	%ScheduleRows.visible = has_schedule
	if not has_schedule:
		return
	if _cells.is_empty():
		_build_cells()
	_refresh()

func _build_cells() -> void:
	for hour: int in TimeManager.HOURS_PER_CYCLE:
		var cell := ColorRect.new()
		cell.custom_minimum_size = CELL
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.tooltip_text = "%02d:00" % hour
		cell.gui_input.connect(_on_cell_gui_input.bind(hour))
		cell.mouse_entered.connect(_on_cell_mouse_entered.bind(hour))
		%CellRow.add_child(cell)
		_cells.append(cell)

func _on_cell_gui_input(event: InputEvent, hour: int) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		# First cell toggles; the drag then paints that same value.
		_paint_value = ScheduleData.Slot.REST if pawn.schedule.slots[hour] == ScheduleData.Slot.WORK \
				else ScheduleData.Slot.WORK
		_painting = true
		_apply(hour)
	else:
		_painting = false

func _on_cell_mouse_entered(hour: int) -> void:
	# Physical button state is the truth - covers releasing outside any cell.
	if _painting and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_apply(hour)
	else:
		_painting = false

func _apply(hour: int) -> void:
	pawn.schedule.set_slot_value(hour, _paint_value)
	_refresh()

func _refresh() -> void:
	var current_hour: int = Global.time_manager.hour if Global.time_manager != null else -1
	for hour: int in _cells.size():
		_cells[hour].color = UIPalette.shift_cell(
			pawn.schedule.slots[hour] == ScheduleData.Slot.WORK, hour == current_hour)
