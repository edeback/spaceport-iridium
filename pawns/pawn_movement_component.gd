class_name PawnMovementComponent
extends PawnComponentBase

var target: Node2D
var speed: float = 1.0
var end_in_space: bool = false

var next_path_index: int = 0
var path: Array[ModuleGraph.PathPoint] = []
var nodes_to_watch: Array[Node2D] = []

var in_sub_path: bool = false
var sub_path: Array[PathComponent.PathTraversalEdgeData] 
var sub_path_index: int = 0

enum State { Idle, Moving, Paused }
var state: State = State.Idle

var _pending_target: Node2D = null
var _pending_speed: float = 1.0
var _pending_end_in_space: bool = false
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
		return  # a cab (or similar) owns our position right now — just wait
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return  # sim paused — hold position, resume exactly where we were
	match state:
		State.Moving:
			if target == null or _pending_target != null:
				state = State.Idle
				return
			state = State.Paused
			await move(sim_delta)
			if state == State.Paused:
				state = State.Moving
		State.Paused:
			owner_pawn.set_idle()
		State.Idle:
			if _pending_target != null:
				_start_pending()
				
func move_to(new_target: Node2D, new_speed: float = 1.0, in_space: bool = false) -> void:
	_pending_target = new_target
	_pending_speed = new_speed
	_pending_end_in_space = in_space

func _start_pending() -> void:
	if target != null:
		path_invalidated.emit()
	target = _pending_target
	speed = _pending_speed
	end_in_space = _pending_end_in_space
	_pending_target = null
	run_pathfinding()

func is_traveling() -> bool:
	return state == State.Moving or state == State.Paused or _busy_in_hook

func movement_complete() -> void:
	target = null
	state = State.Idle
	movement_ended.emit(true)
	
func movement_fail() -> void:
	target = null
	movement_ended.emit(false)

	
func run_pathfinding() -> void:
	path.clear()
	sub_path.clear()
	nodes_to_watch.clear()
	
	if target == null:
		movement_fail()
		return
	
	var start_node: Node2D = owner_pawn.path_position_override
	if start_node == null:
		start_node = owner_pawn.current_module
	if start_node != null:
		if start_node == target:
			movement_complete()
			return
		path = Global.path_manager.run_pathfinding_by_node(start_node, target, end_in_space)
	else:
		path = Global.path_manager.run_pathfinding_by_node(owner_pawn, target, end_in_space)

	if path.is_empty():
		movement_fail()
	else:
		if path.size() > 1 and path[0].node is TurboliftCab and path[1].node is ModuleTurbolift:
			var request: RideRequest = path[0].node.get_onboard_request_for(owner_pawn)
			if request:
				request.to_floor = path[1].node
		next_path_index = -1
		sub_path_index = -1
		in_sub_path = false
		for point in path:
			nodes_to_watch.append(point.node)
		nodes_to_watch.reverse()
		state = State.Moving
		movement_started.emit()
		# Debug shove path in UI
		#var packed_path: PackedVector2Array = []
		#for index in path.size():
			#packed_path.append(Global.world_to_cell(extract_position(index)))
		#Global.ui_in_game.debug_path_cell = packed_path
		#Global.ui_in_game.debug_path_position = get_debug_path_detailed()
	
		
func module_removed(removed_module: ModuleBase) -> void:
	if removed_module == target:
		# Target is gone, we can't ever get there
		movement_fail()
		path_invalidated.emit()
	elif nodes_to_watch.has(removed_module):
		# One of the modules on the path is gone, recalc path
		path_invalidated.emit()
		call_deferred("run_pathfinding")
		
func module_group_changed(module: ModuleBase) -> void:
	if nodes_to_watch.has(module):
		# One of the modules on the path changed groups, recalc path
		path_invalidated.emit()
		call_deferred("run_pathfinding")
		
func cancel() -> void:
	path_invalidated.emit()
	movement_fail()
		
func get_debug_path_detailed() -> PackedVector2Array:
	var packed_path: PackedVector2Array = []
	for index: int in path.size():
		if path[index] and path[index].node:
			var base_pos := path[index].node.global_position
			var sub := get_sub_path(index)
			if sub.size() > 0:
				#packed_path.append(base_pos + sub[0].start_pos)
				for data: PathComponent.PathTraversalEdgeData in sub:
					packed_path.append(base_pos + data.end_pos)
			else:
				packed_path.append(extract_position(index))
			#if path[index] is ModuleBase:
				#var mod := path[index] as ModuleBase
				#packed_path.append(mod.get_global_center())
			#else:
				#packed_path.append(base_pos)
	return packed_path
	
		
func extract_position(index: int) -> Vector2:
	if index >= path.size() or index < 0:
		print("trying to get the path position of an element not in the path_variant array!")
		return Vector2.ZERO
	if not is_instance_valid(path[index].node):
		print("trying to get the path position of a freed node!")
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
	
func reached_next_node() -> void:
	if next_path_index >= 0 and path[next_path_index].node is ModuleBase and path[next_path_index].node.has_custom_pathing():
		var door: int = 0
		if sub_path.size() > 0:
			door = sub_path[sub_path.size() - 1].end_index
		var leaving_module: ModuleBase = path[next_path_index].node as ModuleBase
		var next_module: Node2D = path[next_path_index + 1].node if path.size() > (next_path_index + 1) else null
		_busy_in_hook = true
		await leaving_module.path_exit(owner_pawn, door, path[next_path_index].edge_meta, next_module, path_invalidated)
		_busy_in_hook = false
		if target == null:
			return
		
	next_path_index += 1

	if next_path_index == 0:
		sub_path = get_partial_sub_path(next_path_index)
	else:
		sub_path = get_sub_path(next_path_index)
		
	if next_path_index > 0 and next_path_index < path.size() and path[next_path_index].node is ModuleBase and path[next_path_index].node.has_custom_pathing():
		var door: int = 0
		if sub_path.size() > 0:
			door = sub_path[0].end_index
		var entering_module: ModuleBase = path[next_path_index].node as ModuleBase
		var next_module: Node2D = path[next_path_index + 1].node if path.size() > (next_path_index + 1) else null
		_busy_in_hook = true
		await entering_module.path_enter(owner_pawn, door, path[next_path_index - 1].edge_meta, next_module, path_invalidated)
		_busy_in_hook = false
		if target == null:
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
	if index > 0 and index + 1 < path.size():
		if !path[index].in_space and path[index].node is ModuleBase:
			var current_module: ModuleBase = path[index].node as ModuleBase
			if current_module.get_path_component() != null:
				return current_module.get_path_component().get_path_through_module(path[index - 1].node, path[index + 1].node)
	return []
	
func get_partial_sub_path(index: int) -> Array[PathComponent.PathTraversalEdgeData]:
	if index >= 0 and index + 1 < path.size():
		if !path[index].in_space and path[index].node is ModuleBase:
			var current_module: ModuleBase = path[index].node as ModuleBase
			if current_module.get_path_component() != null:
				return current_module.get_path_component().get_path_exiting_module(owner_pawn.global_position, path[index + 1].node)
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
		if target == null:
			return
	var dist_to_travel: float = owner_pawn.speed * delta * speed
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
				await reached_next_subpath()
				if target == null:
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
				await reached_next_node()
				if target == null:
					return
				next_position = owner_pawn.global_position
			else:
				next_position = next_position + travel_vector / dist_to_next_point * dist_to_travel
				dist_to_travel = 0
				break
	#if next_position == pawn.global_position:
		# We didn't move, we're done here
		#print ("tried to move but failed? Marking as finished but investigate")
		#action_state = PathActionState.Finished
	owner_pawn.move_to(next_position)
	if next_path_index >= path.size():
		# Made it to the last position
		movement_complete()
