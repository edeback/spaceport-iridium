extends GutTest

## WI-44 action runner. This is the highest-value pure surface in the refactor:
## every job type's control flow now runs through Job's sequencer, so a bug here
## is a bug in all of them at once.
##
## Driven entirely by stub actions and a stub driver - no Global, no SignalBus,
## no pawn. The claim registry is injected so end()'s release path is exercised
## without a live world. Movement (CompleteMode.MOVEMENT) needs a real
## PawnMovementComponent and is covered by the in-game probe instead.

# --- stubs --------------------------------------------------------------------

class StubAction:
	extends ActionBase

	var start_calls: int = 0
	var resume_calls: int = 0
	var tick_calls: int = 0
	var finish_calls: int = 0
	var last_outcome: int = -1
	## What each hook reports back; tests set these before running.
	var start_status: ActionBase.Status = ActionBase.Status.ONGOING
	var tick_status: ActionBase.Status = ActionBase.Status.ONGOING
	var check_status: ActionBase.Status = ActionBase.Status.ONGOING
	var state: Dictionary = {}
	var cargo: bool = false
	## Set to end the job from inside on_start, the way a failed claim would.
	var end_job_on_start: bool = false

	func on_start(job: Job) -> ActionBase.Status:
		start_calls += 1
		if end_job_on_start:
			job.end(Job.Outcome.FAILED)
		return start_status

	func on_resume(_job: Job) -> ActionBase.Status:
		resume_calls += 1
		return start_status

	func tick(_job: Job, _delta: float) -> ActionBase.Status:
		tick_calls += 1
		return tick_status

	func check(_job: Job) -> ActionBase.Status:
		return check_status

	func on_finish(_job: Job, job_outcome: Job.Outcome) -> void:
		finish_calls += 1
		last_outcome = int(job_outcome)

	func save_state() -> Dictionary:
		return state

	func load_state(data: Dictionary) -> void:
		state = data

	func expects_cargo() -> bool:
		return cargo

	func report(_job: Job) -> String:
		return "stub " + String(label)


class StubDriver:
	extends JobDriver

	var plan: Array[ActionBase] = []
	var valid: bool = true
	## finished index -> forced next index. Absent = the default (finished + 1).
	var jumps: Dictionary[int, int] = {}
	var end_calls: int = 0

	func make_actions(_job: Job) -> Array[ActionBase]:
		return plan

	func is_valid(_job: Job) -> bool:
		return valid

	func next_index_after(_job: Job, finished: int) -> int:
		return jumps.get(finished, finished + 1)

	func on_job_end(_job: Job, _job_outcome: Job.Outcome) -> void:
		end_calls += 1


## Minimal claimable honouring the duck-typed contract in ClaimRegistry.
class FakeClaimable:
	extends RefCounted

	var taken: int = 0
	var released: int = 0

	func can_take_claim(_kind: int, _amount: int) -> bool:
		return true

	func take_claim(_kind: int, amount: int) -> Variant:
		taken += amount
		return true

	func release_claim(_kind: int, amount: int, _payload: Variant) -> void:
		released += amount

# --- fixtures -----------------------------------------------------------------

var registry: ClaimRegistry = null

func before_each() -> void:
	registry = ClaimRegistry.new()

func after_each() -> void:
	registry.free()
	registry = null

func _data(saveable: bool = true) -> JobData:
	var data := JobData.new()
	data.id = &"test_job"
	data.display_name = "Test Job"
	data.saveable = saveable
	return data

## A job wired to `actions`, with the registry injected and the driver installed
## directly (bypassing JobData.driver, which would need a real script on disk).
func _job(actions: Array[ActionBase]) -> Job:
	var job := Job.create(_data())
	job.registry = registry
	var driver := StubDriver.new()
	driver.plan = actions
	job.install_driver(driver)
	return job

func _driver_of(job: Job) -> StubDriver:
	return job.driver() as StubDriver

func _instant(action_label: StringName = &"") -> StubAction:
	var action := StubAction.new()
	action.complete_mode = ActionBase.CompleteMode.INSTANT
	action.label = action_label
	return action

func _condition(action_label: StringName = &"") -> StubAction:
	var action := StubAction.new()
	action.complete_mode = ActionBase.CompleteMode.CONDITION
	action.label = action_label
	return action

func _timed(seconds: float) -> StubAction:
	var action := StubAction.new()
	action.complete_mode = ActionBase.CompleteMode.DURATION
	action.duration = seconds
	return action

## A target pointing at a bare Object, so the freeing tests don't need a real
## module. Production code always goes through JobTarget.of_module() and friends.
func _fake_target(obj: Object) -> JobTarget:
	var slot := JobTarget.none()
	slot.kind = JobTarget.Kind.MODULE
	slot._object = obj
	return slot

# --- starting -----------------------------------------------------------------

func test_start_enters_first_action() -> void:
	var first := _condition()
	var job := _job([first] as Array[ActionBase])
	job.start_job(null)
	assert_eq(first.start_calls, 1, "first action is started once")
	assert_eq(job.action_index(), 0, "runner sits on action 0")
	assert_false(job.is_ended(), "a CONDITION action that isn't done keeps the job running")

func test_empty_action_list_fails_the_job() -> void:
	var job := _job([] as Array[ActionBase])
	job.start_job(null)
	assert_true(job.is_failed(), "a driver that produces no actions fails rather than silently succeeding")
	assert_push_error("produced no actions", "and says so loudly - this is always a driver bug")

func test_start_is_a_no_op_after_end() -> void:
	var only := _condition()
	var job := _job([only] as Array[ActionBase])
	job.end(Job.Outcome.FAILED)
	job.start_job(null)
	assert_eq(only.start_calls, 0, "an already-ended job never enters an action")

# --- completion modes ---------------------------------------------------------

func test_instant_action_chains_to_the_next() -> void:
	var first := _instant()
	var second := _condition()
	var job := _job([first, second] as Array[ActionBase])
	job.start_job(null)
	assert_eq(first.finish_calls, 1, "the instant action finished immediately")
	assert_eq(second.start_calls, 1, "and the runner chained straight into the next")
	assert_eq(job.action_index(), 1, "settled on the non-instant action")

func test_all_instant_sequence_succeeds_without_a_tick() -> void:
	var job := _job([_instant(), _instant(), _instant()] as Array[ActionBase])
	job.start_job(null)
	assert_true(job.is_finished(), "running off the end of the list is success")

func test_duration_action_completes_when_elapsed_reaches_duration() -> void:
	var timed := _timed(2.0)
	var after := _condition()
	var job := _job([timed, after] as Array[ActionBase])
	job.start_job(null)
	job.process_job(1.0)
	assert_eq(job.action_index(), 0, "still running below the duration")
	job.process_job(1.0)
	assert_eq(job.action_index(), 1, "advances on the frame elapsed crosses the duration")

func test_condition_action_completes_when_check_says_done() -> void:
	var gated := _condition()
	var after := _condition()
	var job := _job([gated, after] as Array[ActionBase])
	job.start_job(null)
	job.process_job(0.5)
	assert_eq(job.action_index(), 0, "check() still ONGOING")
	gated.check_status = ActionBase.Status.DONE
	job.process_job(0.5)
	assert_eq(job.action_index(), 1, "advances once check() reports DONE")

func test_tick_runs_before_the_completion_check() -> void:
	# Progress accumulated this frame has to count toward finishing this frame,
	# or every timed action silently costs one extra frame.
	var action := _condition()
	var job := _job([action] as Array[ActionBase])
	job.start_job(null)
	job.process_job(0.1)
	assert_eq(action.tick_calls, 1, "tick ran")
	action.tick_status = ActionBase.Status.DONE
	job.process_job(0.1)
	assert_true(job.is_finished(), "DONE from tick ends the job on the same frame")

# --- statuses -----------------------------------------------------------------

func test_on_start_returning_done_skips_the_action() -> void:
	# The "already carrying this, move on" early-out that makes resume cheap.
	var skipped := _condition()
	skipped.start_status = ActionBase.Status.DONE
	var after := _condition()
	var job := _job([skipped, after] as Array[ActionBase])
	job.start_job(null)
	assert_eq(skipped.finish_calls, 1, "the skipped action still gets its on_finish")
	assert_eq(job.action_index(), 1, "and the runner moves on")

func test_on_start_returning_failed_fails_the_job() -> void:
	var bad := _condition()
	bad.start_status = ActionBase.Status.FAILED
	var job := _job([bad, _condition()] as Array[ActionBase])
	job.start_job(null)
	assert_true(job.is_failed(), "a failed entry fails the whole job")

func test_tick_returning_failed_fails_the_job() -> void:
	var action := _condition()
	var job := _job([action] as Array[ActionBase])
	job.start_job(null)
	action.tick_status = ActionBase.Status.FAILED
	job.process_job(0.1)
	assert_true(job.is_failed(), "FAILED from tick fails the job")

func test_action_can_end_the_job_from_on_start() -> void:
	# A claim action that can't get its slot ends the job inside on_start; the
	# runner must not then carry on entering actions.
	var ender := _condition()
	ender.end_job_on_start = true
	var never := _condition()
	var job := _job([ender, never] as Array[ActionBase])
	job.start_job(null)
	assert_true(job.is_failed(), "the job ended as the action asked")
	assert_eq(never.start_calls, 0, "and the runner stopped rather than advancing")

# --- control flow -------------------------------------------------------------

func test_index_of_label_finds_the_labelled_action() -> void:
	var job := _job([_condition(&"first"), _condition(&"loop"), _condition()] as Array[ActionBase])
	job.start_job(null)
	assert_eq(job.index_of_label(&"loop"), 1, "label resolves to its index")
	assert_eq(job.index_of_label(&"nope"), -1, "an unknown label is -1")

func test_next_index_after_can_jump_backwards_to_loop() -> void:
	# The mine -> not full? -> mine again shape, without lambdas.
	var work := _condition()
	var done := _condition()
	var job := _job([work, done] as Array[ActionBase])
	_driver_of(job).jumps[0] = 0  # finishing action 0 re-enters action 0
	job.start_job(null)
	work.check_status = ActionBase.Status.DONE
	job.process_job(0.1)
	assert_eq(job.action_index(), 0, "looped back onto itself")
	assert_eq(work.start_calls, 2, "and re-entered, so on_start ran again")
	assert_eq(done.start_calls, 0, "without falling through to the next action")

func test_next_index_past_the_end_succeeds() -> void:
	var only := _condition()
	var job := _job([only] as Array[ActionBase])
	_driver_of(job).jumps[0] = 99
	job.start_job(null)
	only.check_status = ActionBase.Status.DONE
	job.process_job(0.1)
	assert_true(job.is_finished(), "an out-of-range next index ends the job successfully")

func test_runaway_instant_chain_is_caught() -> void:
	# A driver that loops instant actions forever must fail loudly, not hang.
	var job := _job([_instant(), _instant()] as Array[ActionBase])
	_driver_of(job).jumps[0] = 1
	_driver_of(job).jumps[1] = 0
	job.start_job(null)
	assert_true(job.is_failed(), "the chain guard fails the job instead of hanging")
	assert_push_error("instant actions", "and names the runaway so the driver can be found")

# --- termination --------------------------------------------------------------

func test_end_is_idempotent_and_emits_once() -> void:
	var job := _job([_condition()] as Array[ActionBase])
	job.start_job(null)
	var ends: Array[int] = []
	job.job_end.connect(func() -> void: ends.append(1))
	job.end(Job.Outcome.SUCCEEDED)
	job.end(Job.Outcome.FAILED)
	assert_eq(ends.size(), 1, "job_end fires exactly once")
	assert_true(job.is_finished(), "and the first outcome is the one that sticks")

func test_end_finishes_the_current_action_with_the_terminal_outcome() -> void:
	var action := _condition()
	var job := _job([action] as Array[ActionBase])
	job.start_job(null)
	job.end(Job.Outcome.INTERRUPTED)
	assert_eq(action.finish_calls, 1, "current action is finished exactly once")
	assert_eq(action.last_outcome, int(Job.Outcome.INTERRUPTED), "and told how the job ended")

func test_cancel_maps_to_failed_and_interrupted() -> void:
	var failed := _job([_condition()] as Array[ActionBase])
	failed.start_job(null)
	failed.cancel(true)
	assert_true(failed.is_failed(), "cancel(true) is a failure")

	var graceful := _job([_condition()] as Array[ActionBase])
	graceful.start_job(null)
	graceful.cancel(false)
	assert_false(graceful.is_failed(), "cancel(false) is not a failure")
	assert_eq(graceful.outcome(), Job.Outcome.INTERRUPTED, "it is an interruption")

func test_process_after_end_does_nothing() -> void:
	var action := _condition()
	var job := _job([action] as Array[ActionBase])
	job.start_job(null)
	job.end(Job.Outcome.SUCCEEDED)
	var ticks_at_end: int = action.tick_calls
	job.process_job(1.0)
	assert_eq(action.tick_calls, ticks_at_end, "an ended job is inert")

func test_driver_is_told_the_job_ended() -> void:
	var job := _job([_condition()] as Array[ActionBase])
	var driver := _driver_of(job)
	job.start_job(null)
	job.end(Job.Outcome.SUCCEEDED)
	assert_eq(driver.end_calls, 1, "driver.on_job_end runs once")

# --- global fail conditions ---------------------------------------------------

func test_driver_going_invalid_fails_the_job() -> void:
	var job := _job([_condition()] as Array[ActionBase])
	job.start_job(null)
	_driver_of(job).valid = false
	job.process_job(0.1)
	assert_true(job.is_failed(), "is_valid() false fails the job on the next frame")

func test_losing_a_hard_target_fails_the_job() -> void:
	# The declarative replacement for eleven hand-wired module_removed handlers.
	var doomed := Object.new()
	var job := _job([_condition()] as Array[ActionBase])
	job.target_a = _fake_target(doomed)
	job.start_job(null)
	job.process_job(0.1)
	assert_false(job.is_ended(), "alive target, job runs")
	doomed.free()
	job.process_job(0.1)
	assert_true(job.is_failed(), "target freed -> job fails without any per-job wiring")

func test_losing_a_soft_target_does_not_fail_the_job() -> void:
	var doomed := Object.new()
	var job := _job([_condition()] as Array[ActionBase])
	job.target_b = _fake_target(doomed)
	job.target_b.fail_on_lost = false
	job.start_job(null)
	doomed.free()
	job.process_job(0.1)
	assert_false(job.is_ended(), "a target the job can outlive doesn't end it")

# --- claims -------------------------------------------------------------------

func test_ending_releases_every_claim() -> void:
	# The structural version of "release on EVERY termination path".
	var bed := FakeClaimable.new()
	var bin := FakeClaimable.new()
	var job := _job([_condition()] as Array[ActionBase])
	job.start_job(null)
	job.claim(bed, ClaimSpec.Kind.SLOT, 1)
	job.claim(bin, ClaimSpec.Kind.STORAGE_DEPOSIT, 12)
	assert_eq(registry.claims_of(job).size(), 2, "both claims recorded")
	job.end(Job.Outcome.FAILED)
	assert_eq(bed.released, 1, "the slot went back")
	assert_eq(bin.released, 12, "and so did the full reserved amount")
	assert_eq(registry.claims_of(job).size(), 0, "ledger is clean after the job ends")

func test_claims_are_released_even_when_the_job_fails_mid_action() -> void:
	var bed := FakeClaimable.new()
	var action := _condition()
	var job := _job([action] as Array[ActionBase])
	job.start_job(null)
	job.claim(bed, ClaimSpec.Kind.SLOT, 1)
	action.tick_status = ActionBase.Status.FAILED
	job.process_job(0.1)
	assert_eq(bed.released, 1, "a failure path releases like every other path")

# --- reporting ----------------------------------------------------------------

func test_report_substitutes_count_and_falls_back_to_display_name() -> void:
	var job := _job([_condition()] as Array[ActionBase])
	job.count = 7
	job.data.report_template = "Hauling {count} units"
	assert_eq(job.report(), "Hauling 7 units", "placeholders are filled from the job")
	job.data.report_template = ""
	assert_eq(job.report(), "Test Job", "an empty template falls back to display_name")

func test_subtask_report_comes_from_the_current_action() -> void:
	var job := _job([_condition(&"walk"), _condition(&"work")] as Array[ActionBase])
	job.start_job(null)
	assert_eq(job.subtask_report(), "stub walk", "reads the action the runner is on")

func test_expects_cargo_delegates_to_the_current_action() -> void:
	var carrying := _condition()
	carrying.cargo = true
	var job := _job([_condition(), carrying] as Array[ActionBase])
	_driver_of(job).jumps[0] = 1
	job.start_job(null)
	assert_false(job.expects_cargo(), "the first action doesn't need cargo")
	job.process_job(0.1)
	assert_false(job.expects_cargo(), "still on action 0")
	(job.current_action() as StubAction).check_status = ActionBase.Status.DONE
	job.process_job(0.1)
	assert_true(job.expects_cargo(), "the cargo-holding action reports through the job")

# --- subtask signal -----------------------------------------------------------

func test_subtask_changed_fires_when_the_runner_settles_on_an_action() -> void:
	var first := _condition()
	var second := _condition()
	var job := _job([first, second] as Array[ActionBase])
	var changes: Array[int] = []
	job.subtask_changed.connect(func() -> void: changes.append(job.action_index()))
	job.start_job(null)
	first.check_status = ActionBase.Status.DONE
	job.process_job(0.1)
	assert_eq(changes, [0, 1] as Array[int], "one emission per settled action, in order")

func test_chained_instant_actions_do_not_emit_intermediate_subtasks() -> void:
	# Instant steps flash past within one frame; emitting for each would make the
	# UI strobe through text nobody can read.
	var job := _job([_instant(), _instant(), _condition()] as Array[ActionBase])
	var changes: Array[int] = []
	job.subtask_changed.connect(func() -> void: changes.append(job.action_index()))
	job.start_job(null)
	assert_eq(changes, [2] as Array[int], "only the action the runner settles on emits")
