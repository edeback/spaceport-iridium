class_name WorkspaceComponent
extends ComponentBase

## Crew assignment for a module (WI-23). A module with assignees only hands its
## posted work jobs (manned processors today; mining/repair later) to those
## assignees, and assignees prefer their workspace's jobs over equal-priority
## board work (JobBase.workspace + effective_priority_for). An empty assignment
## reopens the jobs to everyone, exactly as if there were no WorkspaceComponent.
##
## Assignments are held as live pawn references at runtime and persisted as
## PawnBase.pawn_id lists: module save data loads before pawns exist, so ids are
## re-resolved to live pawns once the roster is in (first slow_tick after load).

## How many crew can be assigned here at once. 0 or fewer = effectively no cap
## beyond the roster, but scenes should set a sensible small number.
@export var max_workers: int = 1

## Currently assigned crew (live refs). Never contains drones - only CrewManager
## crew get assigned through the UI.
var assigned: Array[PawnBase] = []

## Saved pawn_ids awaiting resolution to live pawns after a load. Non-empty only
## between load and the first slow_tick; kept out of is_open() so jobs don't
## briefly reopen to everyone before the assignees resolve.
var _pending_ids: Array[int] = []

signal assignment_changed

func ready_constructed() -> void:
	# Prune dead assignees and finish resolving any post-load pending ids.
	# Assignment is a rare, coarse state, so a slow_tick cadence is plenty.
	Global.time_manager.slow_tick.connect(_on_slow_tick)

func _on_slow_tick(_interval: float) -> void:
	_maybe_resolve()
	# Any id still pending after a live-world resolve is a pawn that's gone (died
	# / never loaded). Drop it, or an empty-but-pending workspace would stay
	# closed to everyone forever. slow_tick only fires once the world is live, so
	# this can't prematurely drop an id whose pawn hasn't loaded yet.
	if not _pending_ids.is_empty():
		_pending_ids.clear()
		assignment_changed.emit()
	_prune_invalid()

## Re-links saved pawn_ids (WI-23) to live pawns, on demand. Cheap no-op once
## resolved. Guarded on tree membership so unit-test components (never in a tree)
## and any call before pawns have loaded neither scan nor crash - they just leave
## the ids pending. Called from every query so a restored worker's can_do_job
## sees its assignment the same frame the roster is back, not a slow_tick later.
## Unlike the slow_tick sweep this never DROPS unresolved ids (the roster may
## still be loading); it only moves the ones it finds.
func _maybe_resolve() -> void:
	if _pending_ids.is_empty() or not is_inside_tree():
		return
	var changed: bool = false
	for node: Node in get_tree().get_nodes_in_group(Groups.PAWN):
		var pawn: PawnBase = node as PawnBase
		if pawn == null or pawn is MiningDronePawn:
			continue
		if _pending_ids.has(pawn.pawn_id):
			_pending_ids.erase(pawn.pawn_id)
			if not assigned.has(pawn):
				assigned.append(pawn)
				changed = true
	if changed:
		assignment_changed.emit()

func _prune_invalid() -> void:
	var changed: bool = false
	for i: int in range(assigned.size() - 1, -1, -1):
		var pawn: PawnBase = assigned[i]
		if pawn == null or not is_instance_valid(pawn) or pawn.is_queued_for_deletion():
			assigned.remove_at(i)
			changed = true
	if changed:
		assignment_changed.emit()

# --- queries ------------------------------------------------------------------

## No assignees (and none pending) - jobs are open to every pawn.
func is_open() -> bool:
	return assigned.is_empty() and _pending_ids.is_empty()

## Is `pawn` one of this workspace's assignees? Cheap - called from the job
## selection hot path (effective_priority_for).
func lists(pawn: PawnBase) -> bool:
	return pawn != null and assigned.has(pawn)

## May `pawn` take a job gated by this workspace? Open workspaces allow anyone;
## otherwise only assignees.
func allows(pawn: PawnBase) -> bool:
	return is_open() or lists(pawn)

func can_assign_more() -> bool:
	return max_workers <= 0 or assigned.size() < max_workers

func get_assigned() -> Array[PawnBase]:
	_prune_invalid()
	return assigned

# --- mutation (UI) ------------------------------------------------------------

func assign(pawn: PawnBase) -> bool:
	if pawn == null or assigned.has(pawn) or not can_assign_more():
		return false
	assigned.append(pawn)
	assignment_changed.emit()
	return true

func unassign(pawn: PawnBase) -> void:
	if assigned.has(pawn):
		assigned.erase(pawn)
		assignment_changed.emit()

func toggle(pawn: PawnBase) -> void:
	if assigned.has(pawn):
		unassign(pawn)
	else:
		assign(pawn)

# --- persistence (WI-23) ------------------------------------------------------

## Empty dict when nothing is assigned, so the module's save section stays lean
## for the common unassigned case.
## Assignments (WI-23) restore as pending pawn_ids and re-link to live pawns on
## the first slow_tick, once the roster has loaded - so nothing here depends on
## where in the chain it sits.
func save_order() -> int:
	return 30

func save_key() -> StringName:
	return &"workspace"

func get_save_data() -> Dictionary:
	var ids: Array = []
	for pawn: PawnBase in assigned:
		if is_instance_valid(pawn):
			ids.append(pawn.pawn_id)
	# Preserve still-unresolved ids too (a save taken right after a load).
	for id: int in _pending_ids:
		if not ids.has(id):
			ids.append(id)
	if ids.is_empty():
		return {}
	return {"assigned": ids}

func load_save_data(data: Dictionary) -> void:
	assigned.clear()
	_pending_ids.clear()
	for id_val: Variant in data.get("assigned", []):
		_pending_ids.append(int(id_val))

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var tab := WorkspaceTab.new()
	tab.setup(self)
	return tab
