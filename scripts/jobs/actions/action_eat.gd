class_name Action_Eat
extends ActionBase

## Sit down with a meal taken from the sustenance pool in a slot (WI-44).
##
## The pawn is served ONCE and then eats for a while. on_start takes the whole
## portion out of the pool and bills a visitor for it; the nourishment then
## arrives in proportion to the time spent at the table, over the serving
## module's `meal_duration_hours`. That lingering is the point - the mess hall is
## somewhere crew spend an hour, not a vending machine they touch and leave.
##
## Deliberately NOT an Action_RestoreNeed even though it now takes time: the SIZE
## and QUALITY of the meal are decided at the moment it is served rather than
## being a rate ticking a value upward. The quality read is why the service has
## to be one atomic step - consume_sustenance() returns the amount and the
## quality of the portion together, captured before an emptied pool resets, and
## re-reading pool_quality later would grade the meal against whatever the
## kitchen cooked next.
##
## Leaving early WASTES the rest of the tray: the portion is already out of the
## pool, nothing puts it back, and the pawn keeps only the nourishment they had
## time to eat plus an "interrupted meal" mood hit. This does not cross the
## no-resource-destruction invariant - that one is about goods a pawn is
## CARRYING, and a served meal is consumed, not carried.

## Portion size to ask for. Matches the eat job's desired_sustenance.
@export var slot: JobTarget.Slot = JobTarget.Slot.A
@export var desired: int = 70

## Total nourishment this meal is worth - portion size times the quality
## multiplier, fixed at the moment of service and paid out over the meal.
var _nourishment: float = 0.0
## How much of that has already been added to the pawn's hunger.
var _served: float = 0.0
## Sim-seconds spent eating. The runner keeps its own elapsed clock for the
## DURATION check, but the payout is a fraction of the meal and the action has to
## own the number it divides by - and it has to survive a save the way the
## runner's does.
var _eaten_seconds: float = 0.0
## Quality of the portion on the tray, held for the end-of-meal mood band.
var _quality: float = FoodInstanceData.DEFAULT_QUALITY
## Latch for the end-of-meal mood, which must fire exactly once even though the
## runner calls on_finish twice on the success path (once as the action
## completes, once as the job ends on it).
var _settled: bool = false

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A, portion: int = 70) -> void:
	slot = target_slot
	desired = portion
	complete_mode = CompleteMode.DURATION

func on_start(job: Job) -> Status:
	var sustenance: SustenanceComponent = _sustenance(job)
	if sustenance == null or job.pawn == null:
		return Status.FAILED
	# Re-validated rather than trusted: the walk took time and someone else may
	# have emptied the pool in the meantime.
	if sustenance.sustenance_available <= 0:
		return Status.FAILED
	var meal: Dictionary = sustenance.consume_sustenance(desired)
	var eaten: int = int(meal["amount"])
	if eaten <= 0:
		return Status.FAILED
	_quality = float(meal["quality"])
	# Nourishment scales with quality (WI-29): a good meal fills hunger further
	# per unit eaten, a poor one less. Settled here, at the moment of service, so
	# the kitchen restocking mid-meal can't re-grade what's already on the tray.
	_nourishment = eaten * FoodInstanceData.nourishment_mult(_quality,
		sustenance.min_nourish_mult, sustenance.max_nourish_mult)
	_served = 0.0
	_eaten_seconds = 0.0
	duration = meal_seconds(sustenance)
	# Visitors pay for the meal (WI-33); crew eat free. Charged AFTER serving, so
	# a paying guest always gets what they ate - and charged once, up front, so a
	# meal cut short is not also a refund.
	sustenance.charge_meal(job.pawn)
	# Records that the portion is out of the pool, so a save taken mid-meal does
	# not serve a second one on load.
	job.count = eaten
	return Status.ONGOING

## Already served. Without this a job saved mid-meal would take a second portion
## and bill a visitor twice - the same hazard Action_TakeFromStorage guards
## against. The eating itself resumes from the saved fraction.
func on_resume(job: Job) -> Status:
	if job.count <= 0:
		return on_start(job)
	var sustenance: SustenanceComponent = _sustenance(job)
	if sustenance == null:
		return Status.FAILED
	# duration is rebuilt rather than saved: make_actions() hands back a default
	# instance, and the module's own pace is the truth even if it was retuned
	# between the save and the load.
	duration = meal_seconds(sustenance)
	return Status.ONGOING

func tick(job: Job, delta: float) -> Status:
	_eaten_seconds += delta
	var needs: PawnNeedsComponent = _needs(job)
	if needs == null:
		# Nothing to feed (a pawn kind with no hunger need got here somehow) -
		# still let the meal run its course rather than failing the job.
		return Status.ONGOING
	var owed: float = nourishment_owed(_nourishment, _eaten_seconds, duration, _served)
	if owed > 0.0:
		needs.hunger_value += owed
		_served += owed
	return Status.ONGOING

## Nourishment the pawn is owed right now: the eaten fraction of the meal's
## total, minus what has already been handed over.
##
## Computed as a fraction of the whole rather than a per-frame slice on purpose.
## The frame that runs past the end tops the meal up to exactly its full value
## instead of leaving a sliver behind, and a meal cut short pays out exactly the
## fraction eaten. A zero-length meal (a module tuned back to the instant
## behaviour) is served whole on its first tick.
static func nourishment_owed(total: float, eaten_seconds: float, meal_length: float,
		already_served: float) -> float:
	var progress: float = 1.0 if meal_length <= 0.0 else clampf(eaten_seconds / meal_length, 0.0, 1.0)
	return maxf(total * progress - already_served, 0.0)

## How long this module's meals take, in sim-seconds.
static func meal_seconds(sustenance: SustenanceComponent) -> float:
	return maxf(sustenance.meal_duration_hours, 0.0) * TimeManager.SECONDS_PER_HOUR

## The mood the meal leaves behind, decided by how it ENDED. Finishing grades the
## food by its quality band; being pulled away from it earns the interrupted-meal
## grumble instead, and the two are mutually exclusive - a meal you didn't get to
## finish isn't a good one however well it was cooked.
func on_finish(job: Job, outcome: Job.Outcome) -> void:
	# job.count is the "was anything actually served" record: interrupted on the
	# walk over, or an empty pool on arrival, means no meal to grade and nothing
	# wasted.
	if _settled or job.count <= 0:
		return
	var needs: PawnNeedsComponent = _needs(job)
	var sustenance: SustenanceComponent = _sustenance(job)
	# The balance numbers live on the serving module, so a mess hall destroyed
	# mid-meal takes the mood nudge with it. The pawn eating through a hull breach
	# has larger problems than an unfinished lunch.
	if needs == null or sustenance == null:
		return
	_settled = true
	if outcome == Job.Outcome.SUCCEEDED:
		_apply_meal_mood(needs, sustenance, _quality)
		return
	needs.remove_modifier(&"good_meal")
	needs.remove_modifier(&"bad_meal")
	needs.add_modifier(&"interrupted_meal", sustenance.interrupted_meal_mood,
		sustenance.interrupted_meal_duration_hours)

## Timed happiness nudge from the meal's quality band (WI-29). good_meal and
## bad_meal are mutually exclusive: the latest meal clears the other id so "last
## meal wins" (a good meal after a bad one lifts you, not both at once); a neutral
## meal clears both. A finished meal also clears the last one's interruption.
func _apply_meal_mood(needs: PawnNeedsComponent, sustenance: SustenanceComponent,
		quality: float) -> void:
	needs.remove_modifier(&"interrupted_meal")
	var band: int = FoodInstanceData.meal_mood_band(quality,
		sustenance.bad_meal_band, sustenance.good_meal_band)
	if band > 0:
		needs.remove_modifier(&"bad_meal")
		needs.add_modifier(&"good_meal", sustenance.good_meal_mood,
			sustenance.meal_mood_duration_hours)
	elif band < 0:
		needs.remove_modifier(&"good_meal")
		needs.add_modifier(&"bad_meal", sustenance.bad_meal_mood,
			sustenance.meal_mood_duration_hours)
	else:
		needs.remove_modifier(&"good_meal")
		needs.remove_modifier(&"bad_meal")

# --- persistence --------------------------------------------------------------

## The meal in progress. Empty before the first bite, when restarting the action
## from the top loses nothing.
func save_state() -> Dictionary:
	if _nourishment <= 0.0 and _eaten_seconds <= 0.0:
		return {}
	return {
		"nourish": _nourishment,
		"served": _served,
		"eaten": _eaten_seconds,
		"quality": _quality,
	}

func load_state(data: Dictionary) -> void:
	_nourishment = float(data.get("nourish", 0.0))
	_served = float(data.get("served", 0.0))
	_eaten_seconds = float(data.get("eaten", 0.0))
	_quality = float(data.get("quality", FoodInstanceData.DEFAULT_QUALITY))

func report(_job: Job) -> String:
	return "Eating"

func _sustenance(job: Job) -> SustenanceComponent:
	var slot_target: JobTarget = job.target(slot)
	if slot_target == null or not slot_target.is_alive():
		return null
	return slot_target.component() as SustenanceComponent

func _needs(job: Job) -> PawnNeedsComponent:
	if job.pawn == null:
		return null
	return job.pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
