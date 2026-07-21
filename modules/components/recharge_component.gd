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

func ready_constructed() -> void:
	add_to_group("recharger")

func powered() -> bool:
	return power_consumption_component == null or power_consumption_component.powered

## Available to claim right now: powered and with a free slot.
func is_available() -> bool:
	return powered() and has_free_slot()

func has_free_slot() -> bool:
	return _claims.size() < capacity

func claim_slot(job: JobBase) -> bool:
	if not has_free_slot() or _claims.has(job):
		return false
	_claims.append(job)
	return true

func release_slot(job: JobBase) -> void:
	_claims.erase(job)

## Energy per game-hour this charger delivers right now; 0 when unpowered so a
## robot mid-charge leaves gracefully on a power cut.
func charge_per_hour() -> float:
	return charge_rate_per_hour if powered() else 0.0
