extends GutTest

## JobSlot (WI-70 §2): the one contract eleven job owners used to hand-roll.
##
## Pure - jobs are built from a bare JobData with the claim registry injected, the
## way test_job_runner.gd drives the runner. What each owner does with the handler
## is covered by the integration suite; this pins the contract they all share.

class Recorder:
	extends RefCounted

	var calls: Array[Dictionary] = []
	## Read inside the handler, to prove the slot let go before calling it.
	var slot: JobSlot = null
	## Posted from inside the handler, the way a re-posting owner does.
	var repost: Job = null

	func on_end(job: Job, completed: bool) -> void:
		calls.append({"job": job, "completed": completed,
			"held_during_handler": slot.job() if slot != null else null})
		if repost != null and slot != null:
			slot.post(repost)

## Posts into a slot from inside a job's own end(), after the job is marked ended
## and before its job_end fires - the one window in which a held job is "not
## live" but still connected.
class PostOnFinish:
	extends ActionBase

	var slot: JobSlot = null
	var replacement: Job = null

	func _init() -> void:
		# Holds until end(): nothing ticks the job in this suite.
		complete_mode = CompleteMode.DURATION
		duration = 60.0

	func on_finish(_job: Job, _outcome: Job.Outcome) -> void:
		slot.post(replacement)

class OneActionDriver:
	extends JobDriver

	var action: ActionBase = null

	func make_actions(_job: Job) -> Array[ActionBase]:
		return [action] as Array[ActionBase]

var registry: ClaimRegistry = null

func before_each() -> void:
	registry = ClaimRegistry.new()

func after_each() -> void:
	registry.free()
	registry = null

func _job() -> Job:
	var data := JobData.new()
	data.id = &"test_job"
	var job := Job.create(data)
	job.registry = registry
	return job

func _slot_with(recorder: Recorder) -> JobSlot:
	var slot := JobSlot.new(recorder.on_end)
	recorder.slot = slot
	return slot

# --- post ---------------------------------------------------------------------

func test_an_empty_slot_holds_what_is_posted() -> void:
	var slot := JobSlot.new()
	var job: Job = _job()
	assert_false(slot.is_live(), "a fresh slot holds nothing")
	assert_null(slot.job())
	assert_eq(slot.post(job), job, "post returns the job it took")
	assert_true(slot.is_live())
	assert_eq(slot.job(), job)

func test_post_refuses_while_a_job_is_live() -> void:
	var slot := JobSlot.new()
	var first: Job = _job()
	var second: Job = _job()
	slot.post(first)
	assert_eq(slot.post(second), first, "refused, and the live job comes back instead")
	assert_eq(slot.job(), first, "an owner can never silently replace a running job")

func test_post_takes_a_new_job_once_the_old_one_ended() -> void:
	var slot := JobSlot.new()
	var first: Job = _job()
	slot.post(first)
	first.end(Job.Outcome.SUCCEEDED)
	assert_false(slot.is_live(), "an ended job is not live")
	assert_null(slot.job(), "and job() does not hand it out")
	var second: Job = _job()
	assert_eq(slot.post(second), second)
	assert_eq(slot.job(), second)

# --- adopt --------------------------------------------------------------------

func test_adopt_takes_a_restored_job_into_an_empty_slot() -> void:
	var slot := JobSlot.new()
	var restored: Job = _job()
	assert_true(slot.adopt(restored))
	assert_eq(slot.job(), restored)

func test_adopt_refuses_while_live() -> void:
	# F2's old-save artefact: two restored jobs for one owner. The second runs once
	# as an orphan rather than displacing the first.
	var slot := JobSlot.new()
	var first: Job = _job()
	slot.adopt(first)
	assert_false(slot.adopt(_job()), "refused")
	assert_eq(slot.job(), first, "the first is kept")

func test_adopt_refuses_an_ended_job_and_null() -> void:
	var slot := JobSlot.new()
	var ended: Job = _job()
	ended.end(Job.Outcome.FAILED)
	assert_false(slot.adopt(ended), "an ended job is nobody's to hold")
	assert_false(slot.adopt(null))
	assert_false(slot.is_live())

# --- clear_if -----------------------------------------------------------------

func test_clear_if_ignores_a_job_that_is_not_held() -> void:
	var recorder := Recorder.new()
	var slot: JobSlot = _slot_with(recorder)
	var held: Job = _job()
	slot.post(held)
	assert_false(slot.clear_if(_job()), "a stale job cannot clear the slot (F2)")
	assert_false(slot.clear_if(null), "nor can no job at all (a cheat flip)")
	assert_eq(slot.job(), held)

func test_clear_if_lets_go_of_the_held_job_without_the_handler() -> void:
	var recorder := Recorder.new()
	var slot: JobSlot = _slot_with(recorder)
	var held: Job = _job()
	slot.post(held)
	assert_true(slot.clear_if(held))
	assert_false(slot.is_live())
	held.end(Job.Outcome.SUCCEEDED)
	assert_eq(recorder.calls.size(), 0, "a job the owner let go of reports to nobody")

# --- the handler --------------------------------------------------------------

func test_the_handler_hears_success_as_completed() -> void:
	_assert_handler_flag(Job.Outcome.SUCCEEDED, true)

func test_the_handler_hears_failure_as_not_completed() -> void:
	_assert_handler_flag(Job.Outcome.FAILED, false)

func test_the_handler_hears_an_interruption_as_not_completed() -> void:
	# F25 in one line: an interrupted builder is not a failed one, and the owner
	# that only asked is_failed() never re-posted.
	_assert_handler_flag(Job.Outcome.INTERRUPTED, false)

func _assert_handler_flag(outcome: Job.Outcome, completed: bool) -> void:
	var recorder := Recorder.new()
	var slot: JobSlot = _slot_with(recorder)
	var job: Job = _job()
	slot.post(job)
	job.end(outcome)
	assert_eq(recorder.calls.size(), 1, "the handler runs once")
	if recorder.calls.is_empty():
		return
	assert_eq(recorder.calls[0]["job"], job, "and is told which job ended")
	assert_eq(recorder.calls[0]["completed"], completed,
		"%s reads as completed = %s" % [Job.Outcome.keys()[outcome], completed])
	assert_false(slot.is_live(), "the slot is empty afterwards")

func test_the_slot_is_empty_while_the_handler_runs_so_a_repost_is_taken() -> void:
	var recorder := Recorder.new()
	var slot: JobSlot = _slot_with(recorder)
	var first: Job = _job()
	var replacement: Job = _job()
	recorder.repost = replacement
	slot.post(first)
	first.end(Job.Outcome.INTERRUPTED)
	assert_null(recorder.calls[0]["held_during_handler"], "let go before the handler")
	assert_eq(slot.job(), replacement, "so the handler's re-post is held")
	replacement.end(Job.Outcome.SUCCEEDED)
	assert_eq(recorder.calls.size(), 2, "and the replacement reports in its turn")

func test_a_post_inside_the_old_jobs_end_is_not_cleared_by_its_emit() -> void:
	# Between end() marking a job ended and job_end firing, the job is not live but
	# is still connected. A post in that window must disconnect it, or its emit
	# would clear the job that replaced it.
	var recorder := Recorder.new()
	var slot: JobSlot = _slot_with(recorder)
	var first: Job = _job()
	var replacement: Job = _job()
	var action := PostOnFinish.new()
	action.slot = slot
	action.replacement = replacement
	var driver := OneActionDriver.new()
	driver.action = action
	first.install_driver(driver)
	slot.post(first)
	first.start_job(null)
	first.end(Job.Outcome.FAILED)
	assert_eq(slot.job(), replacement, "the replacement survives the old job's emit")
	assert_eq(recorder.calls.size(), 0, "and the superseded job reports to nobody")

# --- cancel_live --------------------------------------------------------------

func test_cancel_live_ends_the_job_without_the_handler() -> void:
	var recorder := Recorder.new()
	var slot: JobSlot = _slot_with(recorder)
	var job: Job = _job()
	slot.post(job)
	assert_eq(slot.cancel_live(), job, "returns what it cancelled, for the board")
	assert_true(job.is_failed(), "cancelled as failed by default")
	assert_false(slot.is_live())
	assert_eq(recorder.calls.size(), 0, "the owner ended it and has nothing to learn")

func test_cancel_live_can_interrupt() -> void:
	var slot := JobSlot.new()
	var job: Job = _job()
	slot.post(job)
	slot.cancel_live(false)
	assert_eq(job.outcome(), Job.Outcome.INTERRUPTED)

func test_cancel_live_on_an_empty_slot_is_a_no_op() -> void:
	var slot := JobSlot.new()
	assert_null(slot.cancel_live())

# --- what it keeps alive (WI-70 §6) -------------------------------------------

func test_a_slot_holding_an_ended_job_keeps_nothing_alive() -> void:
	var slot := JobSlot.new()
	var job: Job = _job()
	var watch: WeakRef = weakref(job)
	slot.post(job)
	job.end(Job.Outcome.SUCCEEDED)
	job = null
	assert_null(watch.get_ref(), "the ended job is freed with the slot still standing")
	assert_false(slot.is_live())

func test_a_job_does_not_keep_its_slot_alive() -> void:
	var job: Job = _job()
	var slot := JobSlot.new()
	var watch: WeakRef = weakref(slot)
	slot.post(job)
	slot = null
	assert_null(watch.get_ref(), "the connection holds an ObjectID, not a reference")
	job.end(Job.Outcome.FAILED)
	pass_test("ending a job whose slot is gone is harmless")

func test_a_waiting_job_goes_with_its_slot() -> void:
	# The shape of §6's leak. A job still waiting on the board at teardown is held
	# by the board and by its owner's slot; once both let go it must be freed.
	var slot := JobSlot.new()
	var job: Job = _job()
	var watch: WeakRef = weakref(job)
	slot.post(job)
	job = null
	slot = null
	assert_null(watch.get_ref(), "no cycle between a live job and its slot")

func test_a_bound_handler_is_the_cycle_the_slot_removes() -> void:
	# The pattern JobSlot replaced, measured: a handler bound to its own job puts a
	# strong reference to the job inside a connection the job holds.
	var job: Job = _job()
	var watch: WeakRef = weakref(job)
	job.job_end.connect(_ignore.bind(job), CONNECT_ONE_SHOT)
	job = null
	var leaked: Job = watch.get_ref() as Job
	assert_not_null(leaked, "the job keeps itself alive until job_end fires")
	# Break the cycle so the suite doesn't leak what it just proved.
	if leaked != null:
		leaked.end(Job.Outcome.SUCCEEDED)

func _ignore(_job_arg: Job) -> void:
	pass
