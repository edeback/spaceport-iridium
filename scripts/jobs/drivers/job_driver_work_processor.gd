class_name JobDriver_WorkProcessor
extends JobDriver

## Operating a manned processor (WI-44) - the replacement for Job_WorkProcessor.
##
## Target A is the ProcessorComponent.
##
## The interesting change is batch chaining. The old job finished, built a
## FOLLOWUP job, handed it to the processor via adopt_followup_work_job() so the
## component wouldn't post a duplicate during the swap, and pushed it onto the
## pawn's queue - all resolved synchronously to dodge a _process ordering race.
## Here it is simply a LOOP: next_index_after() sends the runner back to the work
## step. The job never ends, so there is no handoff, no window for a duplicate,
## and no race to dodge.

const CLAIM: int = 0
const GOTO: int = 1
const WORK: int = 2

func make_actions(_job: Job) -> Array[ActionBase]:
	return [
		# Capacity-1 pool: one operator per machine.
		Action_ClaimSlot.new(JobTarget.Slot.A),
		Action_GotoAnchor.new(JobTarget.Slot.A, AnchorDef.AnchorType.WORKSTATION),
		Action_OperateProcessor.new(JobTarget.Slot.A),
	] as Array[ActionBase]

## Each processor names its own worker skill, so a bakery and a smelter running
## this same job type train different things.
func skill(job: Job) -> StringName:
	var processor: ProcessorComponent = _processor(job)
	return processor.worker_skill if processor != null else &"crafting"

## Alive while there is work to do. Deliberately not tied to `processing` alone,
## so the job survives the moment between batches.
func is_valid(job: Job) -> bool:
	var processor: ProcessorComponent = _processor(job)
	if processor == null or not is_instance_valid(processor.owner_module):
		return false
	if not (processor.has_active_batch() or processor.can_ready_batch()):
		return false
	return processor.power_consumer == null or processor.power_consumer.powered

func can_do(job: Job, pawn: PawnBase) -> bool:
	if not is_valid(job):
		return false
	var workspace: WorkspaceComponent = _workspace(job)
	if workspace != null and not workspace.allows(pawn):
		return false
	return Global.path_manager.is_reachable(pawn, _processor(job).owner_module)

func explain_block(job: Job, pawn: PawnBase) -> String:
	var processor: ProcessorComponent = _processor(job)
	if processor == null:
		return "the machine is gone"
	if processor.power_consumer != null and not processor.power_consumer.powered:
		return "the machine has no power"
	if not (processor.has_active_batch() or processor.can_ready_batch()):
		return "no batch ready and no materials to start one"
	var workspace: WorkspaceComponent = _workspace(job)
	if workspace != null and not workspace.allows(pawn):
		return "%s isn't assigned to this workspace" % pawn.pawn_name
	if not Global.path_manager.is_reachable(pawn, processor.owner_module):
		return "%s can't reach it" % pawn.pawn_name
	return ""

## Keep working the same machine batch after batch, rather than ending and being
## re-picked. The conditions are the old _build_followup()'s, unchanged.
func next_index_after(job: Job, finished: int) -> int:
	if finished == WORK and _should_keep_working(job):
		return WORK
	return finished + 1

func _should_keep_working(job: Job) -> bool:
	var pawn: PawnBase = job.pawn
	if pawn == null or not is_valid(job):
		return false
	if not pawn.is_on_shift():
		return false
	# Queued needs (eat, sleep) outrank chaining another batch - let them run.
	if not pawn.job_queue.is_empty():
		return false
	var workspace: WorkspaceComponent = _workspace(job)
	if workspace != null and not workspace.allows(pawn):
		return false
	return Global.path_manager.is_reachable(pawn, _processor(job).owner_module)

## The operator slot from CLAIM onward, the workstation anchor from GOTO onward.
func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	var processor: ProcessorComponent = _processor(job)
	if processor == null:
		return out
	if action_index > CLAIM:
		out.append(ClaimSpec.make(processor.claim_pool(), ClaimSpec.Kind.SLOT, 1))
	if action_index > GOTO and processor.owner_module != null:
		var path: PathComponent = processor.owner_module.get_path_component()
		if path != null:
			out.append(ClaimSpec.make(path.anchor_pool(AnchorDef.AnchorType.WORKSTATION),
				ClaimSpec.Kind.ANCHOR, 1))
	return out

func _processor(job: Job) -> ProcessorComponent:
	if job.target_a == null or not job.target_a.is_alive():
		return null
	return job.target_a.component() as ProcessorComponent

## Read off the module rather than job.workspace so the gate is correct even if
## whoever posted the job forgot to set it. Posters should still assign
## job.workspace, since that is what drives the assignee priority bonus (WI-23).
func _workspace(job: Job) -> WorkspaceComponent:
	var processor: ProcessorComponent = _processor(job)
	if processor == null or processor.owner_module == null:
		return null
	return processor.owner_module.get_component_by_type(WorkspaceComponent) as WorkspaceComponent
