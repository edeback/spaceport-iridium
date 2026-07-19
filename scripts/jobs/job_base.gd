class_name JobBase
extends Resource

## Which board queue a job lives in. Pawns can filter by category when
## claiming (shift/assignment filtering arrives in WI-06); selection across
## categories is still by effective priority, so categories are an index,
## not a ranking.
enum Category { HAUL, BUILD, WORK, NEEDS, MOVE, MISC }

@export var name: String = ""
@export var description: String = ""
var priority: int = 0
## Sim-seconds spent waiting unclaimed on the board (bumped by JobManager on
## slow_tick). Feeds effective_priority() so starved jobs slowly surface.
var age: float = 0.0

## Optional workspace gate (WI-23). null = open to any pawn. When set to a
## module's WorkspaceComponent that has assignees, only those assignees pass
## can_do_job (posting subclasses enforce it), and they get an affinity bump in
## effective_priority_for so they prefer their own workspace's jobs. An empty
## assignment reopens the job to everyone with no affinity effect.
var workspace: WorkspaceComponent = null

enum JobState { Starting, Moving, Working, Finished, Failed }

signal subtask_changed

## Emitted exactly once, when the job terminates for any reason (success,
## graceful cancel, or failure). Safe to CONNECT_ONE_SHOT.
signal job_end

## Lifecycle guard: set the moment end_job() runs. cancel() and end_job()
## are both no-ops afterward, so reservations can't double-release and
## job_end can't double-fire.
## RULE for subclasses: any callback that can fire after the job ends (e.g.
## a movement_ended one-shot still connected when the job is cancelled) must
## early-return on _ended BEFORE mutating state or moving resources. cancel()
## sets the terminal state exactly once; a late callback that overwrites it
## can never be corrected (the _ended latch blocks re-cancel), which leaves
## the pawn processing a dead job forever.
var _ended: bool = false

func get_category() -> Category:
	return Category.MISC

## The skill (WI-22) whose multiplier gates this job's work rate and that gains
## xp when the job completes. &"" (default) = unskilled: no multiplier applied,
## no xp granted. Skilled subclasses (construct, mine, ...) override this.
func get_skill() -> StringName:
	return &""

## XP granted to get_skill() on successful completion. Completion-only jobs
## (construction) return their whole reward here; long jobs that trickle xp
## during process_job (mining) return 0 and grant as they work.
func xp_reward() -> float:
	return 0.0

func get_category_name() -> String:
	return String(Category.keys()[get_category()]).capitalize()

func get_job_description() -> String:
	return ""

func get_subtask_description() -> String:
	return ""

func player_cancelable() -> bool:
	return true

## Board sort key: base priority plus a capped age bonus, so long-waiting
## jobs eventually outrank fresher peers within nearby bands (the cap keeps
## aging from ever crossing the ±99 construction routing bands).
func effective_priority() -> float:
	return priority + minf(age * JobPriorities.AGE_BONUS_RATE, JobPriorities.AGE_BONUS_CAP)

## Per-pawn selection key (WI-23): the board-sort effective_priority() plus a
## workspace affinity bonus when this job's workspace lists `pawn`. JobManager
## uses this to pick a pawn's next job, while the board stays sorted by the
## pawn-agnostic effective_priority(), so assignees prefer their workspace's
## work without disturbing global ordering.
func effective_priority_for(pawn: PawnBase) -> float:
	var base: float = effective_priority()
	if workspace != null and workspace.lists(pawn):
		base += JobPriorities.WORKSPACE_AFFINITY_BONUS
	return base

func is_valid() -> bool:
	return true

func can_do_job(_pawn: PawnBase) -> bool:
	return true

func start_job(_pawn: PawnBase) -> void:
	pass

func process_job(_delta: float) -> void:
	# Override by subclasses
	pass

func is_failed() -> bool:
	# Override by subclasses
	return false

func is_finished() -> bool:
	# Override by subclasses
	return false

## Authoritative "this job is over" check - true once end_job() has run,
## regardless of what the subclass state machine claims. Pawns use this as a
## backstop against stale callbacks overwriting the terminal state.
func is_ended() -> bool:
	return _ended

## THE single termination entry point (lifecycle contract, WI-04):
## releases the job's resources, sets terminal state, and ends the job -
## callers (JobManager, pawns, UI) call this and nothing else. Idempotent.
## Subclasses override _on_cancel(), never this.
func cancel(as_failed: bool) -> void:
	if _ended:
		return
	_on_cancel(as_failed)
	end_job()

## Subclass hook: release reservations and set the terminal state
## (Failed when as_failed, Finished otherwise). Runs at most once.
func _on_cancel(_as_failed: bool) -> void:
	pass

## Finalizer; fires job_end exactly once. cancel() calls this itself; the
## pawn also calls it when it notices a job finished successfully (jobs set
## their Finished state without going through cancel), and the guard makes
## the overlap harmless.
func end_job() -> void:
	if _ended:
		return
	_ended = true
	_on_end()
	job_end.emit()

## Subclass hook for one-time teardown that must happen however the job
## ends - e.g. disconnecting from SignalBus signals so finished jobs don't
## linger connected (and alive) forever.
func _on_end() -> void:
	pass

## Serialization hook (WI-21). Base returns {} = "not saveable, drop on save"
## - correct for board-derived, idle, and store-inventory jobs that a system
## re-derives on load. Saveable subclasses (the ones a pawn carries as
## current_job / job_queue) override this to return
## {"type": <String job id>, ...target refs + ctor params...}. JobSerializer
## maps the type id back to the subclass's static restore(data) -> JobBase
## factory, which rebuilds the job in its initial state pointed at resolved
## targets; start_job() then re-runs the normal claim/validity gauntlet.
func get_save_data() -> Dictionary:
	return {}

## Override to compute a followup job for pawn. Call this yourself (see
## Job_GetResource.deposit_resource()) at the exact moment you know you've
## succeeded, and push the result onto the pawn's queue immediately - don't
## wait for end_job()/is_finished() to be noticed on a later _process()
## tick. Node processing order between you and whatever you're offering a
## followup on behalf of isn't guaranteed, so resolving eagerly and
## synchronously inside your own success path is what keeps the handoff
## race-free. Return null (the default) if there's nothing to chain into.
func get_followup_job(_pawn: PawnBase) -> JobBase:
	return null
