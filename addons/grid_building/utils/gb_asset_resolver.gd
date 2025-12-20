## Centralized asset resolver for loading Grid Building resources from folders.
##
## Provides unified loading functionality for placeables, category tags, and other
## Grid Building assets. Supports both folder-based loading and individual asset arrays.
## Handles resource validation and provides consistent error handling across the plugin.
class_name GBAssetResolver
extends RefCounted

## Result structure for asset loading operations
class LoadResult:
	var assets: Array = []
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	func is_successful() -> bool:
		return errors.is_empty()
	
	func has_warnings() -> bool:
		return not warnings.is_empty()
	
	func get_summary() -> String:
		var parts: Array[String] = []
		parts.append("Loaded: %d assets" % assets.size())
		if not errors.is_empty():
			parts.append("Errors: %d" % errors.size())
		if not warnings.is_empty():
			parts.append("Warnings: %d" % warnings.size())
		return "[%s]" % ", ".join(parts)

## Loads placeables from a folder path, maintaining backward compatibility with PlaceableLoader
static func load_placeables(folder_path: String, individual_placeables: Array[Placeable] = []) -> Array[Placeable]:
	var result := load_assets_of_type(folder_path, Placeable, individual_placeables)
	if not result.is_successful():
		push_error("Failed to load placeables from '%s': %s" % [folder_path, str(result.errors)])
	
	# Convert generic array to typed array
	var typed_result: Array[Placeable] = []
	for asset in result.assets:
		if asset is Placeable:
			typed_result.append(asset as Placeable)
	return typed_result

## Loads placeables and returns detailed LoadResult for advanced error handling
static func load_placeables_with_result(folder_path: String, individual_placeables: Array[Placeable] = []) -> LoadResult:
	return load_assets_of_type(folder_path, Placeable, individual_placeables)

## Loads category tags from a folder path
static func load_category_tags(folder_path: String, individual_tags: Array[CategoricalTag] = []) -> Array[CategoricalTag]:
	var result := load_assets_of_type(folder_path, CategoricalTag, individual_tags)
	if not result.is_successful():
		push_error("Failed to load category tags from '%s': %s" % [folder_path, str(result.errors)])
	
	# Convert generic array to typed array
	var typed_result: Array[CategoricalTag] = []
	for asset in result.assets:
		if asset is CategoricalTag:
			typed_result.append(asset as CategoricalTag)
	return typed_result

## Loads category tags and returns detailed LoadResult for advanced error handling
static func load_category_tags_with_result(folder_path: String, individual_tags: Array[CategoricalTag] = []) -> LoadResult:
	return load_assets_of_type(folder_path, CategoricalTag, individual_tags)

## Loads placeable sequences from a folder path
static func load_placeable_sequences(folder_path: String, individual_sequences: Array[PlaceableSequence] = []) -> Array[PlaceableSequence]:
	var result := load_assets_of_type(folder_path, PlaceableSequence, individual_sequences)
	if not result.is_successful():
		push_error("Failed to load placeable sequences from '%s': %s" % [folder_path, str(result.errors)])
	
	# Convert generic array to typed array
	var typed_result: Array[PlaceableSequence] = []
	for asset in result.assets:
		if asset is PlaceableSequence:
			typed_result.append(asset as PlaceableSequence)
	return typed_result

## Loads placeable sequences and returns detailed LoadResult for advanced error handling
static func load_placeable_sequences_with_result(folder_path: String, individual_sequences: Array[PlaceableSequence] = []) -> LoadResult:
	return load_assets_of_type(folder_path, PlaceableSequence, individual_sequences)

## Generic asset loading function that can load any resource type from a folder
static func load_assets_of_type(folder_path: String, asset_type: GDScript, individual_assets: Array = []) -> LoadResult:
	var result := LoadResult.new()
	
	# Start with individual assets if provided
	for asset in individual_assets:
		if asset != null and asset.get_script() == asset_type:
			result.assets.append(asset)
		elif asset != null:
			result.warnings.append("Individual asset type mismatch: expected %s, got %s" % [asset_type.get_global_name(), asset.get_class()])
		else:
			result.warnings.append("Individual asset is null")
	
	# Load from folder if path is provided
	if folder_path != null and folder_path != "":
		var folder_result := _load_from_folder(folder_path, asset_type)
		result.assets.append_array(folder_result.assets)
		result.errors.append_array(folder_result.errors)
		result.warnings.append_array(folder_result.warnings)
	
	return result

## Internal helper to load assets from a folder
static func _load_from_folder(folder_path: String, asset_type: GDScript) -> LoadResult:
	var result := LoadResult.new()
	
	var dir := DirAccess.open(folder_path)
	if dir == null:
		result.errors.append("Failed to open directory: %s" % folder_path)
		return result
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := folder_path.path_join(file_name)
			var load_result := _load_single_asset(full_path, asset_type, true) # Tolerate type mismatches in folder loading
			
			if load_result.asset != null:
				result.assets.append(load_result.asset)
			elif not load_result.errors.is_empty():
				# Only add errors that are not type mismatches (tolerated in folder loading)
				for error in load_result.errors:
					if not error.begins_with("Resource type mismatch"):
						result.errors.append(error)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return result

## Result structure for single asset loading
class SingleAssetResult:
	var asset: Resource = null
	var errors: Array[String] = []

## Internal helper to load a single asset file with tolerance for type mismatches
static func _load_single_asset(file_path: String, expected_type: GDScript, tolerate_type_mismatch: bool = false) -> SingleAssetResult:
	var result := SingleAssetResult.new()
	
	if not ResourceLoader.exists(file_path):
		result.errors.append("Resource file does not exist: %s" % file_path)
		return result
	
	var resource := ResourceLoader.load(file_path)
	if resource == null:
		result.errors.append("Failed to load resource: %s" % file_path)
		return result
	
	# Check if the resource is of the expected type
	var is_correct_type := false
	
	# Check if resource has the expected script type
	if resource.get_script() == expected_type:
		is_correct_type = true
	# Check if resource inherits from expected class (for built-in types)
	elif expected_type.get_global_name() != "":
		var expected_class_name := expected_type.get_global_name()
		is_correct_type = resource.get_class() == expected_class_name or resource.has_method("get_class") and resource.get_class() == expected_class_name
	
	if is_correct_type:
		result.asset = resource
	else:
		var expected_name := expected_type.get_global_name() if expected_type.get_global_name() != "" else str(expected_type)
		var message := "Resource type mismatch in '%s': expected %s, got %s" % [file_path, expected_name, resource.get_class()]
		if tolerate_type_mismatch:
			# For folder loading, type mismatches are just warnings - skip the file
			# This is expected when a folder contains mixed resource types
			pass # Just skip - don't even warn since this is normal
		else:
			result.errors.append(message)
	
	return result

## Validates that a folder path exists and is accessible
static func validate_folder_path(folder_path: String) -> bool:
	if folder_path == null or folder_path == "":
		return false
	
	var dir := DirAccess.open(folder_path)
	return dir != null

## Gets diagnostic information about a folder's contents
static func get_folder_diagnostics(folder_path: String) -> Dictionary:
	var diagnostics := {
		"exists": false,
		"total_files": 0,
		"tres_files": 0,
		"subdirectories": 0,
		"sample_files": []
	}
	
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return diagnostics
	
	diagnostics.exists = true
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var file_count := 0
	
	while file_name != "" and file_count < 20:  # Limit sample size
		if dir.current_is_dir():
			diagnostics.subdirectories += 1
		else:
			diagnostics.total_files += 1
			if file_name.ends_with(".tres"):
				diagnostics.tres_files += 1
			
			if diagnostics.sample_files.size() < 5:
				diagnostics.sample_files.append(file_name)
		
		file_name = dir.get_next()
		file_count += 1
	
	dir.list_dir_end()
	return diagnostics