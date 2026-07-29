class_name JobDriver_Recharge
extends JobDriver

## A drone topping up its batteries (WI-44) - the replacement for Job_Recharge.
##
## Structurally identical to the organic need jobs (find, claim, walk, restore).
## The only difference is where the need lives: a drone has no PawnNeedsComponent,
## so the restore action is pointed at RobotPowerComponent's own energy /
## energy_max instead of the <need>_value convention.

const FIND: int = 0
const CLAIM: int = 1
const GOTO: int = 2
const CHARGE: int = 3

func make_actions(_job: Job) -> Array[ActionBase]:
	return [
		Action_FindBestTarget.new(Finder_Recharger.new(), JobTarget.Slot.A),
		Action_ClaimSlot.new(JobTarget.Slot.A),
		Action_GotoTarget.new(JobTarget.Slot.A),
		Action_RestoreNeed.new(&"energy", JobTarget.Slot.A, 0.0, &"", &"energy", &"energy_max"),
	] as Array[ActionBase]

func can_do(job: Job, pawn: PawnBase) -> bool:
	var existing: JobTarget = job.target_a
	if existing != null and existing.is_alive():
		return true
	return Finder_Recharger.new().find(job, pawn) != null

func explain_block(_job: Job, _pawn: PawnBase) -> String:
	return "no reachable powered charger with a free pad"

func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if action_index <= CLAIM or job.target_a == null or not job.target_a.is_alive():
		return out
	var charger: ComponentBase = job.target_a.component()
	if charger != null and charger.has_method(&"claim_pool"):
		out.append(ClaimSpec.make(charger.call(&"claim_pool"), ClaimSpec.Kind.SLOT, 1))
	return out
