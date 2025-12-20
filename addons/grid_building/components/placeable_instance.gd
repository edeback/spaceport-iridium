## Component to attach to objects that are placed by the building system by
## remembering the placeable resource that they were instanced from
class_name PlaceableInstance
extends GBGameNode

signal placeable_path_changed(placeable_path: String)

## Path to the placeable resource that creates or recreates instances
## of this gameplay object type
@export_file("*.tres", "*.res") var placeable_path: String:
	set(value):
		if placeable_path == value:
			return

		placeable_path = value
		placeable_path_changed.emit(placeable_path)

		if not placeable_path.is_empty():
			placeable = load(placeable_path)

const default_name = "PlaceableInstance"
const group_name = "PlaceableInstance"

var placeable: Placeable

var _logger: GBLogger


func _init(p_placeable_path: String = "") -> void:
	placeable_path = p_placeable_path
	add_to_group(group_name)


func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	_logger = p_container.get_logger()


func validate_setup() -> bool:
	var passing = true

	if not GBValidation.check_not_null(self, ["placeable"]):
		passing = false

	if not is_in_group(group_name):
		_logger.log_warning(
			"PlaceableInstance is not in group %s even though expected to be so." % group_name
		)
		passing = false

	return passing


## Saves the location and reference to placeable reference
## so a new instance of the object can be created on load
##
## Only provides enough data for the PackedScene to be instance
## but does not by itself remember the full state of the scene object
func save(p_include_uid: bool) -> Dictionary:
	var parent = get_parent()
	var save = {}
	save[Names.INSTANCE_NAME] = parent.name
	save[Names.TRANSFORM] = var_to_str(parent.transform)
	save[Names.PLACEABLE] = placeable.get_load_data(p_include_uid)
	return save


## Instances a new copy of the saved PlaceableInstance placeable's packed_scene
##
## This only recreates the object as the PackedScene in the Placeable resource
## dictates plus adding a new PlaceableInstance node.
##
## If you want other data to persist, you will need to create your one save methods
static func instance_from_save(p_save: Dictionary, p_instance_parent: Node) -> Node:
	var placeable: Placeable

	if p_save.has(Names.PLACEABLE):
		placeable = Placeable.load_resource(p_save[Names.PLACEABLE])

	if not is_instance_valid(placeable):
		push_error(
			(
				"Placeable resource could not be located. Instancing of %s failed!"
				% "PlaceableInstance"
			)
		)

	var instance: Node = placeable.packed_scene.instantiate()
	p_instance_parent.add_child(instance)
	instance.name = p_save[Names.INSTANCE_NAME]
	instance.transform = str_to_var(p_save[Names.TRANSFORM])

	if instance.find_children("", "PlaceableInstance", true, false).is_empty():  # Only add one, if the root scene does not already have a PlaceableInstance
		var placeable_instance = PlaceableInstance.new(placeable.resource_path)
		instance.add_child(placeable_instance)

	return instance


## Shared name constants
##
## Be very careful about changing these because game saves do not know
## if you change the string key of loaded properties.
class Names:
	const INSTANCE_NAME = "instance_name"
	const PLACEABLE = "placeable"
	const TRANSFORM = "transform"
