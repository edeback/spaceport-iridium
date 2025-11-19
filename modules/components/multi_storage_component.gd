class_name MultiStorageComponent
extends ComponentBase

@export var priority: int = 1
@export var stored_resources: Array[ResourceData]
@export var max_stored: float = 10

@export var accepts_imports: bool = true
@export var accepts_exports: bool = true

@export var cur_stored: Dictionary[ResourceData, float] = {}

@export var import_job: Dictionary[ResourceData, JobData] = {}

@export var storage_ui: ProgressBar

#var stock_reserved: Dictionary[ResourceData, float] = {}
#var space_reserved: Dictionary[ResourceData, float] = {}

var export_jobs: Array[JobData] = []
var import_jobs: Array[JobData] = []

const SMALL_FLOAT: float = 0.000001

signal storage_changed(resource: ResourceData, new_value: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	add_to_group("resource_storage")
	for resource: ResourceData in stored_resources:
		Global.resource_manager.register_component(resource, self)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if accepts_imports and space_available() > 1.0:
		for resource: ResourceData in stored_resources:
			if !import_job.has(resource):
				var new_job: JobData = JobData.new()
				new_job.requester = self
				new_job.resource_data = resource
				new_job.deposit_storage = self
				new_job.priority = priority
				Global.job_manager.add_job(owner_module, new_job)
				import_job[resource] = new_job
		#Global.job_manager.add_job(owner_module, import_job)
		pass
	var test_total_stored: float = 0
	for resource in cur_stored:
		test_total_stored += cur_stored[resource]
	storage_ui.value = test_total_stored / max_stored
	
func _exit_tree() -> void:
	for resource: ResourceData in stored_resources:
		Global.resource_manager.unregister_component(resource, self)
	for job: JobData in export_jobs:
		job.cancel()
	export_jobs.clear()
	for job: JobData in import_jobs:
		job.cancel()
	import_jobs.clear()
	for resource: ResourceData in import_job:
		var job: JobData = import_job[resource]
		if job != null:
			job.cancel()
	import_job.clear()
	
func _calc_reserved_from_jobs(resource: ResourceData, jobs: Array[JobData]) -> float:
	var reserved: float = 0
	for job: JobData in jobs:
		if job.resource_data == resource:
			reserved += job.amount
	return reserved
	
func find_first_stored_resource_with_base(base_resource: ResourceData, minimum: float = 0) -> ResourceData:
	for resource: ResourceData in cur_stored:
		if resource == base_resource or resource.base_resource == base_resource:
			if minimum == 0 or (minimum > 0 and can_withdraw(resource)):
				return resource
	return null
	
func can_store_resource(resource: ResourceData) -> bool:
	var has_resource: bool = stored_resources.has(resource)
	if resource.base_resource != null:
		has_resource = has_resource or stored_resources.has(resource.base_resource)
	return has_resource

func can_withdraw(resource: ResourceData, quantity: float = 1.0, use_reserve: bool = false) -> bool:
	if can_store_resource(resource):
		var available: float = cur_stored.get_or_add(resource, 0.0)
		if not use_reserve:
			available -= _calc_reserved_from_jobs(resource, export_jobs)
		return available + SMALL_FLOAT >= quantity
	return false
	
func withdraw(resource: ResourceData, quantity: float = 1.0, use_reserve: bool = false) -> bool:
	if can_withdraw(resource, quantity, use_reserve):
		var new_value: float = max(cur_stored[resource] - quantity, 0)
		cur_stored[resource] = new_value
		emit_signal("storage_changed", resource, new_value)
		Global.resource_manager.queue_recalc_resource(resource)
		return true
	return false
	
func withdraw_job(job: JobData) -> bool:
	if export_jobs.has(job):
		if withdraw(job.resource_data, job.amount, true):
			export_jobs.erase(job)
			return true
	return false
	
func total_stored_by_resource(base_resource: ResourceData, include_sub_resources: bool = true) -> float:
	var total: float = 0
	if cur_stored.has(base_resource):
		total += cur_stored[base_resource]
	if include_sub_resources:
		for stored_resource: ResourceData in cur_stored:
			if stored_resource.base_resource == base_resource:
				total += cur_stored[stored_resource]
	return total
	
func space_available(use_reserve: bool = false) -> float:
	var cur_stored_and_reserved: float = 0
	for stored_resource in cur_stored:
		cur_stored_and_reserved += cur_stored.get_or_add(stored_resource, 0)
		if not use_reserve:
			cur_stored_and_reserved += _calc_reserved_from_jobs(stored_resource, import_jobs)
	return max_stored - cur_stored_and_reserved

func can_deposit(resource: ResourceData, quantity: float = 1.0, use_reserve: bool = false) -> bool:
	if can_store_resource(resource):
		return space_available(use_reserve) + SMALL_FLOAT >= quantity
	return false

func deposit(resource: ResourceData, quantity: float = 1.0, only_if_room: bool = false, use_reserve: bool = false) -> bool:
	if can_store_resource(resource):
		var free_space: float = space_available(use_reserve)
		if only_if_room and (free_space < quantity):
			return false 
		var new_value: float = cur_stored.get_or_add(resource, 0) + clampf(quantity, 0, free_space)
		cur_stored[resource] = new_value
		emit_signal("storage_changed", resource, new_value)
		Global.resource_manager.queue_recalc_resource(resource)
		return true
	return false
	
func deposit_job(job: JobData) -> bool:
	if import_jobs.has(job):
		if deposit(job.resource_data, job.amount, false, true):
			import_jobs.erase(job)
			import_job.erase(job.resource_data)
			if job.resource_data.base_resource != null:
				import_job.erase(job.resource_data.base_resource)
			return true
	return false
	
func has_ui() -> bool:
	return true
	
func get_ui() -> ModuleComponentUI:
	var panel_element: UIStorageComponent = ui_info_panel_element.instantiate() as UIStorageComponent
	panel_element.set_storage_component(self)
	return panel_element
			
#func reserve_stock_for_export(resource: ResourceData, quantity: float = 1.0) -> bool:
#	stock_reserved[resource] = stock_reserved.get_or_add(resource, 0) + quantity
#	return true
	
#func reserve_space_for_import(resource: ResourceData, quantity: float = 1.0) -> bool:
#	space_reserved[resource] = space_reserved.get_or_add(resource, 0) + quantity
#	return true
