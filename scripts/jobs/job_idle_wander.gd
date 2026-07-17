class_name Job_IdleWander
extends JobBase

var pawn: PawnBase
var destination_module: ModuleBase
var state: JobState = JobState.Starting

func get_category() -> Category:
	return Category.MISC

func get_job_description() -> String:
	return "Wandering idly"

func get_subtask_description() -> String:
	return ""
	
func is_valid() -> bool:
	return true
	
func can_do_job(_pawn: PawnBase) -> bool:
	if _pawn.current_module:
		return _pawn.current_module.get_path_component().module_connections.size() > 0
	else:
		var airlocks: Array[Node] = _pawn.get_tree().get_nodes_in_group("airlock")
		return airlocks.size() > 0
	
func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	var destination: ModuleBase = null
	if _pawn.current_module:
		var connections: Array[Node2D] = _pawn.current_module.get_path_component().module_connections.keys()
		connections.shuffle()
		# Off-shift pawns drift toward company: prefer a connected social
		# space when one exists (WI-06).
		if not _pawn.is_on_shift():
			for node in connections:
				if node is ModuleBase and node is not ModuleTurbolift \
						and (node as ModuleBase).get_component_by_type(SocialComponent) != null \
						and PawnBreathingComponent.is_module_safe_for(_pawn, node as ModuleBase):
					destination = node as ModuleBase
					break
		if destination == null:
			for node in connections:
				if node is ModuleBase and node is not ModuleTurbolift \
						and PawnBreathingComponent.is_module_safe_for(_pawn, node as ModuleBase):
					destination = node as ModuleBase
					break
	else:
		var airlocks: Array[Node] = _pawn.get_tree().get_nodes_in_group("airlock")
		var distance: float = -1
		for node in airlocks:
			if node is ModuleBase:
				var dist_sq: float = node.global_position.distance_squared_to(_pawn.global_position)
				if distance < 0 or dist_sq < distance:
					distance = dist_sq
					destination = node as ModuleBase
	if destination != null:
		destination_module = destination
		move_to_module()
	else:
		cancel(true)
		
func complete(as_success: bool) -> void:
	if as_success and not _ended and _try_spread():
		return
	cancel(!as_success)

## Arrival spreading (WI-16): if we stopped in a module that already holds
## other stationary pawns, claim a STAND anchor (generated for hallways) and
## walk the short tail to it instead of stacking on the arrival point. One
## group query at arrival - never per-frame. The pawn keeps the claim while
## parked; it auto-releases on its next movement.
func _try_spread() -> bool:
	if pawn.current_module == null or not _module_has_other_idlers():
		return false
	var anchor: AnchorDef = pawn.claim_stand_anchor()
	if anchor == null:
		return false  # no free spot - staying put is the correct fallback
	state = JobState.Working
	pawn.movement_component.movement_ended.connect(_spread_done, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(pawn.current_module, 0.4, false, anchor)
	return true

func _spread_done(_as_success: bool) -> void:
	# However the spreading leg ended, the wander itself already succeeded.
	cancel(false)

func _module_has_other_idlers() -> bool:
	for node: Node in pawn.get_tree().get_nodes_in_group("pawn"):
		var other: PawnBase = node as PawnBase
		if other == null or other == pawn:
			continue
		if other.current_module == pawn.current_module and not other.movement_component.is_traveling():
			return true
	return false

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = JobState.Failed
	else:
		state = JobState.Finished

func move_to_module() -> void:
	state = JobState.Moving
	pawn.movement_component.movement_ended.connect(complete, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(destination_module, 0.4)
	
	
func is_failed() -> bool:
	return state == JobState.Failed
	
func is_finished() -> bool:
	return state == JobState.Finished
