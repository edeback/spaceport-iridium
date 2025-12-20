## Rule that validates placement based on collision detection.
##
## This rule checks for physics collisions at indicator positions and validates based on
## the [member pass_on_collision] setting:
## - [code]false[/code] (default): Placement FAILS if collision detected ("must have clear space")
## - [code]true[/code]: Placement FAILS if NO collision detected ("must overlap with existing objects")
class_name CollisionsCheckRule
extends TileCheckRule

## Controls collision validation behavior:
## - [code]false[/code]: Rule PASSES when no collision (placement requires clear space)
## - [code]true[/code]: Rule PASSES when collision detected (placement requires overlap)
##
## Common use cases:
## - [code]false[/code]: Building placement (needs empty space)
## - [code]true[/code]: Attachment mechanics (must connect to existing structures)
@export var pass_on_collision = false

## Physics layers to scan for collisions.
@export_flags_2d_physics() var collision_mask = 1

## Modular message configuration resource
@export var messages : CollisionRuleSettings

var _rule_check_layer_names : Array[String]

func _init():
	if messages == null:
		messages = CollisionRuleSettings.new()

## Setup the rule with the provided GridTargetingState.
## Returns an array of issues found during setup.
## [code]p_gts[/code]: [i]GridTargetingState[/i] - The targeting state to use for placement
## [returns] Array[String] - Array of issues found during setup
func setup(p_gts : GridTargetingState) -> Array[String]:
	_rule_check_layer_names = PhysicsMatchingUtils2D.get_physics_layer_names_from_mask(collision_mask)
	# Delegate to PlacementRule.setup to initialize _grid_targeting_state and _ready.
	var issues := super.setup(p_gts)

	_ready = true
	return issues

## Validates placement by checking collisions on all provided indicators.
## Returns a RuleResult with success/failure and messages.
func validate_placement() -> RuleResult:
	if indicators.size() == 0:
		return RuleResult.build(self, [messages.no_indicators_message])

	var issue_message : String = ""
	var reason_message : String = ""
	# Compute failing indicators once so we can report a concise count
	var failing_indicators := get_failing_indicators(indicators)
	var failing_count := failing_indicators.size()
	var is_successful := failing_count == 0

	if is_successful:
		reason_message = messages.success_reason
	else:
		reason_message = messages.failure_reason
		
		# Build detailed issue message
		if messages.prepend_resource_name:
			issue_message += resource_name + ": "

		# Concise failure summary with number of failing indicators
		# When pass_on_collision is true, failing means no collision where one was expected
		# When pass_on_collision is false, failing means a collision was detected where none was expected
		if pass_on_collision:
			# Avoid % formatting to prevent mismatched placeholder runtime errors
			if messages.fail_missing_overlap_message.find("%d") != -1:
				issue_message += messages.fail_missing_overlap_message.replace("%d", str(failing_count))
			else:
				issue_message += messages.fail_missing_overlap_message + " (" + str(failing_count) + ")"
		else:
			if messages.fail_blocked_message.find("%d") != -1:
				issue_message += messages.fail_blocked_message.replace("%d", str(failing_count))
			else:
				issue_message += messages.fail_blocked_message + " (" + str(failing_count) + ")"

		if messages.append_layer_names:
			issue_message += "\n" + messages.layers_tested_prefix + str(_rule_check_layer_names)

	# Build the result with issues array if validation failed
	var issues: Array[String] = []
	if not is_successful:
		issues.append(issue_message)
	
	return RuleResult.build(self, issues)

## Runs the rule against an array of indicators.
## Returns the number of failing indicators.[br][br]
## [code]p_indicators[/code]: [i]Array[RuleCheckIndicator][/i] - Array of indicators to test collision against
## NOTE: This method is public and should be used directly by callers. The previous
## private wrapper `_get_failing_indicators` was removed to simplify the API.
func get_failing_indicators(p_indicators : Array[RuleCheckIndicator]) -> Array[RuleCheckIndicator]:
	var failed_indicators : Array[RuleCheckIndicator] = []
	var null_count = 0
	var valid_count = 0
	var collision_count = 0

	# Perform collision checks
	for indicator in p_indicators:
		# Skip invalid/freed indicators
		if indicator == null:
			null_count += 1
			continue

		valid_count += 1

		# Ensure we never collide with the preview's own bodies
		_indicator_apply_target_exceptions(indicator)

		var original_mask := indicator.collision_mask
		indicator.collision_mask = collision_mask

		if not indicator.is_inside_tree():
			failed_indicators.append(indicator)
			continue

		indicator.force_shapecast_update()

		if pass_on_collision:
			if not indicator.is_colliding():
				failed_indicators.append(indicator)
			else:
				collision_count += 1
		else:
			if indicator.is_colliding():
				failed_indicators.append(indicator)
				collision_count += 1

		indicator.collision_mask = original_mask
		# DO NOT clear exceptions here - they persist across physics frames
		# and are re-applied at the start of each validation via _indicator_apply_target_exceptions()

	# Log validation summary
	var expected_collisions = "collisions" if pass_on_collision else "no collisions"
	var passed_count = valid_count - failed_indicators.size()
	return failed_indicators

## Add all CollisionObject2D under the preview target as exceptions on the shape cast.
## Also adds any nodes from GridTargetingState.collision_exclusions (e.g., original object during manipulation move).
func _indicator_apply_target_exceptions(indicator: ShapeCast2D) -> void:
	if indicator == null or not is_instance_valid(indicator):
		return
	# Always clear previous exceptions to avoid stale exception lists affecting collision checks
	indicator.clear_exceptions()
	if _grid_targeting_state == null:
		return
	
	var bodies: Array[CollisionObject2D] = []
	
	# Add preview target exceptions (the copy being manipulated)
	var target_node := _grid_targeting_state.target
	if target_node != null:
		_collect_bodies_recursive(target_node, bodies)
	
	# Add collision exclusions (e.g., the original object being moved)
	for excluded_node in _grid_targeting_state.collision_exclusions:
		if excluded_node != null and is_instance_valid(excluded_node):
			_collect_bodies_recursive(excluded_node, bodies)
	
	# Apply all collected bodies as exceptions
	for body in bodies:
		if body and is_instance_valid(body):
			indicator.add_exception(body)

func _collect_bodies_recursive(node: Node, out: Array[CollisionObject2D]) -> void:
	if node == null:
		return
	if node is CollisionObject2D:
		out.append(node)
	for child in node.get_children():
		if child is Node:
			_collect_bodies_recursive(child, out)

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(super.get_editor_issues())
	
	if collision_mask == 0:
		issues.append("CollisionsCheckRule has no collision layers set in collision_mask")
	
	if messages == null:
		issues.append("CollisionsCheckRule has no messages resource configured")
	elif messages.success_message.is_empty():
		issues.append("CollisionsCheckRule has no success message set")
	
	if messages != null and messages.expected_no_collisions_message.is_empty():
		issues.append("CollisionsCheckRule has no expected_no_collisions_message set")
	
	return issues

## Returns an array of issues found during runtime validation
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(super.get_runtime_issues())
	
	if _rule_check_layer_names.is_empty():
		issues.append("CollisionsCheckRule has no collision layer names configured")
	
	return issues
