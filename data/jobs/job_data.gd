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

enum JobState { Start, Gather, Return }
var job_state: JobState = JobState.Start

func process_job() -> void:
	match job_state:
		JobState.Start:
			job_state = JobState.Gather
			pass
		JobState.Gather:
			_job_gather()
			pass
		JobState.Return:
			pass
			
func _job_gather() -> void:
	var min_distance: int = 0
	var storage_component: MultiStorageComponent = null
	var storage_nodes = worker.get_tree().get_nodes_in_group("resource_storage")
	for node in storage_nodes:
		var storage = node as MultiStorageComponent
		if storage.accepts_exports and storage.stored_resources.has(resource_data) and storage.can_withdraw(resource_data, amount):
			var new_distance = storage_component.owner_module.module_cell.distance_squared_to(worker.cell)
			if storage_component ==  null or new_distance < min_distance:
				storage_component = storage
				min_distance = new_distance
	if storage_component != null:
		destination = storage_component.owner_module.module_cell
	pass
