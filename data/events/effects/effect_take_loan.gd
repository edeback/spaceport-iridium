class_name EventEffectTakeLoan
extends EventEffect

## Takes an ARC loan of `principal` credits (WI-25) via EconomyManager. Used by
## the insolvency warning card's "accept a loan" choice. A no-op if a loan is
## already active - the economy page is then the way to manage it.

@export var principal: int = 2500

func apply(_event: EventData) -> void:
	if Global.economy_manager != null:
		Global.economy_manager.take_loan(principal)

func describe() -> String:
	return "borrow %d credits from ARC" % principal
