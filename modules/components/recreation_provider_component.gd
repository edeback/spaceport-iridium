class_name RecreationProviderComponent
extends ComponentBase

## Base for anything that restores the recreation need. Socializing is NOT
## its own need - it's one way of restoring recreation (WI-05) - so both
## EntertainmentComponent (holodeck) and SocialComponent (mess hall) are
## providers behind this one interface, and Job_Recreate picks randomly from
## the combined reachable pool. Slot claims mirror SleepComponent's: claimed
## by the job up front, released in its _on_end so they can't leak.

@export var capacity: int = 4
## Adjacency tuning (WI-30): nearby industrial vibration divides the recreation
## gain by (1 + vibration * k), the same shape sleep uses.
@export var vibration_penalty_k: float = 1.0

var _claims: Array[JobBase] = []
## WI-44 claim target. Occupancy for BOTH job systems is booked here while they
## coexist, so neither can oversubscribe the other's occupants. Reach it through
## claim_pool(), which syncs capacity first.
var _slots := SlotPool.new()

## The object a WI-44 job takes its SLOT claim against. Capacity is re-synced on
## every call so a local upgrade that widens the component is picked up without
## anything having to notify this.
func claim_pool() -> SlotPool:
	_slots.capacity = capacity
	return _slots

func ready_constructed() -> void:
	add_to_group(Groups.RECREATION_PROVIDER)

func has_free_slot() -> bool:
	return claim_pool().has_free()

func claim_slot(job: JobBase) -> bool:
	if _claims.has(job) or claim_pool().take_claim(ClaimSpec.Kind.SLOT, 1) == null:
		return false
	_claims.append(job)
	return true

func release_slot(job: JobBase) -> void:
	if _claims.has(job):
		_claims.erase(job)
		claim_pool().release_claim(ClaimSpec.Kind.SLOT, 1, null)

## Recreation points per game-hour for this pawn right now, after the adjacency
## vibration penalty. 0 means "currently unavailable" (e.g. unpowered) -
## Job_Recreate skips or leaves. Subclasses override _raw_recreation_per_hour,
## not this, so every provider gets the penalty uniformly.
func recreation_per_hour(_pawn: PawnBase) -> float:
	var raw: float = _raw_recreation_per_hour(_pawn)
	if raw <= 0.0:
		return 0.0
	return raw * vibration_multiplier()

## WI-44 adapter: the uniform name Action_RestoreNeed calls on every provider,
## whatever need it serves. One small method per provider replaces each need job
## knowing its own provider's differently-named rate function.
func restore_rate_per_hour(pawn: PawnBase) -> float:
	return recreation_per_hour(pawn)

## Provider-specific base rate before adjacency. Override this in subclasses.
func _raw_recreation_per_hour(_pawn: PawnBase) -> float:
	return 0.0

## Vibration divisor (WI-30). 1.0 when no vibration reaches this module or the
## manager isn't up yet.
func vibration_multiplier() -> float:
	if Global.adjacency_manager == null or owner_module == null:
		return 1.0
	var vibration: float = Global.adjacency_manager.get_field(owner_module, &"vibration")
	return 1.0 / (1.0 + vibration * vibration_penalty_k)
