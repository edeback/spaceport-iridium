class_name JobDriver_GetTreatment
extends JobDriver

## Check into the medical bay (WI-44) - the replacement for the treatment job.
##
## Target A is the MedicalComponent. Same four-step shape as sleeping - find,
## claim the bunk, walk to the BUNK anchor, then hold - because it is the same
## shape: the only genuinely different part is what accrues while lying there,
## and that is Action_Treat's business.

const FIND: int = 0
const CLAIM: int = 1
const GOTO: int = 2
const TREAT: int = 3

func make_actions(_job: Job) -> Array[ActionBase]:
	return [
		Action_FindBestTarget.new(Finder_MedicalBay.new(), JobTarget.Slot.A),
		Action_ClaimSlot.new(JobTarget.Slot.A),
		Action_GotoAnchor.new(JobTarget.Slot.A, AnchorDef.AnchorType.BUNK),
		Action_Treat.new(JobTarget.Slot.A),
	] as Array[ActionBase]

func can_do(job: Job, pawn: PawnBase) -> bool:
	var existing: JobTarget = job.target_a
	if existing != null and existing.is_alive():
		return true
	return Finder_MedicalBay.new().find(job, pawn) != null

func explain_block(_job: Job, _pawn: PawnBase) -> String:
	return "no reachable powered medical bay with a free bunk"

## Bunk and anchor, held from CLAIM/GOTO onward. A restored patient re-takes both
## before resuming; failing to means the job drops and the disease component's
## seek loop queues another attempt.
func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if job.target_a == null or not job.target_a.is_alive():
		return out
	var medical: ComponentBase = job.target_a.component()
	if medical == null:
		return out
	if action_index > CLAIM and medical.has_method(&"claim_pool"):
		out.append(ClaimSpec.make(medical.call(&"claim_pool"), ClaimSpec.Kind.SLOT, 1))
	if action_index > GOTO and medical.owner_module != null:
		var path: PathComponent = medical.owner_module.get_path_component()
		if path != null:
			out.append(ClaimSpec.make(path.anchor_pool(AnchorDef.AnchorType.BUNK),
				ClaimSpec.Kind.ANCHOR, 1))
	return out
