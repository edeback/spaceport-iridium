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
	var carried_amount: int = pawn.inventory_component.get_carried_amount(resource_data)
	var deposit_amount: int = mini(carried_amount, deposit_storage.space_available())
	if deposit_amount <= 0:
		# Storage filled up while we were walking over — try again next tick.
		cancel(true)
		return
	var withdrawn: Array[ResourceStack] = pawn.inventory_component.withdraw_stacks(resource_data, deposit_amount)
	if not withdrawn.is_empty() and deposit_storage.deposit_stacks(resource_data, withdrawn):
		job_state = StoreInventoryState.Finished
	else:
		# Something went wrong after we already took it off the pawn — give it back
		# rather than losing it.
		if not withdrawn.is_empty():
			pawn.inventory_component.add_stacks(resource_data, withdrawn)
		cancel(true)

## Finds one carried resource type and the closest reachable storage that will
## accept it. Returns {} if nothing carried has anywhere to go right now.
## Pure query — safe to call from can_do_job() without side effects.
func _find_storage_target(_pawn: PawnBase) -> Dictionary:
	if _pawn == null or _pawn.inventory_component == null or _pawn.inventory_component.is_empty():
		return {}
	for resource: ResourceData in _pawn.inventory_component.get_carried_resources():
		if _pawn.inventory_component.get_carried_amount(resource) <= 0:
			continue
		var storage: StorageComponent = _find_closest_import_storage(_pawn, resource)
		if storage != null:
			return {"resource": resource, "storage": storage}
	return {}

func _find_closest_import_storage(_pawn: PawnBase, resource: ResourceData) -> StorageComponent:
	var storage_nodes: Array[Node] = _pawn.get_tree().get_nodes_in_group("resource_storage")
	var best_storage: StorageComponent = null
	var min_distance: int = 0
	for node in storage_nodes:
		var storage: StorageComponent = node as StorageComponent
		if storage.accepts_imports and storage.can_deposit(resource, 1) and Global.path_manager.is_reachable(_pawn, storage.owner_module):
			var new_distance: int = storage.owner_module.module_cell.distance_squared_to(Global.world_to_cell(_pawn.global_position))
			if best_storage == null or new_distance < min_distance:
				best_storage = storage
				min_distance = new_distance
	return best_storage
