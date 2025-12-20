## Message configuration resource for CollisionsCheckRule.
## Provides modular, reusable message settings that can be shared across multiple rules.
class_name CollisionRuleSettings
extends Resource

@export_group("Issue Messages")
## Message to be passed along when the tile validates as successful
@export var success_message : String = "No placement collisions found"

## Message to be passed along when the rule requirements were not met.
@export var expected_no_collisions_message : String = "Must have no collisions"

## When collision is expected (physics overlap), this message will be added to failed results.
@export var expected_collision_message : String = "Must have collisions in area"
@export var expected_collisions_message : String = "Must overlap "

@export var no_indicators_message : String = "No tile collision indicators to check for collisions in placement"

## Player-friendly failure shown when placement is blocked by overlaps.
## [code]%d[/code]: number of indicators that detected a blocking overlap
@export var fail_blocked_message : String = "Colliding on %d tile(s)"

## Player-friendly failure shown when an overlap was required but missing.
## [code]%d[/code]: number of indicators that did not find a required overlap
@export var fail_missing_overlap_message : String = "Missing required overlap on %d tile(s)"

@export_group("Reason Messages")
## Player-friendly reason shown when collision validation succeeds
@export var success_reason : String = "Clear to build"

## Player-friendly reason shown when collision validation fails
@export var failure_reason : String = "Cannot build here"

## Player-friendly reason shown when no indicators are available
@export var no_indicators_reason : String = "No build area"

@export_group("Display Settings")
## Add name of CollisionsCheckRule resource to the start of a fail / success message
@export var prepend_resource_name : bool

## Whether to show a list of layers tested in output messages
@export var append_layer_names = false
@export var layers_tested_prefix : String = " : Layers Checked: "
