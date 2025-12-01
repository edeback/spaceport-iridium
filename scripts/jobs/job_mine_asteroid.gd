class_name Job_MineAsteroid
extends JobBase

var asteroid: AsteroidBase
var pawn: PawnBase
var requesting_module: ModuleBase
var state: MineAsteroidState = MineAsteroidState.Starting
var action: Action_PathToTarget = null
var resource_mined: ResourceData
var amount_mined: float = 0

enum MineAsteroidState { Starting, MovingToAsteroid, MineAsteroid, ReturningToModule, DepositMaterial, Finished, Failed }


func setup(_module: ModuleBase) -> void:
	assert(_module != null)
	requesting_module = _module
	state = MineAsteroidState.Starting
	SignalBus.module_removed.connect(_module_removed)
	
func can_do_job(_pawn: PawnBase) -> bool:
	var asteroids: Array[Node] = _pawn.get_tree().get_nodes_in_group("asteroid")
	var test_asteroid: AsteroidBase = asteroids.pick_random() as AsteroidBase
	var test_action: Action_PathToTarget = Action_PathToTarget.new()
	test_action.initialize_action(_pawn, test_asteroid)
	var failed: bool = test_action.is_failed()
	test_action.free()
	return not failed
	
func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	if state != MineAsteroidState.Failed:
		state = MineAsteroidState.Starting
	
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
		action.initialize_action(pawn, asteroid)
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
	if not resource_mined:
		resource_mined = asteroid.output_resource
	# Stay glued to asteroid
	pawn.position = asteroid.position
	var new_amount_mined: float = asteroid.mine_resource(delta * 5.0)
	amount_mined += new_amount_mined
	if new_amount_mined < 0.0001:
		state = MineAsteroidState.ReturningToModule
		
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
	var storage: MultiStorageComponent = requesting_module.get_component_by_type(MultiStorageComponent) as MultiStorageComponent
	if storage:
		storage.deposit(resource_mined, amount_mined)
		state = MineAsteroidState.Finished
	else:
		state = MineAsteroidState.Failed
	
func is_failed() -> bool:
	return state == MineAsteroidState.Failed
	
func is_finished() -> bool:
	return state == MineAsteroidState.Finished
