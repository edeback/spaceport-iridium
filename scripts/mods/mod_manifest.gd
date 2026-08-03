class_name ModManifest
extends RefCounted

## One mod's `mod.json`, parsed and validated (WI-47 M1).
##
## The manifest lives **outside** the `.pck`, next to it in the mod's folder.
## That isn't a style choice: `ProjectSettings.load_resource_pack()` has no
## counterpart, so a mounted pack can never be unmounted, and therefore every
## decision about whether to load a mod at all - id collisions, missing
## dependencies, load order - has to be made from something readable *before*
## mounting. A manifest inside the pack would be readable only once it was
## already too late to say no.
##
## Pure: parsing and validation only, no filesystem walk and no mounting. Both of
## those are ModManager's, so the rules stay unit-testable.

const MANIFEST_FILE: String = "mod.json"

## Namespace prefix for every id this mod defines - see ContentPaths.accept_id.
var id: StringName = &""
var display_name: String = ""
var version: String = ""
## Which game version the author built against. A mismatch warns; it never
## refuses, because a mod is usually fine across a patch and the player is better
## placed than we are to judge.
var game_version: String = ""
## Mods that MUST be present. A missing dep drops this mod, transitively.
var deps: Array[StringName] = []
## Soft ordering only - "put me after these if they happen to be installed".
var load_after: Array[StringName] = []

## Absolute `user://mods/<folder>/` this was read from. Empty for a manifest
## built in a test.
var folder: String = ""
## Optional: which `.pck` in the folder to mount. Only needed when the folder
## holds more than one; otherwise the single pack is found without being named.
var pck_file: String = ""
## The `.pck` to mount, resolved by ModManager. Empty until then.
var pck_path: String = ""

## Non-empty when this manifest is unusable; the reason is player-facing text.
var error: String = ""

static func from_dict(data: Dictionary, folder_path: String = "") -> ModManifest:
	var out := ModManifest.new()
	out.folder = folder_path
	out.id = StringName(String(data.get("id", "")).strip_edges())
	out.display_name = String(data.get("name", ""))
	out.version = String(data.get("version", ""))
	out.game_version = String(data.get("game_version", ""))
	out.pck_file = String(data.get("pck", ""))
	out.deps = _to_ids(data.get("deps", []))
	out.load_after = _to_ids(data.get("load_after", []))

	if out.id == &"":
		out.error = "manifest has no 'id'"
	elif not is_valid_id(String(out.id)):
		out.error = "'%s' is not a usable mod id (lowercase letters, digits and underscores; must start with a letter)" % out.id
	elif out.version == "":
		out.error = "mod '%s' has no 'version'" % out.id
	if out.display_name == "":
		out.display_name = String(out.id)
	return out

## The id doubles as a namespace prefix (`modid.thing`) and as a directory name
## inside the pack, so it is deliberately narrow: no dots (that's the separator),
## no slashes, no case to get wrong when a player reports a bug.
static func is_valid_id(candidate: String) -> bool:
	if candidate.is_empty():
		return false
	for index: int in candidate.length():
		var chr: String = candidate[index]
		var is_lower: bool = chr >= "a" and chr <= "z"
		var is_digit: bool = chr >= "0" and chr <= "9"
		if index == 0:
			if not is_lower:
				return false
			continue
		if not (is_lower or is_digit or chr == "_"):
			return false
	return true

func is_usable() -> bool:
	return error == ""

## Where this mod's pack mounts. Fixed by convention rather than declared, so a
## mod can never mount over `res://data/` and shadow the base game by accident.
func mount_root() -> String:
	return "res://mods/%s/" % id

## The root ContentPaths scans for this mod's `.tres`.
func content_root() -> String:
	return mount_root() + "data/"

func summary() -> String:
	return "%s (%s) v%s" % [display_name, id, version]

static func _to_ids(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if value is Array:
		for entry: Variant in value as Array:
			var id_text: String = String(entry).strip_edges()
			if id_text != "":
				out.append(StringName(id_text))
	return out
