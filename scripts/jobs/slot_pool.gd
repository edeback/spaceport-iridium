class_name SlotPool
extends RefCounted

## Occupancy for a capacity-limited component (WI-44): bunks, charger pads, shop
## counters, medical beds, holodeck seats.
##
## This is the claim TARGET for ClaimSpec.Kind.SLOT, for the same reason
## StorageData is the target for storage claims rather than StorageComponent -
## the claimable object should be the thing that actually owns the constraint,
## and it should be pure. Five components each hand-rolled this counting; now
## they each hold one of these.
##
## Every occupant is booked through this one object, so the count that matters
## lives in exactly one place.

var capacity: int = 1
var occupied: int = 0

func has_free() -> bool:
	return occupied < capacity

func free_count() -> int:
	return maxi(capacity - occupied, 0)

# --- claimable contract -------------------------------------------------------

func can_take_claim(kind: int, amount: int) -> bool:
	if kind != ClaimSpec.Kind.SLOT:
		return false
	return occupied + amount <= capacity

func take_claim(kind: int, amount: int) -> Variant:
	if not can_take_claim(kind, amount):
		return null
	occupied += amount
	return true

func release_claim(_kind: int, amount: int, _payload: Variant) -> void:
	occupied = maxi(occupied - amount, 0)
