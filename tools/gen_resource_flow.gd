extends SceneTree

## Generates the resource-flow diagram from content data.
##
## Run: godot --headless -s tools/gen_resource_flow.gd
##
## The chart is DERIVED, never hand-drawn: adding a recipe .tres, an ore to a
## SpaceBodyProfile, or a processor tag to a module changes the diagram on the
## next run. Chains that are designed but not yet built live in one place -
## data/planned_flow.json - and render dashed, so one document is the roadmap and
## the reference at once without the two drifting apart.
##
## Why this parses .tres as TEXT instead of calling ResourceLoader: a `-s` script
## runs with no autoloads, so ModuleData (and everything reaching StorageData)
## fails to compile on `Identifier not found: Global` and every module .tres loads
## back as a blank Resource. Text parsing needs no game script to compile at all,
## which also means this tool can never be broken by a gameplay refactor.

const OUT_PATH: String = "res://Obsidian Vault/Spaceport Iridium/Planning/Resource_Flow.md"
const PLANNED_PATH: String = "res://data/planned_flow.json"
const RECIPES_DIR: String = "res://data/recipes/"
const MODULES_DIR: String = "res://data/modules/"
const RESOURCES_DIR: String = "res://data/resources/"
const BODIES_DIR: String = "res://data/space_bodies/"
## The belt's WEIGHTED_PICK pool is an @export on the AsteroidManager node, not a
## data file - see AsteroidManager.ore_types_available.
const MAIN_SCENE: String = "res://main.tscn"
const ASTEROID_POOL_PROPERTY: String = "ore_types_available"

const SLUG_OK: String = "abcdefghijklmnopqrstuvwxyz0123456789"

## res://…/foo.tres -> display name, for every ResourceData.
var _resource_names: Dictionary[String, String] = {}
## display name -> mermaid node id, so a planned recipe naming "Carbon" reuses the
## node the real refining recipe already made.
var _res_ids: Dictionary[String, String] = {}
var _lines: PackedStringArray = []


func _initialize() -> void:
	_resource_names = _scan_resource_names()
	var modules_by_tag: Dictionary[String, String] = _scan_module_tags()

	var groups: Dictionary[String, Array] = {}
	var order: PackedStringArray = []
	for path: String in _tres_under(RECIPES_DIR):
		var recipe: Dictionary = _parse_recipe(path)
		if recipe.is_empty():
			continue
		var label: String = _owner_for(recipe["tags"], modules_by_tag)
		if not groups.has(label):
			groups[label] = []
			order.append(label)
		(groups[label] as Array).append(recipe)

	var sources: Array[Dictionary] = _scan_sources()
	_merge_planned(groups, order, sources)
	_emit(groups, order, sources)

	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not write %s" % OUT_PATH)
		quit(1)
		return
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("Wrote %s - %d recipes across %d producers, %d body kinds." % [
			OUT_PATH, _count(groups), order.size(), sources.size()])
	quit(0)


# --- content scans ----------------------------------------------------------------

func _scan_resource_names() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for path: String in _tres_under(RESOURCES_DIR):
		var name: String = _string_value(_read(path), "name")
		if name != "":
			out[path] = name
	return out


## processor tag -> module display name, matching how RecipeData.for_tags resolves
## eligibility. First module claiming a tag wins the label.
func _scan_module_tags() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for path: String in _tres_under(MODULES_DIR):
		var text: String = _read(path)
		var name: String = _string_value(text, "name")
		if name == "":
			continue
		for tag: String in _string_array_value(text, "tags"):
			if not out.has(tag):
				out[tag] = name
	return out


func _owner_for(tags: PackedStringArray, modules_by_tag: Dictionary[String, String]) -> String:
	var names: PackedStringArray = []
	for tag: String in tags:
		var label: String = modules_by_tag.get(tag, "")
		if label != "" and not names.has(label):
			names.append(label)
	if names.is_empty():
		# A recipe whose tag no module claims can never run. Surfacing that in the
		# chart is the point - it is exactly the drift this generator exists to catch.
		return "UNREACHABLE (tags: %s)" % ", ".join(tags)
	return " / ".join(names)


func _scan_sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for path: String in _tres_under(BODIES_DIR):
		var text: String = _read(path)
		var display: String = _string_value(text, "display_name")
		if display == "":
			continue
		var names: PackedStringArray = []
		if _int_value(text, "mix_mode", 0) == 1:  # MixMode.FIXED_LIST
			names = _fixed_ore_names(text)
		else:
			names = _belt_pool_names()
		out.append({"name": display, "resources": names,
				"planned_resources": PackedStringArray()})
	return out


## A FIXED_LIST profile authors its mix as BodyOreEntry sub-resources; the array
## names them in order, each block points at one ResourceData.
func _fixed_ore_names(text: String) -> PackedStringArray:
	var ext: Dictionary[String, String] = _ext_paths(text)
	var sub_to_resource: Dictionary[String, String] = {}
	var current_sub: String = ""
	for line: String in text.split("\n"):
		if line.begins_with("[sub_resource"):
			current_sub = _attribute(line, "id")
		elif line.begins_with("["):
			current_sub = ""
		elif current_sub != "" and line.begins_with("resource = ExtResource("):
			sub_to_resource[current_sub] = ext.get(_first_quoted(line), "")
	var out: PackedStringArray = []
	for sub_id: String in _all_calls(_line_value(text, "fixed_ores"), "SubResource"):
		var name: String = _resource_names.get(sub_to_resource.get(sub_id, ""), "")
		if name != "" and not out.has(name):
			out.append(name)
	return out


func _belt_pool_names() -> PackedStringArray:
	var text: String = _read(MAIN_SCENE)
	var ext: Dictionary[String, String] = _ext_paths(text)
	var out: PackedStringArray = []
	for ext_id: String in _all_calls(_line_value(text, ASTEROID_POOL_PROPERTY), "ExtResource"):
		var name: String = _resource_names.get(ext.get(ext_id, ""), "")
		if name != "" and not out.has(name):
			out.append(name)
	return out


func _parse_recipe(path: String) -> Dictionary:
	var text: String = _read(path)
	if not text.contains("recipe_data.gd"):
		return {}
	var ext: Dictionary[String, String] = _ext_paths(text)
	return {
		"name": _string_value(text, "name"),
		"sort": _int_value(text, "sort_order", 0),
		"inputs": _parse_amounts(text, "inputs", ext),
		"outputs": _parse_amounts(text, "outputs", ext),
		"tags": _string_array_value(text, "processor_tags"),
		"planned": false,
	}


## `inputs`/`outputs` are ResourceData->int dictionaries, authored either bare or
## wrapped in `Dictionary[ExtResource(..), int](…)`. Both open with `{` and close
## with a line whose first character is `}`.
func _parse_amounts(text: String, key: String, ext: Dictionary[String, String]) -> Array:
	var out: Array = []
	var lines: PackedStringArray = text.split("\n")
	var inside: bool = false
	for line: String in lines:
		if not inside:
			if line.begins_with(key + " = ") and line.ends_with("{"):
				inside = true
			continue
		if line.begins_with("}"):
			break
		var parts: PackedStringArray = line.split(":")
		if parts.size() < 2:
			continue
		var res_path: String = ext.get(_first_quoted(parts[0]), "")
		var name: String = _resource_names.get(res_path, "")
		if name == "":
			continue
		out.append([name, int(parts[1].strip_edges().trim_suffix(","))])
	return out


# --- planned overlay ----------------------------------------------------------------

func _merge_planned(groups: Dictionary[String, Array], order: PackedStringArray,
		sources: Array[Dictionary]) -> void:
	if not FileAccess.file_exists(PLANNED_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLANNED_PATH))
	if parsed is not Dictionary:
		push_error("%s is not a JSON object" % PLANNED_PATH)
		return
	var data: Dictionary = parsed

	for entry: Variant in data.get("sources", []):
		var src: Dictionary = entry
		var label: String = String(src.get("name", "?"))
		var target: Dictionary = {}
		for existing: Dictionary in sources:
			if String(existing["name"]) == label:
				target = existing
				break
		if target.is_empty():
			target = {"name": label, "resources": PackedStringArray(),
					"planned_resources": PackedStringArray()}
			sources.append(target)
		var have: PackedStringArray = target["resources"]
		var planned: PackedStringArray = target["planned_resources"]
		for n: Variant in src.get("resources", []):
			if not have.has(String(n)):
				have.append(String(n))
				planned.append(String(n))

	for entry: Variant in data.get("modules", []):
		var mod: Dictionary = entry
		var label: String = String(mod.get("name", "?"))
		if not groups.has(label):
			groups[label] = []
			order.append(label)
		var rows: Array = groups[label]
		for r: Variant in mod.get("recipes", []):
			var recipe: Dictionary = r
			rows.append({
				"name": String(recipe.get("name", "?")),
				"sort": 9999,
				"inputs": _pairs_from_json(recipe.get("inputs", {})),
				"outputs": _pairs_from_json(recipe.get("outputs", {})),
				"tags": PackedStringArray(),
				"planned": true,
			})


# --- emit -------------------------------------------------------------------------

func _emit(groups: Dictionary[String, Array], order: PackedStringArray,
		sources: Array[Dictionary]) -> void:
	_lines.append("# Resource Flow")
	_lines.append("")
	_lines.append("> [!warning] Generated file - do not edit by hand.")
	_lines.append("> `godot --headless -s tools/gen_resource_flow.gd` rebuilds it from")
	_lines.append("> `data/recipes/`, `data/modules/`, `data/space_bodies/`, `main.tscn`'s")
	_lines.append("> belt pool and `data/planned_flow.json`.")
	_lines.append("> **Solid = implemented. Dashed = planned** (edit `data/planned_flow.json`).")
	_lines.append("")
	_lines.append("```mermaid")
	_lines.append("flowchart LR")
	_lines.append("  classDef res fill:#132630,stroke:#4fc3f7,color:#e7f4fb;")
	_lines.append("  classDef proc fill:#2a2214,stroke:#ffb74d,color:#fbf1e2;")
	_lines.append("  classDef planned stroke-dasharray:5 4,opacity:0.7;")

	var planned_nodes: PackedStringArray = []
	var edges: PackedStringArray = []

	for src: Dictionary in sources:
		var planned_res: PackedStringArray = src["planned_resources"]
		_lines.append("  subgraph g_src_%s[\"%s\"]" % [_slug(String(src["name"])), src["name"]])
		_lines.append("    direction TB")
		for rname: String in src["resources"]:
			var nid: String = _res_id(rname)
			_lines.append("    %s([\"%s\"]):::res" % [nid, rname])
			if planned_res.has(rname):
				planned_nodes.append(nid)
		_lines.append("  end")

	for label: String in order:
		var rows: Array = groups[label]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["sort"]) != int(b["sort"]):
				return int(a["sort"]) < int(b["sort"])
			return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
		_lines.append("  subgraph g_%s[\"%s\"]" % [_slug(label), label])
		_lines.append("    direction TB")
		for row: Dictionary in rows:
			var pid: String = _proc_id(label, String(row["name"]))
			_lines.append("    %s[\"%s\"]:::proc" % [pid, row["name"]])
			if bool(row["planned"]):
				planned_nodes.append(pid)
		_lines.append("  end")

		for row: Dictionary in rows:
			var pid: String = _proc_id(label, String(row["name"]))
			var planned: bool = bool(row["planned"])
			for pair: Array in row["inputs"]:
				edges.append("  %s([\"%s\"]):::res %s %s" % [_res_id(String(pair[0])),
						pair[0], _arrow(planned, int(pair[1])), pid])
			for pair: Array in row["outputs"]:
				edges.append("  %s %s %s([\"%s\"]):::res" % [pid, _arrow(planned, int(pair[1])),
						_res_id(String(pair[0])), pair[0]])

	_lines.append_array(edges)
	if not planned_nodes.is_empty():
		_lines.append("  class %s planned;" % ",".join(planned_nodes))
	_lines.append("```")
	_lines.append("")


func _arrow(planned: bool, amount: int) -> String:
	# Mermaid spells a labelled dotted edge `-. text .->`, not `-.->|text|`.
	return "-. %d .->" % amount if planned else "-->|%d|" % amount


# --- .tres text helpers --------------------------------------------------------------

## Line endings are mixed across the repo's .tres files, and a trailing \r turns
## every `ends_with("{")` test into a silent miss - so normalise on the way in.
func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path).replace("\r\n", "\n")


func _tres_under(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("No such directory: %s" % dir_path)
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			out.append_array(_tres_under(full + "/"))
		elif entry.ends_with(".tres"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


## ext_resource id -> res:// path, from a .tres or .tscn header.
func _ext_paths(text: String) -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for line: String in text.split("\n"):
		if not line.begins_with("[ext_resource"):
			continue
		var id: String = _attribute(line, "id")
		var path: String = _attribute(line, "path")
		if id != "" and path != "":
			out[id] = path
	return out


## The value of `key="…"` in a `[…]` header line. The match must start at a word
## boundary: `id="` is a substring of `uid="`, and taking the first hit hands back
## the uid for every resource that has one.
func _attribute(line: String, key: String) -> String:
	var needle: String = key + "=\""
	var at: int = line.find(needle)
	while at > 0:
		var before: String = line[at - 1]
		if before == " " or before == "[":
			var start: int = at + needle.length()
			var end: int = line.find("\"", start)
			return line.substr(start, end - start) if end > start else ""
		at = line.find(needle, at + 1)
	return ""


func _line_value(text: String, key: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with(key + " = "):
			return line
	return ""


func _string_value(text: String, key: String) -> String:
	return _first_quoted(_line_value(text, key))


func _int_value(text: String, key: String, fallback: int) -> int:
	var line: String = _line_value(text, key)
	if line == "":
		return fallback
	var raw: String = line.split(" = ", true, 1)[1].strip_edges()
	return int(raw) if raw.is_valid_int() else fallback


## Every quoted entry of an `Array[String]([...])` value.
func _string_array_value(text: String, key: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var line: String = _line_value(text, key)
	var parts: PackedStringArray = line.split("\"")
	var i: int = 1
	while i < parts.size():
		out.append(parts[i])
		i += 2
	return out


## Every id inside `Call("id")` occurrences on one line, in order.
func _all_calls(line: String, call: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var needle: String = call + "(\""
	var at: int = line.find(needle)
	while at >= 0:
		var start: int = at + needle.length()
		var end: int = line.find("\"", start)
		if end < 0:
			break
		out.append(line.substr(start, end - start))
		at = line.find(needle, end)
	return out


func _first_quoted(s: String) -> String:
	var start: int = s.find("\"")
	if start < 0:
		return ""
	var end: int = s.find("\"", start + 1)
	return s.substr(start + 1, end - start - 1) if end > start else ""


# --- misc ---------------------------------------------------------------------------

func _res_id(rname: String) -> String:
	if not _res_ids.has(rname):
		_res_ids[rname] = "r_" + _slug(rname)
	return _res_ids[rname]


func _proc_id(module_label: String, recipe_name: String) -> String:
	return "p_%s_%s" % [_slug(module_label), _slug(recipe_name)]


func _slug(s: String) -> String:
	var out: String = ""
	for c: String in s.to_lower():
		out += c if SLUG_OK.contains(c) else "_"
	return out


func _pairs_from_json(d: Dictionary) -> Array:
	var out: Array = []
	for key: Variant in d:
		out.append([String(key), int(d[key])])
	return out


func _count(groups: Dictionary[String, Array]) -> int:
	var n: int = 0
	for key: String in groups:
		n += (groups[key] as Array).size()
	return n
