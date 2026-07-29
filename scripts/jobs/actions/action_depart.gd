class_name Action_Depart
extends ActionBase

## Leave the station for good (WI-44). Instant, and terminal - the pawn is gone
## when this returns.
##
## The pawn's PREDELETE handler dumps whatever it was carrying to a pile, so the
## "jobs never destroy carried resources" invariant holds even here, and it
## re-cancels this job on the way out (harmless - the job has already ended by
## then, and end() is idempotent).

func _init() -> void:
	complete_mode = CompleteMode.INSTANT

func on_start(job: Job) -> Status:
	if job.pawn == null or not is_instance_valid(job.pawn):
		return Status.FAILED
	SignalBus.crew_departed.emit(job.pawn)
	job.pawn.queue_free()
	return Status.DONE

func report(_job: Job) -> String:
	return "Departing"
