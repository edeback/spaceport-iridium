extends GutTest

## WI-73 on a running station.
##
## The unit suites pin what can be pinned without a tree: the section table's
## pairs, the manager order in main.tscn, the keys each pawn kind writes. What they
## cannot show is the other half of each - that the sections a booted game actually
## registers are the table's, and that a pawn kind's LOAD hook puts it back where
## it was: a drone flying for its own bay again, a hauler on its bay's roster, a
## guest partway through its stay. The real quicksave has drones and no hauler or
## guest, so all three are made here.

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

# --- the table is what registers ----------------------------------------------------

## Every section a booted game registers is in the table, at the table's number,
## and every row of the table is registered by somebody. A registrant that went
## back to its own literal, or a row nobody reads any more, fails here.
func test_the_booted_game_registers_exactly_the_table() -> void:
	var registered: Dictionary[StringName, int] = {}
	for section: SaveSection in SaveManager.sections_in_order():
		registered[section.id] = section.order
	for id: StringName in SaveManager.SECTION_ORDER:
		assert_true(registered.has(id), "%s is registered" % id)
		assert_eq(registered.get(id, -1), SaveManager.SECTION_ORDER[id], "%s sits at its table number" % id)
	for id: StringName in registered:
		assert_true(SaveManager.SECTION_ORDER.has(id), "%s is in the table" % id)

# --- pawn kinds round-trip ------------------------------------------------------------

func test_drones_a_hauler_and_a_guest_survive_two_reloads() -> void:
	assert_true(await _populate(), "a station with drones, a hauler and a guest")
	var before: Dictionary = _kinds()
	assert_gt((before["drones"] as Dictionary).size(), 0, "there are drones to restore")
	assert_eq((before["haulers"] as Dictionary).size(), 1, "there is a hauler to restore")
	assert_eq((before["guests"] as Dictionary).size(), 1, "there is a guest to restore")

	assert_true(await fx.save_and_reload())
	assert_eq(_kinds(), before, "every kind is back with its own fields")
	assert_true(fx.save())
	var first_after_load: Dictionary = fx.read_save()
	assert_true(await fx.save_and_reload())
	assert_true(fx.save())
	var second_after_load: Dictionary = fx.read_save()
	assert_eq(StationFixture.diff(first_after_load["sections"], second_after_load["sections"]),
		PackedStringArray(), "post-load saves are identical with every pawn kind aboard")
	assert_true(fx.check_invariants("after two reloads with robots and a guest"))
	assert_true(await fx.tick(5.0), "and the reloaded station runs")

## Each restored robot is back on its bay's roster, not just pointing at the bay:
## the bay is what powers, re-stats and tears a robot down, and a robot it does not
## know about is one it can never replace.
func test_restored_robots_are_on_their_bays_rosters() -> void:
	assert_true(await _populate())
	assert_true(await fx.save_and_reload())
	var drones: int = 0
	var haulers: int = 0
	for pawn: PawnBase in fx.pawns():
		var drone: MiningDronePawn = pawn as MiningDronePawn
		if drone != null:
			drones += 1
			assert_not_null(drone.parent_mining_component, "%s has its bay back" % drone.pawn_name)
			if drone.parent_mining_component != null:
				assert_true(drone.parent_mining_component.drones.has(drone),
					"%s is on its bay's roster" % drone.pawn_name)
		var hauler: HaulerRobotPawn = pawn as HaulerRobotPawn
		if hauler != null:
			haulers += 1
			assert_not_null(hauler.parent_bay, "%s has its bay back" % hauler.pawn_name)
			if hauler.parent_bay != null:
				assert_true(hauler.parent_bay.robots.has(hauler), "%s is on its bay's roster" % hauler.pawn_name)
	assert_gt(drones, 0)
	assert_eq(haulers, 1)

## The ARC inspector is the one kind that says no, and says it on its own class.
func test_the_inspector_is_not_in_the_save() -> void:
	var inspector: InspectorPawn = (load("res://pawns/inspector_pawn.tscn") as PackedScene).instantiate() as InspectorPawn
	Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.SPACE).add_child(inspector)
	inspector.current_module = _home()
	assert_true(fx.save())
	for entry: Dictionary in fx.read_save()["sections"]["pawns"]:
		assert_ne(String(entry.get("scene", "")), inspector.scene_file_path, "no inspector entry")
	inspector.queue_free()

# --- helpers ----------------------------------------------------------------------------

func _home() -> ModuleBase:
	return Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, Vector2i(15, 8))

## The production line (which has a mining bay), a logistics bay beside it with one
## hauler bought, and a guest with a known stay - then a few seconds of sim, so the
## drones are out flying rather than parked where they were built.
func _populate() -> bool:
	fx.build_production_line()
	var logistics: ModuleBase = fx.place(&"logistics_bay_mdata", Vector2i(4, 9))
	fx.corridor(9, 4, 6)
	if logistics == null:
		return false
	var bay: LogisticsBayComponent = logistics.get_component_by_type(LogisticsBayComponent) as LogisticsBayComponent
	Global.cheats.add_credits(1000)
	assert_true(bay != null and bay.buy_robot(), "the logistics bay sells a hauler")
	var guest: VisitorPawn = Global.visitor_manager.spawn_visitor_at(_home(), 120, 30.0)
	assert_not_null(guest, "a guest arrives")
	if guest != null:
		guest._departure_reported = true
	return await fx.tick_until(_drones_are_out, 30.0)

func _drones_are_out() -> bool:
	for pawn: PawnBase in fx.pawns():
		if pawn is MiningDronePawn and pawn.current_module == null:
			return true
	return false

## What each kind's hooks carry, keyed by name so a reorder of the pawn list can't
## make two equal stations compare unequal: name -> the fields that kind saves for
## itself.
func _kinds() -> Dictionary:
	var drones: Dictionary = {}
	var haulers: Dictionary = {}
	var guests: Dictionary = {}
	for pawn: PawnBase in fx.pawns():
		var drone: MiningDronePawn = pawn as MiningDronePawn
		if drone != null:
			drones[drone.pawn_name] = [drone.robot_index, SaveRefs.component_ref(drone.parent_mining_component)]
		var hauler: HaulerRobotPawn = pawn as HaulerRobotPawn
		if hauler != null:
			haulers[hauler.pawn_name] = [hauler.robot_index, SaveRefs.component_ref(hauler.parent_bay)]
		var guest: VisitorPawn = pawn as VisitorPawn
		if guest != null:
			guests[guest.pawn_name] = [snappedf(guest.stay_hours_remaining, 0.001), guest._leaving,
				guest._departure_reported]
	return {"drones": drones, "haulers": haulers, "guests": guests}
