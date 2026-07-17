class_name EventEffectOfferContract
extends EventEffect

## Puts a fresh delivery-contract offer on the contracts board (WI-14 tie-in:
## contracts are one of the possible event choices). Parameters roll from the
## same generator trader visits use; premium_bonus sweetens event-sourced
## offers over routine ones.

## Added on top of the generator's rolled price premium (0.15 = +15%).
@export var premium_bonus: float = 0.15

func apply(_event: EventData) -> void:
	var contract: ContractData = Global.contract_manager.generate_offer(premium_bonus)
	if contract == null:
		# Nothing worth contracting (no stored tradeables) - a silent no-op
		# would feel like the choice did nothing, so say so.
		SignalBus.station_alert.emit("The contractor found nothing worth shipping")

func describe() -> String:
	return "a delivery contract offer"
