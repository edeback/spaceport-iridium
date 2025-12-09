class_name MultiStorageComponent
extends ComponentBase




@export var priority: int = 1
@export var stored_resources: Array[ResourceData]
@export var max_stored: float = 10
@export var power_consumption_component: PowerConsumptionComponent

@export var include_in_stats: bool = true

@export var accepts_imports: bool = true
@export var accepts_exports: bool = true

@export var cur_stored: Dictionary[ResourceData, float] = {}

@export var storage_data: Dictionary[ResourceData, StorageData] = {}

@export var cur_reserved_withdraw: Dictionary[ResourceData, float] = {}
@export var cur_reserved_deposit: Dictionary[ResourceData, float] = {}

@export var default_import_jobs: Dictionary[ResourceData, Job_GetResource] = {}

@export var storage_ui: ProgressBar
@export var player_configurable: bool = false

#var stock_reserved: Dictionary[ResourceData, float] = {}
#var space_reserved: Dictionary[ResourceData, float] = {}

var export_jobs: Array[Job_GetResource] = []
var import_jobs: Array[Job_GetResource] = []

const SMALL_FLOAT: float = 0.000001

signal storage_changed(resource: ResourceData, new_value: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	add_to_group("resource_storage")
	if include_in_stats:
		for resource: ResourceData in stored_resources:
			Global.resource_manager.register_component(resource, self)

func add_stored_resource(resource: ResourceData) -> void:
	if not stored_resources.has(resource):
		stored_resources.append(resource)
		if include_in_stats:
			Global.resource_manager.register_component(resource, self)
			
func remove_stored_resource(resource: ResourceData) -> void:
	if stored_resources.has(resource):
		stored_resources.erase(resource)
		cur_stored.erase(resource)
		cur_reserved_deposit.erase(resource)
		cur_reserved_withdraw.erase(resource)
		if include_in_stats:
			Global.resource_manager.unregister_component(resource, self)
		if default_import_jobs.has(resource):
			default_import_jobs[resource].cancel(true)
			default_import_jobs.erase(resource)
		var jobs_to_keep: Array[Job_GetResource] = []
		for job: Job_GetResource in export_jobs:
			if job.resource_data == resource:
				job.cancel(true)
			else:
				jobs_to_keep.append(job)
		export_jobs = jobs_to_keep
		jobs_to_keep = []
		for job: Job_GetResource in import_jobs:
			if job.resource_data == resource:
				job.cancel(true)
			else:
				jobs_to_keep.append(job)
		import_jobs = jobs_to_keep
			

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var test_total_stored: float = 0
	for resource in cur_stored:
		test_total_stored += cur_stored[resource]
	storage_ui.value = test_total_stored / max_stored
	if power_consumption_component and not power_consumption_component.powered:
		last_error = "No power!"
		return
	last_error = ""
	if accepts_imports and space_available() > 1.0:
		for resource: ResourceData in stored_resources:
			if !default_import_jobs.has(resource):
				var new_job: Job_GetResource = Job_GetResource.new()
				new_job.requester = self
				new_job.resource_data = resource
				new_job.deposit_storage = self
				new_job.priority = priority
				Global.job_manager.add_job(new_job)
				default_import_jobs[resource] = new_job
		#Global.job_manager.add_job(owner_module, import_job)
		pass
	
func _exit_tree() -> void:
	if include_in_stats:
		for resource: ResourceData in stored_resources:
			Global.resource_manager.unregister_component(resource, self)
	for job: Job_GetResource in export_jobs:
		job.cancel(true)
	export_jobs.clear()
	for job: Job_GetResource in import_jobs:
		job.cancel(true)
	import_jobs.clear()
	for job: Job_GetResource in default_import_jobs.values():
		job.cancel(true)
		Global.job_manager.remove_job(job)
	default_import_jobs.clear()
	
#func _calc_reserved_from_jobs(resource: ResourceData, jobs: Array[JobData]) -> float:
	#var reserved: float = 0
	#for job: JobData in jobs:
		#if job.resource_data == resource:
			#reserved += job.amount
	#return reserved
	
func update_priority(new_priority: int) -> void:
	if priority != new_priority:
		priority = new_priority
		for job: Job_GetResource in default_import_jobs.values():
			job.priority = priority
		
	
func find_first_stored_resource_with_base(base_resource: ResourceData, minimum: float = 0) -> ResourceData:
	for resource: ResourceData in cur_stored:
		if resource == base_resource or resource.base_resource == base_resource:
			if minimum == 0 or (minimum > 0 and can_withdraw(resource, minimum)):
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
			available -= cur_reserved_withdraw.get_or_add(resource, 0)
		return available + SMALL_FLOAT >= quantity
	return false
	
func withdraw(resource: ResourceData, quantity: float = 1.0, use_reserve: bool = false) -> bool:
	if can_withdraw(resource, quantity, use_reserve):
		var new_value: float = max(cur_stored[resource] - quantity, 0)
		cur_stored[resource] = new_value
		if use_reserve:
			cur_reserved_withdraw[resource] = max(cur_reserved_withdraw.get_or_add(resource, 0) - quantity, 0)
		storage_changed.emit(resource, new_value)
		Global.resource_manager.queue_recalc_resource(resource)
		return true
	return false
	
func withdraw_up_to(resource: ResourceData, quantity: float = 1.0, use_reserve: bool = false) -> float:
	if  cur_stored.has(resource):
		var max_withdrawable: float = max(cur_stored.get_or_add(resource, 0), 0)
		if not use_reserve:
			max_withdrawable -= cur_reserved_withdraw.get_or_add(resource, 0)
		var withdrawn: float = clampf(quantity, 0, max_withdrawable)
		cur_stored[resource] -= withdrawn
		if use_reserve:
			cur_reserved_withdraw[resource] = max(cur_reserved_withdraw.get_or_add(resource, 0) - withdrawn, 0)
		storage_changed.emit(resource, cur_stored[resource])
		Global.resource_manager.queue_recalc_resource(resource)
		return withdrawn
	return 0
	
func add_withdraw_job(job: Job_GetResource) -> bool:
	if (can_withdraw(job.resource_data)):
		export_jobs.append(job)
		cur_reserved_withdraw[job.resource_data] = cur_reserved_withdraw.get_or_add(job.resource_data, 0) + job.amount
		return true
	return false
	
func cancel_withdraw_job(job: Job_GetResource) -> void:
	if export_jobs.has(job):
		export_jobs.erase(job)
		cur_reserved_withdraw[job.resource_data] = cur_reserved_withdraw.get_or_add(job.resource_data, 0) - job.amount
	
func complete_withdraw_job(job: Job_GetResource) -> bool:
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
			for value: float in cur_reserved_deposit.values():
				cur_stored_and_reserved += value
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
		if use_reserve:
			cur_reserved_deposit[resource] = max(cur_reserved_deposit.get_or_add(resource, 0) - quantity, 0)
		storage_changed.emit(resource, new_value)
		Global.resource_manager.queue_recalc_resource(resource)
		return true
	return false
	
func add_deposit_job(job: Job_GetResource) -> bool:
	if (can_deposit(job.resource_data, job.amount)):
		import_jobs.append(job)
		cur_reserved_deposit[job.resource_data] = cur_reserved_deposit.get_or_add(job.resource_data, 0) + job.amount
		return true
	return false
	
func cancel_deposit_job(job: Job_GetResource) -> void:
	if import_jobs.has(job):
		import_jobs.erase(job)
		cur_reserved_deposit[job.resource_data] = cur_reserved_deposit.get_or_add(job.resource_data, 0) - job.amount
		if job.resource_data.base_resource != null:
			default_import_jobs.erase(job.resource_data.base_resource)
	if default_import_jobs.has(job.resource_data) and default_import_jobs[job.resource_data] == job:
		default_import_jobs.erase(job.resource_data)
	if job.resource_data.base_resource != null and default_import_jobs.has(job.resource_data.base_resource) and default_import_jobs[job.resource_data.base_resource] == job:
		default_import_jobs.erase(job.resource_data.base_resource)
	
func complete_deposit_job(job: Job_GetResource) -> bool:
	if import_jobs.has(job):
		if deposit(job.resource_data, job.amount, false, true):
			import_jobs.erase(job)
			default_import_jobs.erase(job.resource_data)
			if job.resource_data.base_resource != null:
				default_import_jobs.erase(job.resource_data.base_resource)
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
