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
## The build or teardown job this site has posted and not yet seen end (WI-70).
## Its handler is what puts a site back to work when a builder walks away: see
## _on_slot_job_end.
var _slot: JobSlot = JobSlot.new(_on_slot_job_end)

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
	material_storage.set_all_roles(StorageData.Role.EXCLUDED)
	material_storage.display_storage_ui = false
	material_storage.display_info_panel_ui = false
	Global.path_manager.set_exterior(owner_module, false)

func start_deconstruction() -> void:
	if current_state == ConstructionState.Built:
		set_process(true)
		# Tearing down something already standing is "finish what's started".
		_post_deconstruction_job()
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
			if ready_for_construction() and not _slot.is_live():
				_start_construction_job(true)
		ConstructionState.Constructing:
			if work_seconds_done >= work_seconds_to_complete:
				current_state = ConstructionState.Built
				construction_finished.emit()
				owner_module.ready_constructed()
			elif not _slot.is_live():
				# Belt and braces for F25 (WI-70 §4): building with nobody on the
				# job. The slot handler already resets this, so reaching here means
				# a path that ended the job without it - and it is also what frees a
				# site stuck like this in a session that predates the fix.
				current_state = ConstructionState.NotStarted
		ConstructionState.Built:
			pass
		ConstructionState.Deconstructing:
			if work_seconds_done > 0 and not _slot.is_live():
				# Same self-heal for a teardown, and the path a site restored
				# mid-teardown takes when nobody was working it at the save (F38).
				_post_deconstruction_job()
			elif work_seconds_done <= 0:
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
			push_warning("Failed to setup storage as it cannot contain required materials!")
			return false
	return true

## Creates and holds a construction job. The slot's handler is what keeps the
## site from getting stuck if the job never gets done - a direct handoff declined
## at the last second, a board-claimed job that failed after pickup (unreachable,
## module removed mid-route), or a builder who was interrupted (F25).
##
## Only called with nothing live in the slot; both callers check.
func _start_construction_job(add_to_board: bool) -> Job:
	# Only created once the site is fully resourced, so this is always a
	# finish-what's-started job: boost it over starting fresh hauls.
	var job: Job = Job.of(&"construct_module")
	job.target_a = JobTarget.of_component(self)
	job.priority = JobPriorities.COMPLETION_BOOST
	_slot.post(job)
	_begin_constructing()
	if add_to_board:
		Global.job_manager.add_job(job)
	return job

## The site is resourced and has a builder accounted for.
func _begin_constructing() -> void:
	# Freezes the bin WITH its materials still in it - the site is fully resourced
	# and the delivered stock must not be hauled back out while the work runs.
	# This is the case the per-slot role exists for: a component-level flag would
	# have done, but a role that only worked on an empty bin would not have.
	material_storage.set_all_roles(StorageData.Role.EXCLUDED)
	material_storage.display_storage_ui = false
	material_storage.display_info_panel_ui = false
	current_state = ConstructionState.Constructing

func _post_deconstruction_job() -> void:
	if Global.job_manager == null:
		return
	var job: Job = Job.of(&"deconstruct_module")
	job.target_a = JobTarget.of_component(self)
	job.priority = JobPriorities.COMPLETION_BOOST
	if _slot.post(job) == job:
		Global.job_manager.add_job(job)

## Claims the pawn that just delivered the last resource this site needed,
## handing them straight into the construction job instead of waiting for
## _process() to notice next frame and post it on the shared board for
## whoever happens to be free.
func offer_followup_job(_pawn: PawnBase) -> Job:
	if current_state != ConstructionState.NotStarted or _slot.is_live():
		return null
	if not ready_for_construction():
		return null
	return _start_construction_job(false)

## The build or teardown job ended. Finished is the lifecycle's business: the
## work counter is where it should be and _process moves the state on. Anything
## else - FAILED or INTERRUPTED - puts the site back to work (F25, WI-70 §4). This
## handler asked is_failed() before, and an interrupted job is not failed: a
## builder who resigned, was fired, or went to suit up at Tier 2 left the site in
## Constructing for the rest of the session.
func _on_slot_job_end(_job: Job, completed: bool) -> void:
	if completed or not is_inside_tree():
		return
	match current_state:
		ConstructionState.Constructing:
			current_state = ConstructionState.NotStarted # re-posts once resourced
		ConstructionState.Deconstructing:
			_post_deconstruction_job()

## The build or teardown job a pawn was on when the save was written (WI-70 §3).
## The site restores without it - Constructing comes back as NotStarted, and a
## teardown comes back Deconstructing with an empty slot - so without this both
## post a second job beside the restored one (F26).
func adopt_restored_job(job: Job) -> bool:
	if job.is_type(&"construct_module"):
		# Resourced by now: the storage block restored the delivered materials
		# before any pawn loaded.
		if current_state != ConstructionState.NotStarted or not ready_for_construction():
			return false
		if not _slot.adopt(job):
			return false
		_begin_constructing()
		return true
	if job.is_type(&"deconstruct_module"):
		return current_state == ConstructionState.Deconstructing and _slot.adopt(job)
	return false

## The live build or teardown job, or null. For the inspector and the tests.
func live_job() -> Job:
	return _slot.job()

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
	if owner_module.module_data.resource_costs.is_empty():
		# A free module never receives anything, so its bin stays out of hauling
		# entirely rather than sitting at +99 asking for nothing.
		material_storage.set_all_roles(StorageData.Role.EXCLUDED)
		material_storage.display_storage_ui = false
		material_storage.display_info_panel_ui = false
	else:
		material_storage.display_storage_ui = true
		material_storage.display_info_panel_ui = true
		material_storage.max_stored = 0
		material_storage.priority = JobPriorities.CONSTRUCTION_IMPORT
		for resource : ResourceData in owner_module.module_data.resource_costs:
			if resource != Global.resource_manager.credit_resource:
				var new_data := StorageData.new()
				new_data.role = StorageData.Role.INPUT
				new_data.desired = owner_module.module_data.resource_costs[resource]
				material_storage.storage_data[resource] = new_data
				material_storage.max_stored += new_data.desired

func setup_storage_post_deconstruction() -> void:
	Global.path_manager.set_exterior(owner_module, true)
	material_storage.empty_all()
	material_storage.add_to_group(Groups.RESOURCE_STORAGE)
	if owner_module.module_data.resource_costs.is_empty():
		material_storage.set_all_roles(StorageData.Role.EXCLUDED)
		material_storage.display_storage_ui = false
		material_storage.display_info_panel_ui = false
	else: 
		material_storage.display_storage_ui = true
		material_storage.display_info_panel_ui = true
		material_storage.default_role = StorageData.Role.OUTPUT
		# Refunds are OUTPUT: they ship at the floor to anywhere that will take
		# them, which is exactly what the old DECONSTRUCTION_EXPORT constant meant
		# and no longer needs its own number (WI-65 §2).
		material_storage.output_capacity = 0
		for resource : ResourceData in owner_module.module_data.resource_costs:
			if resource != Global.resource_manager.credit_resource:
				var new_data := StorageData.new()
				new_data.role = StorageData.Role.OUTPUT
				new_data.deposit(owner_module.module_data.resource_costs[resource], false)
				new_data.desired = 0
				material_storage.storage_data[resource] = new_data
				material_storage.output_capacity += new_data.stored

# --- persistence ------------------------------------------------------------

## First of everything. The deconstruction path reconfigures the module's material
## storage, so construction has to have restored before the storage block puts
## actual contents into those bins.
func save_order() -> int:
	return 10

func save_key() -> StringName:
	return &"construction"

func get_save_data() -> Dictionary:
	return {"state": current_state, "work_done": work_seconds_done}

## Runs after the ready pass (ready_blueprint for unbuilt modules). Saved
## Constructing collapses to NotStarted, with work_seconds_done keeping the
## progress already made: a builder restored mid-job is re-adopted through
## adopt_restored_job, which puts it back to Constructing, and a build nobody had
## claimed yet re-posts as soon as ready_for_construction() sees the materials.
func load_save_data(data: Dictionary) -> void:
	var saved_state: ConstructionState = int(data.get("state", ConstructionState.NotStarted)) as ConstructionState
	match saved_state:
		ConstructionState.Built:
			pass # ready_constructed already set everything
		ConstructionState.Deconstructing:
			_restore_deconstructing(float(data.get("work_done", 0.0)))
		ConstructionState.Deconstructed:
			_setup_deconstructed_for_load()
		_:
			current_state = ConstructionState.NotStarted
			work_seconds_done = float(data.get("work_done", 0.0))

## A teardown saved in progress comes back IN PROGRESS, with the work it had left
## (F38, WI-70 §5).
##
## It used to collapse to Deconstructed, "the mirror of Constructing->NotStarted".
## It wasn't one. The refund is only deposited by the live Deconstructing ->
## Deconstructed transition, and during a teardown the bin is empty - so the
## reloaded site found nothing to ship, removed itself, and the whole refund was
## gone. The realistic path was pause, order a demolition, quicksave.
##
## The load's ready pass ran ready_constructed (a teardown site saves as built),
## which left the bin empty and frozen - exactly how start_deconstruction finds
## one. So this is start_deconstruction with the progress restored and without a
## job: the one a pawn was on is adopted through adopt_restored_job, and if nobody
## was, the first frame's self-heal posts one. A save written mid-teardown before
## this fix still says Deconstructing with its work_done, so it restores too.
func _restore_deconstructing(work_left: float) -> void:
	current_state = ConstructionState.Deconstructing
	# After the state: progress reads the remaining work against the teardown's
	# own total only once the state says it is a teardown.
	work_seconds_done = work_left
	set_process(true)
	owner_module.ready_deconstructing()

## A finished teardown whose refund was still waiting to be hauled away: the
## material storage becomes the export bin again, and the storage section
## restores the refund still in it on top of this.
func _setup_deconstructed_for_load() -> void:
	Global.path_manager.set_exterior(owner_module, true)
	material_storage.empty_all()
	material_storage.add_to_group(Groups.RESOURCE_STORAGE)
	material_storage.display_storage_ui = true
	material_storage.display_info_panel_ui = true
	# The storage block restores the actual contents on top of this, and it
	# creates the slots itself - so the role has to be waiting for them rather
	# than applied to slots that do not exist yet.
	material_storage.default_role = StorageData.Role.OUTPUT
	var capacity: int = 0
	for resource: ResourceData in owner_module.module_data.resource_costs:
		if resource != Global.resource_manager.credit_resource:
			capacity += owner_module.module_data.resource_costs[resource]
	material_storage.output_capacity = maxi(capacity, material_storage.output_capacity)
	work_seconds_done = 0
	current_state = ConstructionState.Deconstructed
	set_process(true) # keeps polling until the export bin empties, then removes the module
	# The load's ready pass ran ready_constructed on this module (a teardown site
	# still saves as "built" - see ModuleBase.ready_deconstructing), so its
	# components signed up for everything a standing module does. Undo that.
	owner_module.ready_deconstructing()

## A progress readout, so only while there is progress to report. WI-51 moved the
## deconstruct/demolish pair out to the inspector's footer, which left a finished
## module with a Build tab that had nothing in it.
func has_ui() -> bool:
	if owner_module == null or owner_module.module_data == null:
		return false
	if owner_module.module_data.instant_build:
		return false
	return current_state != ConstructionState.Built

func get_ui() -> ModuleComponentUI:
	var ui: ConstructionComponentUI = ui_info_panel_element.instantiate() as ConstructionComponentUI
	ui.set_construction_component(self)
	return ui
