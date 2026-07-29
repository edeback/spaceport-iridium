class_name Action_FindBestTarget
extends ActionBase

## Run a TargetFinder and write the answer into a target slot (WI-44).
##
## Instant, and normally a no-op: a job posted with both its endpoints already
## known skips straight past. It only does work for the half of a job that wasn't
## specified at post time - which is how one fixed action sequence serves both a
## "pull" haul (destination known, hunt for a source) and a "push" haul (source
## known, hunt for a destination) without the driver branching. That matters,
## because make_actions() has to be deterministic for the saved index to mean
## anything at all.

@export var finder: TargetFinder = null
@export var slot: JobTarget.Slot = JobTarget.Slot.A
## Leave an already-resolved slot alone. False = always re-run the finder.
@export var skip_if_set: bool = true
## Finding nothing is a legitimate outcome rather than a failure - the driver
## branches on whether the slot came back set. Only one job needs this (leaving
## the station falls back to an escape pod when no docking bay is reachable), and
## it is a flag rather than a second action because the alternative is a
## near-duplicate class differing in one return value.
@export var optional: bool = false

func _init(target_finder: TargetFinder = null, into_slot: JobTarget.Slot = JobTarget.Slot.A) -> void:
	finder = target_finder
	slot = into_slot
	complete_mode = CompleteMode.INSTANT

func on_start(job: Job) -> Status:
	if finder == null:
		return Status.FAILED
	var existing: JobTarget = job.target(slot)
	if skip_if_set and existing != null and existing.is_alive():
		return Status.DONE
	if job.pawn == null:
		return Status.FAILED
	var found: JobTarget = finder.find(job, job.pawn)
	if found == null or not found.is_alive():
		# Leave the slot untouched so the driver's next_index_after() can tell the
		# difference between "found nothing" and "found something".
		return Status.DONE if optional else Status.FAILED
	job.set_target(slot, found)
	return Status.DONE

func report(_job: Job) -> String:
	return "Looking for " + (finder.describe() if finder != null else "something")
