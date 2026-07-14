@tool
class_name ResourceData
extends Resource

## Stable identifier for save files (matches the .tres file stem). Never
## rename once players have saves referencing it.
@export var id: StringName = &""
@export var name: String = ""
@export var icon: Texture2D

#@export var sub_resources: Dictionary[ResourceData, float]
#@export var base_resource: ResourceData

@export var default_cost: int = 10
@export var default_market_supply: int = 100

@export var has_global_store: bool = false
## Only used if has_global_store is true
@export var global_total: int = 0

@export var cached_total: int = 0
var needs_recalc: bool = true

## Does this resource carry per-stack variance (ore richness, food quality,
## etc)? When false (the default, and correct for most resources), every
## stack of this resource has instance_data == null and storage behaves
## exactly like a single int count - no behavior change from before this
## system existed.
@export var has_variance: bool = false

## How close two variant stacks' ItemInstanceData.get_primary_value() need to
## be to merge into one stack, once has_variance is true. Higher = coarser
## buckets (fewer stacks, less precision retained); 0 = only exact matches
## merge. Ignored when has_variance is false.
@export_range(0.0, 1.0, 0.01) var merge_tolerance: float = 0.05

var registered_storage: Array[StorageComponent] = []

#@export var show_test: bool = false:
	#set(value):
		#show_test = value
		#notify_property_list_changed()
		#
#@export_storage var test_val: String = ""
#
#func _get_property_list() -> Array[Dictionary]:
	#var properties: Array[Dictionary] = []
	#if show_test:
		#properties.append({
			#"name": "test_val",
			#"type": TYPE_STRING,
			#"usage": PROPERTY_USAGE_DEFAULT,
			#"hint": PROPERTY_HINT_NONE,
			#"hint_string": ""
		#})
	#return properties

signal total_changed(new_total: int)

# Returns new global total
func change_global_total(amount: int) -> int:
	global_total += amount
	needs_recalc = true
	return global_total

func get_total(force_recalc: bool = false) -> int:
	_recalc_resource(force_recalc)
	return cached_total

func register_component(component: StorageComponent) -> void:
	if not registered_storage.has(component):
		registered_storage.append(component)
		needs_recalc = true

func unregister_component(component: StorageComponent) -> void:
	registered_storage.erase(component)
	needs_recalc = true
		
func _recalc_resource(force_recalc: bool = false) -> void:
	if needs_recalc or force_recalc:
		needs_recalc = false
		var total: int = global_total
		for storage_component: StorageComponent in registered_storage:
			total += storage_component.total_stored_by_resource(self)
		cached_total = total
		total_changed.emit(total)

func force_withdraw(amount: int) -> void:
	if has_global_store:
		global_total -= amount
		needs_recalc = true
	else:
		var remaining_amount: int = amount
		for component in registered_storage:
			remaining_amount -= component.withdraw_up_to(self, remaining_amount)
			if remaining_amount <= 0:
				break
