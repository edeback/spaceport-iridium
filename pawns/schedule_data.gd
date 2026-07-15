class_name ScheduleData
extends Resource

## A pawn's 24-hour schedule (WI-06): one slot per game-hour of the cycle.
## v1 has two slot types - WORK (eligible for board jobs) and REST (needs,
## errands, and idling only). SLEEP as a distinct slot type can wait: pawns
## already self-manage sleep through the needs system.
##
## Instances are per-pawn mutable state (the schedule tab paints them), so
## PawnBase duplicates its exported schedule in _ready - the same
## shared-subresource trap StorageData had.

enum Slot { WORK, REST }

## One entry per hour; index = hour of cycle (0-23).
@export var slots: Array[int] = []
		

signal this_shift_changed

func _init() -> void:
	# Loaded .tres values overwrite this after _init; this only guarantees a
	# well-formed default for schedules constructed in code.
	if slots.size() != TimeManager.HOURS_PER_CYCLE:
		slots.resize(TimeManager.HOURS_PER_CYCLE)
		slots.fill(Slot.WORK)

func is_work_hour(hour: int) -> bool:
	if hour < 0 or hour >= slots.size():
		return true
	return slots[hour] == Slot.WORK

## Use this to set the internal value of slots
func set_slot_value(hour: int, value: Slot) -> void:
	if hour >= 0 and hour < slots.size():
		slots[hour] = value
		if hour == Global.time_manager.hour:
			this_shift_changed.emit()
	

## Shift A: on duty 06-18.
static func shift_a() -> ScheduleData:
	return _make_shift(6, 18)

## Shift B: on duty 18-06 (wraps midnight).
static func shift_b() -> ScheduleData:
	return _make_shift(18, 6)

## WORK in [work_start, work_end) mod 24, REST elsewhere.
static func _make_shift(work_start: int, work_end: int) -> ScheduleData:
	var schedule := ScheduleData.new()
	for hour: int in schedule.slots.size():
		var working: bool
		if work_start <= work_end:
			working = hour >= work_start and hour < work_end
		else:
			working = hour >= work_start or hour < work_end
		schedule.slots[hour] = Slot.WORK if working else Slot.REST
	return schedule
