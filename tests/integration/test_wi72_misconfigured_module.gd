extends GutTest

## The runtime half of WI-72 §2 (F31): what a station does when a module scene it
## was never told about turns out to be miswired.
##
## The content sweep in `tests/unit/test_module_content.gd` covers every scene
## `data/modules/` points at, and a mod's module is by definition not in it. That
## used to be an `assert` - which is stripped from a release export, so the build
## a player runs had no check at all and a half-wired processor simply stood there
## producing nothing. The replacement has to hold three things at once, and only a
## running station can show all three:
##
## - it is **said once**, not once a frame and not once a batch;
## - the component **stops**, so the failure stays where it is rather than
##   surfacing later as a stall somewhere downstream;
## - the **station keeps running**. A bad mod scene must not be a crash.
##
## The miswired module is a real `.tscn` with one export wrong, which is exactly
## the shape a mod ships - not a hand-rolled node, because what is under test is
## the path from `PackedScene.instantiate()` through `ComponentBase._ready`.

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)

func after_each() -> void:
	await fx.finish()

## The path to the miswired scene: the shipped ore processor, inherited, with its
## recipe cleared. A file rather than a `PackedScene.pack()` of a live tree -
## repacking an instantiated module loses the base scene's authored PathComponent
## anchors, and the test would then be measuring a broken AStar graph instead.
const BROKEN_SCENE: String = "res://tests/integration/fixtures/broken_ore_processor.tscn"

## A [ModuleData] for that scene, under its own id so nothing else in the run can
## find it. Everything else about it is the real ore processor's.
func _broken_processor_data() -> ModuleData:
	var original: ModuleData = Global.save_manager.get_module_data_by_id(&"ore_processor_mdata")
	assert_not_null(original, "the shipped ore processor is there to base it on")
	if original == null:
		return null
	var scene: PackedScene = load(BROKEN_SCENE) as PackedScene
	assert_not_null(scene, "%s loads" % BROKEN_SCENE)
	if scene == null:
		return null
	var data: ModuleData = original.duplicate()
	data.id = &"wi72_broken_processor"
	data.name = "Broken Processor"
	data.scene = scene
	data.flipped_scene = null
	return data

## Every tracked push_error whose text names the fault, marked handled so the
## suite stays green - the error IS the expected result here.
func _handled_wiring_errors() -> Array[String]:
	var out: Array[String] = []
	for error: GutTrackedError in get_errors():
		# `handled` is a flag, not a removal: GUT keeps every error it tracked for
		# the whole test, so anything already accounted for has to be skipped or
		# the second call reports the first call's error all over again.
		if error.handled or not error.is_push_error():
			continue
		if error.contains_text("misconfigured"):
			out.append(String(error.code))
			error.handled = true
	return out

func test_a_miswired_module_says_so_once_stops_and_leaves_the_station_running() -> void:
	assert_true(await fx.boot(), "the station is up")
	var data: ModuleData = _broken_processor_data()
	if data == null:
		return
	var module: ModuleBase = Global.world_manager.add_module(data, Vector2i(10, 9), false, false, true)
	assert_not_null(module, "the module still places - a bad scene is not a placement failure")
	if module == null:
		return

	# Said once, and the sentence names what is wrong rather than only that
	# something is.
	var reported: Array[String] = _handled_wiring_errors()
	assert_eq(reported.size(), 1, "exactly one error: %s" % str(reported))
	if reported.size() == 1:
		assert_true(reported[0].contains("recipe"),
			"and it names the missing recipe: %s" % reported[0])

	# The component stopped, and the module can say so for itself: last_error is
	# what the inspector reads, so the player sees this and not only the log.
	var processor: ProcessorComponent = module.get_component_by_type(ProcessorComponent) as ProcessorComponent
	assert_not_null(processor, "the component is still on the module - it is disabled, not removed")
	if processor != null:
		assert_true(processor.misconfigured, "and it knows it")
		assert_true(processor.last_error.begins_with("Misconfigured:"),
			"the inspector line reads: %s" % processor.last_error)
		assert_false(processor.is_processing(), "and it is not ticking")

	# The station carries on, and nothing repeats the complaint every frame.
	assert_true(await fx.tick(4.0), "the sim keeps running with a broken module standing in it")
	assert_eq(_handled_wiring_errors(), [] as Array[String], "and says nothing further")
	assert_true(is_instance_valid(module) and module.is_inside_tree(),
		"the module is still standing")
	assert_eq(fx.invariants(), PackedStringArray(), "and the station's invariants hold")

## The mirror: the same scene with its recipe left alone places, reports nothing
## and runs. Without this the test above would pass just as well against a
## `wiring_fault()` that complained about everything.
func test_the_same_module_unbroken_says_nothing_and_runs() -> void:
	assert_true(await fx.boot(), "the station is up")
	var module: ModuleBase = fx.place(&"ore_processor_mdata", Vector2i(10, 9))
	assert_not_null(module, "the shipped processor places")
	if module == null:
		return
	assert_eq(_handled_wiring_errors(), [] as Array[String], "and complains about nothing")
	var processor: ProcessorComponent = module.get_component_by_type(ProcessorComponent) as ProcessorComponent
	assert_not_null(processor)
	if processor != null:
		assert_false(processor.misconfigured)
		assert_true(processor.is_processing(), "and is ticking like any other processor")
	assert_true(await fx.tick(2.0))
	assert_eq(fx.invariants(), PackedStringArray())
