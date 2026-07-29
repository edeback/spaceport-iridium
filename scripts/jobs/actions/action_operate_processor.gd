class_name Action_OperateProcessor
extends Action_Work

## Working a manned processor (WI-44). Everything about pushing the batch forward
## is inherited from Action_Work; the one addition is telling the processor WHO is
## operating it, which it needs at the moment a batch completes so food output
## quality can be shifted by the worker's skill (WI-29).
##
## Set every tick rather than once on entry, so it is always current on whichever
## frame the batch happens to finish.

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A) -> void:
	super(target_slot, false, 0.0)
	use_anchor_animation = true

func tick(job: Job, delta: float) -> Status:
	var processor: ProcessorComponent = _processor(job)
	if processor == null:
		return Status.FAILED
	processor.current_worker = job.pawn
	return super(job, delta)

## Drop the operator link so a stale (but still valid) pawn can't be credited to a
## later deposit. A loop into the next batch re-sets it on its first tick, before
## any batch of its own can complete.
func on_finish(job: Job, outcome: Job.Outcome) -> void:
	var processor: ProcessorComponent = _processor(job)
	if processor != null and processor.current_worker == job.pawn:
		processor.current_worker = null
	super(job, outcome)

func _processor(job: Job) -> ProcessorComponent:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_alive():
		return null
	return destination.component() as ProcessorComponent
