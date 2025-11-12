class_name StorageComponent
extends ComponentBase

# Obsolete, do not use, should probably delete soon

@export var stored_resource: ResourceData
@export var max_stored: float = 10

@export var accepts_imports: bool = true
@export var accepts_exports: bool = true

@export var cur_stored: float = 0

@export var import_job: JobData

var stock_reserved: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("resource_storage")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if cur_stored < max_stored and accepts_imports and import_job != null:
		Global.job_manager.add_job(owner_module, import_job)
	pass

func can_withdraw(resource: ResourceData, quantity: float = 1) -> bool:
	if resource == stored_resource:
		return cur_stored - stock_reserved >= quantity
	return false
	
func withdraw(resource: ResourceData, quantity: float = 1) -> bool:
	if can_withdraw(resource, quantity):
		cur_stored -= quantity
		return true
	return false

func can_deposit(resource: ResourceData, quantity: float = 1) -> bool:
	if resource == stored_resource:
		return max_stored - cur_stored >= quantity
	return false

func deposit(resource: ResourceData, quantity: float = 1, only_if_room: bool = false) -> bool:
	if resource == stored_resource:
		if only_if_room and (max_stored - cur_stored < quantity):
			return false
		cur_stored = clampf(cur_stored + quantity, 0, max_stored)
		return true
	return false
			
