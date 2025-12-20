## Resource classes built for the grid_building plugin
@icon("res://addons/grid_building/icons/kenney/menuGrid.png")
class_name GBResource
extends Resource

func get_editor_issues() -> Array[String]:
	return ["Abstract method. Not implemented by inheriting class on resource %s." % get_debug_identifier()]

func get_runtime_issues() -> Array[String]:
	return ["Abstract method. Not implemented by inheriting class on resource %s." % get_debug_identifier()]

## Get a string identifying name for the resource for debugging purposes
func get_debug_identifier() -> StringName:
	# Prefer a saved path, then metadata or common name properties, then a fallback.
	if resource_path != "":
		return StringName(resource_path)
	
	if resource_name != "":
		return StringName(resource_name)
	
	# Last resort: class + instance id to give something unique and non-empty
	return StringName("%s[%d]" % [get_class(), get_instance_id()])
