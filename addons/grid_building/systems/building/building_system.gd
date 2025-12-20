## Manages placement of objects in the game world.
##
## Handles preview, placement validation, and build actions. Uses tile collision indicators to show valid/invalid spots before placement. Checks all rules before adding objects to the world and emits signals for build success or failure.
class_name BuildingSystem
extends GBSystem

## Creates a BuildingSystem with injected dependencies from the container.
static func create_with_injection(container: GBCompositionContainer) -> BuildingSystem:
	var system = BuildingSystem.new()
	
	# Inject dependencies
	system.resolve_gb_dependencies(container)
	
	# Validate dependencies were properly injected
	var issues = system.get_runtime_issues()
	if not issues.is_empty():
		var logger = container.get_logger()
		logger.log_warnings(issues)
	
	return system

## Instantiates building objects for placement.
var _building_instantiator : BuildingInstantiator

## Collision polygons for placement indicators.
var placement_polygons: Array[CollisionPolygon2D]

## Preview layer index for buildable/unbuildable tiles.
var preview_layer: int

## Currently selected placeable resource.
var selected_placeable: Placeable

## Parent node for collision indicators.
var indicators_group: Node2D

#region Injected Dependencies
## Settings for grid building system operation.
var _building_settings : BuildingSettings

## Shared states for plugin systems.
var _states : GBStates

## Context for resolving references to current objects.
var _systems_context : GBSystemsContext

## Placement management and rules context.
var _indicator_context : IndicatorContext

var _actions : GBActions
var _logger : GBLogger

## Keep a reference to the container for lazy component creation
var _container: GBCompositionContainer

#endregion

var _preview_builder : PreviewBuilder

## The report of the active ongoing placement
var _report : PlacementReport

## legacy accessors expected in some validator/integration tests
func get_building_state():
	return _states.building if _states else null
func get_targeting_state():
	return _states.targeting if _states else null

## Tracks drag events for build button.
## InputEventScreenDrag instance used to track drag events for build actions.
## Updated as the user drags to new tiles during multi-build mode.
var _build_drag_event: InputEventScreenDrag


const WARNING_INVALID_PLACEABLE = "Invalid placeable resource. Can't instantiate. [%s]"
const WARNING_NO_PREVIEW = "No preview instance created to instantiate yet. Returning null."

#region Methods

## Returns true if system is ready to place a selected placeable (should already be set)
## Checks if the system is ready to build by validating the selected placeable and build context.
## Returns true if all build requirements are met and no issues are found.
func is_ready_to_place() -> bool:
	var issues : Array[String] = []

	if _states == null || _states.building == null || _states.targeting == null:
		issues.append("GBStates or required sub-states are not set")
	else:
		issues.append_array(_states.building.get_runtime_issues())
		issues.append_array(_states.targeting.get_runtime_issues())

	if selected_placeable == null:
		issues.append("No placeable resource selected.")
	if _indicator_context == null:
		issues.append("No indicator context available.")

	_logger.log_issues(issues)
	return issues.is_empty()

## Returns true if the building system is currently in build mode.
## Checks the current mode state to determine if build mode is active.
func is_in_build_mode() -> bool:
	return _states and _states.mode and _states.mode.current == GBEnums.Mode.BUILD

## Exits build mode and cleans up all build-related elements.
## Sets the mode to OFF, clears the preview, and tears down indicators.
func exit_build_mode() -> void:
	if _states and _states.mode:
		_states.mode.current = GBEnums.Mode.OFF
	_exit_build_cleanup()
	
func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	_systems_context = p_container.get_systems_context()
	_systems_context.set_system(self)
	_states = p_container.get_states()
	_building_settings = p_container.config.settings.building
	_actions = p_container.config.actions
	_indicator_context = p_container.get_contexts().indicator
	_logger = p_container.get_logger()
	_container = p_container # Store for later use in creating lazy components if needed
	
	_get_lazy_building_instantiator()

	# React to global mode changes so we can clear preview when leaving BUILD mode
	if _states and _states.mode and not _states.mode.mode_changed.is_connected(_on_mode_changed):
		_states.mode.mode_changed.connect(_on_mode_changed)

	_logger.log_issues(get_runtime_issues())

## Attempts to place a building at the current preview location if all placement rules pass.
## Validates all placement rules and emits success or failure signals based on the result. Returns the built Node2D if successful, null otherwise.
##
## [param p_build_type] Type of build operation (SINGLE, DRAG, or AREA). Defaults to SINGLE.
func try_build(p_build_type: GBEnums.BuildType = GBEnums.BuildType.SINGLE) -> PlacementReport:
	var manager: IndicatorManager = _indicator_context.get_manager()

	# Validate that we have a valid manager
	if not manager:
		push_error("IndicatorManager has not been set in IndicatorContext.")
		return null

	var previous_report := _report
	var preview := _get_lazy_preview_builder().get_preview()
	var previous_indicators := previous_report.indicators_report if previous_report != null else null
	_report = PlacementReport.new(get_builder_owner(), preview, previous_indicators, GBEnums.Action.BUILD)

	if _logger and _logger.is_trace_enabled():
		_logger.log_trace("[BuildingSystem] try_build called; selected_placeable=%s, manager=%s" % [str(selected_placeable), str(manager)])

	var placement_validation: ValidationResults = manager.validate_placement()

	if not placement_validation.is_successful():
		var diag_errors = placement_validation.get_errors()
		var validation_issues = placement_validation.get_issues()
		if _logger and _logger.is_trace_enabled():
			_logger.log_trace("[BuildingSystem] placement validation failed - errors: %s, issues: %s" % [str(diag_errors), str(validation_issues)])

		# Add both configuration errors (for developers) and validation issues (for users)
		for error in diag_errors:
			_report.add_issue(error)
		for issue in validation_issues:
			_report.add_issue(issue)

		report_failure(_report, p_build_type)
		return _report
	
	var placer := _states.building.get_owner()
	_report.placed = _build_instance(selected_placeable, _building_settings.add_placeable_instance)

	if _report.placed == null:
		var fail_msg = "[DIAG-BUILD] _build_instance returned null for selected_placeable=%s" % str(selected_placeable)
		if _logger and _logger.is_debug_enabled():
			_logger.log_debug(fail_msg)
		else:
			print(fail_msg)

		_report.add_issue("Failed to build instance for selected_placeable=%s" % str(selected_placeable))
		report_failure(_report, p_build_type)
		return _report

	# Check final success state - PlacementReport may have issues from indicators_report even if validation passed
	if _report.is_successful():
		report_built(_report, p_build_type)
	else:
		# Placement was built but PlacementReport has issues (likely from indicators_report)
		if _logger and _logger.is_debug_enabled():
			_logger.log_debug("[DIAG-BUILD] Built instance but PlacementReport has issues: %s" % str(_report.get_issues()))
		report_failure(_report, p_build_type)
	return _report

## Legacy API compatibility method for tests
## Attempts to place a building at the specified position
## Temporarily moves the targeting system to the position, attempts placement, then restores position
func try_build_at_position(p_global_position: Vector2) -> PlacementReport:
	if not _states or not _states.targeting or not _states.targeting.positioner:
		var failure_report := PlacementReport.new(get_builder_owner(), null, null, GBEnums.Action.BUILD)
		failure_report.add_issue("try_build_at_position: No targeting state or positioner available")
		return null
		
	var positioner : Node2D = _states.targeting.positioner
	
	var original_pos = positioner.global_position
	positioner.global_position = p_global_position
	var report : PlacementReport = try_build()
	positioner.global_position = original_pos
	
	return report

## Sets up a preview instance for the selected placeable.
## Switches to build mode, clears previous preview, and creates a new preview instance. Returns true if setup is successful.[br][br]
## [code]p_placeable[/code]: [i]Placeable[/i] - Placeable resource to create preview for
func enter_build_mode(p_placeable: Placeable) -> PlacementReport:
	var failure_report := PlacementReport.new(get_builder_owner(), _get_lazy_preview_builder().get_preview(), null, GBEnums.Action.BUILD)

	# Validate dependencies first - this will assert if IndicatorManager is missing
	if p_placeable == null:
		failure_report.add_issue("No placeable passed into enter build mode")

	if not _validate_build_ready():
		failure_report.add_issue("BuildingSystem is not ready to build")

	selected_placeable = p_placeable

	if not is_ready_to_place():
		failure_report.add_issue("Not able to build with placeable %s" % selected_placeable)

	clear_preview()

	if not failure_report.issues.is_empty():
		_states.mode.current = GBEnums.Mode.OFF
		report_failure(failure_report)
		return failure_report

	_states.mode.current = GBEnums.Mode.BUILD

	# Preconditions already validated by is_ready_to_place (fail-fast). Proceed immediately.
	var preview_instance = _get_lazy_preview_builder().create_preview(p_placeable)
	var setup_report : PlacementReport = _try_setup(preview_instance, selected_placeable.placement_rules)

	if _logger.is_debug_enabled():
		_logger.log_debug( "Entered build mode.")

		if _logger.is_verbose_enabled():
			_logger.log_verbose( setup_report.to_verbose_string())

	_report = setup_report

	return setup_report

## Removes the current preview instance.
## Removes the current preview instance and resets placement manager state.
## Called when exiting build mode or clearing preview.
func clear_preview():
	_get_lazy_preview_builder().clear_preview()
	# Guard: only tear down if a manager exists
	if _indicator_context and _indicator_context.has_manager():
		_indicator_context.get_manager().tear_down()

## Cleans up build mode elements and resets indicators.
## Cleans up build mode elements, clears preview, and resets indicator manager.
## Called when exiting build mode or switching modes.
func _exit_build_cleanup():
	# Resume automatic targeting now that build mode is complete
	if _states and _states.targeting:
		_states.targeting.clear_manual_target()
	
	clear_preview()
	if _indicator_context and _indicator_context.has_manager():
		_indicator_context.get_manager().tear_down()

## Handles input for building controls.
## Handles input events for building controls, including build confirmation and mode switching.
## Processes input based on current build mode and user actions.
func _unhandled_input(event: InputEvent):
	if InputMap.has_action(_actions.build_mode) and event.is_action_pressed(_actions.build_mode):
		if _states.mode.current == GBEnums.Mode.BUILD:
			_states.mode.current = GBEnums.Mode.OFF
			# Clear selected placeable when exiting build mode
			selected_placeable = null
		else:
			_states.mode.current = GBEnums.Mode.BUILD
	
	if _states.mode.current == GBEnums.Mode.BUILD:
		if InputMap.has_action(_actions.off_mode) and event.is_action_pressed(_actions.off_mode):
			_states.mode.current = GBEnums.Mode.OFF
		if InputMap.has_action(_actions.confirm_build) and event.is_action_pressed(_actions.confirm_build):
			# Skip building if no placeable is selected. Silent return when build confirmed before placeable selected
			if selected_placeable == null:
				return
				
			try_build()

## Creates a preview instance with limited functionality.
## Strips scripts not needed for preview and replaces root node script if set in config. Used for visual feedback before placement.[br][br]
## [code]p_placeable[/code]: [i]Placeable[/i] - Placeable resource to create preview instance for
func instance_preview(p_placeable: Placeable) -> Node2D:
	# Set selected placeable for compatibility
	selected_placeable = p_placeable
	var preview_instance : Node2D = _get_lazy_preview_builder().create_preview(p_placeable)
	var rules := p_placeable.placement_rules if p_placeable else []
	var placement_report : PlacementReport = _try_setup(preview_instance, rules)
	return preview_instance

## Validates that all required dependencies are set.
## This is called automatically when entering build mode, but can also be called manually
## after scene loads to check if all dependencies are properly configured.
## Returns list of validation issues (empty if valid).
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if not _states:
		issues.append("GBStates is not set")
	
	if not _building_settings:
		issues.append("BuildingSettings is not set")
		
	if not _actions:
		issues.append("GBActions is not set")
		
	if not _logger:
		issues.append("GBLogger is not set")
	
	# Additional runtime validation from original validate() method
	# Note: _preview_builder is created during resolve_gb_dependencies, so check for null gracefully
	var check_props: Array[String] = ["_indicator_context"]
	issues.append_array(GBValidation.check_not_null(self, check_props))
	
	# Note: _preview_builder is created lazily when needed, so no validation required
	# The lazy initialization pattern ensures it's created when first accessed
	
	return issues
	
## Get the current GBOwner of the building object which is the root node of the GBOwner in the active GBOwnerContext
## that is assigned to the BuildingState
func get_builder_owner() -> GBOwner:
	return _states.building.get_owner() if _states and _states.building else null

## Connects BuildingSystem to a DragManager scene component for drag-building support.
## Reports a successful build action through the BuildingState
##
## [param p_report] The placement report for the build action
## [param p_build_type] Type of build operation (SINGLE, DRAG, or AREA)
func report_built(p_report : PlacementReport, p_build_type: GBEnums.BuildType = GBEnums.BuildType.SINGLE) -> void:
	# Notify listeners
	var data := BuildActionData.new(selected_placeable, p_report, p_build_type)
	# DIAGNOSTIC: trace-level internal state logging for tests debugging signal wiring
	if _logger and _logger.is_trace_enabled():
		_logger.log_trace("[DIAG-BUILD] report_built: emitting success -- placed=%s, issues=%s" % [p_report.placed, p_report.get_issues()])
		# Compare _states instance identity if available on the container
		if _container:
			_logger.log_trace("[DIAG-BUILD] report_built: container states building instance=%s" % [_container.get_states().building])
			_logger.log_trace("[DIAG-BUILD] report_built: local _states building instance=%s" % [_states.building])
		# Signal connection diagnostics for deep debugging
		if _states and _states.building and _states.building.has_method("get_signal_connection_list"):
			var conn_list = _states.building.get_signal_connection_list("success")
			_logger.log_trace("[DIAG-BUILD] report_built: success signal connections count=%d" % [conn_list.size()])
	_states.building.success.emit(data)

## Reports a failed build action through the BuildingState
##
## [param p_report] The placement report for the build action
## [param p_build_type] Type of build operation (SINGLE, DRAG, or AREA)
func report_failure(p_report : PlacementReport, p_build_type: GBEnums.BuildType = GBEnums.BuildType.SINGLE) -> void:
	var data := BuildActionData.new(selected_placeable, p_report, p_build_type)
	_states.building.failed.emit(data)

## Private lazy getter for building instantiator.
## Creates and configures the instantiator if it doesn't exist.[br][br]
## [code]return[/code]: [i]BuildingInstantiator[/i] - The building instantiator instance
func _get_lazy_building_instantiator() -> BuildingInstantiator:
	if _building_instantiator == null:
		_building_instantiator = BuildingInstantiator.new(_indicator_context, _states.building, _building_settings)
		add_child(_building_instantiator)
	
	return _building_instantiator

## Private lazy getter for preview builder.
## Creates and configures the preview builder if it doesn't exist.[br][br]
## [code]return[/code]: [i]PreviewBuilder[/i] - The preview builder instance
func _get_lazy_preview_builder() -> PreviewBuilder:
	if _preview_builder == null:
		_preview_builder = PreviewBuilder.from_container(_container)
	
	return _preview_builder

func _try_setup(p_preview_instance : Node, p_placeable_rules : Array[PlacementRule]) -> PlacementReport:
	assert(p_preview_instance != null, "There must be a valid preview to start building")
	var manager := _indicator_context.get_manager()
	var targeting_state := _states.targeting
	
	# Set manual targeting mode - prevents TargetingShapeCast2D from overwriting target
	targeting_state.set_manual_target(p_preview_instance)
	
	var report : PlacementReport = manager.try_setup(p_placeable_rules, targeting_state, GBEnums.Action.BUILD)
	return report


## Places the buildable scene into the world.
## Instantiates and places the buildable scene into the world at the preview location. Attaches PlaceableInstance if required and applies placement rules.[br][br]
## [code]p_placeable[/code]: [i]Placeable[/i] - Placeable resource to build[br]
## [code]p_attach_placeable_instance[/code]: [i]bool[/i] - Whether to attach PlaceableInstance component
func _build_instance(p_placeable : Placeable, p_attach_placeable_instance : bool) -> Node2D:
	if not is_instance_valid(p_placeable):
		push_warning(WARNING_INVALID_PLACEABLE % p_placeable)
		return null
	if not is_instance_valid(_states.building.preview):
		push_warning(WARNING_NO_PREVIEW)
		return null
	
	var instance = p_placeable.packed_scene.instantiate()
	_states.building.placed_parent.add_child(instance)
	instance.owner = _states.building.placed_parent
	instance.global_transform = _states.building.preview.global_transform
	instance.name = p_placeable.get_packed_root_name()
	
	if p_attach_placeable_instance and not GBSearchUtils.find_first(instance, PlaceableInstance):
		var placeable_instance = PlaceableInstance.new(p_placeable.resource_path)
		placeable_instance.name = PlaceableInstance.default_name
		instance.add_child(placeable_instance)

	_indicator_context.get_manager().apply_rules()
		
	return instance

## Validates if the building system is ready for placement.
func _validate_build_ready() -> bool:
	var issues : Array[String] = []
	issues.append_array(get_runtime_issues())

	## Make sure placement manager exists to put preview instances onto
	if _indicator_context and not _indicator_context.has_manager():
		var critical_issue = "CRITICAL: No IndicatorManager found in IndicatorContext. IndicatorManager must be manually created in the scene hierarchy as a child of ManipulationParent (under GridPositioner). Indicators are always parented to IndicatorManager. IndicatorManager must be a child of ManipulationParent to inherit rotation/transform via scene tree. IndicatorManager will register itself through dependency injection."
		issues.append(critical_issue)
		
		# Assert to catch this critical configuration issue early
		assert(false, critical_issue + " This ensures a single source of truth and prevents desync between scene-based and dynamically created managers.")

	return issues.is_empty()

## Aligns preview to the grid system.
## Aligns the preview instance to the grid system based on the given global position.
## Used to snap preview to grid tiles for accurate placement feedback.
func _align_preview_to_grid(collision_shape_global_position: Vector2):
	_get_lazy_preview_builder().align_to_grid(collision_shape_global_position)

## Handles changes to build mode. Cleans up build state and indicators when switching out of build mode.
func _on_mode_changed(p_mode: GBEnums.Mode):
	match p_mode:
		GBEnums.Mode.BUILD:
			pass
		_:
			# Clear the selected placeable when exiting build mode
			if selected_placeable != null:
				if _logger:
					_logger.log_debug("[BuildingSystem] Clearing selected placeable on mode change to %s" % GBEnums.Mode.keys()[p_mode])
				selected_placeable = null
			_exit_build_cleanup()
#endregion
