class_name JobDriver_Repair
extends JobDriver

## Repairing a damaged module (WI-44) - the replacement for Job_Repair.
##
## Target A is the module itself (not a component - repair is module-level work).
## Two steps: walk to the WORKSTATION anchor if the module authors one, then
## repair until nothing is left to fix.

const GOTO: int = 0
const REPAIR: int = 1

func make_actions(_job: Job) -> Array[ActionBase]:
	return [
		Action_GotoAnchor.new(JobTarget.Slot.A, AnchorDef.AnchorType.WORKSTATION),
		Action_Repair.new(JobTarget.Slot.A),
	] as Array[ActionBase]

## Alive while the module still exists, is built, and has something to fix.
func is_valid(job: Job) -> bool:
	var module: ModuleBase = _module(job)
	return module != null and module.is_complete() and module.needs_repair()

func can_do(job: Job, pawn: PawnBase) -> bool:
	if not is_valid(job):
		return false
	var module: ModuleBase = _module(job)
	if Global.path_manager.is_reachable(pawn, module):
		return true
	# Exterior wreckage (truss, an ex-module cell) is reached by EVA, matching how
	# construction reaches a site.
	return Global.path_manager.is_exterior(module) and Global.path_manager.is_space_reachable(pawn)

func explain_block(job: Job, pawn: PawnBase) -> String:
	var module: ModuleBase = _module(job)
	if module == null:
		return "the module is gone"
	if not module.is_complete():
		return "the module isn't built yet"
	if not module.needs_repair():
		return "nothing left to repair"
	return "%s can't reach it" % pawn.pawn_name

## The workstation anchor, from the walk onward. Null-anchor modules (exterior
## wreckage authors none) still claim, and the claim simply carries no anchor.
func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if action_index <= GOTO:
		return out
	var module: ModuleBase = _module(job)
	if module == null:
		return out
	var path: PathComponent = module.get_path_component()
	if path != null:
		out.append(ClaimSpec.make(path.anchor_pool(AnchorDef.AnchorType.WORKSTATION),
			ClaimSpec.Kind.ANCHOR, 1))
	return out

func _module(job: Job) -> ModuleBase:
	if job.target_a == null or not job.target_a.is_alive():
		return null
	return job.target_a.module()
