class_name Action_ClaimSlot
extends ActionBase

## Take the occupancy slot on the component in a target slot (WI-44). Instant.
##
## Replaces the claim_slot()/release_slot() pairs that six job classes each
## hand-wrote, always with the release in _on_end so it couldn't leak. The
## release is now the runner's job and happens on every termination path without
## anything here having to remember it - which is the entire point of the claim
## registry.

@export var slot: JobTarget.Slot = JobTarget.Slot.A

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A) -> void:
	slot = target_slot
	complete_mode = CompleteMode.INSTANT

func on_start(job: Job) -> Status:
	var pool: SlotPool = _pool(job)
	if pool == null:
		return Status.FAILED
	return Status.DONE if job.claim(pool, ClaimSpec.Kind.SLOT, 1) != null else Status.FAILED

func report(_job: Job) -> String:
	return ""

func _pool(job: Job) -> SlotPool:
	var slot_target: JobTarget = job.target(slot)
	if slot_target == null or not slot_target.is_alive():
		return null
	var component: ComponentBase = slot_target.component()
	if component == null or not component.has_method(&"claim_pool"):
		return null
	return component.call(&"claim_pool") as SlotPool
