class_name EventConditionDifficultyAllowsRaids
extends EventCondition

## Eligible only when the chosen difficulty permits pirate raids (WI-37).
##
## Carry this on every member of the raid FAMILY - the raid itself and anything
## that can escalate into one (pirate_extortion's "refuse" branch) - so Peaceful
## never draws the card at all, rather than drawing one whose only real choice
## quietly does nothing. Non-pirate hazards (breakdowns, micrometeorites, hull
## breaches) are deliberately NOT part of the family: Peaceful removes raiders,
## not maintenance.

func is_met() -> bool:
	return Global.difficulty_raids_enabled()
