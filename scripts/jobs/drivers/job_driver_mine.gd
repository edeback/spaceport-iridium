class_name JobDriver_Mine
extends JobDriver

## Fly out, fill the hold, bring it home (WI-44) - the replacement for
## the mining job.
##
## Target A is the asteroid (found, and re-found when one runs dry), target B the
## MiningComponent that wants the ore, target C its output storage. job.count is
## the remaining quota, which Action_Mine decrements as ore comes in.
##
## The asteroid-switching loop is the interesting part. The old job expressed it
## by driving a state enum backwards to Starting from three different places,
## each having to remember to disconnect the despawn signal first. Here it is one
## line of next_index_after(): if the rock is gone and there is still room in the
## hold, go back to the finder.

const FIND_ASTEROID: int = 0
const GOTO_ASTEROID: int = 1
const MINE: int = 2
const FIND_OUTPUT: int = 3
const GOTO_OUTPUT: int = 4
const DEPOSIT: int = 5

func make_actions(_job: Job) -> Array[ActionBase]:
	var to_output := Action_GotoTarget.new(JobTarget.Slot.C)
	to_output.carries_cargo = true
	return [
		Action_FindBestTarget.new(Finder_Asteroid.new(), JobTarget.Slot.A),
		Action_GotoTarget.new(JobTarget.Slot.A),
		Action_Mine.new(JobTarget.Slot.A, JobTarget.Slot.B),
		Action_FindBestTarget.new(Finder_MiningOutput.new(), JobTarget.Slot.C),
		to_output,
		Action_DumpInventory.new(JobTarget.Slot.C),
	] as Array[ActionBase]

## Mining trips are long and the miner is usually a drone with no skills
## component, so the multiplier and the xp both no-op - but the hook stays for
## crew miners, exactly as it did before.
func skill(_job: Job) -> StringName:
	return &"mining"

## The bay is required throughout: it is the destination, and losing it is what
## the old _module_removed handler failed the job for. Rocks are not - they are
## re-findable, and the quota only needs to be non-zero until the pawn turns for
## home.
func is_valid(job: Job) -> bool:
	return _bay(job) != null

func can_do(job: Job, pawn: PawnBase) -> bool:
	if not is_valid(job):
		return false
	if pawn.inventory_component != null and pawn.inventory_component.space_available() <= 0:
		return false
	if not Global.path_manager.is_space_reachable(pawn):
		return false
	return _any_ore_left(pawn)

func explain_block(job: Job, pawn: PawnBase) -> String:
	if _bay(job) == null:
		return "the mining bay is gone"
	if pawn.inventory_component != null and pawn.inventory_component.space_available() <= 0:
		return "%s is already carrying a full load" % pawn.pawn_name
	if not Global.path_manager.is_space_reachable(pawn):
		return "%s cannot get outside" % pawn.pawn_name
	if not _any_ore_left(pawn):
		return "no asteroid has anything left in it"
	return ""

## The one branch in the sequence: an asteroid that ran dry before the hold
## filled sends the pawn back to the finder rather than home half-loaded.
func next_index_after(job: Job, finished: int) -> int:
	if finished != MINE:
		return finished + 1
	if job.count <= 0:
		return FIND_OUTPUT
	if job.pawn == null or job.pawn.inventory_component == null:
		return FIND_OUTPUT
	if job.pawn.inventory_component.space_available() <= 0:
		return FIND_OUTPUT
	# Nothing left to mine anywhere, but the hold is not empty: bring home a
	# partial load rather than failing the trip and leaving the ore on the pawn
	# for the sweep to find, which is what the old job did.
	if not _any_ore_left(job.pawn):
		return FIND_OUTPUT if not job.pawn.inventory_component.is_empty() else FIND_ASTEROID
	# Still room and still quota: the only reason to be here is a spent rock.
	# Clearing the slot is what makes the finder run again rather than skip.
	job.target_a = null
	return FIND_ASTEROID

func _bay(job: Job) -> MiningComponent:
	if job.target_b == null or not job.target_b.is_alive():
		return null
	return job.target_b.component() as MiningComponent

func _any_ore_left(pawn: PawnBase) -> bool:
	for node: Node in pawn.get_tree().get_nodes_in_group(Groups.ASTEROID):
		var asteroid: AsteroidBase = node as AsteroidBase
		if asteroid != null and not asteroid.is_empty():
			return true
	return false
