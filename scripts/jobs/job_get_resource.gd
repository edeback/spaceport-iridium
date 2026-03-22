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
var action: Action_PathToTarget = null

enum JobState { Start, GoToResource, GatherResource, ReturnWithResource, DepositResource, Finished, Failed }
var job_state: JobState = JobState.Start:
	set(new_state):
		if job_state != new_state:
			job_state = new_state
			subtask_changed.emit()

func get_job_description() -> String:
	return "Get resource"

func get_subtask_description() -> String:
	match job_state:
		JobState.GoToResource:
			return "Going to resource"
		JobState.GatherResource:
			return "Gathering resource"
		JobState.ReturnWithResource:
			return "Returning with resource"
		JobState.DepositResource:
			return "Depositing resource"
	return ""

func is_valid() -> bool:
	return requester != null and resource_data != null and deposit_storage != null

func can_do_job(_pawn: PawnBase) -> bool:
	var storage_component: StorageComponent = null
	var storage_nodes: Array[Node] = requester.get_tree().get_nodes_in_group("resource_storage")
	for node in storage_nodes:
		var storage: StorageComponent = node as StorageComponent
		if storage.accepts_exports and storage.priority < deposit_storage.priority and storage.can_withdraw(resource_data, amount):
			storage_component = storage
			break
	if storage_component != null:
		var test_action: Action_PathToTarget = Action_PathToTarget.new()
		test_action.initialize_action(_pawn, storage_component.owner_module)
		if test_action.is_failed():
			return false
		test_action.initialize_action(_pawn, deposit_storage.owner_module)
		return not test_action.is_failed()
	return false

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	if job_state != JobState.Failed:
		job_state = JobState.Start

func process_job(delta: float) -> void:
	match job_state:
		JobState.Start:
			job_start()
			pass
		JobState.GoToResource:
			move_to_export_storage(delta)
			pass
		JobState.GatherResource:
			gather_resource()
			pass
		JobState.ReturnWithResource:
			move_to_import_storage(delta)
			pass
		JobState.DepositResource:
			deposit_resource()
			pass
		JobState.Finished:
			pass
		JobState.Failed:
			pass
			
func is_finished() -> bool:
	return job_state == JobState.Finished
	
func is_failed() -> bool:
	return job_state == JobState.Failed
	
func cancel(as_failed: bool) -> void:
	if as_failed:
		job_state = JobState.Failed
	else:
		job_state = JobState.Finished
	if action != null:
		action.free()
		action = null
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
		job_state = JobState.GoToResource
	else:
		cancel(true)
	
func move_to_export_storage(delta: float) -> void:
	if action == null:
		action = Action_PathToTarget.new()
		action.initialize_action(pawn, export_storage.owner_module)
	action.process_action(delta)
	if action.is_failed():
		cancel(true)
	elif action.is_finished():
		job_state = JobState.GatherResource
		action.free()
		action = null
		
func gather_resource() -> void:
	if export_storage.complete_withdraw_job(self):
		job_state = JobState.ReturnWithResource
	else:
		cancel(true)
		
func move_to_import_storage(delta: float) -> void:
	if action == null:
		action = Action_PathToTarget.new()
		action.initialize_action(pawn, deposit_storage.owner_module)
	action.process_action(delta)
	if action.is_failed():
		cancel(true)
	elif action.is_finished():
		job_state = JobState.DepositResource
		action.free()
		action = null
		
func deposit_resource() -> void:
	if deposit_storage.complete_deposit_job(self):
		job_state = JobState.Finished
	else:
		cancel(true)
#
#func _job_gather() -> void:
	## temp temp temp
	#if withdraw_storage.withdraw_job(self):
		#deposit_storage.deposit_job(self)
		#job_state = JobState.Return
	
