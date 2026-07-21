class_name EntertainmentComponent
extends RecreationProviderComponent

## Dedicated recreation (holodeck-style): flat restore rate, optionally gated
## on power - no power, no fun.

@export var fun_per_hour: float = 30.0
@export var power_consumption_component: PowerConsumptionComponent

func _raw_recreation_per_hour(_pawn: PawnBase) -> float:
	if power_consumption_component != null and not power_consumption_component.powered:
		return 0.0
	return fun_per_hour
