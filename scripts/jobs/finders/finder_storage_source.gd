class_name Finder_StorageSource
extends TargetFinder

## The bin to take this job's resource OUT of.
##
## A thin wrapper over StorageQuery.find_source - deliberately thin. WI-40 just
## finished collapsing four copies of this scoring into one place, and the
## strict directional priority filter that stops a haul flip-flopping between two
## equal-priority bins lives there. Do not reimplement any of it here.

## Slot holding the DESTINATION, whose priority is the ceiling a source must sit
## strictly below. Unset = no filter (a pile sweep has no priority of its own).
## The ceiling is what the destination receives THIS resource at, not its raw
## `priority` field - see [method StorageQuery.source_qualifies].
@export var sink_slot: JobTarget.Slot = JobTarget.Slot.B

func find(job: Job, pawn: PawnBase) -> JobTarget:
	if job.resource == null:
		return null
	var ceiling: int = StorageQuery.ANY_PRIORITY
	var sink: JobTarget = job.target(sink_slot)
	if sink != null and sink.is_alive():
		var sink_storage: StorageComponent = sink.component() as StorageComponent
		if sink_storage != null:
			ceiling = sink_storage.import_priority(job.resource)
	var found: StorageComponent = StorageQuery.find_source(
		pawn, job.resource, StorageQuery.trip_cap(pawn, job.count), ceiling)
	return JobTarget.of_component(found) if found != null else null

func describe() -> String:
	return "a storage holding it"
