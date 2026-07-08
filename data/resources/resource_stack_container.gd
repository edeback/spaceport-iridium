class_name ResourceStackContainer
extends Resource

## Which resource type every stack in `stacks` represents. Set once when the
## container is created (see StorageComponent.add_stored_resource /
## PawnInventoryComponent.add_stacks) - every stack held here is always this
## type, so individual stacks don't need to be checked against it.
@export var resource_data: ResourceData

@export var stacks: Array[ResourceStack] = []

## Cached sum of all stack amounts, kept in sync by every mutating method
## below, so existing code that reads a plain int total (UI, cost checks,
## reservation math) doesn't need to know stacks exist at all.
@export var stored: int = 0

enum WithdrawStrategy { LARGEST_FIRST, HIGHEST_VALUE_FIRST, LOWEST_VALUE_FIRST, FIFO }

func is_empty() -> bool:
	return stored <= 0

func _merge_tolerance() -> float:
	if resource_data != null and resource_data.has_variance:
		return resource_data.merge_tolerance
	return -1.0

## Adds a stack, merging into an existing one where possible:
## - generic stacks (instance_data == null) always merge with each other
## - variant stacks merge only with an existing stack whose
##   instance_data.get_primary_value() is within this resource's
##   merge_tolerance; otherwise they become their own new stack
## Takes ownership of a *copy* of new_stack - the caller's original is left
## untouched (safe to keep using/reference after calling this).
func add_stack(new_stack: ResourceStack) -> void:
	if new_stack == null or new_stack.amount <= 0:
		return
	if new_stack.instance_data == null:
		for existing: ResourceStack in stacks:
			if existing.instance_data == null:
				existing.amount += new_stack.amount
				stored += new_stack.amount
				return
		stacks.append(new_stack.duplicate_stack())
		stored += new_stack.amount
		return
	var tolerance: float = _merge_tolerance()
	if tolerance >= 0.0:
		var new_value: float = new_stack.instance_data.get_primary_value()
		for existing: ResourceStack in stacks:
			if existing.instance_data != null and absf(existing.instance_data.get_primary_value() - new_value) <= tolerance:
				existing.instance_data = existing.instance_data.merged_with(new_stack.instance_data, existing.amount, new_stack.amount)
				existing.amount += new_stack.amount
				stored += new_stack.amount
				return
	stacks.append(new_stack.duplicate_stack())
	stored += new_stack.amount

## Convenience for the common "just add N generic units" case.
func add_amount(amount: int) -> void:
	if amount <= 0:
		return
	var stack := ResourceStack.new()
	stack.resource_data = resource_data
	stack.amount = amount
	add_stack(stack)

## Removes up to `quantity` units total, pulled from stacks per `strategy`.
## Returns the stacks actually withdrawn (their combined amount is `quantity`,
## or less if the container didn't have enough - check the total yourself if
## that distinction matters to the caller).
func withdraw_stacks(quantity: int, strategy: WithdrawStrategy = WithdrawStrategy.LARGEST_FIRST) -> Array[ResourceStack]:
	var result: Array[ResourceStack] = []
	if quantity <= 0 or stacks.is_empty():
		return result
	var ordered: Array[ResourceStack] = stacks.duplicate()
	match strategy:
		WithdrawStrategy.LARGEST_FIRST:
			ordered.sort_custom(func(a: ResourceStack, b: ResourceStack) -> bool: return a.amount > b.amount)
		WithdrawStrategy.HIGHEST_VALUE_FIRST:
			ordered.sort_custom(func(a: ResourceStack, b: ResourceStack) -> bool: return _value_of(a) > _value_of(b))
		WithdrawStrategy.LOWEST_VALUE_FIRST:
			ordered.sort_custom(func(a: ResourceStack, b: ResourceStack) -> bool: return _value_of(a) < _value_of(b))
		WithdrawStrategy.FIFO:
			pass # `stacks` is already in append/insertion order
	var remaining: int = quantity
	for stack: ResourceStack in ordered:
		if remaining <= 0:
			break
		var take: int = mini(stack.amount, remaining)
		if take <= 0:
			continue
		var taken: ResourceStack = stack.duplicate_stack()
		taken.amount = take
		result.append(taken)
		stack.amount -= take
		remaining -= take
	var kept: Array[ResourceStack] = []
	for stack: ResourceStack in stacks:
		if stack.amount > 0:
			kept.append(stack)
	stacks = kept
	stored -= (quantity - remaining)
	return result

## Generic-amount convenience wrapper around withdraw_stacks() for callers that
## don't care which specific stack(s) it came from. Returns the amount removed.
func withdraw_amount(quantity: int, strategy: WithdrawStrategy = WithdrawStrategy.LARGEST_FIRST) -> int:
	var withdrawn: Array[ResourceStack] = withdraw_stacks(quantity, strategy)
	var total: int = 0
	for stack: ResourceStack in withdrawn:
		total += stack.amount
	return total

func _value_of(stack: ResourceStack) -> float:
	return stack.instance_data.get_primary_value() if stack.instance_data != null else 0.0
