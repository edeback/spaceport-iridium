extends GutTest

## A text sweep over the game's scripts for the two ways back into WI-70's bugs.
## Same shape as test_ui_theme's script sweep: one failure per offending line,
## naming it, so the list is the fix list.
##
## - **`is_failed()` outside `scripts/jobs/`.** An owner deciding whether to
##   re-post asks Job.did_not_complete(). is_failed() is false for an INTERRUPTED
##   job and reads like the same question, which is exactly how F25 happened: a
##   builder who resigned, was fired or went to suit up left the site stuck.
## - **`job_end.connect(` outside JobSlot.** An owner that remembers a job holds it
##   in a JobSlot. A hand-rolled listener is a twelfth copy of the contract, with
##   its own chance to disagree - and the usual `.bind(job)` form is a reference
##   cycle that kept every board job alive at teardown (§6).

## Where the game's scripts live. addons/, tests/ and vendored assets are not the
## game's; tools/sample_mod only compiles once its .pck is mounted.
const ROOTS: PackedStringArray = ["res://scripts", "res://modules", "res://pawns",
	"res://data", "res://ui", "res://objects"]

## The runner, its actions and drivers, and the job itself - the code that
## decides outcomes rather than reacting to them.
const IS_FAILED_ALLOWED_UNDER: String = "res://scripts/jobs/"

## The slot, and the inspection runner's one-shot: the ARC inspector's walk home
## is a single job the runner waits on once, and nothing remembers it afterwards.
const CONNECT_ALLOWED: PackedStringArray = [
	"res://scripts/jobs/job_slot.gd",
	"res://scripts/managers/inspection_runner.gd",
]

func _script_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for root: String in ROOTS:
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

func test_the_sweep_actually_finds_scripts() -> void:
	var paths: PackedStringArray = _script_paths()
	assert_gt(paths.size(), 250, "the sweep sees the game's scripts")
	assert_true(paths.has("res://modules/components/construction_component.gd"),
		"including the owner F25 was in")

func test_no_owner_asks_is_failed() -> void:
	var checked: int = 0
	for path: String in _script_paths():
		if path.begins_with(IS_FAILED_ALLOWED_UNDER):
			continue
		checked += 1
		_fail_each_line(path, "is_failed()",
			"asks is_failed(), which an interrupted job is not - ask did_not_complete()")
	assert_gt(checked, 200, "and read them")

func test_nothing_but_a_slot_listens_for_a_job_ending() -> void:
	var checked: int = 0
	for path: String in _script_paths():
		if CONNECT_ALLOWED.has(path):
			continue
		checked += 1
		_fail_each_line(path, "job_end.connect(",
			"listens for a job ending by hand - hold the job in a JobSlot")
	assert_gt(checked, 250, "and read them")

func test_the_allowed_listeners_still_exist() -> void:
	# An allowance for a file that has gone quietly allows nothing - and a renamed
	# runner would slip its listener past the sweep under the new name.
	for path: String in CONNECT_ALLOWED:
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
		assert_true(FileAccess.get_file_as_string(path).contains("job_end.connect("),
			"%s still has the listener it is allowed" % path)

func _fail_each_line(path: String, needle: String, why: String) -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for index: int in lines.size():
		var line: String = lines[index]
		var code: String = line.strip_edges()
		if code.begins_with("#"):
			continue # prose may name the old call
		if code.contains(needle):
			fail_test("%s:%d %s:  %s" % [path, index + 1, why, code])
