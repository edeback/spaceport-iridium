class_name JobDriver
extends RefCounted

## The behaviour of one job type (WI-44) - RimWorld's JobDriver. Named by a
## JobData resource, instantiated per Job, and completely stateless: everything
## a job knows lives on the Job (targets, count) or in its actions (progress).
##
## HARD RULE, same as ActionBase - a driver must NEVER hold the Job in a field.
## Job holds the driver, so a `var job` here is a reference cycle, and Godot's
## RefCounted has no cycle collector: every job the board ever validated would
## leak for the whole session. (JobManager calls is_valid() on unclaimed board
## jobs, which builds a driver for jobs that may never run, so "the job always
## ends and ends break the cycle" is not a defence.) The job is passed into every
## hook instead.
##
## Stateless also means a driver holds nothing worth saving, which is why the
## save format stores an action index and not a driver snapshot.

## The step sequence, in order.
##
## MUST BE DETERMINISTIC. The save format stores an integer index into this
## array, so the same JobData + the same targets have to produce the same list
## every time, including after a load. Don't branch on anything that changes
## between save and load (time of day, a component's current stock, RNG) - put
## that in an action's on_start() or in next_index_after() instead.
##
## Job stores a cheap signature of the returned list and refuses to resume a
## saved index whose signature no longer matches, so a code change between save
## and load drops the job cleanly rather than resuming into the wrong step.
func make_actions(_job: Job) -> Array[ActionBase]:
	return [] as Array[ActionBase]

## Board-level "is this job still worth existing".
## Checked by JobManager before handing the job out, and by the runner every
## frame as the global fail condition. Runs on UNCLAIMED jobs too, so it must not
## assume job.pawn is set.
func is_valid(_job: Job) -> bool:
	return true

## Per-pawn claimability. Must stay a pure query:
## it runs against every candidate job for every idle pawn.
func can_do(_job: Job, _pawn: PawnBase) -> bool:
	return true

## Why can_do() said no, for the board inspector. Called on demand for a single
## selected pawn, never per frame, so it can afford to be more thorough than
## can_do() - but it must not have side effects either.
func explain_block(_job: Job, _pawn: PawnBase) -> String:
	return ""

## The claims that must be held for the action at `action_index` to mean
## anything. Claims are deliberately NOT saved (derived state is re-derived), but
## a saved action index points PAST the actions that took them: a pawn resuming
## mid-sleep is at "restore need", and the claim-the-bed step already ran. Job
## re-acquires this list on load before resuming, and drops the job cleanly if it
## can't - which is strictly better than the pre-WI-44 behaviour of restarting
## the whole job from its first step.
##
## Return the claims needed at that index, cumulatively (a job at index 4 usually
## still holds what it took at index 0).
func required_claims(_job: Job, _action_index: int) -> Array[ClaimSpec]:
	return [] as Array[ClaimSpec]

## Which action runs after the one at `finished`. The default is "the next one",
## and most jobs never override it.
##
## This is the typed replacement for RimWorld's JumpToToil. A branch or a loop is
## an integer - serializable, greppable, and unable to desynchronise from the
## saved index the way a lambda mutating driver state would. Use
## job.index_of_label(&"...") rather than hardcoding numbers.
## Returning a value outside the array ends the job successfully.
func next_index_after(_job: Job, finished: int) -> int:
	return finished + 1

## The skill this job's work is gated by and grants xp to. Defaults to the type's
## JobData.skill; overridden where the skill is a property of the TARGET rather
## than the job type - each processor names its own worker_skill, so a bakery and
## a smelter running the same job type train different things.
func skill(job: Job) -> StringName:
	return job.data.skill if job.data != null else &""

## Last chance to react to the job ending, after the current action's on_finish
## but before claims are released. Rarely needed - most teardown belongs to the
## action that set the thing up.
func on_job_end(_job: Job, _outcome: Job.Outcome) -> void:
	pass
