extends GutTest

## Unit tests for the save blocks added or widened by WI-45 (the D8 audit sweep):
## storage priority (A4), the processor's batch + queued recipe (A2), and the two
## power components' manual shutdown / partial fuel burn (A3).
##
## Every component is constructed bare - never added to a tree, no owner_module -
## so nothing here touches Global or SignalBus. That constraint is the point:
## it's what keeps these load paths free of tree lookups on the branches the
## tests take, the same discipline test_battery_persistence enforces.
##
## Not covered here, and deliberately: A1 (TurboliftManager's cab count) and A6
## (mining priority ore) both resolve through Global on load and are guard
## placement rather than pure rules - they're verified in-engine instead.

# --- A4: storage priority ------------------------------------------------------

var storage: StorageComponent

func before_each() -> void:
	storage = autofree(StorageComponent.new())
	storage.priority = 1

func test_priority_round_trips() -> void:
	storage.update_priority(-20)
	var data: Dictionary = storage.get_save_data()
	storage.update_priority(1) # what the scene's ready pass would leave behind
	storage.load_save_data(data)
	assert_eq(storage.priority, -20, "a hand-tuned bin reloads at the priority the player set")

func test_priority_survives_the_full_band() -> void:
	# The spinbox range is -100..100 and the routing bands live at +-99.
	for value: int in [-100, -99, 0, 99, 100]:
		storage.update_priority(value)
		var fresh: StorageComponent = autofree(StorageComponent.new())
		fresh.load_save_data(storage.get_save_data())
		assert_eq(fresh.priority, value, "priority %d round-trips" % value)

func test_save_nests_the_resource_map() -> void:
	var data: Dictionary = storage.get_save_data()
	assert_true(data.has("resources"), "the resource map moved under its own key")
	assert_true(data.has("priority"), "and the component-level field sits beside it")

func test_legacy_flat_block_still_loads() -> void:
	# Pre-WI-45 shape: the dict IS the resource map, with no "resources" key and
	# no priority. It must load without error and leave priority alone rather
	# than treating a resource entry as a component field.
	storage.update_priority(7)
	storage.load_save_data({})
	assert_eq(storage.priority, 7, "a legacy block leaves the scene-authored priority in place")

func test_absent_priority_key_is_not_a_reset() -> void:
	storage.update_priority(-5)
	storage.load_save_data({"resources": {}})
	assert_eq(storage.priority, -5, "a block without the key is a no-op, not a wipe to the default")

# --- A2: processor batch + queued recipe ---------------------------------------

## Two recipes so can_select_recipes() is true; contents don't matter here, only
## identity and membership of available_recipes.
func _processor(requires_worker: bool) -> ProcessorComponent:
	var processor: ProcessorComponent = autofree(ProcessorComponent.new())
	processor.requires_worker = requires_worker
	processor.time_to_process = 10.0
	return processor

func test_unmanned_batch_round_trips() -> void:
	# The regression this WI exists for: an unmanned processor withdraws its
	# inputs up front, so dropping `processing` on load destroys them.
	var processor: ProcessorComponent = _processor(false)
	processor.processing = true
	processor.current_process_time = 4.0
	processor.current_batch_richness = 0.8
	var data: Dictionary = processor.get_save_data()
	assert_true(data.get("processing", false), "an unmanned batch is saved, not silently dropped")

	var restored: ProcessorComponent = _processor(false)
	restored.load_save_data(data)
	assert_true(restored.processing, "and comes back mid-batch")
	assert_almost_eq(restored.current_process_time, 4.0, 0.001, "at the progress it had")
	assert_almost_eq(restored.current_batch_richness, 0.8, 0.001, "with the batch's richness intact")

func test_manned_batch_still_round_trips() -> void:
	# WI-23's path must not regress now that the gate is gone.
	var processor: ProcessorComponent = _processor(true)
	processor.processing = true
	processor.current_process_time = 2.5
	processor.current_batch_richness = -1.0
	var restored: ProcessorComponent = _processor(true)
	restored.load_save_data(processor.get_save_data())
	assert_true(restored.processing, "a manned batch resumes")
	assert_almost_eq(restored.current_process_time, 2.5, 0.001, "at its saved progress")
	assert_almost_eq(restored.current_batch_richness, -1.0, 0.001, "and a no-variance batch stays at the -1 sentinel")

func test_idle_processor_saves_no_batch() -> void:
	var processor: ProcessorComponent = _processor(false)
	processor.processing = false
	assert_false(processor.get_save_data().has("processing"), "an idle machine adds nothing to the save")

func test_yield_residue_is_saved() -> void:
	# Sub-1-unit carry-over is still output the player's inputs paid for, and a
	# save/load is not them choosing to discard it.
	var processor: ProcessorComponent = _processor(false)
	var steel: ResourceData = autofree(ResourceData.new())
	steel.id = &"steel"
	processor._yield_residue[steel] = 0.7
	var data: Dictionary = processor.get_save_data()
	assert_true(data.has("yield_residue"), "residue reaches the save block")
	assert_almost_eq(float(data["yield_residue"]["steel"]), 0.7, 0.001, "at its exact fractional value")

func test_zero_and_idless_residue_are_not_written() -> void:
	var processor: ProcessorComponent = _processor(false)
	var spent: ResourceData = autofree(ResourceData.new())
	spent.id = &"steel"
	processor._yield_residue[spent] = 0.0
	var anonymous: ResourceData = autofree(ResourceData.new())
	anonymous.id = &""
	processor._yield_residue[anonymous] = 0.4
	assert_false(processor.get_save_data().has("yield_residue"),
		"a fully-consumed entry and an unsaveable resource both stay out of the save")

func test_residue_is_untouched_by_an_empty_block() -> void:
	var processor: ProcessorComponent = _processor(false)
	var steel: ResourceData = autofree(ResourceData.new())
	steel.id = &"steel"
	processor._yield_residue[steel] = 0.3
	processor.load_save_data({})
	assert_almost_eq(processor._yield_residue[steel], 0.3, 0.001,
		"an absent key is a no-op, not a wipe")

func test_batch_state_is_untouched_by_an_empty_block() -> void:
	var processor: ProcessorComponent = _processor(false)
	processor.processing = true
	processor.current_process_time = 3.0
	processor.load_save_data({})
	assert_true(processor.processing, "an absent key is a no-op, not a cancel")
	assert_almost_eq(processor.current_process_time, 3.0, 0.001, "progress is left alone too")

# --- A3: power consumption -----------------------------------------------------

func test_force_off_round_trips() -> void:
	var consumer: PowerConsumptionComponent = autofree(PowerConsumptionComponent.new())
	consumer.force_off = true
	var restored: PowerConsumptionComponent = autofree(PowerConsumptionComponent.new())
	restored.load_save_data(consumer.get_save_data())
	assert_true(restored.force_off, "a deliberately shut-down module stays shut down across a load")

func test_running_consumer_saves_nothing() -> void:
	var consumer: PowerConsumptionComponent = autofree(PowerConsumptionComponent.new())
	consumer.force_off = false
	assert_true(consumer.get_save_data().is_empty(), "pristine means no key, so untouched stations stay compact")

func test_consumer_load_clears_a_stale_flag() -> void:
	var consumer: PowerConsumptionComponent = autofree(PowerConsumptionComponent.new())
	consumer.force_off = true
	consumer.load_save_data({})
	assert_false(consumer.force_off, "an empty block means the module was running when it was saved")

# --- A3: power generation ------------------------------------------------------

func _generator(fuelled: bool) -> PowerGenerationComponent:
	var generator: PowerGenerationComponent = autofree(PowerGenerationComponent.new())
	generator.seconds_per_resource_consumed = 60.0 if fuelled else 0.0
	return generator

func test_generator_force_off_round_trips() -> void:
	var generator: PowerGenerationComponent = _generator(true)
	generator.disable_generation(true)
	var restored: PowerGenerationComponent = _generator(true)
	restored.load_save_data(generator.get_save_data())
	assert_true(restored.force_off, "a shut-down reactor stays shut down")
	assert_false(restored.powered, "and reports itself as producing nothing")

func test_partial_fuel_burn_round_trips() -> void:
	var generator: PowerGenerationComponent = _generator(true)
	generator._fuel_seconds_left = 25.0
	var restored: PowerGenerationComponent = _generator(true)
	restored.load_save_data(generator.get_save_data())
	assert_almost_eq(restored._fuel_seconds_left, 25.0, 0.001, "the unit already paid for keeps burning")

func test_restored_fuel_comes_back_powered() -> void:
	# The deadlock guard: restart_generation() only powers up on the tick it has
	# to withdraw a FRESH unit, and generate_power() only burns while powered - so
	# a half-burnt generator restored with powered false would sit dark forever.
	var generator: PowerGenerationComponent = _generator(true)
	generator.load_save_data({"fuel_seconds": 25.0})
	assert_true(generator.powered, "a generator restored mid-burn resumes producing")

func test_force_off_wins_over_restored_fuel() -> void:
	var generator: PowerGenerationComponent = _generator(true)
	generator.load_save_data({"force_off": true, "fuel_seconds": 25.0})
	assert_true(generator.force_off, "the manual switch is restored")
	assert_false(generator.powered, "and beats the fuel still in the hopper")

func test_negative_fuel_floors_at_empty() -> void:
	var generator: PowerGenerationComponent = _generator(true)
	generator.load_save_data({"fuel_seconds": -10.0})
	assert_almost_eq(generator._fuel_seconds_left, 0.0, 0.001, "a corrupt burn time floors at empty")

func test_idle_generator_saves_nothing() -> void:
	var generator: PowerGenerationComponent = _generator(false)
	assert_true(generator.get_save_data().is_empty(), "a running solar panel adds no keys")

# --- WI-68 F10: the chat log re-types on load --------------------------------------

func test_the_chat_log_comes_back_with_its_types() -> void:
	# Through real JSON, as a save does: every number comes back a float. The log
	# must re-type on load, or `with` (a pawn_id) stops matching int-keyed lookups.
	var saved: Dictionary = {"recent": [{
		"with": 6, "name": "Erla Hadley", "positive": true, "delta": 0.05, "cycle": 15, "hour": 22,
	}]}
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(saved)) as Dictionary
	var social: SocializeComponent = autofree(SocializeComponent.new())
	social.load_save_data(parsed)
	var chats: Array[Dictionary] = social.recent_chats()
	assert_eq(chats.size(), 1, "the one logged chat is restored")
	if chats.size() != 1:
		return
	var chat: Dictionary = chats[0]
	assert_eq(typeof(chat["with"]), TYPE_INT, "with is a pawn_id - an int, not the float JSON handed back")
	assert_eq(typeof(chat["cycle"]), TYPE_INT, "cycle is an int")
	assert_eq(typeof(chat["hour"]), TYPE_INT, "hour is an int")
	assert_eq(chat["with"], 6)
	assert_eq(chat["name"], "Erla Hadley")
	assert_true(chat["positive"])
	assert_almost_eq(float(chat["delta"]), 0.05, 0.0001)

func test_a_malformed_chat_entry_is_skipped() -> void:
	var social: SocializeComponent = autofree(SocializeComponent.new())
	social.load_save_data({"recent": ["not a chat", {"with": 2, "cycle": 1, "hour": 3}]})
	assert_eq(social.recent_chats().size(), 1, "the bad entry is dropped, the good one kept")

# --- WI-68 F13: asteroid spin saves idempotently -----------------------------------

func test_saved_asteroid_rotation_is_one_turn() -> void:
	for degrees: float in [0.0, 359.9996, 360.0, 3457.6199, -45.25, 1000000.123]:
		var saved: float = AsteroidBase.saved_rotation_of(degrees)
		assert_true(saved >= 0.0 and saved < 360.0, "%f saves inside one turn, got %f" % [degrees, saved])

func test_saved_asteroid_rotation_survives_a_load_and_resave() -> void:
	# The load writes rotation_degrees onto a real node, which stores float32
	# radians - the exact path that used to lose a bit on every round trip.
	var node: Node2D = autofree(Node2D.new())
	for degrees: float in [0.3, 217.6, 3457.61987304688, 1759.90686035156, 359.9994, 12.345678]:
		var first: float = AsteroidBase.saved_rotation_of(degrees)
		node.rotation_degrees = first
		assert_eq(AsteroidBase.saved_rotation_of(node.rotation_degrees), first,
			"%f saves, loads and saves back unchanged" % degrees)
