extends GutTest

## WI-74 §3 (F33): the simulation does not reach up into the HUD.
##
## Two ways it used to. Four world objects - a module's footprint, a pawn, a pile
## and an asteroid - called `Global.ui_main.*_clicked` from their own input
## handlers, and two simulation managers bound `UiInGame` by a relative path into
## the HUD's branch of `main.tscn` (one of them to write the multi-select path
## preview into it, the other for nothing). A click is now
## `SignalBus.world_object_clicked`, which UIMain listens for, and the path preview
## is PathManager's to compute and UIInGame's to draw.
##
## A text sweep, one failure per offending line. Comment lines are skipped: a
## doc comment that names the HUD to explain why the code does not is fine.

## World objects: nothing here may name the HUD at all.
const WORLD_ROOTS: PackedStringArray = ["res://modules", "res://pawns", "res://objects", "res://data"]
const WORLD_FORBIDDEN: PackedStringArray = ["Global.ui_main", "Global.ui_in_game"]

const MANAGER_ROOT: String = "res://scripts/managers"
## The managers whose job is to put something on the HUD, each mounting under
## UIMain when there is one: a conversation's balloon, and the tutorial's coach
## mark. Global declares the slots. Everything else in the managers directory is
## simulation.
const MANAGERS_THAT_MOUNT_UI: PackedStringArray = [
	"res://scripts/managers/global.gd",
	"res://scripts/managers/dialogue_runner.gd",
	"res://scripts/managers/tutorial_manager.gd",
]
const MANAGER_FORBIDDEN: PackedStringArray = [
	"Global.ui_main", "Global.ui_in_game", "UIInGame", "UIMain", "$\"../../",
]

func test_the_sweep_sees_the_world_and_the_managers() -> void:
	assert_gt(_paths(WORLD_ROOTS).size(), 100, "the world objects' scripts")
	assert_gt(_paths([MANAGER_ROOT]).size(), 25, "and the managers'")
	assert_true(_paths(WORLD_ROOTS).has("res://modules/templates/module_base.gd"), "including a footprint click")

func test_no_world_object_names_the_hud() -> void:
	var checked: int = 0
	for path: String in _paths(WORLD_ROOTS):
		checked += 1
		_fail_lines(path, WORLD_FORBIDDEN, "names the HUD - emit SignalBus.world_object_clicked, or a signal of its own")
	assert_gt(checked, 100, "and read them")

func test_no_simulation_manager_binds_the_hud() -> void:
	var checked: int = 0
	for path: String in _paths([MANAGER_ROOT]):
		if MANAGERS_THAT_MOUNT_UI.has(path):
			continue
		checked += 1
		_fail_lines(path, MANAGER_FORBIDDEN, "reaches into the HUD - expose state and a signal, and let the UI read it")
	assert_gt(checked, 25, "and read them")

func test_the_allowed_managers_still_exist() -> void:
	for path: String in MANAGERS_THAT_MOUNT_UI:
		assert_true(FileAccess.file_exists(path), "%s is allowed and no longer exists" % path)

func test_the_sweep_bites() -> void:
	var probe: String = "func _on_click() -> void:\n\t# Global.ui_main is only named in a comment\n\tGlobal.ui_main.pawn_clicked(self)\n"
	assert_eq(_offending_lines(probe, WORLD_FORBIDDEN), [3] as Array[int], "the call is caught and the comment is not")

func _fail_lines(path: String, forbidden: PackedStringArray, why: String) -> void:
	for line_number: int in _offending_lines(FileAccess.get_file_as_string(path), forbidden):
		fail_test("%s:%d %s" % [path, line_number, why])

## 1-based numbers of the non-comment lines of `source` naming any of `forbidden`.
static func _offending_lines(source: String, forbidden: PackedStringArray) -> Array[int]:
	var out: Array[int] = []
	var lines: PackedStringArray = source.split("\n")
	for index: int in lines.size():
		var code: String = lines[index].strip_edges()
		if code.begins_with("#"):
			continue
		for needle: String in forbidden:
			if code.contains(needle):
				out.append(index + 1)
				break
	return out

func _paths(roots: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for root: String in roots:
		_collect(root, out)
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
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
