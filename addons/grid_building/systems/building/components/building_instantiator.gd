## Responsible for instantiating and setting up a placed building object in the world.
## This component handles the creation of a building instance, assigning its transform,
## and attaching necessary components like PlaceableInstance.
class_name BuildingInstantiator
extends GBSystemsComponent

var _indicator_context: IndicatorContext
var _building_state: BuildingState
var _building_settings: BuildingSettings

const DEFAULT_NAME = "BuildingInstantiator"
const WARNING_INVALID_PLACEABLE = "Invalid placeable resource. Can't instantiate. [%s]"
const WARNING_NO_PREVIEW = "No preview instance provided to instantiate from. Returning null."

func _init(
	p_indicator_context: IndicatorContext = null,
	p_building_state: BuildingState = null,
	p_building_settings: BuildingSettings = null
) -> void:
	_indicator_context = p_indicator_context
	_building_state = p_building_state
	_building_settings = p_building_settings
	name = DEFAULT_NAME

## Resolve dependencies from the composition container.[br][br]
## [code]p_container[/code]: [i]GBCompositionContainer[/i] - Container with system dependencies
func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	_indicator_context = p_container.get_contexts().indicator
	_building_state = p_container.get_states().building
	_building_settings = p_container.config.settings.building

## Instantiates a Placeable's scene, sets its properties, and adds it to the world.
## Returns the instantiated Node2D if successful, otherwise null.[br][br]
## [code]p_placeable[/code]: [i]Placeable[/i] - The Placeable resource to instantiate[br]
## [code]p_preview[/code]: [i]Node2D[/i] - The preview node that holds the desired global_transform
func instantiate_building(p_placeable: Placeable, p_preview: Node2D) -> Node2D:
	if not is_instance_valid(p_placeable):
		push_warning(WARNING_INVALID_PLACEABLE % p_placeable)
		return null
	if not is_instance_valid(p_preview):
		push_warning(WARNING_NO_PREVIEW)
		return null

	var instance = p_placeable.packed_scene.instantiate()

	# Add the instance to the designated parent node
	_building_state.placed_parent.add_child(instance)
	instance.owner = _building_state.placed_parent

	# Transfer the transform from the preview to the actual instance
	instance.global_transform = p_preview.global_transform
	instance.name = p_placeable.get_packed_root_name()

	# Optionally attach a PlaceableInstance component
	if (
		_building_settings.add_placeable_instance
		and not GBSearchUtils.find_first(instance, PlaceableInstance)
	):
		var placeable_instance = PlaceableInstance.new(p_placeable.resource_path)
		placeable_instance.name = PlaceableInstance.default_name
		instance.add_child(placeable_instance)

	# Execute any placement rules after instantiation
	if instance != null and is_instance_valid(_indicator_context):
		_indicator_context.get_manager().apply_rules()

	return instance
