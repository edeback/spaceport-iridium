class_name Finder_MiningOutput
extends TargetFinder

## Where a mining bay wants its ore put (WI-44).
##
## Derived from the bay rather than carried as a third target set at post time,
## so a bay whose output storage is re-pointed between trips is honoured on the
## next one without the in-flight job holding a stale reference.

@export var bay_slot: JobTarget.Slot = JobTarget.Slot.B

func find(job: Job, _pawn: PawnBase) -> JobTarget:
	var bay: JobTarget = job.target(bay_slot)
	if bay == null or not bay.is_alive():
		return null
	var mining: MiningComponent = bay.component() as MiningComponent
	if mining == null or mining.output_storage == null or not is_instance_valid(mining.output_storage):
		return null
	return JobTarget.of_component(mining.output_storage)

func describe() -> String:
	return "the mining bay's storage"
