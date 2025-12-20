## Loads placeables from a location on the disk
class_name PlaceableLoader
extends RefCounted

## Finds all placeables at the path and sub directories and returns them
## as an array
static func get_placeables(p_path: String) -> Array[Placeable]:
	var placeables: Array[Placeable] = []
	var dir := DirAccess.open(p_path)
	if dir == null:
		push_error("Failed to open directory: %s" % p_path)
		return placeables

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := p_path.path_join(file_name)
			var res := ResourceLoader.load(full_path)
			if res is Placeable:
				placeables.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return placeables
