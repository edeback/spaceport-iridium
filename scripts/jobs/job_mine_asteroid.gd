class_name Job_MineAsteroid
extends JobBase

var asteroid: AsteroidBase
var pawn: PawnBase
var requesting_module: ModuleBase
var state: MineAsteroidState = MineAsteroidState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()
var action: Action_PathToTarget = null
var efficiency: float = 1.0
var time_mining: float = 0.0
var default_seconds_to_mine: float = 1.0
var max_mined: int = 5
var resources_mined: Array[ResourceData] = []

enum MineAsteroidState { Starting, MovingToAsteroid, MineAsteroid, ReturningToModule, DepositMaterial, Finished, Failed }

func get_job_description() -> String:
	return "Mine Asteroid"

func get_subtask_description() -> String:
	match state:
		MineAsteroidState.MovingToAsteroid:
			return "Moving to asteroid"
		MineAsteroidState.MineAsteroid:
			return "Mining asteroid"
		MineAsteroidState.ReturningToModule:
			return "Returning to mining bay"
	return ""

func setup(_module: ModuleBase) -> void:
	assert(_module != null)
	requesting_module = _module
	state = MineAsteroidState.Starting
	SignalBus.module_removed.connect(_module_removed)
	
func can_do_job(_pawn: PawnBase) -> bool:
	var asteroids: Array[Node] = _pawn.get_tree().get_nodes_in_group("asteroid")
	var has_resources: bool = false
	for node in asteroids:
		if (node as AsteroidBase).cur_resources > 0:
			has_resources = true
			break
	return has_resources and Global.path_manager.is_space_reachable(_pawn)
	
func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	if state != MineAsteroidState.Failed:
		state = MineAsteroidState.Starting
		
func cancel(_as_failed: bool) -> void:
	if _as_failed:
		state = MineAsteroidState.Failed
	else:
		state = MineAsteroidState.Finished
	if action:
		action.cancel()
		action = null
	
func process_job(delta: float) -> void:
	match state:
		MineAsteroidState.Starting:
			get_asteroid()
		MineAsteroidState.MovingToAsteroid:
			move_to_asteroid(delta)
		MineAsteroidState.MineAsteroid:
			mine_asteroid(delta)
		MineAsteroidState.ReturningToModule:
			move_to_module(delta)
		MineAsteroidState.DepositMaterial:
			deposit_material()
		MineAsteroidState.Finished:
			pass
		MineAsteroidState.Failed:
			pass
	
func get_asteroid() -> void:
	var asteroids: Array[Node] = pawn.get_tree().get_nodes_in_group("asteroid")
	asteroids.shuffle()
	asteroid = null
	for test_asteroid: AsteroidBase in asteroids: 
		if not test_asteroid.is_empty():
			asteroid = test_asteroid
			break
	if asteroid == null:
		state = MineAsteroidState.Failed
		return
	asteroid.despawning.connect(_asteroid_despawned)
	state = MineAsteroidState.MovingToAsteroid
	
func _asteroid_despawned() -> void:
	asteroid = null
	# Find a different one!
	if state < MineAsteroidState.ReturningToModule:
		state = MineAsteroidState.Starting
		if action != null:
			action.free()
			action = null
	# otherwise we don't care, we already came and left already

func _module_removed(module: ModuleBase) -> void:
	if module == requesting_module:
		requesting_module = null
		state = MineAsteroidState.Failed
		if action != null:
			action.free()
			action = null

func move_to_asteroid(delta: float) -> void:
	if action == null:
		action = Action_PathToTarget.new()
		action.initialize_action(pawn, asteroid, 1, true)
	action.process_action(delta)
	if action.is_failed():
		state = MineAsteroidState.Failed
		action.free()
		action = null
	elif action.is_finished():
		state = MineAsteroidState.MineAsteroid
		action.free()
		action = null
		
func mine_asteroid(delta: float) -> void:
	# Stay glued to asteroid
	pawn.position = asteroid.position
	time_mining += delta * efficiency
	if time_mining >= default_seconds_to_mine:
		time_mining = 0
		resources_mined.append(asteroid.mine_resource())
	if resources_mined.size() >= max_mined:
		state = MineAsteroidState.ReturningToModule
	elif asteroid.is_empty():
		state = MineAsteroidState.Starting
		
func move_to_module(delta: float) -> void:
	if action == null:
		action = Action_PathToTarget.new()
		action.initialize_action(pawn, requesting_module)
	action.process_action(delta)
	if action.is_failed():
		state = MineAsteroidState.Failed
		action.free()
		action = null
	elif action.is_finished():
		state = MineAsteroidState.DepositMaterial
		action.free()
		action = null
		
func deposit_material() -> void:
	var storage: StorageComponent = requesting_module.get_component_by_type(StorageComponent) as StorageComponent
	if storage:
		for resource: ResourceData in resources_mined:
			storage.deposit(resource, 1)
		state = MineAsteroidState.Finished
	else:
		state = MineAsteroidState.Failed
	
func is_failed() -> bool:
	return state == MineAsteroidState.Failed
	
func is_finished() -> bool:
	return state == MineAsteroidState.Finished
