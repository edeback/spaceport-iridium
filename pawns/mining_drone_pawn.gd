class_name MiningDronePawn
extends PawnBase

@export var drone_efficiency: float = 0.2
@export var cargo_size: float = 5

@export var powered: bool = true:
	set(new_powered):
		if powered != new_powered:
			powered = new_powered
			powered_changed(new_powered)

var parent_mining_component: MiningComponent = null

func powered_changed(new_powered: bool) -> void:
	pass


func _process(delta: float) -> void:
	if powered:
		super(delta)
	
## Overrides start_job as we only want to get mining jobs, and only from our parent mining component
## Storing inventory and forced jobs are fine though, just not from the job board
func start_job() -> void:
	# If we have an inventory, try to store it ASAP
	if inventory_component != null and not inventory_component.is_empty():
		var return_job: Job_StoreInventory = Job_StoreInventory.new()
		if return_job.can_do_job(self):
			_begin_job(return_job)
			return
		# No storage will take what we're carrying right now — fall through and
		# look for a normal job anyway rather than stalling the pawn entirely.
	# Personal queue next - chained followups and queued needs. Checked once
	# here rather than polled every frame by whatever queued them.
	while not job_queue.is_empty():
		var queued_job: JobBase = job_queue.pop_front()
		if queued_job.is_valid() and queued_job.can_do_job(self):
			_begin_job(queued_job)
			return
		queued_job.cancel(true)
	if parent_mining_component:
		current_job = parent_mining_component.get_next_job(self)
	if current_job:
		current_job.start_job(self)
	else:
		# No job, idle pose
		if animated_sprite != null:
			animated_sprite.play("idle")


func self_destruct() -> void:
	if current_job != null:
		current_job.cancel(true)
		current_job = null
	queue_free()
