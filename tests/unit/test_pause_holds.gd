extends GutTest

## WI-58 stage 3.2: the sim names whatever is holding it.
##
## `TimeManager.pause_holders()` has existed since WI-53 and had exactly one
## consumer in the whole project - a cheat. Pressing un-pause under an
## outstanding hold snapped the button back with no explanation, and selecting a
## speed pill lit the pill while the clock stayed still. Both read as a broken
## control rather than as "something else is holding this", which is the clearest
## remaining violation of WI-57's *"a blocked action names its blocker on its own
## control"*.
##
## Pure: [method UITimeScaleSelect.hold_reason] is static and touches no node, no
## [Global] and no [SignalBus]; the constants it maps are declared on the five
## classes that take the holds.

## Every holder in the game, and the class that takes it. The sweep below asserts
## the table in `UITimeScaleSelect` covers exactly this set - a new modal that
## stops the sim without adding a sentence fails here rather than shipping a
## button that bounces for no stated reason.
func _declared_holders() -> Array[StringName]:
	return [
		AlertManager.PAUSE_HOLD,
		PauseMenu.PAUSE_HOLD,
		EventCard.PAUSE_HOLD,
		TradePanel.PAUSE_HOLD,
		GameOverScreen.PAUSE_HOLD,
	] as Array[StringName]

func test_nothing_holding_the_sim_says_nothing() -> void:
	assert_eq(UITimeScaleSelect.hold_reason([] as Array[StringName]), "",
		"an ordinary player pause needs no explanation")

func test_every_real_holder_has_a_sentence_and_a_short_form() -> void:
	for holder: StringName in _declared_holders():
		assert_true(UITimeScaleSelect.HOLD_REASONS.has(holder),
			"%s is a real pause holder, so it owes the player a sentence" % holder)
		assert_true(UITimeScaleSelect.HOLD_LABELS.has(holder),
			"%s also needs a form short enough for the console line" % holder)

## The console's time zone is 247px and the cycle line has room for about twenty
## characters. An over-long label does not overflow - it truncates, into
## something that reads like a different word.
func test_every_short_form_fits_the_console_line() -> void:
	for holder: StringName in UITimeScaleSelect.HOLD_LABELS:
		var label: String = UITimeScaleSelect.HOLD_LABELS[holder]
		assert_lte(label.length(), UITimeScaleSelect.HOLD_LABEL_MAX,
			"%s renders as \"%s\" without ellipsing" % [holder, label])
		assert_gt(label.length(), 3, "%s still says something" % holder)

## The short form is the line, the sentence is the tooltip - they are different
## things and the short one must not simply be the long one.
func test_the_short_form_and_the_sentence_differ() -> void:
	for holder: StringName in UITimeScaleSelect.HOLD_LABELS:
		assert_ne(UITimeScaleSelect.HOLD_LABELS[holder],
			UITimeScaleSelect.HOLD_REASONS[holder],
			"%s: the tooltip explains more than the line" % holder)

func test_no_sentence_describes_a_holder_that_does_not_exist() -> void:
	var real: Array[StringName] = _declared_holders()
	for holder: StringName in UITimeScaleSelect.HOLD_REASONS:
		assert_true(real.has(holder),
			"%s has a sentence but nothing takes that hold any more" % holder)
	for holder: StringName in UITimeScaleSelect.HOLD_LABELS:
		assert_true(real.has(holder),
			"%s has a label but nothing takes that hold any more" % holder)

## None of them may be a bare "unavailable" - the whole point is that the player
## learns what to go and do.
func test_every_sentence_says_something_specific() -> void:
	for holder: StringName in UITimeScaleSelect.HOLD_REASONS:
		var text: String = UITimeScaleSelect.HOLD_REASONS[holder]
		assert_gt(text.length(), 8, "%s says something" % holder)
		assert_false(text.to_lower().contains("unavailable"),
			"%s names its blocker rather than reporting one" % holder)

func test_the_first_holder_is_the_one_reported() -> void:
	var two: Array[StringName] = [EventCard.PAUSE_HOLD, PauseMenu.PAUSE_HOLD] as Array[StringName]
	assert_eq(UITimeScaleSelect.hold_reason(two),
		UITimeScaleSelect.HOLD_REASONS[EventCard.PAUSE_HOLD],
		"one sentence the player can act on, not a list to parse")

## A mod, or a holder somebody added without a sentence. It must still name the
## id: a bug report saying "held by cargo_inspection" is worth more than "held".
func test_an_unknown_holder_still_names_itself() -> void:
	var holders: Array[StringName] = [&"cargo_inspection"] as Array[StringName]
	assert_string_contains(UITimeScaleSelect.hold_reason(holders), "cargo_inspection",
		"the unknown id survives into the sentence")
	assert_string_contains(UITimeScaleSelect.hold_label(holders), "cargo_inspection",
		"and into the line")

func test_nothing_holding_says_nothing_in_either_form() -> void:
	var none: Array[StringName] = [] as Array[StringName]
	assert_eq(UITimeScaleSelect.hold_label(none), "", "no line")
	assert_eq(UITimeScaleSelect.hold_reason(none), "", "no tooltip")

## The pause split WI-53 drew and this item depends on: `paused` is the player's
## own flag and the *only* thing that saves; a hold is somebody else's and is
## never written to it.
func test_a_hold_is_not_the_players_pause() -> void:
	var manager: TimeManager = autofree(TimeManager.new())
	assert_false(manager.is_paused(), "a fresh manager is running")
	manager.hold_pause(&"probe")
	assert_true(manager.is_paused(), "a hold stops the sim")
	assert_false(manager.paused, "but it never touches the player's own flag")
	assert_eq(manager.pause_holders(), [&"probe"] as Array[StringName], "and it is reported")
	manager.release_pause(&"probe")
	assert_false(manager.is_paused(), "releasing resumes")
	assert_eq(UITimeScaleSelect.hold_reason(manager.pause_holders()), "",
		"and the control goes quiet again")

## Two holders compose; the sim runs again only when both let go.
func test_holds_compose_and_release_independently() -> void:
	var manager: TimeManager = autofree(TimeManager.new())
	manager.hold_pause(&"a")
	manager.hold_pause(&"b")
	manager.release_pause(&"a")
	assert_true(manager.is_paused(), "one holder left is still a hold")
	manager.release_pause(&"b")
	assert_false(manager.is_paused(), "the last release resumes")
