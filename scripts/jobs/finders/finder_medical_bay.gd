class_name Finder_MedicalBay
extends Finder_FreeSlotComponent

## The nearest powered Medical Bay with a free bunk (WI-44).
##
## Nearest-wins with no tolerance band: a sick pawn should not walk past a free
## bunk to reach a marginally nicer one.

func _init(_unused_group: StringName = &"", _tolerance: float = 0.0, _random: bool = false) -> void:
	super(Groups.MEDICAL_BAY, 0.0, false)

func accepts(_job: Job, _pawn: PawnBase, candidate: ComponentBase) -> bool:
	var medical: MedicalComponent = candidate as MedicalComponent
	return medical != null and medical.powered()

func describe() -> String:
	return "a medical bay"
