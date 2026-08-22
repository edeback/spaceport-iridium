extends GutTest

## [ResponseRules] (WI-62 §1): what a response row says, and when a line has no
## way forward.
##
## These are the two rules the dialogue balloon most needs right and least easily
## shows: a blocked response that says nothing is a dead control the player cannot
## explain, and a line whose every option is gated is a modal with no exit.
## Extracting them out of the balloon is what makes either testable without a live
## scene, a compiled [DialogueResource] and the addon's own menu widget.
##
## Pure: [DialogueResponse] is a plain [RefCounted] and constructs directly.

func _response(text: String, allowed: bool = true, blocked_reason: String = "",
		condition_text: String = "") -> DialogueResponse:
	var response := DialogueResponse.new()
	response.text = text
	response.is_allowed = allowed
	response.condition_as_text = condition_text
	if not blocked_reason.is_empty():
		response.tags = PackedStringArray(["%s=%s" % [ResponseRules.BLOCKED_TAG, blocked_reason]])
	return response

# --- labels -----------------------------------------------------------------------

func test_an_allowed_response_is_just_its_text() -> void:
	assert_eq(ResponseRules.label_for(_response("Pay the ransom")), "Pay the ransom")

func test_an_allowed_response_ignores_a_blocked_tag_it_happens_to_carry() -> void:
	# A tag left on a response whose condition later became always-true must not
	# start appending an explanation to a working button.
	var response: DialogueResponse = _response("Pay the ransom", true, "You cannot raise 600 credits")
	assert_eq(ResponseRules.label_for(response), "Pay the ransom")

func test_a_blocked_response_carries_its_authored_reason() -> void:
	var response: DialogueResponse = _response(
		"Pay the ransom", false, "You cannot raise 600 credits", 'station.credits_held() >= 600')
	assert_eq(ResponseRules.label_for(response),
		"Pay the ransom" + ResponseRules.BLOCKED_JOIN + "You cannot raise 600 credits",
		"the authored sentence wins over the expression")

## Deliberately ugly, and deliberately not silent: it is still a sentence naming
## the blocker, and it is what makes the author who forgot the tag find out from a
## screenshot rather than from nothing at all.
func test_a_blocked_response_with_no_tag_falls_back_to_the_raw_condition() -> void:
	var response: DialogueResponse = _response(
		"Pay the ransom", false, "", 'station.credits_held() >= 600')
	assert_string_contains(ResponseRules.label_for(response), "station.credits_held()")

func test_a_blocked_response_with_neither_is_at_least_still_its_text() -> void:
	assert_eq(ResponseRules.label_for(_response("Pay the ransom", false)), "Pay the ransom")

func test_a_null_response_does_not_crash() -> void:
	assert_eq(ResponseRules.label_for(null), "")

func test_uses_raw_condition_finds_the_untagged_ones() -> void:
	assert_true(ResponseRules.uses_raw_condition(_response("x", false, "", "a > b")))
	assert_false(ResponseRules.uses_raw_condition(_response("x", false, "because")))
	assert_false(ResponseRules.uses_raw_condition(_response("x", true)),
		"an allowed response is not showing a condition at all")

# --- the soft-lock guard --------------------------------------------------------------

## The ordinary click-to-continue line. It has no responses, and it is emphatically
## not blocked - treating it as blocked would put an escape hatch under every line
## of narration in the game.
func test_a_line_with_no_responses_is_not_blocked() -> void:
	assert_false(ResponseRules.is_all_blocked([]))

func test_one_open_response_is_enough() -> void:
	var responses: Array = [
		_response("Blocked", false, "because"),
		_response("Open"),
		_response("Also blocked", false, "because"),
	]
	assert_false(ResponseRules.is_all_blocked(responses))
	assert_eq(ResponseRules.allowed_count(responses), 1)

func test_every_response_blocked_is_a_soft_lock() -> void:
	var responses: Array = [
		_response("Blocked", false, "because"),
		_response("Also blocked", false, "because"),
	]
	assert_true(ResponseRules.is_all_blocked(responses))
	assert_eq(ResponseRules.allowed_count(responses), 0)

## A null slot in an authored array must not be read as "blocked" and trigger the
## escape hatch on a line that is otherwise fine.
func test_a_null_entry_does_not_count_as_blocked() -> void:
	assert_false(ResponseRules.is_all_blocked([null]))
	assert_eq(ResponseRules.allowed_count([null]), 0)

func test_the_escape_hatch_label_says_what_it_is() -> void:
	assert_string_contains(ResponseRules.NO_OPTION_LABEL.to_lower(), "no option available")
	assert_string_contains(ResponseRules.NO_OPTION_LABEL.to_lower(), "end")
