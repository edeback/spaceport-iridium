class_name RobotRepairComponent
extends ComponentBase

## The Repair Bay's business end (WI-28): where a damaged robot restores its
## integrity. Deliberately NOT folded into the Logistics Bay or the charger - a
## Repair Bay is a dedicated module, so losing it actually matters (a robot with
## no reachable Repair Bay stays damaged until destroyed). Repairs any robot type.
##
## Powered, slot-limited, and non-leaking exactly like RechargeComponent - the two
## are near-twins, but kept separate so a station can have chargers without repair
## capacity and vice versa.

@export var power_consumption_component: PowerConsumptionComponent
## Integrity restored per game-hour to a docked robot.
@export var repair_rate_per_hour: float = 120.0
## How many robots can be repaired here at once.
@export var capacity: int = 1
## Optional per-hour resource cost while repairing (exported; default none for v1,
## matching WI-24 module repairs which consume nothing).
@export var repair_resource: ResourceData = null
@export var repair_resource_per_hour: float = 0.0

var _claims: Array[JobBase] = []

func ready_constructed() -> void:
	add_to_group("robot_repair")

func powered() -> bool:
	return power_consumption_component == null or power_consumption_component.powered

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

## Integrity per game-hour this bay restores right now; 0 when unpowered so a
## robot mid-repair leaves gracefully on a power cut.
func repair_per_hour() -> float:
	return repair_rate_per_hour if powered() else 0.0

## Draw the optional per-hour repair resource for `sim_hours` of work. Returns true
## if the work is affordable/paid (always true when no resource is configured), so
## Job_GetRepaired can pause when the bay runs dry.
func consume_repair_resource(sim_hours: float) -> bool:
	if repair_resource == null or repair_resource_per_hour <= 0.0:
		return true
	var needed: int = int(ceil(repair_resource_per_hour * sim_hours))
	if needed <= 0:
		return true
	if repair_resource.get_total() < needed:
		return false
	repair_resource.force_withdraw(needed)
	return true
