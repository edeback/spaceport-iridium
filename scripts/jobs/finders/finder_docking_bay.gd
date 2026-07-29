class_name Finder_DockingBay
extends TargetFinder

## The way off the station (WI-44) - the nearest reachable docking bay, by its
## CrewRecruitmentComponent.
##
## Not a Finder_FreeSlotComponent: a docking bay has no occupancy to book. A
## departing pawn walks there and despawns, so any number can leave at once.

func find(_job: Job, pawn: PawnBase) -> JobTarget:
	var best: CrewRecruitmentComponent = null
	var best_distance: float = 0.0
	var origin: Vector2i = Global.world_to_cell(pawn.global_position)
	for node: Node in pawn.get_tree().get_nodes_in_group(Groups.CREW_RECRUITMENT):
		var bay: CrewRecruitmentComponent = node as CrewRecruitmentComponent
		if bay == null or bay.owner_module == null:
			continue
		if not Global.path_manager.is_reachable(pawn, bay.owner_module):
			continue
		var distance: float = Vector2(bay.owner_module.module_cell - origin).length()
		if best == null or distance < best_distance:
			best = bay
			best_distance = distance
	return JobTarget.of_component(best) if best != null else null

func describe() -> String:
	return "a docking bay"
