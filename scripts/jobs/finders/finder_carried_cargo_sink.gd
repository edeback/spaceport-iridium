class_name Finder_CarriedCargoSink
extends TargetFinder

## Any bin that will take something the pawn is currently carrying (WI-44).
##
## Deliberately unfiltered by priority. A sweep has no source bin to compare
## against, and a loaded pawn must accept ANY bin that will take the cargo rather
## than strand itself holding goods nothing will receive - the asymmetry that
## StorageQuery.find_sink() documents.

func find(job: Job, pawn: PawnBase) -> JobTarget:
	if pawn == null or pawn.inventory_component == null or pawn.inventory_component.is_empty():
		return null
	# A sweep pre-aimed at a bin (a mining drone's own bay) keeps it while it still
	# has room for something carried. find_sink() rightly refuses that bay - its
	# slots are OUTPUT, not somewhere haulers deliver - and JobDriver_StoreInventory
	# .can_do() asks this finder directly rather than through Action_FindBestTarget's
	# skip-a-resolved-slot, so without this the pre-aim only held when some OTHER
	# bin happened to have room as well.
	var aimed: StorageComponent = _aimed_bin(job)
	if aimed != null:
		for resource: ResourceData in pawn.inventory_component.get_carried_resources():
			if pawn.inventory_component.get_carried_amount(resource) > 0 \
					and aimed.room_for(resource, true) > 0:
				return job.target_a
	for resource: ResourceData in pawn.inventory_component.get_carried_resources():
		if pawn.inventory_component.get_carried_amount(resource) <= 0:
			continue
		var sink: StorageComponent = StorageQuery.find_sink(pawn, resource)
		if sink != null:
			return JobTarget.of_component(sink)
	return null

func _aimed_bin(job: Job) -> StorageComponent:
	if job == null or job.target_a == null or not job.target_a.is_alive():
		return null
	return job.target_a.component() as StorageComponent

func describe() -> String:
	return "somewhere to put this down"
