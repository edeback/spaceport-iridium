class_name JobDriver_Haul
extends JobDriver

## Move a resource from one storage to another (WI-44) - the replacement for
## the haul job, which was 207 lines of which roughly 150 were movement
## plumbing, reservation bookkeeping, a five-state enum, and a hand-written
## save/restore pair. All of that is shared now.
##
## Target A is the SOURCE storage component, target B the DESTINATION,
## job.resource what to move, job.count how much.
##
## A posting component normally knows only one end: a bin below its desired
## amount posts a "pull" (B known, hunt for a source), a bin above it posts a
## "push" (A known, hunt for a destination). One fixed sequence serves both,
## because Action_FindBestTarget skips a slot that is already resolved - which is
## what keeps make_actions() deterministic, and therefore the saved action index
## meaningful.

const FIND_SOURCE: int = 0
const RESERVE_SOURCE: int = 1
const FIND_SINK: int = 2
const RESERVE_SINK: int = 3
const GOTO_SOURCE: int = 4
const TAKE: int = 5
const GOTO_SINK: int = 6
const DEPOSIT: int = 7
const FOLLOWUP: int = 8

func make_actions(_job: Job) -> Array[ActionBase]:
	var to_sink := Action_GotoTarget.new(JobTarget.Slot.B)
	# The walk home is carrying the goods, so PawnBase's "store your inventory
	# first" preemption must stand down for it - otherwise a reload mid-walk
	# sweeps the cargo into a random bin and the trip has to be redone.
	to_sink.carries_cargo = true
	return [
		Action_FindBestTarget.new(Finder_StorageSource.new(), JobTarget.Slot.A),
		Action_ReserveStorage.new(JobTarget.Slot.A, ClaimSpec.Kind.STORAGE_WITHDRAW, true),
		Action_FindBestTarget.new(Finder_StorageSink.new(), JobTarget.Slot.B),
		# Cuts the trip to the sink's real room and trims the withdraw at A to match.
		Action_ReserveStorage.new(JobTarget.Slot.B, ClaimSpec.Kind.STORAGE_DEPOSIT, false,
			JobTarget.Slot.A),
		Action_GotoTarget.new(JobTarget.Slot.A),
		Action_TakeFromStorage.new(JobTarget.Slot.A),
		to_sink,
		Action_DepositToStorage.new(JobTarget.Slot.B),
		# Delivering the last material a construction site needed hands the pawn
		# straight into building it, rather than posting to the board and letting
		# whoever is nearest next frame take it.
		Action_QueueFollowup.new(JobTarget.Slot.B),
	] as Array[ActionBase]

## A haul is alive while it has a resource and at least ONE end - the other side
## is still being hunted for. Same rule the pre-WI-44 job used.
func is_valid(job: Job) -> bool:
	if job.resource == null:
		return false
	return _storage(job.target_a) != null or _storage(job.target_b) != null

func can_do(job: Job, pawn: PawnBase) -> bool:
	if not is_valid(job):
		return false
	if pawn.inventory_component != null and pawn.inventory_component.space_available() <= 0:
		return false
	var source: StorageComponent = _storage(job.target_a)
	var sink: StorageComponent = _storage(job.target_b)
	if source != null and sink != null:
		# Fully specified: just confirm both ends are reachable.
		return Global.path_manager.is_reachable(pawn, source.owner_module) \
			and Global.path_manager.is_reachable(pawn, sink.owner_module)
	# Per-resource priorities, never the bins' raw `priority` fields - see
	# StorageQuery.source_qualifies for the WI-65 regression that caused.
	if sink != null:
		# Pull: destination fixed, need a reachable source with stock.
		return Global.path_manager.is_reachable(pawn, sink.owner_module) \
			and StorageQuery.find_source(pawn, job.resource,
				StorageQuery.trip_cap(pawn, job.count), sink.import_priority(job.resource)) != null
	# Push: source fixed, need a reachable destination with room.
	return Global.path_manager.is_reachable(pawn, source.owner_module) \
		and StorageQuery.find_sink(pawn, job.resource, source.export_priority(job.resource)) != null

func explain_block(job: Job, pawn: PawnBase) -> String:
	if job.resource == null:
		return "no resource set"
	if pawn.inventory_component != null and pawn.inventory_component.space_available() <= 0:
		return "%s is already carrying a full load" % pawn.pawn_name
	var source: StorageComponent = _storage(job.target_a)
	var sink: StorageComponent = _storage(job.target_b)
	if source == null and sink == null:
		return "both ends are gone"
	if sink != null and source == null:
		var ceiling: int = sink.import_priority(job.resource)
		# REFUSED is a separate answer, not a number to print.
		if ceiling == StorageComponent.REFUSED:
			return "%s no longer takes %s" % [sink.owner_module.module_data.name, job.resource.name]
		if StorageQuery.find_source(pawn, job.resource,
				StorageQuery.trip_cap(pawn, job.count), ceiling) == null:
			return "no reachable storage holds %s below priority %d" % [job.resource.name, ceiling]
	if source != null and sink == null:
		var floor_priority: int = source.export_priority(job.resource)
		if floor_priority == StorageComponent.REFUSED:
			return "%s no longer ships %s" % [source.owner_module.module_data.name, job.resource.name]
		if StorageQuery.find_sink(pawn, job.resource, floor_priority) == null:
			return "no reachable storage will take %s above priority %d" % [job.resource.name, floor_priority]
	for endpoint: StorageComponent in [source, sink]:
		if endpoint != null and not Global.path_manager.is_reachable(pawn, endpoint.owner_module):
			return "%s cannot reach %s" % [pawn.pawn_name, endpoint.owner_module.module_data.name]
	return ""

## Both reservations, from the action that took them onward. A resume re-takes
## these before the saved action runs; failing to re-take drops the job cleanly.
func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	# The withdraw reservation is SPENT at TAKE - the goods are on the pawn from
	# then on - so it must not be re-taken after that point, or the source bin
	# would have stock reserved against a job that already collected it.
	if action_index > RESERVE_SOURCE and action_index <= TAKE:
		var source: StorageComponent = _storage(job.target_a)
		if source != null:
			var bin: StorageData = source.claim_target_for(job.resource)
			if bin != null:
				out.append(ClaimSpec.make(bin, ClaimSpec.Kind.STORAGE_WITHDRAW, job.count))
	# Likewise the deposit reservation is spent at DEPOSIT.
	if action_index > RESERVE_SINK and action_index <= DEPOSIT:
		var sink: StorageComponent = _storage(job.target_b)
		if sink != null:
			var bin: StorageData = sink.claim_target_for(job.resource, true)
			if bin != null:
				out.append(ClaimSpec.make(bin, ClaimSpec.Kind.STORAGE_DEPOSIT, job.count))
	return out

func _storage(slot: JobTarget) -> StorageComponent:
	if slot == null or not slot.is_alive():
		return null
	return slot.component() as StorageComponent
