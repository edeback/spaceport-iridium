class_name StorageData
extends ResourceStackContainer

## Which directions hauling may move this resource (WI-65). Replaces the
## component-level accepts_imports/accepts_exports pair, which could not express
## "this bin pulls gold ore in AND pushes gold out" - the reason a refinery
## needed two StorageComponents.
##
## Four values, not three, because two booleans have four states: EXCLUDED is
## the fourth corner, so converting the flag pair to this enum loses nothing and
## a bin frozen out of hauling stays expressible.
##
## Roles govern HAULING, not the storage API. deposit()/withdraw_stacks() and
## friends ignore role entirely - a processor deposits into its own OUTPUT slot,
## and ConstructionComponent consumes materials out of an EXCLUDED bin.
enum Role {
	## Receives and ships. Storerooms.
	GENERAL,
	## Receives only. Recipe ingredients, galley food, reactor fuel, sell-order
	## staging. Its `desired` is a hard cap (WI-65 §11).
	INPUT,
	## Ships only, always at StoresModel.PRIORITY_MIN. Recipe products, mined
	## ore, arriving purchases, deconstruction refunds.
	OUTPUT,
	## Neither. A bin frozen out of hauling - construction storage before its
	## site is a blueprint, and after a free module needs no materials.
	EXCLUDED,
}

@export var role: Role = Role.GENERAL
@export var desired: int = 0
@export var reserved_withdraw: int = 0
@export var reserved_deposit: int = 0
## The outstanding board jobs this bin has posted, so it doesn't post a second
## one for the same deficit/surplus: a pull it wants filled, a push it wants
## emptied. Reservations are NOT tracked here any more - they are claims, and
## reserved_withdraw/reserved_deposit above are maintained by the claimable
## contract below (WI-44). A haul restored from a save comes back through
## StorageComponent.adopt_restored_job (WI-70).
var import_slot: JobSlot = JobSlot.new()
var export_slot: JobSlot = JobSlot.new()
## Destroy stock above this level; -1 disables, which is the default and what
## nearly every bin stays at.
##
## Separate from `desired` because they are different decisions taken at
## different levels. `desired` is where hauling stops filling; this is where the
## station starts destroying, and the gap between them is the grace an export job
## gets to move the surplus somewhere useful before the vent opens. With one
## number the two mechanisms raced over the same units and which won depended on
## whether a hauler happened to be free.
##
## Must sit at or above `desired` - the reverse of what a cap-shaped reading
## suggests - because a threshold BELOW desired would destroy stock the bin is
## still actively asking to be filled with.
@export var autodump_above: int = -1

# --- role predicates (WI-65) --------------------------------------------------
#
# Pure, and deliberately here rather than on StorageComponent: they are questions
# about one slot, they need nothing but `role`, and keeping them on this class is
# what lets the GUT suite drive the whole routing table without a scene tree.

## Will hauling ever bring goods INTO this slot?
func accepts_imports() -> bool:
	return role == Role.GENERAL or role == Role.INPUT

## Will hauling ever take goods OUT of this slot?
func accepts_exports() -> bool:
	return role == Role.GENERAL or role == Role.OUTPUT

## How much this slot wants hauled away right now (WI-65 §4).
##
## The role decides what "surplus" means. A GENERAL bin ships what it holds over
## its target; an OUTPUT slot ships everything, because its `desired` is a
## capacity bound rather than a level to sit at and its whole purpose is to be
## emptied. INPUT ships nothing - an over-cap INPUT slot sheds to the module's
## overflow pile instead (§12), never through the board, because it would post at
## a priority no ordinary storeroom can out-rank.
func exportable_surplus() -> int:
	match role:
		Role.GENERAL:
			return maxi(stored - reserved_withdraw - desired, 0)
		Role.OUTPUT:
			return maxi(stored - reserved_withdraw, 0)
		_:
			return 0

func end_all_jobs() -> void:
	# cancel_live lets go BEFORE cancelling: ending a job releases its claims,
	# which re-enters this storage, and clearing first is what keeps that
	# re-entrancy safe.
	for slot: JobSlot in [import_slot, export_slot]:
		var job: Job = slot.cancel_live(true)
		if job != null and Global.job_manager != null:
			Global.job_manager.remove_job(job)

func set_job_priority(new_priority: int) -> void:
	for slot: JobSlot in [import_slot, export_slot]:
		var job: Job = slot.job()
		if job != null:
			job.priority = new_priority

## How much autodump is allowed to destroy: surplus over `autodump_above`, minus
## anything a hauler has already reserved a withdrawal against. Without the
## reserved term a pawn walking to this bin arrives to find its stock deleted
## and the trip is wasted (WI-38 A4). Kept here, and out of
## StorageComponent.destroy_resource, because that is also the module-destruction
## and eject path, where ignoring reservations is the correct behavior.
##
## Zero when disabled, which is the only state a bin reaches without the player
## explicitly turning it on - venting stock is exactly the kind of loss the
## no-silent-resource-loss rule is about.
func autodump_amount() -> int:
	if autodump_above < 0:
		return 0
	return maxi(stored - autodump_above - reserved_withdraw, 0)

## Is autodump on for this slot? One question with one answer, rather than a bool
## beside a threshold that could disagree with it.
func autodump_enabled() -> bool:
	return autodump_above >= 0

## Stock nobody has already spoken for - the `AVAIL` column of the Trade panel
## (WI-55), and the amount-form of [method can_withdraw] with use_reserve false.
##
## Clamped at zero rather than allowed to go negative: `reserved_withdraw` can
## legitimately exceed `stored` for a moment while a job holds a claim against
## stock a second path already removed, and a negative "available" would read as
## a debt the player owes rather than as "nothing spare".
func available_to_withdraw() -> int:
	return maxi(stored - reserved_withdraw, 0)

func can_withdraw(quantity: int, use_reserve: bool) -> bool:
	var available: int = stored
	if not use_reserve:
		available -= reserved_withdraw
	return available >= quantity

## Core withdraw shared by the generic (bool) and stack-aware APIs below.
func _do_withdraw(quantity: int, use_reserve: bool) -> Array[ResourceStack]:
	if not can_withdraw(quantity, use_reserve):
		return []
	var withdrawn: Array[ResourceStack] = withdraw_stacks(quantity)
	if use_reserve:
		reserved_withdraw = maxi(reserved_withdraw - quantity, 0)
	return withdrawn

## Generic (no-variant) withdraw, kept for existing call sites that only deal
## in plain counts (debug buttons, ResourceData.force_withdraw, etc).
## Internally this still withdraws real stacks, it just discards whichever
## instance_data came off them.
func try_withdraw(quantity: int, use_reserve: bool) -> bool:
	return not _do_withdraw(quantity, use_reserve).is_empty()

func withdraw_up_to(quantity: int, use_reserve: bool) -> int:
	var available: int = stored
	if not use_reserve:
		available -= reserved_withdraw
	var withdrawable: int = mini(quantity, available)
	if withdrawable <= 0:
		return 0
	_do_withdraw(withdrawable, use_reserve)
	return withdrawable

## Generic (no-variant) deposit, kept for existing call sites.
func deposit(quantity: int, use_reserve: bool) -> int:
	add_amount(quantity)
	if use_reserve:
		reserved_deposit -= quantity
		assert(reserved_deposit >= 0)
	return stored

# --- claimable contract (WI-44) -----------------------------------------------
#
# StorageData is the claim target, NOT StorageComponent: reservations are
# per-resource and the duck-typed contract has no room for a resource argument.
# It also keeps the claim path free of Global, which is what preserves this
# class's pure GUT suite.
#
# The amount-based replacement for the add/cancel/complete_*_job pairs this class
# used to carry, whose hard the haul job type was the reason pile collection
# could never reserve deposit space. A claim carries its own amount and does not
# care who is asking, so any job can now reserve either direction.

func can_take_claim(kind: int, amount: int) -> bool:
	if kind == ClaimSpec.Kind.STORAGE_WITHDRAW:
		# use_reserve = false: must be stock nobody else has already spoken for.
		return can_withdraw(amount, false)
	if kind != ClaimSpec.Kind.STORAGE_DEPOSIT:
		return false
	# For GENERAL and OUTPUT, deposit space is a COMPONENT-level question (the
	# role's pool spans every slot in it), which this class deliberately cannot
	# see - that is what keeps the claim path free of Global and this suite pure.
	# So the reservation stays pure bookkeeping, and the room is checked where the
	# pool is visible: Action_ReserveStorage sizes the trip to
	# StorageComponent.room_for_booking() before it claims. Nothing here would
	# refuse an over-sized claim, which is how a whole trip used to be booked
	# against a storeroom's last few units and delivered anyway.
	#
	# INPUT is different since WI-65 §11: its `desired` is a hard per-slot cap,
	# which is slot-local and therefore answerable right here. Without this check
	# five haulers each reserve against the same five remaining units and four
	# arrive at a full slot.
	if role != Role.INPUT:
		return true
	return stored + reserved_deposit + amount <= desired

func take_claim(kind: int, amount: int) -> Variant:
	if not can_take_claim(kind, amount):
		return null
	if kind == ClaimSpec.Kind.STORAGE_WITHDRAW:
		reserved_withdraw += amount
	else:
		reserved_deposit += amount
	return true

func release_claim(kind: int, amount: int, _payload: Variant) -> void:
	if kind == ClaimSpec.Kind.STORAGE_WITHDRAW:
		reserved_withdraw = maxi(reserved_withdraw - amount, 0)
	else:
		reserved_deposit = maxi(reserved_deposit - amount, 0)

## Takes `amount` out against a reservation this job already holds, as real
## stacks. The reservation is spent by the withdraw itself, so the caller must
## CONSUME its claim record rather than releasing it - releasing would credit the
## same units back a second time. See ClaimRegistry.consume().
func withdraw_reserved(amount: int) -> Array[ResourceStack]:
	return _do_withdraw(amount, true)

## Mirror of the above for the deposit side: the stacks are added and the
## reservation they were holding is spent.
func deposit_reserved(stacks: Array[ResourceStack], amount: int) -> void:
	for stack: ResourceStack in stacks:
		add_stack(stack)
	reserved_deposit = maxi(reserved_deposit - amount, 0)
