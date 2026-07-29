class_name JobDriver_Wait
extends JobDriver

## "Stay put and look busy" (WI-44) - the replacement for the wait job. Used by the
## ARC inspector while dwelling at a checklist module (WI-26).
##
## The wait length rides on job.count (whole sim-seconds) rather than a field on
## the driver, so it round-trips through the generic save format without the
## driver needing any state of its own - which is also what keeps make_actions()
## deterministic across a load.

const DEFAULT_SECONDS: float = 10.0

func make_actions(job: Job) -> Array[ActionBase]:
	var seconds: float = float(job.count) if job.count > 0 else DEFAULT_SECONDS
	return [Action_Wait.new(seconds)] as Array[ActionBase]
