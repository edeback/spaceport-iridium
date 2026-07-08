class_name ResourceStack
extends Resource

## Which resource type this stack is. Redundant when the stack lives inside a
## ResourceStackContainer (which is already scoped to one resource type), but
## kept here too so a stack is self-describing once it's been withdrawn and
## handed off (pawn inventory, job hand-offs, etc).
@export var resource_data: ResourceData
@export var amount: int = 0
## null = generic, no variance. Non-null = this batch has its own data (ore
## richness, food quality, ...). See ItemInstanceData.
@export var instance_data: ItemInstanceData = null

func duplicate_stack() -> ResourceStack:
	var copy := ResourceStack.new()
	copy.resource_data = resource_data
	copy.amount = amount
	copy.instance_data = instance_data
	return copy
