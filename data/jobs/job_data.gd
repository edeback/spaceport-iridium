class_name JobData
extends Resource

@export var name: String = ""
@export var description: String = ""
@export var resource_data: ResourceData
@export var amount: float = 1.0

var origin: Vector2i
var destination: Vector2i
var requester: Node
var worker: PawnBase
var priority: int = 0

var withdraw_storage: MultiStorageComponent
var deposit_storage: MultiStorageComponent

enum JobState { Start, Gather, Return }
var job_state: JobState = JobState.Start

func process_job() -> void:
	match job_state:
		JobState.Start:
			_job_start()
			pass
		JobState.Gather:
			_job_gather()
			pass
		JobState.Return:
			pass
			
func is_finished() -> bool:
	return job_state == JobState.Return
	
func cancel() -> void:
	job_state = JobState.Return
	pass
			
func _job_start() -> void:
	var min_distance: int = 0
	var storage_component: MultiStorageComponent = null
	var storage_nodes: Array[Node] = requester.get_tree().get_nodes_in_group("resource_storage")
	for node in storage_nodes:
		var storage: MultiStorageComponent = node as MultiStorageComponent
		if storage.accepts_exports and storage.stored_resources.has(resource_data) and storage.priority < deposit_storage.priority and storage.can_withdraw(resource_data, amount):
			storage_component = storage
			break
			#var new_distance = storage.owner_module.module_cell.distance_squared_to(worker.cell)
			#if storage_component ==  null or new_distance < min_distance:
			#	storage_component = storage
			#	min_distance = new_distance
	if storage_component != null:
		destination = storage_component.owner_module.module_cell
		withdraw_storage = storage_component
		withdraw_storage.export_jobs.append(self)
		deposit_storage.import_jobs.append(self)
		job_state = JobState.Gather
	pass

func _job_gather() -> void:
	# temp temp temp
	if withdraw_storage.withdraw_job(self):
		deposit_storage.deposit_job(self)
		job_state = JobState.Return
	
