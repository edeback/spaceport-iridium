## Collision Object Resolver
##
## Internal utility for resolving collision objects and their test setups.
## Handles the logic for determining appropriate CollisionObject2D instances
## for layer checking and finding corresponding CollisionTestSetup2D objects.
##
## This is an internal implementation detail of CollisionMapper and should not
## be used directly. Unit tests access it for testing the resolution logic.
##
## [b]Responsibilities:[/b]
## - Resolve CollisionObject2D for layer checking from various collision node types
## - Find appropriate CollisionTestSetup2D for collision objects
## - Validate collision object hierarchies
## - Provide type-safe collision object handling
##
## [b]Supported Collision Types:[/b]
## - CollisionObject2D (direct)
## - CollisionShape2D (via parent CollisionObject2D)
## - CollisionPolygon2D (via parent CollisionObject2D)
class_name CollisionObjectResolver
extends RefCounted

## Result of collision object resolution
class ResolutionResult:
	var collision_object: CollisionObject2D = null
	var test_setup: CollisionTestSetup2D = null
	var is_valid: bool = false
	var error_message: String = ""

	func _init(p_collision_object: CollisionObject2D = null, p_test_setup: CollisionTestSetup2D = null, p_is_valid: bool = false, p_error: String = "") -> void:
		collision_object = p_collision_object
		test_setup = p_test_setup
		is_valid = p_is_valid
		error_message = p_error

## Resolve a collision object for layer checking and test setup lookup
##
## @param collision_node: The collision node to resolve (CollisionObject2D, CollisionShape2D, or CollisionPolygon2D)
## @param test_setups: Array of available CollisionTestSetup2D objects
## @return ResolutionResult containing the resolved collision object and test setup
func resolve_collision_object(collision_node: Node2D, test_setups: Array[CollisionTestSetup2D]) -> ResolutionResult:
	if not collision_node:
		return ResolutionResult.new(null, null, false, "Collision node is null")

	# Handle direct CollisionObject2D
	if collision_node is CollisionObject2D:
		return _resolve_direct_collision_object(collision_node, test_setups)

	# Handle CollisionShape2D or CollisionPolygon2D (must have CollisionObject2D parent)
	if collision_node is CollisionShape2D or collision_node is CollisionPolygon2D:
		return _resolve_child_collision_object(collision_node, test_setups)

	# Unsupported node type
	return ResolutionResult.new(null, null, false, "Unsupported collision node type: " + collision_node.get_class())

## Resolve direct CollisionObject2D
##
## Processes a CollisionObject2D node to find its corresponding test setup or determine 
## if it can be processed without one (e.g., when it contains CollisionPolygon2D children).
##
## [b]Parameters:[/b]
## • [code]collision_obj[/code]: [i]CollisionObject2D[/i] - The collision object to resolve
## • [code]test_setups[/code]: [i]Array[CollisionTestSetup2D][/i] - Available test setups to search through
##
## [b]Returns:[/b]
## [i]ResolutionResult[/i] - Contains the collision object, found test setup (may be null), 
## validity flag, and descriptive message
##
## [b]Behavior:[/b]
## • First attempts to find a matching CollisionTestSetup2D for the collision object
## • If no test setup found, checks if the object has CollisionPolygon2D children
## • CollisionPolygon2D children allow processing without test setups (polygon-based geometry)
## • Returns valid=true for polygon children, valid=false otherwise
func _resolve_direct_collision_object(collision_obj: CollisionObject2D, test_setups: Array[CollisionTestSetup2D]) -> ResolutionResult:
	var test_setup = _find_test_setup_for_collision_object(collision_obj, test_setups)
	if not test_setup:
		# Check if the CollisionObject2D has CollisionPolygon2D children that can be processed without test setups
		var has_polygon_children = false
		for child in collision_obj.get_children():
			if child is CollisionPolygon2D:
				has_polygon_children = true
				break
		
		if has_polygon_children:
			# Allow processing without test setup for CollisionObject2D with polygon children
			return ResolutionResult.new(collision_obj, null, true, "CollisionObject2D with polygon children")
		else:
			return ResolutionResult.new(collision_obj, null, false, "No test setup found for CollisionObject2D")

	return ResolutionResult.new(collision_obj, test_setup, true, "")

## Resolve CollisionShape2D or CollisionPolygon2D via parent CollisionObject2D
func _resolve_child_collision_object(collision_node: Node2D, test_setups: Array[CollisionTestSetup2D]) -> ResolutionResult:
	var parent = collision_node.get_parent()
	if not parent is CollisionObject2D:
		return ResolutionResult.new(null, null, false, collision_node.name + " has no CollisionObject2D parent")

	var collision_obj := parent as CollisionObject2D
	var test_setup = _find_test_setup_for_collision_object(collision_obj, test_setups)
	if not test_setup:
		return ResolutionResult.new(collision_obj, null, false, "No test setup found for parent CollisionObject2D of " + collision_node.name)

	return ResolutionResult.new(collision_obj, test_setup, true, "")

## Find test setup for a collision object
func _find_test_setup_for_collision_object(collision_obj: CollisionObject2D, test_setups) -> CollisionTestSetup2D:
	# Accept either Array or Dictionary (some test factories provide a dict keyed by object)
	if test_setups == null:
		return null

	var t = typeof(test_setups)
	if t == TYPE_ARRAY:
		for setup in test_setups:
			if setup.collision_object == collision_obj:
				return setup
		return null
	elif t == TYPE_DICTIONARY:
		if test_setups.has(collision_obj):
			return test_setups[collision_obj]
		# Fall back to scanning values
		for key in test_setups.keys():
			var s = test_setups[key]
			if s is CollisionTestSetup2D and s.collision_object == collision_obj:
				return s
		return null
	else:
		return null

## Check if a collision object matches the given layer mask
##
## @param collision_obj: The CollisionObject2D to check
## @param layer_mask: The layer mask to match against
## @return true if the object matches the layer mask
func object_matches_layer_mask(collision_obj: CollisionObject2D, layer_mask: int) -> bool:
	if not collision_obj:
		return false
	return PhysicsMatchingUtils2D.object_has_matching_layer(collision_obj, layer_mask)
