class_name Action_QueueFollowup
extends ActionBase

## Hand the pawn straight into work the delivery just unblocked (WI-44). Instant.
##
## This is the race-free half of `get_followup_job()`. A construction site that
## has only just received its last material would otherwise post to the shared
## board and wait for `_process()` to notice next frame, by which time the pawn
## standing right there has wandered off and someone across the station may claim
## it. Resolving it HERE - synchronously, inside the job that caused the
## condition - is what the pre-WI-44 comment on `JobBase.get_followup_job()`
## insisted on, and node `_process` order between the two components still isn't
## guaranteed, so the reasoning survives the refactor intact.
##
## Finding nothing is the normal case and is DONE, not FAILED: most deliveries
## unblock nothing at all.

@export var slot: JobTarget.Slot = JobTarget.Slot.B

func _init(destination_slot: JobTarget.Slot = JobTarget.Slot.B) -> void:
	slot = destination_slot
	complete_mode = CompleteMode.INSTANT

func on_start(job: Job) -> Status:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_alive() or job.pawn == null:
		return Status.DONE
	var module: ModuleBase = destination.module()
	if module == null:
		return Status.DONE
	for component: ComponentBase in module.components:
		var offered: Job = component.offer_followup_job(job.pawn)
		if offered == null:
			continue
		if offered.can_do_job(job.pawn):
			# Front of the personal queue, not the board: the whole point is that
			# this pawn gets it.
			job.pawn.queue_job(offered, true)
		else:
			offered.cancel(true)
		return Status.DONE
	return Status.DONE

## A restored job resuming on this step has already delivered; re-offering would
## queue a second copy of work the site may already have posted.
func on_resume(_job: Job) -> Status:
	return Status.DONE

func report(_job: Job) -> String:
	return ""
