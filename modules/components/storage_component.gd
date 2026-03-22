class_name StorageComponent
extends ComponentBase

@export var priority: int = 1
@export var max_stored: int = 10
@export var power_consumption_component: PowerConsumptionComponent

@export var include_in_stats: bool = true

@export var accepts_imports: bool = true
@export var accepts_exports: bool = true

## Can we store anything in here if we want?
@export var allow_any_resource: bool = false
@export var storage_data: Dictionary[ResourceData, StorageData] = {}

#@export var stored_resources: Array[ResourceData]
#@export var cur_stored: Dictionary[ResourceData, float] = {}
#@export var cur_reserved_withdraw: Dictionary[ResourceData, float] = {}
#@export var cur_reserved_deposit: Dictionary[ResourceData, float] = {}
#@export var default_import_jobs: Dictionary[ResourceData, Job_GetResource] = {}

@export var display_info_panel_ui: bool = true
@export var storage_ui: ProgressBar
@export var display_storage_ui: bool = true:
	set(new_display):
		if new_display != display_storage_ui:
			display_storage_ui = new_display
			storage_ui.visible = display_storage_ui
@export var player_configurable: bool = false
@export var construction_storage: bool = false

#var stock_reserved: Dictionary[ResourceData, float] = {}
#var space_reserved: Dictionary[ResourceData, float] = {}

var export_jobs: Array[Job_GetResource] = []
var import_jobs: Array[Job_GetResource] = []

const SMALL_FLOAT: float = 0.000001

var storage_value_changed: bool = true
signal storage_changed(resource: ResourceData, new_value: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()

func ready_preview() -> void:
	set_process(false)
	
func ready_blueprint() -> void:
	if construction_storage:
		display_info_panel_ui = true
		add_to_group("resource_storage")
		set_process(true)
	else:
		display_info_panel_ui = false
		set_process(false)
	
func ready_constructed() -> void:
	if construction_storage:
		display_info_panel_ui = false
		remove_from_group("resource_storage")
		set_process(false)
	else:
		display_info_panel_ui = true
		add_to_group("resource_storage")
		set_process(true)
		if include_in_stats:
			for resource: ResourceData in storage_data:
				resource.register_component(self)

func add_stored_resource(resource: ResourceData) -> void:
	if not storage_data.has(resource):
		var new_data := StorageData.new()
		storage_data[resource] = new_data
		if include_in_stats:
			resource.register_component(self)
			
func remove_stored_resource(resource: ResourceData) -> void:
	var data: StorageData = storage_data.get(resource)
	if data:
		data.end_all_jobs()
		storage_data.erase(resource)
		if include_in_stats:
			resource.unregister_component(self)
		
	#if stored_resources.has(resource):
		#stored_resources.erase(resource)
		#cur_stored.erase(resource)
		#cur_reserved_deposit.erase(resource)
		#cur_reserved_withdraw.erase(resource)
		#if include_in_stats:
			#Global.resource_manager.unregister_component(resource, self)
		#if default_import_jobs.has(resource):
			#default_import_jobs[resource].cancel(true)
			#default_import_jobs.erase(resource)
		#var jobs_to_keep: Array[Job_GetResource] = []
		#for job: Job_GetResource in export_jobs:
			#if job.resource_data == resource:
				#job.cancel(true)
			#else:
				#jobs_to_keep.append(job)
		#export_jobs = jobs_to_keep
		#jobs_to_keep = []
		#for job: Job_GetResource in import_jobs:
			#if job.resource_data == resource:
				#job.cancel(true)
			#else:
				#jobs_to_keep.append(job)
		#import_jobs = jobs_to_keep
			

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Move to only when changed
	if display_storage_ui and storage_value_changed:
		storage_value_changed = false
		update_storage_ui()
	if power_consumption_component and not power_consumption_component.powered:
		last_error = "No power!"
		return
	last_error = ""
	if accepts_imports and space_available(true) > 0:
		for resource: ResourceData in storage_data:
			var data := storage_data[resource]
			if data.import_job == null:
				var new_job: Job_GetResource = Job_GetResource.new()
				new_job.requester = self
				new_job.resource_data = resource
				new_job.deposit_storage = self
				new_job.priority = priority
				data.import_job = new_job
				Global.job_manager.add_job(new_job)

func update_storage_ui() -> void:
	var filled_space := max_stored - space_available()
	storage_ui.value = float(filled_space) / max_stored

func _exit_tree() -> void:
	if include_in_stats:
		for resource: ResourceData in storage_data:
			resource.unregister_component(self)
	for data: StorageData in storage_data.values():
		data.end_all_jobs()
			
		#for resource: ResourceData in stored_resources:
			#Global.resource_manager.unregister_component(resource, self)
	#for job: Job_GetResource in export_jobs:
		#job.cancel(true)
	#export_jobs.clear()
	#for job: Job_GetResource in import_jobs:
		#job.cancel(true)
	#import_jobs.clear()
	#for job: Job_GetResource in default_import_jobs.values():
		#job.cancel(true)
		#Global.job_manager.remove_job(job)
	#default_import_jobs.clear()
	
#func _calc_reserved_from_jobs(resource: ResourceData, jobs: Array[JobData]) -> float:
	#var reserved: float = 0
	#for job: JobData in jobs:
		#if job.resource_data == resource:
			#reserved += job.amount
	#return reserved
	
func update_priority(new_priority: int) -> void:
	if priority != new_priority:
		priority = new_priority
		for data: StorageData in storage_data.values():
			data.set_job_priority(new_priority)
		#for job: Job_GetResource in default_import_jobs.values():
			#job.priority = priority
		
	
#func find_first_stored_resource_with_base(base_resource: ResourceData, minimum: float = 0) -> ResourceData:
	#for resource: ResourceData in cur_stored:
		#if resource == base_resource or resource.base_resource == base_resource:
			#if minimum == 0 or (minimum > 0 and can_withdraw(resource, minimum)):
				#return resource
	#return null
	
func can_store_resource(resource: ResourceData) -> bool:
	if allow_any_resource:
		return true
	return storage_data.has(resource)
	#var has_resource: bool = stored_resources.has(resource)
	#if resource.base_resource != null:
		#has_resource = has_resource or stored_resources.has(resource.base_resource)
	#return has_resource

func can_withdraw(resource: ResourceData, quantity: int, use_reserve: bool = false) -> bool:
	var data: StorageData = storage_data.get(resource)
	if data:
		return data.can_withdraw(quantity, use_reserve)
	return false
		
	#if can_store_resource(resource):
		#var available: float = cur_stored.get_or_add(resource, 0.0)
		#if not use_reserve:
			#available -= cur_reserved_withdraw.get_or_add(resource, 0)
		#return available + SMALL_FLOAT >= quantity
	
func withdraw(resource: ResourceData, quantity: int, use_reserve: bool = false) -> bool:
	var data: StorageData = storage_data.get(resource)
	if data:
		if data.try_withdraw(quantity, use_reserve):
			storage_value_changed = true
			storage_changed.emit(resource, data.stored)
			resource.needs_recalc = true
			return true
	return false
		
	#if can_withdraw(resource, quantity, use_reserve):
		#var new_value: float = max(cur_stored[resource] - quantity, 0)
		#cur_stored[resource] = new_value
		#if use_reserve:
			#cur_reserved_withdraw[resource] = max(cur_reserved_withdraw.get_or_add(resource, 0) - quantity, 0)
		#storage_changed.emit(resource, new_value)
		#return true
	#return false
	
func withdraw_up_to(resource: ResourceData, quantity: int, use_reserve: bool = false) -> int:
	var data: StorageData = storage_data.get(resource)
	if data:
		var withdrawn := data.withdraw_up_to(quantity, use_reserve)
		if withdrawn > 0:
			storage_value_changed = true
			storage_changed.emit(resource, data.stored)
			resource.needs_recalc = true
		return withdrawn
	return 0
	
	#if  cur_stored.has(resource):
		#var max_withdrawable: float = max(cur_stored.get_or_add(resource, 0), 0)
		#if not use_reserve:
			#max_withdrawable -= cur_reserved_withdraw.get_or_add(resource, 0)
		#var withdrawn: float = clampf(quantity, 0, max_withdrawable)
		#cur_stored[resource] -= withdrawn
		#if use_reserve:
			#cur_reserved_withdraw[resource] = max(cur_reserved_withdraw.get_or_add(resource, 0) - withdrawn, 0)
		#storage_changed.emit(resource, cur_stored[resource])
		#Global.resource_manager.queue_recalc_resource(resource)
		#return withdrawn
	#return 0
	
func add_withdraw_job(job: Job_GetResource) -> bool:
	if (can_withdraw(job.resource_data, job.amount)):
		storage_data[job.resource_data].add_withdraw_job(job)
		return true
	return false
	
func cancel_withdraw_job(job: Job_GetResource) -> void:
	var data: StorageData = storage_data.get(job.resource_data)
	if data:
		data.cancel_withdraw_job(job)
	
func complete_withdraw_job(job: Job_GetResource) -> bool:
	var data: StorageData = storage_data.get(job.resource_data)
	if data:
		var did_withdraw: bool = data.complete_withdraw_job(job)
		if did_withdraw:
			storage_value_changed = true
			storage_changed.emit(job.resource_data, data.stored)
		return did_withdraw
	return false
	
func total_stored_by_resource(resource: ResourceData) -> int:
	var data: StorageData = storage_data.get(resource)
	if data:
		return data.stored
	return 0
	
func space_available(excluding_reserve: bool = false) -> int:
	var cur_stored_and_reserved: int = 0
	for data: StorageData in storage_data.values():
		cur_stored_and_reserved += data.stored
		if excluding_reserve:
			cur_stored_and_reserved += data.reserved_deposit
	return max_stored - cur_stored_and_reserved

func can_deposit(resource: ResourceData, quantity: int, use_reserve: bool = false) -> bool:
	if allow_any_resource or storage_data.has(resource):
		return space_available(use_reserve) >= quantity
	return false

func deposit(resource: ResourceData, quantity: int, only_if_room: bool = false, use_reserve: bool = false) -> bool:
	var data: StorageData = storage_data.get(resource)
	if not data and allow_any_resource:
		add_stored_resource(resource)
		data = storage_data.get(resource)
	if data:
		var free_space := space_available(use_reserve)
		if only_if_room and free_space < quantity:
			return false
		var new_stored := data.deposit(quantity, use_reserve)
		storage_value_changed = true
		storage_changed.emit(resource, new_stored)
		resource.needs_recalc = true
		return true
	return false
	
func add_deposit_job(job: Job_GetResource) -> bool:
	var data: StorageData = storage_data.get(job.resource_data)
	if data:
		data.add_deposit_job(job)
		return true
	return false
	
func cancel_deposit_job(job: Job_GetResource) -> void:
	var data: StorageData = storage_data.get(job.resource_data)
	if data:
		data.cancel_deposit_job(job)
	
func complete_deposit_job(job: Job_GetResource) -> bool:
	var data: StorageData = storage_data.get(job.resource_data)
	if data:
		var did_deposit: bool = data.complete_deposit_job(job)
		if did_deposit:
			storage_value_changed = true
			storage_changed.emit(job.resource_data, data.stored)
		return did_deposit
	return false
	#if import_jobs.has(job):
		#if deposit(job.resource_data, job.amount, false, true):
			#import_jobs.erase(job)
			#default_import_jobs.erase(job.resource_data)
			#if job.resource_data.base_resource != null:
				#default_import_jobs.erase(job.resource_data.base_resource)
			#return true
	#return false
	
func has_ui() -> bool:
	return display_info_panel_ui
	
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
