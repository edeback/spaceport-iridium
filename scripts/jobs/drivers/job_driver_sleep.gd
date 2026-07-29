class_name JobDriver_Sleep
extends JobDriver

## Get some sleep (WI-44) - the replacement for the sleep job.
##
## Four shared actions. Notably this is the first driver that needs an ANCHOR as
## well as a slot: the pawn sleeps on the bunk, not at the module centre.
##
## Target A is the sleeping pod (a SleepComponent).

const FIND: int = 0
const CLAIM: int = 1
const GOTO: int = 2
const SLEEP: int = 3

func make_actions(_job: Job) -> Array[ActionBase]:
	return [
		Action_FindBestTarget.new(Finder_SleepPod.new(), JobTarget.Slot.A),
		Action_ClaimSlot.new(JobTarget.Slot.A),
		Action_GotoAnchor.new(JobTarget.Slot.A, AnchorDef.AnchorType.BUNK),
		# No stay cap: a pawn sleeps until rested. The decay loop decides when they
		# next need to. The lay_down pose is a property of this step, not a step of
		# its own - an INSTANT "play animation" action would start and restore the
		# pose in the same frame.
		Action_RestoreNeed.new(&"sleep", JobTarget.Slot.A, 0.0, &"lay_down"),
	] as Array[ActionBase]

func can_do(job: Job, pawn: PawnBase) -> bool:
	var existing: JobTarget = job.target_a
	if existing != null and existing.is_alive():
		return true
	return Finder_SleepPod.new().find(job, pawn) != null

func explain_block(_job: Job, pawn: PawnBase) -> String:
	if pawn != null and pawn.is_visitor:
		return "no free hotel room"
	return "no reachable crew bunk with a free slot"

## Both the bed and the bunk anchor are held from CLAIM/GOTO onward, so a
## restored sleeper re-takes them before resuming - or drops cleanly if someone
## else took the bed while the save was loading, in which case the need re-queues.
func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if job.target_a == null or not job.target_a.is_alive():
		return out
	var pod: ComponentBase = job.target_a.component()
	if pod == null:
		return out
	if action_index > CLAIM and pod.has_method(&"claim_pool"):
		out.append(ClaimSpec.make(pod.call(&"claim_pool"), ClaimSpec.Kind.SLOT, 1))
	if action_index > GOTO and pod.owner_module != null:
		var path: PathComponent = pod.owner_module.get_path_component()
		if path != null:
			out.append(ClaimSpec.make(path.anchor_pool(AnchorDef.AnchorType.BUNK),
				ClaimSpec.Kind.ANCHOR, 1))
	return out

## Bill a visitor's completed hotel night (WI-33) - only on a full night, never an
## early cancel. No-op for crew. This lives on the driver rather than in an action
## because it is a property of the JOB succeeding, not of any one step.
func on_job_end(job: Job, outcome: Job.Outcome) -> void:
	if outcome != Job.Outcome.SUCCEEDED:
		return
	if job.target_a == null or not job.target_a.is_alive():
		return
	var pod: SleepComponent = job.target_a.component() as SleepComponent
	if pod != null and job.pawn != null and is_instance_valid(job.pawn):
		pod.complete_stay(job.pawn)
