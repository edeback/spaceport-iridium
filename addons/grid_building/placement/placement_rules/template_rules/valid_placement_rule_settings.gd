## Settings resource for ValidPlacementTileRule message configuration.
## Provides customizable messages for tile placement validation scenarios.
class_name ValidPlacementRuleSettings
extends Resource

@export_group("Summary Reasons")
## Player-friendly reason shown when tile validation succeeds
@export var success_reason : String = "Valid placement"

## Player-friendly reason shown when tile validation fails
@export var failure_reason : String = "Invalid location"

## Player-friendly reason shown when no indicators are available
@export var no_indicators_reason : String = "No build area"

@export_group("Issues")
## Success message for valid tiles.
@export var success_message : String = "All expected nearby tiles exist"

## Message to be passed along when the rule requirements were not met.
@export var failed_message : String = "Tiles in expected tile areas are missing"

## Message to output when there are no tile collision indicators to check against the rule.
@export var no_indicators_message : String = "No tile collision indicators to check for valid tile placement"
