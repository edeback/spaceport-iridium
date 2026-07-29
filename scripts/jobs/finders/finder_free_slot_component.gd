class_name Finder_FreeSlotComponent
extends TargetFinder

## "The nearest reachable component of this kind that has a free slot and will
## take this pawn" (WI-44).
##
## This is the one that earns its keep. Before WI-44, seven job classes each
## carried their own copy of this walk - Job_Sleep._find_pod,
## Job_Recharge._find_charger, Job_GetRepaired._find_bay,
## Job_GetTreatment._find_bay, Job_Eat.find_best_sustenance, and
## _gather_candidates in both Job_Recreate and Job_Shop - all differing only in
## which group they scanned and how they broke ties. Subclasses override the two
## hooks; everything else is shared.
##
## Only Job_Sleep had the desirability tolerance band (adjacency-driven bunk
## quality, WI-30); putting it here hands it to all seven.

## Which group to scan. Set by the subclass or at construction.
@export var group: StringName = &""
## Candidates within this many cells of the nearest are treated as equally close,
## so a nicer option can win without sending the pawn on a station-crossing trek.
## Zero = strictly nearest.
@export var distance_tolerance: float = 0.0
## Pick at random among the acceptable candidates instead of scoring them. What
## Job_Recreate did deliberately, so pawns spread across the available options.
@export var pick_randomly: bool = false

func _init(scan_group: StringName = &"", tolerance: float = 0.0, random: bool = false) -> void:
	group = scan_group
	distance_tolerance = tolerance
	pick_randomly = random

## Extra per-candidate filter beyond "has a free slot and is reachable" - a hotel
## room taking visitors only, a charger with no power, a provider whose rate has
## dropped to zero. Return false to skip.
func accepts(_job: Job, _pawn: PawnBase, _candidate: ComponentBase) -> bool:
	return true

## Higher is better, among candidates inside the tolerance band. Default 0 makes
## it a pure nearest-wins search.
func desirability(_job: Job, _pawn: PawnBase, _candidate: ComponentBase) -> float:
	return 0.0

func find(job: Job, pawn: PawnBase) -> JobTarget:
	if group == &"" or pawn == null:
		return null
	var candidates: Array[ComponentBase] = []
	var distances: PackedFloat32Array = []
	var nearest: float = -1.0
	var origin: Vector2i = Global.world_to_cell(pawn.global_position)
	for node: Node in pawn.get_tree().get_nodes_in_group(group):
		var candidate: ComponentBase = node as ComponentBase
		if candidate == null or candidate.owner_module == null:
			continue
		if not _has_free_slot(candidate):
			continue
		if not accepts(job, pawn, candidate):
			continue
		if not Global.path_manager.is_reachable(pawn, candidate.owner_module):
			continue
		var distance: float = Vector2(candidate.owner_module.module_cell - origin).length()
		candidates.append(candidate)
		distances.append(distance)
		if nearest < 0.0 or distance < nearest:
			nearest = distance
	if candidates.is_empty():
		return null
	if pick_randomly:
		return JobTarget.of_component(candidates.pick_random())
	# Second pass: among the comparably-close band, most desirable wins; ties
	# fall back to distance so the result stays deterministic.
	var best: ComponentBase = null
	var best_desire: float = 0.0
	var best_distance: float = 0.0
	for i: int in candidates.size():
		if distances[i] > nearest + distance_tolerance:
			continue
		var desire: float = desirability(job, pawn, candidates[i])
		if best == null or desire > best_desire \
				or (is_equal_approx(desire, best_desire) and distances[i] < best_distance):
			best = candidates[i]
			best_desire = desire
			best_distance = distances[i]
	return JobTarget.of_component(best) if best != null else null

## Duck-typed rather than a shared base class: the five slot components don't
## share one (ShopComponent descends from RecreationProviderComponent, the rest
## are siblings under ComponentBase).
func _has_free_slot(candidate: ComponentBase) -> bool:
	if not candidate.has_method(&"has_free_slot"):
		return false
	return bool(candidate.call(&"has_free_slot"))

func describe() -> String:
	return "somewhere free"
