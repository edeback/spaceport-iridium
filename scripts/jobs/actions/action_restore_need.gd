class_name Action_RestoreNeed
extends ActionBase

## Sit at a provider and push one of the pawn's needs back up until it is full
## (WI-44).
##
## This is the action that collapses seven job classes - sleep, eat, recreate,
## shop, recharge, get-repaired, get-treatment were 1,022 lines of "occupy a
## slot, tick a value upward, stop when it's full or you've been here too long",
## differing only in which need and which provider.
##
## The need is addressed by name (`sleep` -> sleep_value / sleep_max on
## PawnNeedsComponent) and the rate comes from the provider through one
## duck-typed adapter, `restore_rate_per_hour(pawn)`. Providers implement that
## one small method instead of each job knowing a different signature.

@export var slot: JobTarget.Slot = JobTarget.Slot.A
## Need channel: reads <need>_value and <need>_max off the needs component.
@export var need: StringName = &""
## Leave once this many game-hours have passed even if the need isn't full -
## stops pawns parking in the holodeck all cycle when the restore rate barely
## beats decay. Zero = stay until full.
@export var max_stay_hours: float = 0.0

## Hours spent here so far. Saved, so a session interrupted by a save resumes
## with its stay clock intact rather than earning a fresh full allowance.
var _stay_hours: float = 0.0

func _init(need_id: StringName = &"", target_slot: JobTarget.Slot = JobTarget.Slot.A,
		stay_cap_hours: float = 0.0) -> void:
	need = need_id
	slot = target_slot
	max_stay_hours = stay_cap_hours
	complete_mode = CompleteMode.CONDITION

func tick(job: Job, delta: float) -> Status:
	var needs: PawnNeedsComponent = _needs(job)
	var provider: ComponentBase = _provider(job)
	if needs == null or provider == null:
		return Status.FAILED
	var rate: float = _rate(provider, job.pawn)
	if rate <= 0.0:
		# Power died mid-visit, or the provider stopped being useful. Leave
		# gracefully rather than failing - the need re-queues itself if still low.
		job.end(Job.Outcome.INTERRUPTED)
		return Status.ONGOING
	# delta arrives already sim-scaled from the runner.
	var sim_hours: float = delta / TimeManager.SECONDS_PER_HOUR
	_stay_hours += sim_hours
	needs.set(_value_property(), float(needs.get(_value_property())) + rate * sim_hours)
	return Status.ONGOING

func check(job: Job) -> Status:
	var needs: PawnNeedsComponent = _needs(job)
	if needs == null:
		return Status.FAILED
	if float(needs.get(_value_property())) >= float(needs.get(_max_property())):
		return Status.DONE
	if max_stay_hours > 0.0 and _stay_hours >= max_stay_hours:
		return Status.DONE
	return Status.ONGOING

func save_state() -> Dictionary:
	return {"stay": _stay_hours} if _stay_hours > 0.0 else {}

func load_state(data: Dictionary) -> void:
	_stay_hours = float(data.get("stay", 0.0))

func report(_job: Job) -> String:
	return "Resting" if need == &"sleep" else "Recovering"

func _needs(job: Job) -> PawnNeedsComponent:
	if job.pawn == null:
		return null
	return job.pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent

func _provider(job: Job) -> ComponentBase:
	var slot_target: JobTarget = job.target(slot)
	if slot_target == null or not slot_target.is_alive():
		return null
	return slot_target.component()

## Duck-typed so one action serves every provider. A provider that doesn't
## implement it reads as unavailable, which ends the visit gracefully.
func _rate(provider: ComponentBase, pawn: PawnBase) -> float:
	if not provider.has_method(&"restore_rate_per_hour"):
		return 0.0
	return float(provider.call(&"restore_rate_per_hour", pawn))

func _value_property() -> StringName:
	return StringName("%s_value" % need)

func _max_property() -> StringName:
	return StringName("%s_max" % need)
