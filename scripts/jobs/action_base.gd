class_name ActionBase
extends Resource

## One step in a Job's sequence (WI-44) - RimWorld's Toil, made typed and
## serializable. Actions are the shared vocabulary: "walk to slot A", "take from
## storage", "restore a need until full". A job type is a list of these plus the
## handful of rules that are genuinely its own.
##
## HARD RULE - an action must NEVER hold the Job in a field.
## Job owns Array[ActionBase]; an action holding the job back is a reference
## cycle, and Godot's RefCounted has no cycle collector, so every job ever
## started would leak for the whole session. The job is passed into every hook
## instead. For the same reason, don't cache job.pawn either - read it through
## the job argument each time. This is the one rule that gets broken by the
## twentieth driver; if you are adding a `var job` here, stop.

enum Status {
	ONGOING,  ## still running
	DONE,     ## finished successfully - the runner advances to the next action
	FAILED,   ## finished badly - the runner fails the whole job
}

## How the runner decides this action is over. Chosen by the action's
## constructor, not by the driver, because it's a property of what the step does.
enum CompleteMode {
	INSTANT,    ## on_start() is the whole action; done the moment it returns
	MOVEMENT,   ## done when the pawn's movement ends (the runner watches the signal)
	DURATION,   ## done after `duration` sim-seconds
	CONDITION,  ## done when check() returns DONE
}

@export var complete_mode: CompleteMode = CompleteMode.INSTANT
## Sim-seconds, for CompleteMode.DURATION.
@export var duration: float = 0.0
## Optional jump label. JobDriver.next_index_after() resolves it through
## Job.index_of_label() to build loops and branches without lambdas.
@export var label: StringName = &""

# --- lifecycle ----------------------------------------------------------------

## Entering the action for the first time. Return DONE to skip straight past it
## (a no-op step for this particular job), FAILED to fail the job.
func on_start(_job: Job) -> Status:
	return Status.ONGOING

## Entering the action after a LOAD, with load_state() already applied.
##
## This is the hook that makes toil-level resume work without replaying side
## effects, and it is the single most important contract in the action library.
## on_start() for a step like "take from storage" WITHDRAWS stock; calling it on
## load would withdraw a second time. Any action whose on_start() changes the
## world must override this with the "already done, verify and continue" version.
## Actions whose on_start() only sets something up (start walking, start an
## animation) can leave the default, which re-runs on_start().
func on_resume(job: Job) -> Status:
	return on_start(job)

## Per-frame work. `delta` arrives already scaled by sim speed. Runs BEFORE the
## completion check for the frame, so progress accumulated here counts toward
## finishing on the same frame it crosses the line.
func tick(_job: Job, _delta: float) -> Status:
	return Status.ONGOING

## Completion test for CompleteMode.CONDITION.
func check(_job: Job) -> Status:
	return Status.ONGOING

## Teardown, on EVERY termination path - success, failure, or interruption -
## exactly once. Claims do NOT need releasing here: the runner releases the
## whole job's claims through ClaimRegistry when the job ends. Use this for the
## things a claim can't express (stopping an animation, telling a component its
## worker left).
func on_finish(_job: Job, _outcome: Job.Outcome) -> void:
	pass

## Subtask line for the pawn's job tab and the board inspector. Defaults to
## nothing, which makes the UI show the job's own report alone.
func report(_job: Job) -> String:
	return ""

# --- persistence --------------------------------------------------------------

## This action's own mid-flight progress. {} (the default) means the action is
## stateless and restarting it from its beginning loses nothing - true for goto,
## claim, and most instant steps. Actions that accumulate (work seconds, units
## mined, credits paid) return it here and get it back through load_state().
func save_state() -> Dictionary:
	return {}

func load_state(_data: Dictionary) -> void:
	pass

# --- runner hints -------------------------------------------------------------

## True when this action needs whatever the pawn is already carrying. A restored
## job sitting on such an action suppresses PawnBase's "sweep your inventory into
## storage first" preemption, which would otherwise walk the cargo to a random
## bin and force the job to redo its trip - the exact reload behaviour WI-44
## exists to remove.
func expects_cargo() -> bool:
	return false

## Debug name for the board inspector and the make_actions() signature check.
func action_name() -> String:
	var script_path: String = get_script().resource_path if get_script() != null else ""
	if script_path.is_empty():
		return "Action"
	return script_path.get_file().get_basename()
