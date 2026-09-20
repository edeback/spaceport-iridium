class_name Job
extends Resource

## A running (or board-waiting) job instance (WI-44) - RimWorld's Job, and the
## thing that gets saved. Composition of three pieces:
##
##   JobData   the type: category, report template, skill, which driver
##   Job       this: targets, count, priority, WHICH ACTION IS CURRENT
##   ActionBase[]  the steps, built by the driver
##
## Everything a job type used to hand-write - the state enum, the movement
## one-shot plumbing, the module-removed handler, the reservation releases, the
## get_save_data/restore pair - lives here once instead.

## How a job ended. Replaces the old cancel(as_failed: bool): "interrupted" was
## already a distinct meaning (PawnBase.interrupt_with_job passes false so cargo
## survives) and actions need to tell it apart from failure when deciding whether
## to keep their progress. Three values, not RimWorld's nine - the rest of its
## JobCondition set is error plumbing with no consumer here.
enum Outcome { ONGOING, SUCCEEDED, FAILED, INTERRUPTED }

## Guard against a driver whose next_index_after() cycles through INSTANT actions
## forever. Real sequences are under a dozen steps; this only ever trips on a bug.
const MAX_INSTANT_CHAIN: int = 64

signal subtask_changed
## Emitted exactly once, however the job ended. Safe to CONNECT_ONE_SHOT.
signal job_end

var data: JobData = null
var pawn: PawnBase = null

# --- targets ------------------------------------------------------------------
# Three slots, checked against all 23 pre-WI-44 job types - nothing needed a
# fourth. Don't add one speculatively; add it when a real job needs it.
var target_a: JobTarget = null
var target_b: JobTarget = null
var target_c: JobTarget = null
## Generic "how many" - units to haul, batches to run. Meaning is per job type.
var count: int = 0
## The resource this job is about, when it is about one. A definition reference,
## saved by id rather than as a target.
var resource: ResourceData = null

# --- board state --------------------------------------------------------------
## Set by whoever posts the job. Storage priority is the routing language, so
## this is computed per-post and deliberately has no JobData default.
var priority: int = 0
## Sim-seconds spent waiting unclaimed (bumped by JobManager on slow_tick).
var age: float = 0.0
## Optional workspace gate (WI-23). Unchanged semantics.
var workspace: WorkspaceComponent = null
## Who re-adopts this job after a load (WI-70 §3). Defaults from the type's
## JobData.origin; with_origin() overrides it for a haul, whose poster depends on
## direction. Saved only when it differs from the type's default.
var origin: JobData.Origin = JobData.Origin.NONE

# --- runner state -------------------------------------------------------------
var _driver: JobDriver = null
var _actions: Array[ActionBase] = []
var _index: int = -1
var _outcome: Outcome = Outcome.ONGOING
var _ended: bool = false
var _started: bool = false
## Seconds spent in the current action (CompleteMode.DURATION), reset on entry.
var _elapsed: float = 0.0
## Elapsed time carried across a load, applied by the first _enter() of a resume.
## DURATION progress lives on the runner rather than in the action, so without
## this a job saved four seconds into a six-second wait would restart the wait.
var _resume_elapsed: float = 0.0
## Set by a restore that put the job back on its saved action; cleared once a pawn
## resumes it. See awaits_resume().
var _awaiting_resume: bool = false

enum MoveState { NONE, PENDING, ARRIVED, FAILED }
var _move_state: MoveState = MoveState.NONE

## The claim ledger. Injected so the runner can be unit-tested without a live
## world; falls back to the real registry the first time it's needed.
var registry: ClaimRegistry = null

# --- construction -------------------------------------------------------------

static func create(job_data: JobData) -> Job:
	var job := Job.new()
	job.data = job_data
	if job_data != null:
		job.origin = job_data.origin
	return job

## The posting-site constructor: `Job.of(&"haul_resource").with_resource(r)`.
## Every job in the game is now built this way, so an unknown id is a typo in a
## posting site rather than a recoverable condition - it pushes an error and
## returns a job with no definition, which fails on its first frame.
static func of(id: StringName) -> Job:
	var job_data: JobData = JobDataRegistry.get_data(id)
	if job_data == null:
		push_error("No JobData registered for id '%s'" % id)
	return create(job_data)

func with_target_a(target: JobTarget) -> Job:
	target_a = target
	return self

func with_target_b(target: JobTarget) -> Job:
	target_b = target
	return self

func with_target_c(target: JobTarget) -> Job:
	target_c = target
	return self

func with_count(new_count: int) -> Job:
	count = new_count
	return self

func with_resource(new_resource: ResourceData) -> Job:
	resource = new_resource
	return self

func with_priority(new_priority: int) -> Job:
	priority = new_priority
	return self

func with_origin(new_origin: JobData.Origin) -> Job:
	origin = new_origin
	return self

# --- target access ------------------------------------------------------------

func target(slot: JobTarget.Slot) -> JobTarget:
	match slot:
		JobTarget.Slot.A:
			return target_a
		JobTarget.Slot.B:
			return target_b
		JobTarget.Slot.C:
			return target_c
	return null

func set_target(slot: JobTarget.Slot, value: JobTarget) -> void:
	match slot:
		JobTarget.Slot.A:
			target_a = value
		JobTarget.Slot.B:
			target_b = value
		JobTarget.Slot.C:
			target_c = value

# --- driver / action access ---------------------------------------------------

func driver() -> JobDriver:
	return _driver

func current_action() -> ActionBase:
	if _index < 0 or _index >= _actions.size():
		return null
	return _actions[_index]

func action_index() -> int:
	return _index

func action_count() -> int:
	return _actions.size()

## Index of the action carrying `action_label`, or -1. How drivers express jumps
## without hardcoding positions.
func index_of_label(action_label: StringName) -> int:
	for i: int in _actions.size():
		if _actions[i].label == action_label:
			return i
	return -1

# --- lifecycle ----------------------------------------------------------------

## Type test for the handful of places that genuinely care WHICH job this is -
## "is this pawn merely idling", "is this the recharge job". Replaces `job is
## the idle job` now that every job shares one class and differs by its definition.
func is_type(type_id: StringName) -> bool:
	return data != null and data.id == type_id

## True while the pawn is doing nothing that matters: idling in place or drifting.
## Several systems (breathing, robot power) treat both the same way.
func is_idle_type() -> bool:
	return is_type(&"idle") or is_type(&"idle_wander")

func get_category() -> JobData.Category:
	return data.category if data != null else JobData.Category.MISC

## Delegates to the driver, which may resolve the skill from the target rather
## than the type (see JobDriver.skill). Falls back to the type's own skill for a
## board job whose driver hasn't been built yet.
func get_skill() -> StringName:
	if _driver != null:
		return _driver.skill(self)
	return data.skill if data != null else &""

func xp_reward() -> float:
	return data.xp_reward if data != null else 0.0

func player_cancelable() -> bool:
	return data.player_cancelable if data != null else true

func is_valid() -> bool:
	if data == null:
		return false
	# Before start_job the driver doesn't exist yet, so a board job's validity is
	# asked of a throwaway driver instance. JobManager calls this on every scan,
	# so keep that lazy rather than building one per call.
	if _driver == null:
		_ensure_board_driver()
	return _driver != null and _driver.is_valid(self)

func can_do_job(candidate: PawnBase) -> bool:
	if not is_valid():
		return false
	return _driver.can_do(self, candidate)

## True for a job restored part-way through its sequence that no pawn has resumed
## yet. Only a pawn's own restored job is ever in this state; board jobs are not
## saved, and a job restored from a pawn's queue was never started.
func awaits_resume() -> bool:
	return _awaiting_resume and not _ended

## Whether `candidate` may begin this job now: the board's claimability check for
## a fresh job, and always for one awaiting resume (F40, WI-70).
##
## Neither of the board's questions can be asked of a restored job before it
## resumes. can_do() is a PICKUP gate - is there room to carry, is there somewhere
## to take it - and asked of a pawn restored mid-carry it refused every full load,
## because the pawn's hands were full of that job's own cargo. is_valid() can hang
## on a claim: a pile collection between reserving and taking is valid only while
## it holds its pile claim, and claims are never saved, so every one restored on
## its walk to the pile read as invalid. Both were cancelled before they moved.
## A resumed job proves itself instead: resume_job() re-takes the claims its
## action needs and ends it cleanly if it cannot, and process_job() asks
## is_valid() on its first frame, with the claims back in hand.
func can_begin(candidate: PawnBase) -> bool:
	if awaits_resume():
		return true
	return can_do_job(candidate)

func explain_block(candidate: PawnBase) -> String:
	if _driver == null:
		_ensure_board_driver()
	return _driver.explain_block(self, candidate) if _driver != null else "no driver"

## Builds a driver for a job that hasn't been claimed yet, so is_valid()/can_do()
## work on the board. `pawn` is still null at this point and drivers must not
## assume otherwise in those two methods.
func _ensure_board_driver() -> void:
	if _driver != null or data == null:
		return
	var script: GDScript = data.driver as GDScript
	if script == null:
		return
	_driver = script.new() as JobDriver

## Installs a pre-built driver instead of instantiating data.driver. Used by the
## load path (which needs the driver before the action list exists) and by unit
## tests, which inject a stub rather than routing through a .tres.
func install_driver(new_driver: JobDriver) -> void:
	_driver = new_driver

func start_job(claiming_pawn: PawnBase) -> void:
	if _ended:
		return
	pawn = claiming_pawn
	_started = true
	_awaiting_resume = false
	_ensure_board_driver()
	if _driver == null:
		push_error("Job '%s' has no usable driver script" % _id_string())
		end(Outcome.FAILED)
		return
	_actions = _driver.make_actions(self)
	if _actions.is_empty():
		push_error("Job '%s' driver produced no actions" % _id_string())
		end(Outcome.FAILED)
		return
	_enter(0, false)

## Per-frame drive, called by PawnBase with delta already sim-scaled.
func process_job(delta: float) -> void:
	if _ended or not _started:
		return
	# Global fail conditions, checked before the action gets a frame.
	if not _driver.is_valid(self):
		end(Outcome.FAILED)
		return
	if not _targets_alive():
		end(Outcome.FAILED)
		return
	var action: ActionBase = current_action()
	if action == null:
		end(Outcome.FAILED)
		return

	_elapsed += delta
	# Tick BEFORE the completion check, so progress accumulated this frame counts
	# toward finishing on this frame rather than the next one.
	var status: ActionBase.Status = action.tick(self, delta)
	if _ended:
		return
	if status == ActionBase.Status.ONGOING:
		status = _completion_status(action)
	_apply_status(status)

## Applies an action's status: advance on DONE, fail the job on FAILED.
func _apply_status(status: ActionBase.Status) -> void:
	if status == ActionBase.Status.FAILED:
		end(Outcome.FAILED)
		return
	if status != ActionBase.Status.DONE:
		return
	var action: ActionBase = current_action()
	if action != null:
		_restore_action_animation(action)
		action.on_finish(self, Outcome.SUCCEEDED)
	if _ended:
		return
	_enter(_driver.next_index_after(self, _index), false)

## How the runner knows the current action is over.
func _completion_status(action: ActionBase) -> ActionBase.Status:
	match action.complete_mode:
		ActionBase.CompleteMode.INSTANT:
			return ActionBase.Status.DONE
		ActionBase.CompleteMode.DURATION:
			return ActionBase.Status.DONE if _elapsed >= action.duration else ActionBase.Status.ONGOING
		ActionBase.CompleteMode.MOVEMENT:
			match _move_state:
				MoveState.ARRIVED:
					return ActionBase.Status.DONE
				MoveState.FAILED:
					return ActionBase.Status.FAILED
				_:
					return ActionBase.Status.ONGOING
		ActionBase.CompleteMode.CONDITION:
			return action.check(self)
	return ActionBase.Status.ONGOING

## Enters the action at `index`, chaining through any that complete immediately.
## `resuming` routes through on_resume() instead of on_start() - the load path.
func _enter(index: int, resuming: bool) -> void:
	var guard: int = 0
	while true:
		guard += 1
		if guard > MAX_INSTANT_CHAIN:
			push_error("Job '%s' chained %d instant actions - next_index_after is looping"
				% [_id_string(), MAX_INSTANT_CHAIN])
			end(Outcome.FAILED)
			return
		if index < 0 or index >= _actions.size():
			# Ran off the end: every step done, job succeeded.
			end(Outcome.SUCCEEDED)
			return
		_index = index
		_elapsed = _resume_elapsed if resuming else 0.0
		_resume_elapsed = 0.0
		_move_state = MoveState.NONE
		var action: ActionBase = _actions[_index]
		var status: ActionBase.Status = action.on_resume(self) if resuming else action.on_start(self)
		# on_start can end the job outright (a claim it needed was taken).
		if _ended:
			return
		if status == ActionBase.Status.FAILED:
			end(Outcome.FAILED)
			return
		# DONE from on_start is a legitimate skip ("already carrying this, move
		# on"), and INSTANT means on_start WAS the action.
		if status == ActionBase.Status.DONE or action.complete_mode == ActionBase.CompleteMode.INSTANT:
			action.on_finish(self, Outcome.SUCCEEDED)
			if _ended:
				return
			index = _driver.next_index_after(self, _index)
			# Only the first action of a resume is resumed; anything chained after
			# it is being entered for the first time.
			resuming = false
			continue
		_play_action_animation(action)
		subtask_changed.emit()
		return

## THE single termination entry point. Idempotent, and the only place claims are
## released. Callers (JobManager, PawnBase, the UI cancel button) call this and
## nothing else.
func end(outcome: Outcome) -> void:
	if _ended:
		return
	_ended = true
	_outcome = outcome
	var action: ActionBase = current_action()
	if action != null:
		_restore_action_animation(action)
		action.on_finish(self, outcome)
	if _driver != null:
		_driver.on_job_end(self, outcome)
	_disconnect_movement()
	var ledger: ClaimRegistry = _claims()
	if ledger != null:
		ledger.release_all(self)
	job_end.emit()

## `end()` as FAILED or INTERRUPTED - the shorthand most call sites use.
func cancel(as_failed: bool) -> void:
	end(Outcome.FAILED if as_failed else Outcome.INTERRUPTED)

func is_ended() -> bool:
	return _ended

func is_finished() -> bool:
	return _ended and _outcome == Outcome.SUCCEEDED

## Ended as FAILED - and only FAILED. For the runner and its tests. An owner
## deciding whether to re-post wants [method did_not_complete]: an INTERRUPTED job
## didn't finish either, and asking this instead is F25 (WI-70). A source sweep
## fails on any call to it outside `scripts/jobs/`.
func is_failed() -> bool:
	return _ended and _outcome == Outcome.FAILED

## Ended without finishing: FAILED or INTERRUPTED. "It didn't finish, so re-post"
## is the question every owner asks.
func did_not_complete() -> bool:
	return _ended and _outcome != Outcome.SUCCEEDED

func outcome() -> Outcome:
	return _outcome

## True when the current action needs whatever the pawn is already carrying, so
## PawnBase's "store your inventory first" preemption must stand down. Without
## this, a restored haul gets its cargo swept into a random bin and has to redo
## the whole trip - the exact reload behaviour WI-44 exists to remove.
func expects_cargo() -> bool:
	var action: ActionBase = current_action()
	return action != null and action.expects_cargo()

# --- targets ------------------------------------------------------------------

## The declarative replacement for eleven hand-wired module_removed handlers: any
## target flagged fail_on_lost that stops being alive fails the job.
func _targets_alive() -> bool:
	for slot: JobTarget in [target_a, target_b, target_c]:
		if slot != null and slot.is_set() and slot.fail_on_lost and not slot.is_alive():
			return false
	return true

# --- movement -----------------------------------------------------------------

## Starts a move and arms the arrival watch. The ONE place in the system that
## connects movement_ended - the twenty-two hand-rolled CONNECT_ONE_SHOT sites
## with their _ended guards collapse into this.
func begin_movement(node: Node2D, speed: float = 1.0, in_space: bool = false, anchor: AnchorDef = null) -> bool:
	if pawn == null or pawn.movement_component == null or node == null:
		return false
	_move_state = MoveState.PENDING
	if not pawn.movement_component.movement_ended.is_connected(_on_movement_ended):
		pawn.movement_component.movement_ended.connect(_on_movement_ended)
	pawn.movement_component.move_to(node, speed, in_space, anchor)
	return true

## Pose handling for CompleteMode-agnostic "hold this animation while the action
## runs". Only ever touches the sprite when the action asked for a pose.
func _play_action_animation(action: ActionBase) -> void:
	if action.animation == &"" or pawn == null or not is_instance_valid(pawn):
		return
	if pawn.animated_sprite != null:
		pawn.animated_sprite.play(String(action.animation))

func _restore_action_animation(action: ActionBase) -> void:
	if action.animation == &"" or action.restore_animation == &"":
		return
	if pawn == null or not is_instance_valid(pawn) or pawn.animated_sprite == null:
		return
	# Only undo OUR pose - if something else has taken the sprite over since,
	# stomping it would be worse than leaving it be.
	if pawn.animated_sprite.animation == action.animation:
		pawn.animated_sprite.play(String(action.restore_animation))

func _on_movement_ended(as_success: bool) -> void:
	# The latch, once, centrally. Every job used to re-derive this guard, and the
	# eight-line warning above JobBase._ended existed to explain why.
	if _ended:
		return
	_move_state = MoveState.ARRIVED if as_success else MoveState.FAILED

func _disconnect_movement() -> void:
	if pawn != null and is_instance_valid(pawn) and pawn.movement_component != null \
			and pawn.movement_component.movement_ended.is_connected(_on_movement_ended):
		pawn.movement_component.movement_ended.disconnect(_on_movement_ended)

func movement_state() -> MoveState:
	return _move_state

# --- claims -------------------------------------------------------------------

func _claims() -> ClaimRegistry:
	if registry == null:
		registry = Global.claim_registry
	return registry

## Takes a claim on this job's behalf. Released automatically when the job ends.
func claim(target_object: Object, kind: ClaimSpec.Kind, amount: int = 1) -> ClaimSpec:
	var ledger: ClaimRegistry = _claims()
	return ledger.claim(self, target_object, kind, amount) if ledger != null else null

func release_claim(target_object: Object, kind: ClaimSpec.Kind) -> void:
	var ledger: ClaimRegistry = _claims()
	if ledger != null:
		ledger.release(self, target_object, kind)

## Forgets a claim the job has SPENT (reserved stock now on the pawn, reserved
## space now filled). Releasing it instead would credit the reservation back a
## second time - see ClaimRegistry.consume().
func consume_claim(target_object: Object, kind: ClaimSpec.Kind) -> void:
	var ledger: ClaimRegistry = _claims()
	if ledger != null:
		ledger.consume(self, target_object, kind)

## Trims a claim down to `amount`, giving the excess back - see ClaimRegistry.shrink().
func shrink_claim(target_object: Object, kind: ClaimSpec.Kind, amount: int) -> void:
	var ledger: ClaimRegistry = _claims()
	if ledger != null:
		ledger.shrink(self, target_object, kind, amount)

## The claim record this job holds against `target_object`, or null. Actions that
## need the claim's PAYLOAD back (which anchor was handed out) go through here.
func find_claim(target_object: Object, kind: ClaimSpec.Kind) -> ClaimSpec:
	var ledger: ClaimRegistry = _claims()
	return ledger.find_claim(self, target_object, kind) if ledger != null else null

func holds_claim(target_object: Object, kind: ClaimSpec.Kind) -> bool:
	var ledger: ClaimRegistry = _claims()
	return ledger != null and ledger.holds_claim(self, target_object, kind)

# --- reporting ----------------------------------------------------------------

## The job's headline text, composed from JobData's template and this job's own
## targets - so a new job type gets usable UI text without writing any.
func report() -> String:
	if data == null:
		return ""
	if data.report_template.is_empty():
		return data.display_name
	var text: String = data.report_template
	text = text.replace("{a}", _describe_slot(target_a))
	text = text.replace("{b}", _describe_slot(target_b))
	text = text.replace("{c}", _describe_slot(target_c))
	text = text.replace("{resource}", resource.name if resource != null else "resource")
	text = text.replace("{count}", str(count))
	return text

func subtask_report() -> String:
	var action: ActionBase = current_action()
	return action.report(self) if action != null else ""

func get_category_name() -> String:
	return data.category_name() if data != null else ""

## Two different unknowns, and the player can act on the difference: a slot that
## was never filled means the job has not chosen yet (its finder runs as the first
## action), while "?" from describe() means the thing it HAD picked has since been
## destroyed. A half-specified haul is the common case - a bin posts a pull with
## only its own end known - so this text is on screen constantly.
func _describe_slot(slot: JobTarget) -> String:
	if slot == null or not slot.is_set():
		return "somewhere"
	return slot.describe()

func _id_string() -> String:
	return String(data.id) if data != null else "<no data>"

# --- persistence --------------------------------------------------------------
#
# The whole of it. No job type contributes serialization code: the seventeen
# hand-written get_save_data()/restore() pairs collapse into the two functions
# below, because JobTarget knows how to encode any kind of target and the action
# index says which step to come back to.

## Cheap shape check for the saved action index. make_actions() is required to be
## deterministic, but a CODE change between save and load legitimately changes
## the list - and resuming index 3 of a sequence that no longer has the same
## steps would silently run the wrong action. Comparing this instead drops the
## job cleanly.
func _signature() -> String:
	var names: PackedStringArray = []
	for action: ActionBase in _actions:
		names.append(action.action_name())
	return "|".join(names)

## Encoded form, or {} when this job must not persist. Pure - the SaveManager ref
## helpers JobTarget delegates to are all encode-only.
##
## {} means "drop this job on save", which covers three cases: no definition, a
## definition flagged saveable = false (idle, wander, store-inventory,
## leave-station - all re-derived by their own system on load), and a job whose
## every target has already died.
func to_dict() -> Dictionary:
	if data == null or data.id == &"" or not data.saveable:
		return {}
	var out: Dictionary = {
		"def": String(data.id),
		"index": _index,
	}
	var encoded_a: Dictionary = target_a.to_dict() if target_a != null else {}
	var encoded_b: Dictionary = target_b.to_dict() if target_b != null else {}
	var encoded_c: Dictionary = target_c.to_dict() if target_c != null else {}
	if not encoded_a.is_empty():
		out["a"] = encoded_a
	if not encoded_b.is_empty():
		out["b"] = encoded_b
	if not encoded_c.is_empty():
		out["c"] = encoded_c
	if count != 0:
		out["count"] = count
	if resource != null and resource.id != &"":
		out["resource"] = String(resource.id)
	if priority != 0:
		out["priority"] = priority
	# Only a per-post override is written; every other job's owner comes from its
	# .tres, which is also what lets a save predating origin be adopted.
	if origin != data.origin:
		out["origin"] = int(origin)
	# A job still sitting in a pawn's queue has never been started, so it has no
	# actions and no index to protect - it restores by running from the top.
	if _started:
		out["sig"] = _signature()
		# A restored job keeps its progress in _resume_elapsed until its pawn
		# re-enters the action, and _elapsed is 0 until then. Writing _elapsed alone
		# lost the progress on any save taken before that - a game saved while
		# paused, loaded and saved again restarted the wait (F39, found by WI-69's
		# save/load/save test).
		var elapsed: float = _resume_elapsed if _resume_elapsed > 0.0 else _elapsed
		if elapsed > 0.0:
			out["elapsed"] = elapsed
		var states: Dictionary = {}
		for i: int in _actions.size():
			var state: Dictionary = _actions[i].save_state()
			if not state.is_empty():
				states[str(i)] = state
		if not states.is_empty():
			out["state"] = states
	return out

## Production restore: resolves the definition and resource through the
## registries, then delegates. Returns null for anything unrecoverable, which
## propagates as "drop this job" exactly as WI-21 established.
static func from_dict(encoded: Dictionary) -> Job:
	if encoded.is_empty():
		return null
	var job_data: JobData = JobDataRegistry.get_data(StringName(String(encoded.get("def", ""))))
	if job_data == null:
		return null
	var job_resource: ResourceData = null
	var resource_id: String = String(encoded.get("resource", ""))
	if not resource_id.is_empty():
		if Global.save_manager == null:
			return null
		job_resource = Global.save_manager.get_resource_by_id(StringName(resource_id))
		# The job is ABOUT a resource that no longer exists - nothing to resume.
		if job_resource == null:
			return null
	return restore(encoded, job_data, job_resource, Global.claim_registry)

## Rebuilds a job from `encoded` with its definition and resource already
## resolved. Split out from from_dict so the sequencing logic - signature check,
## index restore, per-action state, claim re-acquisition - is testable without a
## live world.
##
## Returns null on any condition that makes resuming unsafe. A dropped job is
## always better than one resumed into the wrong step.
static func restore(encoded: Dictionary, job_data: JobData, job_resource: ResourceData,
		ledger: ClaimRegistry) -> Job:
	var job := Job.create(job_data)
	job.registry = ledger
	job.resource = job_resource
	return restore_into(job, encoded)

## Decodes `encoded` onto an already-constructed job. The seam exists because a
## driver can legitimately be installed before the decode (unit tests inject a
## stub; a future caller may want a pre-built driver), and restore() must not
## clobber it.
static func restore_into(job: Job, encoded: Dictionary) -> Job:
	job.count = int(encoded.get("count", 0))
	job.priority = int(encoded.get("priority", 0))
	if encoded.has("origin"):
		job.origin = int(encoded["origin"]) as JobData.Origin
	job.target_a = JobTarget.from_dict(encoded.get("a", {}))
	job.target_b = JobTarget.from_dict(encoded.get("b", {}))
	job.target_c = JobTarget.from_dict(encoded.get("c", {}))
	# A target that was recorded but no longer resolves (module deconstructed,
	# pile swept, pawn gone) takes the job with it - unless the job had already
	# declared it survivable.
	for key: String in ["a", "b", "c"]:
		if encoded.has(key) and not bool((encoded[key] as Dictionary).get("soft", false)):
			var slot: JobTarget = job.target(_slot_of(key))
			if slot == null or not slot.is_set():
				return null
	var saved_index: int = int(encoded.get("index", -1))
	# Never started: no index to honour, so it restores as a fresh queued job and
	# runs from the top when the pawn gets to it.
	if saved_index < 0 or not encoded.has("sig"):
		return job
	if not job._resume_at(saved_index, String(encoded.get("sig", "")), encoded.get("state", {})):
		return null
	job._resume_elapsed = float(encoded.get("elapsed", 0.0))
	return job

static func _slot_of(key: String) -> JobTarget.Slot:
	match key:
		"b":
			return JobTarget.Slot.B
		"c":
			return JobTarget.Slot.C
	return JobTarget.Slot.A

## Puts a restored job back on the action it was running. Returns false when the
## job must be dropped instead.
func _resume_at(saved_index: int, saved_signature: String, states: Dictionary) -> bool:
	_ensure_board_driver()
	if _driver == null:
		return false
	_actions = _driver.make_actions(self)
	if _actions.is_empty():
		return false
	if saved_index >= _actions.size():
		return false
	if _signature() != saved_signature:
		# The driver's steps changed since this save was written. Resuming an
		# index into a different sequence would run the wrong action with the
		# right-looking state, which is worse than starting over.
		push_warning("Job '%s' action sequence changed since save; dropping the in-flight job" % _id_string())
		return false
	for key: String in states:
		var i: int = int(key)
		if i >= 0 and i < _actions.size():
			_actions[i].load_state(states[key] as Dictionary)
	_index = saved_index
	_started = true
	_awaiting_resume = true
	return true

## Hands a job restored from a save back to whoever posted it (WI-70 §3), so that
## owner holds it in its JobSlot rather than posting a second one beside it.
## Returns whether anyone took it.
##
## `holder` is the pawn the job was restored onto; `pawn` is still null here,
## because it is only set once the job starts or resumes.
##
## The owner answers through a duck-typed `adopt_restored_job(job) -> bool`,
## and declining is always safe: an unadopted job still runs, and at worst its
## owner posts a duplicate once, which is what every load did before this.
## Nobody is asked for `NONE`, and nobody is found for a PAWN job whose component
## is missing (a mod removed since the save).
func offer_to_owner(holder: PawnBase) -> bool:
	match origin:
		JobData.Origin.NONE:
			return false
		JobData.Origin.PAWN:
			if holder == null:
				return false
			for component: PawnComponentBase in holder.components:
				if _offer(component):
					return true
			return false
		JobData.Origin.TARGET_A:
			return _offer_to_target(target_a)
		JobData.Origin.TARGET_B:
			return _offer_to_target(target_b)
		JobData.Origin.TARGET_C:
			return _offer_to_target(target_c)
	return false

func _offer_to_target(slot: JobTarget) -> bool:
	return slot != null and _offer(slot.object())

## Both callers hand this a live object or null - the pawn's own component list,
## and [method JobTarget.object], which answers null for a dead target - so the
## null check is the whole of the guarantee (WI-71 §2c).
func _offer(candidate: Object) -> bool:
	if candidate == null or not candidate.has_method(&"adopt_restored_job"):
		return false
	return bool(candidate.call(&"adopt_restored_job", self))

## Second half of the restore, run once the pawn is known: re-acquires the claims
## the current action needs and enters that action through on_resume().
##
## Claims are deliberately never saved (derived state is re-derived), but the
## saved index points PAST the actions that took them - a pawn resuming mid-sleep
## is on "restore need", and the claim-the-bed step already ran. If a claim can't
## be re-taken (someone else got the bed during load), the job fails cleanly and
## whatever queued it will queue it again, which is still better than the
## pre-WI-44 behaviour of replaying the whole job from its first step.
##
## PawnBase._begin_job() is the caller, for every job a pawn begins, so this is
## also the ordinary start for anything not awaiting a resume. Until WI-70 (F40)
## nothing called this at all: every restored job went through start_job(), which
## rebuilt its actions and replayed them from the first step, so the saved index,
## the per-action state, every action's on_resume() and F39's elapsed time were
## all written and never read.
func resume_job(claiming_pawn: PawnBase) -> void:
	if _ended:
		return
	if not awaits_resume():
		# Never actually started - the ordinary path is correct.
		start_job(claiming_pawn)
		return
	_awaiting_resume = false
	pawn = claiming_pawn
	var ledger: ClaimRegistry = _claims()
	for spec: ClaimSpec in _driver.required_claims(self, _index):
		if ledger == null or ledger.claim(self, spec.target, spec.kind, spec.amount) == null:
			end(Outcome.FAILED)
			return
	_enter(_index, true)

# --- board sorting ------------------------------------------------------------

func effective_priority() -> float:
	return priority + minf(age * JobPriorities.AGE_BONUS_RATE, JobPriorities.AGE_BONUS_CAP)

func effective_priority_for(candidate: PawnBase) -> float:
	var base: float = effective_priority()
	if workspace != null and workspace.lists(candidate):
		base += JobPriorities.WORKSPACE_AFFINITY_BONUS
	return base
