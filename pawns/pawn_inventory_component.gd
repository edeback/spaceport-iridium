class_name PawnInventoryComponent
extends PawnComponentBase

## Resource -> stack container currently carried. Real ResourceStack data
## (so richness/quality picked up from a module or asteroid survives the
## trip), capped in total by owner_pawn.carrying_capacity, same cap as before.
@export var carried: Dictionary[ResourceData, ResourceStackContainer] = {}

## Emitted whenever a resource's total carried amount changes (including
## going to 0, in which case new_amount will be 0 and the key will already be
## gone from `carried`).
signal inventory_changed(resource: ResourceData, new_amount: int)

func total_carried() -> int:
	var total: int = 0
	for container: ResourceStackContainer in carried.values():
		total += container.stored
	return total

func space_available() -> int:
	if owner_pawn == null:
		return 0
	return maxi(owner_pawn.carrying_capacity - total_carried(), 0)

func is_empty() -> bool:
	return carried.is_empty()

func get_carried_amount(resource: ResourceData) -> int:
	var container: ResourceStackContainer = carried.get(resource)
	return container.stored if container != null else 0

## Snapshot of resource types currently carried. Safe to iterate over while
## calling withdraw_stacks()/add_stacks() on this component.
func get_carried_resources() -> Array[ResourceData]:
	return carried.keys()

func can_add(_resource: ResourceData, amount: int) -> bool:
	return amount > 0 and amount <= space_available()

## Generic add - creates a plain stack with no instance_data. Returns the
## amount actually added (may be less than requested, or 0, if full).
func add(resource: ResourceData, amount: int) -> int:
	if resource == null or amount <= 0:
		return 0
	var stack := ResourceStack.new()
	stack.resource_data = resource
	stack.amount = amount
	var leftover: Array[ResourceStack] = add_stacks(resource, [stack])
	var leftover_amount: int = 0
	for s: ResourceStack in leftover:
		leftover_amount += s.amount
	return amount - leftover_amount

## Adds real stacks (preserving instance_data), clamped to space_available().
## Returns whatever didn't fit (empty array if everything was added) so the
## caller decides what to do with the leftover instead of it silently
## disappearing - e.g. hand it back to the source storage.
func add_stacks(resource: ResourceData, stacks: Array[ResourceStack]) -> Array[ResourceStack]:
	var leftover: Array[ResourceStack] = []
	if resource == null or stacks.is_empty():
		return leftover
	var container: ResourceStackContainer = carried.get(resource)
	if container == null:
		container = ResourceStackContainer.new()
		container.resource_data = resource
		carried[resource] = container
	var any_added: bool = false
	for stack: ResourceStack in stacks:
		var space: int = space_available()
		if space <= 0:
			leftover.append(stack)
			continue
		if stack.amount <= space:
			container.add_stack(stack)
			any_added = true
		else:
			var accepted: ResourceStack = stack.duplicate_stack()
			accepted.amount = space
			container.add_stack(accepted)
			any_added = true
			var remainder: ResourceStack = stack.duplicate_stack()
			remainder.amount = stack.amount - space
			leftover.append(remainder)
	if any_added:
		inventory_changed.emit(resource, container.stored)
	return leftover

func can_withdraw(resource: ResourceData, amount: int) -> bool:
	var container: ResourceStackContainer = carried.get(resource)
	return amount > 0 and container != null and container.stored >= amount

## Generic withdraw - returns the amount actually removed.
func withdraw(resource: ResourceData, amount: int) -> int:
	var stacks: Array[ResourceStack] = withdraw_stacks(resource, amount)
	var total: int = 0
	for stack: ResourceStack in stacks:
		total += stack.amount
	return total

## Withdraws real stacks (preserving instance_data) for handing off elsewhere
## (a job depositing into module storage, etc).
func withdraw_stacks(resource: ResourceData, amount: int) -> Array[ResourceStack]:
	var container: ResourceStackContainer = carried.get(resource)
	if container == null or amount <= 0:
		return []
	var withdrawn: Array[ResourceStack] = container.withdraw_stacks(amount)
	if not withdrawn.is_empty():
		inventory_changed.emit(resource, container.stored)
	if container.is_empty():
		carried.erase(resource)
	return withdrawn
