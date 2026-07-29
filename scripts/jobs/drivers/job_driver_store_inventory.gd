class_name JobDriver_StoreInventory
extends JobDriver

## The cargo sweep (WI-44) - the replacement for Job_StoreInventory.
##
## Not saveable: PawnBase re-creates it from whatever the pawn is actually
## carrying, so persisting it would only duplicate what the inventory already
## says. That is a flag on the .tres now, rather than an omission from a
## hand-maintained registry that a new job type could silently miss.
##
## Loops: after putting down what one bin accepts, if the pawn is still carrying
## something with somewhere to go, it finds the next bin instead of ending and
## waiting to be re-picked.

const FIND: int = 0
const GOTO: int = 1
const DUMP: int = 2

func make_actions(_job: Job) -> Array[ActionBase]:
	var travel := Action_GotoTarget.new(JobTarget.Slot.A)
	travel.carries_cargo = true
	return [
		Action_FindBestTarget.new(Finder_CarriedCargoSink.new(), JobTarget.Slot.A),
		travel,
		Action_DumpInventory.new(JobTarget.Slot.A),
	] as Array[ActionBase]

## Alive while the pawn still has something to put down. An unclaimed sweep has
## no pawn yet, so that case defers to can_do().
func is_valid(job: Job) -> bool:
	if job.pawn == null:
		return true
	return job.pawn.inventory_component != null and not job.pawn.inventory_component.is_empty()

func can_do(job: Job, pawn: PawnBase) -> bool:
	if pawn.inventory_component == null or pawn.inventory_component.is_empty():
		return false
	return Finder_CarriedCargoSink.new().find(job, pawn) != null

func explain_block(_job: Job, pawn: PawnBase) -> String:
	if pawn.inventory_component == null or pawn.inventory_component.is_empty():
		return "carrying nothing"
	return "no reachable storage will take what %s is carrying" % pawn.pawn_name

## Keep going while there is more cargo with somewhere to go. The find step is
## re-entered rather than reusing the old bin, since the next resource may belong
## somewhere else entirely - so the slot is cleared first, or the finder would
## skip over it as already resolved.
func next_index_after(job: Job, finished: int) -> int:
	if finished != DUMP or job.pawn == null or job.pawn.inventory_component == null:
		return finished + 1
	if job.pawn.inventory_component.is_empty():
		return finished + 1
	if Finder_CarriedCargoSink.new().find(job, job.pawn) == null:
		return finished + 1
	job.target_a = null
	return FIND
