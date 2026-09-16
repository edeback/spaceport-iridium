class_name Action_ChangeSuit
extends ActionBase

## Get into (or out of) a pressure suit, standing in an airlock (WI-67).
##
## The last step of the change_suit job. Everything before it is the walk; this is
## the few seconds at the rack and the flip itself.
##
## ## Two contracts this action has to honour
##
## **The flip must not happen twice.** ActionBase's most important rule is that an
## on_start() which changes the world needs an on_resume() that verifies rather
## than repeats. The flip is recorded in save_state(), so a save landing inside
## the change comes back already-changed and finishes immediately instead of
## toggling a suit a second time.
##
## **It re-checks at the moment of the flip.** Conditions turn during a walk. A
## pawn who set out for a habitable airlock and arrives at a vented one must keep
## the suit on - and tell the component, so the retry is throttled rather than
## re-posted every tick.

## True = putting the suit on, false = taking it off.
@export var putting_on: bool = true
@export var slot: JobTarget.Slot = JobTarget.Slot.A

## Set once the suit has actually changed, so a resumed action does not repeat it.
var _changed: bool = false

func _init(on: bool = true, airlock_slot: JobTarget.Slot = JobTarget.Slot.A,
		seconds: float = 6.0) -> void:
	putting_on = on
	slot = airlock_slot
	duration = seconds
	complete_mode = CompleteMode.DURATION
	animation = &"interact"

func on_start(job: Job) -> Status:
	var suit: PawnSuitComponent = _suit(job)
	if suit == null:
		return Status.FAILED
	# Taking a suit off is the only direction that can be refused: the airlock has
	# to still be fit to stand in unsuited.
	if not putting_on and not _airlock_is_fit(job):
		suit.trip_refused()
		return Status.FAILED
	return Status.ONGOING

## Already changed before the save? Then the wait is all that is left, and even
## that can be skipped - the world change this action exists for has happened.
func on_resume(job: Job) -> Status:
	if _changed:
		return Status.DONE
	return on_start(job)

## The flip lands in on_finish rather than here, and only on the SUCCEEDED path:
## on_finish runs on every termination, and a change cancelled halfway must leave
## the pawn wearing what they arrived in.
func on_finish(job: Job, outcome: Job.Outcome) -> void:
	if _changed or outcome != Job.Outcome.SUCCEEDED:
		return
	var suit: PawnSuitComponent = _suit(job)
	if suit == null:
		return
	if not putting_on and not _airlock_is_fit(job):
		suit.trip_refused()
		return
	_changed = true
	suit.apply_change(putting_on)

func report(_job: Job) -> String:
	return "Putting on a suit" if putting_on else "Taking off a suit"

func save_state() -> Dictionary:
	return {"changed": _changed}

func load_state(data: Dictionary) -> void:
	_changed = bool(data.get("changed", false))

func _suit(job: Job) -> PawnSuitComponent:
	if job.pawn == null:
		return null
	return job.pawn.get_component_by_type(PawnSuitComponent) as PawnSuitComponent

func _airlock_is_fit(job: Job) -> bool:
	var target: JobTarget = job.target(slot)
	if target == null or not target.is_alive() or job.pawn == null:
		return false
	return Finder_Airlock.is_habitable(job.pawn, target.module())
