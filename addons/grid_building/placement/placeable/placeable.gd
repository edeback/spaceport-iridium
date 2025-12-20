## Object that can be placed into the game world by instancing the packed_scene.
@tool
class_name Placeable
extends GBResource

## Display name for in-game reading.
@export var display_name : StringName

## Texture icon for UI elements.
@export var icon : Texture2D

## Scene to instance when placed.
@export var packed_scene : PackedScene

## Category tags for grouping placeables.
@export var tags : Array[CategoricalTag]

## Placement rules specific to this placeable.
## If [member ignore_base_rules] is [code]false[/code], these rules are combined with
## base rules from [member GBSettings.placement_rules].
@export var placement_rules : Array[PlacementRule] = []

## When [code]true[/code], skips base placement rules from [member GBSettings.placement_rules]
## and uses ONLY the rules defined in [member placement_rules].
##
## Use cases:
## - [code]false[/code] (default): Inherit common rules + add object-specific rules
## - [code]true[/code]: Completely custom validation (e.g., special objects with unique placement logic)
@export var ignore_base_rules = false

func _init(p_packed_scene : PackedScene = null, p_placement_rules : Array[PlacementRule] = []):
	packed_scene = p_packed_scene
	placement_rules = p_placement_rules
		
## Gets a serialized reference to the placeable for both the FILE_PATH and the file path as a backup
func get_load_data(p_include_uid : bool) -> Dictionary:
	var dictionary = {
		Names.FILE_PATH: resource_path,
	}
	
	if p_include_uid: # Only works in editor
		dictionary[Names.UID] = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(resource_path))
	
	return dictionary
	
## Function to help location the placeable using FILE_PATH or file path as backup and returning it
static func load_resource(p_load_data : Dictionary) -> Placeable:
	var placeable : Placeable
	
	if OS.has_feature("editor") && p_load_data.has(Names.UID): # UIDs only load in editor
		var uid_str : String = p_load_data[Names.UID]
		var uid_int : int = ResourceUID.text_to_id(uid_str)
		
		if ResourceUID.has_id(uid_int):
			placeable = load(uid_str)
			return placeable
	
	var file_path = p_load_data[Names.FILE_PATH]
		
	placeable = load(file_path)
	return placeable

## Gets the name of the root node in the packed_scene
func get_packed_root_name() -> StringName:
	if packed_scene:
		return packed_scene._bundled["names"][0]
		
	return &"NO_PACKED_SCENE"

## Returns an array of issues that were found in the placeable
func get_editor_issues() -> Array[String]:
	var issues : Array[String] = []
	
	if packed_scene == null:
		issues.append("[packed_scene] is null but should be set to the scene you want to instance from a placeable.")
	
	for rule_idx in range(0, placement_rules.size(), 1):
		if placement_rules[rule_idx] == null:
			issues.append("Placement rule [%d] is null at %s" % [rule_idx, resource_path])
		
	return issues

## Returns all found runtime issues including the editor issues as a baseline.
func get_runtime_issues() -> Array[String]:
	var issues : Array[String] = []

	issues.append_array(get_editor_issues())

	return issues

## In editor validation
func _validate_property(property: Dictionary):
	var all_passing = true
	
	if property.name == Names.FILE_PATH:
		property.hint = PROPERTY_HINT_OBJECT_ID
	
	if property.name == "scene" && packed_scene == null:
		push_warning("[packed_scene] is null but should be set to the scene you want to instance from a placeable.")
		all_passing = false
	
	if property.name == "placement_rules":
		for rule_idx in range(0, placement_rules.size(), 1):
			if not is_instance_valid(placement_rules[rule_idx]):
				push_warning("Building rule [%s] is NOT valid at %s" % [str(rule_idx),resource_path])
				all_passing = false
			

class Names:
	const UID = "uid" # Only Editor
	const FILE_PATH = "file_path"
