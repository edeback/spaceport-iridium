## Resource stack for inventory and cost tracking.
class_name ResourceStack
extends Resource

## The resource type stored in the stack.
@export var type: Resource

## The number of resources in the stack.
@export var count: int = 1


## Initializes the resource stack with a type and count.
func _init(p_type: Resource = null, p_count: int = 0):
	type = p_type
	count = p_count
