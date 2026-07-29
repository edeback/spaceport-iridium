class_name Finder_WanderDestination
extends TargetFinder

## Somewhere - anywhere - reachable to drift to (WI-44).
##
## Deliberately random, so idle pawns do not all converge on the same module.
## That is safe despite the determinism rule: `make_actions()` is what has to be
## deterministic, not the finder. The chosen destination is written into a target
## slot once, and the slot is what gets saved.

func find(_job: Job, pawn: PawnBase) -> JobTarget:
	var candidates: Array[ModuleBase] = []
	for node: Node in pawn.get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null or not module.is_complete() or module == pawn.current_module:
			continue
		if Global.path_manager.is_reachable(pawn, module):
			candidates.append(module)
	if candidates.is_empty():
		return null
	return JobTarget.of_module(candidates.pick_random())

func describe() -> String:
	return "somewhere to go"
