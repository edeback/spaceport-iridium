## CollisionTestSetup2D
## [codeblock]
## var test_setup = CollisionTestSetup2D.new(collision_object, Vector2(16, 16))
## if test_setup.validate_setup():
##     # Use test_setup.rect_collision_test_setups for collision testing
##     pass
## [/codeblock]
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
## var test_setup = CollisionTestSetup2D.new(collision_object, Vector2(16, 16))
## if test_setup.validate_setup():
##     # Use test_setup.rect_collision_test_setups for collision testing
##     pass
## [/codeblock]
##
## [b]Advanced Documentation:[/b]
## For detailed usage, API reference, and troubleshooting, see:
## https://gridbuilding.pages.dev/api/v5.0.0/CollisionTestSetup
##
## [b]Dependencies:[/b] RectCollisionTestingSetup, GBGeometryUtils
class_name CollisionTestSetup2D
extends RefCounted

#region Properties

## The CollisionObject2D being analyzed for collision testing.
var collision_object: CollisionObject2D :
	set(value):
		collision_object = value
		
		if not is_instance_valid(collision_object):
			add_issue("Collision object is not valid.")

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
func _init(p_collision_object: CollisionObject2D, p_shape_stretch_size: Vector2) -> void:
	collision_object = p_collision_object
	shape_stretch_size = p_shape_stretch_size
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

## Creates collision test setups for multiple collision owners.
##
## [b]Purpose:[/b] Batch creation of collision test setups when you already have a mapping
## of collision owners to their shapes. This is the lower-level method that gives you
## fine-grained control over which collision owners to process.
##
## [b]Use Case:[/b] When you have pre-analyzed collision data or need to process only
## specific collision owners from a larger set.
##
## [b]Parameters:[/b]
##   [code]owner_shapes[/code]: [i]Dictionary[Node2D, Array][/i] - Pre-mapped collision owners to their shapes
##   [code]targeting_state[/code]: [i]GridTargetingState[/i] - Provides tile set for size calculations
##
## [b]Returns:[/b]
##   [i]Dictionary[Node2D, CollisionTestSetup2D][/i] - Test setups keyed by collision owner
##
## [b]Behavior:[/b]
## • CollisionObject2D owners → Get CollisionTestSetup2D instances
## • CollisionPolygon2D owners → Get null (not supported for collision testing)
## • Invalid tile set → Skips owner with error message
##
## [b]Example:[/b]
## [codeblock]
## var owner_shapes = GBGeometryUtils.get_all_collision_shapes_by_owner(scene_root)
## var setups_dict = CollisionTestSetup2D.create_test_setups_for_collision_owners(owner_shapes, targeting_state)
## for owner in setups_dict.keys():
##     var setup = setups_dict[owner]
##     if setup != null:  # Skip null entries for unsupported types
##         # Use setup for collision testing
## [/codeblock]
static func create_test_setups_for_collision_owners(
	owner_shapes: Dictionary[Node2D, Array], 
	targeting_state: GridTargetingState
) -> Dictionary[Node2D, CollisionTestSetup2D]:
	var setups: Dictionary[Node2D, CollisionTestSetup2D] = {}
	
	for owner in owner_shapes.keys():
		if owner is CollisionObject2D:
			var tile_set = targeting_state.get_target_map_tile_set()
			if tile_set == null:
				push_error("CollisionTestSetup2D: Invalid tile set in targeting state")
				continue
			var collision_shape_stretch_amount = tile_set.tile_size * 2.0
			setups[owner] = CollisionTestSetup2D.new(owner, collision_shape_stretch_amount)
		elif owner is CollisionPolygon2D:
			setups[owner] = null
	
	return setups

## Creates collision test setups starting from a test node.
##
## [b]Purpose:[/b] One-step collision test setup creation from any scene node.
## This is the higher-level convenience method that handles the complete workflow
## of finding collision owners and creating test setups.
##
## [b]Use Case:[/b] When you have a scene node (like a placeable object) and want
## to quickly set up collision testing for all collision objects within it.
## Perfect for placement validation, drag-and-drop preview, and rule checking.
##
## [b]Parameters:[/b]
##   [code]test_node[/code]: [i]Node2D[/i] - Any node to scan for collision objects (usually a placeable root)
##   [code]targeting_state[/code]: [i]GridTargetingState[/i] - Provides tile set for size calculations
##
## [b]Returns:[/b]
##   [i]Array[CollisionTestSetup2D][/i] - Ready-to-use collision test setups (null entries filtered out)
##
## [b]Workflow:[/b]
## 1. Scans test_node tree for all collision shapes using GBGeometryUtils
## 2. Groups shapes by their collision owner nodes  
## 3. Creates CollisionTestSetup2D instances for supported owners
## 4. Filters out null entries (unsupported collision types)
## 5. Returns clean array of working test setups
##
## [b]Example:[/b]
## [codeblock]
## # Quick setup for placeable collision testing
## var placeable_node = load("res://placeables/building.tscn").instantiate()
## var test_setups = CollisionTestSetup2D.create_test_setups_from_test_node(placeable_node, targeting_state)
## for setup in test_setups:
##     # All setups are guaranteed to be non-null and ready for testing
##     var collision_results = collision_mapper.get_tile_offsets_for_test_collisions(setup)
## [/codeblock]
##
## [b]Comparison with create_test_setups_for_collision_owners:[/b]
## • This method: Auto-discovers collision owners → Convenient for most use cases
## • create_test_setups_for_collision_owners: Requires pre-mapped owners → More control
static func create_test_setups_from_test_node(
	test_node: Node2D,
	targeting_state: GridTargetingState
) -> Array[CollisionTestSetup2D]:
	var shapes_by_owner : Dictionary[Node2D, Array] = GBGeometryUtils.get_all_collision_shapes_by_owner(test_node)
	var setups_dict = create_test_setups_for_collision_owners(shapes_by_owner, targeting_state)
	
	# Convert Dictionary to Array as per method signature
	var result: Array[CollisionTestSetup2D] = []
	for setup in setups_dict.values():
		if setup != null:  # Skip null entries
			result.append(setup)
	return result

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
