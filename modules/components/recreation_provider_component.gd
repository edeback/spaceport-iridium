class_name RecreationProviderComponent
extends ComponentBase

## Base for anything that restores the recreation need. Socializing is NOT
## its own need - it's one way of restoring recreation (WI-05) - so both
## EntertainmentComponent (holodeck) and SocialComponent (mess hall) are
## providers behind this one interface, and Job_Recreate picks randomly from
## the combined reachable pool. Slot claims mirror SleepComponent's: claimed
## by the job up front, released in its _on_end so they can't leak.

@export var capacity: int = 4

var _claims: Array[JobBase] = []

func ready_constructed() -> void:
	add_to_group("recreation_provider")

func has_free_slot() -> bool:
	return _claims.size() < capacity

func claim_slot(job: JobBase) -> bool:
	if not has_free_slot() or _claims.has(job):
		return false
	_claims.append(job)
	return true

func release_slot(job: JobBase) -> void:
	_claims.erase(job)

## Recreation points per game-hour for this pawn right now. 0 means
## "currently unavailable" (e.g. unpowered) - Job_Recreate skips or leaves.
func recreation_per_hour(_pawn: PawnBase) -> float:
	return 0.0
