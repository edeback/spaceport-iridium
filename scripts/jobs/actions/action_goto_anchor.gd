class_name Action_GotoAnchor
extends ActionBase

## Claim an anchor of a given type on the target's module and walk to it (WI-44)
## - the bunk in a sleeping pod, the workstation in a processor bay.
##
## Replaces the claim_anchor/release_anchor pairs that four job classes each
## hand-wrote, always with the release in _on_end so it couldn't leak. The
## release is the runner's job now.
##
## Anchor scarcity never blocks movement: if the module has no free anchor of
## this type (or none authored at all), the claim still succeeds with an empty
## holder and the pawn walks to the module centre, which is PathComponent's
## long-standing contract.

@export var slot: JobTarget.Slot = JobTarget.Slot.A
@export var anchor_type: AnchorDef.AnchorType = AnchorDef.AnchorType.STAND
@export var speed: float = 1.0

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A,
		type: AnchorDef.AnchorType = AnchorDef.AnchorType.STAND) -> void:
	slot = target_slot
	anchor_type = type
	complete_mode = CompleteMode.MOVEMENT

func on_start(job: Job) -> Status:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_alive():
		return Status.FAILED
	var module: ModuleBase = destination.module()
	if module == null:
		return Status.FAILED
	var anchor: AnchorDef = claimed_anchor(job)
	if anchor == null:
		var path: PathComponent = module.get_path_component()
		if path != null:
			var spec: ClaimSpec = job.claim(path.anchor_pool(anchor_type), ClaimSpec.Kind.ANCHOR, 1)
			if spec != null:
				anchor = (spec.payload as AnchorPool.Claim).anchor
	# Already standing in the right module with nothing better to aim at.
	if anchor == null and job.pawn != null and job.pawn.current_module == module:
		return Status.DONE
	# Ask the graph rather than assuming interior: exterior wreckage (truss, an
	# ex-module cell) is reached by EVA, the same way construction reaches a site.
	# Interior modules answer false, so ordinary walks are unchanged.
	var outside: bool = Global.path_manager.is_exterior(module)
	if not job.begin_movement(module, speed, outside, anchor):
		return Status.FAILED
	return Status.ONGOING

## Resuming a walk saved with the pawn (WI-75): claim the anchor that walk was
## heading to rather than whichever is first free, so on_start's begin_movement
## picks the walk up where it stood. Claims are never saved, so the anchor is
## re-taken here; if somebody took it first, on_start claims another and the pawn
## re-paths to that one instead.
func on_resume(job: Job) -> Status:
	var destination: JobTarget = job.target(slot)
	if destination != null and destination.is_alive() and job.pawn != null \
			and job.pawn.movement_component != null and claimed_anchor(job) == null:
		var module: ModuleBase = destination.module()
		var path: PathComponent = module.get_path_component() if module != null else null
		var restored: AnchorDef = job.pawn.movement_component.restored_anchor(module)
		if path != null and restored != null:
			path.anchor_pool(anchor_type).prefer(restored)
	return on_start(job)

## The anchor this job already holds on the target's module, if any. Resume goes
## through here so a re-entered action walks to the SAME bunk rather than
## claiming a second one.
func claimed_anchor(job: Job) -> AnchorDef:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_alive():
		return null
	var module: ModuleBase = destination.module()
	if module == null:
		return null
	var path: PathComponent = module.get_path_component()
	if path == null:
		return null
	var spec: ClaimSpec = job.find_claim(path.anchor_pool(anchor_type), ClaimSpec.Kind.ANCHOR)
	if spec == null:
		return null
	var holder: AnchorPool.Claim = spec.payload as AnchorPool.Claim
	return holder.anchor if holder != null else null

func report(job: Job) -> String:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_set():
		return "Walking"
	return "Walking to " + destination.describe()
