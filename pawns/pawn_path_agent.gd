class_name PawnPathAgent
extends PawnComponentBase

var pawn: PawnBase
var target: Node2D
var speed: float = 1.0
var end_in_space: bool = false
#var path: PackedVector2Array
var next_path_index: int = 0
var path: Array[ModuleGraph.PathPoint] = []
var nodes_to_watch: Array[Node2D] = []

var airlock_data: ModuleData = preload("res://data/modules/module_airlock.tres") as ModuleData

var in_sub_path: bool = false
var sub_path: Array[PathComponent.PathTraversalEdgeData] 
var sub_path_index: int = 0

enum PathActionState { Starting, Moving, Finished, Failed }

var action_state: PathActionState = PathActionState.Starting



func _ready() -> void:
	SignalBus.module_removed.connect(module_removed)

func initialize_action(_pawn: PawnBase, _target: Node2D, _speed: float = 1.0, _end_in_space: bool = false) -> void:
	pawn = _pawn
	target = _target
	speed = _speed
	end_in_space = _end_in_space
	run_pathfinding()
	
func run_pathfinding() -> void:
	path.clear()
	sub_path.clear()
	nodes_to_watch.clear()
	if pawn.current_module != null:
		if pawn.current_module == target:
			action_state = PathActionState.Finished
			return
		path = Global.path_manager.run_pathfinding_by_node(pawn.current_module, target, end_in_space)
		sub_path = get_partial_sub_path(0)
		if sub_path.size() > 0:
			sub_path_index = 0
			in_sub_path = true
	else:
		path = Global.path_manager.run_pathfinding_by_node(pawn, target, end_in_space)

	if path.is_empty():
		action_state = PathActionState.Failed
	else:
		next_path_index = 0
		nodes_to_watch.append_array(path)
		nodes_to_watch.reverse()
		action_state = PathActionState.Moving
		# Debug shove path in UI
		#var packed_path: PackedVector2Array = []
		#for index in path.size():
			#packed_path.append(Global.world_to_cell(extract_position(index)))
		#Global.ui_in_game.debug_path_cell = packed_path
		Global.ui_in_game.debug_path_position = get_debug_path_detailed()



func process_action(delta: float) -> void:
	match action_state:
		PathActionState.Starting:
			pass
		PathActionState.Moving:
			move(delta)
		PathActionState.Finished:
			pass
		PathActionState.Failed:
			pass
		
func module_removed(removed_module: ModuleBase) -> void:
	if removed_module == target:
		# Target is gone, we can't ever get there
		action_state = PathActionState.Failed
	elif nodes_to_watch.has(removed_module):
		# One of the modules on the path is gone, recalc path
		run_pathfinding()
		
func get_debug_path_detailed() -> PackedVector2Array:
	var packed_path: PackedVector2Array = []
	for index: int in path.size():
		var base_pos := path[index].node.global_position
		var sub := get_sub_path(index)
		if sub.size() > 0:
			packed_path.append(base_pos + sub[0].start_pos)
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
	if path[index].node is ModuleBase:
		var module: ModuleBase = path[index].node as ModuleBase
		if path[index].in_space:
			return Global.cell_to_world(module.module_cell, true)
		if index > 0 and path[index - 1].node is ModuleBase:
			var prev_mod: ModuleBase = path[index - 1].node as ModuleBase
			return Vector2(module.get_path_component().get_connection_point_from(prev_mod)) + module.global_position
		if pawn.current_module != null and pawn.current_module == module:
			return pawn.global_position
		if !module.get_path_component().door_connections.is_empty():
			return Vector2(module.get_path_component().get_closest_path_point(pawn.global_position - module.global_position)) + module.global_position
		return Global.cell_to_world(module.module_cell, true)
	return path[index].node.global_position
	
func reached_next_node() -> void:
	if path[next_path_index].node is ModuleBase and not path[next_path_index].in_space:
		var this_module: ModuleBase = path[next_path_index].node as ModuleBase
		var prev_module: ModuleBase = null
		if next_path_index > 0 and path[next_path_index - 1].node is ModuleBase:
			prev_module = path[next_path_index - 1].node as ModuleBase
		this_module.enter_module_from(pawn, prev_module)
	else:
		pawn.current_module = null
	nodes_to_watch.pop_back()
	next_path_index += 1
	sub_path = get_sub_path(next_path_index)
	if sub_path.size() > 0:
		sub_path_index = -1
		await reached_next_subpath()
		in_sub_path = true
	
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
				return current_module.get_path_component().get_path_exiting_module(pawn.global_position, path[index + 1].node)
	return []
	
func reached_next_subpath() -> void:
	sub_path_index += 1
	if sub_path_index >= sub_path.size():
		in_sub_path = false
		await reached_next_node()
		return
	var module: ModuleBase = path[next_path_index].node as ModuleBase
	if module != null and module.has_custom_pathing():
		await module.traverse(pawn, sub_path[sub_path_index])
	
func move(delta: float) -> void:
	var dist_to_travel: float = pawn.speed * delta * speed
	var next_position: Vector2 = pawn.global_position
	while dist_to_travel > 0:
		if in_sub_path:
			var next_path_position: Vector2 = path[next_path_index].node.global_position + sub_path[sub_path_index].end_pos
			var travel_vector: Vector2 = next_path_position - next_position
			var dist_to_next_point: float = travel_vector.length()
			if dist_to_next_point <= dist_to_travel + 0.0001:
				next_position = next_path_position
				dist_to_travel -= dist_to_next_point
				await reached_next_subpath()
			else:
				next_position = next_position + travel_vector / dist_to_next_point * dist_to_travel
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
			else:
				next_position = next_position + travel_vector / dist_to_next_point * dist_to_travel
				dist_to_travel = 0
				break
	if next_position == pawn.global_position:
		# We didn't move, we're done here
		#print ("tried to move but failed? Marking as finished but investigate")
		action_state = PathActionState.Finished
	if next_path_index >= path.size():
		# Made it to the last position
		action_state = PathActionState.Finished
	pawn.move_to(next_position)

func is_failed() -> bool:
	return action_state == PathActionState.Failed
	
func is_finished() -> bool:
	return action_state == PathActionState.Finished
