extends GutTest

## Unit tests for EventData eligibility rules (data/events/event_data.gd):
## is_eligible (the cycle gate plus every condition), and conditions_met on its
## own - which is what a **scheduled** event checks, having already skipped the
## roll, the cooldown and the cycle gate (WI-62 §5).
##
## The `has_free_choice` guard these tests used to carry is gone with
## [EventChoice]: a conversation's options are decided line by line at runtime, so
## the all-blocked case cannot be checked statically. Its replacement lives in
## [DialogueBalloon] (an escape hatch plus a `push_error`), and the static half
## that *can* be checked - that every event's cue exists - is
## `script_problem()`, swept in `test_event_content.gd`.

## Controllable EventCondition stand-in, so we can drive is_eligible without any
## live game state behind the real condition subclasses.
class StubCondition extends EventCondition:
	var met: bool = true
	func is_met() -> bool:
		return met

func _event(min_cycle: int) -> EventData:
	var event := EventData.new()
	event.id = &"evt"
	event.min_cycle = min_cycle
	return event

# --- cycle gate ---------------------------------------------------------------

func test_not_eligible_before_min_cycle() -> void:
	var event := _event(3)
	assert_false(event.is_eligible(2), "too early")
	assert_true(event.is_eligible(3), "eligible from the min cycle onward")
	assert_true(event.is_eligible(5), "and after")

# --- conditions ---------------------------------------------------------------

func test_unmet_condition_blocks_eligibility() -> void:
	var event := _event(1)
	var cond := StubCondition.new()
	cond.met = false
	event.conditions.append(cond)
	assert_false(event.is_eligible(5), "a failing condition blocks an otherwise-eligible event")
	cond.met = true
	assert_true(event.is_eligible(5), "and clears once it's met")

func test_all_conditions_must_be_met() -> void:
	var event := _event(1)
	var ok := StubCondition.new()
	ok.met = true
	var bad := StubCondition.new()
	bad.met = false
	event.conditions.append(ok)
	event.conditions.append(bad)
	assert_false(event.is_eligible(5), "one unmet condition is enough to block")

func test_null_conditions_are_ignored() -> void:
	var event := _event(1)
	event.conditions.append(null) # placeholder entry in authored data
	assert_true(event.is_eligible(5), "null condition slots don't block eligibility")

# --- the condition half on its own (WI-62) ------------------------------------
#
# A scheduled follow-up bypasses `min_cycle`, so `conditions_met` is the gate it
# is actually held to. The two must not drift into one another.

func test_conditions_met_ignores_the_cycle_gate() -> void:
	var event := _event(999)
	assert_false(event.is_eligible(5), "the cycle gate still blocks a natural roll")
	assert_true(event.conditions_met(),
		"but a scheduled follow-up only has to make sense in the world it lands in")

func test_conditions_met_still_respects_conditions() -> void:
	var event := _event(1)
	var cond := StubCondition.new()
	cond.met = false
	event.conditions.append(cond)
	assert_false(event.conditions_met(),
		"a follow-up whose prerequisite has gone away must not fire anyway")

# --- the runnability guard ----------------------------------------------------

func test_an_event_with_no_dialogue_names_its_problem() -> void:
	var event := _event(1)
	assert_string_contains(event.script_problem(), "dialogue",
		"an event that names no script must say so at load rather than fire and do nothing")

func test_an_event_with_a_dialogue_but_no_cue_names_its_problem() -> void:
	var event := _event(1)
	event.dialogue = DialogueResource.new()
	assert_string_contains(event.script_problem(), "cue")

func test_a_cue_that_is_not_in_the_resource_is_a_problem() -> void:
	var event := _event(1)
	event.dialogue = DialogueResource.new()
	event.dialogue.cues = {"hail": "0"}
	event.cue = "hale"
	assert_false(event.script_problem().is_empty(),
		"a typo would otherwise be an event that fires and does nothing, forever")
	event.cue = "hail"
	assert_eq(event.script_problem(), "", "and the correct cue is fine")
