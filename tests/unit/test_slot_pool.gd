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

# --- against a real component -------------------------------------------------

func test_component_reports_full_once_its_only_seat_is_claimed() -> void:
	# The pool IS the component's occupancy - has_free_slot() reads it rather than
	# keeping a second count, which is what stopped the two job systems
	# double-booking a bunk while both were live, and is now simply the only count.
	var component := RecreationProviderComponent.new()
	component.capacity = 1
	assert_not_null(component.claim_pool().take_claim(ClaimSpec.Kind.SLOT, 1), "took the only seat")
	assert_false(component.has_free_slot(), "so the component reports full")
	assert_false(component.claim_pool().can_take_claim(ClaimSpec.Kind.SLOT, 1),
		"and a second claim is refused")
	component.claim_pool().release_claim(ClaimSpec.Kind.SLOT, 1, null)
	assert_true(component.has_free_slot(), "releasing frees it again")
	component.free()

func test_capacity_is_resynced_on_every_claim_pool_call() -> void:
	# A local upgrade widens the component without notifying anything, so the pool
	# re-reads capacity each time rather than caching it at construction.
	var component := RecreationProviderComponent.new()
	component.capacity = 1
	assert_eq(component.claim_pool().capacity, 1)
	component.capacity = 3
	assert_eq(component.claim_pool().capacity, 3, "the widened capacity is picked up")
	component.free()
