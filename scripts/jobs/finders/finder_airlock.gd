class_name Finder_Airlock
extends TargetFinder

## The nearest reachable airlock to change in (WI-67).
##
## Not a Finder_FreeSlotComponent: an airlock has no occupancy to book. Any number
## of crew can be changing at once, deliberately - slot contention here would turn
## a safety mechanism into a traffic jam, and a suit is not an item that can run
## out (the brief is explicit that suits cost nothing).
##
## Nearest-wins with no tolerance band, for the same reason Finder_MedicalBay has
## none: somebody who is suffocating should not walk past a working airlock to
## reach a marginally closer one.

## Taking a suit OFF needs the airlock to be fit to stand in unsuited; putting one
## ON accepts any airlock at all, because you can always climb into a suit. That
## asymmetry is the brief's, and it is why this flag exists rather than two finder
## classes differing in one predicate.
@export var require_habitable: bool = false

func _init(needs_habitable: bool = false) -> void:
	require_habitable = needs_habitable

func find(_job: Job, pawn: PawnBase) -> JobTarget:
	var best: ModuleBase = null
	var best_distance: float = 0.0
	var origin: Vector2i = Global.world_to_cell(pawn.global_position)
	for node: Node in pawn.get_tree().get_nodes_in_group(Groups.AIRLOCK):
		var module: ModuleBase = node as ModuleBase
		if module == null or not module.is_complete():
			continue
		if not Global.path_manager.is_reachable(pawn, module):
			continue
		if require_habitable and not is_habitable(pawn, module):
			continue
		var distance: float = Vector2(module.module_cell - origin).length()
		if best == null or distance < best_distance:
			best = module
			best_distance = distance
	return JobTarget.of_module(best) if best != null else null

## Is this airlock somewhere `pawn` could stand without a suit?
##
## Static and shared with Action_ChangeSuit, which re-asks at the moment of the
## change: conditions can turn during the walk, and a pawn must not strip in an
## airlock that has vented since they set out.
##
## Both callers pass a live module or null - the group scan above, and
## [method JobTarget.module], which answers null for a dead target - so the null
## check is the whole of the guarantee (WI-71 §2c).
static func is_habitable(pawn: PawnBase, module: ModuleBase) -> bool:
	var suit: PawnSuitComponent = pawn.get_component_by_type(PawnSuitComponent) as PawnSuitComponent
	if suit == null or module == null:
		return false
	var atmosphere: AtmosphereComponent = null
	if Global.atmosphere_manager != null:
		atmosphere = Global.atmosphere_manager.get_component(module)
	var heat: HeatComponent = null
	if Global.heat_manager != null:
		heat = Global.heat_manager.get_component(module)
	return SuitRules.classify(
		atmosphere.o2_partial() if atmosphere != null else 0.0,
		heat.temperature_f if heat != null else HeatMath.NEUTRAL_TEMPERATURE_F,
		suit.thresholds(), atmosphere != null, heat != null) == SuitRules.RoomState.HABITABLE

func describe() -> String:
	return "a habitable airlock" if require_habitable else "an airlock"
