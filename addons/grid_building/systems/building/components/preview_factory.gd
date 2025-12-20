class_name PreviewFactory
extends GBInjectable

## Creates a PreviewFactory with dependency injection from container.
## Container serves as single source of truth for all dependencies.
## Parameters:
##   container: GBCompositionContainer - The dependency container
## Returns:
##   PreviewFactory - Fully configured preview factory with validated dependencies
static func create_with_injection(container: GBCompositionContainer) -> PreviewFactory:
	# Get dependencies from container as single source of truth
	var logger = container.get_logger()
	var settings = container.get_building_settings()
	
	var factory = PreviewFactory.new(settings, logger)
	
	# Inject dependencies
	factory.resolve_gb_dependencies(container)
	
	# Validate dependencies were properly injected
	var issues = factory.get_runtime_issues()
	if not issues.is_empty():
		logger.log_warnings(issues)
	
	return factory

var _building_settings : BuildingSettings
var _logger: GBLogger
## Receives injected dependencies from the composition container.
## Assigns logger and building settings if available.
## [b]Returns[/b]: [i]bool[/i] - True if dependencies were successfully resolved, false otherwise
func resolve_gb_dependencies(p_config: GBCompositionContainer) -> bool:
	if p_config == null:
		return false
		
	_logger = p_config.get_logger()
	_building_settings = p_config.get_building_settings()
	return true
		
	
## Validates that all required dependencies and state are properly set.
## Returns an empty array if valid, or a list of issues if not.
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	if not _logger:
		issues.append("GBLogger is not set")
	return issues

func _init(p_building_settings : BuildingSettings, p_logger : GBLogger):
	_building_settings = p_building_settings
	_logger = p_logger

## Places an instance of the p_placeable scene onto the positioner,
## and strips it of any script types not declared in preview_kept_script_types
##
## The root node of the scene will be assigned the preview_root_script if any is in the settings
func instance_preview(p_placeable : Placeable, p_positioner : Node2D) -> Node2D:
	var root_script : Script = _building_settings.preview_root_script
	
	if p_placeable == null:
		_logger.log_warning( "Placeable is null, cannot instance preview.")
		return null

	var validation_issues : Array[String] = p_placeable.get_editor_issues()

	if not validation_issues.is_empty():
		_logger.log_issues(validation_issues)
		_logger.log_warning( BuildingSystem.WARNING_INVALID_PLACEABLE % p_placeable)
		return null
	
	# Instantiate the packed scene directly (do not duplicate — duplication may strip children/scripts)
	var new_instance = p_placeable.packed_scene.instantiate()
	
	# Mark the preview as a preview so save systems can filter it out
	new_instance.set_meta("gb_preview", true)

	# Use centralized utility to remove scripts and disable processing
	GBManipulationCopyUtils.prepare_manipulation_copy(new_instance, _building_settings.preview_kept_script_types)

	if root_script and new_instance.get_script() == null:
		new_instance.set_script(root_script)

	# Handle name conflicts before adding to parent
	var desired_name = p_placeable.get_packed_root_name()
	var existing_child = p_positioner.get_node_or_null(NodePath(desired_name))
	if existing_child and existing_child != new_instance:
		# Remove the existing child with the same name (likely an old preview)
		p_positioner.remove_child(existing_child)
		existing_child.queue_free()

	new_instance.name = desired_name
	p_positioner.add_child(new_instance)
	# CRITICAL: Ensure preview is centered on positioner (local position 0,0)
	# This ensures collision shapes are properly aligned with tile grid
	new_instance.position = Vector2.ZERO
	new_instance.z_index = _building_settings.preview_instance_z_index

	# Debug: log the children of the created preview and detect collision nodes
	if _logger:
		var child_names := []
		for c in new_instance.get_children():
			child_names.append(str(c.get_class()) + ":" + str(c.name))
		_logger.log_debug( "instance_preview: created preview '%s' with children=%s" % [new_instance.name, str(child_names)])
		# Detect collision-related nodes
		var collision_nodes := []
		for c in new_instance.get_children():
			if c is CollisionPolygon2D or c is CollisionShape2D or c.get_class().find("Collision") != -1:
				collision_nodes.append(str(c.get_class()) + ":" + str(c.name))
		if collision_nodes.size() == 0:
			_logger.log_debug( "instance_preview: No collision nodes found directly under preview root")
		else:
			_logger.log_debug( "instance_preview: collision nodes=%s" % [str(collision_nodes)])
	return new_instance
