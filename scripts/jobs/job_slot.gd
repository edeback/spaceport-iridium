class_name JobSlot
extends RefCounted

## One job that an owner posted and remembers, so it never posts a second
## (WI-70).
##
## Eleven components used to hand-roll this: keep a pointer, clear it when the job
## ends, re-post if the job didn't finish, and re-link to the restored job after a
## load. The eleven copies disagreed, and three got it wrong. F25 was a site that
## re-posted only on FAILED and so never on INTERRUPTED. F26 was every module-side
## owner forgetting its job across a load. F2 was a stale job clearing the pointer
## of the one that replaced it. This is the contract written once.
##
## ## What it guarantees
##
## - **Never two.** [method post] and [method adopt] refuse while a live job is
##   held, so an owner cannot silently replace a running job.
## - **Only the held job clears the slot.** The end handler reads the job from the
##   slot rather than from a bound argument, and [method clear_if] ignores any job
##   that isn't the held one, which is F2's rule made general.
## - **The handler learns how it ended.** `on_end(job, completed)`, where
##   `completed` is false for FAILED *and* INTERRUPTED. "It didn't finish, so
##   re-post" is the question every owner asks, and asking `is_failed()` instead is
##   how F25 happened.
##
## ## Why no `.bind(job)`
##
## The slot connects the job's `job_end` to its own unbound [method _on_job_end].
## A Callable to a method holds an ObjectID, not a reference, so the job does not
## keep the slot alive, and freeing the slot drops the connection. The
## `job.job_end.connect(handler.bind(job))` this replaces put a strong reference
## to the job inside a connection the job itself holds: a cycle until the signal
## fired, and a leak for every job still waiting on the board at teardown (§6).
##
## Pure: no Global, no scene tree. What an owner does when its job ends -
## re-post, reset a state, raise an alert - stays in the owner's handler.

## The held job, live or not yet let go. Null when nothing is held.
var _job: Job = null
## `func(job: Job, completed: bool)`, or an empty Callable for an owner that only
## needs the pointer cleared.
var _on_end: Callable

func _init(on_end: Callable = Callable()) -> void:
	_on_end = on_end

## The held job while it is live, else null.
func job() -> Job:
	return _job if is_live() else null

## Held and not ended.
func is_live() -> bool:
	return _job != null and not _job.is_ended()

## Holds `new_job` if nothing live is held and returns it. If a live job is
## already held, refuses and returns *that* one instead, so a caller can tell
## the two apart by comparing: `if slot.post(job) == job: board.add_job(job)`.
func post(new_job: Job) -> Job:
	if is_live() or new_job == null:
		return job()
	_hold(new_job)
	return new_job

## The restore path: a job rebuilt from a save, offered back to the owner that
## posted it. Same rule as [method post], plus an ended job is never adopted.
## Returns whether it was taken. A second restored job for the same owner (a save
## written by a build with F2's bug) is refused and runs once as an orphan.
func adopt(restored: Job) -> bool:
	if is_live() or restored == null or restored.is_ended():
		return false
	_hold(restored)
	return true

## Lets go of `candidate` if it is the held job, without calling the handler.
## Returns whether it was. A stale job asking to clear the slot is ignored, which
## is the whole of WI-68's F2 fix.
func clear_if(candidate: Job) -> bool:
	if candidate == null or candidate != _job:
		return false
	_release()
	return true

## Ends the held job, if it is live, **without** calling the handler: the owner is
## the one ending it and has nothing to learn. Lets go first, because ending a job
## releases its claims, and a claim release can re-enter the owner. Returns the
## cancelled job, so the caller can take it off the board, or null.
func cancel_live(as_failed: bool = true) -> Job:
	var held: Job = job()
	_release()
	if held != null:
		held.cancel(as_failed)
	return held

func _hold(new_job: Job) -> void:
	# A held job that has ended but not yet emitted (a post from inside the old
	# job's own end(), before its job_end fires) must not stay connected, or its
	# emit would clear the job that replaced it.
	_release()
	_job = new_job
	_job.job_end.connect(_on_job_end, CONNECT_ONE_SHOT)

func _release() -> void:
	if _job != null and _job.job_end.is_connected(_on_job_end):
		_job.job_end.disconnect(_on_job_end)
	_job = null

func _on_job_end() -> void:
	var ended: Job = _job
	# Cleared before the handler runs, so a handler that re-posts is accepted.
	_job = null
	if ended != null and _on_end.is_valid():
		_on_end.call(ended, ended.is_finished())
