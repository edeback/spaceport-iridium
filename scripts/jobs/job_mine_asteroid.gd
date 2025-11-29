class_name Job_MineAsteroid
extends Node

var asteroid: AsteroidBase
var pawn: PawnBase
var requesting_module: ModuleBase
var state: MineAsteroidState = MineAsteroidState.Starting
var action: Action_PathToTarget = null

enum MineAsteroidState { Starting, MovingToAsteroid, ReturningToModule, Finished, Failed }


func setup(_module: ModuleBase, _pawn: PawnBase) -> void:
	assert(_module != null and _pawn != null)
	requesting_module = _module
	pawn = _pawn
	state = MineAsteroidState.Starting
	SignalBus.module_removed.connect(_module_removed)
	
	
func process_job(delta: float) -> void:
	match state:
		MineAsteroidState.Starting:
			get_asteroid()
		MineAsteroidState.MovingToAsteroid:
			move_to_asteroid(delta)
		MineAsteroidState.ReturningToModule:
			move_to_module(delta)
		MineAsteroidState.Finished:
			state = MineAsteroidState.Starting
		MineAsteroidState.Failed:
			pass
	
func get_asteroid() -> void:
	var asteroids: Array[Node] = pawn.get_tree().get_nodes_in_group("asteroid")
	if asteroids.size() == 0:
		state = MineAsteroidState.Failed
		return
	asteroid = asteroids.pick_random() as AsteroidBase
	asteroid.despawning.connect(_asteroid_despawned)
	state = MineAsteroidState.MovingToAsteroid
	
func _asteroid_despawned() -> void:
	asteroid = null
	# Find a different one!
	if state == MineAsteroidState.MovingToAsteroid:
		
		state = MineAsteroidState.Starting
	# otherwise we don't care, we already came and left already

func _module_removed(module: ModuleBase) -> void:
	if module == requesting_module:
		requesting_module = null
		state = MineAsteroidState.Failed

func move_to_asteroid(delta: float) -> void:
	if action == null:
		action = Action_PathToTarget.new()
		action.initialize_action(pawn, asteroid, false)
	action.process_action(delta)
	if action.is_failed():
		state = MineAsteroidState.Failed
	elif action.is_finished():
		state = MineAsteroidState.ReturningToModule
		action.free()
		action = null
		
func move_to_module(delta: float) -> void:
	if action == null:
		action = Action_PathToTarget.new()
		action.initialize_action(pawn, requesting_module, true)
	action.process_action(delta)
	if action.is_failed():
		state = MineAsteroidState.Failed
	elif action.is_finished():
		state = MineAsteroidState.Finished
		action.free()
		action = null
	
func is_failed() -> bool:
	return state == MineAsteroidState.Failed
	
func is_finished() -> bool:
	return state == MineAsteroidState.Finished
