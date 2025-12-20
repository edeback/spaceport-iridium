## IndicatorCollisionTestSetup
##
## Builds collision test parameters for a CollisionObject2D to enable placement indicators
## to perform accurate collision checks against object geometry.
##
## [b]Purpose:[/b] Converts CollisionObject2D shapes into testable RectCollisionTestingSetup
## instances for collision validation during placement operations.
##
## [b]Key Features:[/b]
## • Creates one RectCollisionTestingSetup per shape owner
## • Expands test areas using configurable shape_stretch_size
## • Supports CollisionShape2D and CollisionPolygon2D nodes
## • Comprehensive error reporting via issues array
##
## [b]Quick Start:[/b]
## [codeblock]
## var test_setup = IndicatorCollisionTestSetup.new(collision_object, Vector2(16, 16), owning_node)
## if test_setup.validate_setup():
##     # Use test_setup.rect_collision_test_setups for collision testing
##     pass
## [/codeblock]
##
## [b]Advanced Documentation:[/b]
## For detailed usage, API reference, and troubleshooting, see:
## https://gridbuilding.pages.dev/api/v5.0.0/CollisionTestSetup2D
##
## [b]Dependencies:[/b] RectCollisionTestingSetup, GBGeometryUtils
class_name IndicatorCollisionTestSetup
extends RefCounted

#region Properties

## The CollisionObject2D being analyzed for collision testing.
var collision_object: CollisionObject2D :
	set(value):
		collision_object = value
		
		if not is_instance_valid(collision_object):
			add_issue("Collision object is not valid.")

## The owning Node2D that contains this collision object (e.g., the test object or scene node).
## This provides context about which object this collision setup belongs to.
var owning_node: Node2D

## Size to stretch collision shapes for comprehensive tile coverage.
## Recommended: Use your tile size (e.g., Vector2(16, 16) for 16x16 tiles).
## See advanced documentation for detailed sizing guidance.
var shape_stretch_size: Vector2

## Array of RectCollisionTestingSetup instances, one per shape owner.
## Use these setups to perform collision tests for placement indicators.
var rect_collision_test_setups: Array[RectCollisionTestingSetup]

## Issues discovered during collision test setup.
## Check this array after initialization to identify configuration problems.
var issues: Array[String] = []

#endregion

#region Initialization

## Initializes collision test setup for the given CollisionObject2D.
func _init(p_collision_object: CollisionObject2D, p_shape_stretch_size: Vector2, p_owning_node: Node2D = null) -> void:
	collision_object = p_collision_object
	shape_stretch_size = p_shape_stretch_size
	owning_node = p_owning_node
	rect_collision_test_setups = _create_rect_tests_for_collision_object(collision_object)
	validate_setup()

#endregion

#region Public Methods

## Records an issue encountered during setup.
func add_issue(p_issue: String) -> void:
	issues.append(p_issue)

## Frees all testing nodes created during setup.
## Call this when the setup is no longer needed to prevent memory leaks.
func free_testing_nodes() -> void:
	for test_setup in rect_collision_test_setups:
		test_setup.free_nodes()

## Validates the collision test setup and reports any issues.
## Returns true if setup is valid and ready for use, false otherwise.
func validate_setup() -> bool:
	var no_issues = true
	
	if rect_collision_test_setups == null || rect_collision_test_setups.size() == 0:
		add_issue("Test params have no RectCollisionTestingSetups. Collision object probably has no CollisionShape2D or CollisionPolygon2D children. Check scene for those.")
		no_issues = false
	
	return no_issues

#endregion

#region Private Methods

## Creates RectCollisionTestingSetup instances for each shape owner in the CollisionObject2D.
func _create_rect_tests_for_collision_object(p_collision_object : CollisionObject2D) -> Array[RectCollisionTestingSetup]:
	assert(p_collision_object != null, "The collision object must not be null to create a rect test.")
	var owner_test_params_set : Array[RectCollisionTestingSetup] = []
	
	# Get the shape owners and then create tests for each shape owners shape rects
	var shape_owner_ids = p_collision_object.get_shape_owners()
		
	for shape_owner_id in shape_owner_ids:
		var shape_owner_node =  p_collision_object.shape_owner_get_owner(shape_owner_id)
		var owner_shape_count = p_collision_object.shape_owner_get_shape_count(shape_owner_id)
		var owned_shapes : Array[Shape2D] = []
		
		for shape_index in range(0, owner_shape_count, 1):
			var found_shape = p_collision_object.shape_owner_get_shape(shape_owner_id, shape_index)
			owned_shapes.append(found_shape)
		
		var owner_testing_rect = _get_testing_rect_for_owner(shape_owner_node)
		
		var rect_test_parameters = RectCollisionTestingSetup.new(
			shape_owner_node,
			owned_shapes,
			owner_testing_rect
		)
		
		owner_test_params_set.append(rect_test_parameters)
	
	return owner_test_params_set

## Calculates the testing rectangle for a shape owner node.
## Supports CollisionShape2D and CollisionPolygon2D nodes.
func _get_testing_rect_for_owner(p_shape_owner: Node2D) -> Rect2:
	if p_shape_owner is CollisionShape2D:
		var shape = p_shape_owner.shape
		
		if(shape == null):
			add_issue("Shape owner " + p_shape_owner.name + " has no shape set.")
			return Rect2()
		
		var shape_rect = p_shape_owner.shape.get_rect()
		var adjusted_rect = _adjust_rect_to_testing_size(shape_rect, p_shape_owner.global_transform)
		return adjusted_rect
	elif p_shape_owner is CollisionPolygon2D:
		var polygon: PackedVector2Array = p_shape_owner.polygon
		var polygon_rect: Rect2 = GBGeometryUtils.points_array_to_rect_2d(polygon, p_shape_owner.position)
		var adjusted_rect = _adjust_rect_to_testing_size(polygon_rect, p_shape_owner.global_transform)
		return adjusted_rect
	else:
		add_issue("Class type of " + str(p_shape_owner.get_path()) + " is not supported. Type " + str(p_shape_owner.get_class()))
		return Rect2()

## Expands the rectangle by shape_stretch_size to ensure comprehensive tile coverage.
## Handles complex transforms by converting to squares when rotation/skew is present.
func _adjust_rect_to_testing_size(p_base_rect: Rect2, p_shape_owner_global_transform: Transform2D) -> Rect2:
	var origin = p_shape_owner_global_transform.get_origin()
	var adjusted_rect = p_base_rect
	
	# If complex shape (rotated/skewed), make the rectangle cover full area as a square
	if(p_shape_owner_global_transform.get_skew() != 0 || p_shape_owner_global_transform.get_rotation() != 0):
		adjusted_rect = GBGeometryUtils.grow_rect2_to_square(adjusted_rect)
		
	# Expand the testing area by shape_stretch_size for comprehensive tile coverage
	adjusted_rect.size += shape_stretch_size

	return adjusted_rect

#endregion
