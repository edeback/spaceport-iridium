class_name Job_MineAsteroid
extends JobBase

var asteroid: AsteroidBase
var pawn: PawnBase
var requesting_component: MiningComponent
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

enum MineAsteroidState { Starting, MovingToAsteroid, MineAsteroid, ReturningToModule, DepositMaterial, Finished, Failed }

func get_category() -> Category:
	return Category.WORK

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

func setup(component: MiningComponent) -> void:
	assert(component != null and component.owner_module != null)
	requesting_component = component
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
	max_mined = pawn.carrying_capacity
	if pawn is MiningDronePawn:
		efficiency = (pawn as MiningDronePawn).drone_efficiency
	if state != MineAsteroidState.Failed:
		state = MineAsteroidState.Starting
		
func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = MineAsteroidState.Failed
	else:
		state = MineAsteroidState.Finished

func _on_end() -> void:
	# Don't stay connected to the autoload after the job ends (leaks the job
	# and keeps _module_removed firing forever).
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	if asteroid != null and is_instance_valid(asteroid) and asteroid.despawning.is_connected(_asteroid_despawned):
		asteroid.despawning.disconnect(_asteroid_despawned)
	
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
	
## Reset the set asteroid so we can find a new one
func cancel_asteroid() -> void:
	if asteroid != null and is_instance_valid(asteroid) and asteroid.despawning.is_connected(_asteroid_despawned):
		asteroid.despawning.disconnect(_asteroid_despawned)
	asteroid = null
	
func get_asteroid() -> void:
	# If an asteroid is still set (and valid), it came from a save - honor it, otherwise find a new one
	if asteroid == null or not is_instance_valid(asteroid):
		var asteroids: Array[Node] = pawn.get_tree().get_nodes_in_group("asteroid")
		asteroids.shuffle()
		# Priority order: player-designated asteroids first, then ones carrying
		# this mining bay's priority ore, then whatever the shuffle found first.
		# requesting_component can be null (module removed while unclaimed).
		var priority_ore: ResourceData = requesting_component.priority_ore if requesting_component != null else null
		var ore_match: AsteroidBase = null
		var fallback: AsteroidBase = null
		asteroid = null
		for test_asteroid: AsteroidBase in asteroids:
			if test_asteroid.is_empty():
				continue
			if test_asteroid.designated:
				asteroid = test_asteroid
				break
			if ore_match == null and priority_ore != null and test_asteroid.has_ore(priority_ore):
				ore_match = test_asteroid
			if fallback == null:
				fallback = test_asteroid
		if asteroid == null:
			asteroid = ore_match if ore_match != null else fallback
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
		cancel_asteroid()
		state = MineAsteroidState.Starting
	# otherwise we don't care, we already came and left already

func _module_removed(module: ModuleBase) -> void:
	# requesting_component nulls itself below, so a second removal must not
	# dereference it; pawn is null while the job sits unclaimed on the board.
	if requesting_component != null and module == requesting_component.owner_module:
		requesting_component = null
		state = MineAsteroidState.Failed
		if pawn != null and pawn.movement_component.movement_ended.is_connected(next_state):
			pawn.movement_component.movement_ended.disconnect(next_state)

func move_to_asteroid() -> void:
	state = MineAsteroidState.MovingToAsteroid
	pawn.movement_component.movement_ended.connect(next_state, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(asteroid, 1, true)
		
		
func next_state(prev_success: bool) -> void:
	# _ended: the state comparisons below only *happen* to no-op on the
	# terminal enum values - don't rely on that for a stale one-shot firing
	# after an external cancel.
	if _ended:
		return
	if not prev_success:
		if state < MineAsteroidState.ReturningToModule:
			# We didn't make it there, try a different asteroid
			cancel_asteroid()
			state = MineAsteroidState.Starting
		else:
			cancel(true)
	elif state == MineAsteroidState.MovingToAsteroid:
		state = MineAsteroidState.MineAsteroid
	elif state == MineAsteroidState.ReturningToModule:
		deposit_material()
		
		
func mine_asteroid(delta: float) -> void:
	# Stay glued to asteroid
	pawn.position = asteroid.position
	if pawn.inventory_component != null and pawn.inventory_component.space_available() <= 0:
		move_to_module()
		return
	time_mining += delta * efficiency
	if time_mining >= default_seconds_to_mine:
		time_mining = 0
		# Can be null if another drone emptied the asteroid this frame - the
		# is_empty() check below sends us hunting for a new one.
		var mined_resource: ResourceData = asteroid.mine_resource()
		if mined_resource != null:
			var stack := ResourceStack.new()
			stack.resource_data = mined_resource
			stack.amount = 1
			if mined_resource.has_variance:
				var instance := OreInstanceData.new()
				instance.richness = asteroid.sample_richness()
				stack.instance_data = instance
			pawn.inventory_component.add_stacks(mined_resource, [stack])
			resources_mined_count += 1
	if resources_mined_count >= max_mined or pawn.inventory_component.space_available() <= 0:
		move_to_module()
	elif asteroid.is_empty():
		cancel_asteroid()
		state = MineAsteroidState.Starting
		
func move_to_module() -> void:
	state = MineAsteroidState.ReturningToModule
	pawn.movement_component.movement_ended.connect(next_state, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(requesting_component.owner_module)
		
func deposit_material() -> void:
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

# --- persistence (WI-21) ------------------------------------------------------

## Records the mining bay (component) that owns this job plus the targeted rock.
func get_save_data() -> Dictionary:
	# Lose the job if we were already on our way back, we don't want to start with locating an asteroid again
	if requesting_component == null or not is_instance_valid(requesting_component) or state > MineAsteroidState.MineAsteroid:
		return {}
	return {
		"type": "mine_asteroid",
		"mining_component": SaveManager.component_ref(requesting_component),
		"asteroid": SaveManager.asteroid_ref(asteroid),
	}

static func restore(data: Dictionary) -> JobBase:
	var component: MiningComponent = SaveManager.resolve_component_ref(data.get("mining_component", {})) as MiningComponent
	if component == null:
		return null
	var job := Job_MineAsteroid.new()
	job.setup(component)
	job.output_storage = component.output_storage
	job.asteroid = SaveManager.resolve_asteroid_ref(data.get("asteroid", {}))
	return job

# Probably don't need this - MiningDronePawns have their own way of getting new jobs
#func get_followup_job(_pawn: PawnBase) -> JobBase:
	#if not is_instance_valid(requesting_component):
		#return null
	#
	#var offered: JobBase = requesting_component.offer_followup_job(pawn)
	#if offered != null:
		#return offered
	#return null
