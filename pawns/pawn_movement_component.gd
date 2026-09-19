class_name PawnMovementComponent
extends PawnComponentBase

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

## Conveyed (WI-20): a carrier (turbolift cab today; trams/teleporters later)
## owns the pawn's position. The component does nothing per-frame, repaths are
## deferred until the carrier lets go, and nothing awaits the ride - so
## cancelling a job mid-ride can never strand a suspended coroutine.
enum State { Idle, Moving, Paused, Conveyed }
var state: State = State.Idle
## The Node2D driving our position while Conveyed; null otherwise.
var conveyor: Node2D = null

var _pending_target: Node2D = null
var _pending_speed: float = 1.0
var _pending_end_in_space: bool = false
var _pending_anchor: AnchorDef = null
var _busy_in_hook: bool = false   ## suspended inside path_exit/path_enter/traverse right now

signal path_invalidated # Re-running pathfinding but not canceled yet
signal movement_ended(as_success: bool)
signal movement_started

func _ready() -> void:
	super()
	SignalBus.module_removed.connect(module_removed)
	SignalBus.module_group_changed.connect(module_group_changed)

func _process(delta: float) -> void:
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
			state = State.Paused
			await move(sim_delta)
			if state == State.Paused:
				state = State.Moving
		State.Paused:
			# A hook-driven manual walk (turbolift queue/boarding) owns the
			# animation right now - don't stomp it back to idle.
			if not owner_pawn.in_manual_walk:
				owner_pawn.set_idle()
		State.Conveyed:
			pass  # carrier drives position and animation; exit_conveyed resumes us
		State.Idle:
			if _pending_target != null:
				_start_pending()

func move_to(new_target: Node2D, new_speed: float = 1.0, in_space: bool = false, new_anchor: AnchorDef = null) -> void:
	_pending_target = new_target
	_pending_speed = new_speed
	_pending_end_in_space = in_space
	_pending_anchor = new_anchor
	if state == State.Conveyed:
		# Retargeting mid-ride: flag the ride so the carrier releases us at its
		# next floor stop (never between floors); the pending movement then
		# starts from wherever we were dropped (see exit_conveyed).
		_cancel_conveyor_ride()

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
	state = State.Idle
	# A pending move_to (job changed mid-ride) wins over the old target; _process
	# starts it next frame from Idle. Otherwise resume the interrupted movement.
	if _pending_target == null and target != null:
		run_pathfinding()

## Cancels/retargets can't take effect immediately while Conveyed - carriers
## never dump a pawn between floors. Flag the ride; the carrier drops us at its
## next stop and exit_conveyed handles the rest.
func _cancel_conveyor_ride() -> void:
	var cab: TurboliftCab = conveyor as TurboliftCab
	if cab != null:
		var request: RideRequest = cab.get_onboard_request_for(owner_pawn)
		if request != null:
			cab.cancel_request(request)

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

func is_traveling() -> bool:
	return state == State.Moving or state == State.Paused or state == State.Conveyed or _busy_in_hook

func movement_complete() -> void:
	target = null
	state = State.Idle
	movement_ended.emit(true)
	
func movement_fail() -> void:
	target = null
	movement_ended.emit(false)

	
func run_pathfinding() -> void:
	if state == State.Conveyed:
		# A carrier owns our position; the continuation repath happens in
		# exit_conveyed once the carrier lets go.
		return
	path.clear()
	sub_path.clear()
	nodes_to_watch.clear()

	if target == null:
		movement_fail()
		return

	var start_node: Node2D = owner_pawn.current_module
	if start_node != null:
		if start_node == target:
			if target_anchor == null:
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
	
		
func module_removed(removed_module: ModuleBase) -> void:
	if removed_module == target:
		# Target is gone, we can't ever get there. While Conveyed this fires
		# movement_ended now; the ride still completes to its next stop and
		# exit_conveyed finds no target left to resume.
		movement_fail()
		path_invalidated.emit()
	elif state != State.Conveyed and nodes_to_watch.has(removed_module):
		# One of the modules on the path is gone, recalc path. Conveyed skips
		# this: the carrier reroutes itself (recheck_requests) and we repath
		# from scratch at exit_conveyed anyway.
		path_invalidated.emit()
		call_deferred("run_pathfinding")

func module_group_changed(module: ModuleBase) -> void:
	if state != State.Conveyed and nodes_to_watch.has(module):
		# One of the modules on the path changed groups, recalc path
		path_invalidated.emit()
		call_deferred("run_pathfinding")

func cancel() -> void:
	path_invalidated.emit()
	if state == State.Conveyed:
		# The ride finishes to the next floor stop; movement_ended still fires
		# now (callers expect cancel to be synchronous) and exit_conveyed will
		# find no target to resume.
		_cancel_conveyor_ride()
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
## check - and it keeps the call below typed (WI-68 F7).
static func _has_custom_pathing(node: Node2D) -> bool:
	var module: ModuleBase = node as ModuleBase
	return module != null and module.has_custom_pathing()

func reached_next_node() -> void:
	if next_path_index >= 0 and _has_custom_pathing(path[next_path_index].node):
		var door: int = 0
		if sub_path.size() > 0:
			door = sub_path[sub_path.size() - 1].end_index
		var leaving_module: ModuleBase = path[next_path_index].node as ModuleBase
		var next_module: Node2D = path[next_path_index + 1].node if path.size() > (next_path_index + 1) else null
		_busy_in_hook = true
		await leaving_module.path_exit(owner_pawn, door, path[next_path_index].edge_meta, next_module, path_invalidated)
		_busy_in_hook = false
		# Conveyed: the hook boarded us onto a carrier - the whole call chain
		# unwinds here and exit_conveyed resumes the movement later (WI-20).
		if target == null or state == State.Conveyed:
			return
		
	next_path_index += 1

	if next_path_index == 0:
		sub_path = get_partial_sub_path(next_path_index)
	else:
		sub_path = get_sub_path(next_path_index)
		
	if next_path_index > 0 and next_path_index < path.size() and _has_custom_pathing(path[next_path_index].node):
		var door: int = 0
		if sub_path.size() > 0:
			door = sub_path[0].end_index
		var entering_module: ModuleBase = path[next_path_index].node as ModuleBase
		var next_module: Node2D = path[next_path_index + 1].node if path.size() > (next_path_index + 1) else null
		_busy_in_hook = true
		await entering_module.path_enter(owner_pawn, door, path[next_path_index - 1].edge_meta, next_module, path_invalidated)
		_busy_in_hook = false
		if target == null or state == State.Conveyed:
			return
		
	if sub_path.size() > 0:
		sub_path_index = -1
		await reached_next_subpath()
		in_sub_path = true
	else:
		# If we don't have a subpath, "enter" this node now
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
	
func reached_next_subpath() -> void:
	sub_path_index += 1
	if sub_path_index == 0:
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
	if sub_path_index >= sub_path.size():
		in_sub_path = false
		await reached_next_node()
		return
	var module: ModuleBase = path[next_path_index].node as ModuleBase
	if module != null and module.has_custom_pathing():
		await module.traverse(owner_pawn, sub_path[sub_path_index])
	
func move(delta: float) -> void:
	if next_path_index < 0:
		await reached_next_node()
		if target == null or state == State.Conveyed:
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
				# Snap BEFORE the await: hooks expect the pawn at the point,
				# and if this was the path's last point the post-await reset
				# to global_position would otherwise discard the snap and
				# strand the pawn a frame short of its anchor (WI-16).
				owner_pawn.move_to(next_position, sub_path[sub_path_index].use_exact_position)
				await reached_next_subpath()
				if target == null or state == State.Conveyed:
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
				# Same pre-await snap as the sub-path branch above.
				owner_pawn.move_to(next_position)
				await reached_next_node()
				if target == null or state == State.Conveyed:
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
