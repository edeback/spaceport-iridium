extends GutTest

## A new game, booted the way the main menu's New Game boots it (WI-69 §4).
## Every other integration suite starts from this station, so this is the one
## that says what it is.

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

func test_the_starting_station_is_placed() -> void:
	var world: WorldManager = Global.world_manager
	for expected: ModuleData in [world.start_module, world.docking_bay, world.hallway_module, world.module_airlock]:
		var found: bool = false
		for module: ModuleBase in fx.modules():
			found = found or (module.module_data == expected and module.is_complete())
		assert_true(found, "a built %s" % expected.id)

func test_two_crew_arrive() -> void:
	assert_eq(Global.crew_manager.crew_count(), 2)

func test_nothing_holds_the_sim() -> void:
	var time: TimeManager = Global.time_manager
	assert_false(time.is_paused(), StationFixture.describe_pause(time))
	assert_eq(time.pause_holders().size(), 0)

func test_the_quiet_defaults_are_in_force() -> void:
	assert_eq(Global.difficulty_id(), &"peaceful")
	assert_false(Global.difficulty_raids_enabled())
	assert_eq(Global.event_manager.expected_cycles_between_events, 0.0)
	assert_false(Global.alert_manager.pause_on_critical)
	assert_true(Global.tutorial_manager.ledger.onboarding_done, "skipping records the onboarding as done")
	assert_eq(Global.tutorial_manager.unseen_count(), 0, "and spends every hint")

func test_an_hour_of_play_leaves_the_station_clean() -> void:
	assert_true(await fx.tick(TimeManager.SECONDS_PER_HOUR))
	assert_eq(fx.invariants(), PackedStringArray(), "invariants after one sim-hour")
	assert_eq(Global.crew_manager.crew_count(), 2)

func test_saves_go_to_the_fixture_directory() -> void:
	assert_eq(SaveManager.save_dir(), StationFixture.SAVE_DIR)
	assert_true(fx.save())
	assert_true(FileAccess.file_exists(StationFixture.SAVE_DIR + StationFixture.SLOT + ".json"))
	assert_false(FileAccess.file_exists(SaveManager.SAVE_DIR + StationFixture.SLOT + ".json"),
		"nothing lands in the player's saves")
