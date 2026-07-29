class_name JobDriver_Shop
extends JobDriver

## Go shopping (WI-44) - the replacement for Job_Shop.
##
## Structurally the recreation driver with one extra step: pay on arrival. Target
## A is the shop, and everything the old job hand-rolled around that - the
## candidate retry loop, the slot claim and its release, the movement one-shot,
## the module-removed handler, the five-state enum - is shared machinery now.
##
## The old job's "if the shop fills up before the customer commits, fall back to
## the rest of the affordable pool" retry is dropped for the same reason
## JobDriver_Recreate dropped it: the slot is claimed BEFORE the walk, so the
## window it covered is much narrower, and reinstating it is a next_index_after()
## jump back to the finder rather than a hand-rolled loop.

const FIND: int = 0
const CLAIM: int = 1
const GOTO: int = 2
const PAY: int = 3
const BROWSE: int = 4

## Matches Job_Shop.max_stay_hours - leave even if not fully restored, so a
## customer doesn't camp the store all cycle.
const MAX_STAY_HOURS: float = 3.0

func make_actions(_job: Job) -> Array[ActionBase]:
	return [
		Action_FindBestTarget.new(Finder_Shop.new(), JobTarget.Slot.A),
		Action_ClaimSlot.new(JobTarget.Slot.A),
		Action_GotoTarget.new(JobTarget.Slot.A),
		Action_Pay.new(JobTarget.Slot.A),
		Action_RestoreNeed.new(&"recreation", JobTarget.Slot.A, MAX_STAY_HOURS),
	] as Array[ActionBase]

func can_do(job: Job, pawn: PawnBase) -> bool:
	var existing: JobTarget = job.target_a
	if existing != null and existing.is_alive():
		return true
	return Finder_Shop.new().find(job, pawn) != null

func explain_block(_job: Job, pawn: PawnBase) -> String:
	if pawn != null and pawn.personal_credits <= 0:
		return "%s has no credits to spend" % pawn.pawn_name
	return "no reachable open shop they can afford"

## The counter is held from CLAIM onward, so a restored visit re-takes it before
## resuming - or drops cleanly if the shop filled during the load.
func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if action_index <= CLAIM:
		return out
	var shop: ComponentBase = job.target_a.component() if job.target_a != null and job.target_a.is_alive() else null
	if shop != null and shop.has_method(&"claim_pool"):
		out.append(ClaimSpec.make(shop.call(&"claim_pool"), ClaimSpec.Kind.SLOT, 1))
	return out
