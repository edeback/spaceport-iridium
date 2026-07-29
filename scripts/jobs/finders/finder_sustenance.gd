class_name Finder_Sustenance
extends TargetFinder

## Somewhere with food in it (WI-44).
##
## The one need-provider search that is NOT a Finder_FreeSlotComponent: a
## sustenance pool has no slots (any number of pawns can eat from it) and its tie
## break is about how much food is left, not how close it is. A place holding a
## whole meal always beats one holding a mouthful, however far away - and only
## among places that cannot serve a full portion does the fullest win. That is
## Job_Eat.find_best_sustenance's rule, kept exactly.

## Portion size the search is trying to satisfy; matches Action_Eat's default.
@export var desired: int = 70

func _init(desired_sustenance: int = 70) -> void:
	desired = desired_sustenance

func find(_job: Job, pawn: PawnBase) -> JobTarget:
	var best_full: SustenanceComponent = null
	var best_full_distance: float = 0.0
	var best_partial: SustenanceComponent = null
	var best_partial_amount: int = -1
	var best_partial_distance: float = 0.0
	var origin: Vector2i = Global.world_to_cell(pawn.global_position)
	for node: Node in pawn.get_tree().get_nodes_in_group(Groups.SUSTENANCE_COMPONENT):
		var sustenance: SustenanceComponent = node as SustenanceComponent
		# can_serve gates visitors behind the crew-priority reserve (WI-33); crew
		# are served whenever there is any food at all.
		if sustenance == null or sustenance.owner_module == null or not sustenance.can_serve(pawn):
			continue
		if not Global.path_manager.is_reachable(pawn, sustenance.owner_module):
			continue
		var distance: float = Vector2(sustenance.owner_module.module_cell - origin).length()
		if sustenance.sustenance_available >= desired:
			if best_full == null or distance < best_full_distance:
				best_full = sustenance
				best_full_distance = distance
		elif sustenance.sustenance_available > best_partial_amount \
				or (sustenance.sustenance_available == best_partial_amount and distance < best_partial_distance):
			best_partial = sustenance
			best_partial_amount = sustenance.sustenance_available
			best_partial_distance = distance
	var chosen: SustenanceComponent = best_full if best_full != null else best_partial
	return JobTarget.of_component(chosen) if chosen != null else null

func describe() -> String:
	return "somewhere to eat"
