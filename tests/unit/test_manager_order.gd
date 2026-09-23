extends GutTest

## WI-73 §1: the manager ready order, pinned.
##
## Ready order is the child order under `Managers/` in main.tscn, and the scene is
## the thing an editor drag changes without anybody meaning to. So this reads the
## scene - as a PackedScene's state, instantiating nothing - and asserts the two
## positions that are load-bearing, plus that CLAUDE.md's list is the scene's list.
##
## Reading every manager's `_ready` on 2026-09-22 found exactly two constraints:
## - **TimeManager first.** Twelve managers connect to its signals in `_ready` -
##   atmosphere, contract, economy, event, heat, job, market, power, resource,
##   trader, unlock and visitor - and `Global.time_manager` is null until it runs.
## - **SaveManager last.** It queues the pending load from its `_ready`, so last
##   means the load lands behind anything another manager starts in its own.
##
## Two things that look like constraints and are not: RaidManager and
## TutorialManager read difficulty and skip-onboarding from `Global`, an autoload,
## so they impose nothing. And ready order is also the order the managers connect
## to `SignalBus.module_added` / `module_removed`, but none of those handlers reads
## what another one does - path and structure each add or drop their own vertex,
## atmosphere and heat attach their own component, adjacency defers its rebuild,
## alerts resolve rows, and the crew spawn is deferred - so that order is free too.

const MAIN_SCENE: String = "res://main.tscn"
const CLAUDE_MD: String = "res://CLAUDE.md"
const MANAGERS: String = "Managers"

## Node name and script global name of each child of Managers/, in scene order.
## A child with no script (AudioManager, a bare holder for the music player)
## reports an empty class.
func _managers() -> Array[Dictionary]:
	var scene: PackedScene = load(MAIN_SCENE) as PackedScene
	var state: SceneState = scene.get_state()
	var out: Array[Dictionary] = []
	for index: int in state.get_node_count():
		if String(state.get_node_path(index, true)).trim_prefix("./") != MANAGERS:
			continue
		var script_class: StringName = &""
		for property: int in state.get_node_property_count(index):
			if state.get_node_property_name(index, property) == &"script":
				var script: Script = state.get_node_property_value(index, property) as Script
				if script != null:
					script_class = script.get_global_name()
		out.append({"name": String(state.get_node_name(index)), "class": script_class})
	return out

func _index_of_class(managers: Array[Dictionary], script_class: StringName) -> int:
	for index: int in managers.size():
		if managers[index]["class"] == script_class:
			return index
	return -1

func _names(managers: Array[Dictionary]) -> PackedStringArray:
	var out := PackedStringArray()
	for manager: Dictionary in managers:
		out.append(manager["name"])
	return out

## The manager list out of CLAUDE.md's Managers paragraph: the comma-separated run
## after "`Managers/`", from the first ": " to the end of that sentence.
func _documented() -> PackedStringArray:
	for line: String in FileAccess.get_file_as_string(CLAUDE_MD).split("\n"):
		if not line.begins_with("**Managers**"):
			continue
		var start: int = line.find(": ", line.find("`Managers/`"))
		if start < 0:
			return PackedStringArray()
		start += 2
		var end: int = line.find(". ", start)
		var out := PackedStringArray()
		for name: String in line.substr(start, end - start).split(","):
			out.append(name.strip_edges())
		return out
	return PackedStringArray()

# --- the reader sees what it thinks it sees ------------------------------------------

func test_the_scene_has_its_managers_where_we_look() -> void:
	# If the path or the parsing broke, every assertion below would pass on an
	# empty list.
	var managers: Array[Dictionary] = _managers()
	assert_gt(managers.size(), 20, "Managers/ children read out of main.tscn")
	assert_gt(_index_of_class(managers, &"WorldManager"), -1, "scripts resolve to their classes")

func test_claude_md_still_has_the_list_where_we_look() -> void:
	assert_gt(_documented().size(), 20, "the Managers paragraph of CLAUDE.md lists them")

# --- the two constraints ---------------------------------------------------------------

func test_time_manager_readies_first() -> void:
	assert_eq(_index_of_class(_managers(), &"TimeManager"), 0,
		"twelve managers connect to TimeManager's signals in their _ready")

func test_save_manager_readies_last() -> void:
	var managers: Array[Dictionary] = _managers()
	assert_eq(_index_of_class(managers, &"SaveManager"), managers.size() - 1,
		"SaveManager queues the pending load from its _ready, behind everything the others start")

# --- the doc ------------------------------------------------------------------------------

## CLAUDE.md lists the managers in tree order, and the list had already drifted
## once (it lacked HeatManager and DialogueRunner). A new manager, a removed one,
## or a drag in the editor now fails here until the paragraph says the same thing.
func test_claude_md_lists_every_manager_in_scene_order() -> void:
	assert_eq(_documented(), _names(_managers()))
