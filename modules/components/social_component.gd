class_name SocialComponent
extends RecreationProviderComponent

## Marks a module as a social space (mess hall, future promenade). Restores
## recreation faster per additional pawn present in the module - a lone pawn
## still restores at base rate (slow but never zero, or an early-game solo
## pawn could never satisfy recreation). Deep conversation simulation: no.

@export var base_fun_per_hour: float = 10.0
@export var fun_per_extra_pawn_per_hour: float = 8.0
## Company bonus stops growing past this many extra pawns.
@export var max_counted_company: int = 5

func _raw_recreation_per_hour(_pawn: PawnBase) -> float:
	var present: int = 0
	for node: Node in get_tree().get_nodes_in_group("pawn"):
		var pawn: PawnBase = node as PawnBase
		if pawn != null and pawn.current_module == owner_module:
			present += 1
	# The recreating pawn counts itself in `present`; company is everyone else.
	var company: int = clampi(present - 1, 0, max_counted_company)
	return base_fun_per_hour + company * fun_per_extra_pawn_per_hour
