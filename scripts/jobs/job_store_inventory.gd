class_name Job_StoreInventory
extends JobBase

## Sweeps whatever the pawn is currently carrying into the nearest reachable
## storage that will take it. Runs ahead of the normal job board (see
## PawnBase.start_job()) whenever a pawn is idle with a non-empty inventory —
## most commonly because a Job_GetResource or Job_MineAsteroid got canceled
## mid-transfer and left them holding resources.

var pawn: PawnBase
var resource_data: ResourceData
var deposit_storage: StorageComponent

enum StoreInventoryState { Start, GoToStorage, DepositResource, Finished, Failed }
var job_state: StoreInventoryState = StoreInventoryState.Start:
	set(new_state):
		if job_state != new_state:
			job_state = new_state
			subtask_changed.emit()

func get_category() -> Category:
	return Category.HAUL

func get_job_description() -> String:
	return "Store Carried Resources"

func get_subtask_description() -> String:
	match job_state:
		StoreInventoryState.GoToStorage:
			return "Returning resources to storage"
		StoreInventoryState.DepositResource:
			return "Depositing resources"
	return ""

func can_do_job(_pawn: PawnBase) -> bool:
	# If we have a specific storage we're trying to get to, only check that one
	if deposit_storage != null:
		return Global.path_manager.is_reachable(_pawn, deposit_storage.owner_module)
	return not _find_storage_target(_pawn).is_empty()

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	job_start()

func is_finished() -> bool:
	return job_state == StoreInventoryState.Finished

func is_failed() -> bool:
	return job_state == StoreInventoryState.Failed

func _on_cancel(as_failed: bool) -> void:
	# Deliberately don't touch pawn.inventory_component here. Whatever is still
	# carried stays with the pawn and gets picked up again on the next idle
	# tick via PawnBase.start_job().
	if as_failed:
		job_state = StoreInventoryState.Failed
	else:
		job_state = StoreInventoryState.Finished

func job_start() -> void:
	# No specific deposit set, search for anything
	if deposit_storage == null:
		var target: Dictionary = _find_storage_target(pawn)
		if target.is_empty():
			cancel(true)
			return
		resource_data = target["resource"]
		deposit_storage = target["storage"]
	move_to_storage()

func move_to_storage() -> void:
	job_state = StoreInventoryState.GoToStorage
	pawn.movement_component.movement_ended.connect(deposit_resource, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(deposit_storage.owner_module)

func deposit_resource(prev_success: bool) -> void:
	# _ended: a stale movement one-shot firing after an external cancel must
	# not overwrite the terminal state or move inventory on a dead job.
	if not prev_success or _ended:
		cancel(true)
		return
	job_state = StoreInventoryState.DepositResource
	# If there is a specific resource stated, deposit it
	# Otherwise try to deposit everything it can
	var success := false
	if resource_data != null:
		success = deposit_one_resource(resource_data)
	else:
		for resource: ResourceData in pawn.inventory_component.get_carried_resources():
			if deposit_storage.can_store_resource(resource):
				success = deposit_one_resource(resource)
			if not success:
				break
	if success:
		job_state = StoreInventoryState.Finished
	else:
		cancel(true)
		
func deposit_one_resource(resource: ResourceData) -> bool:
	var carried_amount: int = pawn.inventory_component.get_carried_amount(resource)
	var deposit_amount: int = mini(carried_amount, deposit_storage.space_available())
	if deposit_amount <= 0:
		# Storage filled up while we were walking over — try again next tick.
		return false
	var withdrawn: Array[ResourceStack] = pawn.inventory_component.withdraw_stacks(resource, deposit_amount)
	if not withdrawn.is_empty() and deposit_storage.deposit_stacks(resource, withdrawn):
		return true
	else:
		# Something went wrong after we already took it off the pawn — give it back
		# rather than losing it.
		if not withdrawn.is_empty():
			pawn.inventory_component.add_stacks(resource, withdrawn)
		return false

## Finds one carried resource type and the closest reachable storage that will
## accept it. Returns {} if nothing carried has anywhere to go right now.
## Pure query — safe to call from can_do_job() without side effects.
func _find_storage_target(_pawn: PawnBase) -> Dictionary:
	if _pawn == null or _pawn.inventory_component == null or _pawn.inventory_component.is_empty():
		return {}
	for resource: ResourceData in _pawn.inventory_component.get_carried_resources():
		if _pawn.inventory_component.get_carried_amount(resource) <= 0:
			continue
		var storage: StorageComponent = _find_import_storage(_pawn, resource)
		if storage != null:
			return {"resource": resource, "storage": storage}
	return {}

## Picks the reachable sink that will take `resource`, highest priority first and
## nearest among equals - the same ordering as Job_GetResource._find_deposit_storage,
## because storage priority is the routing language: dumping a sweep into whatever
## bin is merely *closest* can drop it in a deconstruction site's -99 export bin,
## which then has to haul it straight back out.
##
## Unlike the haul job this deliberately has NO `priority >` floor. A haul needs one
## so a push can't flip-flop between two equal bins; a sweep has no source bin to
## compare against and must accept *any* bin that will take the cargo rather than
## strand a loaded pawn (PawnBase relies on {} meaning "nowhere will take this").
func _find_import_storage(_pawn: PawnBase, resource: ResourceData) -> StorageComponent:
	var storage_nodes: Array[Node] = _pawn.get_tree().get_nodes_in_group("resource_storage")
	var best_storage: StorageComponent = null
	var best_priority: int = 0
	var best_distance: int = 0
	for node in storage_nodes:
		var storage: StorageComponent = node as StorageComponent
		if storage == null or not storage.accepts_imports:
			continue
		if not storage.can_deposit(resource, 1) or not Global.path_manager.is_reachable(_pawn, storage.owner_module):
			continue
		var distance: int = storage.owner_module.module_cell.distance_squared_to(Global.world_to_cell(_pawn.global_position))
		if best_storage == null or storage.priority > best_priority or (storage.priority == best_priority and distance < best_distance):
			best_storage = storage
			best_priority = storage.priority
			best_distance = distance
	return best_storage
