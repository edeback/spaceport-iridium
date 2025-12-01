class_name ObjectBase
extends Node2D

## ObjectBase is the base class for all non-pawn objects that hold components

@export var components: Array[ComponentBase]

func get_component_by_type(type: Variant) -> ComponentBase:
	for component: ComponentBase in components:
		if is_instance_of(component, type):
			return component
	return null
