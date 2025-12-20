## Filters for arrays of PlacementRules used by placement and validation helpers.
##
## Contains small pure functions to extract subsets of rules (e.g., TileCheckRule) from mixed rule arrays.
class_name RuleFilters

## Filters build rules to get all collision rules from an array of building rules.[br][br]
## [code]p_building_rules[/code]: [i]Array[PlacementRule][/i] - Array of placement rules to filter
static func only_tile_check(p_building_rules: Array[PlacementRule]) -> Array[TileCheckRule]:
	var tile_check_rules: Array[TileCheckRule] = []

	for col_rule in p_building_rules.filter(func(rule): return rule is TileCheckRule):
		tile_check_rules.append(col_rule)

	return tile_check_rules
