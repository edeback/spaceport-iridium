class_name JobDriver_Recreate
extends JobDriver

## Take a break (WI-44) - the replacement for Job_Recreate, and the template for
## the other six need jobs.
##
## Target A is the recreation provider. The driver is four shared actions and a
## finder; everything that used to be specific to this job - the slot claim and
## its release, the movement one-shot, the module-removed handler, the state
## enum, the save pair - is gone.
##
## One behaviour is deliberately NOT carried over: the old job's "if the chosen
## provider fills up before the pawn commits, fall back to the rest of the pool"
## retry loop. The claim now happens BEFORE the walk and the provider is picked
## from those that currently have a free slot, so the window that retry covered
## is much narrower; if it turns out to matter, it is a next_index_after() jump
## back to the finder rather than a hand-rolled loop.

const FIND: int = 0
const CLAIM: int = 1
const GOTO: int = 2
const RESTORE: int = 3

## Matches Job_Recreate.max_stay_hours - leave even if not fully restored, so
## pawns don't park in the holodeck all cycle when the rate barely beats decay.
const MAX_STAY_HOURS: float = 3.0

func make_actions(_job: Job) -> Array[ActionBase]:
	return [
		Action_FindBestTarget.new(Finder_RecreationProvider.new(), JobTarget.Slot.A),
		Action_ClaimSlot.new(JobTarget.Slot.A),
		Action_GotoTarget.new(JobTarget.Slot.A),
		Action_RestoreNeed.new(&"recreation", JobTarget.Slot.A, MAX_STAY_HOURS),
	] as Array[ActionBase]

## A needs job is posted straight onto the pawn's personal queue with no target,
## so validity is just "is there anywhere to go" - answered by the finder.
func can_do(job: Job, pawn: PawnBase) -> bool:
	var existing: JobTarget = job.target_a
	if existing != null and existing.is_alive():
		return true
	return Finder_RecreationProvider.new().find(job, pawn) != null

func explain_block(_job: Job, _pawn: PawnBase) -> String:
	return "no reachable recreation with a free slot"

## The slot is taken at CLAIM and held for the rest of the job, so a restored
## session re-takes it before resuming - or drops cleanly if someone else sat
## down during the load.
func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if action_index <= CLAIM:
		return out
	var provider: ComponentBase = job.target_a.component() if job.target_a != null and job.target_a.is_alive() else null
	if provider != null and provider.has_method(&"claim_pool"):
		out.append(ClaimSpec.make(provider.call(&"claim_pool"), ClaimSpec.Kind.SLOT, 1))
	return out
