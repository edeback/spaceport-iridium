extends GutTest

## Two text sweeps over the game's scripts for WI-71's rule: *nothing keeps a
## reference to a node it doesn't own past the current frame without one of the
## four disciplines*. Same shape as `test_ui_theme`'s script sweep and
## `test_job_ownership_sweep` - one failure per offending line, naming it, so the
## list is the fix list.
##
## **Sweep 1 (F24): `is_instance_valid(<typed Object parameter>)`.** GDScript
## rejects a freed object at a typed Object parameter *at the call*, with a
## script error that aborts the caller, before the body can check anything. So
## the check is dead code for the one case it was written for, and the error it
## was meant to prevent lands on whoever called. A function that really can be
## handed a freed reference - one bound into a `Callable`, read out of a stored
## field, or arriving through a signal - takes it as `Variant` and casts after the
## check. A function that cannot asks `p != null`, which catches a freed object
## anyway (a freed object compares equal to null in Godot 4) and stops claiming
## protection it does not have.
##
## Two placements are legitimate and are not flagged:
## - **after the function's first `await`.** The parameter was live when the call
##   started and may have died while the coroutine was suspended; re-checking is
##   exactly the rule. `TraderManager._courier_collect` and the two shuttle-docked
##   handlers are this. `TurboliftShaft.request_ride` was too, until WI-75 took
##   its awaits out: a ride is phases now, and nothing is left to re-check.
## - **inside a lambda in the body.** A lambda runs later, and what it sees is a
##   *captured local*, not a parameter crossing a typed boundary at that moment -
##   checking it is discipline 4, not a violation of it.
##
## **Sweep 2 (F8): a member `Dictionary` keyed on a node.** Iterating one errors
## inside `Dictionary.next()` the moment a key has been freed - and it errors on
## the *dictionary's* key type, so an untyped loop variable does not help and any
## `is_instance_valid` guard inside the loop is unreachable. `duplicate()` and
## `dict[freed_key]` error too; `keys()`, `values()`, `size()`, `has()`, `get()`
## and `erase()` are the safe accessors. One is allowed only when an explicit
## lifecycle hook removes the key **before** the node is freed, and [constant
## PAIRED] names that hook for each. Anything else keys on `get_instance_id()`.

## Where the game's scripts live. addons/, tests/ and vendored assets are not the
## game's; tools/sample_mod only compiles once its .pck is mounted.
const ROOTS: PackedStringArray = ["res://scripts", "res://modules", "res://pawns",
	"res://data", "res://ui", "res://objects"]

## Types a parameter can be declared as that are not Object-derived, so a freed
## instance can never arrive in one. Everything else is treated as a class name.
const NON_OBJECT_TYPES: PackedStringArray = ["int", "float", "bool", "String",
	"StringName", "NodePath", "Variant", "void", "Vector2", "Vector2i", "Vector3",
	"Vector3i", "Vector4", "Vector4i", "Rect2", "Rect2i", "Transform2D",
	"Transform3D", "Basis", "Quaternion", "AABB", "Plane", "Color", "Array",
	"Dictionary", "Callable", "Signal", "RID", "PackedByteArray",
	"PackedInt32Array", "PackedInt64Array", "PackedFloat32Array",
	"PackedFloat64Array", "PackedStringArray", "PackedVector2Array",
	"PackedVector3Array", "PackedColorArray", "PackedVector4Array"]

## Every member `Dictionary[<node class>, …]` in the game, and the hook that
## empties it before its keys are freed. A new one fails the sweep until it is
## listed here with its pairing, or keyed on `get_instance_id()` instead.
##
## `Dictionary[<Resource>, …]` and `Dictionary[<enum>, …]` are not here and are
## not swept: a resource the dictionary references cannot be freed under it, and
## an enum is an int.
const PAIRED: Dictionary[String, String] = {
	"res://modules/components/path_component.gd:module_connections":
		"remove_connections() / disconnect_from(), both reached from " \
		+ "WorldManager.remove_module before the queue_free",
	"res://modules/components/structure_component.gd:module_connections":
		"remove_connections() / disconnect_from(), the same path",
	"res://modules/transport/turbolift_cab.gd:assigned_locations":
		"keys are the cab's own standing_locations markers, its children - " \
		+ "they die with it, and destroy() clears the dictionary first",
	"res://scripts/managers/atmosphere_manager.gd:_components":
		"unregister_component() from AtmosphereComponent._exit_tree, which " \
		+ "runs at the remove_child inside WorldManager.remove_module",
	"res://scripts/managers/atmosphere_manager.gd:_low_o2_alerted":
		"the same unregister_component()",
	"res://scripts/managers/heat_manager.gd:_components":
		"unregister_component() from HeatComponent._exit_tree, as above",
	"res://scripts/utility/module_graph.gd:_vertices":
		"remove_vertex() on module_removed, on a pawn's PREDELETE and on an " \
		+ "asteroid's or cab's teardown, plus clear() from the owning manager's " \
		+ "_exit_tree (WI-68 F3)",
	"res://ui/inspector/tab_sets/module_tab_set.gd:_errors":
		"keys are the bound module's own components, which outlive the set - " \
		+ "InspectorPanel clears it the frame is_alive() turns false",
	"res://ui/windows/stores_panel.gd:_cards":
		"_rebuild() clears it, and every lookup uses a component taken fresh " \
		+ "from _collect_entries() in the same call",
}

# --- shared ---------------------------------------------------------------------

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

func _lines(path: String) -> PackedStringArray:
	return FileAccess.get_file_as_string(path).replace("\r\n", "\n").split("\n")

func _indent_of(line: String) -> int:
	var depth: int = 0
	while depth < line.length() and line[depth] == "\t":
		depth += 1
	return depth

func test_the_sweep_actually_finds_scripts() -> void:
	var paths: PackedStringArray = _script_paths()
	assert_gt(paths.size(), 250, "the sweep sees the game's scripts")
	assert_true(paths.has("res://scripts/utility/pawn_status.gd"),
		"including one the F24 census named")
	assert_true(paths.has("res://scripts/managers/heat_manager.gd"),
		"and one F8 named")

# --- sweep 1: is_instance_valid on a typed Object parameter ---------------------

## One entry per function: its name, its typed Object parameters, the line its
## first `await` is on (-1 for none) and the lines inside a lambda in its body.
class FunctionScan:
	var name: String = ""
	var line: int = 0
	var params: Dictionary[String, String] = {}
	var first_await: int = -1
	var lambda_lines: Dictionary[int, bool] = {}
	## Line numbers of every is_instance_valid on one of `params` in the body,
	## with the parameter name each one names alongside.
	var check_lines: PackedInt32Array = PackedInt32Array()
	var check_names: PackedStringArray = PackedStringArray()

## Splits a parameter list on top-level commas, and says whether the closing
## bracket was reached - a header can wrap over several lines.
func _split_params(text: String) -> Dictionary:
	var out := PackedStringArray()
	var depth: int = 0
	var current: String = ""
	for index: int in text.length():
		var ch: String = text[index]
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
		elif ch == ")" or ch == "]" or ch == "}":
			if depth == 0:
				out.append(current)
				return {"params": out, "closed": true}
			depth -= 1
		if ch == "," and depth == 0:
			out.append(current)
			current = ""
			continue
		current += ch
	out.append(current)
	return {"params": out, "closed": false}

func _scan_functions(path: String) -> Array[FunctionScan]:
	var out: Array[FunctionScan] = []
	var lines: PackedStringArray = _lines(path)
	var header := RegEx.create_from_string("^(\\t*)(?:static\\s+)?func\\s+(\\w+)\\s*\\((.*)$")
	var param := RegEx.create_from_string("^(\\w+)\\s*:\\s*([A-Za-z_][\\w.]*)")
	var index: int = 0
	while index < lines.size():
		var match_result: RegExMatch = header.search(lines[index])
		if match_result == null:
			index += 1
			continue
		var depth: int = match_result.get_string(1).length()
		var scan := FunctionScan.new()
		scan.name = match_result.get_string(2)
		scan.line = index + 1
		var text: String = match_result.get_string(3)
		var last: int = index
		var split: Dictionary = _split_params(text)
		while not bool(split["closed"]) and last + 1 < lines.size():
			last += 1
			text += " " + lines[last].strip_edges()
			split = _split_params(text)
		for raw: String in (split["params"] as PackedStringArray):
			var found: RegExMatch = param.search(raw.strip_edges())
			if found == null:
				continue
			if NON_OBJECT_TYPES.has(found.get_string(2)):
				continue
			scan.params[found.get_string(1)] = found.get_string(2)
		_scan_body(lines, last + 1, depth, scan)
		out.append(scan)
		index = last + 1
	return out

func _scan_body(lines: PackedStringArray, start: int, depth: int,
		scan: FunctionScan) -> void:
	var lambda_depth: int = -1
	var index: int = start
	while index < lines.size():
		var line: String = lines[index]
		var code: String = line.strip_edges()
		if code != "" and _indent_of(line) <= depth:
			break
		index += 1
		if code.begins_with("#"):
			continue
		var here: int = index  # 1-based
		if lambda_depth >= 0:
			if code != "" and _indent_of(line) <= lambda_depth:
				lambda_depth = -1
			else:
				scan.lambda_lines[here] = true
		if code.contains("func(") or code.contains("func ("):
			lambda_depth = _indent_of(line)
		if scan.first_await < 0 and (code.begins_with("await ") or code.contains(" await ")
				or code.contains("= await ")):
			scan.first_await = here
		for parameter: String in scan.params:
			if code.contains("is_instance_valid(%s)" % parameter) \
					or code.contains("is_instance_valid(%s," % parameter):
				scan.check_lines.append(here)
				scan.check_names.append(parameter)

func test_no_typed_object_parameter_is_checked_for_validity() -> void:
	var functions: int = 0
	var checks: int = 0
	for path: String in _script_paths():
		for scan: FunctionScan in _scan_functions(path):
			functions += 1
			for slot: int in scan.check_lines.size():
				var at: int = scan.check_lines[slot]
				var parameter: String = scan.check_names[slot]
				checks += 1
				if scan.lambda_lines.has(at):
					continue  # a captured local inside a lambda, not a parameter
				if scan.first_await >= 0 and scan.first_await < at:
					continue  # re-checked after an await, which is the rule
				fail_test(("%s:%d %s(%s: %s) checks is_instance_valid on a typed "
					+ "Object parameter before its first await: a freed object is "
					+ "rejected at the call, so the check is dead code. Take it as "
					+ "Variant and cast after the check, or ask `%s != null`.")
					% [path, at, scan.name, parameter, scan.params[parameter], parameter])
	assert_gt(functions, 2000, "the sweep parsed the game's functions")
	assert_gt(checks, 3, "and found the legitimate checks it is meant to allow")

func test_the_legitimate_checks_are_still_there() -> void:
	# An allowance nothing exercises allows nothing. These three re-check a
	# parameter *after* an await, which is the discipline rather than a breach of
	# it - if one is rewritten the sweep should be re-read, not silently relaxed.
	# (A fourth, TurboliftShaft.request_ride, went with WI-75's awaits.)
	var expected: Dictionary[String, String] = {
		"res://scripts/managers/crew_manager.gd": "_on_shuttle_docked",
		"res://scripts/managers/visitor_manager.gd": "_on_shuttle_docked",
		"res://scripts/managers/trader_manager.gd": "_courier_collect",
	}
	for path: String in expected:
		var found: bool = false
		for scan: FunctionScan in _scan_functions(path):
			if scan.name != expected[path] or scan.check_lines.is_empty():
				continue
			found = scan.first_await >= 0 and scan.first_await < scan.check_lines[0]
		assert_true(found, "%s.%s still re-checks its parameter after an await"
			% [path, expected[path]])

# --- sweep 2: node-keyed member dictionaries ------------------------------------

## A class name that is a node, as far as this sweep can tell from text. Anything
## the game declares is resolved through the global class list; an engine class is
## resolved through ClassDB.
func _is_node_type(type_name: String) -> bool:
	if ClassDB.class_exists(type_name):
		return ClassDB.is_parent_class(type_name, "Node")
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) != type_name:
			continue
		var base: String = String(entry.get("base", ""))
		return _is_node_type(base) if base != type_name else false
	return false

func test_every_node_keyed_member_dictionary_is_paired() -> void:
	var member := RegEx.create_from_string(
		"^(?:@export\\s+)?(?:static\\s+)?var\\s+(\\w+)\\s*:\\s*Dictionary\\[\\s*([A-Za-z_][\\w.]*)\\s*,")
	var seen: Dictionary[String, bool] = {}
	for path: String in _script_paths():
		for line: String in _lines(path):
			if _indent_of(line) > 0:
				continue  # a local, which never outlives its frame
			var found: RegExMatch = member.search(line)
			if found == null:
				continue
			if not _is_node_type(found.get_string(2)):
				continue
			var key: String = "%s:%s" % [path, found.get_string(1)]
			seen[key] = true
			if PAIRED.has(key):
				continue
			fail_test(("%s declares `%s: Dictionary[%s, …]` as a member. Key it on "
				+ "get_instance_id() instead, or list it in PAIRED with the hook "
				+ "that erases the key before the node is freed.")
				% [path, found.get_string(1), found.get_string(2)])
	for key: String in PAIRED:
		assert_true(seen.has(key),
			"%s is still declared - a pairing for a dictionary that has gone " % key
			+ "allows nothing, and would hide the same field under a new name")

func test_the_pawn_roster_rows_are_keyed_on_an_id() -> void:
	# The one F8 named that had no real pairing: CrewPanel.refresh() early-returns
	# while the roster is off screen, so a crew member who dies with the HIRE tab
	# open leaves a dangling key - and _paint_selection iterates it on a click.
	var source: String = FileAccess.get_file_as_string("res://ui/windows/crew_panel.gd")
	assert_true(source.contains("var _rows: Dictionary[int, CrewRosterRow]"),
		"CrewPanel._rows is keyed on an instance id")
	assert_false(source.contains("var _rows: Dictionary[PawnBase,"),
		"and nothing in the panel is keyed on a pawn")
