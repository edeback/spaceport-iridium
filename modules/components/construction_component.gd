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
var construction_job: Job = null

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
	Global.path_manager.set_exterior(owner_module, true)

func ready_constructed() -> void:
	set_process(false)
	# Ensure state is set if this was spawned already built
	current_state = ConstructionState.Built
	material_storage.empty_all()
	material_storage.accepts_exports = false
	material_storage.accepts_imports = false
	material_storage.display_storage_ui = false
	material_storage.display_info_panel_ui = false
	Global.path_manager.set_exterior(owner_module, false)

func start_deconstruction() -> void:
	if current_state == ConstructionState.Built:
		set_process(true)
		# Tearing down something already standing is "finish what's started".
		construction_job = Job.of(&"deconstruct_module")
		construction_job.target_a = JobTarget.of_component(self)
		construction_job.priority = JobPriorities.COMPLETION_BOOST
		construction_job.job_end.connect(_on_deconstruction_job_end.bind(construction_job), CONNECT_ONE_SHOT)
		Global.job_manager.add_job(construction_job)
		current_state = ConstructionState.Deconstructing
		work_seconds_done = work_seconds_to_complete * deconstruction_time_multiplier
		# A module coming apart stops being a live part of the station - it was
		# only ever still drawing/generating power because construction predates
		# the lifecycle hook (WI-39).
		owner_module.ready_deconstructing()

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

## WI-44 adapter - the uniform name Action_Work calls on anything a pawn can put
## work seconds into (ProcessorComponent already had exactly this signature).
## Positive seconds build, negative deconstruct; returns whether the work is done.
##
## Deliberately only moves the counter and answers "are we there yet". The STATE
## transition, the finished signals and ready_constructed() all still happen in
## _process, so the existing lifecycle ordering is untouched.
func advance_work(seconds: float) -> bool:
	work_seconds_done += seconds
	if seconds < 0.0:
		return work_seconds_done <= 0.0
	return work_seconds_done >= work_seconds_to_complete

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
func _start_construction_job(add_to_board: bool) -> Job:
	material_storage.accepts_exports = false
	material_storage.accepts_imports = false
	material_storage.display_storage_ui = false
	material_storage.display_info_panel_ui = false
	# Only created once the site is fully resourced, so this is always a
	# finish-what's-started job: boost it over starting fresh hauls.
	construction_job = Job.of(&"construct_module")
	construction_job.target_a = JobTarget.of_component(self)
	construction_job.priority = JobPriorities.COMPLETION_BOOST
	construction_job.job_end.connect(_on_construction_job_end.bind(construction_job), CONNECT_ONE_SHOT)
	current_state = ConstructionState.Constructing
	if add_to_board:
		Global.job_manager.add_job(construction_job)
	return construction_job

## Claims the pawn that just delivered the last resource this site needed,
## handing them straight into the construction job instead of waiting for
## _process() to notice next frame and post it on the shared board for
## whoever happens to be free.
func offer_followup_job(_pawn: PawnBase) -> Job:
	if current_state != ConstructionState.NotStarted or construction_job != null:
		return null
	if not ready_for_construction():
		return null
	return _start_construction_job(false)

func _on_construction_job_end(finished_job: Job) -> void:
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
		material_storage.priority = JobPriorities.CONSTRUCTION_IMPORT
		for resource : ResourceData in owner_module.module_data.resource_costs:
			if resource != Global.resource_manager.credit_resource:
				var new_data := StorageData.new()
				new_data.desired = owner_module.module_data.resource_costs[resource]
				material_storage.storage_data[resource] = new_data
				material_storage.max_stored += new_data.desired

func _on_deconstruction_job_end(finished_job: Job) -> void:
	if finished_job.is_failed() and construction_job == finished_job:
		construction_job = Job.of(&"deconstruct_module")
		construction_job.target_a = JobTarget.of_component(self)
		construction_job.priority = JobPriorities.COMPLETION_BOOST
		construction_job.job_end.connect(_on_deconstruction_job_end.bind(construction_job), CONNECT_ONE_SHOT)
		Global.job_manager.add_job(construction_job)

func setup_storage_post_deconstruction() -> void:
	Global.path_manager.set_exterior(owner_module, true)
	material_storage.empty_all()
	material_storage.add_to_group(Groups.RESOURCE_STORAGE)
	material_storage.accepts_imports = false
	if owner_module.module_data.resource_costs.is_empty():
		material_storage.display_storage_ui = false
		material_storage.display_info_panel_ui = false
	else: 
		material_storage.accepts_exports = true
		material_storage.display_storage_ui = true
		material_storage.display_info_panel_ui = true
		material_storage.priority = JobPriorities.DECONSTRUCTION_EXPORT
		for resource : ResourceData in owner_module.module_data.resource_costs:
			if resource != Global.resource_manager.credit_resource:
				var new_data := StorageData.new()
				new_data.deposit(owner_module.module_data.resource_costs[resource], false)
				new_data.desired = 0
				material_storage.storage_data[resource] = new_data

# --- persistence ------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"state": current_state, "work_done": work_seconds_done}

## Runs after the ready pass (ready_blueprint for unbuilt modules). Saved
## Constructing collapses to NotStarted: the job wasn't persisted, and
## NotStarted re-posts as soon as ready_for_construction() sees the restored
## materials - work_seconds_done keeps the progress already made.
func load_save_data(data: Dictionary) -> void:
	var saved_state: ConstructionState = int(data.get("state", ConstructionState.NotStarted)) as ConstructionState
	match saved_state:
		ConstructionState.Built:
			pass # ready_constructed already set everything
		ConstructionState.Deconstructing, ConstructionState.Deconstructed:
			_setup_deconstructed_for_load()
		_:
			current_state = ConstructionState.NotStarted
			work_seconds_done = float(data.get("work_done", 0.0))

## Deconstruction-in-progress collapses to Deconstructed on load (mirror of
## the Constructing->NotStarted rule): reconfigure the material storage as an
## export bin; the storage section restores the actual remaining contents.
func _setup_deconstructed_for_load() -> void:
	Global.path_manager.set_exterior(owner_module, true)
	material_storage.empty_all()
	material_storage.add_to_group(Groups.RESOURCE_STORAGE)
	material_storage.accepts_imports = false
	material_storage.accepts_exports = true
	material_storage.display_storage_ui = true
	material_storage.display_info_panel_ui = true
	material_storage.priority = JobPriorities.DECONSTRUCTION_EXPORT
	var capacity: int = 0
	for resource: ResourceData in owner_module.module_data.resource_costs:
		if resource != Global.resource_manager.credit_resource:
			capacity += owner_module.module_data.resource_costs[resource]
	material_storage.max_stored = maxi(capacity, material_storage.max_stored)
	work_seconds_done = 0
	current_state = ConstructionState.Deconstructed
	set_process(true) # keeps polling until the export bin empties, then removes the module
	# The load's ready pass ran ready_constructed on this module (a teardown site
	# still saves as "built" - see ModuleBase.ready_deconstructing), so its
	# components signed up for everything a standing module does. Undo that.
	owner_module.ready_deconstructing()

func has_ui() -> bool:
	return (not owner_module.module_data.instant_build) if owner_module and owner_module.module_data else false
	
func get_ui() -> ModuleComponentUI:
	var ui: ConstructionComponentUI = ui_info_panel_element.instantiate() as ConstructionComponentUI
	ui.set_construction_component(self)
	return ui
