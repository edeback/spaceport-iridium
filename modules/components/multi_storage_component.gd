class_name MultiStorageComponent
extends ComponentBase

@export var stored_resources: Array[ResourceData]
@export var max_stored: float = 10

@export var accepts_imports: bool = true
@export var accepts_exports: bool = true

@export var cur_stored: Dictionary[ResourceData, float] = {}

@export var import_job: Dictionary[ResourceData, JobData] = {}

@export var storage_ui: ProgressBar

var stock_reserved: Dictionary[ResourceData, float] = {}
var space_reserved: Dictionary[ResourceData, float] = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("resource_storage")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var test_total_stored: float = 0
	for resource in cur_stored:
		test_total_stored += cur_stored[resource]
	if test_total_stored < max_stored and accepts_imports:
		for resource: ResourceData in stored_resources:
			if !import_job.has(resource):
				var new_job: JobData = JobData.new()
				new_job.requester = self
				new_job.resource_data = resource
				Global.job_manager.add_job(owner_module, new_job)
				import_job[resource] = new_job
		#Global.job_manager.add_job(owner_module, import_job)
		pass
	storage_ui.value = test_total_stored / max_stored

func can_withdraw(resource: ResourceData, quantity: float = 1) -> bool:
	if stored_resources.has(resource):
		return cur_stored.get_or_add(resource, 0.0) - stock_reserved.get_or_add(resource, 0.0) >= quantity
	return false
	
func withdraw(resource: ResourceData, quantity: float = 1) -> bool:
	if can_withdraw(resource, quantity):
		cur_stored[resource] = cur_stored[resource] - quantity
		return true
	return false
	
func _space_available() -> float:
	var cur_stored_and_reserved: float = 0
	for stored_resource in cur_stored:
		cur_stored_and_reserved += cur_stored.get_or_add(stored_resource, 0)
		cur_stored_and_reserved += space_reserved.get_or_add(stored_resource, 0)
	return max_stored - cur_stored_and_reserved

func can_deposit(resource: ResourceData, quantity: float = 1) -> bool:
	if stored_resources.has(resource):
		return _space_available() >= quantity
	return false

func deposit(resource: ResourceData, quantity: float = 1, only_if_room: bool = false) -> bool:
	if stored_resources.has(resource):
		if only_if_room and (_space_available() < quantity):
			return false
		cur_stored[resource] = cur_stored[resource] + clampf(quantity, 0, _space_available())
		return true
	return false
			
func reserve_stock_for_export(resource: ResourceData, quantity: float = 1) -> bool:
	return true
	
func reserve_space_for_import(resource: ResourceData, quantity: float = 1) -> bool:
	return true
