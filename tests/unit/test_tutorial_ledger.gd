extends GutTest

## [TutorialLedger] - what the tutorial remembers (WI-63 §6).
##
## Pure, constructed directly. The most valuable test here is the last group: an
## absent save section has to restore as **complete**, and that decision is silent
## if it regresses - a veteran's save would simply start explaining corridors, and
## nothing would fail.

const EVERY: Array[StringName] = [&"a", &"b", &"c"]

var ledger: TutorialLedger

func before_each() -> void:
	ledger = TutorialLedger.new()

# --- spending -------------------------------------------------------------------

func test_a_fresh_ledger_has_given_nothing() -> void:
	assert_false(ledger.onboarding_done, "the introduction has not run")
	assert_false(ledger.skipped, "nobody opted out")
	assert_eq(ledger.spent_count(), 0, "no advisories given")
	assert_false(ledger.is_spent(&"a"), "an unspent hint reads unspent")

## The return value is what [TutorialManager] disconnects a watcher on, so "was
## this new" has to be the answer rather than "did it work".
func test_spending_is_news_exactly_once() -> void:
	assert_true(ledger.spend(&"a"), "the first spend is news")
	assert_false(ledger.spend(&"a"), "the second is not")
	assert_eq(ledger.spent_count(), 1, "and it was not recorded twice")

func test_spending_an_empty_id_is_refused() -> void:
	assert_false(ledger.spend(&""), "a hint with no id cannot be recorded")
	assert_eq(ledger.spent_count(), 0, "and nothing was stored")
	assert_push_error_count(1, "the refusal is loud")

## The AIDE archive renders newest-first, which is only meaningful if the ledger
## keeps an order at all - the reason this is an array rather than a set.
func test_spent_hints_keep_their_order() -> void:
	ledger.spend(&"c")
	ledger.spend(&"a")
	ledger.spend(&"b")
	assert_eq(ledger.spent_hints(), [&"c", &"a", &"b"] as Array[StringName],
		"oldest first, in the order they fired")

# --- skipping -------------------------------------------------------------------

func test_skipping_spends_everything() -> void:
	ledger.skip(EVERY)
	assert_true(ledger.onboarding_done, "the introduction will not run")
	assert_true(ledger.skipped, "and the ledger knows why")
	for id: StringName in EVERY:
		assert_true(ledger.is_spent(id), "'%s' will not interrupt anybody" % id)

func test_skipping_after_a_hint_fired_does_not_duplicate_it() -> void:
	ledger.spend(&"b")
	ledger.skip(EVERY)
	assert_eq(ledger.spent_count(), EVERY.size(), "each hint appears once")
	assert_eq(ledger.spent_hints()[0], &"b", "the one already given keeps its place")

func test_completing_the_onboarding_is_not_skipping_it() -> void:
	ledger.complete_onboarding()
	assert_true(ledger.onboarding_done, "it ran")
	assert_false(ledger.skipped, "nobody opted out")
	assert_eq(ledger.spent_count(), 0, "and the advisories are all still to come")

# --- the migration --------------------------------------------------------------

## The whole point of [method TutorialLedger.mark_legacy]: it looks like a skip
## from the outside, and AIDE tells the two apart on `skipped`.
func test_a_legacy_save_is_complete_but_was_not_skipped() -> void:
	ledger.mark_legacy(EVERY)
	assert_true(ledger.onboarding_done, "an old save does not get taught the game")
	assert_false(ledger.skipped, "because the player never opted out - it did not exist")
	assert_eq(ledger.spent_count(), EVERY.size(), "and no advisory is pending")

# --- persistence ----------------------------------------------------------------

## A saved section must never be an empty dictionary, or it becomes
## indistinguishable from the missing-section case that means the opposite thing.
func test_a_saved_ledger_is_never_an_empty_dictionary() -> void:
	assert_false(ledger.to_save().is_empty(), "even a pristine ledger writes a key")

func test_round_trip_preserves_everything() -> void:
	ledger.complete_onboarding()
	ledger.spend(&"c")
	ledger.spend(&"a")
	var restored := TutorialLedger.new()
	restored.from_save(ledger.to_save(), EVERY)
	assert_true(restored.onboarding_done, "the introduction stays run")
	assert_false(restored.skipped, "and stays un-skipped")
	assert_eq(restored.spent_hints(), [&"c", &"a"] as Array[StringName],
		"the archive keeps its order across a save")

func test_a_skipped_run_round_trips_as_skipped() -> void:
	ledger.skip(EVERY)
	var restored := TutorialLedger.new()
	restored.from_save(ledger.to_save(), EVERY)
	assert_true(restored.skipped, "AIDE still knows to say so")

## A mod that shipped a hint and was then removed. Keeping the entry would let it
## come back carrying a decision from a run that no longer makes sense.
func test_a_hint_that_no_longer_exists_is_dropped() -> void:
	ledger.spend(&"a")
	ledger.spend(&"gone")
	var restored := TutorialLedger.new()
	restored.from_save(ledger.to_save(), EVERY)
	assert_eq(restored.spent_hints(), [&"a"] as Array[StringName], "only what still exists")
	assert_push_warning_count(1, "and the drop is reported")

func test_loading_replaces_rather_than_merges() -> void:
	ledger.spend(&"a")
	ledger.from_save({"onboarding_done": false, "skipped": false, "spent": ["b"]}, EVERY)
	assert_eq(ledger.spent_hints(), [&"b"] as Array[StringName],
		"a load is a replacement, not an accumulation")

func test_clear_returns_a_ledger_to_pristine() -> void:
	ledger.skip(EVERY)
	ledger.clear()
	assert_false(ledger.onboarding_done, "the introduction is pending again")
	assert_false(ledger.skipped, "and nothing is recorded as opted out")
	assert_eq(ledger.spent_count(), 0, "every advisory is armed")
