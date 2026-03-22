class_name ConstructionComponent
extends ComponentBase

@export var instant_build : bool = false
@export var material_storage: StorageComponent
@export var work_seconds_to_complete: float = 10
var work_seconds_done: float = 0:
	set = _set_work_seconds

enum ConstructionState { Paused, NotStarted, Constructing, Built, Deconstructing, Deconstructed }
var current_state : ConstructionState = ConstructionState.NotStarted
var construction_job: Job_ConstructModule = null

signal construction_finished
signal deconstruction_finished

func _ready() -> void:
	super()
	
func ready_preview() -> void:
	pass
	
func ready_blueprint() -> void:
	set_process(true)
	setup_storage_for_construction()
	current_state = ConstructionState.NotStarted
	owner_module.progress = 0
	Global.path_manager.graph.change_vertex_group(owner_module, "space")
	
func ready_constructed() -> void:
	set_process(false)
	material_storage.storage_data.clear()
	material_storage.accepts_exports = false
	material_storage.accepts_imports = false
	material_storage.display_storage_ui = false
	material_storage.display_info_panel_ui = false
	Global.path_manager.graph.change_vertex_group(owner_module, "")

func _process(delta: float) -> void:
	match current_state:
		ConstructionState.Paused:
			pass
		ConstructionState.NotStarted:
			if ready_for_construction():
				construction_job = Job_ConstructModule.new()
				construction_job.setup(owner_module)
				Global.job_manager.add_job(construction_job)
				current_state = ConstructionState.Constructing
		ConstructionState.Constructing:
			if work_seconds_done >= work_seconds_to_complete:
				current_state = ConstructionState.Built
				construction_finished.emit()
				owner_module.ready_constructed()
		ConstructionState.Built:
			pass
		ConstructionState.Deconstructing:
			pass
		ConstructionState.Deconstructed:
			deconstruction_finished.emit()

func _set_work_seconds(new_work_seconds: float) -> void:
	work_seconds_done = new_work_seconds
	owner_module.progress = work_seconds_done / work_seconds_to_complete

func ready_for_construction() -> bool:
	if owner_module.module_data.resource_costs.is_empty():
		return true
	for resource : ResourceData in owner_module.module_data.resource_costs:
		if material_storage.storage_data.has(resource):
			if material_storage.storage_data[resource].stored < owner_module.module_data.resource_costs[resource]:
				return false
		else:
			print("Failed to setup storage as it cannot contain required materials!")
			return false
	return true
	

func setup_storage_for_construction() -> void:
	material_storage.accepts_exports = false
	if owner_module.module_data.resource_costs.is_empty():
		material_storage.display_storage_ui = false
		material_storage.display_info_panel_ui = false
	else:
		material_storage.accepts_imports = true
		material_storage.display_storage_ui = true
		material_storage.display_info_panel_ui = true
		material_storage.max_stored = 0
		for resource : ResourceData in owner_module.module_data.resource_costs:
			var new_data := StorageData.new()
			new_data.desired = owner_module.module_data.resource_costs[resource]
			material_storage.storage_data[resource] = new_data
			material_storage.max_stored += new_data.desired

func setup_storage_post_deconstruction() -> void:
	material_storage.storage_data.clear()
	material_storage.accepts_imports = false
	if owner_module.module_data.resource_costs.is_empty():
		material_storage.display_storage_ui = false
		material_storage.display_info_panel_ui = false
	else: 
		material_storage.accepts_exports = true
		material_storage.display_storage_ui = true
		material_storage.display_info_panel_ui = true
		for resource : ResourceData in owner_module.module_data.resource_costs:
			var new_data := StorageData.new()
			new_data.desired = owner_module.module_data.resource_costs[resource]
			new_data.stored = new_data.desired
			material_storage.storage_data[resource] = new_data
