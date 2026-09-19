class_name PileStock
extends RefCounted

## The claimable face of one resource type on one ResourcePile (WI-44).
##
## Exists for exactly the reason StorageData is the claim target for storage
## rather than StorageComponent: the claimable contract has no room for a
## resource argument (`can_take_claim(kind, amount)`), so the claimable object
## has to already know which resource it is about. A pile holds several, so it
## hands out one of these per resource and memoises them.
##
## Deliberately a thin face over the pile's own `reserved` dictionary rather than
## a second counter. The pile stays authoritative: one count, whatever books
## against it - the same property SlotPool gives the five slot components.

var pile: ResourcePile = null
var resource: ResourceData = null

static func of(owning_pile: ResourcePile, for_resource: ResourceData) -> PileStock:
	var stock := PileStock.new()
	stock.pile = owning_pile
	stock.resource = for_resource
	return stock

func available() -> int:
	if not is_instance_valid(pile) or resource == null:
		return 0
	return pile.get_available(resource)

# --- claimable contract -------------------------------------------------------

func can_take_claim(kind: int, amount: int) -> bool:
	if kind != ClaimSpec.Kind.PILE or amount <= 0:
		return false
	return available() >= amount

func take_claim(kind: int, amount: int) -> Variant:
	if not can_take_claim(kind, amount):
		return null
	return true if pile.reserve(resource, amount) else null

func release_claim(kind: int, amount: int, _payload: Variant) -> void:
	if kind != ClaimSpec.Kind.PILE or not is_instance_valid(pile):
		return
	pile.cancel_reservation(resource, amount)
