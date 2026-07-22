class_name InspectionRunner
extends Node

## Drives one ARC station inspection (WI-26). Spawned by UnlockManager when the
## player accepts an inspection offer; frees itself when the run resolves.
##
## Flow: an ARC ship flies to the docking bay -> the inspector disembarks ->
## sequentially walks to one built module per checklist tag (nearest instance),
## dwelling a sim-hour at each -> if every target is toured, the station is
## promoted (pass); if the inspector is harmed, ejected, or a target becomes
## unreachable, the run fails. Either way the inspector leaves and the ship
## departs. A separate node (not a section of UnlockManager) so its per-frame
## state machine and the spawned entities own a clean lifecycle.
##
## Runtime-only: nothing here is saved. A save taken mid-inspection reloads with
## no inspector and the offer re-rolls (UnlockManager drops the in-progress flag).

const SHIP_SCENE: PackedScene = preload("res://objects/arrival_shuttle.tscn")
const INSPECTOR_SCENE: PackedScene = preload("res://pawns/inspector_pawn.tscn")
## Fly-in distance for the ARC ship, matching the trader/crew shuttles.
const SHIP_APPROACH_DISTANCE: float = 1400.0

enum State { INBOUND, TOURING, DWELLING, LEAVING }

var _state: State = State.INBOUND
var _bay: ModuleBase
var _ship: ArrivalShuttle
var _inspector: InspectorPawn
var _checklist: Array[String] = []
var _index: int = 0
var _current_target: ModuleBase
var _leg_job: Job_MoveToLocation
var _wait_job: Job_Wait

var _dwell_hours: float = 1.0
var _health_fail_threshold: float = 70.0
## True once pass/fail is decided: fail checks stop and the inspector heads out.
var _resolved: bool = false

## Configured by UnlockManager before begin(): which bay to dock at, the tour
## checklist (module tags), and the dwell/health-fail tunables.
func setup(bay: ModuleBase, checklist: Array[String], dwell_hours: float, health_fail_threshold: float) -> void:
	_bay = bay
	_checklist = checklist.duplicate()
	_dwell_hours = dwell_hours
	_health_fail_threshold = health_fail_threshold

## Flies the ARC ship in. The inspector disembarks once it docks.
func begin() -> void:
	if not is_instance_valid(_bay):
		_fail("the docking bay was lost")
		return
	if SHIP_SCENE == null:
		_on_ship_docked()
		return
	_ship = SHIP_SCENE.instantiate() as ArrivalShuttle
	Global.world_manager.pawn_layer.add_child(_ship)
	var dock: Vector2 = DockingBay.dock_position_for(_bay)
	_ship.setup(dock, dock + Vector2(DockingBay.approach_sign_for(_bay) * SHIP_APPROACH_DISTANCE, 0.0))
	_ship.docked.connect(_on_ship_docked, CONNECT_ONE_SHOT)
	SignalBus.station_alert.emit("An ARC inspection vessel is approaching the docking bay.")

func _on_ship_docked() -> void:
	if not is_instance_valid(_bay):
		_fail("the docking bay was lost")
		return
	_inspector = INSPECTOR_SCENE.instantiate() as InspectorPawn
	Global.world_manager.pawn_layer.add_child(_inspector)
	_inspector.current_module = _bay
	_inspector.global_position = Global.cell_to_world(_bay.module_cell, true)
	SignalBus.station_alert.emit("The ARC inspector has come aboard for a tour.")
	_start_next_leg()

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	if _resolved:
		return
	# Sabotage / hazard checks run every tick the inspector is aboard and touring.
	if _state == State.TOURING or _state == State.DWELLING:
		if _check_fail_conditions():
			return
	match _state:
		State.TOURING:
			_tick_touring()
		State.DWELLING:
			_tick_dwelling()

# --- touring ------------------------------------------------------------------

## Picks the next checklist target and walks the inspector there. Advancing past
## the end of the list means every facility was toured - a pass.
func _start_next_leg() -> void:
	if _index >= _checklist.size():
		_pass()
		return
	var tag: String = _checklist[_index]
	var target: ModuleBase = _nearest_built_with_tag(tag)
	if target == null:
		_fail("no %s facility to inspect" % tag)
		return
	# Cheap is_reachable check before committing the leg (WI-26 design): a target
	# walled off before we set out fails cleanly rather than stranding the pawn.
	if not Global.path_manager.is_reachable(_inspector, target):
		_fail("the %s facility was unreachable" % tag)
		return
	_current_target = target
	_state = State.TOURING
	_leg_job = Job_MoveToLocation.new()
	_leg_job.destination_module = target
	_inspector.interrupt_with_job(_leg_job)

func _tick_touring() -> void:
	if _leg_job == null or not _leg_job.is_ended():
		return
	# The move ended. Arrived -> dwell; failed to arrive (target deconstructed or
	# corridor cut mid-route) -> fail.
	if _leg_job.is_finished() and _inspector.current_module == _current_target:
		_begin_dwell()
	else:
		_fail("the %s facility became unreachable" % _checklist[_index])

func _begin_dwell() -> void:
	_state = State.DWELLING
	# A wait job keeps the inspector non-idle so the breathing component damages
	# (but never flees) it in a vented section - the low-O2 fail path (WI-26).
	_wait_job = Job_Wait.new()
	_wait_job.duration = _dwell_hours * TimeManager.SECONDS_PER_HOUR
	_inspector.interrupt_with_job(_wait_job)

func _tick_dwelling() -> void:
	if _wait_job == null or not _wait_job.is_ended():
		return
	_index += 1
	_start_next_leg()

# --- fail detection -----------------------------------------------------------

## Returns true (and calls _fail) if the inspector is harmed or ejected. Checked
## only while touring/dwelling; once resolved the inspector is just leaving.
func _check_fail_conditions() -> bool:
	if not is_instance_valid(_inspector):
		_fail("the inspector was lost")
		return true
	# Ejected: the module they were standing in was removed (PawnBase nulls
	# current_module on module_removed), dumping them to space.
	if _inspector.current_module == null:
		_fail("the inspector was ejected into space")
		return true
	var health: PawnHealthComponent = _inspector.get_component_by_type(PawnHealthComponent) as PawnHealthComponent
	if health != null and health.health_value < _health_fail_threshold:
		_fail("the inspector was harmed by unsafe conditions")
		return true
	return false

# --- resolution ---------------------------------------------------------------

func _pass() -> void:
	if _resolved:
		return
	_resolved = true
	SignalBus.station_alert.emit("The ARC inspector is satisfied. Promotion approved!")
	if Global.unlock_manager != null:
		Global.unlock_manager.on_inspection_passed()
	_send_inspector_home()

func _fail(reason: String) -> void:
	if _resolved:
		return
	_resolved = true
	SignalBus.station_alert.emit("ARC inspection failed: %s. The inspector is leaving." % reason)
	if Global.unlock_manager != null:
		Global.unlock_manager.on_inspection_failed(reason)
	_send_inspector_home()

## Walks the inspector back to the bay (cosmetic) then departs. If the bay is
## gone or unreachable, just despawns and departs immediately.
func _send_inspector_home() -> void:
	_state = State.LEAVING
	if not is_instance_valid(_inspector):
		_finish_departure()
		return
	if is_instance_valid(_bay) and _inspector.current_module != null \
			and Global.path_manager.is_reachable(_inspector, _bay):
		var go_home: Job_MoveToLocation = Job_MoveToLocation.new()
		go_home.destination_module = _bay
		go_home.job_end.connect(_finish_departure, CONNECT_ONE_SHOT)
		_inspector.interrupt_with_job(go_home)
	else:
		_finish_departure()

func _finish_departure() -> void:
	if is_instance_valid(_inspector):
		_inspector.queue_free()
	_inspector = null
	if is_instance_valid(_ship):
		_ship.depart()
	_ship = null
	queue_free()

# --- helpers ------------------------------------------------------------------

## Nearest built module carrying `tag` to the inspector's current position.
func _nearest_built_with_tag(tag: String) -> ModuleBase:
	var origin: Vector2 = _inspector.global_position if is_instance_valid(_inspector) else Vector2.ZERO
	var best: ModuleBase = null
	var best_dist: float = -1.0
	for node: Node in get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null or not module.is_complete() or module.module_data == null:
			continue
		if not module.module_data.tags.has(tag):
			continue
		var dist: float = module.get_global_center().distance_squared_to(origin)
		if best == null or dist < best_dist:
			best = module
			best_dist = dist
	return best
