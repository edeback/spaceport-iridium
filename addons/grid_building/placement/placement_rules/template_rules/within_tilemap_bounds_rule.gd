## A rule that validates placement is within the boundaries of a tilemap.
##
## This rule works by checking if a tile exists at a proposed placement position on the target `TileMapLayer`. It ensures that a player or system cannot place objects in empty, unmapped areas of the scene.
##
## **Behavior**:
## - The rule passes if every indicator is positioned over a cell that has an assigned `TileData` object on the target map.
## - The rule fails if any indicator is over a cell that returns `null` for `TileData`, indicating that the cell is outside of the mapped region.
##
## **Usage**:
## - Attach this rule to a GBCompositionContainer for context wide injection OR a Placeable for placeable specific rule evaluation
## - The `GridTargetingState` must provide a valid `TileMapLayer` for the rule to check against.
class_name WithinTilemapBoundsRule
extends TileCheckRule

## Success message for valid placement.
@export var success_message : String = "Placement is within map bounds"

## Failure message for out-of-bounds placement.
@export var failed_message : String = "Tried placing outside of valid map area"

@export var no_indicators_message = "No tile collision indicators to check for within tilemap bounds."

## Optional: enable extra per-indicator diagnostics during tile lookups (very verbose)
@export var enable_debug_diagnostics: bool = false

## Issue keywords considered non-critical for bounds checking (cosmetic/setup)
const NON_CRITICAL_ISSUE_KEYWORDS: Array[String] = [
	"valid_settings",
	"invalid_settings",
	"validity_sprite",
	"show_indicators",
	"Logger not resolved"
]

func setup(p_gts : GridTargetingState) -> Array[String]:
	# Correctly delegate to base PlacementRule.setup so _grid_targeting_state and _ready are initialized
	return super.setup(p_gts)

func tear_down():
	# Clear local state then delegate to base tear_down implementation
	super.tear_down()

## For each tilemap indicator, check the tilemap to see if the tile at its position is used on any layer or not.
func validate_placement() -> RuleResult:
	if indicators.size() == 0:
		return RuleResult.build(self, [no_indicators_message])

	var failing_indicators: Array[RuleCheckIndicator] = get_failing_indicators(indicators)

	if failing_indicators.size() > 0:
		return RuleResult.build(self, [failed_message])

	return RuleResult.build(self, [])

## Evaluates indicators against the rule and returns failing ones.
## Returns the failing indicators that are outside valid tilemap bounds.[br][br]
## [code]p_indicators[/code]: [i]Array[RuleCheckIndicator][/i] - Array of indicators to check against tilemap bounds
## 
## CRITICAL: Overrides TileCheckRule.get_failing_indicators to avoid circular dependency 
## where the base implementation checks indicator.valid, but indicator.valid depends on rule results
func get_failing_indicators(p_indicators : Array[RuleCheckIndicator]) -> Array[RuleCheckIndicator]:
	var failing_indicators : Array[RuleCheckIndicator] = []
	var target_map : TileMapLayer = _grid_targeting_state.target_map
	
	if target_map == null:
		return p_indicators # All fail because there is no target tile map

	for indicator in p_indicators:
		if not indicator: # Safety against null indicators
			continue
			
		var results : ValidationResults = _is_over_valid_tile(indicator, target_map)
		if not results.is_successful():
			failing_indicators.append(indicator)
			
	return failing_indicators

## Validates if an indicator is positioned over a valid tile.
## A tile with no tile data does not have a sprite set and is an unused tile.
## Returns true if TileData is found or false if not.[br][br]
## [code]p_indicator[/code]: [i]RuleCheckIndicator[/i] - The indicator to check position for[br]
## [code]p_target_map[/code]: [i]Node2D[/i] - The target map to validate against
func _is_over_valid_tile(p_indicator : RuleCheckIndicator, p_target_map : TileMapLayer) -> ValidationResults:
	var results: ValidationResults = ValidationResults.new()
	if p_indicator == null:
		results.add_error("Indicator is null - cannot validate tile position")
		results.message = "Indicator is null - cannot validate tile position"
		return results

	# Evaluating invalid indicators - only fail for critical issues, not cosmetic setup
	var indicator_issues: Array[String] = p_indicator.get_runtime_issues()
	if not indicator_issues.is_empty():
		# Only fail for critical issues that prevent tilemap bounds checking
		var critical_issues: Array[String] = _filter_critical_indicator_issues(indicator_issues)

		if not critical_issues.is_empty():
			for issue in critical_issues:
				results.add_error(issue)
			results.message = "Critical indicator validation failed: " + ", ".join(critical_issues)
			return results
		# Otherwise, continue with tilemap bounds check despite cosmetic issues

	if p_target_map == null:
		results.add_error("No target map provided for validation")
		results.message = "There is no p_target_map to test against so _is_over_valid_tile automatically fails."
		return results

	var local_pos: Vector2 = p_target_map.to_local(p_indicator.global_position)
	var tile_under : Vector2i = p_target_map.local_to_map(local_pos)

	assert(p_target_map is TileMapLayer, "p_target_map is not TileMapLayer, only TileMapLayer is supported in Grid Builder.")

	var cell_data: TileData = p_target_map.get_cell_tile_data(tile_under)

	if cell_data == null:
		results.add_error("Indicator not over valid tile at position %s" % [tile_under])
		results.message = "The indicator is not over a tile that is within tilemap bounds at position %s" % [tile_under]
		_debug_diagnostic("OUT_OF_BOUNDS: ind=%s map_cell=%s local_pos=%s global_pos=%s" % [
			p_indicator.name,
			str(tile_under),
			str(local_pos),
			str(p_indicator.global_position)
		])
		return results
	
	_debug_diagnostic("IN_BOUNDS: ind=%s map_cell=%s local_pos=%s global_pos=%s" % [
		p_indicator.name,
		str(tile_under),
		str(local_pos),
		str(p_indicator.global_position)
	])

	# The tile is valid, so no errors are added. The result will be successful.
	return results

## Filters indicator issues, returning only those considered critical for bounds checking
func _filter_critical_indicator_issues(issues: Array[String]) -> Array[String]:
	var critical: Array[String] = []
	for issue in issues:
		if _is_critical_indicator_issue(issue):
			critical.append(issue)
	return critical

## Determines if an issue string is critical (i.e., not cosmetic)
func _is_critical_indicator_issue(issue: String) -> bool:
	for keyword in NON_CRITICAL_ISSUE_KEYWORDS:
		if issue.contains(keyword):
			return false
	return true

## Emits gated diagnostics when debug diagnostics are enabled
func _debug_diagnostic(message: String) -> void:
	if not enable_debug_diagnostics:
		return
	# Use push_warning to avoid altering functional behavior; only visible when flag is set
	push_warning("WithinTilemapBoundsRule: " + message)
