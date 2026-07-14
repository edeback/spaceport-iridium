class_name Job_ConstructModule
extends JobBase

var pawn: PawnBase
var module_to_construct: ModuleBase
var construction_component: ConstructionComponent
var deconstruct: bool = false
var state: ConstructModuleState = ConstructModuleState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()
var shift_spot_interval: float = 3.0
var shift_spot_elapsed: float = 0.0

enum ConstructModuleState { Starting, MovingToModule, ConstructModule, DeconstructModule, Finished, Failed }

func get_category() -> Category:
	return Category.BUILD

func get_job_description() -> String:
	if deconstruct:
		return "Deconstruct Module"
	return "Construct Module"

func get_subtask_description() -> String:
	match state:
		ConstructModuleState.MovingToModule:
			return "Moving to module"
		ConstructModuleState.ConstructModule:
			return "Constructing module"
		ConstructModuleState.DeconstructModule:
			return "Deconstructing module"
	return ""

func setup(_module: ModuleBase) -> void:
	assert(_module != null)
	module_to_construct = _module
	construction_component = module_to_construct.get_component_by_type(ConstructionComponent)
	if construction_component == null:
		print("Module trying to construct without construction component assigned?")
		state = ConstructModuleState.Failed
		return
	state = ConstructModuleState.Starting
	SignalBus.module_removed.connect(_module_removed)
	construction_component.construction_finished.connect(_on_work_complete)
	construction_component.deconstruction_finished.connect(_on_work_complete)

func _on_work_complete() -> void:
	state = ConstructModuleState.Finished
	
func is_valid() -> bool:
	return is_instance_valid(module_to_construct) and is_instance_valid(construction_component)
	
func can_do_job(_pawn: PawnBase) -> bool:
	if !deconstruct and !construction_component.ready_for_construction():
		return false
	return Global.path_manager.is_space_reachable(_pawn)
	
func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	move_to_module()
		
func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = ConstructModuleState.Failed
	else:
		state = ConstructModuleState.Finished

func _on_end() -> void:
	# Ended jobs must not linger connected to the autoload or the component -
	# the connections would both leak the job and keep its handlers firing.
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	if is_instance_valid(construction_component):
		if construction_component.construction_finished.is_connected(_on_work_complete):
			construction_component.construction_finished.disconnect(_on_work_complete)
		if construction_component.deconstruction_finished.is_connected(_on_work_complete):
			construction_component.deconstruction_finished.disconnect(_on_work_complete)
	
func process_job(delta: float) -> void:
	match state:
		ConstructModuleState.Starting:
			pass
		ConstructModuleState.MovingToModule:
			pass
		ConstructModuleState.ConstructModule:
			construct_module(delta)
		ConstructModuleState.DeconstructModule:
			construct_module(delta)
		ConstructModuleState.Finished:
			pass
		ConstructModuleState.Failed:
			pass
			
func _module_removed(module: ModuleBase) -> void:
	if module == module_to_construct:
		module_to_construct = null
		state = ConstructModuleState.Failed

func move_to_module() -> void:
	state = ConstructModuleState.MovingToModule
	pawn.movement_component.movement_ended.connect(move_complete, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(module_to_construct, 1, true)
		
func move_complete(as_success: bool) -> void:
	# _ended: a stale movement one-shot firing after an external cancel must
	# not overwrite the terminal state (Failed -> ConstructModule would leave
	# the pawn working a dead job forever).
	if not as_success or _ended:
		cancel(true)
		return
	if deconstruct:
		state = ConstructModuleState.DeconstructModule
	else:
		state = ConstructModuleState.ConstructModule
		
func construct_module(delta: float) -> void:
	shift_spot_elapsed += delta
	if shift_spot_elapsed >= shift_spot_interval:
		pawn.global_position = module_to_construct.get_random_position_on_module()
		shift_spot_elapsed = 0
	construction_component.work_seconds_done += -delta if deconstruct else delta
	
	
func is_failed() -> bool:
	return state == ConstructModuleState.Failed
	
func is_finished() -> bool:
	return state == ConstructModuleState.Finished
