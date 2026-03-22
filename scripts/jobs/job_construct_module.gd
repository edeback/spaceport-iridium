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
var action: Action_PathToTarget = null
var shift_spot_interval: float = 3.0
var shift_spot_elapsed: float = 0.0

enum ConstructModuleState { Starting, MovingToModule, ConstructModule, DeconstructModule, Finished, Failed }

func get_job_description() -> String:
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
	construction_component.construction_finished.connect(
		func() -> void:
			state = ConstructModuleState.Finished
	)
	construction_component.deconstruction_finished.connect(
		func() -> void:
			state = ConstructModuleState.Finished
	)
	
func is_valid() -> bool:
	return is_instance_valid(module_to_construct) and is_instance_valid(construction_component)
	
func can_do_job(_pawn: PawnBase) -> bool:
	if !construction_component.ready_for_construction():
		return false
	var test_action: Action_PathToTarget = Action_PathToTarget.new()
	test_action.initialize_action(_pawn, module_to_construct)
	var failed: bool = test_action.is_failed()
	test_action.free()
	return not failed
	
func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
		
func cancel(_as_failed: bool) -> void:
	if _as_failed:
		state = ConstructModuleState.Failed
	else:
		state = ConstructModuleState.Finished
	if action:
		action.free()
		action = null
	
func process_job(delta: float) -> void:
	match state:
		ConstructModuleState.Starting:
			state = ConstructModuleState.MovingToModule
		ConstructModuleState.MovingToModule:
			move_to_module(delta)
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
		if action != null:
			action.free()
			action = null

func move_to_module(delta: float) -> void:
	if action == null:
		action = Action_PathToTarget.new()
		action.initialize_action(pawn, module_to_construct)
	action.process_action(delta)
	if action.is_failed():
		state = ConstructModuleState.Failed
		action.free()
		action = null
	elif action.is_finished():
		if deconstruct:
			state = ConstructModuleState.DeconstructModule
		else:
			state = ConstructModuleState.ConstructModule
		action.free()
		action = null
		
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
