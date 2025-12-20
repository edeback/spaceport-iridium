## A rule that validates a tile position based on a tilemap's custom data fields.
##
## This rule checks if a tile at a potential placement position has all the required custom data fields and matching values defined in its `expected_tile_custom_data` dictionary. It's used to ensure that a tile can only be placed on a specific type of ground, such as "walkable" or "buildable" tiles.
##
## **Usage**:
## - Assign this rule to a GBCompositionContainer for context wide injection or to a Placeable for placeable specific rule evaluation
## - Set the `expected_tile_custom_data` dictionary to define the required key-value pairs (e.g., `{ "type": "ground", "variant": "grass" }`).
## - The rule will fail if the tile at the indicator's position does not contain all the required custom data or if any values do not match.
class_name ValidPlacementTileRule
extends TileCheckRule

## Expected custom data fields and values for valid tiles.
@export var expected_tile_custom_data = {}

## Settings for the valid placement tile rule. Defines custom messages for this rule's validation.
@export var settings : ValidPlacementRuleSettings

func _init(p_expected_tile_data : Dictionary = {}):
	expected_tile_custom_data = p_expected_tile_data

## Lazy initialization of settings - creates default settings if none are provided
func _ensure_settings() -> ValidPlacementRuleSettings:
	if settings == null:
		settings = ValidPlacementRuleSettings.new()
	return settings

## Creates tile indicators on matching layers to test that colliding tiles
## exist in shape spaces around the object to be placed
func setup(p_gts : GridTargetingState) -> Array[String]:
	# Delegate to base PlacementRule.setup for initializing _grid_targeting_state and readiness state
	return super.setup(p_gts)
		
# Add all indicators to positioner Node2D
## Check each tile indicator of this test to ensure that they collide with the tilemap
func validate_placement() -> RuleResult:
	var rule_settings = _ensure_settings()
	
	if indicators.size() == 0:
		return RuleResult.build(self, [rule_settings.no_indicators_message])

	var invalid_tile_count = _get_failing_indicators(indicators).size()
	
	if invalid_tile_count == 0:
		return RuleResult.build(self, [])
	else:
		return RuleResult.build(self, [rule_settings.failed_message])

## Runs the rule against an array of indicators and
## Returns the failing indicators
func _get_failing_indicators(p_indicators : Array[RuleCheckIndicator]) -> Array[RuleCheckIndicator]:
		
	var failing_indicators : Array[RuleCheckIndicator] = []
	
	for indicator in p_indicators:
		if not does_tile_have_valid_data(indicator, _grid_targeting_state.maps):
			# No collision means rule fails
			failing_indicators.append(indicator)

	return failing_indicators

## Frees tile indicators created for this test when the building system no longer
## is using this rule
func tear_down():
	super.tear_down()

## Validates if tile data contains all expected custom data across provided maps.
## Returns true only if all expected custom data keys match at least one layer in the tile data.[br][br]
## [code]p_indicator[/code]: [i]RuleCheckIndicator[/i] - The indicator object marking the tile position to check[br]
## [code]p_maps[/code]: [i]Array[TileMapLayer][/i] - Array of TileMapLayer or TileMap nodes to check against
func does_tile_have_valid_data(p_indicator: RuleCheckIndicator, p_maps: Array[TileMapLayer]) -> bool:
	# Validate input parameter
	if not p_indicator:
		return false  # Early return if indicator is null
	
	# Check if indicator itself is valid
	if not p_indicator.validate_runtime():
		return false  # Early return if indicator validation fails
	
	# There must be a match on the singular tile in the rule check indicator
	var required_matches := 1
	var match_count := 0
	
	# Check each map for matching tile data
	for map in p_maps:
		var tile_pos: Vector2i = _get_tile_position(map, p_indicator)
		if _tile_has_matching_data(map, tile_pos):
			match_count += 1
	
	# Return true only if all expected data was found
	return match_count == required_matches

## Helper function to convert indicator position to tile coordinates
func _get_tile_position(map: Node2D, indicator: RuleCheckIndicator) -> Vector2i:
	return map.local_to_map(map.to_local(indicator.global_position))

## Helper function to check if a tile contains any matching custom data
func _tile_has_matching_data(map: Node2D, tile_pos: Vector2i) -> bool:
	var tile_data : TileData
	var matched := false
	
	## Make sure the tile data has the custom_data requirements
	if map is TileMapLayer:
		tile_data = map.get_cell_tile_data(tile_pos)
		return _test_tile_data_for_all_matches(tile_data, expected_tile_custom_data)
	elif map is TileMap:
		var layer_count : int = map.get_layers_count()
		for layer in range(layer_count):
			tile_data = map.get_cell_tile_data(layer, tile_pos)
			
			if _test_tile_data_for_all_matches(tile_data, expected_tile_custom_data):
				return true
				
	return false
	
## Checks if the tile data meets all required custom data matches
func _test_tile_data_for_all_matches(p_tile_data : TileData, p_required_custom_data : Dictionary) -> bool:
	if p_tile_data == null: return false
	
	for requirement in p_required_custom_data:
		if not p_tile_data.get_custom_data(requirement) == p_required_custom_data[requirement]:
			return false
	
	return true

func _post_setup_validation() -> Array[String]:
	var issues : Array[String] = []

	if expected_tile_custom_data.keys().size() == 0:
		issues.append("No expected tile custom data entered. This ValidPlacementTileRule %s has nothing to evaluate." % [self, str(resource_path)])

	return issues
