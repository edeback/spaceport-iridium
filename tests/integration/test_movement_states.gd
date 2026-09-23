extends GutTest

## WI-75: movement without coroutines, on a live station.
##
## Every wait a walk can hit is a state of PawnMovementComponent now - a door
## (Waiting), a turbolift queue walk and the walk into the cab (ManualWalk), the
## queue spot (Held), the ride (Conveyed) - and every one of them is saved. So this
## suite checks three things the coroutines could not offer:
##
## - **The states are real.** A crew member crossing the starting airlock is seen
##   waiting at each door for as long as that door takes, and a ride between two
##   floors is seen passing through every phase of its RideRequest.
## - **They end.** A floor switched off in the queue, a cab destroyed while a pawn
##   is walking into it and a day of lift traffic all leave every pawn somewhere
##   valid and nobody waiting on something that will never come.
## - **A reload changes nothing** (the author's settling of WI-75 §0.3). The game
##   is saved with a pawn at each phase, and then *forked*: the live game runs on,
##   the save is loaded and run again over the same stretch, and the two traces
##   must match exactly - state, ride phase and position, every quarter second.
##   The other crew are frozen in both runs so that their random wandering, which
##   no save can replay, stays out of it.

## The station [method _build_lift] adds beside the starting corridor: a four-floor
## shaft at x = 14, a corridor on its top floor (row 9, the starting station's)
## and its bottom one (row 12), and power.
const SHAFT_X: int = 14
const TOP_ROW: int = 9
const BOTTOM_ROW: int = 12
## Where a trip down ends: the bottom corridor's east end.
const BOTTOM_STOP: Vector2i = Vector2i(16, 12)
## Where a trip up ends: the top corridor's west end.
const TOP_STOP: Vector2i = Vector2i(12, 9)
## A pile in open space east of the starting airlock, for a walk that has to
## cross it.
const OUTSIDE_CELL: Vector2i = Vector2i(24, 9)
## A fork's run, and how often it is sampled.
const FORK_SECONDS: float = 12.0
const SAMPLE_SECONDS: float = 0.25

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

# --- doors ----------------------------------------------------------------------

func test_a_crew_member_crosses_an_airlock_waiting_at_each_door() -> void:
	var pawn: PawnBase = fx.pawns()[0]
	var movement: PawnMovementComponent = pawn.movement_component
	var arrived_travelling: Array[bool] = []
	movement.movement_ended.connect(func(success: bool) -> void:
		if success:
			arrived_travelling.append(movement.is_traveling()))
	var job: Job = _send_outside(pawn)
	var waits: Array[float] = await _door_waits(pawn, job, 1.0)
	assert_eq(job.outcome(), Job.Outcome.SUCCEEDED, "the walk outside finished")
	assert_eq(waits.size(), 2, "one wait at each of the airlock's two doors")
	if waits.size() == 2:
		# The inner door swings open (one second); the outer then waits for the
		# inner to finish shutting behind the pawn and swings open itself - the
		# order Behavior_LinkedDoors' awaits ran in, now DoorMotion's schedule.
		assert_almost_eq(waits[0], 1.0, 0.05, "the inner door's swing")
		assert_between(waits[1], 1.5, 2.05, "the inner door shutting, then the outer's swing")
	assert_eq(arrived_travelling, [false] as Array[bool],
		"and on arrival nothing reports the pawn as travelling")

func test_door_waits_last_as_long_at_4x_in_sim_time() -> void:
	var pawn: PawnBase = fx.pawns()[0]
	var job: Job = _send_outside(pawn)
	var waits: Array[float] = await _door_waits(pawn, job, 4.0)
	assert_eq(waits.size(), 2, "no door skipped at 4x")
	if waits.size() == 2:
		# A 4x frame is a fifteenth of a second of sim; a wait is timed to within
		# one of them, and never shortened by carrying a frame's leftover on.
		assert_almost_eq(waits[0], 1.0, 4.0 / 60.0 + 0.001, "the same swing, in sim time")

func test_a_paused_game_freezes_a_door_wait() -> void:
	var pawn: PawnBase = fx.pawns()[0]
	var movement: PawnMovementComponent = pawn.movement_component
	_send_outside(pawn)
	assert_true(await _tick_until_state(pawn, PawnMovementComponent.State.Waiting, 30.0))
	var left: float = movement._wait_left
	Global.time_manager.hold_pause(&"wi75_test")
	for frame: int in 30:
		await get_tree().process_frame
	assert_almost_eq(movement._wait_left, left, 0.00001, "half a second of paused frames took nothing off")
	assert_eq(movement.state, PawnMovementComponent.State.Waiting)
	Global.time_manager.release_pause(&"wi75_test")

# --- turbolifts -----------------------------------------------------------------

func test_a_pawn_rides_between_floors_through_every_phase() -> void:
	_build_lift()
	var pawn: PawnBase = fx.pawns()[0]
	var job: Job = _send(pawn, _bottom_stop())
	var phases: Array[int] = []
	var finished: bool = await fx.tick_until(func() -> bool:
		var phase: int = _phase(pawn)
		if phase >= 0 and (phases.is_empty() or phases[phases.size() - 1] != phase):
			phases.append(phase)
		return job.is_ended(), 30.0, 1.0 / 60.0, 1.0)
	assert_true(finished, "the trip ended")
	assert_eq(job.outcome(), Job.Outcome.SUCCEEDED, "and the job it was for completed")
	assert_eq(phases, [RideRequest.Phase.QUEUEING, RideRequest.Phase.WAITING,
		RideRequest.Phase.BOARDING, RideRequest.Phase.ONBOARD] as Array[int],
		"queue walk, wait, walk in, ride")
	assert_eq(pawn.current_module, _bottom_stop(), "and the pawn is at the bottom")
	assert_null(pawn.movement_component.ride, "with the ride let go of")
	assert_false(pawn.get_parent() is TurboliftCab, "and out of the cab")

func test_a_floor_switched_off_under_the_queue_fails_the_ride_cleanly() -> void:
	_build_lift()
	var pawn: PawnBase = fx.pawns()[0]
	var job: Job = _send(pawn, _bottom_stop())
	assert_true(await _tick_until_phase(pawn, RideRequest.Phase.WAITING), "the pawn is waiting at the lift")
	var request: RideRequest = pawn.movement_component.ride
	var queue_path: PathComponent = request.queue_path
	var top_floor: ModuleTurbolift = request.from_floor
	top_floor.floor_enabled = false
	assert_null(pawn.movement_component.ride, "the ride is dropped")
	assert_eq(request.phase, RideRequest.Phase.CANCELLED)
	assert_ne(pawn.movement_component.state, PawnMovementComponent.State.Held, "nobody holds the pawn in the queue")
	if queue_path != null:
		assert_false(queue_path._anchor_claims.has(request.get_instance_id()), "its queue spot is free again")
	assert_true(await fx.tick(1.0, 1.0))
	assert_true(job.is_ended(), "the walk failed, and its job with it")
	assert_eq(job.outcome(), Job.Outcome.FAILED)
	assert_true(await fx.tick(10.0), "and the pawn carries on with something else")
	assert_null(pawn.movement_component.ride)

func test_a_cab_destroyed_mid_boarding_drops_the_pawn_where_it_stands() -> void:
	_build_lift()
	var pawn: PawnBase = fx.pawns()[0]
	var job: Job = _send(pawn, _bottom_stop())
	assert_true(await _tick_until_phase(pawn, RideRequest.Phase.BOARDING), "the pawn is walking into the cab")
	var request: RideRequest = pawn.movement_component.ride
	var cab: TurboliftCab = request.cab
	cab.shaft.cabs.erase(cab)
	cab.destroy()
	assert_null(pawn.movement_component.ride, "the ride is over")
	assert_eq(pawn.movement_component.state, PawnMovementComponent.State.Idle, "the pawn stands where it was")
	assert_false(pawn.get_parent() == cab, "and is not taken down with the cab")
	assert_eq(pawn.current_module, request.from_floor, "on the floor it was boarding at")
	assert_true(await fx.tick(1.0, 1.0))
	assert_true(job.is_ended(), "its walk failed with the ride")
	assert_true(await fx.tick(10.0), "and it carries on with something else")
	assert_true(is_instance_valid(pawn), "alive")

func test_a_ride_called_off_aboard_gets_off_at_the_next_stop() -> void:
	_build_lift()
	var pawn: PawnBase = fx.pawns()[0]
	_send(pawn, _bottom_stop())
	assert_true(await _tick_until_phase(pawn, RideRequest.Phase.ONBOARD), "aboard")
	var request: RideRequest = pawn.movement_component.ride
	# A new errand while riding: the cab never drops a pawn between floors.
	var errand: Job = _send(pawn, _top_stop())
	assert_eq(pawn.movement_component.state, PawnMovementComponent.State.Conveyed, "still aboard")
	assert_null(request.to_floor, "the ride is called off")
	var off: bool = await fx.tick_until(func() -> bool: return pawn.movement_component.ride == null, 20.0, 0.1, 1.0)
	assert_true(off, "and got off at a floor")
	assert_true(pawn.current_module is ModuleTurbolift, "a real floor of the shaft")
	assert_true(await fx.tick_until(func() -> bool: return errand.is_ended(), 30.0, 0.25, 1.0),
		"and the new errand runs from there")
	assert_eq(errand.outcome(), Job.Outcome.SUCCEEDED)

func test_a_day_of_lift_traffic_leaves_nobody_stuck() -> void:
	_build_lift()
	var longest_wait: float = 0.0
	var longest_carry: float = 0.0
	var waiting_for: Dictionary[int, float] = {}
	var carried_for: Dictionary[int, float] = {}
	var trips: int = 0
	var step: float = 0.25
	var elapsed: float = 0.0
	while elapsed < TimeManager.SECONDS_PER_HOUR * 24.0:
		# Anyone idling is sent to the other floor, so the shaft is always busy
		# without taking anyone away from eating or sleeping.
		for pawn: PawnBase in fx.pawns():
			if pawn.current_job == null or pawn.current_job.is_idle_type():
				var going_down: bool = pawn.global_position.y < Global.cell_to_world(Vector2i(0, 11)).y
				_send(pawn, _bottom_stop() if going_down else _top_stop())
				trips += 1
		if not await fx.tick(step):
			break
		elapsed += step
		for pawn: PawnBase in fx.pawns():
			var id: int = pawn.get_instance_id()
			var movement: PawnMovementComponent = pawn.movement_component
			waiting_for[id] = waiting_for.get(id, 0.0) + step if movement.state == PawnMovementComponent.State.Waiting else 0.0
			carried_for[id] = carried_for.get(id, 0.0) + step if movement.ride != null else 0.0
			longest_wait = maxf(longest_wait, waiting_for[id])
			longest_carry = maxf(longest_carry, carried_for[id])
	assert_gt(trips, 20, "the lift was busy")
	assert_lt(longest_wait, 3.0, "no door wait outlasted its doors")
	assert_lt(longest_carry, 60.0, "no ride - queue, wait, boarding and trip - took a minute")
	assert_true(fx.check_invariants("after a day of lift traffic"))

# --- the teleporter -------------------------------------------------------------

func test_the_teleporter_flash_is_a_wait_in_sim_time() -> void:
	var teleporter: ModuleTeleporter = fx.place(&"module_teleporter", Vector2i(30, 4)) as ModuleTeleporter
	assert_not_null(teleporter)
	if teleporter == null:
		return
	var edge := PathComponent.PathTraversalEdgeData.new()
	edge.edge_meta = &"run_teleporter"
	edge.start_index = teleporter.teleporter_path_index - 1
	edge.end_index = teleporter.teleporter_path_index
	var flash: float = DoorMotion.animation_seconds(teleporter.lightning_sprite.sprite_frames, &"teleport")
	var result: PathHookResult = teleporter.traverse(fx.pawns()[0], edge)
	assert_eq(result.kind, PathHookResult.Kind.WAIT, "stepping on waits for the flash")
	assert_almost_eq(result.seconds, flash, 0.0001, "the whole flash")
	assert_true(teleporter.lightning_sprite.visible)
	var saved: Dictionary = teleporter.get_save_data()
	assert_true(saved.has("flash"), "a save mid-flash carries it")
	assert_true(await fx.tick(flash + 0.1, 1.0))
	assert_false(teleporter.lightning_sprite.visible, "and it is over when the wait is")
	assert_false(teleporter.get_save_data().has("flash"))

# --- a reload changes nothing (WI-75 §0.3, as the author settled it) -------------

func test_a_save_at_the_lift_queue_walk_reloads_unchanged() -> void:
	await _fork_at_phase(RideRequest.Phase.QUEUEING)

func test_a_save_in_the_lift_queue_reloads_unchanged() -> void:
	await _fork_at_phase(RideRequest.Phase.WAITING)

func test_a_save_mid_boarding_reloads_unchanged() -> void:
	await _fork_at_phase(RideRequest.Phase.BOARDING)

func test_a_save_aboard_a_cab_reloads_unchanged() -> void:
	await _fork_at_phase(RideRequest.Phase.ONBOARD)

func test_a_save_at_an_airlock_door_reloads_unchanged() -> void:
	var pawn: PawnBase = fx.pawns()[0]
	_freeze_all_but(pawn.pawn_id)
	_send_outside(pawn)
	assert_true(await _tick_until_state(pawn, PawnMovementComponent.State.Waiting, 30.0),
		"a crew member is waiting at the airlock's door")
	await _fork(pawn.pawn_id)

func test_a_save_part_way_along_a_path_reloads_unchanged() -> void:
	_build_lift()
	var pawn: PawnBase = fx.pawns()[0]
	_freeze_all_but(pawn.pawn_id)
	_send(pawn, _bottom_stop())
	# Half a second in: walking the top corridor, part way along its sub-path.
	assert_true(await fx.tick(0.5, 1.0))
	assert_eq(pawn.movement_component.state, PawnMovementComponent.State.Moving, "walking")
	await _fork(pawn.pawn_id)

# --- forks ----------------------------------------------------------------------

func _fork_at_phase(phase: RideRequest.Phase) -> void:
	_build_lift()
	var pawn: PawnBase = fx.pawns()[0]
	_freeze_all_but(pawn.pawn_id)
	_send(pawn, _bottom_stop())
	assert_true(await _tick_until_phase(pawn, phase), "the ride reached %s" % RideRequest.Phase.keys()[phase])
	await _fork(pawn.pawn_id)

## Saves, runs the live game on for FORK_SECONDS, loads the save, runs the same
## stretch again, and asserts the two runs are the same run. Also that the load
## put the pawn back exactly as it was saved, and that a save written straight
## after the load is the save that was loaded.
func _fork(pawn_id: int) -> void:
	var at_save: String = _snapshot(_pawn(pawn_id))
	assert_true(fx.save())
	var live_save: Dictionary = fx.read_save()
	var live: PackedStringArray = await _trace(pawn_id)
	assert_true(await fx.reload_saved(), "the save loads")
	_freeze_all_but(pawn_id)
	assert_not_null(_pawn(pawn_id), "the pawn is back")
	if _pawn(pawn_id) == null:
		return
	assert_eq(_snapshot(_pawn(pawn_id)), at_save, "exactly where and how it was saved")
	assert_true(fx.save())
	assert_eq(StationFixture.diff(StationFixture.restored_form(live_save["sections"]),
		fx.read_save()["sections"]), PackedStringArray(),
		"and a save straight after the load is the save that was loaded")
	var loaded: PackedStringArray = await _trace(pawn_id)
	assert_lt(live.size(), roundi(FORK_SECONDS / SAMPLE_SECONDS), "the live trip finished inside the fork")
	for index: int in mini(live.size(), loaded.size()):
		if live[index] != loaded[index]:
			fail_test("the reloaded run left the live one %.2f s in:\n  live   %s\n  loaded %s"
				% [(index + 1) * SAMPLE_SECONDS, live[index], loaded[index]])
			return
	assert_eq(loaded.size(), live.size(), "and the trip ended on the same sample in both")

## The pawn, every SAMPLE_SECONDS, for as long as the trip it was sent on lasts -
## and not a sample longer: once it arrives it picks its next job, and an idle
## wander's destination is a random roll that no save can replay.
func _trace(pawn_id: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for sample: int in roundi(FORK_SECONDS / SAMPLE_SECONDS):
		if not await fx.tick(SAMPLE_SECONDS, 1.0):
			break
		var pawn: PawnBase = _pawn(pawn_id)
		if pawn == null or pawn.current_job == null or not pawn.current_job.is_type(&"move_to_location"):
			break
		out.append(_snapshot(pawn))
	return out

## Everything about a pawn's walk a player could see or the sim could act on:
## state, ride phase, position, where it is and what it is parented to, the walk's
## place on its path and any wait - plus the cab carrying it or the airlock doors
## it is at. Objects are named by what they are, never by instance names, which a
## load regenerates.
func _snapshot(pawn: PawnBase) -> String:
	var movement: PawnMovementComponent = pawn.movement_component
	var parts: PackedStringArray = [
		PawnMovementComponent.State.keys()[movement.state],
		RideRequest.Phase.keys()[movement.ride.phase] if movement.ride != null else "-",
		"(%.3f, %.3f)" % [pawn.global_position.x, pawn.global_position.y],
		"in " + _describe_node(pawn.current_module),
		"under " + _describe_node(pawn.get_parent()),
		"path %d/%d sub %d/%d step %d wait %.4f" % [movement.next_path_index, movement.path.size(),
			movement.sub_path_index, movement.sub_path.size(), movement._step, movement._wait_left],
	]
	if movement.ride != null and movement.ride.cab != null:
		parts.append("cab " + JSON.stringify(movement.ride.cab.to_dict()))
	var module: ModuleBase = pawn.current_module
	if module != null and module.get_path_component() != null:
		parts.append("doors " + JSON.stringify(module.get_path_component().get_save_data()))
	return " | ".join(parts)

static func _describe_node(node: Node) -> String:
	if node == null:
		return "nothing"
	var module: ModuleBase = node as ModuleBase
	if module != null:
		return "%s@%s" % [module.module_data.id, module.module_cell]
	if node is TurboliftCab:
		return "cab"
	return String(node.name)

# --- helpers --------------------------------------------------------------------

func _build_lift() -> void:
	for row: int in range(TOP_ROW, BOTTOM_ROW + 1):
		fx.place(&"turbolift_mdata", Vector2i(SHAFT_X, row))
	fx.corridor(TOP_ROW, TOP_STOP.x, 17)
	fx.corridor(BOTTOM_ROW, TOP_STOP.x, BOTTOM_STOP.x)
	fx.place(&"debug_power", Vector2i(12, 8))

func _bottom_stop() -> ModuleBase:
	return Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.CORRIDOR, BOTTOM_STOP)

func _top_stop() -> ModuleBase:
	return Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.CORRIDOR, TOP_STOP)

## Sends `pawn` to `destination` on a move job, dropping whatever it was doing.
func _send(pawn: PawnBase, destination: Node) -> Job:
	var target: JobTarget = JobTarget.of_module(destination as ModuleBase) if destination is ModuleBase \
		else JobTarget.of_pile(destination as ResourcePile)
	var job: Job = Job.of(&"move_to_location").with_target_a(target)
	pawn.interrupt_with_job(job)
	return job

## Sends `pawn` out through the starting airlock to a pile in open space.
func _send_outside(pawn: PawnBase) -> Job:
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.SPACE)
	var pile := ResourcePile.spawn(canvas, Global.cell_to_world(OUTSIDE_CELL, true))
	pile.add_amount(fx.resource(&"iron_ore"), 1)
	return _send(pawn, pile)

## Every door wait `pawn` stands through until `job` ends, each as the sim-seconds
## it lasted.
func _door_waits(pawn: PawnBase, job: Job, speed: float) -> Array[float]:
	var waits: Array[float] = []
	# A dictionary, not a float: a lambda captures locals by value, so a float it
	# reassigned would be back at -1 on the next call.
	var started: Dictionary = {"at": -1.0}
	var time: TimeManager = Global.time_manager
	await fx.tick_until(func() -> bool:
		var waiting: bool = pawn.movement_component.state == PawnMovementComponent.State.Waiting
		var at: float = float(started["at"])
		if waiting and at < 0.0:
			started["at"] = time.total_sim_seconds
		elif not waiting and at >= 0.0:
			waits.append(time.total_sim_seconds - at)
			started["at"] = -1.0
		return job.is_ended(), 60.0, 1.0 / 60.0, speed)
	return waits

func _tick_until_state(pawn: PawnBase, state: PawnMovementComponent.State, seconds: float) -> bool:
	return await fx.tick_until(func() -> bool: return pawn.movement_component.state == state,
		seconds, 1.0 / 60.0, 1.0)

func _tick_until_phase(pawn: PawnBase, phase: RideRequest.Phase) -> bool:
	return await fx.tick_until(func() -> bool: return _phase(pawn) == phase, 30.0, 1.0 / 60.0, 1.0)

func _phase(pawn: PawnBase) -> int:
	var ride: RideRequest = pawn.movement_component.ride
	return int(ride.phase) if ride != null else -1

func _pawn(pawn_id: int) -> PawnBase:
	for pawn: PawnBase in fx.pawns():
		if pawn.pawn_id == pawn_id:
			return pawn
	return null

## Stops every other pawn in its tracks - in the live run and again straight after
## the load, before a frame has passed, so both runs hold them at the save.
func _freeze_all_but(pawn_id: int) -> void:
	for pawn: PawnBase in fx.pawns():
		if pawn.pawn_id != pawn_id:
			pawn.process_mode = Node.PROCESS_MODE_DISABLED
