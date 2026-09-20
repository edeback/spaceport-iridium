extends GutTest

## A sweep of every module scene the shipped content points at (WI-72 §2, F31).
##
## Eleven `assert`s used to guard authored scene wiring: a processor with no
## recipe, a bin with OUTPUT slots and no output pool, a mining bay with no
## storage. An `assert` is stripped from a release export, so the check that
## existed to catch a bad scene was absent from precisely the build a player
## runs - and a scene edit or a mod would ship silently and fail hours later,
## somewhere else. WI-72 split each one in two: this sweep, which catches a
## vanilla fault before it is committed, and a runtime `push_error` that names
## the module and disables the component (see the components themselves).
##
## The scenes are instantiated but **never added to the tree**, so only `_init`
## runs: no `_ready`, no `@onready`, no [Global]. Exported node references are
## resolved by `PackedScene.instantiate()` itself, which is what makes the
## authored wiring readable here at all. Anything a component derives later - a
## processor's slot roles, a trade bay's order sheet - is not visible yet, so the
## checks below reason from the authored recipe rather than from the slots.
##
## The first audit's R3 probe walked all these scenes once, inside a running
## game, and then went away. This is the same walk, kept.

# --- the scenes ---------------------------------------------------------------

## Every distinct scene the shipped [ModuleData] point at, flipped variants
## included - a flipped scene is a separate `.tscn` with its own wiring, and
## WI-42's preview cache is the only other thing that ever looks at one.
##
## Cached for the run: the walk loads every ModuleData in the game and each rule
## below wants the same answer.
var _scene_cache: Dictionary[String, PackedScene] = {}

func _module_scenes() -> Dictionary[String, PackedScene]:
	if not _scene_cache.is_empty():
		return _scene_cache
	for path: String in ContentPaths.scan(ContentPaths.MODULES):
		var data: ModuleData = ResourceLoader.load(path) as ModuleData
		if data == null:
			continue
		for scene: PackedScene in [data.scene, data.flipped_scene]:
			if scene != null and not _scene_cache.has(scene.resource_path):
				_scene_cache[scene.resource_path] = scene
	return _scene_cache

## Runs `check` against every component of type `type` in every module scene,
## handing it the component, the scene path, and the module root.
##
## One walk per rule rather than one walk for everything: a failure then names
## the rule it broke, and a rule that finds no component at all fails its own
## "the sweep sees something" assertion instead of passing vacuously.
func _each_component(type: Variant, check: Callable) -> int:
	var found: int = 0
	var scenes: Dictionary[String, PackedScene] = _module_scenes()
	for scene_path: String in scenes:
		var root: Node = scenes[scene_path].instantiate()
		if root == null:
			fail_test("%s did not instantiate" % scene_path)
			continue
		for node: Node in _walk(root):
			if is_instance_of(node, type):
				found += 1
				check.call(node, scene_path, root)
		root.free()
	return found

func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out

# --- the sweep sees what it thinks it sees -------------------------------------

func test_the_sweep_finds_the_module_scenes() -> void:
	var scenes: Dictionary[String, PackedScene] = _module_scenes()
	assert_gt(scenes.size(), 30, "the scan sees data/modules/ and the scenes it points at")
	assert_true(scenes.has("res://modules/industrial_processors/ore_processor.tscn"),
		"including a processor, which is what half the rules below are about")

func test_every_module_data_points_at_a_scene() -> void:
	# A ModuleData with no scene is a build-menu entry that cannot be placed.
	for path: String in ContentPaths.scan(ContentPaths.MODULES):
		var data: ModuleData = ResourceLoader.load(path) as ModuleData
		if data == null:
			continue
		assert_not_null(data.scene, "%s names no scene" % path.get_file())

func test_every_module_scene_instantiates_without_a_tree() -> void:
	# The premise of every rule below: `_init` alone must be enough. A component
	# that reached Global from `_init` would take the whole suite down here rather
	# than in whichever rule happened to walk it first (WI-68 F12, TurboliftCab).
	for scene_path: String in _module_scenes():
		var root: Node = _module_scenes()[scene_path].instantiate()
		assert_not_null(root, "%s instantiates outside the tree" % scene_path)
		if root != null:
			root.free()

# --- processors ----------------------------------------------------------------

func test_every_processor_is_wired(  ) -> void:
	var seen: int = _each_component(ProcessorComponent,
		func(component: ProcessorComponent, scene_path: String, _root: Node) -> void:
			assert_eq(component.wiring_fault(), "",
				"%s: %s" % [scene_path.get_file(), component.wiring_fault()]))
	assert_gt(seen, 5, "the sweep found the processors")

## A resource cannot be an ingredient and a product of the same recipe: a slot
## has ONE role (WI-65), so the bin would have to be both an INPUT cap and an
## OUTPUT pool for the same row. Checked here for the recipe a scene is authored
## with, and across every shipped recipe in `test_recipe_index.gd`.
func test_no_processor_scene_is_authored_with_a_self_referencing_recipe() -> void:
	var seen: int = _each_component(ProcessorComponent,
		func(component: ProcessorComponent, scene_path: String, _root: Node) -> void:
			if component.recipe == null:
				return
			assert_eq(ProcessorComponent.recipe_role_conflict(component.recipe), "",
				"%s: %s" % [scene_path.get_file(),
					ProcessorComponent.recipe_role_conflict(component.recipe)]))
	assert_gt(seen, 5, "the sweep found the processors")

## The defect WI-65 actually shipped, caught by a screenshot rather than by any
## check: a processor whose recipe has products, whose bin therefore grows OUTPUT
## slots at build time, and whose output pool is zero - so it produces nothing,
## forever, with nothing on screen saying why.
func test_every_processor_that_produces_has_somewhere_to_put_it() -> void:
	var seen: int = _each_component(ProcessorComponent,
		func(component: ProcessorComponent, scene_path: String, _root: Node) -> void:
			if component.recipe == null or component.storage == null:
				return
			if component.recipe.outputs.is_empty():
				return
			assert_gt(component.storage.output_capacity, 0,
				("%s produces %d resource(s) into a bin whose output_capacity is 0 -"
				+ " every batch would stall on deposit")
					% [scene_path.get_file(), component.recipe.outputs.size()]))
	assert_gt(seen, 5, "the sweep found the processors")

# --- storage --------------------------------------------------------------------

## The general form of the rule above, over authored slots rather than derived
## ones: a bin that ships with OUTPUT rows and no pool for them can hold nothing.
func test_no_bin_has_output_slots_it_cannot_hold() -> void:
	var seen: int = _each_component(StorageComponent,
		func(component: StorageComponent, scene_path: String, _root: Node) -> void:
			assert_eq(component.wiring_fault(), "",
				"%s: %s" % [scene_path.get_file(), component.wiring_fault()]))
	assert_gt(seen, 20, "the sweep found the bins")

# --- mining, logistics, power, trade ----------------------------------------------

func test_every_mining_bay_is_wired() -> void:
	var seen: int = _each_component(MiningComponent,
		func(component: MiningComponent, scene_path: String, _root: Node) -> void:
			assert_eq(component.wiring_fault(), "",
				"%s: %s" % [scene_path.get_file(), component.wiring_fault()]))
	assert_gt(seen, 0, "the sweep found the mining bay")

func test_every_logistics_bay_is_wired() -> void:
	var seen: int = _each_component(LogisticsBayComponent,
		func(component: LogisticsBayComponent, scene_path: String, _root: Node) -> void:
			assert_eq(component.wiring_fault(), "",
				"%s: %s" % [scene_path.get_file(), component.wiring_fault()]))
	assert_gt(seen, 0, "the sweep found the logistics bay")

## A generator that burns fuel needs both a bin to burn it out of and a resource
## to burn. Missing either and it silently runs as a free generator, which is a
## balance change rather than a crash - the worst kind to ship.
func test_every_fuel_burning_generator_has_a_bin_and_a_fuel() -> void:
	var seen: int = _each_component(PowerGenerationComponent,
		func(component: PowerGenerationComponent, scene_path: String, _root: Node) -> void:
			assert_eq(component.wiring_fault(), "",
				"%s: %s" % [scene_path.get_file(), component.wiring_fault()]))
	assert_gt(seen, 3, "the sweep found the generators")

## A trade bay needs BOTH pools: `max_stored` stages the sell orders crew haul in,
## `output_capacity` receives what a trader delivers. Zero on either side is half
## a docking bay, and which half is missing depends on which way trade is going.
func test_every_trade_bay_has_both_pools() -> void:
	var seen: int = _each_component(TradeComponent,
		func(component: TradeComponent, scene_path: String, _root: Node) -> void:
			assert_eq(component.wiring_fault(), "",
				"%s: %s" % [scene_path.get_file(), component.wiring_fault()]))
	assert_gt(seen, 0, "the sweep found the docking bay")

# --- the rules themselves --------------------------------------------------------------
#
# Every check above delegates to the component's own `wiring_fault()`, which is
# also what `ComponentBase._ready` runs before pushing an error and shutting the
# component down. One predicate, two callers, so the sweep cannot drift from the
# thing that actually refuses to run - which is exactly what went wrong with the
# `assert`s these replaced, where the rule existed in one place and that place was
# compiled out of the shipping build.
#
# These construct the component directly and break one thing at a time, which is
# the half the scene sweep structurally cannot cover: every shipped scene is
# correct, so without them a `wiring_fault()` that returned "" unconditionally
# would pass the whole file.

func _free_later(node: Node) -> Node:
	autofree(node)
	return node

func test_a_processor_names_each_thing_it_is_missing() -> void:
	var processor: ProcessorComponent = _free_later(ProcessorComponent.new()) as ProcessorComponent
	assert_string_contains(processor.wiring_fault(), "recipe")
	processor.recipe = RecipeData.new()
	assert_string_contains(processor.wiring_fault(), "storage")
	processor.storage = _free_later(StorageComponent.new()) as StorageComponent
	assert_string_contains(processor.wiring_fault(), "power_consumer")
	processor.power_consumer = _free_later(PowerConsumptionComponent.new()) as PowerConsumptionComponent
	processor.time_to_process = 0.0
	assert_string_contains(processor.wiring_fault(), "time_to_process")
	processor.time_to_process = 1.0
	assert_eq(processor.wiring_fault(), "", "and says nothing once it is whole")

func test_a_recipe_that_names_one_resource_on_both_sides_is_reported() -> void:
	var ore: ResourceData = ResourceData.new()
	ore.name = "Iron Ore"
	var recipe := RecipeData.new()
	recipe.name = "Perpetual Iron"
	recipe.inputs = {ore: 1}
	recipe.outputs = {ore: 2}
	assert_string_contains(ProcessorComponent.recipe_role_conflict(recipe), "Iron Ore")
	recipe.outputs = {}
	assert_eq(ProcessorComponent.recipe_role_conflict(recipe), "")
	assert_eq(ProcessorComponent.recipe_role_conflict(null), "", "and a missing recipe is the other rule's problem")

func test_a_bin_with_an_output_role_and_no_output_pool_is_reported() -> void:
	var bin: StorageComponent = _free_later(StorageComponent.new()) as StorageComponent
	assert_eq(bin.wiring_fault(), "", "an ordinary intake bin is fine with no output pool")
	bin.default_role = StorageData.Role.OUTPUT
	assert_string_contains(bin.wiring_fault(), "output_capacity")
	bin.output_capacity = 10
	assert_eq(bin.wiring_fault(), "")

func test_a_mining_bay_and_a_logistics_bay_name_what_they_are_missing() -> void:
	var bay: MiningComponent = _free_later(MiningComponent.new()) as MiningComponent
	assert_string_contains(bay.wiring_fault(), "output_storage")
	bay.output_storage = _free_later(StorageComponent.new()) as StorageComponent
	assert_string_contains(bay.wiring_fault(), "power_consumer")
	bay.power_consumer = _free_later(PowerConsumptionComponent.new()) as PowerConsumptionComponent
	assert_eq(bay.wiring_fault(), "")
	var logistics: LogisticsBayComponent = _free_later(LogisticsBayComponent.new()) as LogisticsBayComponent
	assert_string_contains(logistics.wiring_fault(), "power_consumer")
	logistics.power_consumer = _free_later(PowerConsumptionComponent.new()) as PowerConsumptionComponent
	assert_eq(logistics.wiring_fault(), "")

## The fuel-wiring rule has the one branch that must stay silent: a solar panel
## burns nothing, so it has nothing to wire and is not misconfigured.
func test_a_generator_is_only_asked_about_fuel_if_it_burns_any() -> void:
	var generator: PowerGenerationComponent = _free_later(PowerGenerationComponent.new()) as PowerGenerationComponent
	assert_eq(generator.wiring_fault(), "", "a solar panel has no fuel to wire")
	generator.seconds_per_resource_consumed = 30.0
	assert_string_contains(generator.wiring_fault(), "input_storage")
	generator.input_storage = _free_later(StorageComponent.new()) as StorageComponent
	assert_string_contains(generator.wiring_fault(), "resource_consumed")
	generator.resource_consumed = ResourceData.new()
	assert_eq(generator.wiring_fault(), "")

func test_a_trade_bay_names_whichever_pool_is_missing() -> void:
	var bay: TradeComponent = _free_later(TradeComponent.new()) as TradeComponent
	assert_string_contains(bay.wiring_fault(), "storage")
	var bin: StorageComponent = _free_later(StorageComponent.new()) as StorageComponent
	bin.max_stored = 0
	bin.output_capacity = 0
	bay.storage = bin
	assert_string_contains(bay.wiring_fault(), "max_stored")
	bin.max_stored = 50
	assert_string_contains(bay.wiring_fault(), "output_capacity")
	bin.output_capacity = 50
	assert_eq(bay.wiring_fault(), "")

## The default: a component with nothing to check says nothing, so adding a
## component does not mean writing a rule.
func test_a_component_with_no_rule_reports_nothing() -> void:
	var plain: ComponentBase = _free_later(ComponentBase.new()) as ComponentBase
	assert_eq(plain.wiring_fault(), "")
	assert_false(plain.misconfigured, "and nothing has shut it down")

## `check_wiring()` is called from `ComponentBase._ready`, so a component that
## states a rule and then overrides `_ready` without `super()` states a rule
## nothing ever runs - silently, and only in the build a player runs, which is
## the exact failure mode F31 was about. Two components legitimately skip
## `super()` (AtmosphereComponent and HeatComponent are runtime-attached and set
## `owner_module` themselves); neither declares a rule, and this is what stops
## the third one from being a surprise.
func test_every_component_that_states_a_rule_still_reaches_the_check() -> void:
	var checked: int = 0
	for path: String in ResourceScanner.scan_paths("res://modules/components", "gd"):
		if path.ends_with("component_base.gd"):
			continue # it declares the default and its _ready IS the caller
		var text: String = FileAccess.get_file_as_string(path)
		if not text.contains("func wiring_fault("):
			continue
		checked += 1
		var body: String = _ready_body(text)
		if body.is_empty():
			continue # no override, so ComponentBase._ready runs as-is
		assert_true(body.contains("super()"),
			"%s states a wiring rule but its _ready never reaches ComponentBase._ready, so nothing checks it"
				% path.get_file())
	assert_gt(checked, 4, "the sweep found the components that state a rule")

## The lines of a script's own `_ready`, or "" if it does not override one. Read
## line by line rather than by regex: Godot's RegEx has no multiline `^` by
## default, and a pattern anchored at the start of the subject silently matches
## nothing in a whole-file search - which passes every test written on it.
func _ready_body(text: String) -> String:
	var out := PackedStringArray()
	var inside: bool = false
	for line: String in text.split("\n"):
		var code: String = line.rstrip("\r")
		if code.begins_with("func _ready("):
			inside = true
			continue
		if inside:
			if code.begins_with("func "):
				break
			out.append(code)
	return "\n".join(out) if inside else ""
