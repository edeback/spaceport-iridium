extends GutTest

## WI-71's four fixes that only a live station can exercise:
##
## - **F28:** a module freed while a pawn is suspended inside its door hook left
##   `_busy_in_hook` latched, so `is_traveling()` answered true for the rest of
##   that pawn's life - the roster sentence and the robot moving-drain both read
##   it. Movement itself always recovered, which is why nothing visibly stuck.
##   WI-75 took the hook's await out, and the latch with it: a pawn at a door is
##   in the movement component's Waiting state now, so the two F28 tests drive a
##   real crew member to a real airlock door instead of poking at the latch.
## - **F27a:** a module's breach / low-O2 / breakdown / cut-vertex rows were
##   resolved on `module_destroyed` only. **Deconstruction** ends in
##   `remove_module(module, false)` with no `module_destroyed`, so a deconstructed
##   module left its rows in the feed with a freed subject: JUMP went nowhere and
##   an unacknowledged HIGH stayed until CLEAR ALL.
## - **F27b:** a departing crew member's `need_*`, `suit_up` and `disease_*` rows
##   did the same - `_on_crew_departed` resolved only `resigning`.
## - **F29:** every manager left its [Global] slot pointing at a freed node after
##   a Quit to Menu. Harmless in Godot 4.7, where a freed object compares equal to
##   null, but `is_instance_valid(Global.x)` and the debugger both lied.

## Every [Global] slot a node in `main.tscn` registers itself into, which §7 makes
## live-or-null rather than live-or-freed. `cheats`, `tilemap`, `settings` and the
## staging fields are not here: they are assigned by their owner rather than
## self-registered, and `settings` deliberately outlives the scene.
const REGISTERED_SLOTS: PackedStringArray = ["time_manager", "save_manager",
	"world_manager", "path_manager", "structure_manager", "adjacency_manager",
	"heat_manager", "power_manager", "job_manager", "claim_registry",
	"turbolift_manager", "resource_manager", "market_manager", "economy_manager",
	"asteroid_manager", "unlock_manager", "crew_manager", "trader_manager",
	"event_manager", "dialogue_runner", "tutorial_manager", "story_state",
	"contract_manager", "raid_manager", "visitor_manager", "atmosphere_manager",
	"alert_manager", "ui_in_game", "ui_main", "stellar_background"]

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)

func after_each() -> void:
	await fx.finish()

# --- F28: a module freed while a pawn waits at its door -------------------------

## Sends the first crew member out through the starting airlock to a pile in open
## space, and returns once they are standing at one of its doors (WI-75's Waiting
## state). Null if they never got there.
func _pawn_waiting_at_the_airlock() -> PawnBase:
	var pawn: PawnBase = fx.pawns()[0]
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.SPACE)
	var pile := ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(24, 9), true))
	pile.add_amount(fx.resource(&"iron_ore"), 1)
	pawn.interrupt_with_job(Job.of(&"move_to_location").with_target_a(JobTarget.of_pile(pile)))
	var waiting: bool = await fx.tick_until(func() -> bool:
		return pawn.movement_component.state == PawnMovementComponent.State.Waiting,
		30.0, 1.0 / 60.0, 1.0)
	return pawn if waiting else null

## A door wait that outlived its module was F28's coroutine: it never resumed, and
## the latch it set said "travelling" for good. Now the wait is a state, and
## removing the module under it re-plans on the next frame - including when the
## module is the one the pawn is standing in.
func test_a_module_freed_while_a_pawn_waits_at_its_door_releases_the_pawn() -> void:
	assert_true(await fx.boot())
	var pawn: PawnBase = await _pawn_waiting_at_the_airlock()
	assert_not_null(pawn, "a crew member stops at the airlock's door")
	if pawn == null:
		return
	var movement: PawnMovementComponent = pawn.movement_component
	var airlock: ModuleBase = pawn.current_module
	assert_true(airlock != null and airlock.is_in_group(Groups.AIRLOCK), "standing in the airlock")
	if airlock == null:
		return
	assert_true(movement.is_traveling(), "and waiting at a door counts as travelling")

	assert_true(Global.world_manager.remove_module(airlock, false),
		"the airlock is destroyed under the pawn")
	assert_true(await fx.tick(0.1, 1.0), "a moment on")
	assert_ne(movement.state, PawnMovementComponent.State.Waiting,
		"the wait ended with the module - a suspended hook would never have resumed")
	assert_true(await fx.tick(TimeManager.SECONDS_PER_HOUR), "and an hour of play is clean")
	assert_ne(movement.state, PawnMovementComponent.State.Waiting,
		"nobody is left waiting at a door that is gone")
	assert_eq(movement.is_traveling(), movement.state != PawnMovementComponent.State.Idle,
		"is_traveling() is a pure read of the movement state")

## The other half: a module removed while a pawn waits at a *different* module's
## door must leave the wait alone, or a busy station would unstick every pawn at
## every airlock whenever anything was demolished.
func test_removing_another_module_leaves_the_wait_alone() -> void:
	assert_true(await fx.boot())
	var other: ModuleBase = fx.place(&"hallway_mdata", Vector2i(42, 20))
	var pawn: PawnBase = await _pawn_waiting_at_the_airlock()
	assert_not_null(pawn, "a crew member stops at the airlock's door")
	if pawn == null:
		return
	var movement: PawnMovementComponent = pawn.movement_component
	var left: float = movement._wait_left
	assert_true(Global.world_manager.remove_module(other, false))
	assert_eq(movement.state, PawnMovementComponent.State.Waiting, "still waiting at the airlock")
	assert_almost_eq(movement._wait_left, left, 0.0001, "with the same time left")
	assert_true(await fx.tick(1.0 / 60.0, 1.0))
	assert_eq(movement.state, PawnMovementComponent.State.Waiting, "and the next frame too")

# --- F27: alerts about things that are gone -------------------------------------

func test_a_deconstructed_module_takes_its_breakdown_row_with_it() -> void:
	assert_true(await fx.boot())
	var alerts: AlertManager = Global.alert_manager
	var module: ModuleBase = fx.place(&"small_storage", Vector2i(30, 4))
	module._trigger_breakdown()
	var id: StringName = AlertRules.make_id(&"breakdown", module)
	assert_true(_has_live(id), "the breakdown is in the feed")
	assert_true(_in_history(id), "and in the log")

	# remove_module(_, false) is the deconstruction path, and emits no
	# module_destroyed at all - which is the whole of F27.
	assert_true(Global.world_manager.remove_module(module, false), "deconstructed")
	assert_false(_has_live(id), "the row goes with the module")
	assert_true(_in_history(id), "and the log still has it")
	assert_eq(alerts.outstanding_count(), 0, "nothing outstanding is left about it")

func test_the_sweep_drops_a_row_whose_subject_was_freed_without_a_signal() -> void:
	assert_true(await fx.boot())
	var alerts: AlertManager = Global.alert_manager
	# A subject with no removal signal of its own: a free-floating pile.
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.SPACE)
	var pile := ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(34, 4), true))
	pile.add_amount(fx.resource(&"iron_ore"), 3)
	var id: StringName = AlertRules.make_id(&"cheat_alert", pile)
	AlertManager.raise_alert(id, AlertData.Priority.HIGH, "About a pile", "", pile)
	assert_true(_has_live(id), "raised")
	pile.queue_free()
	await wait_physics_frames(2)
	alerts.sweep()
	assert_false(_has_live(id), "the sweep drops a row whose subject is gone")
	assert_true(_in_history(id), "history keeps the record, as it does for any resolve")

func test_a_departing_crew_member_takes_a_critical_need_row_with_them() -> void:
	assert_true(await fx.boot())
	var crew: CrewManager = Global.crew_manager
	var pawn: PawnBase = crew.get_crew()[0]
	# Both ids are built while the pawn is alive: make_id falls back to the bare
	# family name for a freed subject, so asking after the departure would ask
	# about a different row entirely.
	var need_id: StringName = AlertRules.make_id(&"need_hunger", pawn)
	var departed_id: StringName = AlertRules.make_id(&"departed", pawn)
	SignalBus.pawn_critical_need.emit(pawn, &"hunger")
	assert_true(_has_live(need_id), "the need is in the feed")

	# The real departure: fire posts a leave_station job, the pawn walks to the
	# crew gateway and Action_Depart emits crew_departed before freeing them.
	var before: int = crew.crew_count()
	Global.economy_manager.fire_pawn(pawn)
	var gone: bool = await fx.tick_until(func() -> bool: return crew.crew_count() < before,
		8.0 * TimeManager.SECONDS_PER_HOUR, 1.0)
	assert_true(gone, "the crew member leaves the station")
	assert_false(_has_live(need_id), "their critical need goes with them")
	assert_true(_has_live(departed_id),
		"the departure notice itself survives - it is news, not a condition")

# --- F29: Global slots ----------------------------------------------------------

func test_every_manager_hands_its_global_slot_back() -> void:
	assert_true(await fx.boot())
	for slot: String in REGISTERED_SLOTS:
		assert_true(is_instance_valid(Global.get(slot)), "%s is live while the game runs" % slot)
	await fx.teardown()
	for slot: String in REGISTERED_SLOTS:
		var held: Variant = Global.get(slot)
		assert_null(held, "%s is null after a Quit to Menu, not a freed node" % slot)
	assert_true(await fx.boot(), "and a new game boots on top of it")
	for slot: String in REGISTERED_SLOTS:
		assert_true(is_instance_valid(Global.get(slot)), "%s is live again" % slot)

# --- helpers --------------------------------------------------------------------

func _has_live(id: StringName) -> bool:
	for alert: AlertData in Global.alert_manager.live():
		if alert.id == id:
			return true
	return false

func _in_history(id: StringName) -> bool:
	for alert: AlertData in Global.alert_manager.history():
		if alert.id == id:
			return true
	return false
