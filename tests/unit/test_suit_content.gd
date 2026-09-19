extends GutTest

## Content sweep over everything WI-67 authored.
##
## The rule itself is pinned by test_suit_rules.gd; this pins the DATA that rule
## reads, because every one of these is silent when it is wrong. A tier file
## missing `suits_mandatory` gives a Tier 1 crew no suits and no warning. A hint
## naming an undeclared trigger never fires, forever, with nothing on screen to
## say so. An unlock at the wrong tier is a fix the player cannot buy on the day
## the problem starts.

const TIER_DIR: String = "res://data/tiers/"

# --- the tier flag ------------------------------------------------------------

func test_only_tier_one_keeps_the_crew_in_suits() -> void:
	# The whole feature hangs off this one bool. Tier 1 true, everything else
	# false: a second mandatory tier would silently re-suit a station that had
	# already earned its way out.
	for tier: int in range(1, 6):
		var data: TierData = load(TIER_DIR + "tier_%d.tres" % tier) as TierData
		assert_not_null(data, "tier_%d.tres loads" % tier)
		if data == null:
			continue
		assert_eq(data.tier, tier, "tier_%d.tres knows its own number" % tier)
		if tier == 1:
			assert_true(data.suits_mandatory, "Tier 1 crew live in suits")
		else:
			assert_false(data.suits_mandatory, "Tier %d crew do not" % tier)

# --- the job ------------------------------------------------------------------

func test_the_change_suit_job_is_authored_as_the_rule_expects() -> void:
	var data: JobData = load("res://data/jobs/change_suit.tres") as JobData
	assert_not_null(data, "change_suit.tres loads")
	if data == null:
		return
	assert_eq(data.id, &"change_suit", "the id the component posts")
	assert_eq(data.category, JobData.Category.NEEDS, "self-care, not station work")
	assert_not_null(data.driver, "names a driver")
	if data.driver != null:
		assert_true(String(data.driver.resource_path).ends_with("job_driver_change_suit.gd"),
			"and it is the suit driver")
	# A player cancelling somebody's suit-up is cancelling their life support.
	assert_false(data.player_cancelable, "not cancelable from the jobs screen")
	# The walk is the whole feature, so a save mid-trip has to come back mid-trip.
	assert_true(data.saveable, "a trip survives a save")

# --- the hint -----------------------------------------------------------------

func test_the_tier_two_hint_is_wired_to_a_declared_trigger() -> void:
	var hint: TutorialHintData = load("res://data/tutorial/habitable_interior.tres") as TutorialHintData
	assert_not_null(hint, "habitable_interior.tres loads")
	if hint == null:
		return
	var triggers := TutorialTriggers.new()
	assert_true(triggers.is_declared(hint.trigger), "its trigger is declared")
	assert_true(triggers.takes_filter(hint.trigger), "and that trigger takes a filter")
	assert_eq(hint.trigger_filter, &"2", "fires on reaching Tier 2")
	assert_false(hint.has_subject, "it is about the station, not about one pawn")
	assert_eq(hint.script_problem(), "", "its dialogue and cue resolve")
	# The durable copy is what a player who clicked through it still has, and the
	# only explanation a tutorial-skipper gets beyond the Needs tab row.
	assert_false(hint.body.is_empty(), "it transmits a body")
	assert_true(hint.body.to_lower().contains("airlock"),
		"and the body names where crew change, which is the rule that moved")

func test_the_new_trigger_is_declared_with_a_filter() -> void:
	assert_true(TutorialTriggers.DECLARED.has(&"station_tier_reached"))
	assert_true(TutorialTriggers.DECLARED.get(&"station_tier_reached", false),
		"filtered by tier number, so a Tier 3 hint needs no watcher edit")

# --- the mood -----------------------------------------------------------------

func test_the_indoor_suit_mood_is_named_and_caused() -> void:
	var described: Dictionary = MoodCatalog.describe(PawnSuitComponent.MOOD_SUIT_INDOORS)
	assert_eq(String(described.get("label", "")), "Spacesuit on inside")
	assert_eq(String(described.get("cause", "")), MoodCatalog.CAUSE_SUITED,
		"permanent, so the Needs tab prints a cause rather than a countdown")
	# The blurb is load-bearing: for a player who skipped the tutorial it is where
	# the Tier 2 rule change is explained at all.
	assert_true(String(described.get("blurb", "")).to_lower().contains("airlock"),
		"and the blurb says where they change")

# --- the heater ---------------------------------------------------------------

func test_the_heater_is_a_buried_life_support_module() -> void:
	var data: ModuleData = load("res://data/modules/life_support/heater_mdata.tres") as ModuleData
	assert_not_null(data, "heater_mdata.tres loads")
	if data == null:
		return
	assert_eq(data.category_id, &"life_support", "buckets with the other life support")
	assert_true(data.tags.has("Thermal"), "tagged for the thermal systems")
	assert_false(data.unlocked_by_default, "researched, not free")
	assert_not_null(data.scene, "names its scene")
	# The radiator wants exposure; this wants the opposite. A heater that radiated
	# like a radiator would spend most of its output on empty space.
	assert_lt(data.heat_radiation_mult, 1.0, "sheds less than an ordinary module")

func test_the_heater_can_be_bought_the_day_the_cold_starts_costing() -> void:
	var unlock: UnlockData = load("res://data/unlocks/industrial_tree/heater_unlock.tres") as UnlockData
	assert_not_null(unlock, "heater_unlock.tres loads")
	if unlock == null:
		return
	assert_eq(unlock.min_tier, 2, "available exactly when suits start coming off")
	# No prerequisite on purpose: life_support_unlock sits behind the electrolyzer,
	# and gating the fix for a Tier 2 problem behind two purchases is a trap.
	assert_eq(unlock.prerequisites.size(), 0, "one purchase away, not two")
	var grants_heater: bool = false
	for effect: UnlockEffect in unlock.effects:
		var module: Variant = effect.get("module")
		if module is ModuleData and (module as ModuleData).id == &"heater_mdata":
			grants_heater = true
	assert_true(grants_heater, "and it actually grants the heater")

func test_the_thermostat_band_is_the_habitable_one() -> void:
	assert_lt(HeatEmitterComponent.TARGET_MIN_F, HeatEmitterComponent.TARGET_MAX_F)
	assert_gt(HeatEmitterComponent.TARGET_STEP_F, 0, "a stepper needs a step")
	# Aiming a heater outside the band the crew can live in is aiming it at hurting
	# them, so the control does not offer it.
	assert_eq(HeatEmitterComponent.TARGET_MIN_F, HeatMath.DEFAULT_HABITABLE_LOW_F)
	assert_eq(HeatEmitterComponent.TARGET_MAX_F, HeatMath.DEFAULT_HABITABLE_HIGH_F)

# --- the driver's action sequence ---------------------------------------------
#
# make_actions() MUST be deterministic and MUST depend only on the job, because
# the save format stores an integer index into the list it returns. A driver that
# built a different sequence after a load would resume a saved trip into the wrong
# step - which for this job means flipping a suit that was never taken off.

func _job(putting_on: bool) -> Job:
	# Typed as a trip: the component declines to adopt anything else, because
	# Job.offer_to_owner asks every component on the pawn in turn (WI-70).
	var data := JobData.new()
	data.id = PawnSuitComponent.CHANGE_SUIT_JOB
	var job := Job.create(data)
	job.count = 1 if putting_on else 0
	return job

func test_the_trip_is_find_then_walk_then_change() -> void:
	var driver := JobDriver_ChangeSuit.new()
	var actions: Array[ActionBase] = driver.make_actions(_job(true))
	assert_eq(actions.size(), 3, "three steps")
	if actions.size() != 3:
		return
	assert_true(actions[0] is Action_FindBestTarget, "find an airlock")
	# The walk is the whole feature: it is what makes a breach dangerous.
	assert_true(actions[1] is Action_GotoTarget, "walk to it")
	assert_true(actions[2] is Action_ChangeSuit, "change there")
	assert_eq(actions[2].complete_mode, ActionBase.CompleteMode.DURATION,
		"the change takes time at the rack")

func test_direction_rides_on_the_job_not_on_live_state() -> void:
	# Reading the pawn's current suit here instead would rebuild a DIFFERENT
	# sequence for a pawn whose suit changed while the save was closed.
	var driver := JobDriver_ChangeSuit.new()
	var on := driver.make_actions(_job(true))[2] as Action_ChangeSuit
	var off := driver.make_actions(_job(false))[2] as Action_ChangeSuit
	assert_true(on.putting_on, "count 1 puts a suit on")
	assert_false(off.putting_on, "count 0 takes it off")

func test_make_actions_is_deterministic() -> void:
	var driver := JobDriver_ChangeSuit.new()
	var job: Job = _job(true)
	var first: Array[ActionBase] = driver.make_actions(job)
	var second: Array[ActionBase] = driver.make_actions(job)
	assert_eq(first.size(), second.size(), "same length every call")
	for i: int in mini(first.size(), second.size()):
		assert_eq(first[i].get_script(), second[i].get_script(),
			"step %d is the same kind of action every call" % i)

func test_taking_a_suit_off_demands_a_habitable_airlock() -> void:
	# You can always climb INTO a suit, anywhere. Taking one off needs somewhere
	# fit to stand unsuited - which is the asymmetry the finder flag exists for.
	var driver := JobDriver_ChangeSuit.new()
	assert_true(driver.explain_block(_job(false), null).contains("habitable"),
		"the blocked message says which kind of airlock is missing")
	assert_false(driver.explain_block(_job(true), null).contains("habitable"),
		"suiting up accepts any airlock")

# --- the component's save block -----------------------------------------------

func test_the_suit_block_round_trips() -> void:
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	suit.apply_change(true)
	assert_gt(suit.hold_remaining(), 0.0, "suiting up against harm starts the hold")
	var restored: PawnSuitComponent = autofree(PawnSuitComponent.new())
	restored.load_save_data(suit.get_save_data())
	assert_eq(restored.suited, suit.suited, "the suit round-trips")
	assert_almost_eq(restored.hold_remaining(), suit.hold_remaining(), 0.0001,
		"and so does the hold, which is a clock rather than derived state")

func test_a_missing_block_loads_as_suited() -> void:
	# A pre-WI-67 save has no suit block at all. Suited with no hold is the safe
	# reading: at Tier 1 nothing changes, and at Tier 2+ the first tick sends
	# anyone in a habitable room off to an airlock to change.
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	suit.load_save_data({})
	assert_true(suit.suited)
	assert_eq(suit.hold_remaining(), 0.0)

func test_taking_a_suit_off_clears_the_hold() -> void:
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	suit.apply_change(true)
	suit.apply_change(false)
	assert_false(suit.suited)
	assert_eq(suit.hold_remaining(), 0.0, "out of the suit means the hold is spent")

# --- the trip pointer (WI-68 F2) ------------------------------------------------
#
# The trip is not saved; the job it points at is. SaveManager hands the restored job
# back through adopt_restored_job, and only the trip itself may clear the
# pointer - a stale trip's failure, or a cheat flip, must leave a live one alone.

func test_an_adopted_trip_counts_as_under_way() -> void:
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	assert_false(suit.has_live_trip(), "a fresh component has no trip")
	assert_true(suit.adopt_restored_job(_job(true)))
	assert_true(suit.has_live_trip(), "a restored trip is live, so no second one is posted")

func test_only_a_trip_is_adopted() -> void:
	# A restored PAWN job is offered to every component on the pawn until one takes
	# it, so each must decline what isn't theirs - or the suit adopts a meal.
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	var data := JobData.new()
	data.id = &"eat"
	assert_false(suit.adopt_restored_job(Job.create(data)), "a meal is not a trip")
	assert_false(suit.has_live_trip())

func test_a_second_restored_trip_is_refused() -> void:
	# F2's old-save artefact: two trips saved for one pawn. The second runs once as
	# an orphan rather than replacing the first.
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	assert_true(suit.adopt_restored_job(_job(true)))
	assert_false(suit.adopt_restored_job(_job(true)), "one trip per pawn")

func test_a_stale_trips_refusal_leaves_the_current_one_alone() -> void:
	# _start_trip sets the new trip before interrupt_with_job cancels the old one,
	# whose driver then reports the failure. That report must not null the new
	# trip, or the next slow tick posts another and the change never finishes.
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	assert_true(suit.adopt_restored_job(_job(true)))
	suit.trip_refused(_job(true))
	assert_true(suit.has_live_trip(), "the current trip survives a stale trip's failure")
	assert_eq(suit.trip_cooldown_remaining(), 0.0, "and no retry throttle is started")

func test_the_current_trips_refusal_clears_it_and_throttles() -> void:
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	var trip: Job = _job(false)
	assert_true(suit.adopt_restored_job(trip))
	suit.trip_refused(trip)
	assert_false(suit.has_live_trip(), "a refused trip is over")
	assert_eq(suit.trip_cooldown_remaining(), suit.trip_retry_hours,
		"and the retry throttle starts, so a station that cannot comply doesn't re-post every tick")

func test_a_refusal_with_no_trip_is_harmless() -> void:
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	suit.trip_refused(_job(true))
	assert_eq(suit.trip_cooldown_remaining(), 0.0, "nothing was refused that this component asked for")

func test_a_change_clears_only_its_own_trip() -> void:
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	var trip: Job = _job(true)
	assert_true(suit.adopt_restored_job(trip))
	suit.apply_change(true, _job(true))
	assert_true(suit.has_live_trip(), "another job's change does not end this trip")
	suit.apply_change(true, trip)
	assert_false(suit.has_live_trip(), "the trip's own change does")

func test_a_cheat_flip_leaves_a_walking_trip_alone() -> void:
	# The cheat console calls apply_change with no job. Clearing the pointer then
	# would orphan the trip still walking - the save/load bug in miniature.
	var suit: PawnSuitComponent = autofree(PawnSuitComponent.new())
	assert_true(suit.adopt_restored_job(_job(true)))
	suit.apply_change(false)
	assert_true(suit.has_live_trip(), "the trip finishes and applies its own change")

# --- breaches -----------------------------------------------------------------

func test_hull_breaches_cannot_fire_at_tier_one() -> void:
	var event: EventData = load("res://data/events/micrometeorite_strike.tres") as EventData
	assert_not_null(event, "micrometeorite_strike.tres loads")
	if event == null:
		return
	var gate: EventConditionMinTier = null
	for condition: EventCondition in event.conditions:
		if condition is EventConditionMinTier:
			gate = condition as EventConditionMinTier
	assert_not_null(gate, "the strike carries a min-tier gate")
	if gate != null:
		# At Tier 1 the crew are suited, so a breach harms nobody - and it is a
		# CRITICAL that stops the sim over nothing.
		assert_eq(gate.min_tier, 2, "and that gate is Tier 2")
