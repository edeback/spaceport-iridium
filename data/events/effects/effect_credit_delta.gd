class_name EventEffectCreditDelta
extends EventEffect

## Adds (or, negative, removes) credits. Going below zero is acceptable -
## debt contributes to the game-over flow via CrewManager's hire check.

@export var amount: int = 0

func apply(_event: EventData) -> void:
	Global.resource_manager.credit_resource.change_global_total(amount)
	# Book it on the economy ledger (WI-25) - an event swing bypasses the levy
	# but still shows on the economy page.
	if Global.economy_manager != null:
		Global.economy_manager.record_event_delta(amount)

func describe() -> String:
	return "%+d credits" % amount
