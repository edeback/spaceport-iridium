class_name ResponseRules
extends RefCounted

## What a response row says, and when a line has no way forward (WI-62 §1).
##
## Extracted out of [DialogueBalloon] because it is a rule, and a rule belongs
## somewhere a GUT suite can construct it: the balloon needs a live scene, a
## [DialogueResource] and the addon's own menu widget before it will render
## anything, which is three reasons a defect here would only ever be caught by a
## screenshot.
##
## Pure: static, no [Global], no nodes. [DialogueResponse] is a plain [RefCounted]
## and constructs directly, which is what makes this testable at all.

## The tag a response uses to say **why** it is blocked, in words a player can
## read:
## [codeblock]
## - Turn him in [if story.flag("x") /] [#blocked=You never learned his name]
## [/codeblock]
##
## Tag values are comma-split by the addon's parser, so a blocker sentence must
## not contain a comma.
const BLOCKED_TAG: String = "blocked"

## What separates a response's text from its blocker. An en dash rather than a
## colon: a colon in a `.dialogue` line is the character/text separator, and
## while this string is built after compilation, keeping the two apart in the
## author's head is worth one character.
const BLOCKED_JOIN: String = " — "

## What an all-blocked response list offers instead of a dead modal.
const NO_OPTION_LABEL: String = "[ No option available — end transmission ]"

## The label a response row shows.
##
## An allowed response is its own text. A blocked one carries its reason, because
## **a blocked action names its blocker on its own control** - the console UI's
## standing rule (WI-57), and the reason [constant UIPalette.TEXT_DISABLED] is its
## own palette token: that sentence has to be readable.
##
## The fallback when no [constant BLOCKED_TAG] was authored is the raw condition
## expression. That is deliberately ugly. It is still a sentence naming the
## blocker, it is greppable, and it makes the author who forgot the tag find out
## from a screenshot rather than from nothing at all.
static func label_for(response: DialogueResponse) -> String:
	if response == null:
		return ""
	if response.is_allowed:
		return response.text
	var reason: String = response.get_tag_value(BLOCKED_TAG)
	if reason.is_empty():
		reason = response.condition_as_text
	if reason.is_empty():
		return response.text
	return response.text + BLOCKED_JOIN + reason

## Whether a blocked response is showing the raw expression rather than an
## authored sentence. Not used at runtime - it is what a content sweep would ask.
static func uses_raw_condition(response: DialogueResponse) -> bool:
	if response == null or response.is_allowed:
		return false
	return response.get_tag_value(BLOCKED_TAG).is_empty()

## Whether the player has any way forward. A line whose every response is gated is
## an **authoring mistake, not a game state**: it leaves a modal with no exit, and
## the balloon answers it with an escape hatch plus a `push_error` rather than
## treating it as a designed outcome.
##
## An empty list is not blocked - a line with no responses at all is the ordinary
## click-to-continue case.
static func is_all_blocked(responses: Array) -> bool:
	if responses.is_empty():
		return false
	for entry: Variant in responses:
		var response: DialogueResponse = entry as DialogueResponse
		if response == null or response.is_allowed:
			return false
	return true

## How many of the responses the player can actually take.
static func allowed_count(responses: Array) -> int:
	var count: int = 0
	for entry: Variant in responses:
		var response: DialogueResponse = entry as DialogueResponse
		if response != null and response.is_allowed:
			count += 1
	return count
