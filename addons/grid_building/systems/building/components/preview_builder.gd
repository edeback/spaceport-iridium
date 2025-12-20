## PreviewBuilder
##
## Purpose
##   Manages the visual preview instance used during building placement. The class
##   requires the core runtime objects up-front: `BuildingSettings`, the
##   `GridTargetingState`, `BuildingState`, and a `GBLogger`. These are accepted
##   in the constructor so the caller is explicit about required dependencies.
##
##   In addition, `resolve_gb_dependencies(container)` exists to refresh or update
##   dependencies from a `GBCompositionContainer` if the container changes during
##   runtime (rare for tests but supported). The `GridTargetingState` is treated
##   as the single source of truth for the `positioner` — the preview will always
##   query the latest positioner when creating the preview.
class_name PreviewBuilder
extends GBInjectable

var _preview_factory: PreviewFactory
var _current_preview: Node2D = null
var _building_state : BuildingState
var _targeting_state : GridTargetingState
var _logger: GBLogger
var _building_settings: BuildingSettings


"""Construct a PreviewBuilder with explicit required dependencies.

	Args:
		p_building_settings: BuildingSettings - configuration for preview placement
		p_targeting_state: GridTargetingState - the authoritative targeting state
		p_building_state: BuildingState - building runtime state
		p_logger: GBLogger - logger for diagnostics
		p_container: GBCompositionContainer (optional) - the composition container
			that can be used later to refresh dependencies. If provided it will
			be stored and used by `create_preview` to find the current positioner.
"""
func _init(p_building_settings: BuildingSettings, p_targeting_state: GridTargetingState, p_building_state : BuildingState, p_logger: GBLogger) -> void:
	_building_settings = p_building_settings
	_targeting_state = p_targeting_state
	_building_state = p_building_state
	_logger = p_logger
	_preview_factory = PreviewFactory.new(_building_settings, _logger)


## Factory: Create a PreviewBuilder from a composition container.
## This provides a DRY creation path used by systems/tests that have a
## `GBCompositionContainer` holding the required runtime objects.
##
## Args:
##   p_building_settings: BuildingSettings - required settings (not always in container)
##   container: GBCompositionContainer - used to resolve targeting_state, building_state, logger
##
## Returns:
##   PreviewBuilder - constructed and wired, or null on failure
static func from_container(container: GBCompositionContainer) -> PreviewBuilder:
	var p_building_settings: BuildingSettings = container.get_settings().building
	var targeting_state: GridTargetingState = container.get_targeting_state()
	var building_state: BuildingState = container.get_states().building
	var logger: GBLogger = container.get_logger()
	var builder: PreviewBuilder = PreviewBuilder.new(p_building_settings, targeting_state, building_state, logger)
	return builder

## Refresh/resolve dependencies from the composition container.
## Returns: bool - True if dependencies were found, false otherwise.
func resolve_gb_dependencies(container: GBCompositionContainer) -> bool:
	_building_settings = container.get_building_settings()
	_targeting_state = container.get_targeting_state()
	_building_state = container.get_states().building
	_logger = container.get_logger()
	_preview_factory = PreviewFactory.new(_building_settings, _logger)
	return true

## Validates that all required dependencies are properly set.
## Returns:
##   Array[String] - List of validation issues (empty if valid)
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []

	if not _targeting_state:
		issues.append("GridTargetingState is not set")

	if not _building_state:
		issues.append("BuildingState is not set")

	if not _logger:
		issues.append("GBLogger is not set")

	if not _preview_factory:
		issues.append("PreviewFactory is not set")

	return issues

func initialize(p_building_settings: BuildingSettings, p_targeting_state: GridTargetingState, p_building_state : BuildingState, p_logger: GBLogger) -> void:
	# Backwards compatibility helper - prefer explicit constructor instead
	push_warning("PreviewBuilder.initialize is deprecated; use constructor injection instead.")
	_building_settings = p_building_settings
	_targeting_state = p_targeting_state
	_building_state = p_building_state
	_logger = p_logger
	if not _preview_factory:
		_preview_factory = PreviewFactory.new(p_building_settings, p_logger)

## Spawns a new preview for the given placeable.
## Clears the previous one if active.
func create_preview(p_placeable: Placeable) -> Node2D:
	clear_preview()
	# Resolve the most up-to-date positioner from the single source of truth.
	var positioner : Node2D = _targeting_state.positioner
	_current_preview = _preview_factory.instance_preview(p_placeable, positioner)

	assert(_current_preview != null, "Preview instance must not be null after creation")
	if not _current_preview:
		if _logger:
			_logger.log_error( "Failed to instance preview for placeable: %s" % p_placeable)

	# Update runtime states to point to the newly created preview
	if _building_state != null:
		_building_state.preview = _current_preview
	if _targeting_state != null:
		_targeting_state.target = _current_preview
		# CRITICAL: Add preview to collision exclusions to prevent self-collision detection
		# The preview object should not detect collisions with itself when indicators are checking placement validity
		if not _targeting_state.collision_exclusions.has(_current_preview):
			_targeting_state.collision_exclusions.append(_current_preview)
			if _logger and _logger.is_trace_enabled():
				_logger.log_trace("[PreviewBuilder] Added preview to collision_exclusions: %s" % _current_preview.name)

	return _current_preview

## Get the object current previewed for placement
func get_preview() -> Node2D:
	return _current_preview if _current_preview != null else null

## Frees the active preview node.
func clear_preview():
	if is_instance_valid(_current_preview):
		# Remove from collision exclusions before clearing
		if _targeting_state != null:
			var idx = _targeting_state.collision_exclusions.find(_current_preview)
			if idx >= 0:
				_targeting_state.collision_exclusions.remove_at(idx)
				if _logger and _logger.is_trace_enabled():
					_logger.log_trace("[PreviewBuilder] Removed preview from collision_exclusions: %s" % _current_preview.name)
		
		# Store references before clearing
		var parent = _current_preview.get_parent()

		# Remove from parent safely
		if parent and is_instance_valid(parent):
			parent.remove_child(_current_preview)

		# Free the node
		_current_preview.queue_free()
	_current_preview = null

	if _targeting_state != null and _building_state != null and _targeting_state.target == _building_state.preview:
		_targeting_state.target = null
	if _building_state != null:
		_building_state.preview = null

func align_to_grid(collision_shape_global_position : Vector2):
	if _building_state == null or _building_state.preview == null:
		return
	var tile_size = _building_state.get_tile_size()
	var preview_offset := Vector2(
		int(collision_shape_global_position.x) % tile_size.x,
		int(collision_shape_global_position.y) % tile_size.y
	)
	_building_state.preview.global_position += preview_offset

## Repositions the preview in world space.
func update_position(p_position: Vector2):
	if _current_preview:
		_current_preview.global_position = p_position

## Optional: Check if a preview is currently being shown.
func has_active_preview() -> bool:
	return is_instance_valid(_current_preview)
