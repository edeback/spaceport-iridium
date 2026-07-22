class_name ArrivalShuttle
extends Sprite2D

## Crew-delivery shuttle visual (WI-07). Movement is sim-scaled by hand -
## tweens run on the wall clock and would ignore pause and game speed.
## Lifecycle: setup() -> flies to the dock -> emits `docked` (once) ->
## owner responds (spawns the crew) and calls depart() -> flies back out
## along its approach path and frees itself.

## Pixels per sim-second.
@export var speed: float = 400.0

signal docked

var _target: Vector2
var _exit_point: Vector2
var _departing: bool = false
var _docked_fired: bool = false

## Every ship-like node (crew/visitor arrivals, the trader shuttle, and the ARC
## inspector ship all reuse this script) joins minimap_tracked so the minimap
## renders it as a triangle without hard-coding any manager (WI-34).
func _ready() -> void:
	add_to_group(Groups.MINIMAP_TRACKED)

func setup(dock_position: Vector2, approach_from: Vector2) -> void:
	global_position = approach_from
	_target = dock_position
	_exit_point = approach_from
	flip_h = _target.x < global_position.x

func depart() -> void:
	_departing = true
	_target = _exit_point
	flip_h = _target.x < global_position.x

func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	global_position = global_position.move_toward(_target, speed * sim_delta)
	if global_position.distance_to(_target) > 0.5:
		return
	if _departing:
		queue_free()
	elif not _docked_fired:
		_docked_fired = true
		docked.emit()
