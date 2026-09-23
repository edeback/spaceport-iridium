class_name PawnMovementComponent
extends PawnComponentBase

## Walks a pawn along a graph path, one state at a time (WI-75).
##
## Nothing in here awaits. The walk used to be a coroutine chain - `move` awaited
## `reached_next_node`, which awaited a module's door hook and then
## `reached_next_subpath`, which awaited `move` again - and a pawn at a door or in
## a turbolift queue was a suspended call that could not be saved, stepped or
## asserted, and that never resumed if its module was freed first (F28). Every
## wait is now one of the states below, advanced in `_process`, and a save carries
## all of them: a pawn saved at an airlock door, in a lift queue or half way into
## a cab loads exactly there, doing exactly that.

var target: Node2D
var speed: float = 1.0
var end_in_space: bool = false
## Optional interior destination in the target module (WI-16): the final
## module's sub-path ends at this anchor instead of the door/center. Survives
## repaths (the anchor lives in the target module, which must still exist).
var target_anchor: AnchorDef = null

var next_path_index: int = 0
var path: Array[ModuleGraph.PathPoint] = []
var nodes_to_watch: Array[Node2D] = []

var in_sub_path: bool = false
var sub_path: Array[PathComponent.PathTraversalEdgeData]
var sub_path_index: int = 0

## - **Idle**: going nowhere.
## - **Moving**: walking the path.
## - **Waiting**: stood at a module whose hook asked for time - a door swinging,
##   the teleporter's flash. [member _wait_left] counts it down in sim time.
## - **ManualWalk**: a straight-line walk a carrier asked for - to a turbolift
##   queue spot, or into the cab. Interiors are open boxes, so the line is safe.
## - **Held**: a carrier has taken over and the pawn stands where it was put,
##   waiting for it - a lift queue spot until the cab comes.
## - **Conveyed** (WI-20): a carrier (turbolift cab today) owns the pawn's
##   position. Repaths wait until it lets go.
enum State { Idle, Moving, Waiting, ManualWalk, Held, Conveyed }
var state: State = State.Idle
## The Node2D driving our position while Conveyed; null otherwise.
var conveyor: Node2D = null
## The turbolift ride holding this pawn - from the queue walk to the drop-off -
## or null. Its phase says where in that it is (WI-75 §5).
var ride: RideRequest = null

## What arriving at a path point still has to do - the hooks and the entering -
## so a wait in the middle of it resumes on the step after the hook that asked
## for it. Arriving used to be the call stack of the coroutine chain, and the
## place a hook suspended was simply where the stack was.
enum Step {
	NONE,        ## nothing pending: walk
	EXIT_HOOK,   ## at the end of a node: ask it to let us out
	AFTER_EXIT,  ## step onto the next node and work out its sub-path
	ENTER_HOOK,  ## ask the new node to let us in
	AFTER_ENTER, ## start its sub-path, or enter it outright if it has none
	SUB_POINT,   ## at a sub-path point: take the next edge, asking to cross it
}
var _step: Step = Step.NONE
## Sim-seconds left of a Waiting state.
var _wait_left: float = 0.0
## Where a ManualWalk is going, in world space.
var _walk_dest: Vector2 = Vector2.ZERO
## A module on the path went away or changed group: re-plan at the top of the
## next frame, before any step runs on the stale path. It was a call_deferred,
## which left the rest of the frame walking the old route into a module that was
## on its way out.
var _repath_pending: bool = false
## A walk restored from a save, not yet claimed by the job it belonged to - see
## [method can_adopt] and [method close_adoption].
var _awaiting_adoption: bool = false

var _pending_target: Node2D = null
var _pending_speed: float = 1.0
var _pending_end_in_space: bool = false
var _pending_anchor: AnchorDef = null

signal path_invalidated # Re-running pathfinding but not canceled yet
signal movement_ended(as_success: bool)
signal movement_started

func _ready() -> void:
	super()
	SignalBus.module_removed.connect(module_removed)
	SignalBus.module_group_changed.connect(module_group_changed)

func _notification(what: int) -> void:
	# A ride not yet boarded holds a queue spot and a place in a cab's pickups;
	# a pawn freed in the queue must hand both back, or the spot stays claimed by
	# a request nobody will ever serve. One already aboard stays on the cab's
	# list, which skips a freed pawn at unload.
	if what == NOTIFICATION_PREDELETE and ride != null and ride.is_pending():
		var request: RideRequest = ride
		ride = null
		request.abandon(false)

func _process(delta: float) -> void:
	if _repath_pending and not _is_carried():
		run_pathfinding()
	if owner_pawn.path_position_override != null:
		return  # a carrier owns our position right now (Conveyed) — just wait
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return  # sim paused — hold position, resume exactly where we were
	match state:
		State.Moving:
			if target == null or _pending_target != null:
				state = State.Idle
				return
			# Freed under us (an asteroid mined dry, a pile emptied). The path's
			# last point is dangling, so walking it would send the pawn to the
			# origin via extract_position's freed-node guard. Checked AFTER the
			# pending-target branch on purpose: a job that already retargeted us
			# must not get a stale movement_ended(false) for the old destination.
			if not is_instance_valid(target):
				movement_fail()
				return
			move(sim_delta)
		State.Waiting:
			_tick_wait(sim_delta)
		State.ManualWalk:
			_walk(sim_delta)
		State.Held:
			owner_pawn.set_idle()
		State.Conveyed:
			pass  # carrier drives position and animation; exit_conveyed resumes us
		State.Idle:
			if _pending_target != null:
				_start_pending()

func move_to(new_target: Node2D, new_speed: float = 1.0, in_space: bool = false, new_anchor: AnchorDef = null) -> void:
	if can_adopt(new_target, in_space, new_anchor):
		# The walk this pawn was on when the game was saved, asked for again by
		# the job it belonged to: carry on from exactly where it stands.
		_awaiting_adoption = false
		speed = new_speed
		return
	_awaiting_adoption = false
	_pending_target = new_target
	_pending_speed = new_speed
	_pending_end_in_space = in_space
	_pending_anchor = new_anchor
	# Retargeting on a ride: one not yet boarded is let go of here and the new
	# walk starts from the queue spot; one already boarding or aboard drops us at
	# its next stop (never between floors), and the pending walk starts there.
	_release_ride()

## A carrier takes ownership of the pawn's position (WI-20). Replaces the old
## pattern where the cab set path_position_override while this component sat
## suspended inside a path_enter/path_exit await.
func enter_conveyed(carrier: Node2D) -> void:
	owner_pawn.path_position_override = carrier
	conveyor = carrier
	state = State.Conveyed

## The carrier is done with us - normal arrival, a cancelled ride's next-stop
## drop, or the carrier being destroyed. Always leaves the pawn owning its own
## position again; the continuation is a fresh repath from wherever we were
## dropped, so a diverted drop-off self-corrects exactly like a normal one.
## Callers must set the pawn's current_module (and reparent it) first.
func exit_conveyed() -> void:
	if state != State.Conveyed:
		return
	owner_pawn.path_position_override = null
	conveyor = null
	if ride != null:
		ride.release_queue_anchor()
		ride = null
	state = State.Idle
	# A pending move_to (job changed mid-ride) wins over the old target; _process
	# starts it next frame from Idle. Otherwise resume the interrupted movement.
	if _pending_target == null and target != null:
		run_pathfinding()

# --- rides (WI-75 §5) -------------------------------------------------------------
#
# A turbolift's path_exit hands the pawn to a RideRequest and answers TAKEN_OVER.
# From there the ride drives these: a straight walk to a queue spot, a hold there
# until a cab comes, a straight walk into the cab, and Conveyed until the drop-off.

## The shaft took us at a turbolift door: walk to `queue_spot` and wait there.
func begin_ride(request: RideRequest, queue_spot: Vector2) -> void:
	ride = request
	_step = Step.NONE
	walk_to(queue_spot)

## A straight-line walk to `destination` (WI-16's queue and boarding legs). Ends
## Held, and tells the ride, if there is one, that we got there.
func walk_to(destination: Vector2) -> void:
	_walk_dest = destination
	state = State.ManualWalk

## Whether the pawn has finished the walk `request` asked for and is standing
## where it was sent - what a boarding cab watches for.
func is_holding_for(request: RideRequest) -> bool:
	return state == State.Held and ride == request

## The ride died before we were aboard - its floor was switched off, no cab could
## take it, or its cab was destroyed. The movement fails as a cancelled ride
## always has; the job re-plans from the floor the ride stood the pawn back on.
func ride_failed(request: RideRequest) -> void:
	if ride != request:
		return
	ride = null
	state = State.Idle
	cancel()

## A ride not yet boarded is let go of at once; one already boarding or aboard is
## called off, which drops the pawn at the cab's next stop.
func _release_ride() -> void:
	if ride == null:
		return
	if ride.is_committed():
		ride.call_off()
		return
	var request: RideRequest = ride
	ride = null
	request.abandon()
	state = State.Idle

## Something other than the path owns what happens next: a ride at any phase.
func _is_carried() -> bool:
	return ride != null or state == State.Conveyed

func _start_pending() -> void:
	if target != null:
		path_invalidated.emit()
	target = _pending_target
	speed = _pending_speed
	end_in_space = _pending_end_in_space
	target_anchor = _pending_anchor
	_pending_target = null
	_pending_anchor = null
	# Any stand-around claim from the last arrival is stale once we move again
	# (unless this movement is the walk TO that claim).
	owner_pawn.notify_movement_starting(target_anchor)
	run_pathfinding()

## What PawnStatus's roster sentence and RobotPowerComponent's moving drain ask.
## A pure read of the state since WI-75: the WI-71 latch that ORed in "suspended
## in a hook" is gone with the hooks' awaits.
func is_traveling() -> bool:
	return state != State.Idle

func movement_complete() -> void:
	target = null
	state = State.Idle
	_step = Step.NONE
	movement_ended.emit(true)

func movement_fail() -> void:
	target = null
	# A walk or a door wait simply stops. A ride keeps its state: one not yet
	# boarded has already been let go of by whoever called this, and one aboard
	# finishes at the next stop, where exit_conveyed finds no target to resume.
	if state == State.Moving or state == State.Waiting:
		state = State.Idle
		_step = Step.NONE
		_wait_left = 0.0
	movement_ended.emit(false)


func run_pathfinding() -> void:
	if _is_carried():
		# A carrier owns what happens next; the continuation repath happens in
		# exit_conveyed once it lets go.
		return
	_repath_pending = false
	path.clear()
	sub_path.clear()
	nodes_to_watch.clear()
	_step = Step.NONE
	_wait_left = 0.0

	if target == null:
		movement_fail()
		return

	var start_node: Node2D = owner_pawn.current_module
	if start_node != null:
		if start_node == target:
			if target_anchor == null or _standing_on_target_anchor():
				movement_complete()
				return
			# Already in the target module but heading to an interior anchor:
			# a single-node path whose partial sub-path is the anchor leg.
			var only_point: ModuleGraph.PathPoint = ModuleGraph.PathPoint.new()
			only_point.node = target
			path.append(only_point)
		else:
			path = Global.path_manager.run_pathfinding_by_node(start_node, target, end_in_space)
	else:
		path = Global.path_manager.run_pathfinding_by_node(owner_pawn, target, end_in_space)

	if path.is_empty():
		movement_fail()
	else:
		next_path_index = -1
		sub_path_index = -1
		in_sub_path = false
		for point in path:
			nodes_to_watch.append(point.node)
		nodes_to_watch.reverse()
		state = State.Moving
		movement_started.emit()

## Already on the anchor we are sent to. Without this a pawn that arrived in the
## very frame a save was written re-walked from the nearest path point back to
## the anchor it was standing on when the load resumed its job.
func _standing_on_target_anchor() -> bool:
	var module: ModuleBase = target as ModuleBase
	if module == null or module.get_path_component() == null:
		return false
	var spot: Vector2 = module.get_path_component().get_anchor_global_position(target_anchor)
	return owner_pawn.global_position.distance_squared_to(spot) < 0.25

func module_removed(removed_module: ModuleBase) -> void:
	if ride != null and ride.is_pending() \
			and (removed_module == ride.from_floor or removed_module == ride.to_floor):
		# A floor of a ride we have not boarded yet. Cabs only hear about rides
		# already on their lists, so one still walking to its queue spot learns
		# it here. Fails the movement, like any ride that dies before boarding.
		ride.fail()
		return
	if removed_module == target:
		# Target is gone, we can't ever get there. On a ride this fires
		# movement_ended now; a ride not yet boarded is let go of, and one aboard
		# still completes to its next stop, where exit_conveyed finds no target.
		cancel()
	elif not _is_carried() and nodes_to_watch.has(removed_module):
		# One of the modules on the path is gone - including the one we may be
		# waiting at a door of, which is how a wait on a dead module ends. A ride
		# skips this: the cab reroutes itself (recheck_requests) and we repath
		# from scratch at exit_conveyed anyway.
		path_invalidated.emit()
		_repath_pending = true

func module_group_changed(module: ModuleBase) -> void:
	if not _is_carried() and nodes_to_watch.has(module):
		# One of the modules on the path changed groups, recalc path
		path_invalidated.emit()
		_repath_pending = true

func cancel() -> void:
	path_invalidated.emit()
	_awaiting_adoption = false
	# A ride not yet boarded is let go of now; one aboard finishes to the next
	# stop. movement_ended still fires now either way - callers expect cancel to
	# be synchronous - and exit_conveyed will find no target to resume.
	_release_ride()
	movement_fail()

func get_debug_path_detailed() -> PackedVector2Array:
	var packed_path: PackedVector2Array = []
	for index: int in path.size():
		if path[index] and path[index].node:
			var base_pos := path[index].node.global_position
			var sub := get_sub_path(index)
			if sub.size() > 0:
				for data: PathComponent.PathTraversalEdgeData in sub:
					packed_path.append(base_pos + data.end_pos)
			else:
				packed_path.append(extract_position(index))
	return packed_path


func extract_position(index: int) -> Vector2:
	if index >= path.size() or index < 0:
		push_warning("trying to get the path position of an element not in the path_variant array!")
		return Vector2.ZERO
	if not is_instance_valid(path[index].node):
		push_warning("trying to get the path position of a freed node!")
		return Vector2.ZERO
	if path[index].node is ModuleBase:
		var module: ModuleBase = path[index].node as ModuleBase
		if path[index].in_space:
			return Global.cell_to_world(module.module_cell, true)
		if index > 0 and path[index - 1].node is ModuleBase:
			var prev_mod: ModuleBase = path[index - 1].node as ModuleBase
			return Vector2(module.get_path_component().get_connection_point_from(prev_mod)) + module.global_position
		if owner_pawn.current_module != null and owner_pawn.current_module == module:
			return owner_pawn.global_position
		if !module.get_path_component().door_connections.is_empty():
			return Vector2(module.get_path_component().get_closest_path_point(owner_pawn.global_position - module.global_position)) + module.global_position
		return Global.cell_to_world(module.module_cell, true)
	return path[index].node.global_position

## Whether a path node is a module with its own interior pathing. Path nodes are
## Node2D (space nodes and turbolift cabs are on the graph too), so the cast is the
## check - and it keeps the call below typed (WI-68 F7). Takes the node as Variant
## because it is read out of a stored path, where a freed one would error at a
## typed parameter (WI-71).
static func _has_custom_pathing(node: Variant) -> bool:
	if not is_instance_valid(node):
		return false
	var module: ModuleBase = node as ModuleBase
	return module != null and module.has_custom_pathing()

# --- arriving (WI-75 §2) ----------------------------------------------------------

## Runs the steps of arriving at a path point until one asks us to stand still or
## hands us to a carrier. True if the walk carries on this frame.
##
## This is the old reached_next_node / reached_next_subpath pair unrolled. Their
## recursion existed only because a hook could await; with hooks answering at
## once, each step is a case here and `_step` remembers where a wait stopped it.
func _advance_steps() -> bool:
	while _step != Step.NONE:
		if state != State.Moving or target == null:
			return false
		match _step:
			Step.EXIT_HOOK:
				_step = Step.AFTER_EXIT
				if next_path_index >= 0 and _has_custom_pathing(path[next_path_index].node):
					var door: int = 0
					if sub_path.size() > 0:
						door = sub_path[sub_path.size() - 1].end_index
					var leaving_module: ModuleBase = path[next_path_index].node as ModuleBase
					var next_module: Node2D = path[next_path_index + 1].node if path.size() > (next_path_index + 1) else null
					if not _apply_hook(leaving_module.path_exit(owner_pawn, door, path[next_path_index].edge_meta, next_module)):
						return false
			Step.AFTER_EXIT:
				next_path_index += 1
				if next_path_index == 0:
					sub_path = get_partial_sub_path(next_path_index)
				else:
					sub_path = get_sub_path(next_path_index)
				_step = Step.ENTER_HOOK
			Step.ENTER_HOOK:
				_step = Step.AFTER_ENTER
				if next_path_index > 0 and next_path_index < path.size() and _has_custom_pathing(path[next_path_index].node):
					var door: int = 0
					if sub_path.size() > 0:
						door = sub_path[0].end_index
					var entering_module: ModuleBase = path[next_path_index].node as ModuleBase
					var next_module: Node2D = path[next_path_index + 1].node if path.size() > (next_path_index + 1) else null
					if not _apply_hook(entering_module.path_enter(owner_pawn, door, path[next_path_index - 1].edge_meta, next_module)):
						return false
			Step.AFTER_ENTER:
				if sub_path.size() > 0:
					sub_path_index = -1
					_step = Step.SUB_POINT
				else:
					_step = Step.NONE
					_enter_node_without_sub_path()
			Step.SUB_POINT:
				sub_path_index += 1
				if sub_path_index == 0:
					_enter_node_on_sub_path()
				if sub_path_index >= sub_path.size():
					in_sub_path = false
					_step = Step.EXIT_HOOK
				else:
					in_sub_path = true
					_step = Step.NONE
					if _has_custom_pathing(path[next_path_index].node):
						var module: ModuleBase = path[next_path_index].node as ModuleBase
						if not _apply_hook(module.traverse(owner_pawn, sub_path[sub_path_index])):
							return false
	return state == State.Moving and target != null

## Acts on a hook's verdict. `_step` already names the step after the hook, so a
## wait resumes there.
func _apply_hook(result: PathHookResult) -> bool:
	match result.kind:
		PathHookResult.Kind.WAIT:
			state = State.Waiting
			_wait_left = result.seconds
			owner_pawn.set_idle()
			return false
		PathHookResult.Kind.TAKEN_OVER:
			# The carrier has already put us in its first state (a ride's queue
			# walk). The path is finished with until it hands us back.
			_step = Step.NONE
			return false
		PathHookResult.Kind.FAIL:
			cancel()
			return false
	return state == State.Moving and target != null

## "Enter" a node whose sub-path is empty, the moment we step onto it.
func _enter_node_without_sub_path() -> void:
	if next_path_index > -1 and next_path_index < path.size():
		if path[next_path_index].node is ModuleBase and not path[next_path_index].in_space:
			var this_module: ModuleBase = path[next_path_index].node as ModuleBase
			var prev_module: ModuleBase = null
			if next_path_index > 0 and path[next_path_index - 1].node is ModuleBase:
				prev_module = path[next_path_index - 1].node as ModuleBase
			this_module.enter_module_from(owner_pawn, prev_module)
		elif path[next_path_index].node is TurboliftCab:
			# Don't dump people into space when they're riding the turbolift
			pass
		else:
			owner_pawn.current_module = null
		if next_path_index > 1:
			nodes_to_watch.pop_back()

## Enter a node at the first point of its sub-path.
func _enter_node_on_sub_path() -> void:
	if next_path_index > -1 and next_path_index < path.size():
		if path[next_path_index].node is ModuleBase and not path[next_path_index].in_space:
			var this_module: ModuleBase = path[next_path_index].node as ModuleBase
			var prev_module: ModuleBase = null
			if next_path_index > 0 and path[next_path_index - 1].node is ModuleBase:
				prev_module = path[next_path_index - 1].node as ModuleBase
			this_module.enter_module_from(owner_pawn, prev_module)
		else:
			owner_pawn.current_module = null
		if next_path_index > 1:
			nodes_to_watch.pop_back()

## A hook's wait, in sim time. A long frame at 4x ends the wait rather than
## carrying its leftover into the next step, so a door can never be skipped.
func _tick_wait(sim_delta: float) -> void:
	if target == null or _pending_target != null:
		state = State.Idle
		return
	if not is_instance_valid(target):
		movement_fail()
		return
	owner_pawn.set_idle()
	_wait_left -= sim_delta
	if _wait_left > 0.0:
		return
	_wait_left = 0.0
	state = State.Moving
	if _advance_steps() and next_path_index >= path.size():
		movement_complete()

## A ManualWalk step - the old walk_straight_to's loop body, at the same speed.
func _walk(sim_delta: float) -> void:
	owner_pawn.move_to(owner_pawn.global_position.move_toward(_walk_dest,
		owner_pawn.speed * owner_pawn.speed_jitter * sim_delta))
	if owner_pawn.global_position.distance_squared_to(_walk_dest) >= 0.25:
		return
	owner_pawn.set_idle()
	if ride == null:
		state = State.Idle
		return
	state = State.Held
	ride.on_walk_finished()

# --- walking ----------------------------------------------------------------------

## Terrain speed of the module whose interior sub-path we're currently on.
func _sub_path_speed_mult() -> float:
	if next_path_index >= 0 and next_path_index < path.size() and path[next_path_index].node is ModuleBase:
		var module: ModuleBase = path[next_path_index].node as ModuleBase
		var pc: PathComponent = module.get_path_component()
		if pc != null:
			return pc.get_traversal_speed_mult()
	return 1.0

func get_sub_path(index: int) -> Array[PathComponent.PathTraversalEdgeData]:
	if index > 0 and index < path.size():
		if !path[index].in_space and path[index].node is ModuleBase:
			var current_module: ModuleBase = path[index].node as ModuleBase
			if current_module.get_path_component() != null:
				if index + 1 < path.size():
					return current_module.get_path_component().get_path_through_module(path[index - 1].node, path[index + 1].node)
				# Final module with an anchor (WI-16): interior path from the
				# entry door to the anchor instead of stopping at the door.
				if target_anchor != null and current_module == target:
					return current_module.get_path_component().get_path_to_anchor(path[index - 1].node, target_anchor)
	return []

func get_partial_sub_path(index: int) -> Array[PathComponent.PathTraversalEdgeData]:
	if index >= 0 and index < path.size():
		if !path[index].in_space and path[index].node is ModuleBase:
			var current_module: ModuleBase = path[index].node as ModuleBase
			if current_module.get_path_component() != null:
				if index + 1 < path.size():
					return current_module.get_path_component().get_path_exiting_module(owner_pawn.global_position, path[index + 1].node)
				# Already inside the target module, walking to its anchor.
				if target_anchor != null and current_module == target:
					return current_module.get_path_component().get_path_to_anchor_from_position(owner_pawn.global_position, target_anchor)
	return []

func move(delta: float) -> void:
	if next_path_index < 0:
		_step = Step.EXIT_HOOK
		if not _advance_steps():
			return
	# move_speed_scale is 1.0 for everyone except a robot crawling on backup
	# power at zero energy (WI-28), which travels at a fraction of its speed.
	var dist_to_travel: float = owner_pawn.speed * owner_pawn.speed_jitter * delta * speed * owner_pawn.move_speed_scale
	var next_position: Vector2 = owner_pawn.global_position
	while dist_to_travel > 0:
		if in_sub_path:
			# Interior movement runs at the module's terrain speed (WI-11):
			# a segment of length d consumes d / mult of the travel budget.
			var seg_mult: float = _sub_path_speed_mult()
			var next_path_position: Vector2 = path[next_path_index].node.global_position + sub_path[sub_path_index].end_pos
			var travel_vector: Vector2 = next_path_position - next_position
			var dist_to_next_point: float = travel_vector.length()
			if dist_to_next_point / seg_mult <= dist_to_travel + 0.0001:
				next_position = next_path_position
				dist_to_travel -= dist_to_next_point / seg_mult
				# Snap, THEN step: hooks expect the pawn at the point, and if
				# this was the path's last point a wait or a hand-over leaves the
				# pawn exactly here - without the snap it would stand a frame
				# short of its anchor (WI-16). It was "snap before the await".
				owner_pawn.move_to(next_position, sub_path[sub_path_index].use_exact_position)
				_step = Step.SUB_POINT
				if not _advance_steps():
					return
				next_position = owner_pawn.global_position
			else:
				next_position = next_position + travel_vector / dist_to_next_point * (dist_to_travel * seg_mult)
				dist_to_travel = 0
				break
		else:
			if next_path_index >= path.size():
				break
			var next_path_position: Vector2 = extract_position(next_path_index)
			var travel_vector: Vector2 = next_path_position - next_position
			var dist_to_next_point: float = travel_vector.length()
			if dist_to_next_point <= dist_to_travel + 0.0001:
				next_position = next_path_position
				dist_to_travel -= dist_to_next_point
				# Same snap-then-step as the sub-path branch above.
				owner_pawn.move_to(next_position)
				_step = Step.EXIT_HOOK
				if not _advance_steps():
					return
				next_position = owner_pawn.global_position
			else:
				next_position = next_position + travel_vector / dist_to_next_point * dist_to_travel
				dist_to_travel = 0
				break
	owner_pawn.move_to(next_position)
	if next_path_index >= path.size():
		# Made it to the last position
		movement_complete()

# --- a restored walk and the job it belongs to (WI-75) ----------------------------
#
# A load puts the walk back exactly as it was saved - path, place on it, a door
# wait half run down, a ride at whatever phase. The job that started it is
# restored separately and resumes on the pawn's first job pick, asking for its
# walk again through Job.begin_movement. That request *adopts* the restored walk
# rather than re-pathing from wherever the pawn stands, which is what makes a
# reload invisible. Anything the first pick did not claim belonged to a job that
# is gone (an unsaved idle wander, one that no longer validates), and is dropped.

## Whether a restored walk is still unclaimed and heading exactly there.
func can_adopt(node: Node2D, in_space: bool, anchor: AnchorDef) -> bool:
	return _awaiting_adoption and node != null and node == target \
		and in_space == end_in_space and anchor == target_anchor

## The anchor a restored, unclaimed walk is heading to in `module`, so the job's
## resume can re-claim that one rather than whichever is first free.
func restored_anchor(module: ModuleBase) -> AnchorDef:
	if _awaiting_adoption and module != null and target == module:
		return target_anchor
	return null

## The pawn's first job pick after a load has finished: an unclaimed restored walk
## belonged to a job that is not coming back.
func close_adoption() -> void:
	if _awaiting_adoption:
		cancel()

# --- persistence ------------------------------------------------------------------
#
# Not a component block: the movement component is created in PawnBase._ready and
# is not in `components`, and it has to restore after EVERY pawn is back (a walk
# can target another pawn, and a ride names the pawns ahead of it in the cab's
# lists). SaveManager's pawn section writes this as the entry's "movement" and
# reads it back in a second pass once the whole section has loaded.

func get_save_data() -> Dictionary:
	if state == State.Idle:
		return {}
	var out: Dictionary = {"state": int(state)}
	var target_ref: Dictionary = SaveRefs.node_ref(target)
	if not target_ref.is_empty():
		out["target"] = target_ref
	out["speed"] = speed
	if end_in_space:
		out["in_space"] = true
	var target_module: ModuleBase = target as ModuleBase
	if target_anchor != null and target_module != null and target_module.get_path_component() != null:
		out["anchor"] = target_module.get_path_component().anchor_ref(target_anchor)
	var points: Array = []
	for point: ModuleGraph.PathPoint in path:
		points.append({"node": SaveRefs.node_ref(point.node), "space": point.in_space, "meta": point.edge_meta})
	if not points.is_empty():
		out["path"] = points
	out["index"] = next_path_index
	var edges: Array = []
	for edge: PathComponent.PathTraversalEdgeData in sub_path:
		edges.append({
			"from": [edge.start_pos.x, edge.start_pos.y], "to": [edge.end_pos.x, edge.end_pos.y],
			"i": edge.start_index, "j": edge.end_index, "meta": String(edge.edge_meta),
			"exact": edge.use_exact_position,
		})
	if not edges.is_empty():
		out["sub"] = edges
	out["sub_index"] = sub_path_index
	if in_sub_path:
		out["in_sub"] = true
	out["watch"] = nodes_to_watch.size()
	if _step != Step.NONE:
		out["step"] = int(_step)
	if state == State.Waiting:
		out["wait"] = _wait_left
	if state == State.ManualWalk:
		out["walk"] = [_walk_dest.x, _walk_dest.y]
	if ride != null:
		out["ride"] = ride.to_dict()
	if _repath_pending:
		out["repath"] = true
	return out

## Restores what get_save_data wrote. Every pawn, module, cab and pile is back by
## now. Anything that no longer resolves degrades to what a load did before
## WI-75: the pawn stands where it was saved and its job re-paths.
func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	var saved_state: State = int(data.get("state", State.Idle)) as State
	if saved_state == State.Idle:
		return
	target = SaveRefs.resolve_node_ref(data.get("target", {}))
	speed = float(data.get("speed", 1.0))
	end_in_space = bool(data.get("in_space", false))
	target_anchor = null
	var target_module: ModuleBase = target as ModuleBase
	if data.has("anchor") and target_module != null and target_module.get_path_component() != null:
		target_anchor = target_module.get_path_component().resolve_anchor_ref(data["anchor"])
	var path_whole: bool = true
	path.clear()
	for entry: Dictionary in data.get("path", []):
		var point := ModuleGraph.PathPoint.new()
		point.node = SaveRefs.resolve_node_ref(entry.get("node", {}))
		point.in_space = bool(entry.get("space", false))
		point.edge_meta = String(entry.get("meta", ""))
		if point.node == null:
			path_whole = false
		path.append(point)
	next_path_index = int(data.get("index", -1))
	sub_path.clear()
	for entry: Dictionary in data.get("sub", []):
		var edge := PathComponent.PathTraversalEdgeData.new()
		var from: Array = entry.get("from", [0, 0])
		var to: Array = entry.get("to", [0, 0])
		edge.start_pos = Vector2(float(from[0]), float(from[1]))
		edge.end_pos = Vector2(float(to[0]), float(to[1]))
		edge.start_index = int(entry.get("i", -1))
		edge.end_index = int(entry.get("j", -1))
		edge.edge_meta = StringName(String(entry.get("meta", "")))
		edge.use_exact_position = bool(entry.get("exact", false))
		sub_path.append(edge)
	sub_path_index = int(data.get("sub_index", -1))
	in_sub_path = bool(data.get("in_sub", false))
	# The watch list is the path's nodes, last first, with the ones already
	# walked past popped off the end - so its length is all a save needs.
	nodes_to_watch.clear()
	var watched: int = int(data.get("watch", 0))
	for index: int in range(path.size() - 1, -1, -1):
		if nodes_to_watch.size() >= watched:
			break
		nodes_to_watch.append(path[index].node)
	_step = int(data.get("step", Step.NONE)) as Step
	_wait_left = float(data.get("wait", 0.0))
	var walk: Array = data.get("walk", [])
	if walk.size() == 2:
		_walk_dest = Vector2(float(walk[0]), float(walk[1]))
	_repath_pending = bool(data.get("repath", false))

	if data.has("ride"):
		ride = RideRequest.restore(data["ride"], owner_pawn)
		if ride == null:
			_stand_down_from_lost_ride()
			return
		if saved_state == State.Conveyed:
			enter_conveyed(ride.cab)
		else:
			state = saved_state
	elif saved_state == State.Conveyed or saved_state == State.Held or saved_state == State.ManualWalk:
		# Carried with no ride to carry us: nothing can hand us back.
		_stand_down_from_lost_ride()
		return
	else:
		state = saved_state
		if not path_whole:
			# A node on the saved path did not come back. Keep the destination
			# for the job to adopt, and re-plan on the first frame.
			_repath_pending = true
	_awaiting_adoption = target != null

## A saved ride that cannot be put back (its cab or floor is gone): the pawn stands
## on the floor it boarded at, which is what every save did with a ride before
## WI-75, and its job re-paths from there.
func _stand_down_from_lost_ride() -> void:
	ride = null
	state = State.Idle
	_step = Step.NONE
	var floor_module: ModuleBase = owner_pawn.current_module
	if floor_module != null:
		owner_pawn.reparent(Global.world_manager.get_canvas_for_layer(owner_pawn.current_layer))
		owner_pawn.global_position = floor_module.get_global_center()
