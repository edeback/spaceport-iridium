extends GutTest

## Unit tests for WI-23 workspace assignment + affinity - the pure-logic surface
## that doesn't need a live world. WorkspaceComponent is constructed directly and
## never added to the tree (so ComponentBase/PawnBase _ready never runs and never
## touches Global/SignalBus); pawns are bare PawnBase nodes used only for identity
## and pawn_id. Anything that needs the roster/tree (pending-id resolution on
## slow_tick, the assignment UI, the manned-processor loop) is covered by the
## in-game verification steps in the WI, not here.

func _pawn(id: int) -> PawnBase:
	var pawn: PawnBase = autofree(PawnBase.new())
	pawn.pawn_id = id
	return pawn

func _workspace(max_workers: int = 1) -> WorkspaceComponent:
	var ws: WorkspaceComponent = autofree(WorkspaceComponent.new())
	ws.max_workers = max_workers
	return ws

# --- affinity constant sanity ------------------------------------------------

func test_affinity_bonus_is_within_band() -> void:
	# Must beat a fully-aged generic job (win ties + modest bands) but never
	# cross the ±99 routing bands construction/deconstruction rely on.
	assert_gt(JobPriorities.WORKSPACE_AFFINITY_BONUS, JobPriorities.AGE_BONUS_CAP,
		"affinity out-ranks the age cap so a fresh workspace job beats a starved generic one")
	assert_lt(JobPriorities.WORKSPACE_AFFINITY_BONUS, float(JobPriorities.COMPLETION_BOOST),
		"affinity stays below the completion-boost band")
	assert_lt(JobPriorities.WORKSPACE_AFFINITY_BONUS, float(JobPriorities.CONSTRUCTION_IMPORT),
		"affinity stays well below the construction routing band")

# --- open / assignment gating ------------------------------------------------

func test_new_workspace_is_open_to_everyone() -> void:
	var ws := _workspace()
	var a := _pawn(1)
	assert_true(ws.is_open(), "no assignees -> open")
	assert_true(ws.allows(a), "open workspace allows any pawn")
	assert_false(ws.lists(a), "open workspace lists nobody")

func test_assign_closes_to_assignees_only() -> void:
	var ws := _workspace()
	var a := _pawn(1)
	var b := _pawn(2)
	assert_true(ws.assign(a), "first assign succeeds")
	assert_false(ws.is_open(), "an assignment closes the workspace")
	assert_true(ws.lists(a), "assignee is listed")
	assert_true(ws.allows(a), "assignee is allowed")
	assert_false(ws.allows(b), "non-assignee is blocked once someone is assigned")

func test_max_workers_caps_assignment() -> void:
	var ws := _workspace(1)
	var a := _pawn(1)
	var b := _pawn(2)
	assert_true(ws.assign(a), "assign within cap")
	assert_false(ws.can_assign_more(), "cap reached at max_workers")
	assert_false(ws.assign(b), "assign past the cap is rejected")
	assert_false(ws.lists(b), "the rejected pawn is not listed")

func test_assigning_twice_is_idempotent() -> void:
	var ws := _workspace(2)
	var a := _pawn(1)
	assert_true(ws.assign(a), "first assign succeeds")
	assert_false(ws.assign(a), "re-assigning the same pawn is a no-op false")
	assert_eq(ws.get_assigned().size(), 1, "still just one assignee")

func test_unassign_reopens() -> void:
	var ws := _workspace()
	var a := _pawn(1)
	var b := _pawn(2)
	ws.assign(a)
	ws.unassign(a)
	assert_true(ws.is_open(), "removing the last assignee reopens the workspace")
	assert_true(ws.allows(b), "reopened workspace allows anyone again")

func test_toggle_flips_membership() -> void:
	var ws := _workspace(2)
	var a := _pawn(1)
	ws.toggle(a)
	assert_true(ws.lists(a), "toggle on assigns")
	ws.toggle(a)
	assert_false(ws.lists(a), "toggle off unassigns")

# --- save / load -------------------------------------------------------------

func test_empty_workspace_saves_nothing() -> void:
	assert_eq(_workspace().get_save_data(), {}, "no assignees -> empty save section")

func test_save_records_pawn_ids() -> void:
	var ws := _workspace(2)
	ws.assign(_pawn(7))
	ws.assign(_pawn(9))
	var data: Dictionary = ws.get_save_data()
	assert_true(data.has("assigned"), "save carries the assigned list")
	var ids: Array = data["assigned"]
	assert_eq(ids.size(), 2, "both ids saved")
	assert_true(ids.has(7) and ids.has(9), "the exact pawn_ids are saved")

func test_load_holds_ids_pending_and_stays_closed() -> void:
	# Module save data loads before pawns exist, so loaded ids are pending until
	# the first slow_tick resolves them; the workspace must stay closed meanwhile
	# (not briefly reopen to everyone) and not spuriously list an arbitrary pawn.
	var ws := _workspace()
	ws.load_save_data({"assigned": [7]})
	assert_false(ws.is_open(), "pending assignments keep the workspace closed")
	assert_false(ws.allows(_pawn(7)), "no live refs resolved yet -> allows nobody until slow_tick")

func test_load_round_trip_preserves_ids() -> void:
	var source := _workspace(2)
	source.assign(_pawn(3))
	source.assign(_pawn(5))
	var restored := _workspace(2)
	restored.load_save_data(source.get_save_data())
	# Re-serializing the pending ids (a save right after a load) round-trips them.
	var ids: Array = restored.get_save_data().get("assigned", [])
	assert_eq(ids.size(), 2, "both pending ids survive a save->load->save round trip")
	assert_true(ids.has(3) and ids.has(5), "the exact ids round-trip")

# --- Job.effective_priority_for affinity --------------------------------------

func test_no_workspace_matches_plain_priority() -> void:
	var job := Job.new()
	job.priority = 5
	var a := _pawn(1)
	assert_eq(job.effective_priority_for(a), job.effective_priority(),
		"a job with no workspace uses the plain effective priority for every pawn")

func test_assignee_gets_affinity_bonus() -> void:
	var ws := _workspace()
	var a := _pawn(1)
	var b := _pawn(2)
	ws.assign(a)
	var job := Job.new()
	job.workspace = ws
	assert_almost_eq(job.effective_priority_for(a),
		job.effective_priority() + JobPriorities.WORKSPACE_AFFINITY_BONUS, 0.001,
		"the assignee gets the affinity bonus")
	assert_almost_eq(job.effective_priority_for(b), job.effective_priority(), 0.001,
		"a non-assignee gets no bonus")

func test_open_workspace_gives_no_affinity() -> void:
	# An empty (open) workspace lists nobody, so no pawn gets the bonus.
	var job := Job.new()
	job.workspace = _workspace()
	var a := _pawn(1)
	assert_almost_eq(job.effective_priority_for(a), job.effective_priority(), 0.001,
		"an open workspace confers no affinity on anyone")
