class_name JobDriver_Doctor
extends JobDriver

## Staffing a medical bay (WI-44) - the replacement for the doctor job.
##
## Target A is the MedicalComponent. The doctor occupies a WORKSTATION, not a
## treatment bunk, so this claims an anchor but no slot - the beds belong to the
## patients.

const GOTO: int = 0
const TEND: int = 1

func make_actions(_job: Job) -> Array[ActionBase]:
	return [
		Action_GotoAnchor.new(JobTarget.Slot.A, AnchorDef.AnchorType.WORKSTATION),
		Action_Doctor.new(JobTarget.Slot.A),
	] as Array[ActionBase]

func is_valid(job: Job) -> bool:
	var medical: MedicalComponent = _medical(job)
	return medical != null and is_instance_valid(medical.owner_module) \
		and medical.has_patients() and medical.powered()

func can_do(job: Job, pawn: PawnBase) -> bool:
	if not is_valid(job):
		return false
	var medical: MedicalComponent = _medical(job)
	# The sole doctor can't also be one of the patients (WI-31 edge case).
	# NOTE: is_patient() still walks the LEGACY claims array - see the coexistence
	# gaps in the WI - so this under-reports until the treatment job converts.
	if medical.is_patient(pawn):
		return false
	var workspace: WorkspaceComponent = _workspace(job)
	if workspace != null and not workspace.allows(pawn):
		return false
	return Global.path_manager.is_reachable(pawn, medical.owner_module)

func explain_block(job: Job, pawn: PawnBase) -> String:
	var medical: MedicalComponent = _medical(job)
	if medical == null:
		return "the medical bay is gone"
	if not medical.powered():
		return "the medical bay has no power"
	if not medical.has_patients():
		return "nobody needs treating"
	if medical.is_patient(pawn):
		return "%s is a patient here" % pawn.pawn_name
	var workspace: WorkspaceComponent = _workspace(job)
	if workspace != null and not workspace.allows(pawn):
		return "%s isn't assigned to this workspace" % pawn.pawn_name
	return "%s can't reach it" % pawn.pawn_name

func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if action_index <= GOTO:
		return out
	var medical: MedicalComponent = _medical(job)
	if medical == null or medical.owner_module == null:
		return out
	var path: PathComponent = medical.owner_module.get_path_component()
	if path != null:
		out.append(ClaimSpec.make(path.anchor_pool(AnchorDef.AnchorType.WORKSTATION),
			ClaimSpec.Kind.ANCHOR, 1))
	return out

func _medical(job: Job) -> MedicalComponent:
	if job.target_a == null or not job.target_a.is_alive():
		return null
	return job.target_a.component() as MedicalComponent

func _workspace(job: Job) -> WorkspaceComponent:
	var medical: MedicalComponent = _medical(job)
	if medical == null or medical.owner_module == null:
		return null
	return medical.owner_module.get_component_by_type(WorkspaceComponent) as WorkspaceComponent
