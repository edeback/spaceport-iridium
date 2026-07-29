class_name JobDriver_CollectPile
extends JobDriver

## Sweep up a ResourcePile (WI-44) - the replacement for the pile-collection job.
##
## Target A is the pile, target B the storage to carry it to, job.resource which
## of the pile's resources this trip is about.
##
## One behavioural upgrade over the job it replaces, which documented at length
## that it "deliberately does NOT reserve space in deposit_storage" because
## StorageData's job-tracking arrays were hard-typed to the haul job. Claims
## carry their own amount and care nothing about who is asking, so this now
## reserves both ends like any other haul - a pawn no longer walks a load across
## the station to a bin that filled up while it was travelling.

const FIND_SINK: int = 0
const RESERVE_PILE: int = 1
const RESERVE_SINK: int = 2
const GOTO_PILE: int = 3
const TAKE: int = 4
const GOTO_SINK: int = 5
const DEPOSIT: int = 6

func make_actions(_job: Job) -> Array[ActionBase]:
	var to_sink := Action_GotoTarget.new(JobTarget.Slot.B)
	to_sink.carries_cargo = true
	# source_slot A holds a PILE, not a storage, so Finder_StorageSink resolves no
	# priority floor and falls back to ANY_PRIORITY. That is the intended reading:
	# a pile has no priority of its own to out-rank, so any bin that will take the
	# goods is a valid destination.
	return [
		Action_FindBestTarget.new(Finder_StorageSink.new(), JobTarget.Slot.B),
		Action_ReservePile.new(JobTarget.Slot.A, JobTarget.Slot.B, true),
		Action_ReserveStorage.new(JobTarget.Slot.B, ClaimSpec.Kind.STORAGE_DEPOSIT, false),
		Action_GotoTarget.new(JobTarget.Slot.A),
		Action_TakeFromPile.new(JobTarget.Slot.A),
		to_sink,
		Action_DepositToStorage.new(JobTarget.Slot.B),
	] as Array[ActionBase]

## Past TAKE the pile is irrelevant - and usually gone, since it despawns the
## moment it empties. Before TAKE it has to still be holding something we could
## claim; once we hold the claim, get_available() reads zero by construction, so
## the claim itself is what keeps the job alive from that point.
func is_valid(job: Job) -> bool:
	if job.resource == null:
		return false
	if job.action_index() > TAKE:
		return true
	var pile: ResourcePile = _pile(job)
	if pile == null:
		return false
	if job.action_index() > RESERVE_PILE:
		return job.holds_claim(pile.claim_target_for(job.resource), ClaimSpec.Kind.PILE)
	return pile.get_available(job.resource) > 0

func can_do(job: Job, pawn: PawnBase) -> bool:
	if not is_valid(job):
		return false
	if pawn.inventory_component != null and pawn.inventory_component.space_available() <= 0:
		return false
	var pile: ResourcePile = _pile(job)
	if pile == null:
		return false
	# An in-module pile is not a graph vertex: anywhere inside a reachable module
	# is reachable, so the module is what gets tested. A free-floating one is an
	# EVA trip.
	if pile.parent_module != null:
		if not is_instance_valid(pile.parent_module) \
				or not Global.path_manager.is_reachable(pawn, pile.parent_module):
			return false
	elif not Global.path_manager.is_space_reachable(pawn):
		return false
	return StorageQuery.find_sink(pawn, job.resource) != null

func explain_block(job: Job, pawn: PawnBase) -> String:
	if job.resource == null:
		return "no resource set"
	var pile: ResourcePile = _pile(job)
	if pile == null:
		return "the pile is gone"
	if pawn.inventory_component != null and pawn.inventory_component.space_available() <= 0:
		return "%s is already carrying a full load" % pawn.pawn_name
	if pile.parent_module != null and not Global.path_manager.is_reachable(pawn, pile.parent_module):
		return "%s cannot reach the pile" % pawn.pawn_name
	if pile.parent_module == null and not Global.path_manager.is_space_reachable(pawn):
		return "%s cannot get outside to the pile" % pawn.pawn_name
	if StorageQuery.find_sink(pawn, job.resource) == null:
		return "no reachable storage will take %s" % job.resource.name
	return ""

## Both reservations, over exactly the stretch each is held for. The pile claim
## is spent by the withdraw at TAKE; the deposit claim by DEPOSIT.
func required_claims(job: Job, action_index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if action_index > RESERVE_PILE and action_index <= TAKE:
		var pile: ResourcePile = _pile(job)
		if pile != null:
			var stock: PileStock = pile.claim_target_for(job.resource)
			if stock != null:
				out.append(ClaimSpec.make(stock, ClaimSpec.Kind.PILE, job.count))
	if action_index > RESERVE_SINK and action_index <= DEPOSIT:
		var sink: StorageComponent = _sink(job)
		if sink != null:
			var bin: StorageData = sink.claim_target_for(job.resource)
			if bin != null:
				out.append(ClaimSpec.make(bin, ClaimSpec.Kind.STORAGE_DEPOSIT, job.count))
	return out

func _pile(job: Job) -> ResourcePile:
	return job.target_a.pile() if job.target_a != null else null

func _sink(job: Job) -> StorageComponent:
	if job.target_b == null or not job.target_b.is_alive():
		return null
	return job.target_b.component() as StorageComponent
