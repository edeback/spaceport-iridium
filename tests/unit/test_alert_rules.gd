extends GutTest

## Unit tests for WI-53's alert rules (AlertRules + AlertData): what each tier
## means, what an alert id is made of, what order rows come out in, what
## CLEAR ALL is allowed to take, and when a burst collapses into one row.
##
## The tier table is asserted as a table rather than per-call, because "CRITICAL
## is the only tier that pauses" is a claim about the whole enum - a fourth tier
## added later should fail here rather than quietly gain the pause.

var _sequence: int = 0

## An alert with a monotonic sequence, so ordering assertions don't depend on
## how fast the test ran.
func _alert(id: StringName, priority: AlertData.Priority = AlertData.Priority.LOW,
		title: String = "Something happened", raised_at: float = 0.0) -> AlertData:
	var alert := AlertData.create(id, priority, title)
	_sequence += 1
	alert.sequence = _sequence
	alert.raised_at = raised_at
	return alert

func _titles(rows: Array[AlertRules.Group]) -> Array[String]:
	var out: Array[String] = []
	for row: AlertRules.Group in rows:
		out.append(row.title())
	return out

func _ids(alerts: Array[AlertData]) -> Array[StringName]:
	var out: Array[StringName] = []
	for alert: AlertData in alerts:
		out.append(alert.id)
	return out

func before_each() -> void:
	_sequence = 0

# --- the tier table ------------------------------------------------------------

func test_only_critical_pauses() -> void:
	assert_false(AlertRules.pauses(AlertData.Priority.LOW), "low does not pause")
	assert_false(AlertRules.pauses(AlertData.Priority.HIGH), "high does not pause")
	assert_true(AlertRules.pauses(AlertData.Priority.CRITICAL), "critical pauses")

func test_only_low_is_transient() -> void:
	assert_true(AlertRules.ages_out(AlertData.Priority.LOW), "low ages out")
	assert_false(AlertRules.is_sticky(AlertData.Priority.LOW), "and is not sticky")
	for priority: AlertData.Priority in [AlertData.Priority.HIGH, AlertData.Priority.CRITICAL]:
		assert_false(AlertRules.ages_out(priority), "priority %d never ages out" % priority)
		assert_true(AlertRules.is_sticky(priority), "priority %d is sticky" % priority)

## Every tier, LOW included: the feed's `+ n more` line opens the log, and a
## hidden LOW alert the log did not keep is one the player can never find.
func test_every_tier_is_logged_to_history() -> void:
	for priority: AlertData.Priority in [AlertData.Priority.LOW, AlertData.Priority.HIGH,
			AlertData.Priority.CRITICAL]:
		assert_true(AlertRules.is_logged(priority), "priority %d is logged" % priority)

func test_cheat_messages_are_recognised_by_their_prefix() -> void:
	assert_true(AlertRules.is_cheat("CHEAT: built module reactor at (2, 3)"), "prefixed")
	assert_false(AlertRules.is_cheat("Hull breach in Reactor Hall"), "a real alert is not")

# --- ids -----------------------------------------------------------------------

func test_two_subjects_of_one_kind_are_two_alerts() -> void:
	var first := Node2D.new()
	var second := Node2D.new()
	autofree(first)
	autofree(second)
	assert_ne(AlertRules.make_id(&"breach", first), AlertRules.make_id(&"breach", second),
		"two modules breaching are two alerts, not one refreshed one")

func test_the_same_subject_dedupes_to_one_id() -> void:
	var module := Node2D.new()
	autofree(module)
	assert_eq(AlertRules.make_id(&"breach", module), AlertRules.make_id(&"breach", module),
		"a second breach in the same module refreshes rather than stacks")

func test_a_subjectless_alert_is_its_own_family() -> void:
	assert_eq(AlertRules.make_id(&"no_docking_bay"), &"no_docking_bay",
		"a station-wide alert needs no subject half")

func test_a_non_object_subject_is_stringified() -> void:
	assert_eq(AlertRules.make_id(&"need", &"hunger"), &"need|hunger", "the WI-05 key shape")

func test_family_is_everything_before_the_separator() -> void:
	assert_eq(AlertRules.family_of(&"need|hunger"), &"need", "split at the separator")
	assert_eq(AlertRules.family_of(&"no_docking_bay"), &"no_docking_bay", "or the whole id")

# --- ordering ------------------------------------------------------------------

func test_outstanding_criticals_sort_above_everything_regardless_of_recency() -> void:
	var old_critical: AlertData = _alert(&"raid", AlertData.Priority.CRITICAL)
	var new_high: AlertData = _alert(&"broken", AlertData.Priority.HIGH)
	var newest_low: AlertData = _alert(&"levelled", AlertData.Priority.LOW)
	var ordered: Array[AlertData] = AlertRules.order(
		[newest_low, new_high, old_critical] as Array[AlertData])
	assert_eq(_ids(ordered), [&"raid", &"broken", &"levelled"] as Array[StringName],
		"critical, then high, then low")

func test_within_a_band_the_newest_comes_first() -> void:
	var older: AlertData = _alert(&"a", AlertData.Priority.HIGH)
	var newer: AlertData = _alert(&"b", AlertData.Priority.HIGH)
	var ordered: Array[AlertData] = AlertRules.order([older, newer] as Array[AlertData])
	assert_eq(_ids(ordered), [&"b", &"a"] as Array[StringName], "newest first")

func test_an_acknowledged_critical_leaves_the_top_band() -> void:
	var critical: AlertData = _alert(&"raid", AlertData.Priority.CRITICAL)
	var high: AlertData = _alert(&"broken", AlertData.Priority.HIGH)
	critical.acknowledged = true
	var ordered: Array[AlertData] = AlertRules.order([critical, high] as Array[AlertData])
	assert_eq(_ids(ordered), [&"broken", &"raid"] as Array[StringName],
		"acknowledged criticals rank with the sticky band, newest first")

# --- the pause latch -----------------------------------------------------------

func test_an_unacknowledged_critical_holds_the_pause() -> void:
	var critical: AlertData = _alert(&"raid", AlertData.Priority.CRITICAL)
	assert_true(AlertRules.holds_pause(critical), "outstanding")
	critical.acknowledged = true
	assert_false(AlertRules.holds_pause(critical), "acknowledged releases it")

func test_a_critical_raised_during_a_load_never_pauses() -> void:
	var critical: AlertData = _alert(&"breach", AlertData.Priority.CRITICAL)
	critical.suppress_pause = true
	assert_false(AlertRules.holds_pause(critical), "a save must not open on a pause modal")
	assert_true(AlertRules.is_outstanding(critical), "but it is still an outstanding alert")

func test_three_criticals_are_one_pause() -> void:
	var alerts: Array[AlertData] = [
		_alert(&"a", AlertData.Priority.CRITICAL),
		_alert(&"b", AlertData.Priority.CRITICAL),
		_alert(&"c", AlertData.Priority.CRITICAL),
	]
	assert_eq(AlertRules.outstanding_count(alerts), 3, "three outstanding")
	assert_true(AlertRules.any_holds_pause(alerts), "and the sim is held")
	alerts[0].acknowledged = true
	alerts[1].acknowledged = true
	assert_true(AlertRules.any_holds_pause(alerts), "still held after two of three")
	alerts[2].acknowledged = true
	assert_false(AlertRules.any_holds_pause(alerts), "released only by the last")

# --- clearing ------------------------------------------------------------------

func test_clear_all_takes_low_and_high_and_leaves_outstanding_criticals() -> void:
	var low: AlertData = _alert(&"low", AlertData.Priority.LOW)
	var high: AlertData = _alert(&"high", AlertData.Priority.HIGH)
	var critical: AlertData = _alert(&"critical", AlertData.Priority.CRITICAL)
	var survivors: Array[AlertData] = AlertRules.survives_clear(
		[low, high, critical] as Array[AlertData])
	assert_eq(_ids(survivors), [&"critical"] as Array[StringName],
		"a clear that can dismiss a game-pausing alert defeats the tier")

func test_an_acknowledged_critical_is_clearable() -> void:
	var critical: AlertData = _alert(&"critical", AlertData.Priority.CRITICAL)
	critical.acknowledged = true
	assert_eq(AlertRules.survives_clear([critical] as Array[AlertData]).size(), 0,
		"once read, it is an ordinary row")

# --- ageing --------------------------------------------------------------------

func test_low_alerts_age_out_and_sticky_ones_do_not() -> void:
	var low: AlertData = _alert(&"low", AlertData.Priority.LOW, "x", 100.0)
	var high: AlertData = _alert(&"high", AlertData.Priority.HIGH, "x", 100.0)
	var critical: AlertData = _alert(&"crit", AlertData.Priority.CRITICAL, "x", 100.0)
	var pool: Array[AlertData] = [low, high, critical]
	assert_eq(AlertRules.expired(pool, 110.0).size(), 0, "nothing has expired at 10s")
	assert_eq(_ids(AlertRules.expired(pool, 116.0)), [&"low"] as Array[StringName],
		"only the low one, at 16s")

func test_the_ttl_boundary_is_inclusive() -> void:
	var low: AlertData = _alert(&"low", AlertData.Priority.LOW, "x", 0.0)
	assert_eq(AlertRules.expired([low] as Array[AlertData], AlertRules.LOW_TTL_SECONDS).size(), 1,
		"exactly at the TTL counts as expired")

# --- history -------------------------------------------------------------------

func test_history_is_trimmed_from_the_oldest_end() -> void:
	var history: Array[AlertData] = []
	for index: int in 5:
		history.append(_alert(StringName("a%d" % index), AlertData.Priority.HIGH))
	# Newest-first, the order the log is kept in.
	history.reverse()
	var trimmed: Array[AlertData] = AlertRules.trim_history(history, 3)
	assert_eq(_ids(trimmed), [&"a4", &"a3", &"a2"] as Array[StringName], "the newest three")

func test_history_shorter_than_the_cap_is_untouched() -> void:
	var history: Array[AlertData] = [_alert(&"a", AlertData.Priority.HIGH)]
	assert_eq(AlertRules.trim_history(history, 10).size(), 1, "nothing to drop")

func test_history_filters_by_priority() -> void:
	var high: AlertData = _alert(&"high", AlertData.Priority.HIGH)
	var critical: AlertData = _alert(&"crit", AlertData.Priority.CRITICAL)
	var pool: Array[AlertData] = [high, critical]
	assert_eq(_ids(AlertRules.filter_priority(pool, AlertData.Priority.CRITICAL)),
		[&"crit"] as Array[StringName], "criticals only")

func test_a_history_entry_round_trips_without_its_subject() -> void:
	var alert := AlertData.create(&"breach|17", AlertData.Priority.CRITICAL,
		"Hull breach", "Reactor Hall · seals in 1.5h")
	alert.cycle = 4
	alert.hour = 14
	alert.count = 3
	var restored: AlertData = AlertData.from_dict(alert.to_dict())
	assert_eq(restored.id, alert.id, "id")
	assert_eq(restored.priority, AlertData.Priority.CRITICAL, "priority")
	assert_eq(restored.title, "Hull breach", "title")
	assert_eq(restored.detail, "Reactor Hall · seals in 1.5h", "detail")
	assert_eq(restored.stamp(), "Cycle 4 · 14:00", "stamp")
	assert_eq(restored.count, 3, "repeat count")
	assert_null(restored.subject, "object references are never saved")

func test_a_restored_alert_can_never_pause_the_loaded_game() -> void:
	var alert := AlertData.create(&"breach|17", AlertData.Priority.CRITICAL, "Hull breach")
	var restored: AlertData = AlertData.from_dict(alert.to_dict())
	assert_true(restored.acknowledged, "history is already read")
	assert_false(AlertRules.holds_pause(restored), "and holds no pause")

func test_an_unknown_priority_resolves_to_high_rather_than_being_dropped() -> void:
	var restored: AlertData = AlertData.from_dict({"id": "x", "priority": 99})
	assert_eq(restored.priority, AlertData.Priority.HIGH,
		"a tier this build has never heard of was at least worth logging")

# --- coalescing ----------------------------------------------------------------

func test_a_family_below_the_threshold_stays_as_separate_rows() -> void:
	var rows: Array[AlertRules.Group] = AlertRules.group([
		_alert(&"ill|1", AlertData.Priority.HIGH, "Ada fell ill"),
		_alert(&"ill|2", AlertData.Priority.HIGH, "Bo fell ill"),
	] as Array[AlertData], 3)
	assert_eq(rows.size(), 2, "two crew are two facts the player can act on")
	assert_false(rows[0].is_collapsed(), "and neither row is a group")

func test_a_family_at_the_threshold_collapses_into_one_row() -> void:
	var alerts: Array[AlertData] = []
	for index: int in 6:
		var alert: AlertData = _alert(StringName("ill|%d" % index), AlertData.Priority.HIGH,
			"Someone fell ill")
		alert.group_title = "%d crew have fallen ill"
		alerts.append(alert)
	var rows: Array[AlertRules.Group] = AlertRules.group(alerts, 3)
	assert_eq(rows.size(), 1, "one row, not six")
	assert_true(rows[0].is_collapsed(), "collapsed")
	assert_eq(rows[0].size(), 6, "carrying all six")
	assert_eq(rows[0].title(), "6 crew have fallen ill", "with the family's own plural")

func test_a_collapsed_row_without_a_plural_falls_back_to_a_count() -> void:
	var alerts: Array[AlertData] = []
	for index: int in 3:
		alerts.append(_alert(StringName("jam|%d" % index), AlertData.Priority.HIGH, "Module jammed"))
	var rows: Array[AlertRules.Group] = AlertRules.group(alerts, 3)
	assert_eq(rows[0].title(), "Module jammed ×3", "an invented plural reads worse than a count")

func test_a_collapsed_family_keeps_its_highest_ranked_position() -> void:
	var alerts: Array[AlertData] = [_alert(&"high", AlertData.Priority.HIGH, "Broken down")]
	for index: int in 3:
		alerts.append(_alert(StringName("breach|%d" % index), AlertData.Priority.CRITICAL,
			"Hull breach"))
	var rows: Array[AlertRules.Group] = AlertRules.group(alerts, 3)
	assert_eq(rows.size(), 2, "the family plus the loner")
	assert_eq(rows[0].family, &"breach", "the critical family sorts to the top")
	assert_false(rows[0].is_clearable(), "and a group holding an outstanding critical is not clearable")

func test_grouping_is_disabled_by_a_threshold_of_one() -> void:
	var alerts: Array[AlertData] = []
	for index: int in 4:
		alerts.append(_alert(StringName("ill|%d" % index), AlertData.Priority.HIGH, "Ill"))
	assert_eq(AlertRules.group(alerts, 1).size(), 4, "no collapsing at all")

# --- the cap -------------------------------------------------------------------

func test_the_feed_caps_its_rows_and_counts_the_hidden_alerts() -> void:
	var alerts: Array[AlertData] = []
	for index: int in 9:
		alerts.append(_alert(StringName("a%d" % index), AlertData.Priority.HIGH, "Alert"))
	var rows: Array[AlertRules.Group] = AlertRules.group(alerts, AlertRules.COALESCE_THRESHOLD)
	assert_eq(AlertRules.visible(rows, 6).size(), 6, "six rows shown")
	assert_eq(AlertRules.overflow(rows, 6), 3, "and three more summarised")

func test_overflow_counts_alerts_rather_than_rows() -> void:
	var alerts: Array[AlertData] = []
	# The family first, so the two loners are newer and the collapsed row is the
	# one the cap hides - which is the case the count has to get right.
	for index: int in 4:
		alerts.append(_alert(StringName("ill|%d" % index), AlertData.Priority.HIGH, "Ill"))
	for index: int in 2:
		alerts.append(_alert(StringName("a%d" % index), AlertData.Priority.HIGH, "Alert"))
	var rows: Array[AlertRules.Group] = AlertRules.group(alerts, 3)
	assert_eq(rows.size(), 3, "two loners plus one collapsed family")
	assert_eq(AlertRules.overflow(rows, 2), 4,
		"the hidden row stands for four alerts, and saying '1 more' would be a lie")

func test_a_short_feed_has_no_overflow() -> void:
	var rows: Array[AlertRules.Group] = AlertRules.group(
		[_alert(&"a", AlertData.Priority.HIGH)] as Array[AlertData])
	assert_eq(AlertRules.overflow(rows), 0, "nothing hidden")

func test_the_feed_cap_by_state() -> void:
	assert_eq(AlertRules.feed_cap(false), AlertRules.FEED_CAP, "the ordinary feed")
	assert_eq(AlertRules.feed_cap(true), AlertRules.COMPACT_CAP, "a selection is open")
	assert_lt(AlertRules.COMPACT_CAP, AlertRules.FEED_CAP, "compact is actually smaller")

## Zero would hide a critical that paused the sim behind a deselect.
func test_the_compact_feed_still_shows_a_row() -> void:
	assert_gte(AlertRules.COMPACT_CAP, 1, "compact never hides every alert")

## The one row a compact feed keeps is the most severe one, and the overflow line
## still accounts for everything else - counted in alerts, not rows.
func test_the_compact_feed_keeps_the_most_severe_row() -> void:
	var alerts: Array[AlertData] = [
		_alert(&"low", AlertData.Priority.LOW, "Low"),
		_alert(&"crit", AlertData.Priority.CRITICAL, "Critical"),
		_alert(&"high", AlertData.Priority.HIGH, "High"),
	]
	for index: int in 3:
		alerts.append(_alert(StringName("ill|%d" % index), AlertData.Priority.HIGH, "Ill"))
	var rows: Array[AlertRules.Group] = AlertRules.group(alerts)
	var shown: Array[AlertRules.Group] = AlertRules.visible(rows, AlertRules.COMPACT_CAP)
	assert_eq(_titles(shown), ["Critical"] as Array[String], "the critical leads")
	assert_eq(AlertRules.overflow(rows, AlertRules.COMPACT_CAP), alerts.size() - 1,
		"every other alert is in the + n more count")

# --- actionability -------------------------------------------------------------

func test_an_alert_with_a_route_is_actionable_without_a_subject() -> void:
	var alert: AlertData = _alert(&"contract", AlertData.Priority.HIGH)
	assert_false(AlertRules.is_actionable(alert), "nothing to click through to yet")
	alert.route = &"trade"
	assert_true(AlertRules.is_actionable(alert), "a contract offer opens Trade")

func test_a_freed_subject_costs_the_row_its_jump_and_nothing_else() -> void:
	var module := Node2D.new()
	var alert: AlertData = _alert(&"breach", AlertData.Priority.CRITICAL)
	alert.subject = module
	assert_true(alert.has_live_subject(), "live while the module exists")
	module.free()
	assert_false(alert.has_live_subject(), "and gone once it does not")
	assert_null(alert.subject_node(), "with no dangling reference handed out")
	assert_true(AlertRules.is_outstanding(alert), "the alert itself survives its subject")
