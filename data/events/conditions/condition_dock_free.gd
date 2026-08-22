class_name EventConditionDockFree
extends EventCondition

## Eligible only when there is a finished docking bay and nothing is using it
## (WI-62 §7).
##
## This is the brief's *Damaged Ship Needs Help* prerequisite, and it is an
## **event condition** rather than a response condition on purpose: "a bay exists
## and is free" decides whether the hail happens at all. Gating the responses
## instead would mean hailing a station that cannot answer, and then telling the
## player so.
##
## It delegates to [method DialogueBridge.dock_is_free] rather than re-deriving
## the answer, so the `.dialogue` file's `[if station.dock_is_free() /]` and this
## gate can never disagree about what "free" means.

func is_met() -> bool:
	if Global.dialogue_runner == null or Global.dialogue_runner.bridge == null:
		return false
	return Global.dialogue_runner.bridge.dock_is_free()
