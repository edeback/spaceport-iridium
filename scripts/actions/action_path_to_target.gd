class_name Action_PathToTarget
extends Node

var pawn: PawnBase
var target: Node2D
var target_is_module: bool = true
#var path: PackedVector2Array
var next_path_index: int = 0
var path_variant: Array = []

var airlock_data: ModuleData = preload("res://data/modules/module_airlock.tres") as ModuleData


enum PathActionState { Starting, Moving, Finished, Failed }

var action_state: PathActionState = PathActionState.Starting


func initialize_action(_pawn: PawnBase, _target: Node2D, _target_is_module: bool) -> void:
	pawn = _pawn
	target = _target
	target_is_module = _target is ModuleBase
	#path = []
	path_variant.clear()
	if pawn.current_module != null:
		if target_is_module:
			# Module -> Module
			#path = Global.path_manager.run_pathfinding(pawn.current_module, target as ModuleBase, true)
			path_variant = Global.path_manager.run_pathfinding_by_module(pawn.current_module, target as ModuleBase)
		else:
			# Module -> External
			#path = Global.path_manager.run_pathfinding_to_type(pawn.current_module, airlock_data, true)
			path_variant = Global.path_manager.run_pathfinding_to_type_by_module(pawn.current_module, airlock_data)
			# airlock -> direct to object
			path_variant.append(target)
	else:
		if target_is_module:
			# External -> Module
			var nearest_airlock: ModuleBase = Global.world_manager.get_nearest_module_by_type(pawn.position, airlock_data)
			path_variant = [pawn.position]
			path_variant.append_array(Global.path_manager.run_pathfinding_by_module(nearest_airlock, target as ModuleBase))
		else:
			# External -> External
			# Super easy, just go directly?
			path_variant = [pawn.position, target]
	if path_variant.size() < 2:
		action_state = PathActionState.Failed
	else:
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
		
func extract_position(index: int) -> Vector2:
	if index >= path_variant.size():
		print("trying to get the path position of an element not in the path_variant array!")
		return Vector2.ZERO
	if path_variant[index] is ModuleBase:
		var module: ModuleBase = path_variant[index] as ModuleBase
		return module.position
	elif path_variant[index] is Node2D:
		var node: Node2D = path_variant[index] as Node2D
		return node.position
	elif path_variant[index] is Vector2:
		return path_variant[index] as Vector2
	else:
		assert(false, "Unknown type in path array, failing!")
		action_state = PathActionState.Failed
	return Vector2.ZERO
	
func move(delta: float) -> void:
	var dist_to_travel: float = pawn.speed * delta
	var next_position: Vector2 = pawn.position
	while dist_to_travel > 0:
		if next_path_index >= path_variant.size():
			break
		var next_path_position: Vector2 = extract_position(next_path_index)
		var travel_vector: Vector2 = next_path_position - next_position
		var dist_to_next_point: float = travel_vector.length()
		if dist_to_next_point <= dist_to_travel + 0.0001:
			next_position = next_path_position
			dist_to_travel -= dist_to_next_point
			next_path_index += 1
		else:
			next_position = next_position + travel_vector / dist_to_next_point * dist_to_travel
			dist_to_travel = 0
			break
	if next_position == pawn.position:
		# We didn't move, we're done here
		print ("tried to move but failed? Marking as finished but investigate")
		action_state = PathActionState.Finished
	if next_path_index >= path_variant.size():
		# Made it to the last position
		action_state = PathActionState.Finished
	pawn.position = next_position

func is_failed() -> bool:
	return action_state == PathActionState.Failed
	
func is_finished() -> bool:
	return action_state == PathActionState.Finished
