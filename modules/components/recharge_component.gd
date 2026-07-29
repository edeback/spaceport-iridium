class_name RechargeComponent
extends ComponentBase

## A charger robots dock at to refill energy (WI-28). Lives on the robots' home
## bays as an implicit charger (a Mining Bay / Logistics Bay gains one) and as the
## whole point of a standalone Recharge Station. Powered: an unpowered charger
## serves nobody. Slots are claimed by Job_Recharge up front and released in its
## _on_end - the same non-leaking discipline SleepComponent/RecreationProvider use,
## so "all chargers occupied" naturally makes waiting robots queue on other work
## or idle rather than piling onto one pad.
##
## Power model (WI-28, "keep it simple"): the host module draws its fixed
## PowerConsumptionComponent load whenever built, same as every other powered
## module - the charger simply does nothing while unpowered.

@export var power_consumption_component: PowerConsumptionComponent
## Energy restored per game-hour to a docked robot. Sized well above a robot's
## working+moving drain so a charge trip is always net-positive.
@export var charge_rate_per_hour: float = 240.0
## How many robots can charge here at once.
@export var capacity: int = 2

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
	add_to_group(Groups.RECHARGER)

func powered() -> bool:
	return power_consumption_component == null or power_consumption_component.powered

## Available to claim right now: powered and with a free slot.
func is_available() -> bool:
	return powered() and has_free_slot()

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

## Energy per game-hour this charger delivers right now; 0 when unpowered so a
## robot mid-charge leaves gracefully on a power cut.
## WI-44 adapter: the uniform name Action_RestoreNeed calls on every provider.
func restore_rate_per_hour(_pawn: PawnBase) -> float:
	return charge_per_hour() if powered() else 0.0

func charge_per_hour() -> float:
	return charge_rate_per_hour if powered() else 0.0
