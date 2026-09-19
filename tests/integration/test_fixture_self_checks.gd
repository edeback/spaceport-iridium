extends GutTest

## The fixture proves it fails when it should (WI-69 §3), before any real test
## trusts it. Each check plants the fault and asserts it was caught, so the suite
## stays green while pinning that the net has no hole in it.
##
## A fixture that cannot fail is worse than no fixture: it turns "nothing was
## measured" into a pass. The F38 probe's first run did exactly that.

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

## A runtime script error raised by the engine, in a node the sim is ticking, not
## a `push_error`. GUT's tracker has to see it for the test to fail; if it ever
## stops doing so, the fixture's own logger is the fallback and this is where
## that shows up.
func test_a_script_error_in_a_ticked_node_fails_the_test() -> void:
	var planted := NullCaller.new()
	fx.scene.add_child(planted)
	await fx.tick(0.25)
	# free(), not queue_free(): a queued node still gets this frame's _process,
	# which runs after the body returns - and the fixture rightly reports that
	# one as an error outside the test.
	planted.free()
	var tracker: GutErrorTracker = GutUtils.get_error_tracker() as GutErrorTracker
	var caught: int = 0
	for error: GutTrackedError in get_errors():
		# Godot 4.7 words it "Cannot call method 'get_name' on a null value".
		if error.is_engine_error() and error.contains_text("get_name"):
			caught += 1
	assert_gt(caught, 0, "the planted call on null reached GUT's error tracker")
	assert_true(tracker.should_test_fail_from_errors(), "and would fail the test")
	# Handled only now: the assertions above are the point of the test.
	for error: GutTrackedError in get_errors():
		error.handled = true

func test_the_error_log_knows_it_is_inside_a_test_body() -> void:
	assert_true(StationFixture.ErrorLog.in_test_body(),
		"the fixture's logger reads GUT's current-test id; a GUT upgrade that renames it breaks the out-of-body path")

func test_a_broken_reservation_is_named() -> void:
	var target: StorageComponent = null
	var target_resource: ResourceData = null
	for storage: StorageComponent in fx.storages():
		if not storage.storage_data.is_empty():
			target = storage
			target_resource = storage.storage_data.keys()[0]
			break
	assert_not_null(target, "the starting station has a stocked bin to corrupt")
	if target == null:
		return
	assert_eq(fx.invariants().size(), 0, "clean before the plant")
	var data: StorageData = target.storage_data[target_resource]
	data.reserved_deposit += 1
	var problems: PackedStringArray = fx.invariants()
	data.reserved_deposit -= 1
	assert_eq(problems.size(), 1, "exactly the planted reservation is reported")
	if problems.size() == 1:
		assert_string_contains(problems[0], StationFixture.describe_storage(target))
		assert_string_contains(problems[0], String(target_resource.id))
		assert_string_contains(problems[0], "reserved_deposit")

func test_an_overfilled_input_slot_is_named() -> void:
	var bin: ModuleBase = fx.place(&"large_storage", Vector2i(40, 2), false)
	await fx.tick(0.1)
	var site: StorageComponent = (bin.get_component_by_type(ConstructionComponent) as ConstructionComponent).material_storage
	var slot_resource: ResourceData = site.storage_data.keys()[0]
	var slot: StorageData = site.storage_data[slot_resource]
	assert_eq(slot.role, StorageData.Role.INPUT, "a blueprint's material bin is INPUT")
	slot.stored = slot.desired + 1
	var problems: PackedStringArray = fx.invariants()
	slot.stored = 0
	var named: bool = false
	for problem: String in problems:
		named = named or (problem.contains("INPUT slot") and problem.contains(String(slot_resource.id)))
	assert_true(named, "an INPUT slot over its cap is reported: %s" % [problems])

func test_a_pause_hold_fails_tick_and_names_the_holder() -> void:
	var failures: PackedStringArray = []
	fx.on_failure = func(message: String) -> void: failures.append(message)
	Global.time_manager.hold_pause(&"fixture_self_check")
	var ran: bool = await fx.tick(1.0)
	Global.time_manager.release_pause(&"fixture_self_check")
	fx.on_failure = fail_test
	assert_false(ran, "tick stops on a held sim")
	assert_eq(failures.size(), 1, "and reports it once")
	if failures.size() == 1:
		assert_string_contains(failures[0], "fixture_self_check")

func test_the_players_pause_fails_tick_too() -> void:
	var failures: PackedStringArray = []
	fx.on_failure = func(message: String) -> void: failures.append(message)
	Global.time_manager.paused = true
	var ran: bool = await fx.tick(1.0)
	Global.time_manager.paused = false
	fx.on_failure = fail_test
	assert_false(ran)
	assert_eq(failures.size(), 1)
	if failures.size() == 1:
		assert_string_contains(failures[0], "player's pause flag")

## A pawn that stops noticing its job ended. Planted by switching the pawn's own
## processing off, which is the only thing that clears an ended `current_job`.
func test_a_stranded_job_is_named() -> void:
	var crew: Array[PawnBase] = fx.pawns()
	assert_gt(crew.size(), 0)
	if crew.is_empty():
		return
	var pawn: PawnBase = crew[0]
	pawn.set_process(false)
	var ended: Job = Job.of(&"wait")
	var previous: Job = pawn.current_job
	pawn.current_job = ended
	ended.cancel(true)
	await fx.tick(0.25)
	var problems: PackedStringArray = fx.invariants()
	pawn.current_job = previous
	pawn.set_process(true)
	var named: bool = false
	for problem: String in problems:
		named = named or (problem.contains(pawn.pawn_name) and problem.contains("ended wait job"))
	assert_true(named, "the pawn holding an ended job for two frames is reported: %s" % [problems])
	fx._stranded.clear()

## An error raised where GUT has no test to pin it on - here `before_each`, the
## same window a boot or a teardown runs in - is recorded by the fixture, which
## is what makes `finish()` fail the test for it.
class TestErrorsOutsideTheBody:
	extends GutTest

	var fx: StationFixture

	func before_each() -> void:
		fx = StationFixture.new(self)
		await fx.boot()
		push_error("planted outside the test body")

	func after_each() -> void:
		await fx.finish()

	func test_an_error_in_before_each_is_recorded_for_finish() -> void:
		var recorded: PackedStringArray = fx.errors_outside_test()
		var found: bool = false
		for line: String in recorded:
			found = found or line.contains("planted outside the test body")
		assert_true(found, "the fixture recorded the before_each error: %s" % [recorded])
		fx.clear_errors_outside_test()

	func test_an_error_in_the_body_is_left_to_gut() -> void:
		fx.clear_errors_outside_test()
		push_error("planted inside the test body")
		assert_eq(fx.errors_outside_test().size(), 0, "GUT's tracker owns body errors")
		assert_push_error("planted inside the test body")

class NullCaller extends Node:
	var target: Node = null

	func _process(_delta: float) -> void:
		target.get_name()
