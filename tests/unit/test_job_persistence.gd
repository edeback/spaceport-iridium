extends GutTest

## WI-44 generic job persistence. Before this, seventeen job types each wrote
## their own get_save_data()/restore() pair; now there is exactly one, so this is
## the suite that has to hold it up.
##
## What's covered here is everything that decides WHERE a restored job resumes:
## the action index, the signature guard, per-action state, DURATION progress,
## and the claim re-acquisition that makes "reservations are never saved" safe.
##
## Target REF RESOLUTION (module/component/pawn/asteroid/pile) needs Global and a
## live world, so it belongs to the in-game probe. Target ENCODING is pure and is
## covered here through CELL targets, which round-trip entirely in memory.

class StubAction:
	extends ActionBase

	## Name reported to the signature, so tests can change a sequence's shape.
	var stub_name: String = "stub"
	var resume_calls: int = 0
	var start_calls: int = 0
	var state: Dictionary = {}

	func action_name() -> String:
		return stub_name

	func on_start(_job: Job) -> ActionBase.Status:
		start_calls += 1
		return ActionBase.Status.ONGOING

	func on_resume(_job: Job) -> ActionBase.Status:
		resume_calls += 1
		return ActionBase.Status.ONGOING

	func save_state() -> Dictionary:
		return state

	func load_state(data: Dictionary) -> void:
		state = data


class StubDriver:
	extends JobDriver

	## Names of the actions to build, in order. Restore builds a driver through
	## install_driver, so tests control both the saving and the loading shape.
	var plan_names: PackedStringArray = ["walk", "work"]
	var claims_at: Dictionary[int, Array] = {}
	## What the board's pickup gate answers.
	var claimable: bool = true
	## What is_valid() answers.
	var valid: bool = true

	func can_do(_job: Job, _pawn: PawnBase) -> bool:
		return claimable

	func is_valid(_job: Job) -> bool:
		return valid

	func make_actions(_job: Job) -> Array[ActionBase]:
		var out: Array[ActionBase] = []
		for stub_name: String in plan_names:
			var action := StubAction.new()
			action.stub_name = stub_name
			action.complete_mode = ActionBase.CompleteMode.CONDITION
			out.append(action)
		return out

	func required_claims(_job: Job, action_index: int) -> Array[ClaimSpec]:
		var out: Array[ClaimSpec] = []
		out.assign(claims_at.get(action_index, []))
		return out


class FakeClaimable:
	extends RefCounted

	var available: bool = true
	var held: int = 0

	func can_take_claim(_kind: int, _amount: int) -> bool:
		return available

	func take_claim(_kind: int, amount: int) -> Variant:
		if not available:
			return null
		held += amount
		return true

	func release_claim(_kind: int, amount: int, _payload: Variant) -> void:
		held -= amount


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

## A started job sitting on action `index`, with `names` as its sequence.
func _running_job(index: int, names: PackedStringArray = ["walk", "work"]) -> Job:
	var job := Job.create(_data())
	job.registry = registry
	var driver := StubDriver.new()
	driver.plan_names = names
	job.install_driver(driver)
	job.start_job(null)
	# Walk the runner forward without needing the actions to complete naturally.
	job._index = index
	return job

## Restores `encoded` with a driver whose sequence is `names`.
func _restore(encoded: Dictionary, names: PackedStringArray = ["walk", "work"],
		claims_at: Dictionary[int, Array] = {}) -> Job:
	var job := Job.create(_data())
	job.registry = registry
	var driver := StubDriver.new()
	driver.plan_names = names
	driver.claims_at = claims_at
	job.install_driver(driver)
	return Job.restore_into(job, encoded)

# --- what does and doesn't persist --------------------------------------------

func test_unsaveable_definition_serializes_to_nothing() -> void:
	# The data-driven replacement for job_serializer.gd's "deliberately NOT
	# registered" comment: idle, wander, store-inventory, leave-station.
	var job := Job.create(_data(false))
	job.registry = registry
	assert_eq(job.to_dict(), {}, "saveable = false means drop on save")

func test_job_with_no_definition_serializes_to_nothing() -> void:
	var job := Job.new()
	assert_eq(job.to_dict(), {}, "no JobData, nothing to write")

func test_encodes_definition_and_scalars() -> void:
	var job := Job.create(_data())
	job.count = 12
	job.priority = 99
	var encoded: Dictionary = job.to_dict()
	assert_eq(String(encoded.get("def", "")), "test_job", "the definition id identifies the type")
	assert_eq(int(encoded.get("count", 0)), 12, "count survives")
	assert_eq(int(encoded.get("priority", 0)), 99, "priority survives")

func test_defaults_are_omitted_rather_than_written() -> void:
	var job := Job.create(_data())
	var encoded: Dictionary = job.to_dict()
	assert_false(encoded.has("count"), "a zero count isn't worth bytes")
	assert_false(encoded.has("priority"), "nor is a zero priority")
	assert_false(encoded.has("a"), "nor are unset targets")

func test_cell_target_round_trips() -> void:
	var job := Job.create(_data())
	job.target_a = JobTarget.of_cell(Vector2i(16, -8))
	var restored: Job = _restore(job.to_dict())
	assert_not_null(restored, "restored")
	assert_eq(restored.target_a.cell(), Vector2i(16, -8), "the cell came back intact")
	assert_eq(restored.target_a.kind, JobTarget.Kind.CELL, "and so did its kind")

func test_soft_target_flag_round_trips() -> void:
	var job := Job.create(_data())
	job.target_a = JobTarget.of_cell(Vector2i(1, 1))
	job.target_a.fail_on_lost = false
	var restored: Job = _restore(job.to_dict())
	assert_false(restored.target_a.fail_on_lost, "a target the job can outlive stays that way")

# --- the action index ---------------------------------------------------------

func test_queued_job_saves_no_index_and_restores_unstarted() -> void:
	# A job still in the pawn's personal queue has never run; it restores by
	# running from the top, which is what start_job() will do for it.
	var job := Job.create(_data())
	job.registry = registry
	var encoded: Dictionary = job.to_dict()
	assert_eq(int(encoded.get("index", 0)), -1, "no action to come back to")
	assert_false(encoded.has("sig"), "and no sequence to protect")
	var restored: Job = _restore(encoded)
	assert_eq(restored.action_index(), -1, "restores unstarted")

func test_running_job_resumes_on_the_action_it_was_on() -> void:
	# THE point of the refactor: a pawn who has already walked to the workstation
	# comes back working, not walking.
	var job := _running_job(1)
	var restored: Job = _restore(job.to_dict())
	assert_not_null(restored, "restored")
	assert_eq(restored.action_index(), 1, "resumed on action 1, not back at 0")

func test_resume_enters_through_on_resume_not_on_start() -> void:
	# The contract that stops a restored 'take from storage' withdrawing twice.
	var job := _running_job(1)
	var restored: Job = _restore(job.to_dict())
	restored.resume_job(null)
	var action := restored.current_action() as StubAction
	assert_eq(action.resume_calls, 1, "the resumed action went through on_resume")
	assert_eq(action.start_calls, 0, "and never through on_start")

func test_index_past_the_end_of_the_sequence_drops_the_job() -> void:
	var job := _running_job(1)
	var encoded: Dictionary = job.to_dict()
	encoded["index"] = 9
	assert_null(_restore(encoded), "an index the sequence can't contain is unrecoverable")

# --- the signature guard ------------------------------------------------------

func test_changed_action_sequence_drops_the_job() -> void:
	# make_actions() is required to be deterministic, but a CODE change between
	# save and load legitimately changes it - and resuming index 1 of a different
	# sequence would run the wrong action with right-looking state.
	var job := _running_job(1, ["walk", "work"])
	var encoded: Dictionary = job.to_dict()
	assert_null(_restore(encoded, ["walk", "claim", "work"]),
		"a driver whose steps changed drops its in-flight jobs instead of guessing")
	assert_push_warning("sequence changed", "and says why")

func test_same_sequence_restores_cleanly() -> void:
	var job := _running_job(1, ["walk", "work"])
	assert_not_null(_restore(job.to_dict(), ["walk", "work"]), "an unchanged sequence resumes")

# --- per-action progress ------------------------------------------------------

func test_action_state_round_trips_to_the_right_action() -> void:
	var job := _running_job(1)
	(job.current_action() as StubAction).state = {"mined": 4}
	var restored: Job = _restore(job.to_dict())
	assert_eq((restored.current_action() as StubAction).state, {"mined": 4},
		"the action got its own progress back")

func test_stateless_actions_write_nothing() -> void:
	var job := _running_job(1)
	var encoded: Dictionary = job.to_dict()
	assert_false(encoded.has("state"), "no action had state, so no state key at all")

func test_state_is_sparse_and_keyed_by_index() -> void:
	var job := _running_job(1, ["walk", "work", "wrap"])
	(job.current_action() as StubAction).state = {"seconds": 2.5}
	var encoded: Dictionary = job.to_dict()
	var states: Dictionary = encoded.get("state", {})
	assert_eq(states.size(), 1, "only the action that had state is written")
	assert_true(states.has("1"), "keyed by its index")

func test_duration_progress_survives_a_save() -> void:
	# DURATION progress lives on the runner, not in the action, so without
	# explicit handling a job saved four seconds into a six-second wait would
	# silently restart the wait.
	var job := Job.create(_data())
	job.registry = registry
	var driver := StubDriver.new()
	driver.plan_names = ["wait"]
	job.install_driver(driver)
	job.start_job(null)
	job._actions[0].complete_mode = ActionBase.CompleteMode.DURATION
	job._actions[0].duration = 6.0
	job.process_job(4.0)
	var restored: Job = _restore(job.to_dict(), ["wait"])
	restored._actions[0].complete_mode = ActionBase.CompleteMode.DURATION
	restored._actions[0].duration = 6.0
	restored.resume_job(null)
	restored.process_job(1.0)
	assert_false(restored.is_ended(), "five of six seconds - not done yet")
	restored.process_job(1.5)
	assert_true(restored.is_finished(), "and it finishes on the remaining time, not a fresh six seconds")

func test_duration_progress_survives_a_second_save_before_the_resume() -> void:
	# F39 (WI-69): a restored job holds its progress in _resume_elapsed until its
	# pawn re-enters the action, and to_dict() used to write only _elapsed - still
	# 0 then. So save -> load -> save before the pawn resumed (a game saved while
	# paused, loaded, saved again) wrote the wait as not started. Found by the
	# integration suite's save/load/save comparison.
	var job := Job.create(_data())
	job.registry = registry
	var driver := StubDriver.new()
	driver.plan_names = ["wait"]
	job.install_driver(driver)
	job.start_job(null)
	job._actions[0].complete_mode = ActionBase.CompleteMode.DURATION
	job._actions[0].duration = 6.0
	job.process_job(4.0)
	var first: Dictionary = job.to_dict()
	var restored: Job = _restore(first, ["wait"])
	assert_eq(restored.to_dict().get("elapsed", 0.0), first.get("elapsed"),
		"a restored job that has not resumed yet still owes its action four seconds")
	var twice: Job = _restore(restored.to_dict(), ["wait"])
	twice._actions[0].complete_mode = ActionBase.CompleteMode.DURATION
	twice._actions[0].duration = 6.0
	twice.resume_job(null)
	twice.process_job(2.5)
	assert_true(twice.is_finished(), "and after two loads it finishes on the remaining time")

# --- claim re-acquisition -----------------------------------------------------

func test_resume_reacquires_the_claims_the_action_needs() -> void:
	# Claims are deliberately never saved, but the saved index points PAST the
	# actions that took them - a pawn resuming mid-sleep is on 'restore need' and
	# the claim-the-bed step already ran.
	var bed := FakeClaimable.new()
	var job := _running_job(1)
	var needed: Dictionary[int, Array] = {1: [ClaimSpec.make(bed, ClaimSpec.Kind.SLOT, 1)]}
	var restored: Job = _restore(job.to_dict(), ["walk", "work"], needed)
	restored.resume_job(null)
	assert_eq(bed.held, 1, "the bed was re-claimed before the action resumed")
	assert_true(registry.holds_claim(restored, bed, ClaimSpec.Kind.SLOT), "and the ledger knows")

func test_resume_fails_cleanly_when_a_claim_cannot_be_retaken() -> void:
	# Someone else got the bed during load. Failing here re-queues the need,
	# which still beats the pre-WI-44 behaviour of replaying the whole job.
	var bed := FakeClaimable.new()
	bed.available = false
	var job := _running_job(1)
	var needed: Dictionary[int, Array] = {1: [ClaimSpec.make(bed, ClaimSpec.Kind.SLOT, 1)]}
	var restored: Job = _restore(job.to_dict(), ["walk", "work"], needed)
	restored.resume_job(null)
	assert_true(restored.is_failed(), "the job drops rather than running unreserved")
	assert_eq(registry.claims_of(restored).size(), 0, "and leaves nothing behind in the ledger")

func test_resume_on_an_unstarted_job_just_starts_it() -> void:
	var job := Job.create(_data())
	job.registry = registry
	job.install_driver(StubDriver.new())
	job.resume_job(null)
	assert_eq(job.action_index(), 0, "an unstarted job resumes by starting normally")

# --- beginning a restored job (F40, WI-70) -------------------------------------
#
# resume_job() had no caller: every restored job went through start_job() and
# replayed from its first step. PawnBase now begins every job through
# resume_job(), and asks can_begin() rather than the board's pickup gate.

func test_a_restored_job_awaits_resume_until_it_is_resumed() -> void:
	var restored: Job = _restore(_running_job(1).to_dict())
	assert_true(restored.awaits_resume(), "restored on action 1, not yet resumed")
	restored.resume_job(null)
	assert_false(restored.awaits_resume(), "resumed once, and only once")
	assert_eq(restored.action_index(), 1, "on the action it was saved on")

func test_only_a_job_restored_mid_sequence_awaits_resume() -> void:
	var fresh := Job.create(_data())
	assert_false(fresh.awaits_resume(), "a fresh job starts")
	var queued := Job.create(_data())
	var restored_queued: Job = _restore(queued.to_dict())
	assert_false(restored_queued.awaits_resume(), "a job restored from a queue was never started")
	var ended: Job = _restore(_running_job(1).to_dict())
	ended.end(Job.Outcome.FAILED)
	assert_false(ended.awaits_resume(), "an ended job awaits nothing")

func test_a_job_awaiting_resume_is_not_asked_the_pickup_gate() -> void:
	# A pawn restored carrying a full load of this job's own cargo has no room to
	# pick anything up, and the board's can_do() says so. That refused every
	# restored full load and sent the cargo to the sweep.
	var restored: Job = _restore(_running_job(1).to_dict())
	(restored.driver() as StubDriver).claimable = false
	assert_true(restored.can_begin(null), "a resume proves itself through its claims instead")
	var fresh := Job.create(_data())
	var driver := StubDriver.new()
	driver.claimable = false
	fresh.install_driver(driver)
	assert_false(fresh.can_begin(null), "while a fresh job still has to be claimable")

func test_a_job_awaiting_resume_is_not_asked_its_validity_until_it_has_resumed() -> void:
	# A pile collection between reserving and taking is valid only while it holds
	# its pile claim, and claims are never saved - so asked before the resume, every
	# one restored on its walk to the pile read as invalid and was cancelled.
	var restored: Job = _restore(_running_job(1).to_dict())
	var stub: StubDriver = restored.driver() as StubDriver
	stub.valid = false
	assert_true(restored.can_begin(null), "begun, and resumed")
	restored.resume_job(null)
	assert_false(restored.is_ended(), "the resume itself does not ask")
	restored.process_job(0.1)
	assert_true(restored.is_failed(), "the first frame does, with the claims back in hand")

# --- registry -----------------------------------------------------------------

func test_job_data_registry_returns_null_for_unknown_ids() -> void:
	# How an old or hand-edited save drops a job type that no longer exists.
	JobDataRegistry.clear_for_test()
	JobDataRegistry.register_for_test(_data())
	assert_not_null(JobDataRegistry.get_data(&"test_job"), "a registered type resolves")
	assert_null(JobDataRegistry.get_data(&"not_a_real_job"), "an unknown type is null, not an error")
	JobDataRegistry.clear_for_test()
