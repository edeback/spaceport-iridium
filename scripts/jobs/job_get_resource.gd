class_name Job_GetResource
extends JobBase

@export var resource_data: ResourceData
@export var amount: int = 1

var origin: Vector2i
var destination: ModuleBase
var requester: Node
var pawn: PawnBase

var export_storage: StorageComponent
var deposit_storage: StorageComponent

enum ResourceJobState { Start, GoToResource, GatherResource, ReturnWithResource, DepositResource, Finished, Failed }
var job_state: ResourceJobState = ResourceJobState.Start:
	set(new_state):
		if job_state != new_state:
			job_state = new_state
			subtask_changed.emit()

func get_job_description() -> String:
	return "Get resource"

func get_subtask_description() -> String:
	match job_state:
		ResourceJobState.GoToResource:
			return "Going to resource"
		ResourceJobState.GatherResource:
			return "Gathering resource"
		ResourceJobState.ReturnWithResource:
			return "Returning with resource"
		ResourceJobState.DepositResource:
			return "Depositing resource"
	return ""

func is_valid() -> bool:
	return requester != null and resource_data != null and deposit_storage != null

func can_do_job(_pawn: PawnBase) -> bool:
	if _pawn.inventory_component != null and amount > _pawn.inventory_component.space_available():
		return false
	var storage_component: StorageComponent = null
	var storage_nodes: Array[Node] = requester.get_tree().get_nodes_in_group("resource_storage")
	for node in storage_nodes:
		var storage: StorageComponent = node as StorageComponent
		if storage.accepts_exports and storage.priority < deposit_storage.priority and storage.can_withdraw(resource_data, amount):
			storage_component = storage
			break
	if storage_component != null:
		return Global.path_manager.is_reachable(_pawn, storage_component.owner_module) and Global.path_manager.is_reachable(_pawn, deposit_storage.owner_module)
	return false

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	job_start()
			
func is_finished() -> bool:
	return job_state == ResourceJobState.Finished
	
func is_failed() -> bool:
	return job_state == ResourceJobState.Failed
		
func cancel(as_failed: bool) -> void:
	if as_failed:
		job_state = ResourceJobState.Failed
	else:
		job_state = ResourceJobState.Finished
	# Deliberately don't touch pawn.movement here. If it's mid-ride, let it
	# finish on its own terms — the next job will retarget once it's free.
	if export_storage:
		export_storage.cancel_withdraw_job(self)
	if deposit_storage:
		deposit_storage.cancel_deposit_job(self)
		
			
func job_start() -> void:
	var min_distance: int = 0
	var storage_component: StorageComponent = null
	var storage_nodes: Array[Node] = requester.get_tree().get_nodes_in_group("resource_storage")
	for node in storage_nodes:
		var storage: StorageComponent = node as StorageComponent
		if storage.accepts_exports and storage.priority < deposit_storage.priority and storage.can_withdraw(resource_data, amount):
			var new_distance: int = storage.owner_module.module_cell.distance_squared_to(pawn.cell)
			if storage_component ==  null or new_distance < min_distance:
					storage_component = storage
					min_distance = new_distance
	if storage_component != null:
		destination = storage_component.owner_module
		export_storage = storage_component
		export_storage.add_withdraw_job(self)
		deposit_storage.add_deposit_job(self)
		move_to_export_storage()
	else:
		cancel(true)
	
		
func move_to_export_storage() -> void:
	job_state = ResourceJobState.GoToResource
	pawn.movement_component.movement_ended.connect(gather_resource, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(export_storage.owner_module)
		
func gather_resource(prev_success: bool) -> void:
	if not prev_success:
		cancel(true)
		return
	job_state = ResourceJobState.GatherResource
	if export_storage.complete_withdraw_job(self):
		# Resource now physically lives on the pawn. If the job is canceled
		# anywhere from here on, it stays with them instead of disappearing.
		pawn.inventory_component.add(resource_data, amount)
		move_to_import_storage()
	else:
		cancel(true)
		
func move_to_import_storage() -> void:
	job_state = ResourceJobState.ReturnWithResource
	pawn.movement_component.movement_ended.connect(deposit_resource, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(deposit_storage.owner_module)
		
func deposit_resource(prev_success: bool) -> void:
	if not prev_success:
		cancel(true)
		return
	job_state = ResourceJobState.DepositResource
	var carried: int = pawn.inventory_component.withdraw(resource_data, amount)
	if carried <= 0:
		# We aren't actually holding what we expected to deposit. Shouldn't
		# normally happen since only this job touches the pawn's inventory
		# while it's running, but bail out safely if it does.
		cancel(true)
		return
	if deposit_storage.complete_deposit_job(self):
		job_state = ResourceJobState.Finished
	else:
		# Couldn't deposit — give it back so it isn't lost.
		pawn.inventory_component.add(resource_data, carried)
		cancel(true)
#
#func _job_gather() -> void:
	## temp temp temp
	#if withdraw_storage.withdraw_job(self):
		#deposit_storage.deposit_job(self)
		#job_state = JobState.Return
