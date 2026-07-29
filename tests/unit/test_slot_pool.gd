extends GutTest

## WI-44 SlotPool - occupancy for the five capacity-limited components (bunks,
## charger pads, shop counters, medical beds, holodeck seats).
##
## The load-bearing property while both job systems are live is that they share
## ONE occupancy count, so a legacy claim_slot() and a new SLOT claim cannot
## oversubscribe each other. That is asserted here against a real component.

var pool: SlotPool

func before_each() -> void:
	pool = SlotPool.new()
	pool.capacity = 2

# --- the pool itself ----------------------------------------------------------

func test_starts_empty() -> void:
	assert_true(pool.has_free(), "a fresh pool has room")
	assert_eq(pool.free_count(), 2, "all of it")

func test_taking_fills_it() -> void:
	assert_not_null(pool.take_claim(ClaimSpec.Kind.SLOT, 1), "first taken")
	assert_eq(pool.free_count(), 1, "one left")
	assert_not_null(pool.take_claim(ClaimSpec.Kind.SLOT, 1), "second taken")
	assert_false(pool.has_free(), "full")

func test_over_capacity_is_refused() -> void:
	pool.take_claim(ClaimSpec.Kind.SLOT, 2)
	assert_false(pool.can_take_claim(ClaimSpec.Kind.SLOT, 1), "no room to offer")
	assert_null(pool.take_claim(ClaimSpec.Kind.SLOT, 1), "and none given")
	assert_eq(pool.occupied, 2, "the refusal changed nothing")

func test_only_slot_claims_are_accepted() -> void:
	# A pool is not a storage bin; asking it for a withdraw reservation is a bug
	# in the caller and must not silently succeed.
	assert_false(pool.can_take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 1), "wrong kind refused")
	assert_null(pool.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 1), "and nothing taken")

func test_release_frees_the_slot() -> void:
	pool.take_claim(ClaimSpec.Kind.SLOT, 1)
	pool.release_claim(ClaimSpec.Kind.SLOT, 1, null)
	assert_eq(pool.occupied, 0, "reconciles to zero")

func test_release_never_goes_negative() -> void:
	pool.release_claim(ClaimSpec.Kind.SLOT, 5, null)
	assert_eq(pool.occupied, 0, "floors at zero rather than inventing capacity")

func test_capacity_can_grow_under_a_full_pool() -> void:
	# Local upgrades widen these components at runtime; claim_pool() re-syncs
	# capacity on every call, so a widened component must simply have room again.
	pool.take_claim(ClaimSpec.Kind.SLOT, 2)
	assert_false(pool.has_free(), "full at 2")
	pool.capacity = 4
	assert_true(pool.has_free(), "and not full at 4")
	assert_eq(pool.free_count(), 2, "with the new room available")

# --- coexistence with the legacy system ---------------------------------------

func test_legacy_and_new_claims_share_one_occupancy() -> void:
	# THE invariant that makes the two systems safe to run side by side. If these
	# counted separately, a bunk could be double-booked.
	var component := RecreationProviderComponent.new()
	component.capacity = 1
	var legacy_job := JobBase.new()
	assert_true(component.claim_slot(legacy_job), "the legacy job took the only seat")
	assert_false(component.has_free_slot(), "so the component reports full")
	assert_false(component.claim_pool().can_take_claim(ClaimSpec.Kind.SLOT, 1),
		"and a WI-44 claim is refused - not double-booked")
	component.release_slot(legacy_job)
	assert_true(component.claim_pool().can_take_claim(ClaimSpec.Kind.SLOT, 1),
		"once the legacy job leaves, the seat is claimable again")
	component.free()

func test_new_claim_blocks_a_legacy_one() -> void:
	var component := RecreationProviderComponent.new()
	component.capacity = 1
	assert_not_null(component.claim_pool().take_claim(ClaimSpec.Kind.SLOT, 1), "WI-44 took the seat")
	assert_false(component.has_free_slot(), "component reports full")
	assert_false(component.claim_slot(JobBase.new()), "and the legacy path is refused")
	component.free()

func test_releasing_a_job_that_never_claimed_does_not_free_a_seat() -> void:
	# release_slot() erases from _claims AND decrements the pool, so it has to
	# ignore a job it never held - otherwise a stray release hands out a seat that
	# somebody else is sitting in.
	var component := RecreationProviderComponent.new()
	component.capacity = 1
	var holder := JobBase.new()
	component.claim_slot(holder)
	component.release_slot(JobBase.new())
	assert_false(component.has_free_slot(), "the real occupant still has the seat")
	component.release_slot(holder)
	assert_true(component.has_free_slot(), "and only their own release frees it")
	component.free()
