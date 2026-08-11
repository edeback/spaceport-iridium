extends GutTest

## Unit tests for WI-56's [PawnStatus]: the one sentence the crew roster, the job
## board and the inspector's Job tab all print about a pawn, plus the roster's
## problem line.
##
## The rules are tested through [PawnStatus.Facts] rather than through a live
## pawn on purpose - a [PawnBase] reaches for `Global.path_manager` in `_ready`,
## which is exactly why the rules are separated from the adapter that reads one.
## What is asserted here is the *classification*: which sentence, which tone, and
## which rows the footer counts.

func _facts() -> PawnStatus.Facts:
	return PawnStatus.Facts.new()

## A pawn part-way through a real job.
func _working(report: String, category: JobData.Category = JobData.Category.WORK) -> PawnStatus.Facts:
	var facts: PawnStatus.Facts = _facts()
	facts.has_job = true
	facts.report = report
	facts.category = category
	return facts

# --- the sentence ---------------------------------------------------------------

func test_a_working_pawn_prints_its_jobs_own_report() -> void:
	var line: PawnStatus.Line = PawnStatus.describe(_working("Operating Refinery"))
	assert_eq(line.text, "Operating Refinery", "the job composes its own sentence")
	assert_eq(line.tone, PawnStatus.Tone.WORKING, "station work is cyan")

func test_a_moving_pawn_keeps_its_sentence_but_goes_transitional() -> void:
	var facts: PawnStatus.Facts = _working("Hauling iron ore to Storeroom", JobData.Category.HAUL)
	facts.moving = true
	var line: PawnStatus.Line = PawnStatus.describe(facts)
	assert_eq(line.text, "Hauling iron ore to Storeroom",
		"walking to the crate does not change what the job is")
	assert_eq(line.tone, PawnStatus.Tone.TRANSIT, "but it is grey until they arrive")

func test_a_needs_job_is_transitional_not_working() -> void:
	var line: PawnStatus.Line = PawnStatus.describe(
		_working("Sleeping in Bunk Room", JobData.Category.NEEDS))
	assert_eq(line.tone, PawnStatus.Tone.TRANSIT, "sleeping is not work the player is waiting on")

func test_a_pawn_with_no_job_reads_as_between_jobs() -> void:
	var line: PawnStatus.Line = PawnStatus.describe(_facts())
	assert_eq(line.text, PawnStatus.TEXT_BETWEEN_JOBS)
	assert_eq(line.tone, PawnStatus.Tone.IDLE)

## The edge case the WI calls out: no job at all and an idle-type job are two
## different states, and only one of them says the board had nothing to offer.
func test_a_loitering_pawn_is_told_apart_from_one_between_jobs() -> void:
	var facts: PawnStatus.Facts = _working("Wandering to Corridor", JobData.Category.MISC)
	facts.idle_job = true
	var loitering: PawnStatus.Line = PawnStatus.describe(facts)
	assert_eq(loitering.text, PawnStatus.TEXT_NO_WORK, "an idle job means nothing was available")
	assert_ne(loitering.text, PawnStatus.describe(_facts()).text,
		"and it must not read the same as the gap between two jobs")
	assert_eq(loitering.tone, PawnStatus.Tone.IDLE)

func test_an_off_duty_pawn_says_so_rather_than_reading_as_idle() -> void:
	var facts: PawnStatus.Facts = _working("Wandering to Mess Hall", JobData.Category.MISC)
	facts.idle_job = true
	facts.on_shift = false
	assert_eq(PawnStatus.describe(facts).text, PawnStatus.TEXT_OFF_DUTY,
		"the schedule working is not a problem to report")

func test_a_job_type_with_no_report_template_still_produces_a_sentence() -> void:
	assert_eq(PawnStatus.describe(_working("")).text, PawnStatus.TEXT_WORKING,
		"an empty report falls back rather than printing a blank column")

## The wander job has a perfectly good report ("Wandering to Corridor"), and
## printing it would dress the absence the player is scanning for up as activity.
func test_an_idle_job_never_prints_its_own_report() -> void:
	var facts: PawnStatus.Facts = _working("Wandering to Corridor", JobData.Category.MISC)
	facts.idle_job = true
	assert_eq(PawnStatus.describe(facts).text, PawnStatus.TEXT_NO_WORK)

func test_null_facts_never_crash() -> void:
	var line: PawnStatus.Line = PawnStatus.describe(null)
	assert_not_null(line, "a pawn read mid-despawn must not take the panel down")
	assert_eq(line.tone, PawnStatus.Tone.IDLE)
	assert_eq(PawnStatus.tone_of(null), PawnStatus.Tone.IDLE)
	assert_false(PawnStatus.is_idle(null))

# --- amber is a budget ------------------------------------------------------------

func test_a_resigned_pawn_outranks_whatever_they_are_doing() -> void:
	var facts: PawnStatus.Facts = _working("Hauling steel to Storeroom", JobData.Category.HAUL)
	facts.resigned = true
	var line: PawnStatus.Line = PawnStatus.describe(facts)
	assert_eq(line.text, PawnStatus.TEXT_LEAVING)
	assert_eq(line.tone, PawnStatus.Tone.ALERT, "a row the player must not miss")

func test_a_resigning_pawn_is_amber_before_the_grace_window_expires() -> void:
	var facts: PawnStatus.Facts = _facts()
	facts.resignation_pending = true
	var line: PawnStatus.Line = PawnStatus.describe(facts)
	assert_eq(line.text, PawnStatus.TEXT_RESIGNING)
	assert_eq(line.tone, PawnStatus.Tone.ALERT)

func test_a_critical_need_goes_amber_but_keeps_the_job_sentence() -> void:
	var facts: PawnStatus.Facts = _working("Getting something to eat", JobData.Category.NEEDS)
	facts.critical_need = true
	var line: PawnStatus.Line = PawnStatus.describe(facts)
	assert_eq(line.text, "Getting something to eat",
		"whether they are already fixing it is the useful half")
	assert_eq(line.tone, PawnStatus.Tone.ALERT)

func test_only_the_three_alert_states_spend_amber() -> void:
	# Invariant 5: if any ordinary state reached ALERT the budget would be gone.
	for category: JobData.Category in [JobData.Category.HAUL, JobData.Category.BUILD,
			JobData.Category.WORK, JobData.Category.NEEDS, JobData.Category.MOVE,
			JobData.Category.MISC]:
		assert_ne(PawnStatus.describe(_working("Doing a thing", category)).tone,
			PawnStatus.Tone.ALERT, "category %d must not be amber on its own" % category)

# --- robots ------------------------------------------------------------------------

func _robot() -> PawnStatus.Facts:
	var facts: PawnStatus.Facts = _facts()
	facts.robot = true
	return facts

func test_a_robot_recharging_says_so() -> void:
	var facts: PawnStatus.Facts = _robot()
	facts.has_job = true
	facts.job_id = PawnStatus.JOB_RECHARGE
	facts.robot_wants_charge = true
	assert_eq(PawnStatus.describe(facts).text, PawnStatus.TEXT_RECHARGING,
		"an active recharge beats merely wanting one")

func test_a_robot_out_of_power_outranks_every_other_robot_state() -> void:
	var facts: PawnStatus.Facts = _robot()
	facts.has_job = true
	facts.job_id = PawnStatus.JOB_RECHARGE
	facts.robot_out_of_power = true
	facts.robot_wants_charge = true
	var line: PawnStatus.Line = PawnStatus.describe(facts)
	assert_eq(line.text, PawnStatus.TEXT_NO_POWER)
	assert_eq(line.tone, PawnStatus.Tone.ALERT)

func test_a_robot_seeking_a_charger_is_transitional() -> void:
	var facts: PawnStatus.Facts = _robot()
	facts.has_job = true
	facts.report = "Hauling steel to Storeroom"
	facts.robot_wants_charge = true
	assert_eq(PawnStatus.describe(facts).text, PawnStatus.TEXT_SEEKING_CHARGER)

func test_a_robot_being_repaired_says_so() -> void:
	var facts: PawnStatus.Facts = _robot()
	facts.has_job = true
	facts.job_id = PawnStatus.JOB_GET_REPAIRED
	assert_eq(PawnStatus.describe(facts).text, PawnStatus.TEXT_REPAIRING)

## A drone still gets `idle_wander`, so "no job" is `is_idle_type`, not null -
## the WI-50 readiness-dot trap, restated here because this is now where it lives.
func test_an_idle_robot_reads_as_idle_not_as_working() -> void:
	var facts: PawnStatus.Facts = _robot()
	facts.has_job = true
	facts.idle_job = true
	assert_eq(PawnStatus.describe(facts).tone, PawnStatus.Tone.IDLE)

func test_a_working_robot_reports_its_job() -> void:
	var facts: PawnStatus.Facts = _robot()
	facts.has_job = true
	facts.report = "Mining Asteroid"
	facts.category = JobData.Category.WORK
	var line: PawnStatus.Line = PawnStatus.describe(facts)
	assert_eq(line.text, "Mining Asteroid")
	assert_eq(line.tone, PawnStatus.Tone.WORKING)

# --- visitors ----------------------------------------------------------------------

func test_a_visitor_reports_normally_and_is_never_counted_idle() -> void:
	var facts: PawnStatus.Facts = _working("Shopping at Boutique", JobData.Category.NEEDS)
	facts.visitor = true
	assert_eq(PawnStatus.describe(facts).text, "Shopping at Boutique")
	facts.has_job = false
	assert_false(PawnStatus.is_idle(facts), "a guest with nothing to do is not a staffing problem")

# --- what counts as idle -------------------------------------------------------------

func test_idle_is_no_work_while_on_shift() -> void:
	var between: PawnStatus.Facts = _facts()
	assert_true(PawnStatus.is_idle(between), "between jobs on shift is idle")
	var loitering: PawnStatus.Facts = _working("Wandering", JobData.Category.MISC)
	loitering.idle_job = true
	assert_true(PawnStatus.is_idle(loitering), "an idle-type job is idle")
	assert_false(PawnStatus.is_idle(_working("Operating Refinery")), "real work is not")

func test_off_shift_is_not_idle() -> void:
	var facts: PawnStatus.Facts = _facts()
	facts.on_shift = false
	assert_false(PawnStatus.is_idle(facts),
		"or the problem line would read 4 IDLE every night, forever")

func test_robots_are_never_idle_in_the_roster_sense() -> void:
	var facts: PawnStatus.Facts = _robot()
	assert_false(PawnStatus.is_idle(facts), "drones are not staff")

func test_a_departing_pawn_is_counted_as_leaving_not_as_idle() -> void:
	var facts: PawnStatus.Facts = _facts()
	facts.resigned = true
	assert_false(PawnStatus.is_idle(facts), "they have somewhere to be")

# --- the problem line -----------------------------------------------------------------

## Idle, unhappy and bunks-short, from a hand-built roster.
func test_summary_counts_a_hand_built_roster() -> void:
	var idle: PawnStatus.Facts = _facts()
	var busy: PawnStatus.Facts = _working("Operating Refinery")
	var miserable: PawnStatus.Facts = _working("Hauling steel", JobData.Category.HAUL)
	var summary: PawnStatus.Summary = PawnStatus.summarize(
		[idle, busy, miserable], [0.9, 0.8, 0.2], 2)
	assert_eq(summary.idle, 1, "one pawn with nothing to do")
	assert_eq(summary.unhappy, 1, "one below the unhappy threshold")
	assert_eq(summary.leaving, 0)
	assert_eq(summary.bunks_short, 1, "three crew, two bunks")

func test_bunks_short_never_goes_negative() -> void:
	var summary: PawnStatus.Summary = PawnStatus.summarize([_facts()], [1.0], 8)
	assert_eq(summary.bunks_short, 0, "spare bunks are not a problem to report")

func test_a_resigning_pawn_is_counted_once_as_leaving() -> void:
	var quitting: PawnStatus.Facts = _facts()
	quitting.resignation_pending = true
	var summary: PawnStatus.Summary = PawnStatus.summarize([quitting], [0.1], 4)
	assert_eq(summary.leaving, 1)
	assert_eq(summary.unhappy, 0, "one person is one problem, not two")

func test_a_clear_roster_reports_clear() -> void:
	var summary: PawnStatus.Summary = PawnStatus.summarize(
		[_working("Operating Refinery")], [1.0], 4)
	assert_true(summary.is_clear())
	assert_eq(PawnStatus.summary_color(summary), UIPalette.TEXT_META, "grey when nothing is wrong")

func test_a_troubled_roster_goes_amber() -> void:
	var summary: PawnStatus.Summary = PawnStatus.summarize([_facts()], [1.0], 4)
	assert_false(summary.is_clear())
	assert_eq(PawnStatus.summary_color(summary), UIPalette.ATTENTION_TEXT)

## Every term prints even at zero, so the line never changes length under the eye.
func test_summary_text_always_states_all_four_terms() -> void:
	var text: String = PawnStatus.summary_text(PawnStatus.summarize([], [], 0))
	assert_string_contains(text, "0 IDLE")
	assert_string_contains(text, "0 UNHAPPY")
	assert_string_contains(text, "0 LEAVING")
	assert_string_contains(text, "0 BUNKS SHORT")

## Zero crew is the game_over condition, so this state is brief - but the panel
## must render it rather than erroring.
func test_an_empty_roster_summarises_without_erroring() -> void:
	var summary: PawnStatus.Summary = PawnStatus.summarize([], [], 0)
	assert_true(summary.is_clear())

func test_summarize_tolerates_a_short_happiness_array() -> void:
	# The roster is read a frame after a pawn was freed: the two arrays can
	# legitimately disagree in length for one refresh.
	var summary: PawnStatus.Summary = PawnStatus.summarize([_facts(), _facts()], [0.9], 4)
	assert_eq(summary.unhappy, 0, "the row with no happiness reading is not an unhappy row")
	assert_eq(summary.idle, 2, "and both rows are still counted for everything else")

# --- filters ---------------------------------------------------------------------

func test_all_passes_everything() -> void:
	assert_true(PawnStatus.passes(_facts(), 1.0, PawnStatus.Filter.ALL))
	assert_true(PawnStatus.passes(_working("Operating Refinery"), 0.1, PawnStatus.Filter.ALL))

func test_on_shift_filters_by_the_schedule() -> void:
	var off: PawnStatus.Facts = _facts()
	off.on_shift = false
	assert_false(PawnStatus.passes(off, 1.0, PawnStatus.Filter.ON_SHIFT))
	assert_true(PawnStatus.passes(_facts(), 1.0, PawnStatus.Filter.ON_SHIFT))

func test_idle_filter_matches_the_idle_count() -> void:
	assert_true(PawnStatus.passes(_facts(), 1.0, PawnStatus.Filter.IDLE))
	assert_false(PawnStatus.passes(_working("Operating Refinery"), 1.0, PawnStatus.Filter.IDLE))

func test_unhappy_filter_takes_the_number_and_the_notice() -> void:
	assert_true(PawnStatus.passes(_facts(), 0.2, PawnStatus.Filter.UNHAPPY), "below the threshold")
	assert_false(PawnStatus.passes(_facts(), 0.9, PawnStatus.Filter.UNHAPPY))
	var quitting: PawnStatus.Facts = _facts()
	quitting.resignation_pending = true
	assert_true(PawnStatus.passes(quitting, 0.95, PawnStatus.Filter.UNHAPPY),
		"a pawn can recover during their grace window and still be walking out")

func test_a_pawn_with_no_morale_reading_is_not_unhappy() -> void:
	assert_false(PawnStatus.passes(_facts(), -1.0, PawnStatus.Filter.UNHAPPY),
		"no reading is not a low reading")

func test_a_null_row_passes_nothing() -> void:
	for filter: PawnStatus.Filter in [PawnStatus.Filter.ALL, PawnStatus.Filter.ON_SHIFT,
			PawnStatus.Filter.IDLE, PawnStatus.Filter.UNHAPPY]:
		assert_false(PawnStatus.passes(null, 1.0, filter))

# --- sorting -----------------------------------------------------------------------

func test_status_sort_puts_the_actionable_rows_first() -> void:
	var leaving: PawnStatus.Facts = _facts()
	leaving.resigned = true
	var idle: PawnStatus.Facts = _facts()
	var travelling: PawnStatus.Facts = _working("Moving to Refinery", JobData.Category.MOVE)
	var busy: PawnStatus.Facts = _working("Operating Refinery")
	assert_lt(PawnStatus.sort_bucket(leaving), PawnStatus.sort_bucket(idle),
		"a shorter fuse sorts above a longer one")
	assert_lt(PawnStatus.sort_bucket(idle), PawnStatus.sort_bucket(travelling))
	assert_lt(PawnStatus.sort_bucket(travelling), PawnStatus.sort_bucket(busy))

func test_status_sort_breaks_ties_on_morale_then_name() -> void:
	var a: PawnStatus.Facts = _working("Operating Refinery")
	var b: PawnStatus.Facts = _working("Operating Refinery")
	assert_true(PawnStatus.compares_before(a, 0.3, "Zoe", b, 0.8, "Ana",
		PawnStatus.Sort.STATUS), "same bucket: the unhappier one comes first")
	assert_true(PawnStatus.compares_before(a, 0.5, "Ana", b, 0.5, "Zoe",
		PawnStatus.Sort.STATUS), "same bucket and morale: alphabetical")

func test_morale_sort_is_ascending() -> void:
	var a: PawnStatus.Facts = _working("Operating Refinery")
	var b: PawnStatus.Facts = _facts()
	assert_true(PawnStatus.compares_before(a, 0.1, "Zoe", b, 0.9, "Ana",
		PawnStatus.Sort.MORALE), "worst morale first, whatever they are doing")

func test_name_sort_ignores_status_and_morale() -> void:
	var a: PawnStatus.Facts = _facts()
	var b: PawnStatus.Facts = _working("Operating Refinery")
	assert_true(PawnStatus.compares_before(a, 0.9, "Ana", b, 0.1, "Zoe", PawnStatus.Sort.NAME))
	assert_false(PawnStatus.compares_before(b, 0.1, "Zoe", a, 0.9, "Ana", PawnStatus.Sort.NAME))

## A comparator that says "before" in both directions produces a non-total order
## and Godot's sort_custom is free to do anything with it, including crash.
func test_the_comparator_is_antisymmetric_in_every_order() -> void:
	var rows: Array[PawnStatus.Facts] = [_facts(), _working("Operating Refinery"),
		_working("Moving", JobData.Category.MOVE)]
	var morale: Array[float] = [0.4, 0.4, 0.9]
	var names: Array[String] = ["Ana", "Bo", "Cy"]
	for sort: PawnStatus.Sort in [PawnStatus.Sort.STATUS, PawnStatus.Sort.MORALE,
			PawnStatus.Sort.NAME]:
		for i: int in rows.size():
			for j: int in rows.size():
				var forward: bool = PawnStatus.compares_before(
					rows[i], morale[i], names[i], rows[j], morale[j], names[j], sort)
				var backward: bool = PawnStatus.compares_before(
					rows[j], morale[j], names[j], rows[i], morale[i], names[i], sort)
				if i == j:
					assert_false(forward, "no row precedes itself")
				else:
					assert_ne(forward, backward,
						"sort %d must order %s and %s exactly one way" % [sort, names[i], names[j]])

# --- tones -------------------------------------------------------------------------

func test_every_tone_has_a_colour_and_only_alert_takes_a_row_treatment() -> void:
	for tone: PawnStatus.Tone in [PawnStatus.Tone.WORKING, PawnStatus.Tone.TRANSIT,
			PawnStatus.Tone.IDLE, PawnStatus.Tone.ALERT]:
		assert_gt(PawnStatus.tone_color(tone).a, 0.0, "tone %d must be visible" % tone)
		var expected: UIPalette.Row = UIPalette.Row.AMBER if tone == PawnStatus.Tone.ALERT \
			else UIPalette.Row.INERT
		assert_eq(PawnStatus.tone_row(tone), expected)
