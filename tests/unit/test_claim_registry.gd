extends GutTest

## WI-44 claim ledger. The registry doesn't do capacity accounting - owners keep
## that, so StorageData stays a pure testable class - so what's under test here
## is the bookkeeping and, above all, that release_all() gives back EVERYTHING a
## job took. That guarantee is what replaces the fourteen hand-written
## "release on every termination path" blocks.
##
## Constructed directly, never added to the tree, so _ready() (which registers
## into Global) never runs.

## Honours the duck-typed claimable contract and records what it was asked for.
class FakeClaimable:
	extends RefCounted

	var capacity: int = 10
	var held: int = 0
	var release_log: Array[Dictionary] = []
	## Handed back from take_claim; `true` means "taken, nothing to remember".
	var payload_to_return: Variant = true

	func can_take_claim(_kind: int, amount: int) -> bool:
		return held + amount <= capacity

	func take_claim(kind: int, amount: int) -> Variant:
		if not can_take_claim(kind, amount):
			return null
		held += amount
		return payload_to_return

	func release_claim(kind: int, amount: int, payload: Variant) -> void:
		held -= amount
		release_log.append({"kind": kind, "amount": amount, "payload": payload})


## Implements none of the contract - the registry must refuse it rather than
## erroring on a missing method.
class NotClaimable:
	extends RefCounted


var registry: ClaimRegistry = null
var job_a: Job = null
var job_b: Job = null

func before_each() -> void:
	registry = ClaimRegistry.new()
	job_a = Job.new()
	job_b = Job.new()

func after_each() -> void:
	registry.free()
	registry = null
	job_a = null
	job_b = null

# --- claiming -----------------------------------------------------------------

func test_claim_records_and_takes() -> void:
	var bin := FakeClaimable.new()
	var spec: ClaimSpec = registry.claim(job_a, bin, ClaimSpec.Kind.STORAGE_WITHDRAW, 5)
	assert_not_null(spec, "claim succeeded")
	assert_eq(bin.held, 5, "the owner did the actual reserving")
	assert_true(registry.holds_claim(job_a, bin, ClaimSpec.Kind.STORAGE_WITHDRAW), "and the ledger remembers")

func test_claim_on_a_non_claimable_returns_null() -> void:
	assert_null(registry.claim(job_a, NotClaimable.new(), ClaimSpec.Kind.SLOT, 1),
		"an object without the contract is refused, not crashed on")
	assert_null(registry.claim(job_a, null, ClaimSpec.Kind.SLOT, 1), "null target is refused")

func test_claim_with_no_job_is_refused() -> void:
	assert_null(registry.claim(null, FakeClaimable.new(), ClaimSpec.Kind.SLOT, 1), "no claimant, no claim")

func test_refused_claim_records_nothing() -> void:
	var bed := FakeClaimable.new()
	bed.capacity = 1
	bed.held = 1
	assert_null(registry.claim(job_a, bed, ClaimSpec.Kind.SLOT, 1), "owner said no")
	assert_eq(registry.claims_of(job_a).size(), 0, "so nothing was recorded")

func test_reclaiming_the_same_thing_does_not_double_reserve() -> void:
	# Restore paths and retrying actions both re-claim; that has to be safe.
	var bin := FakeClaimable.new()
	var first: ClaimSpec = registry.claim(job_a, bin, ClaimSpec.Kind.STORAGE_DEPOSIT, 4)
	var second: ClaimSpec = registry.claim(job_a, bin, ClaimSpec.Kind.STORAGE_DEPOSIT, 4)
	assert_eq(first, second, "the existing record is handed back")
	assert_eq(bin.held, 4, "and the owner was only asked once")
	assert_eq(registry.claims_of(job_a).size(), 1, "one record, not two")

func test_two_jobs_claim_the_same_target_independently() -> void:
	var bin := FakeClaimable.new()
	registry.claim(job_a, bin, ClaimSpec.Kind.STORAGE_WITHDRAW, 3)
	registry.claim(job_b, bin, ClaimSpec.Kind.STORAGE_WITHDRAW, 2)
	assert_eq(bin.held, 5, "both reservations landed on the owner")
	assert_eq(registry.claimed_amount(bin, ClaimSpec.Kind.STORAGE_WITHDRAW), 5, "and the ledger totals them")

func test_different_kinds_on_one_target_are_separate_claims() -> void:
	var storage := FakeClaimable.new()
	registry.claim(job_a, storage, ClaimSpec.Kind.STORAGE_WITHDRAW, 2)
	registry.claim(job_a, storage, ClaimSpec.Kind.STORAGE_DEPOSIT, 3)
	assert_eq(registry.claims_of(job_a).size(), 2, "withdraw and deposit don't collide")

func test_can_claim_asks_the_owner_without_taking() -> void:
	var bed := FakeClaimable.new()
	bed.capacity = 1
	assert_true(registry.can_claim(bed, ClaimSpec.Kind.SLOT, 1), "free slot")
	assert_eq(bed.held, 0, "asking is not taking")
	assert_false(registry.can_claim(bed, ClaimSpec.Kind.SLOT, 2), "over capacity")
	assert_false(registry.can_claim(NotClaimable.new(), ClaimSpec.Kind.SLOT, 1), "not claimable at all")

# --- payloads -----------------------------------------------------------------

func test_bool_payload_is_normalised_away() -> void:
	var bin := FakeClaimable.new()
	var spec: ClaimSpec = registry.claim(job_a, bin, ClaimSpec.Kind.SLOT, 1)
	assert_null(spec.payload, "'true' means success with nothing to remember")

func test_object_payload_is_kept_and_handed_back_on_release() -> void:
	# This is what makes ANCHOR claims work through the same path as everything
	# else: the payload is the specific AnchorDef the component picked.
	var path := FakeClaimable.new()
	var anchor := RefCounted.new()
	path.payload_to_return = anchor
	var spec: ClaimSpec = registry.claim(job_a, path, ClaimSpec.Kind.ANCHOR, 1)
	assert_eq(spec.payload, anchor, "payload survives on the record")
	registry.release_all(job_a)
	assert_eq(path.release_log[0]["payload"], anchor, "and comes back verbatim on release")

# --- releasing ----------------------------------------------------------------

func test_release_gives_back_one_claim() -> void:
	var bin := FakeClaimable.new()
	registry.claim(job_a, bin, ClaimSpec.Kind.STORAGE_WITHDRAW, 6)
	registry.release(job_a, bin, ClaimSpec.Kind.STORAGE_WITHDRAW)
	assert_eq(bin.held, 0, "the owner got its units back")
	assert_false(registry.holds_claim(job_a, bin, ClaimSpec.Kind.STORAGE_WITHDRAW), "record gone")

func test_release_of_something_not_held_is_a_no_op() -> void:
	var bin := FakeClaimable.new()
	registry.release(job_a, bin, ClaimSpec.Kind.SLOT)
	assert_eq(bin.release_log.size(), 0, "nothing was given back")

func test_release_all_gives_back_everything() -> void:
	var bed := FakeClaimable.new()
	var bin := FakeClaimable.new()
	registry.claim(job_a, bed, ClaimSpec.Kind.SLOT, 1)
	registry.claim(job_a, bin, ClaimSpec.Kind.STORAGE_DEPOSIT, 9)
	registry.release_all(job_a)
	assert_eq(bed.held, 0, "slot returned")
	assert_eq(bin.held, 0, "storage space returned")
	assert_eq(registry.claims_of(job_a).size(), 0, "ledger clean")
	assert_eq(registry.claiming_job_count(), 0, "and the job is gone from the ledger entirely")

func test_release_all_leaves_other_jobs_alone() -> void:
	var bin := FakeClaimable.new()
	registry.claim(job_a, bin, ClaimSpec.Kind.STORAGE_WITHDRAW, 3)
	registry.claim(job_b, bin, ClaimSpec.Kind.STORAGE_WITHDRAW, 4)
	registry.release_all(job_a)
	assert_eq(bin.held, 4, "job_b still holds its reservation")
	assert_true(registry.holds_claim(job_b, bin, ClaimSpec.Kind.STORAGE_WITHDRAW), "and its record survives")

func test_release_all_is_idempotent() -> void:
	var bin := FakeClaimable.new()
	registry.claim(job_a, bin, ClaimSpec.Kind.SLOT, 1)
	registry.release_all(job_a)
	registry.release_all(job_a)
	assert_eq(bin.release_log.size(), 1, "a second release_all gives nothing back twice")

func test_release_survives_a_target_destroyed_while_claimed() -> void:
	# A module deconstructed mid-job takes its accounting with it; there is
	# nothing to give back to, and the registry must not error trying.
	var doomed := ClaimableObject.new()
	registry.claim(job_a, doomed, ClaimSpec.Kind.SLOT, 1)
	doomed.free()
	registry.release_all(job_a)
	assert_eq(registry.claims_of(job_a).size(), 0, "the record is dropped cleanly")

## Manually-freed variant of FakeClaimable, for the destroyed-target case.
class ClaimableObject:
	extends Object

	func can_take_claim(_kind: int, _amount: int) -> bool:
		return true

	func take_claim(_kind: int, _amount: int) -> Variant:
		return true

	func release_claim(_kind: int, _amount: int, _payload: Variant) -> void:
		pass

# --- queries ------------------------------------------------------------------

func test_claims_of_returns_a_copy() -> void:
	var bin := FakeClaimable.new()
	registry.claim(job_a, bin, ClaimSpec.Kind.SLOT, 1)
	var snapshot: Array[ClaimSpec] = registry.claims_of(job_a)
	snapshot.clear()
	assert_eq(registry.claims_of(job_a).size(), 1, "mutating the snapshot can't corrupt the ledger")

func test_claims_of_an_unknown_job_is_empty() -> void:
	assert_eq(registry.claims_of(job_a).size(), 0, "a job that never claimed holds nothing")
	assert_eq(registry.claims_of(null).size(), 0, "null is safe")

func test_claimed_amount_counts_only_the_matching_kind() -> void:
	var storage := FakeClaimable.new()
	# The fake's capacity is shared across kinds; a real StorageData tracks
	# withdraw and deposit separately, so give this one room for both.
	storage.capacity = 100
	registry.claim(job_a, storage, ClaimSpec.Kind.STORAGE_WITHDRAW, 5)
	registry.claim(job_b, storage, ClaimSpec.Kind.STORAGE_DEPOSIT, 7)
	assert_eq(registry.claimed_amount(storage, ClaimSpec.Kind.STORAGE_WITHDRAW), 5, "withdraw total")
	assert_eq(registry.claimed_amount(storage, ClaimSpec.Kind.STORAGE_DEPOSIT), 7, "deposit total")
