class_name EventEffectInspectionResponse
extends EventEffect

## The ARC inspection offer card's choices route back to UnlockManager (WI-26):
## accept begins the inspector's tour, decline sets a re-offer cooldown. The offer
## event (arc_inspection_offer) is fired explicitly by UnlockManager when the tier
## goals are met, never on a natural roll, so both choices are cost-free.

@export var accept: bool = false

func apply(_event: EventData) -> void:
	if Global.unlock_manager == null:
		return
	if accept:
		Global.unlock_manager.begin_inspection()
	else:
		Global.unlock_manager.decline_inspection()

func describe() -> String:
	return "welcome the ARC inspector aboard" if accept else "turn the inspector away for now"
