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
## Display/identity name for the channel, e.g. &"sleep" or &"energy".
@export var need: StringName = &""
## The properties holding the current and maximum value. Default to the
## <need>_value / <need>_max convention PawnNeedsComponent follows; the robot
## components don't (energy / energy_max, integrity / integrity_max), so they set
## these explicitly.
@export var value_property: StringName = &""
@export var max_property: StringName = &""
## Leave once this many game-hours have passed even if the need isn't full -
## stops pawns parking in the holodeck all cycle when the restore rate barely
## beats decay. Zero = stay until full.
@export var max_stay_hours: float = 0.0

## Hours spent here so far. Saved, so a session interrupted by a save resumes
## with its stay clock intact rather than earning a fresh full allowance.
var _stay_hours: float = 0.0

func _init(need_id: StringName = &"", target_slot: JobTarget.Slot = JobTarget.Slot.A,
		stay_cap_hours: float = 0.0, pose: StringName = &"",
		value_prop: StringName = &"", max_prop: StringName = &"") -> void:
	need = need_id
	slot = target_slot
	max_stay_hours = stay_cap_hours
	value_property = value_prop if value_prop != &"" else StringName("%s_value" % need_id)
	max_property = max_prop if max_prop != &"" else StringName("%s_max" % need_id)
	# Held for the whole session and restored by the runner on any exit - which is
	# what stands a sleeper back up however the job ended.
	animation = pose
	complete_mode = CompleteMode.CONDITION

func tick(job: Job, delta: float) -> Status:
	var needs: Object = _needs(job)
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
	needs.set(value_property, float(needs.get(value_property)) + rate * sim_hours)
	return Status.ONGOING

func check(job: Job) -> Status:
	var needs: Object = _needs(job)
	if needs == null:
		return Status.FAILED
	if float(needs.get(value_property)) >= float(needs.get(max_property)):
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

## Whichever of the pawn's components actually owns this need. Organic needs live
## on PawnNeedsComponent; a drone's energy and integrity live on their own
## components with their own property names. Found by property presence rather
## than by type, so a new need channel needs no change here.
func _needs(job: Job) -> Object:
	if job.pawn == null:
		return null
	for component: PawnComponentBase in job.pawn.components:
		if component.get(value_property) != null:
			return component
	return null

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

