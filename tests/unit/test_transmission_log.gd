extends GutTest

## Unit tests for WI-57's [TransmissionLog]: the bounded, saved, newest-first
## record of everything that arrived, and the unread state the console's COMMS
## badge counts.
##
## The log is a plain [RefCounted] precisely so this suite can construct one and
## drive every rule without a scene - [AlertManager] owns an instance and does the
## wiring, and none of the wiring is a rule.
##
## The rule these tests exist to protect is the one that differs from the alert
## queue: **repeats do not collapse**. Five arrivals from one trader are five
## rows, where five raises of one alert id are one row. Two lists, two rules, and
## a regression in either direction would be invisible until a player wondered why
## their log had one line in it.

func _log() -> TransmissionLog:
	return TransmissionLog.new()

## `n` posts from one sender, so the dedupe and cap tests read the same way.
func _fill(log: TransmissionLog, count: int, family: StringName = &"trader") -> void:
	for index: int in count:
		log.post(family, "Meridian Combine", "Docked at bay %d" % index, "", 1, index)

# --- posting -------------------------------------------------------------------

func test_a_post_lands_at_the_front() -> void:
	var log: TransmissionLog = _log()
	log.post(&"arc", "ARC Central", "First")
	log.post(&"arc", "ARC Central", "Second")
	assert_eq(log.size(), 2, "both were kept")
	assert_eq(log.entries()[0].subject, "Second", "newest first, so the panel renders in array order")

func test_a_post_stamps_the_cycle_and_hour_it_was_handed() -> void:
	var log: TransmissionLog = _log()
	var entry: TransmissionData = log.post(&"arc", "ARC Central", "Promotion", "", 7, 14)
	assert_eq(entry.cycle, 7, "the sim cycle is a game fact and is carried on the record")
	assert_eq(entry.hour, 14, "as is the hour")
	assert_eq(entry.stamp(), "Cycle 7 · 14:00", "and the row prints both")

func test_a_post_starts_unread() -> void:
	var log: TransmissionLog = _log()
	assert_true(log.post(&"arc", "ARC Central", "Promotion").unread,
		"nothing arrives already read")

func test_entries_is_a_copy() -> void:
	var log: TransmissionLog = _log()
	log.post(&"arc", "ARC Central", "First")
	var snapshot: Array[TransmissionData] = log.entries()
	log.post(&"arc", "ARC Central", "Second")
	assert_eq(snapshot.size(), 1,
		"a caller mid-render must not have a post appear in the array underneath it")

# --- the rule that differs from alerts ------------------------------------------

func test_repeated_arrivals_from_one_sender_do_not_collapse() -> void:
	var log: TransmissionLog = _log()
	_fill(log, 5)
	assert_eq(log.size(), 5,
		"five arrivals are five rows with five timestamps - this is not the alert queue")

func test_every_entry_gets_its_own_id() -> void:
	var log: TransmissionLog = _log()
	_fill(log, 5)
	var seen: Dictionary[StringName, bool] = {}
	for entry: TransmissionData in log.entries():
		assert_false(seen.has(entry.id), "id %s was minted twice" % entry.id)
		seen[entry.id] = true
	assert_eq(seen.size(), 5, "five distinct ids")

func test_the_id_shape_carries_the_family_and_the_sequence() -> void:
	var log: TransmissionLog = _log()
	log.post(&"contract", "Halcyon Freight", "Contract offered")
	var entry: TransmissionData = log.entries()[0]
	assert_eq(String(entry.id), "contract#1",
		"the id is family + sequence, so 'these do not dedupe' is legible at a glance")

func test_find_resolves_an_id() -> void:
	var log: TransmissionLog = _log()
	_fill(log, 3)
	var wanted: TransmissionData = log.entries()[1]
	assert_eq(log.find(wanted.id), wanted, "an id resolves back to its entry")
	assert_null(log.find(&"nothing#99"), "and an unknown id resolves to nothing")

# --- the cap --------------------------------------------------------------------

func test_the_log_is_bounded() -> void:
	var log: TransmissionLog = _log()
	_fill(log, TransmissionLog.CAP + 10)
	assert_eq(log.size(), TransmissionLog.CAP, "the buffer is bounded")

func test_the_cap_drops_the_oldest_first() -> void:
	var log: TransmissionLog = _log()
	log.post(&"arc", "ARC Central", "The very first thing")
	_fill(log, TransmissionLog.CAP)
	assert_eq(log.size(), TransmissionLog.CAP, "still capped")
	for entry: TransmissionData in log.entries():
		assert_ne(entry.subject, "The very first thing",
			"the oldest entry is the one that goes")

# --- unread state ---------------------------------------------------------------

func test_the_unread_count_matches_the_unread_entries() -> void:
	var log: TransmissionLog = _log()
	_fill(log, 4)
	assert_eq(log.unread_count(), 4, "everything starts unread")
	log.mark_read(log.entries()[0])
	assert_eq(log.unread_count(), 3, "reading one moves the count by one")
	assert_eq(log.unread().size(), 3, "and the list agrees with the count")

func test_marking_one_entry_read_twice_reports_no_second_change() -> void:
	var log: TransmissionLog = _log()
	var entry: TransmissionData = log.post(&"arc", "ARC Central", "Promotion")
	assert_true(log.mark_read(entry), "the first read is a change")
	assert_false(log.mark_read(entry), "the second is not, so no signal is emitted for it")

func test_mark_read_tolerates_a_null() -> void:
	assert_false(_log().mark_read(null), "a row whose entry went away is not a crash")

func test_mark_all_read_preserves_every_entry() -> void:
	var log: TransmissionLog = _log()
	_fill(log, 6)
	assert_true(log.mark_all_read(), "something changed")
	assert_eq(log.size(), 6, "MARK ALL READ zeroes the badge and deletes nothing")
	assert_eq(log.unread_count(), 0, "but the badge is zero")

func test_mark_all_read_on_an_already_read_log_reports_no_change() -> void:
	var log: TransmissionLog = _log()
	_fill(log, 3)
	log.mark_all_read()
	assert_false(log.mark_all_read(), "a second press is a no-op, not a repaint")

func test_has_unread_tracks_the_count() -> void:
	var log: TransmissionLog = _log()
	assert_false(log.has_unread(), "an empty log has nothing to read")
	log.post(&"arc", "ARC Central", "Promotion")
	assert_true(log.has_unread(), "and a post gives it something")

# --- families -------------------------------------------------------------------

func test_of_family_filters_without_reordering() -> void:
	var log: TransmissionLog = _log()
	log.post(&"arc", "ARC Central", "One")
	log.post(&"trader", "Meridian Combine", "Two")
	log.post(&"arc", "ARC Central", "Three")
	var arc: Array[TransmissionData] = log.of_family(&"arc")
	assert_eq(arc.size(), 2, "two ARC messages")
	assert_eq(arc[0].subject, "Three", "still newest first")

# --- persistence ----------------------------------------------------------------

func test_a_round_trip_preserves_order_unread_state_and_stamps() -> void:
	var log: TransmissionLog = _log()
	log.post(&"arc", "ARC Central", "Older", "the body", 2, 6, &"comms")
	log.post(&"trader", "Meridian Combine", "Newer", "", 3, 9, &"trade")
	log.mark_read(log.entries()[0])

	var restored: TransmissionLog = _log()
	restored.load_save(log.to_save())

	assert_eq(restored.size(), 2, "both entries survive")
	var entries: Array[TransmissionData] = restored.entries()
	assert_eq(entries[0].subject, "Newer", "order survives")
	assert_eq(entries[1].subject, "Older", "in both directions")
	assert_false(entries[0].unread, "the entry that was read stays read")
	assert_true(entries[1].unread, "and the one that was not stays unread")
	assert_eq(entries[1].cycle, 2, "the stamp survives")
	assert_eq(entries[1].hour, 6, "both halves of it")
	assert_eq(entries[1].body, "the body", "and so does the body the row expands to")
	assert_eq(entries[0].route, &"trade", "and the route it opens")

func test_an_absent_key_yields_an_empty_log() -> void:
	var log: TransmissionLog = _log()
	_fill(log, 3)
	log.load_save({})
	assert_eq(log.size(), 0, "a pre-WI-57 save loads as an empty log, not as an error")
	assert_eq(log.unread_count(), 0, "and with nothing on the badge")

func test_a_restored_log_does_not_re_mint_an_id_it_already_holds() -> void:
	var log: TransmissionLog = _log()
	_fill(log, 3)
	var restored: TransmissionLog = _log()
	restored.load_save(log.to_save())
	var fresh: TransmissionData = restored.post(&"arc", "ARC Central", "After the load")
	assert_eq(String(fresh.id), "arc#4",
		"the sequence continues past the restored entries rather than restarting at 1")

func test_a_truncated_save_still_cannot_produce_a_duplicate_id() -> void:
	var log: TransmissionLog = _log()
	_fill(log, 3)
	# A save whose counter was lost (hand-edited, or written by an older build).
	var data: Dictionary = log.to_save()
	data.erase("sequence")
	var restored: TransmissionLog = _log()
	restored.load_save(data)
	var fresh: TransmissionData = restored.post(&"arc", "ARC Central", "After the load")
	assert_null(log.find(fresh.id), "the counter is re-derived from the highest id it sees")
	assert_eq(String(fresh.id), "arc#4", "so the next id is still past the restored ones")

func test_a_save_of_an_empty_log_round_trips() -> void:
	var restored: TransmissionLog = _log()
	restored.load_save(_log().to_save())
	assert_true(restored.is_empty(), "an empty log saves and restores as an empty log")

func test_a_restored_log_is_still_capped() -> void:
	var data: Dictionary = {"sequence": 200, "entries": [] as Array}
	for index: int in TransmissionLog.CAP + 20:
		data["entries"].append(TransmissionData.create(
			&"trader", "Meridian Combine", "Docked %d" % index).to_dict())
	var log: TransmissionLog = _log()
	log.load_save(data)
	assert_eq(log.size(), TransmissionLog.CAP,
		"a save written by a build with a larger cap does not grow this one")

# --- the record ------------------------------------------------------------------

func test_an_entry_with_neither_subject_nor_route_has_no_action() -> void:
	var entry: TransmissionData = TransmissionData.create(&"arc", "ARC Central", "Noted")
	assert_false(entry.has_action(), "a row with nowhere to go loses its action")

func test_a_route_alone_is_an_action() -> void:
	var entry: TransmissionData = TransmissionData.create(
		&"contract", "Halcyon Freight", "Offer", "", &"trade")
	assert_true(entry.has_action(), "a route is enough to make the row clickable")

func test_a_freed_subject_costs_the_row_its_action_and_nothing_else() -> void:
	var entry: TransmissionData = TransmissionData.create(&"arc", "ARC Central", "Inspector aboard")
	var node := Node2D.new()
	entry.subject_ref = node
	assert_true(entry.has_action(), "a live subject is an action")
	node.free()
	assert_null(entry.subject_node(), "a freed subject reads as no subject rather than crashing")
	assert_false(entry.has_action(), "so the row keeps its text and loses its action")
	assert_eq(entry.subject, "Inspector aboard", "the text is untouched")

func test_a_non_object_subject_is_not_cast() -> void:
	var entry: TransmissionData = TransmissionData.create(&"arc", "ARC Central", "Noted")
	entry.subject_ref = 42
	assert_null(entry.subject_node(), "a Variant holding an int must not go through a cast")
