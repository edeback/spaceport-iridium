@tool
class_name ResourceData
extends Resource

@export var name: String = ""
@export var icon: Texture2D
@export var sub_resources: Dictionary[ResourceData, float]
@export var base_resource: ResourceData

@export var default_cost: int = 10
@export var default_market_supply: int = 100



@export var show_test: bool = false:
	set(value):
		show_test = value
		notify_property_list_changed()
		
@export_storage var test_val: String = ""

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if show_test:
		properties.append({
			"name": "test_val",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": ""
		})
	return properties
