## Represents a structured report of an IndicatorManager.setup_indicators() run.
## Holds the produced indicators plus diagnostic metadata that can be logged or asserted in tests.
class_name IndicatorSetupReport
extends RefCounted

## The indicators created during setup
var indicators: Array[RuleCheckIndicator] = []

## The targeting state being used for indicators to be created and tested against for placement and validation
var targeting_state : GridTargetingState

## The template being used for instantiating indicators
var template : PackedScene

## The rules that were being evaluated in the creation of the indicators
var rules: Array[TileCheckRule] = []

## All distinct tile positions that were used for the creation of indicators
var tile_positions: Array[Vector2i] = []

## The mapping between tile positions and an array of TileCheckRules that were assigned for an indicator at those positions
var position_rules_map: Dictionary[Vector2i, Array] = {}

## List of owners and their attached collision shapes and polygons
var owner_shapes : Dictionary[Node2D, Array] = {}

## Collision test setups for each collision shape / polygon 2D to be tested.
var indicator_test_setups : Array[CollisionTestSetup2D] = []

## The issues that occured during setup, if any
var issues : Array[String] = []

## Verbose diagnostic notes to detail what happened during indicator setup.
## These notes do not represent issues with the setup but may aid in debugging.
var notes : Array[String] = []

## Defines basically validation dependencies for the indicator setup but does not solely build report.
## Be sure to add issues and notes while handling the indicator instantiation process to keep the report updated.
func _init(p_rules: Array[TileCheckRule], p_targeting_state : GridTargetingState, p_template : PackedScene) -> void:
	rules = p_rules
	template = p_template
	targeting_state = p_targeting_state
	_ensure_positioner_grid_alignment()

## Lists issues that are preventing a proper
## indicators validation during runtime
func get_indicators_issues() -> Array[String]:
	var issues: Array[String] = []

	if rules.size() <= 0:
		issues.append("No rules defined")

	for i in indicators.size():
		# Avoid typed assignment first to prevent crashes on freed instances
		var indicator = indicators.get(i)
		# Guard against freed/invalid indicators to avoid runtime errors during reporting
		if indicator == null or not is_instance_valid(indicator):
			issues.append("Null or freed indicator at index %d" % i)
			continue

		# Use untyped variable to avoid typed assignment to a possibly freed instance
		if indicator.get_rules().size() == 0:
			issues.append("Indicator index %d has no rules" % i)

	if tile_positions.size() <= 0 and not (position_rules_map.size() <= 0 and rules.size() > 0):
		issues.append("No distinct tile positions calculated")

	if position_rules_map.size() <= 0 and not (rules.size() > 0 and position_rules_map.size() <= 0):
		issues.append("No position rules defined")

	# Check for common issues
	if indicators.size() == 0 and not (position_rules_map.size() <= 0 and rules.size() > 0):
		issues.append("No indicators generated")

	return issues

## Populate derived fields (distinct tiles, type counts) after core fields set.
func finalize() -> void:
	_compute_distinct_tiles()

## Add an extra issue to the report
func add_issue(p_issue : String) -> void:
	issues.append(p_issue)

## Whether the report currently has issues. Useful as a guard check.
func has_issues() -> bool:
	return issues.size() > 0

## Adds a diagnostics note to the report
func add_note(p_node : String) -> void:
	notes.append(p_node)

## Sets the collision object test setups for the report
## For each indicator that was tested
func set_test_setups(p_test_setups : Array[CollisionTestSetup2D]) -> void:
	indicator_test_setups = p_test_setups
	add_note("IndicatorTestSetups: %d" % indicator_test_setups.size())

## Perform preflight validation of indicator setup environment
##
## Checks required dependencies and runtime state before indicator generation. If
## issues are found they are appended to the provided [code]IndicatorSetupReport[/code]
## so callers can decide whether to abort and surface a clear error report instead
## of throwing exceptions.
##
## Parameters:
##   [code]p_test_object[/code] : [i]Node[/i] - The preview/test object that will be used to derive collision shapes.
##   [code]p_tile_check_rules[/code] : [i]Array[TileCheckRule][/i] - The set of tile rules that will be evaluated.
##   [code]p_report[/code] : [i]IndicatorSetupReport[/i] - Mutable report where discovered issues will be pushed.
##
## Returns:
##   [i]bool[/i] - True when the environment looks valid (no issues appended); false otherwise.
func validate_setup_environment(p_test_object : Node) -> bool:
	#region Setup Validation
	if not template:
		add_issue("Indicator template is not set; cannot create indicators.")

	if p_test_object == null:
		add_issue("No test object provided; cannot create indicators.")

	# Collect runtime issues from targeting state and local service validation
	var runtime_issues: Array[String] = []

	if targeting_state:
		runtime_issues.append_array(targeting_state.get_runtime_issues())
	else:
		add_issue("Targeting state is not set; cannot validate setup.")

	for issue in runtime_issues:
		add_issue(issue)

	return not has_issues()
	
## Generates a textual summary of the indicator setup report.
func to_summary_string() -> String:
	var summary : String = ""

	summary += "=== Indicator Setup Report Summary ===\n"
	summary += "Indicators: %d\n" % indicators.size()
	summary += "Rules: %d\n" % rules.size()
	summary += "Tile Positions: %d\n" % tile_positions.size()
	summary += "Issues: %d\n" % issues.size()
	summary += "Notes: %d\n" % notes.size()
	summary += "\n"

	if not issues.is_empty():
		summary += "Issues:\n"
		for issue in issues:
			summary += "  - %s\n" % issue
		summary += "\n"

	if not notes.is_empty():
		summary += "Notes:\n"
		for note in notes:
			summary += "  - %s\n" % note
		summary += "\n"

	if tile_positions.size() > 0:
		summary += "Tile Positions: %s\n" % str(tile_positions)

	return summary
	

## Ensures the positioner is properly aligned to the grid before collision calculations.
## This prevents asymmetric indicator generation due to fractional positioning.
## The positioner position is snapped to the nearest tile center for consistent geometry.
##
## Note: Only updates position if it's not already aligned within a small tolerance.
##       Includes verbose logging when alignment adjustments are made.
func _ensure_positioner_grid_alignment() -> bool:
	if targeting_state == null:
		add_issue("targeting_state is missing.")
		return false
	
	if not targeting_state.positioner or not targeting_state.target_map:
		add_issue("positioner or target_map is missing")
		return false
	
	var map = targeting_state.target_map
	var positioner = targeting_state.positioner

	# Get current tile position and snap to tile center
	var current_world_pos = positioner.global_position
	var tile_pos = map.local_to_map(map.to_local(current_world_pos))
	var aligned_world_pos = map.to_global(map.map_to_local(tile_pos))
	
	# Only update if position is not already aligned (avoid unnecessary position changes)
	var position_diff = (aligned_world_pos - current_world_pos).length()
	if position_diff > 0.1:  # Small tolerance for floating-point precision
		positioner.global_position = aligned_world_pos
		# Note: Alignment is automatic and should not prevent setup
		# add_issue("Grid-aligned positioner from " + str(current_world_pos) + " to " + str(aligned_world_pos) + " (tile: " + str(tile_pos) + ")")
		return true  # Allow setup to continue after alignment

	return true

## Calculates the number of tiles that have an indicator over them. There should only be one indicator per tile!
func _compute_distinct_tiles() -> void:
	if targeting_state == null or indicators.is_empty():
		return
		
	var map = targeting_state.target_map
	
	if map == null:
		return
		
	var tiles: Array[Vector2i] = []

	# Iterate by index and validate indicators to avoid interacting with freed instances
	for i in indicators.size():
		var indicator = indicators[i]
		if indicator == null or not is_instance_valid(indicator):
			continue
		var tile_pos := map.local_to_map(map.to_local(indicator.global_position))
		if not tiles.has(tile_pos):
			tiles.append(tile_pos)
			
	tile_positions = tiles
