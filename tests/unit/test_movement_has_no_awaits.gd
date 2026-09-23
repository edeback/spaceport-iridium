extends GutTest

## WI-75 §7: nothing in the movement pipeline awaits.
##
## Every wait a walk can hit - a door, the teleporter's flash, a turbolift queue,
## boarding, the ride - is a state of PawnMovementComponent, RideRequest or
## TurboliftCab, advanced in `_process` and carried by a save. A coroutine there
## is the thing WI-75 removed: it cannot be saved, stepped or asserted, and one
## whose module is freed first never resumes (F28). So a new `await` in any of
## these files fails here, naming its line, rather than quietly reintroducing a
## wait a save cannot hold.
##
## Managers that await for reasons of their own (a shuttle's `sim_seconds` before
## departing, the dialogue balloon) own no pawn's position and are not swept.

## The pipeline: the walk, the hooks it calls, every PathBehavior, and everything
## that carries a pawn. Whole directories where the directory is the pipeline, so
## a new behavior or carrier is swept without being listed.
const FILES: PackedStringArray = [
	"res://pawns/pawn_movement_component.gd",
	"res://pawns/pawn_base.gd",
	"res://modules/templates/module_base.gd",
	"res://modules/components/path_component.gd",
]
const DIRECTORIES: PackedStringArray = [
	"res://scripts/pathing",
	"res://modules/transport",
]

func _swept_paths() -> PackedStringArray:
	var out: PackedStringArray = FILES.duplicate()
	for directory: String in DIRECTORIES:
		for file_name: String in DirAccess.get_files_at(directory):
			if file_name.ends_with(".gd"):
				out.append(directory.path_join(file_name))
	return out

## The code part of a line: string contents blanked out, and everything from a
## `#` outside a string on dropped.
static func _code_of(line: String) -> String:
	var out: String = ""
	var quote: String = ""
	var escaped: bool = false
	for index: int in line.length():
		var character: String = line[index]
		if quote != "":
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote:
				quote = ""
			out += " "
		elif character == "\"" or character == "'":
			quote = character
			out += " "
		elif character == "#":
			return out
		else:
			out += character
	return out

func test_nothing_in_the_movement_pipeline_awaits() -> void:
	var word := RegEx.create_from_string("\\bawait\\b")
	var paths: PackedStringArray = _swept_paths()
	assert_gt(paths.size(), 10, "the sweep found the pipeline's scripts")
	for path: String in paths:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "%s opens" % path)
		if file == null:
			continue
		var number: int = 0
		while not file.eof_reached():
			var line: String = file.get_line()
			number += 1
			if word.search(_code_of(line)) != null:
				fail_test("%s:%d awaits: `%s`. A wait in the movement pipeline is a state the "
					% [path, number, line.strip_edges()]
					+ "movement component, the ride or the cab holds and a save carries (WI-75), "
					+ "never a coroutine.")

func test_the_sweep_sees_an_await_and_ignores_one_in_a_comment() -> void:
	var word := RegEx.create_from_string("\\bawait\\b")
	assert_not_null(word.search(_code_of("\tawait door.animation_finished")), "code")
	assert_null(word.search(_code_of("\t# used to await the door")), "a comment")
	assert_null(word.search(_code_of("\tprint(\"await # not\")  # await")), "a string, then a comment")
	assert_null(word.search(_code_of("\t_awaiting_adoption = true")), "a longer word")
