extends GutTest

## Unit tests for EventData eligibility rules (data/events/event_data.gd):
## is_eligible (cycle gate + all conditions met) and has_free_choice (the
## soft-lock guard - every card event must keep at least one cost-free choice).

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

# --- free-choice soft-lock guard ---------------------------------------------

func test_notification_event_has_free_choice() -> void:
	var event := _event(1)
	assert_true(event.has_free_choice(), "an event with no choices can never soft-lock")

func test_event_with_a_costless_choice_is_free() -> void:
	var event := _event(1)
	event.choices.append(_paid_choice())
	event.choices.append(EventChoice.new()) # empty cost = always takeable
	assert_true(event.has_free_choice())

func test_event_with_only_paid_choices_is_not_free() -> void:
	var event := _event(1)
	event.choices.append(_paid_choice())
	assert_false(event.has_free_choice(), "all-paid choices can soft-lock a broke player")

func _paid_choice() -> EventChoice:
	var choice := EventChoice.new()
	var resource := ResourceData.new()
	resource.id = &"credits"
	var cost: Dictionary[ResourceData, int] = {}
	cost[resource] = 50
	choice.cost = cost
	return choice
