class_name Finder_RobotRepairBay
extends Finder_FreeSlotComponent

## A powered robot repair bay with a free slot (WI-44).

func _init(_g: StringName = &"", _t: float = 0.0, _r: bool = false) -> void:
	super(Groups.ROBOT_REPAIR, 0.0, false)

func accepts(_job: Job, _pawn: PawnBase, candidate: ComponentBase) -> bool:
	var bay: RobotRepairComponent = candidate as RobotRepairComponent
	return bay != null and bay.is_available()

func describe() -> String:
	return "a free repair bay"
