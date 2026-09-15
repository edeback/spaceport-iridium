extends GutTest

## A sweep of every authored [TutorialHintData] and every `guide.` verb any
## `.dialogue` file names (WI-63).
##
## Same argument as `test_event_content.gd`, one notch sharper. An event that
## misfires can fire again next cycle; **an advisory fires once per run and is
## then spent forever**, so a typo in one is not merely silent, it is
## unrepeatable. Everything here is a thing that would otherwise be discovered by
## a player who never saw the advice and never knew there was any.
##
## Content tests, so they load real resources through [ContentPaths] - the same
## walk the manager does, which means a mod's content is swept too.

const BRIDGE_PATH: String = "res://scripts/tutorial/tutorial_bridge.gd"
const DIALOGUE_ROOT: String = "res://data/dialogue/"
const START_MODULE_PATH: String = "res://data/modules/special/starting_module_mdata.tres"

func _hints() -> Array[TutorialHintData]:
	var out: Array[TutorialHintData] = []
	for path: String in ContentPaths.scan(ContentPaths.TUTORIAL):
		var hint: TutorialHintData = ResourceLoader.load(path) as TutorialHintData
		if hint != null:
			out.append(hint)
	return out

func test_the_sweep_actually_finds_hints() -> void:
	# A sweep whose scan silently returned nothing would pass everything below it.
	assert_gt(_hints().size(), 6, "the scan sees data/tutorial/")

# --- the hints themselves -------------------------------------------------------

## The most valuable assertion in the item. A hint naming a cue that is not in its
## dialogue fires, spends itself, posts a transmission and shows **nothing** -
## once, with no second chance to notice.
func test_every_hint_names_a_dialogue_and_a_cue_that_exists() -> void:
	for hint: TutorialHintData in _hints():
		assert_eq(hint.script_problem(), "",
			"hint '%s' would spend itself and say nothing" % hint.id)

func test_every_hint_has_an_id_a_title_and_a_body() -> void:
	for hint: TutorialHintData in _hints():
		assert_ne(hint.id, &"", "a hint with no id cannot be recorded as given")
		assert_false(hint.title.strip_edges().is_empty(),
			"hint '%s' owes the Comms row a subject" % hint.id)
		assert_false(hint.body.strip_edges().is_empty(),
			"hint '%s' is the only copy of advice that fires once" % hint.id)

func test_no_two_hints_share_an_id() -> void:
	var seen: Array[StringName] = []
	for hint: TutorialHintData in _hints():
		assert_false(seen.has(hint.id), "'%s' is declared twice" % hint.id)
		seen.append(hint.id)

# --- triggers -------------------------------------------------------------------

func test_every_hint_names_a_declared_trigger() -> void:
	var triggers := TutorialTriggers.new()
	for hint: TutorialHintData in _hints():
		assert_true(triggers.is_declared(hint.trigger),
			"hint '%s' watches '%s', which nothing emits" % [hint.id, hint.trigger])

## A filter on a trigger that takes none is ignored at fire time, so the hint
## fires for every occurrence rather than the one it meant.
func test_a_filter_appears_exactly_where_its_trigger_takes_one() -> void:
	var triggers := TutorialTriggers.new()
	for hint: TutorialHintData in _hints():
		if not triggers.is_declared(hint.trigger):
			continue
		if triggers.takes_filter(hint.trigger):
			assert_ne(hint.trigger_filter, &"",
				"hint '%s' watches a discriminating trigger and must say which" % hint.id)
		else:
			assert_eq(hint.trigger_filter, &"",
				"hint '%s' sets a filter its trigger ignores" % hint.id)

## A declared trigger with no hint is a watcher burning `slow_tick` for nothing,
## and the failure is invisible - the code runs, correctly, forever, to no end.
func test_every_declared_trigger_has_at_least_one_hint() -> void:
	var used: Array[StringName] = []
	for hint: TutorialHintData in _hints():
		if not used.has(hint.trigger):
			used.append(hint.trigger)
	for id: StringName in TutorialTriggers.DECLARED:
		assert_true(used.has(id), "trigger '%s' is watched for but nothing uses it" % id)

## Two hints on one trigger *and* one filter would make the second unreachable -
## `_fire_for` takes the first unspent match and stops.
func test_no_two_hints_claim_the_same_trigger_and_filter() -> void:
	var seen: Array[String] = []
	for hint: TutorialHintData in _hints():
		var key: String = "%s/%s" % [hint.trigger, hint.trigger_filter]
		assert_false(seen.has(key), "'%s' is claimed twice, so one hint can never fire" % key)
		seen.append(key)

## The three needs the pawn component actually emits. A hint filtered on
## `thirst` would be dead content that looks alive.
func test_the_need_filters_are_needs_that_exist() -> void:
	for hint: TutorialHintData in _hints():
		if hint.trigger != &"need_critical":
			continue
		assert_true([&"hunger", &"sleep", &"recreation"].has(hint.trigger_filter),
			"hint '%s' filters on '%s', which no need is called" % [hint.id, hint.trigger_filter])

## Likewise for the body kinds: the filter is a [SpaceBodyProfile] id, and one
## that matches no profile never fires.
func test_the_body_filters_name_real_space_body_profiles() -> void:
	var ids: Array[StringName] = []
	for path: String in ContentPaths.scan(ContentPaths.SPACE_BODIES):
		var profile: SpaceBodyProfile = ResourceLoader.load(path) as SpaceBodyProfile
		if profile != null:
			ids.append(profile.id)
	assert_false(ids.is_empty(), "the space-body scan found something to compare against")
	for hint: TutorialHintData in _hints():
		if hint.trigger != &"space_body_arrived":
			continue
		assert_true(ids.has(hint.trigger_filter),
			"hint '%s' waits for a '%s', which is not a body kind" % [hint.id, hint.trigger_filter])

# --- what the unreachable advisory is allowed to blame ---------------------------

## `TutorialManager._is_worth_naming` excludes non-MODULE-layer modules, and the
## whole reason is this: placing anything puts a **corridor segment on the same
## cell**, which reads as cut off exactly when the module it serves does. The scan
## takes the first match, so without the filter a player who built a detached Mess
## Hall is told their *Corridor* is unreachable - and then advised to go and build
## a corridor.
##
## The filter is only correct while corridors really are off the MODULE layer, and
## that is a number in a `.tres` that nothing else would complain about.
func test_corridors_are_not_on_the_module_layer() -> void:
	var hallway: ModuleData = _module_by_id(&"hallway_mdata")
	assert_not_null(hallway, "the corridor module exists")
	if hallway == null:
		return
	assert_ne(hallway.interaction_layer, WorldManager.StructureLayer.MODULE,
		"a MODULE-layer corridor would be blamed for its own absence")

## The other half of the same filter: truss is the backfill placed when a module
## is removed, it *is* on the MODULE layer, and so it has to be excluded by
## identity rather than by layer.
func test_truss_is_on_the_module_layer_and_so_needs_naming_by_identity() -> void:
	var truss: ModuleData = _module_by_id(&"truss_mdata")
	assert_not_null(truss, "the truss placeholder exists")
	if truss == null:
		return
	assert_eq(truss.interaction_layer, WorldManager.StructureLayer.MODULE,
		"if truss ever leaves the MODULE layer the identity check becomes dead code")

# --- the `guide` vocabulary -----------------------------------------------------

## The analogue of WI-62's cue sweep, and the only thing that catches a typo'd
## verb statically. [method DialogueRunner._validate_access] allows the bridge
## **wholesale**, so `guide.await_moad("build")` is not refused - it is a runtime
## error in the middle of the tutorial with the simulation held, which is the
## worst place in the game for one.
func test_every_guide_verb_a_dialogue_file_names_exists_on_the_bridge() -> void:
	var known: Array[String] = _bridge_methods()
	assert_true(known.has("await_mode"), "the method list was actually read")
	var found: int = 0
	for path: String in _dialogue_files():
		for verb: String in _verbs_in(path, "guide"):
			found += 1
			assert_true(known.has(verb),
				"%s calls guide.%s(), which the bridge does not have" % [path, verb])
	assert_gt(found, 5, "the scan found the tutorial's own calls")

## A private helper is not vocabulary. Calling one from content would work today
## and break silently the next time it is renamed.
func test_no_dialogue_file_reaches_a_private_bridge_method() -> void:
	for path: String in _dialogue_files():
		for verb: String in _verbs_in(path, "guide"):
			assert_false(verb.begins_with("_"),
				"%s reaches guide.%s(), which is not part of the vocabulary" % [path, verb])

## `point_at_subject` and `subject_name` both read the subject the trigger handed
## over. A hint whose trigger supplies none renders "that has not eaten".
func test_only_subject_carrying_hints_ask_for_a_subject() -> void:
	for hint: TutorialHintData in _hints():
		if hint.has_subject or hint.dialogue == null:
			continue
		var path: String = hint.dialogue.resource_path
		var verbs: Array[String] = _verbs_in(path, "guide")
		assert_false(verbs.has("point_at_subject"),
			"hint '%s' points at a subject its trigger never provides" % hint.id)
		assert_false(verbs.has("subject_name"),
			"hint '%s' names a subject its trigger never provides" % hint.id)

# --- the onboarding -------------------------------------------------------------

func _onboarding() -> DialogueResource:
	return ResourceLoader.load(TutorialManager.ONBOARDING_PATH) as DialogueResource

func test_the_onboarding_exists_and_has_its_cue() -> void:
	var resource: DialogueResource = _onboarding()
	assert_not_null(resource, "the introduction is where the manager looks for it")
	if resource == null:
		return
	assert_true(resource.get_cues().has(TutorialManager.ONBOARDING_CUE),
		"the manager's starting cue is in the file")

## **The affordability pin.** The placement step is a gate with the simulation
## held: if the station cannot pay for the module SAI asks for, the click no-ops
## and the tutorial waits forever, with the skip control as the only way out.
##
## It passes today - a mess hall is 6 steel and the starting module ships 50 - and
## the point of pinning it is that either number can move without anybody
## connecting the change to a tutorial they were not editing.
func test_a_new_station_can_afford_the_module_the_onboarding_asks_for() -> void:
	var gated: StringName = _gated_module_id()
	assert_ne(gated, &"", "the onboarding gates on placing a module")
	var module: ModuleData = _module_by_id(gated)
	assert_not_null(module, "'%s' is a real module" % gated)
	if module == null:
		return
	var stock: Dictionary[StringName, int] = _starting_stock()
	assert_false(stock.is_empty(), "the starting station ships with something")
	for resource: ResourceData in module.resource_costs:
		var cost: int = module.resource_costs[resource]
		var held: int = int(stock.get(resource.id, 0))
		assert_true(held >= cost,
			"a new station holds %d %s and the onboarding asks for %d - the gated step would hang"
				% [held, resource.id, cost])

## Every category and module the introduction walks the player through has to
## exist, or the coach mark rings nothing and the gate never closes.
func test_the_onboarding_points_at_things_that_exist() -> void:
	var text: String = _read(TutorialManager.ONBOARDING_PATH)
	for id: String in _arguments_of(text, "guide.await_category"):
		assert_not_null(ResourceLoader.load(_category_path(id)),
			"the onboarding opens a '%s' build category" % id)
	for id: String in _arguments_of(text, "guide.await_module_picked"):
		assert_not_null(_module_by_id(StringName(id)),
			"the onboarding picks up a '%s'" % id)
	for id: String in _arguments_of(text, "guide.await_mode"):
		assert_true(_mode_labels().has(id.to_lower()),
			"the onboarding opens a '%s' console mode" % id)

## The rail hides a category holding nothing buildable (2026-09-15), and the coach
## reads a hidden row as absent - so a category the introduction waits on has to
## hold something a brand-new station can place, or the gate never closes with the
## sim held. "A new station" is: nothing researched beyond the default nodes.
func test_every_category_the_onboarding_opens_is_on_a_new_stations_rail() -> void:
	var categories: Array[String] = _arguments_of(
		_read(TutorialManager.ONBOARDING_PATH), "guide.await_category")
	assert_false(categories.is_empty(), "the onboarding opens a build category")
	var granted: Array[ModuleData] = _granted_by_default_nodes()
	var locked_at_start := func(module: ModuleData) -> bool:
		return not module.unlocked_by_default and not granted.has(module)
	for id: String in categories:
		var bucket: Array[ModuleData] = []
		for path: String in ContentPaths.scan(ContentPaths.MODULES):
			var module: ModuleData = ResourceLoader.load(path) as ModuleData
			if module != null and module.category_id == StringName(id):
				bucket.append(module)
		assert_true(BuildMenuModel.category_shown(bucket, locked_at_start),
			"the onboarding opens '%s', which a new station's rail does not show" % id)

# --- helpers --------------------------------------------------------------------

func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

## Every `.dialogue` file in the build, source text rather than compiled resource:
## the verb sweep is looking for what an author *wrote*, and a mutation that fails
## to compile never reaches the resource at all.
func _dialogue_files() -> PackedStringArray:
	var out := PackedStringArray()
	_collect(DIALOGUE_ROOT, out)
	return out

func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect(full, out)
		elif entry.ends_with(".dialogue"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

## Distinct method names called on `alias` anywhere in the file.
func _verbs_in(path: String, alias: String) -> Array[String]:
	var out: Array[String] = []
	var regex := RegEx.new()
	regex.compile("%s\\.([A-Za-z_][A-Za-z0-9_]*)\\s*\\(" % alias)
	for match: RegExMatch in regex.search_all(_read(path)):
		var verb: String = match.get_string(1)
		if not out.has(verb):
			out.append(verb)
	return out

## The string literals passed to `call(...)`, in file order.
func _arguments_of(text: String, call: String) -> Array[String]:
	var out: Array[String] = []
	var regex := RegEx.new()
	regex.compile("%s\\s*\\(\\s*\"([^\"]*)\"" % call.replace(".", "\\."))
	for match: RegExMatch in regex.search_all(text):
		out.append(match.get_string(1))
	return out

## Read off the script rather than an instance, so the sweep costs no Node.
func _bridge_methods() -> Array[String]:
	var out: Array[String] = []
	var script: Script = load(BRIDGE_PATH) as Script
	if script == null:
		return out
	for entry: Dictionary in script.get_script_method_list():
		out.append(String(entry.get("name", "")))
	return out

func _gated_module_id() -> StringName:
	var ids: Array[String] = _arguments_of(
		_read(TutorialManager.ONBOARDING_PATH), "guide.await_module_placed")
	return StringName(ids[0]) if not ids.is_empty() else &""

func _module_by_id(id: StringName) -> ModuleData:
	for path: String in ContentPaths.scan(ContentPaths.MODULES):
		var module: ModuleData = ResourceLoader.load(path) as ModuleData
		if module != null and module.id == id:
			return module
	return null

## Modules a default-owned tech node grants, so owned before the introduction runs.
func _granted_by_default_nodes() -> Array[ModuleData]:
	var out: Array[ModuleData] = []
	for path: String in ContentPaths.scan(ContentPaths.UNLOCKS):
		var unlock: UnlockData = ResourceLoader.load(path) as UnlockData
		if unlock == null or not unlock.unlocked_by_default:
			continue
		for effect: UnlockEffect in unlock.effects:
			var grant: GrantModuleEffect = effect as GrantModuleEffect
			if grant != null and grant.module != null:
				out.append(grant.module)
	return out

func _category_path(id: String) -> String:
	return "res://data/build_categories/%s.tres" % id

func _mode_labels() -> Array[String]:
	var out: Array[String] = []
	for mode: ModeManager.Mode in ModeManager.LABELS:
		out.append(ModeManager.LABELS[mode].to_lower())
	return out

## What the starting station's storage is authored to hold, by resource id.
##
## Read out of the scene rather than from a constant, because the number that
## matters is the one the module actually ships with. Instantiating without adding
## to the tree means no `_ready` runs, so nothing here touches [Global].
func _starting_stock() -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	var data: ModuleData = ResourceLoader.load(START_MODULE_PATH) as ModuleData
	if data == null or data.scene == null:
		return out
	var root: Node = data.scene.instantiate()
	for node: Node in _walk(root):
		var storage: StorageComponent = node as StorageComponent
		if storage == null:
			continue
		for resource: ResourceData in storage.storage_data:
			var entry: StorageData = storage.storage_data[resource]
			if entry == null:
				continue
			out[resource.id] = int(out.get(resource.id, 0)) + entry.stored
	root.free()
	return out

func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out
