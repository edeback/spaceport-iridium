extends GutTest

## Unit tests for [PendingHires] - the paid-for-but-not-yet-a-pawn hires that
## [CrewManager]'s arrival timers, bunk gate and lose condition all count.
##
## Pure: constructs nothing, touches no Global and no SignalBus. The load-bearing
## case is the shuttle flight: a hire whose delay has run out is still pending
## until it is settled, or a station whose only crew is on final approach reads
## as abandoned.

const BAY: Dictionary = {"layer": 0, "cell": [4, 2]}

func _candidate(hire_name: String) -> Dictionary:
	return {"name": hire_name, "price": 120}

# --- the arrival delay ----------------------------------------------------------

func test_a_new_hire_is_pending() -> void:
	var hires := PendingHires.new()
	hires.add(BAY, _candidate("Ada"), 4.0)
	assert_eq(hires.count(), 1)
	assert_false(hires.is_empty())

func test_a_hire_short_of_its_delay_is_not_due() -> void:
	var hires := PendingHires.new()
	hires.add(BAY, _candidate("Ada"), 4.0)
	assert_eq(hires.advance(3.5).size(), 0, "half an hour still to go")
	assert_eq(hires.count(), 1)

func test_a_hire_is_due_once_its_delay_runs_out() -> void:
	var hires := PendingHires.new()
	var hire: Dictionary = hires.add(BAY, _candidate("Ada"), 4.0)
	hires.advance(3.0)
	var due: Array[Dictionary] = hires.advance(1.5)
	assert_eq(due.size(), 1)
	assert_true(is_same(due[0], hire), "the entry handed back is the one queued, so settle() can find it")

func test_each_hire_keeps_its_own_clock() -> void:
	var hires := PendingHires.new()
	hires.add(BAY, _candidate("Ada"), 1.0)
	hires.add(BAY, _candidate("Bo"), 4.0)
	var due: Array[Dictionary] = hires.advance(2.0)
	assert_eq(due.size(), 1)
	assert_eq(String((due[0]["candidate"] as Dictionary)["name"]), "Ada")

# --- the shuttle flight ---------------------------------------------------------

## The bug this class exists for: the pawn only exists once the shuttle docks, a
## few sim-seconds after the delay runs out. Until then the hire must still count.
func test_a_launched_hire_is_still_pending_until_settled() -> void:
	var hires := PendingHires.new()
	hires.add(BAY, _candidate("Ada"), 4.0)
	hires.advance(5.0)
	assert_eq(hires.count(), 1, "the shuttle is in flight - nobody has arrived and nobody has been refunded")
	assert_false(hires.is_empty(), "the lose check reads is_empty(); an empty list here ends the run")

func test_a_launched_hire_is_not_launched_twice() -> void:
	var hires := PendingHires.new()
	hires.add(BAY, _candidate("Ada"), 4.0)
	assert_eq(hires.advance(5.0).size(), 1)
	assert_eq(hires.advance(1.0).size(), 0, "one shuttle per hire, however long the flight takes")
	assert_eq(hires.count(), 1)

func test_settling_a_hire_removes_it() -> void:
	var hires := PendingHires.new()
	hires.add(BAY, _candidate("Ada"), 4.0)
	var hire: Dictionary = hires.advance(4.0)[0]
	assert_true(hires.settle(hire))
	assert_eq(hires.count(), 0)
	assert_true(hires.is_empty())

## Two hires can be equal dictionaries; settling one must not take the other.
func test_settle_matches_by_identity_not_by_value() -> void:
	var hires := PendingHires.new()
	var first: Dictionary = hires.add(BAY, _candidate("Ada"), 4.0)
	var second: Dictionary = hires.add(BAY, _candidate("Ada"), 4.0)
	assert_eq(first, second, "precondition: the two entries compare equal")
	hires.settle(second)
	assert_eq(hires.count(), 1)
	assert_true(hires.settle(first), "the one left is the first")

## A shuttle launched before a load can still dock after it; the load has already
## relaunched that hire, so the old shuttle must be told not to deliver.
func test_settling_a_hire_the_list_no_longer_holds_is_refused() -> void:
	var hires := PendingHires.new()
	var stale: Dictionary = hires.add(BAY, _candidate("Ada"), 4.0)
	hires.load_save(hires.to_save())
	assert_false(hires.settle(stale), "the reload built fresh entries")
	assert_eq(hires.count(), 1, "and the refused settle took nothing")

# --- persistence ------------------------------------------------------------------

func test_a_waiting_hire_round_trips_its_remaining_delay() -> void:
	var hires := PendingHires.new()
	hires.add(BAY, _candidate("Ada"), 4.0)
	hires.advance(1.5)
	var loaded := PendingHires.new()
	loaded.load_save(hires.to_save())
	assert_eq(loaded.count(), 1)
	assert_eq(loaded.advance(2.0).size(), 0, "2.5 hours were left, not 4")
	assert_eq(loaded.advance(0.6).size(), 1)

## The shuttle is not saved, so a hire saved mid-flight must come back due and
## launch again - not vanish with the fee already paid.
func test_a_hire_saved_mid_flight_launches_again_after_loading() -> void:
	var hires := PendingHires.new()
	hires.add(BAY, _candidate("Ada"), 4.0)
	hires.advance(4.0)
	var loaded := PendingHires.new()
	loaded.load_save(hires.to_save())
	assert_eq(loaded.count(), 1, "the paid hire survived the save")
	var due: Array[Dictionary] = loaded.advance(0.01)
	assert_eq(due.size(), 1, "and relaunches on the first tick after the load")
	assert_eq(String((due[0]["candidate"] as Dictionary)["name"]), "Ada")
	assert_eq((due[0]["bay"] as Dictionary), BAY)

func test_the_launched_flag_is_not_saved() -> void:
	var hires := PendingHires.new()
	hires.add(BAY, _candidate("Ada"), 4.0)
	hires.advance(4.0)
	var saved: Dictionary = hires.to_save()[0]
	assert_false(saved.has("launched"), "it describes a node the save does not carry")

## Saves from before this class wrote exactly these three keys.
func test_an_older_save_entry_loads() -> void:
	var hires := PendingHires.new()
	hires.load_save([{"remaining": 2.0, "bay": BAY, "candidate": _candidate("Ada")}])
	assert_eq(hires.count(), 1)
	assert_eq(hires.advance(2.0).size(), 1)

func test_loading_replaces_what_was_there() -> void:
	var hires := PendingHires.new()
	hires.add(BAY, _candidate("Ada"), 4.0)
	hires.load_save([])
	assert_true(hires.is_empty())
