class_name TargetFinder
extends Resource

## A strategy object for "go and work out which thing this job should act on"
## (WI-44), in the same spirit as the PathBehavior strategies PathComponent
## already uses. Action_FindBestTarget runs one and writes the answer into a
## target slot.
##
## The point is the seven near-identical finders the pre-WI-44 job classes each
## carried (_find_pod, _find_charger, _find_bay x2, find_best_sustenance,
## _gather_candidates x2) - all of them "scan a group, drop the ones that are
## full or unreachable or won't accept this pawn, score by distance, return the
## best". One action plus a handful of these replaces all of it.

## The chosen target, or an unset/null target when there's nothing suitable.
## Must be a pure query: it runs from can_do() during board scans as well as from
## the action, so it cannot have side effects.
func find(_job: Job, _pawn: PawnBase) -> JobTarget:
	return null

## What this finder is looking for, for the board inspector's blocked-reason text.
func describe() -> String:
	return "target"
