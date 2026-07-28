class_name Finder_StorageSink
extends TargetFinder

## The bin to put this job's resource INTO. Wrapper over StorageQuery.find_sink -
## see Finder_StorageSource for why these stay thin.

## Slot holding the SOURCE, whose priority is the floor a sink must sit strictly
## above. Unset = no filter, which is the deliberate case for a pile collection or
## a carried-cargo sweep: a pawn holding goods must accept ANY bin that will take
## them rather than stranding itself.
@export var source_slot: JobTarget.Slot = JobTarget.Slot.A

func find(job: Job, pawn: PawnBase) -> JobTarget:
	if job.resource == null:
		return null
	var floor_priority: int = StorageQuery.ANY_PRIORITY
	var source: JobTarget = job.target(source_slot)
	if source != null and source.is_alive():
		var source_storage: StorageComponent = source.component() as StorageComponent
		if source_storage != null:
			floor_priority = source_storage.priority
	var found: StorageComponent = StorageQuery.find_sink(pawn, job.resource, floor_priority)
	return JobTarget.of_component(found) if found != null else null

func describe() -> String:
	return "a storage with room for it"
