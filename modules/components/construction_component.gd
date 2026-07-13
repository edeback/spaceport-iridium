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
	work_seconds_done = 0
	Global.path_manager.change_vertex_group(owner_module, &"space")
	
func ready_constructed() -> void:
	set_process(false)
	# Ensure state is set if this was spawned already built
	current_state = ConstructionState.Built
	material_storage.empty_all()
	material_storage.accepts_exports = false
	material_storage.accepts_imports = false
	material_storage.display_storage_ui = false
	material_storage.display_info_panel_ui = false
	if Global.path_manager.get_vertex(owner_module).group == &"space":
		Global.path_manager.change_vertex_group(owner_module, "")

func start_deconstruction() -> void:
	if current_state == ConstructionState.Built:
		set_process(true)
		construction_job = Job_ConstructModule.new()
		construction_job.setup(owner_module)
		construction_job.deconstruct = true
		construction_job.job_end.connect(_on_deconstruction_job_end.bind(construction_job), CONNECT_ONE_SHOT)
		Global.job_manager.add_job(construction_job)
		current_state = ConstructionState.Deconstructing
		work_seconds_done = work_seconds_to_complete * deconstruction_time_multiplier

func _process(delta: float) -> void:
	# State polling only (work progress arrives via the construction job, which
	# is already sim-scaled through its pawn) - but don't advance states while
	# the sim is paused.
	if Global.time_manager.scale(delta) <= 0.0:
		return
	match current_state:
		ConstructionState.Paused:
			pass
		ConstructionState.NotStarted:
			if ready_for_construction():
				_start_construction_job(true)
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

## Creates and arms a construction job, wiring up the failure listener so
## the component can't get permanently stuck if the job never actually gets
## done - whether that's because a direct handoff got declined (can_do_job()
## failed at the last second) or a board-claimed job failed some other way
## after being picked up (unreachable, module removed mid-route, etc).
func _start_construction_job(add_to_board: bool) -> Job_ConstructModule:
	material_storage.accepts_exports = false
	material_storage.accepts_imports = false
	material_storage.display_storage_ui = false
	material_storage.display_info_panel_ui = false
	construction_job = Job_ConstructModule.new()
	construction_job.setup(owner_module)
	construction_job.job_end.connect(_on_construction_job_end.bind(construction_job), CONNECT_ONE_SHOT)
	current_state = ConstructionState.Constructing
	if add_to_board:
		Global.job_manager.add_job(construction_job)
	return construction_job

## Claims the pawn that just delivered the last resource this site needed,
## handing them straight into the construction job instead of waiting for
## _process() to notice next frame and post it on the shared board for
## whoever happens to be free.
func offer_followup_job(_pawn: PawnBase) -> JobBase:
	if current_state != ConstructionState.NotStarted or construction_job != null:
		return null
	if not ready_for_construction():
		return null
	return _start_construction_job(false)

func _on_construction_job_end(finished_job: Job_ConstructModule) -> void:
	if finished_job.is_failed() and construction_job == finished_job:
		construction_job = null
		current_state = ConstructionState.NotStarted

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

func _on_deconstruction_job_end(finished_job: Job_ConstructModule) -> void:
	if finished_job.is_failed() and construction_job == finished_job:
		construction_job = Job_ConstructModule.new()
		construction_job.setup(owner_module)
		construction_job.deconstruct = true
		construction_job.job_end.connect(_on_deconstruction_job_end.bind(construction_job), CONNECT_ONE_SHOT)
		Global.job_manager.add_job(construction_job)

func setup_storage_post_deconstruction() -> void:
	Global.path_manager.change_vertex_group(owner_module, &"space")
	material_storage.empty_all()
	material_storage.add_to_group("resource_storage")
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
