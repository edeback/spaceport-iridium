class_name ResourceScanner
extends RefCounted

## Shared recursive .tres scanner for every system that discovers data
## resources by directory (build menu modules, unlocks, local upgrades).
## Exported builds don't expose plain files: PCK contents surface through
## ResourceLoader.list_directory, and remapped resources can appear with a
## ".remap" (or ".import") suffix. Both are handled here so callers get
## clean res:// paths that ResourceLoader.load accepts in editor and
## export alike.

static func scan_paths(path: String) -> Array[String]:
	var out: Array[String] = []
	_scan_dir(path.rstrip("/"), out)
	return out

static func _scan_dir(path: String, out: Array[String]) -> void:
	var entries: PackedStringArray = ResourceLoader.list_directory(path)
	if entries.is_empty():
		# Not in the resource index (or empty) - try the real filesystem.
		_scan_dir_diraccess(path, out)
		return
	for entry: String in entries:
		if entry.ends_with("/"):
			_scan_dir(path.path_join(entry.rstrip("/")), out)
			continue
		var file_name: String = _clean_file_name(entry)
		if file_name.get_extension() == "tres":
			out.append(path.path_join(file_name))

static func _scan_dir_diraccess(path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			_scan_dir_diraccess(path.path_join(entry), out)
		else:
			var file_name: String = _clean_file_name(entry)
			if file_name.get_extension() == "tres":
				out.append(path.path_join(file_name))
		entry = dir.get_next()
	dir.list_dir_end()

static func _clean_file_name(entry: String) -> String:
	return entry.trim_suffix(".remap").trim_suffix(".import")
