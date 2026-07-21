class_name SleepComponent
extends ComponentBase

## Sleep slots on a pod module. Job_Sleep claims a slot at claim time (not on
## arrival) so two pawns never race for the same pod, and releases it in its
## _on_end - which runs on every termination path (WI-04 contract), so slots
## can't leak. Slots are runtime-only state: rebuilt empty on save/load.

@export var capacity: int = 1
## Restore-rate multiplier; 1.0 = an empty sleep bar refills (gross, before
## the pawn's own decay) in base_hours_to_full.
@export var sleep_quality: float = 1.0
## Game-hours a quality-1 pod takes to gross-restore an empty sleep bar. Set
## below the intended night length: the pawn's sleep decay keeps ticking
## while asleep, so net restore is slower than this.
@export var base_hours_to_full: float = 6.0

## Adjacency tuning (WI-30). Nearby industrial vibration divides rest
## effectiveness by (1 + vibration * k); nearby greenery adds a small rest bonus
## and (more importantly) makes the bunk more desirable when picking one.
@export var vibration_penalty_k: float = 1.0
@export var greenery_rest_bonus_k: float = 0.15
@export var greenery_desirability_k: float = 1.0

var _claims: Array[JobBase] = []

func ready_constructed() -> void:
	add_to_group("sleep_component")

func has_free_slot() -> bool:
	return _claims.size() < capacity

func claim_slot(job: JobBase) -> bool:
	if not has_free_slot() or _claims.has(job):
		return false
	_claims.append(job)
	return true

func release_slot(job: JobBase) -> void:
	_claims.erase(job)

func sleep_restored_per_hour(sleep_max: float) -> float:
	return sleep_max / base_hours_to_full * sleep_quality * environment_rest_multiplier()

## Adjacency modifier on rest effectiveness (WI-30): vibration divides it,
## greenery gives a small bonus. 1.0 when nothing is nearby (or the manager
## isn't up yet), so an isolated pod restores exactly its authored rate.
func environment_rest_multiplier() -> float:
	if Global.adjacency_manager == null or owner_module == null:
		return 1.0
	var vibration: float = Global.adjacency_manager.get_field(owner_module, &"vibration")
	var greenery: float = Global.adjacency_manager.get_field(owner_module, &"greenery")
	return (1.0 / (1.0 + vibration * vibration_penalty_k)) * (1.0 + greenery * greenery_rest_bonus_k)

## Desirability score for choosing among free bunks (WI-30): greener is nicer,
## noisier is worse. Only a tie-break between comparably-close pods - see
## Job_Sleep._find_pod.
func desirability() -> float:
	if Global.adjacency_manager == null or owner_module == null:
		return 0.0
	var vibration: float = Global.adjacency_manager.get_field(owner_module, &"vibration")
	var greenery: float = Global.adjacency_manager.get_field(owner_module, &"greenery")
	return greenery * greenery_desirability_k - vibration * vibration_penalty_k
