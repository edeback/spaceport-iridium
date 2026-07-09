class_name ConstructionComponent
extends ComponentBase

@export var material_storage: StorageComponent
@export var work_seconds_to_complete: float = 10
@export var deconstruction_time_multiplier: float = 0.25
var work_seconds_done: float = 0:
	set = _set_work_seconds

enum ConstructionState { Paused, NotStarted, Constructing, Built, Deconstructing, Deconstructed }
var current_state : ConstructionState = ConstructionState.NotStarted:
	set(new_state):
		if new_state != current_state:
			current_state = new_state
			state_changed.emit(new_state)
var construction_job: Job_ConstructModule = null

signal construction_finished
signal deconstruction_finished
signal state_changed(new_state: ConstructionState)
signal progress_changed(new_progress: float)

func _ready() -> void:
	super()
	
func ready_preview() -> void:
	pass
	
func ready_blueprint() -> void:
	set_process(true)
	setup_storage_for_construction()
	current_state = ConstructionState.NotStarted
	owner_module.progress = 0
	Global.path_manager.change_vertex_group(owner_module, &"space")
	
func ready_constructed() -> void:
	set_process(false)
	material_storage.empty_all()
	material_storage.accepts_exports = false
	material_storage.accepts_imports = false
	material_storage.display_storage_ui = false
	material_storage.display_info_panel_ui = false
	if Global.path_manager.get_vertex(owner_module).group == &"space":
		Global.path_manager.change_vertex_group(owner_module, "")

func start_deconstruction() -> void:
	set_process(true)
	construction_job = Job_ConstructModule.new()
	construction_job.setup(owner_module)
	construction_job.deconstruct = true
	Global.job_manager.add_job(construction_job)
	current_state = ConstructionState.Deconstructing
	work_seconds_done = work_seconds_to_complete * deconstruction_time_multiplier

func _process(delta: float) -> void:
	match current_state:
		ConstructionState.Paused:
			pass
		ConstructionState.NotStarted:
			if ready_for_construction():
				material_storage.accepts_exports = false
				material_storage.accepts_imports = false
				material_storage.display_storage_ui = false
				material_storage.display_info_panel_ui = false
				construction_job = Job_ConstructModule.new()
				construction_job.setup(owner_module)
				Global.job_manager.add_job(construction_job)
				current_state = ConstructionState.Constructing
				work_seconds_done = 0
		ConstructionState.Constructing:
			if work_seconds_done >= work_seconds_to_complete:
				current_state = ConstructionState.Built
				construction_finished.emit()
				owner_module.ready_constructed()
		ConstructionState.Built:
			pass
		ConstructionState.Deconstructing:
			if work_seconds_done <= 0:
				current_state = ConstructionState.Deconstructed
				deconstruction_finished.emit()
				setup_storage_post_deconstruction()
				work_seconds_done = 0
				current_state = ConstructionState.Deconstructed
		ConstructionState.Deconstructed:
			if material_storage.is_empty():
				Global.world_manager.remove_module(owner_module, false)

func _set_work_seconds(new_work_seconds: float) -> void:
	work_seconds_done = new_work_seconds
	var progress: float = get_progress()
	owner_module.progress = progress
	progress_changed.emit(progress)

func get_progress() -> float:
	var progress: float = work_seconds_done / work_seconds_to_complete
	if current_state == ConstructionState.Deconstructing:
		progress /= deconstruction_time_multiplier
	return progress

func ready_for_construction() -> bool:
	if owner_module.module_data.resource_costs.is_empty():
		return true
	for resource : ResourceData in owner_module.module_data.resource_costs:
		if resource == Global.resource_manager.credit_resource:
			continue
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
		material_storage.priority = 99
		for resource : ResourceData in owner_module.module_data.resource_costs:
			if resource != Global.resource_manager.credit_resource:
				var new_data := StorageData.new()
				new_data.desired = owner_module.module_data.resource_costs[resource]
				material_storage.storage_data[resource] = new_data
				material_storage.max_stored += new_data.desired

func setup_storage_post_deconstruction() -> void:
	material_storage.empty_all()
	material_storage.accepts_imports = false
	if owner_module.module_data.resource_costs.is_empty():
		material_storage.display_storage_ui = false
		material_storage.display_info_panel_ui = false
	else: 
		material_storage.accepts_exports = true
		material_storage.display_storage_ui = true
		material_storage.display_info_panel_ui = true
		material_storage.priority = -99
		for resource : ResourceData in owner_module.module_data.resource_costs:
			if resource != Global.resource_manager.credit_resource:
				var new_data := StorageData.new()
				new_data.deposit(owner_module.module_data.resource_costs[resource], false)
				new_data.desired = 0
				material_storage.storage_data[resource] = new_data

func has_ui() -> bool:
	return (not owner_module.module_data.instant_build) if owner_module and owner_module.module_data else false
	
func get_ui() -> ModuleComponentUI:
	var ui: ConstructionComponentUI = ui_info_panel_element.instantiate() as ConstructionComponentUI
	ui.set_construction_component(self)
	return ui
