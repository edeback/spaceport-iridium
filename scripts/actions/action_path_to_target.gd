class_name Action_PathToTarget
extends Node

var pawn: PawnBase
var target: Node2D
var target_is_module: bool = true
#var path: PackedVector2Array
var next_path_index: int = 0
var path_variant: Array = []

var airlock_data: ModuleData = preload("res://data/modules/module_airlock.tres") as ModuleData

var in_sub_path: bool = false
var sub_path: Array[PathComponent.PathTraversalEdgeData] 
var sub_path_index: int = 0

enum PathActionState { Starting, Moving, Finished, Failed }

var action_state: PathActionState = PathActionState.Starting

var modules_to_watch: Array[ModuleBase] = []


func initialize_action(_pawn: PawnBase, _target: Node2D) -> void:
	SignalBus.module_removed.connect(module_removed)
	pawn = _pawn
	target = _target
	target_is_module = _target is ModuleBase
	var target_is_component := _target is ComponentBase
	#path = []
	path_variant.clear()
	modules_to_watch.clear()
	sub_path.clear()
	if pawn.current_module != null:
		if target_is_module or target_is_component:
			if pawn.current_module == target:
				action_state = PathActionState.Finished
				return
			if target_is_component and pawn.current_module == target.owner_module:
				action_state = PathActionState.Finished
				return
			# Module -> Module
			#path = Global.path_manager.run_pathfinding(pawn.current_module, target as ModuleBase, true)
			if target_is_component:
				modules_to_watch = Global.path_manager.run_pathfinding_to_component_type(pawn.current_module, target as ComponentBase)
			else:
				modules_to_watch = Global.path_manager.run_pathfinding_by_module(pawn.current_module, target as ModuleBase)
			path_variant.append_array(modules_to_watch)
		else:
			# Module -> External
			#path = Global.path_manager.run_pathfinding_to_type(pawn.current_module, airlock_data, true)
			modules_to_watch = Global.path_manager.run_pathfinding_to_type_by_module(pawn.current_module, airlock_data)
			path_variant.append_array(modules_to_watch)
			# airlock -> direct to object
			path_variant.append(target)
	else:
		if target_is_module or target_is_component:
			# External -> Module
			var nearest_airlock: ModuleBase = Global.world_manager.get_nearest_module_by_type(pawn.position, airlock_data)
			path_variant = [pawn.position]
			if target_is_component:
				modules_to_watch = Global.path_manager.run_pathfinding_to_component_type(nearest_airlock, target as ComponentBase)
			else:
				modules_to_watch = Global.path_manager.run_pathfinding_by_module(nearest_airlock, target as ModuleBase)
			path_variant.append_array(modules_to_watch)
		else:
			# External -> External
			# Super easy, just go directly?
			path_variant = [pawn.position, target]
	if path_variant.size() < 2:
		action_state = PathActionState.Failed
	else:
		# Want next module at end so easy to pop
		modules_to_watch.reverse()
		action_state = PathActionState.Moving
		# Debug shove path in UI
		var packed_path: PackedVector2Array = []
		for index in path_variant.size():
			packed_path.append(Global.world_to_cell(extract_position(index)))
		Global.ui_in_game.debug_path = packed_path
	

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
	elif modules_to_watch.has(removed_module):
		# One of the modules on the path is gone, recalc path
		initialize_action(pawn, target)
		
func extract_position(index: int) -> Vector2:
	if index >= path_variant.size():
		print("trying to get the path position of an element not in the path_variant array!")
		return Vector2.ZERO
	if path_variant[index] is ModuleBase:
		var module: ModuleBase = path_variant[index] as ModuleBase
		if index > 0 and path_variant[index - 1] is ModuleBase:
			var prev_mod: ModuleBase = path_variant[index - 1] as ModuleBase
			return Vector2(module.get_path_component().get_connection_point_from(prev_mod)) + module.position
		return Global.cell_to_world(module.module_cell, true)
	elif path_variant[index] is Node2D:
		var node: Node2D = path_variant[index] as Node2D
		return node.position
	elif path_variant[index] is Vector2:
		return path_variant[index] as Vector2
	else:
		assert(false, "Unknown type in path array, failing!")
		action_state = PathActionState.Failed
	return Vector2.ZERO
	
func reached_next_node() -> void:
	if path_variant[next_path_index] is ModuleBase:
		var this_module: ModuleBase = path_variant[next_path_index] as ModuleBase
		var prev_module: ModuleBase = null
		if next_path_index > 0 and path_variant[next_path_index -1 ] is ModuleBase:
			prev_module = path_variant[next_path_index -1] as ModuleBase
		this_module.enter_module_from(pawn, prev_module)
		modules_to_watch.pop_back()
	else:
		pawn.current_module = null
	next_path_index += 1
	check_enter_sub_path()
	
func check_enter_sub_path() -> void:
	if next_path_index > 0 and next_path_index + 1 < path_variant.size():
		if path_variant[next_path_index - 1] is ModuleBase and path_variant[next_path_index] is ModuleBase and path_variant[next_path_index + 1] is ModuleBase:
			var last_module: ModuleBase = path_variant[next_path_index - 1] as ModuleBase
			var current_module: ModuleBase = path_variant[next_path_index] as ModuleBase
			var next_module: ModuleBase = path_variant[next_path_index + 1] as ModuleBase
			if current_module.get_path_component() != null:
				sub_path = current_module.get_path_component().get_path_through_module(last_module, next_module)
				if sub_path.size() > 0:
					sub_path_index = 0
					in_sub_path = true
	
func move(delta: float) -> void:
	var dist_to_travel: float = pawn.speed * delta
	var next_position: Vector2 = pawn.position
	while dist_to_travel > 0:
		if in_sub_path:
			if sub_path_index >= sub_path.size():
				in_sub_path = false
				reached_next_node()
				continue
			var next_path_position: Vector2 = path_variant[next_path_index].position + sub_path[sub_path_index].end_pos
			var travel_vector: Vector2 = next_path_position - next_position
			var dist_to_next_point: float = travel_vector.length()
			if dist_to_next_point <= dist_to_travel + 0.0001:
				next_position = next_path_position
				dist_to_travel -= dist_to_next_point
				sub_path_index += 1
			else:
				next_position = next_position + travel_vector / dist_to_next_point * dist_to_travel
				dist_to_travel = 0
				break
		else:
			if next_path_index >= path_variant.size():
				break
			var next_path_position: Vector2 = extract_position(next_path_index)
			var travel_vector: Vector2 = next_path_position - next_position
			var dist_to_next_point: float = travel_vector.length()
			if dist_to_next_point <= dist_to_travel + 0.0001:
				next_position = next_path_position
				dist_to_travel -= dist_to_next_point
				reached_next_node()
			else:
				next_position = next_position + travel_vector / dist_to_next_point * dist_to_travel
				dist_to_travel = 0
				break
	if next_position == pawn.position:
		# We didn't move, we're done here
		#print ("tried to move but failed? Marking as finished but investigate")
		action_state = PathActionState.Finished
	if next_path_index >= path_variant.size():
		# Made it to the last position
		action_state = PathActionState.Finished
	pawn.move_to(next_position)

func is_failed() -> bool:
	return action_state == PathActionState.Failed
	
func is_finished() -> bool:
	return action_state == PathActionState.Finished
