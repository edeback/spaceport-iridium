class_name Job_MineAsteroid
extends JobBase

var asteroid: AsteroidBase
var pawn: PawnBase
var requesting_module: ModuleBase
var output_storage: StorageComponent
var state: MineAsteroidState = MineAsteroidState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()
var efficiency: float = 1.0
var time_mining: float = 0.0
var default_seconds_to_mine: float = 1.0
var max_mined: int = 5
var resources_mined_count: int = 0

## Placeholder sampling range until AsteroidBase exposes real per-chunk
## richness data - this is here so mined ore actually carries continuous
## variance end-to-end. Swap for something asteroid-driven whenever that
## data exists (e.g. richer asteroids biasing toward the high end).
const ORE_RICHNESS_RANGE := Vector2(0.3, 1.0)

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
	if _pawn.inventory_component != null and _pawn.inventory_component.space_available() <= 0:
		return false
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
	
func process_job(delta: float) -> void:
	match state:
		MineAsteroidState.Starting:
			get_asteroid()
		MineAsteroidState.MovingToAsteroid:
			pass
		MineAsteroidState.MineAsteroid:
			mine_asteroid(delta)
		MineAsteroidState.ReturningToModule:
			pass
		MineAsteroidState.DepositMaterial:
			pass
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
	move_to_asteroid()
	
func _asteroid_despawned() -> void:
	asteroid = null
	pawn.movement_component.cancel()
	# Find a different one!
	if state < MineAsteroidState.ReturningToModule:
		state = MineAsteroidState.Starting
	# otherwise we don't care, we already came and left already

func _module_removed(module: ModuleBase) -> void:
	if module == requesting_module:
		requesting_module = null
		state = MineAsteroidState.Failed
		if pawn.movement_component.movement_ended.is_connected(mine_asteroid):
			pawn.movement_component.movement_ended.disconnect(mine_asteroid)

func move_to_asteroid() -> void:
	state = MineAsteroidState.MovingToAsteroid
	pawn.movement_component.movement_ended.connect(start_mining, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(asteroid, 1, true)
		
func start_mining(prev_success: bool) -> void:
	if not prev_success:
		if state < MineAsteroidState.ReturningToModule:
			state = MineAsteroidState.Starting
		else:
			cancel(true)
	else:
		state = MineAsteroidState.MineAsteroid
		
func mine_asteroid(delta: float) -> void:
	# Stay glued to asteroid
	pawn.position = asteroid.position
	if pawn.inventory_component != null and pawn.inventory_component.space_available() <= 0:
		move_to_module()
		return
	time_mining += delta * efficiency
	if time_mining >= default_seconds_to_mine:
		time_mining = 0
		var mined_resource: ResourceData = asteroid.mine_resource()
		var stack := ResourceStack.new()
		stack.resource_data = mined_resource
		stack.amount = 1
		if mined_resource != null and mined_resource.has_variance:
			var instance := OreInstanceData.new()
			instance.richness = randf_range(ORE_RICHNESS_RANGE.x, ORE_RICHNESS_RANGE.y)
			stack.instance_data = instance
		pawn.inventory_component.add_stacks(mined_resource, [stack])
		resources_mined_count += 1
	if resources_mined_count >= max_mined:
		move_to_module()
	elif asteroid.is_empty():
		state = MineAsteroidState.Starting
		
func move_to_module() -> void:
	state = MineAsteroidState.ReturningToModule
	pawn.movement_component.movement_ended.connect(deposit_material, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(requesting_module)
		
func deposit_material(prev_success: bool) -> void:
	if not prev_success:
		cancel(true)
		return
	if output_storage == null:
		state = MineAsteroidState.Failed
		return
	# Drain whatever the pawn is carrying (normally just what this trip mined,
	# but if they picked up leftovers from an earlier canceled job, this sweeps
	# those out too as a side benefit). Anything the storage won't take -
	# wrong resource type, or it fills up mid-deposit - simply stays on the
	# pawn and gets retried by Job_StoreInventory on the next idle tick.
	for resource: ResourceData in pawn.inventory_component.get_carried_resources():
		var carried: int = pawn.inventory_component.get_carried_amount(resource)
		var deposit_amount: int = mini(carried, output_storage.space_available())
		if deposit_amount <= 0:
			continue
		var withdrawn: Array[ResourceStack] = pawn.inventory_component.withdraw_stacks(resource, deposit_amount)
		if not withdrawn.is_empty() and not output_storage.deposit_stacks(resource, withdrawn):
			pawn.inventory_component.add_stacks(resource, withdrawn)
	state = MineAsteroidState.Finished
	
func is_failed() -> bool:
	return state == MineAsteroidState.Failed
	
func is_finished() -> bool:
	return state == MineAsteroidState.Finished
