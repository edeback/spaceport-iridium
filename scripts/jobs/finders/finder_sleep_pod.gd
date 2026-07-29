class_name Finder_SleepPod
extends Finder_FreeSlotComponent

## A free bunk this pawn is allowed to use (WI-44).
##
## The desirability band is the reason Finder_FreeSlotComponent has one at all:
## pods within a few cells of the nearest are treated as equally close, so
## adjacency quality (quiet, greenery - WI-30) can pick between them without
## sending a tired pawn on a station-crossing trek for a marginally nicer bed.

## Matches Job_Sleep.desirability_distance_tolerance.
const TOLERANCE: float = 3.0

func _init(_unused_group: StringName = &"", _tolerance: float = 0.0, _random: bool = false) -> void:
	super(Groups.SLEEP_COMPONENT, TOLERANCE, false)

## Hotel rooms take visitors only, crew pods take crew only (WI-33). This is the
## rule that keeps crew out of paid rooms and guests out of the bunkhouse.
func accepts(_job: Job, pawn: PawnBase, candidate: ComponentBase) -> bool:
	var pod: SleepComponent = candidate as SleepComponent
	return pod != null and pod.accepts(pawn)

func desirability(_job: Job, _pawn: PawnBase, candidate: ComponentBase) -> float:
	var pod: SleepComponent = candidate as SleepComponent
	return pod.desirability() if pod != null else 0.0

func describe() -> String:
	return "a free bunk"
