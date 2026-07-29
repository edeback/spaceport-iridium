class_name Finder_RecreationProvider
extends Finder_FreeSlotComponent

## A holodeck seat or a mess-hall table with room (WI-44). Socializing is not its
## own need - it is one way of restoring recreation (WI-05) - so both provider
## kinds are drawn from one pool.
##
## Picks at RANDOM among the acceptable options rather than nearest-first. That
## was deliberate in the job this replaces: pawns spread across the available
## venues instead of all piling into whichever one is closest to the corridor.

func _init(_unused_group: StringName = &"", _tolerance: float = 0.0, _random: bool = false) -> void:
	super(Groups.RECREATION_PROVIDER, 0.0, true)

## Skip a provider that currently restores nothing (unpowered, or vibration has
## crushed the rate to zero) - the old job's candidate gather did the same.
func accepts(_job: Job, pawn: PawnBase, candidate: ComponentBase) -> bool:
	var provider: RecreationProviderComponent = candidate as RecreationProviderComponent
	return provider != null and provider.recreation_per_hour(pawn) > 0.0

func describe() -> String:
	return "somewhere to relax"
