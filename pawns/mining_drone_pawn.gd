class_name MiningDronePawn
extends PawnBase

@export var drone_efficiency: float = 0.2
@export var cargo_size: float = 5

@export var powered: bool = true:
	set(new_powered):
		if powered != new_powered:
			powered = new_powered
			powered_changed(new_powered)
			



func powered_changed(new_powered: bool) -> void:
	pass


func _process(delta: float) -> void:
	if powered:
		super._process(delta)
	# Else do nothing I guess?

func give_job(new_job: JobBase) -> bool:
	if current_job == null:
		current_job = new_job
		current_job.start_job(self)
		current_job.job_end.connect(job_complete)
		if current_job is Job_MineAsteroid:
			current_job.efficiency = drone_efficiency
			current_job.max_mined = cargo_size
		return true
	return false

func job_complete() -> void:
	pass

func self_destruct() -> void:
	if current_job != null:
		current_job.cancel(true)
		current_job = null
	queue_free()
