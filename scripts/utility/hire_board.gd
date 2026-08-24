class_name HireBoard
extends RefCounted

## Who says what on the Crew panel's `HIRE` page: which blocker belongs to the
## page and which belongs to a single candidate's card.
##
## Pure and static, for the reason [InspectorTabPlan] is: this is a *rule*, and a
## rule inside a panel is a rule nobody can test. [HireTab] gathers the facts -
## whether a docking bay exists, and what [method CrewManager.hire_block_reason]
## said about each candidate - and this decides what the page reads like.
##
## **The one rule, stated once:** a blocker every card shares is the *page's*,
## not the card's. Four cards each printing NO FREE SLEEPING PODS under a page
## that also prints it is one sentence five times; the same page with one
## candidate priced out of reach and the rest affordable is genuinely per-card
## information and must stay on the rows.
##
## Note what this does **not** do: it never decides *whether* a hire is blocked.
## Every sentence handed to it came from [CrewManager], which owns that; a second
## copy of "is there a free bunk" living here is exactly the drift the one-place
## invariant exists to stop. The only sentence this file owns is
## [constant NO_BAY_REASON], because the docking-bay gate is a UI-side rule -
## the manager will happily hire into a station with nowhere to dock.

## Said when the station has no constructed docking bay. Not a bare "no docking
## bay": the sentence names the fix, because a player who cannot hire is the
## player who has not worked out that a bay is what they are missing.
const NO_BAY_REASON: String = "No docking bay — build one before anyone can arrive"

## The sentence the page prints above the list, or "" for no page-level blocker.
##
## The bay gate out-ranks everything the manager said: with nowhere to dock, it
## does not matter whether the station could afford the fare.
static func gate_reason(has_bay: bool, reasons: Array[String]) -> String:
	if not has_bay:
		return NO_BAY_REASON
	return shared_reason(reasons)

## The blocker every card shares, or "" when they differ or nothing is blocked.
##
## An empty list is unblocked by definition - a page with no candidates has no
## shared anything, and returning a blocker for it would print a sentence over an
## empty list.
static func shared_reason(reasons: Array[String]) -> String:
	if reasons.is_empty() or reasons[0].is_empty():
		return ""
	for reason: String in reasons:
		if reason != reasons[0]:
			return ""
	return reasons[0]

## What one card prints under its name: its own blocker, unless the page has
## already said it.
static func card_reason(reason: String, gate: String) -> String:
	return "" if reason == gate else reason

## Whether one card's HIRE button is pressable. The gate blocks every card even
## when no card's own reason does - which is exactly the docking-bay case, where
## the manager has no objection to any of them.
static func can_hire(reason: String, gate: String) -> bool:
	return reason.is_empty() and gate.is_empty()
