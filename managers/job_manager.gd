class_name JobManager
extends Node

var job_board: Array[JobData] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.job_manager = self
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func add_job(module: ModuleBase, job_data: JobData) -> void:
	job_board.insert(job_board.bsearch_custom(job_data.priority, sort_priority_decending), job_data)
	pass
	
func remove_job(job_data: JobData) -> void:
	job_board.erase(job_data)
	pass

func find_job() -> JobData:
	if job_board.size() > 0:
		return job_board.front()
	return null

func sort_priority_decending(a: JobData, b: JobData) -> bool:
	return a.priority > b.priority
