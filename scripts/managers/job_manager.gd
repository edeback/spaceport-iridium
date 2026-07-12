class_name JobManager
extends Node

# Sorted low to high prio, as high prio is often removed first
var job_board: Array[JobBase] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.job_manager = self

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	## Temp insta-run jobs
	#for index in range(job_board.size() -1, -1, -1):
		#var job: JobBase = job_board[index]
		#job.process_job(delta)
		#if !job.is_finished():
			#job_board.erase(job)
	#pass

func add_job(job_data: JobBase) -> void:
	if job_board.is_empty():
		job_board.append(job_data)
	else:
		job_board.insert(job_board.bsearch_custom(job_data, sort_priority_ascending), job_data)
	pass
	
func remove_job(job_data: JobBase) -> void:
	job_board.erase(job_data)
	pass

func find_job(pawn: PawnBase) -> JobBase:
	for index: int in range(job_board.size() - 1, -1, -1):
		var job_to_do: JobBase = job_board[index]
		# Check that the job is still possible
		if !job_to_do.is_valid():
			job_to_do.end_job()
			job_board.remove_at(index)
			continue
		if job_to_do.can_do_job(pawn):
			job_board.remove_at(index)
			return job_to_do
	return null
	
func re_sort_jobs() -> void:
	job_board.sort_custom(sort_priority_ascending)
	
#func get_job() -> JobBase:
	#return job_board.pop_back()

func sort_priority_decending(a: JobBase, b: JobBase) -> bool:
	return a.priority > b.priority

func sort_priority_ascending(a: JobBase, b: JobBase) -> bool:
	return a.priority < b.priority
