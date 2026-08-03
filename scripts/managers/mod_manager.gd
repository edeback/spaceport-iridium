extends Node

## Finds, validates and mounts mods (WI-47 M1). The one manager that is an
## autoload rather than a node under main.tscn's `Managers/`, and it has to be:
## content is scanned from statics that the *main menu* already uses (difficulty
## levels, skills, the job registry), so mounting cannot wait for main.tscn.
## It is ordered first in project.godot, before Global and SignalBus - which is
## why nothing here emits a signal or touches Global. There is nobody to talk to
## yet; the log and the accessors below are the whole reporting surface until the
## mod list UI exists.
##
## No `class_name`, same as global.gd and signal_bus.gd: an autoload named
## ModManager and a global class named ModManager are a name collision.
##
## The shape of a mod on disk:
##     user://mods/<folder>/mod.json     <- read first, decides everything
##     user://mods/<folder>/<name>.pck   <- mounted at res://mods/<id>/
##
## Fail soft is the whole design (WI-47 decision 4). A malformed manifest, a
## missing dependency, a pack that won't mount, a pack whose contents are in the
## wrong place - each of those costs the player that one mod and a log line, and
## the game keeps running.

const MODS_DIR: String = "user://mods/"

var _loaded: Array[ModManifest] = []
var _problems: PackedStringArray = PackedStringArray()
var _warnings: PackedStringArray = PackedStringArray()
## Packs cannot be unmounted, so loading twice would double-mount everything.
var _has_loaded: bool = false

func _ready() -> void:
	load_mods()

## Discovers, orders and mounts every mod in user://mods/. Safe to call once;
## subsequent calls are ignored, because ProjectSettings.load_resource_pack() has
## no counterpart and a second pass would mount the same packs again.
func load_mods() -> void:
	if _has_loaded:
		return
	_has_loaded = true

	var manifests: Array[ModManifest] = _discover()
	if manifests.is_empty() and _problems.is_empty():
		return

	var resolution: ModRegistry.Resolution = ModRegistry.resolve(manifests, _game_version())
	_problems.append_array(resolution.problems)
	_warnings.append_array(resolution.warnings)

	for manifest: ModManifest in resolution.ordered:
		if _mount(manifest):
			_loaded.append(manifest)

	_report()

# --- discovery ------------------------------------------------------------------

func _discover() -> Array[ModManifest]:
	var out: Array[ModManifest] = []
	var mods_dir: DirAccess = DirAccess.open(MODS_DIR)
	if mods_dir == null:
		# No mods directory at all is the normal case, not a problem.
		return out
	for folder_name: String in mods_dir.get_directories():
		var folder: String = MODS_DIR.path_join(folder_name)
		var manifest_path: String = folder.path_join(ModManifest.MANIFEST_FILE)
		if not FileAccess.file_exists(manifest_path):
			_problems.append("%s has no %s - not a mod folder" % [folder, ModManifest.MANIFEST_FILE])
			continue
		var manifest: ModManifest = _read_manifest(manifest_path, folder)
		if manifest != null:
			out.append(manifest)
	return out

func _read_manifest(manifest_path: String, folder: String) -> ModManifest:
	var text: String = FileAccess.get_file_as_string(manifest_path)
	if text == "":
		_problems.append("%s is empty or unreadable" % manifest_path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		_problems.append("%s is not valid JSON" % manifest_path)
		return null
	return ModManifest.from_dict(parsed as Dictionary, folder)

# --- mounting --------------------------------------------------------------------

func _mount(manifest: ModManifest) -> bool:
	manifest.pck_path = _resolve_pck(manifest)
	if manifest.pck_path == "":
		return false

	# replace_files = false is mandatory, not stylistic (WI-47 M9 spike): an
	# exported pack carries res://.godot/global_script_class_cache.cfg,
	# res://.godot/uid_cache.bin and res://project.binary alongside the mod's own
	# files, and the default would let any mod shadow those - and every vanilla
	# resource - by existing.
	if not ProjectSettings.load_resource_pack(manifest.pck_path, false):
		_problems.append("mod '%s': %s could not be mounted" % [manifest.id, manifest.pck_path])
		return false

	# Mounted, and there is no way to undo that, so from here on a problem is
	# reported rather than prevented.
	if not _has_content(manifest.mount_root()):
		_problems.append(("mod '%s' mounted but nothing is at %s - its pack was built with the wrong "
				+ "layout, the mod's files must live at that path inside the .pck")
				% [manifest.id, manifest.mount_root()])
		return false

	ContentPaths.register_mod_root(manifest.content_root(), manifest.id)
	return true

func _resolve_pck(manifest: ModManifest) -> String:
	if manifest.pck_file != "":
		var declared: String = manifest.folder.path_join(manifest.pck_file)
		if not FileAccess.file_exists(declared):
			_problems.append("mod '%s' names %s in its manifest, but that file isn't there"
					% [manifest.id, manifest.pck_file])
			return ""
		return declared

	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(manifest.folder)
	if dir != null:
		for file_name: String in dir.get_files():
			if file_name.get_extension().to_lower() == "pck":
				found.append(file_name)
	if found.is_empty():
		_problems.append("mod '%s' has no .pck in %s" % [manifest.id, manifest.folder])
		return ""
	if found.size() > 1:
		_problems.append("mod '%s' has %d .pck files (%s) - name the one to load with a \"pck\" entry in its manifest"
				% [manifest.id, found.size(), ", ".join(found)])
		return ""
	return manifest.folder.path_join(found[0])

## Does anything actually live at `path` inside the mounted pack? Mirrors
## ResourceScanner's two-step: PCK contents surface through the resource index in
## an exported build and through the real filesystem in the editor.
func _has_content(path: String) -> bool:
	if not ResourceLoader.list_directory(path).is_empty():
		return true
	return DirAccess.open(path) != null

# --- reporting -------------------------------------------------------------------

func _report() -> void:
	for manifest: ModManifest in _loaded:
		print("[mods] loaded %s from %s" % [manifest.summary(), manifest.pck_path])
	for warning: String in _warnings:
		push_warning("[mods] " + warning)
	for problem: String in _problems:
		push_warning("[mods] " + problem)
	if not _loaded.is_empty() or not _problems.is_empty():
		print("[mods] %d loaded, %d not loaded" % [_loaded.size(), _problems.size()])

# --- queries ---------------------------------------------------------------------

## Mods that mounted, in load order.
func get_loaded() -> Array[ModManifest]:
	return _loaded.duplicate()

func is_loaded(id: StringName) -> bool:
	for manifest: ModManifest in _loaded:
		if manifest.id == id:
			return true
	return false

## Why mods didn't load, in player-facing words. The mod list screen renders
## these; until it exists they are warnings in the log.
func get_problems() -> PackedStringArray:
	return _problems.duplicate()

func get_warnings() -> PackedStringArray:
	return _warnings.duplicate()

## id + version per loaded mod - what M11 writes into a save's `meta` block so a
## save can tell the player which mods it was built with.
func mod_records() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for manifest: ModManifest in _loaded:
		out.append({"id": String(manifest.id), "version": manifest.version})
	return out

func _game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", ""))
