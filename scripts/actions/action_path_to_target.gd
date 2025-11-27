class_name Action_PathToTarget
extends Node

var pawn: PawnBase
var target: Node2D
var target_is_module: bool = true
var path: PackedVector2Array

var airlock_data: ModuleData = preload("res://data/modules/module_airlock.tres") as ModuleData


enum PathActionStatus { Starting, MovingToModule, MovingToObject, Finished, Failed }

var action_status: PathActionStatus = PathActionStatus.Starting


func initialize_action(_pawn: PawnBase, _target: Node2D, _target_is_module: bool) -> void:
	pawn = _pawn
	target = _target
	target_is_module = _target_is_module
	path = []
	if pawn.current_module != null:
		if _target_is_module:
			# Module -> Module
			path = Global.path_manager.run_pathfinding(pawn.current_module, target as ModuleBase)
		else:
			# Module -> External
			path = Global.path_manager.run_pathfinding_to_type(pawn.current_module, airlock_data)
			# airlock -> direct to object
			path.append(target.position)
	else:
		if _target_is_module:
			# External -> Module
			var nearest_airlock: ModuleBase = Global.world_manager.get_nearest_module_by_type(pawn.position, airlock_data)
			path = PackedVector2Array([pawn.position])
			path.append_array(Global.path_manager.run_pathfinding(nearest_airlock, target as ModuleBase))
		else:
			# External -> External
			# Super easy, just go directly?
			path = PackedVector2Array([pawn.position, target.position])
	if path.size() < 2:
		action_status = PathActionStatus.Failed
	
	

func process_action(delta: float) -> void:
	match action_status:
		PathActionStatus.Starting:
			pass
		PathActionStatus.MovingToModule:
			pass
		PathActionStatus.MovingToObject:
			pass
		PathActionStatus.Finished:
			pass
		PathActionStatus.Failed:
			pass
		
	
	
