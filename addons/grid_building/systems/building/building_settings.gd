@tool
## Configuration settings for the building system's behavior and appearance.
##
## Controls preview display, multi-build functionality, instance management, and other building-related parameters.
class_name BuildingSettings
extends GBResource

## List of Script Global Class Names that will be kept for preview instances when placing objects in build mode.[br][br]
## [code]preview_kept_script_types[/code]: [i]Array[String][/i] - Script class names to preserve during preview creation
@export var preview_kept_script_types : Array[String] = ["Manipulatable"]
		
## Add a placeable instance component node automatically to any instance objects placed by the building system.
## This node holds a reference to the placeable that created it to reinstate the scene between level loads.[br][br]
## [b]WARNING:[/b] It does this using file_path to the placeable resource. Files can move around a lot so you may consider implementing an ID database for looking up Placeables instead during gameplay to avoid losing reference the Placeable file.[br][br]
## [code]add_placeable_instance[/code]: [i]bool[/i] - Whether to automatically add PlaceableInstance component to placed objects
@export var add_placeable_instance = true

## The z index value to set preview instances to in order to control their rendering order.[br][br]
## [code]preview_instance_z_index[/code]: [i]int[/i] - Z-index for preview instance display ordering
@export var preview_instance_z_index = 100 :
	set(value):
		preview_instance_z_index = value

## Script to be added to the root of any preview instance node temporarily created by
## the building system after non-kept scripts are stripped out. Does not override
## an existing script in the root.
@export var preview_root_script : Script = load("uid://cufp4o5ctq6ak")

func get_editor_issues() -> Array[String]:
	return []

func get_runtime_issues() -> Array[String]:
	return []
