extends GutTest

## [EventSchedule] (WI-62 §5): "and then, four hours later…".
##
## Every rule is a static taking `hours_per_cycle` as a parameter rather than
## reaching for [TimeManager], which is the whole reason this can be tested at
## all. The numbers below use 24 to match the game, and one case uses 10 to prove
## nothing has 24 baked in.
##
## Pure: constructed directly, no [Global], no nodes.

const HOURS: int = 24

var schedule: EventSchedule

func before_each() -> void:
	schedule = EventSchedule.new()

# --- calendar arithmetic ----------------------------------------------------------

func test_a_delay_inside_the_cycle_stays_in_it() -> void:
	assert_eq(EventSchedule.advance(3, 6, 4, HOURS), Vector2i(3, 10))

func test_a_delay_that_crosses_midnight_rolls_the_cycle() -> void:
	assert_eq(EventSchedule.advance(3, 22, 4, HOURS), Vector2i(4, 2))

func test_a_delay_longer_than_a_cycle() -> void:
	assert_eq(EventSchedule.advance(3, 6, 50, HOURS), Vector2i(5, 8))

func test_landing_exactly_on_the_cycle_boundary() -> void:
	assert_eq(EventSchedule.advance(3, 20, 4, HOURS), Vector2i(4, 0))

func test_a_zero_delay_means_the_next_drain_not_never() -> void:
	assert_eq(EventSchedule.advance(3, 6, 0, HOURS), Vector2i(3, 6))
	assert_true(EventSchedule.is_due(3, 6, 3, 6))

func test_a_negative_delay_is_treated_as_now() -> void:
	assert_eq(EventSchedule.advance(3, 6, -5, HOURS), Vector2i(3, 6))

func test_the_cycle_length_is_a_parameter_not_a_constant() -> void:
	assert_eq(EventSchedule.advance(1, 8, 4, 10), Vector2i(2, 2),
		"a ten-hour cycle rolls over at ten")

func test_a_zero_cycle_length_does_not_divide_by_zero() -> void:
	assert_eq(EventSchedule.advance(1, 8, 4, 0), Vector2i(1, 8))

# --- due-ness ---------------------------------------------------------------------

func test_not_due_before_its_hour() -> void:
	assert_false(EventSchedule.is_due(3, 10, 3, 9))

func test_due_on_its_exact_hour() -> void:
	assert_true(EventSchedule.is_due(3, 10, 3, 10),
		"a four-hour delay fires on the fourth hour, not the fifth")

func test_due_after_its_hour() -> void:
	assert_true(EventSchedule.is_due(3, 10, 3, 11))

## The trap this pins: an hour-only comparison says 04:00 on cycle 4 is *earlier*
## than 22:00 on cycle 3, and the follow-up never fires.
func test_a_later_cycle_is_due_even_at_an_earlier_hour() -> void:
	assert_true(EventSchedule.is_due(3, 22, 4, 4))

func test_an_earlier_cycle_is_not_due_even_at_a_later_hour() -> void:
	assert_false(EventSchedule.is_due(4, 4, 3, 22))

# --- the queue --------------------------------------------------------------------

func test_queue_and_drain() -> void:
	schedule.queue(&"kestrel_pursuit", 3, 10)
	assert_eq(schedule.drain_due(3, 9).size(), 0, "not yet")
	assert_eq(schedule.drain_due(3, 10), [&"kestrel_pursuit"] as Array[StringName])

## Draining removes. A caller that fired an event and forgot to remove it would
## fire it every hour forever, and that failure is invisible until a player
## reports a conversation they cannot get rid of.
func test_draining_removes() -> void:
	schedule.queue(&"kestrel_pursuit", 3, 10)
	schedule.drain_due(3, 10)
	assert_eq(schedule.drain_due(4, 10).size(), 0)
	assert_eq(schedule.size(), 0)

func test_re_queueing_replaces_rather_than_stacking() -> void:
	# Two conversations that both ask for the same follow-up want one follow-up,
	# and the later ask is the one that knows the most.
	schedule.queue(&"kestrel_pursuit", 3, 10)
	schedule.queue(&"kestrel_pursuit", 5, 2)
	assert_eq(schedule.size(), 1)
	assert_eq(schedule.drain_due(3, 10).size(), 0, "the later due time won")
	assert_eq(schedule.drain_due(5, 2).size(), 1)

func test_two_due_at_once_come_back_oldest_first() -> void:
	schedule.queue(&"later", 4, 2)
	schedule.queue(&"earlier", 3, 8)
	var due: Array[StringName] = schedule.drain_due(9, 0)
	assert_eq(due, [&"earlier", &"later"] as Array[StringName])

func test_a_not_due_entry_survives_the_drain() -> void:
	schedule.queue(&"soon", 3, 8)
	schedule.queue(&"later", 9, 0)
	schedule.drain_due(3, 8)
	assert_eq(schedule.size(), 1)
	assert_true(schedule.has(&"later"))

func test_cancel() -> void:
	schedule.queue(&"kestrel_pursuit", 3, 10)
	assert_true(schedule.cancel(&"kestrel_pursuit"))
	assert_false(schedule.cancel(&"kestrel_pursuit"), "already gone")
	assert_eq(schedule.size(), 0)

func test_an_empty_id_is_refused() -> void:
	assert_false(schedule.queue(&"", 3, 10))
	assert_push_error("no id")
	assert_eq(schedule.size(), 0)

# --- persistence -------------------------------------------------------------------

func test_round_trip() -> void:
	schedule.queue(&"kestrel_pursuit", 5, 2)
	schedule.queue(&"something_else", 9, 18)
	var restored := EventSchedule.new()
	restored.from_save(schedule.to_save())
	assert_eq(restored.size(), 2)
	assert_eq(restored.drain_due(5, 2), [&"kestrel_pursuit"] as Array[StringName])
	assert_eq(restored.drain_due(9, 18), [&"something_else"] as Array[StringName])

func test_a_save_taken_between_queueing_and_firing_still_fires_once() -> void:
	schedule.queue(&"kestrel_pursuit", 5, 2)
	var restored := EventSchedule.new()
	restored.from_save(schedule.to_save())
	assert_eq(restored.drain_due(5, 2).size(), 1)
	assert_eq(restored.drain_due(5, 3).size(), 0, "and not a second time")

func test_a_malformed_saved_entry_is_skipped() -> void:
	var restored := EventSchedule.new()
	restored.from_save(["not a dictionary", {"cycle": 3, "hour": 4}])
	assert_eq(restored.size(), 0, "an entry with no id is dropped rather than queued as \"\"")
