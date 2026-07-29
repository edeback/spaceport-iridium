class_name Finder_CarriedCargoSink
extends TargetFinder

## Any bin that will take something the pawn is currently carrying (WI-44).
##
## Deliberately unfiltered by priority. A sweep has no source bin to compare
## against, and a loaded pawn must accept ANY bin that will take the cargo rather
## than strand itself holding goods nothing will receive - the asymmetry that
## StorageQuery.find_sink() documents.

func find(_job: Job, pawn: PawnBase) -> JobTarget:
	if pawn == null or pawn.inventory_component == null or pawn.inventory_component.is_empty():
		return null
	for resource: ResourceData in pawn.inventory_component.get_carried_resources():
		if pawn.inventory_component.get_carried_amount(resource) <= 0:
			continue
		var sink: StorageComponent = StorageQuery.find_sink(pawn, resource)
		if sink != null:
			return JobTarget.of_component(sink)
	return null

func describe() -> String:
	return "somewhere to put this down"
