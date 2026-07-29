class_name Finder_Shop
extends Finder_FreeSlotComponent

## An open storefront the pawn can afford (WI-44).
##
## Shops join the "shop" group and deliberately NOT "recreation_provider", so
## Finder_RecreationProvider never offers a paid storefront as free entertainment
## - the split that keeps the two need jobs honest (WI-33). Picks at random for
## the same reason recreation does: customers spread across the shops rather than
## all queueing at the nearest.

func _init(_unused_group: StringName = &"", _tolerance: float = 0.0, _random: bool = false) -> void:
	super(Groups.SHOP, 0.0, true)

## The affordability gate uses the TYPE'S price floor, not the price this visit
## will actually roll, so a customer never walks somewhere it certainly cannot
## pay. The rolled bill is clamped to the wallet at the register anyway, so being
## a few credits short by the time they arrive is not a failure.
func accepts(_job: Job, pawn: PawnBase, candidate: ComponentBase) -> bool:
	var shop: ShopComponent = candidate as ShopComponent
	if shop == null or not shop.is_open():
		return false
	if pawn.personal_credits < shop.min_visit_price():
		return false
	return shop.recreation_per_hour(pawn) > 0.0

func describe() -> String:
	return "a shop"
