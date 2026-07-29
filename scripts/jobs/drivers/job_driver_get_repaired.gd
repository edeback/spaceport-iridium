class_name JobDriver_GetRepaired
extends JobDriver

## A damaged drone getting patched up (WI-44) - the replacement for
## Job_GetRepaired. Same four steps as recharging, pointed at the integrity
## channel on RobotIntegrityComponent.
##
## Note this is the drone being WORKED ON, not doing the work: no skill, no xp.

const FIND: int = 0
const CLAIM: int = 1
const GOTO: int = 2
const REPAIR: int = 3

func make_actions(_job: Job) -> Array[ActionBase]:
	return [
		Action_FindBestTarget.new(Finder_RobotRepairBay.new(), JobTarget.Slot.A),
		Action_ClaimSlot.new(JobTarget.Slot.A),
		Action_GotoTarget.new(JobTarget.Slot.A),
		Action_RestoreNeed.new(&"integrity", JobTarget.Slot.A, 0.0, &"", &"integrity", &"integrity_max"),
	] as Array[ActionBase]

func can_do(job: Job, pawn: PawnBase) -> bool:
	var existing: JobTarget = job.target_a
	if existing != null and existing.is_alive():
		return true
	return Finder_RobotRepairBay.new().find(job, pawn) != null

func explain_block(_job: Job, _pawn: PawnBase) -> String:
	return "no reachable powered repair bay with a free slot"

func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if action_index <= CLAIM or job.target_a == null or not job.target_a.is_alive():
		return out
	var bay: ComponentBase = job.target_a.component()
	if bay != null and bay.has_method(&"claim_pool"):
		out.append(ClaimSpec.make(bay.call(&"claim_pool"), ClaimSpec.Kind.SLOT, 1))
	return out
