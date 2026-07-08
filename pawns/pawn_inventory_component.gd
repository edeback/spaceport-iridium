class_name PawnInventoryComponent
extends PawnComponentBase

## Resource -> amount currently carried by the pawn. Entries are pruned as soon
## as they hit 0 so is_empty()/get_carried_resources() stay cheap to check.
##
## Phase 1: plain int amounts, same as StorageData.stored today. When the
## storage system moves to ResourceStack-based variance (richness/quality),
## this will follow the same pattern so a stack withdrawn from a module can be
## carried and re-deposited without losing its instance data.
@export var carried: Dictionary[ResourceData, int] = {}

## Emitted whenever a resource's carried amount changes (including going to 0,
## in which case new_amount will be 0 and the key will already be gone).
signal inventory_changed(resource: ResourceData, new_amount: int)

func total_carried() -> int:
	var total: int = 0
	for amount: int in carried.values():
		total += amount
	return total

func space_available() -> int:
	if owner_pawn == null:
		return 0
	return maxi(owner_pawn.carrying_capacity - total_carried(), 0)

func is_empty() -> bool:
	return carried.is_empty()

func get_carried_amount(resource: ResourceData) -> int:
	return carried.get(resource, 0)

## Snapshot of resource types currently carried. Safe to iterate over while
## calling withdraw()/add() on this component, since keys() returns a copy.
func get_carried_resources() -> Array[ResourceData]:
	return carried.keys()

func can_add(_resource: ResourceData, amount: int) -> bool:
	return amount > 0 and amount <= space_available()

## Adds up to space_available() of the resource. Returns the amount actually
## added, which may be less than requested (or 0) if the pawn is full.
func add(resource: ResourceData, amount: int) -> int:
	if resource == null or amount <= 0:
		return 0
	var added: int = mini(amount, space_available())
	if added <= 0:
		return 0
	var new_amount: int = carried.get(resource, 0) + added
	carried[resource] = new_amount
	inventory_changed.emit(resource, new_amount)
	return added

func can_withdraw(resource: ResourceData, amount: int) -> bool:
	return amount > 0 and carried.get(resource, 0) >= amount

## Removes up to the requested amount. Returns the amount actually removed,
## which may be less than requested (or 0) if the pawn isn't carrying enough.
func withdraw(resource: ResourceData, amount: int) -> int:
	if resource == null or amount <= 0:
		return 0
	var available: int = carried.get(resource, 0)
	var removed: int = mini(amount, available)
	if removed <= 0:
		return 0
	var remaining: int = available - removed
	if remaining <= 0:
		carried.erase(resource)
	else:
		carried[resource] = remaining
	inventory_changed.emit(resource, remaining)
	return removed
