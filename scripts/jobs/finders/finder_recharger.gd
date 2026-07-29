class_name Finder_Recharger
extends Finder_FreeSlotComponent

## A powered charger pad with a free slot (WI-44).

func _init(_g: StringName = &"", _t: float = 0.0, _r: bool = false) -> void:
	super(Groups.RECHARGER, 0.0, false)

## An unpowered pad restores nothing - a drone that walked to one would sit there
## forever, which is worse than not going.
func accepts(_job: Job, _pawn: PawnBase, candidate: ComponentBase) -> bool:
	var charger: RechargeComponent = candidate as RechargeComponent
	return charger != null and charger.is_available()

func describe() -> String:
	return "a free charger"
