## Grid-aware object rotation utilities for 2D grid-based games.
##
## Provides clean, typed helper functions for rotating objects on a grid with proper
## alignment to grid tiles, particularly for isometric and square tile layouts.
## Supports configurable rotation increments (90°, 45°, 30°, 60°, or any custom angle).
##
## Key features:
## - Configurable rotation increments (4-direction, 8-direction, or any custom angle)
## - Cardinal direction rotation (backward compatible, convenience API)
## - Isometric-aware rotation handling with complex transform support
## - Snap-to-grid positioning after rotation
## - Integration with existing GridPositioner2D and GBPositioning2DUtils
## - Static methods for easy testing and reuse
##
## Usage Examples:
## - 4-direction (RTS-style): rotate_node_clockwise(node, map, 90.0)
## - 8-direction (isometric with diagonals): rotate_node_clockwise(node, map, 45.0)
## - 6-direction (hex-style): rotate_node_clockwise(node, map, 60.0)
## - 12-direction: rotate_node_clockwise(node, map, 30.0)
##
## Designed to work seamlessly with the existing Grid Building plugin architecture
## while providing specialized rotation functionality for grid-based gameplay.
class_name GBGridRotationUtils
extends RefCounted

## Cardinal directions for grid-based rotation (backward compatibility)
## Use these with cardinal_*() methods for 4-direction rotation systems
enum CardinalDirection {
	NORTH = 0,  ## 0 degrees / up
	EAST = 1,   ## 90 degrees / right
	SOUTH = 2,  ## 180 degrees / down  
	WEST = 3    ## 270 degrees / left
}

## Convert rotation degrees to cardinal direction
## [param degrees] Rotation in degrees (will be normalized to 0-360 range)
## [return] CardinalDirection enum value
static func degrees_to_cardinal(degrees: float) -> CardinalDirection:
	# Normalize to 0-360 range
	var normalized := fmod(degrees, 360.0)
	if normalized < 0:
		normalized += 360.0
	
	# Round to nearest 90-degree increment
	var rounded: float = round(normalized / 90.0) * 90.0
	
	match int(rounded) % 360:
		0:
			return CardinalDirection.NORTH
		90:
			return CardinalDirection.EAST
		180:
			return CardinalDirection.SOUTH
		270:
			return CardinalDirection.WEST
		_:
			return CardinalDirection.NORTH

## Convert cardinal direction to rotation degrees
## [param direction] CardinalDirection enum value
## [return] Rotation in degrees (0, 90, 180, or 270)
static func cardinal_to_degrees(direction: CardinalDirection) -> float:
	match direction:
		CardinalDirection.NORTH:
			return 0.0
		CardinalDirection.EAST:
			return 90.0
		CardinalDirection.SOUTH:
			return 180.0
		CardinalDirection.WEST:
			return 270.0
		_:
			return 0.0

## Get the next cardinal direction (clockwise rotation)
## [param current] Current CardinalDirection
## [return] Next CardinalDirection clockwise
static func rotate_clockwise(current: CardinalDirection) -> CardinalDirection:
	return (current + 1) % 4 as CardinalDirection

## Get the previous cardinal direction (counter-clockwise rotation)
## [param current] Current CardinalDirection
## [return] Previous CardinalDirection counter-clockwise
static func rotate_counter_clockwise(current: CardinalDirection) -> CardinalDirection:
	return (current + 3) % 4 as CardinalDirection

## Rotate a Node2D clockwise by a specified increment while maintaining grid alignment
## [param node] Node2D to rotate (must be on a grid tile)
## [param map] TileMapLayer providing grid alignment
## [param increment_degrees] Rotation increment in degrees (default 90.0 for 4-direction)
##                           - Use 90.0 for 4-direction (RTS-style)
##                           - Use 45.0 for 8-direction (isometric with diagonals)
##                           - Use 60.0 for 6-direction (hex-style)
##                           - Use 30.0 for 12-direction
##                           - Or any custom angle
## [param snap_to_grid] Whether to snap position to grid after rotation (default true)
## [return] New rotation angle in degrees (0-360 range)
static func rotate_node_clockwise(node: Node2D, map: TileMapLayer, increment_degrees: float = 90.0, snap_to_grid: bool = true) -> float:
	var current_rotation_deg: float = _normalize_degrees(rad_to_deg(node.global_rotation))
	var new_rotation_deg: float = _normalize_degrees(current_rotation_deg + increment_degrees)
	var target_global_rotation: float = deg_to_rad(new_rotation_deg)
	
	# Calculate the local rotation needed to achieve the target global rotation
	_set_node_global_rotation(node, target_global_rotation)
	
	if snap_to_grid:
		_snap_node_to_grid(node, map)
	
	return new_rotation_deg

## Rotate a Node2D counter-clockwise by a specified increment while maintaining grid alignment
## [param node] Node2D to rotate (must be on a grid tile)
## [param map] TileMapLayer providing grid alignment
## [param increment_degrees] Rotation increment in degrees (default 90.0 for 4-direction)
##                           - Use 90.0 for 4-direction (RTS-style)
##                           - Use 45.0 for 8-direction (isometric with diagonals)
##                           - Use 60.0 for 6-direction (hex-style)
##                           - Use 30.0 for 12-direction
##                           - Or any custom angle
## [param snap_to_grid] Whether to snap position to grid after rotation (default true)
## [return] New rotation angle in degrees (0-360 range)
## Rotate a Node2D counter-clockwise by a specified increment while maintaining grid alignment
## [param node] Node2D to rotate (must be on a grid tile)
## [param map] TileMapLayer providing grid alignment
## [param increment_degrees] Rotation increment in degrees (default 90.0 for 4-direction)
##                           - Use 90.0 for 4-direction (RTS-style)
##                           - Use 45.0 for 8-direction (isometric with diagonals)
##                           - Use 60.0 for 6-direction (hex-style)
##                           - Use 30.0 for 12-direction
##                           - Or any custom angle
## [param snap_to_grid] Whether to snap position to grid after rotation (default true)
## [return] New rotation angle in degrees (0-360 range)
static func rotate_node_counter_clockwise(node: Node2D, map: TileMapLayer, increment_degrees: float = 90.0, snap_to_grid: bool = true) -> float:
	var current_rotation_deg: float = _normalize_degrees(rad_to_deg(node.global_rotation))
	var new_rotation_deg: float = _normalize_degrees(current_rotation_deg - increment_degrees)
	var target_global_rotation: float = deg_to_rad(new_rotation_deg)
	
	# Calculate the local rotation needed to achieve the target global rotation
	_set_node_global_rotation(node, target_global_rotation)
	
	if snap_to_grid:
		_snap_node_to_grid(node, map)
	
	return new_rotation_deg

## Set a Node2D to a specific cardinal direction with grid alignment
## [param node] Node2D to rotate
## [param direction] Target CardinalDirection
## [param map] TileMapLayer providing grid alignment
## [param snap_to_grid] Whether to snap position to grid after rotation (default true)
static func set_node_direction(node: Node2D, direction: CardinalDirection, map: TileMapLayer, snap_to_grid: bool = true) -> void:
	var target_global_rotation := deg_to_rad(cardinal_to_degrees(direction))
	
	# Calculate the local rotation needed to achieve the target global rotation
	_set_node_global_rotation(node, target_global_rotation)
	
	if snap_to_grid:
		_snap_node_to_grid(node, map)

## Get a tile delta vector for movement in a cardinal direction
## [param direction] CardinalDirection to move in
## [return] Vector2i tile delta for the direction
static func get_direction_tile_delta(direction: CardinalDirection) -> Vector2i:
	match direction:
		CardinalDirection.NORTH:
			return Vector2i(0, -1)  # Up
		CardinalDirection.EAST:
			return Vector2i(1, 0)   # Right
		CardinalDirection.SOUTH:
			return Vector2i(0, 1)   # Down
		CardinalDirection.WEST:
			return Vector2i(-1, 0)  # Left
		_:
			return Vector2i.ZERO

## Get the opposite cardinal direction
## [param direction] Input CardinalDirection
## [return] Opposite CardinalDirection (180 degrees)
static func get_opposite_direction(direction: CardinalDirection) -> CardinalDirection:
	return (direction + 2) % 4 as CardinalDirection

## Check if a direction is horizontal (East or West)
## [param direction] CardinalDirection to check
## [return] True if direction is East or West
static func is_horizontal(direction: CardinalDirection) -> bool:
	return direction == CardinalDirection.EAST or direction == CardinalDirection.WEST

## Check if a direction is vertical (North or South)
## [param direction] CardinalDirection to check
## [return] True if direction is North or South
static func is_vertical(direction: CardinalDirection) -> bool:
	return direction == CardinalDirection.NORTH or direction == CardinalDirection.SOUTH

## Convert cardinal direction to a human-readable string
## [param direction] CardinalDirection to convert
## [return] String representation ("North", "East", "South", "West")
static func direction_to_string(direction: CardinalDirection) -> String:
	match direction:
		CardinalDirection.NORTH:
			return "North"
		CardinalDirection.EAST:
			return "East"
		CardinalDirection.SOUTH:
			return "South"
		CardinalDirection.WEST:
			return "West"
		_:
			return "Unknown"

## Snap a node to the nearest grid tile center using existing positioning utilities
## [param node] Node2D to snap to grid
## [param map] TileMapLayer providing grid alignment
static func _snap_node_to_grid(node: Node2D, map: TileMapLayer) -> void:
	var current_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(node.global_position, map)
	GBPositioning2DUtils.move_to_tile_center(node, current_tile, map)

## Normalize degrees to 0-360 range
## [param degrees] Angle in degrees (can be negative or > 360)
## [return] Normalized angle in 0-360 range
static func _normalize_degrees(degrees: float) -> float:
	var normalized: float = fmod(degrees, 360.0)
	if normalized < 0:
		normalized += 360.0
	return normalized

## Rotate and move a node in one operation for grid-based movement systems
## [param node] Node2D to rotate and move
## [param rotation_direction] Direction to rotate (1 for clockwise, -1 for counter-clockwise, 0 for no rotation)
## [param movement_direction] Optional CardinalDirection to move in after rotation
## [param map] TileMapLayer providing grid alignment
## [return] Dictionary with "rotation" (CardinalDirection) and "moved_to_tile" (Vector2i) keys
static func rotate_and_move_node(
	node: Node2D, 
	rotation_direction: int, 
	movement_direction: CardinalDirection = CardinalDirection.NORTH,
	map: TileMapLayer = null,
	move_after_rotation: bool = false
) -> Dictionary:
	var result := {
		"rotation": CardinalDirection.NORTH,
		"moved_to_tile": Vector2i.ZERO
	}
	
	# Apply rotation
	if rotation_direction > 0:
		result.rotation = rotate_node_clockwise(node, map)
	elif rotation_direction < 0:
		result.rotation = rotate_node_counter_clockwise(node, map)
	else:
		result.rotation = degrees_to_cardinal(rad_to_deg(node.rotation))
	
	# Apply movement if requested
	if move_after_rotation and map != null:
		var move_delta := get_direction_tile_delta(movement_direction)
		result.moved_to_tile = GBPositioning2DUtils.move_node_by_tiles(node, move_delta, map)
	else:
		result.moved_to_tile = GBPositioning2DUtils.get_tile_from_global_position(node.global_position, map) if map != null else Vector2i.ZERO
	
	return result

## Helper function to set a node's rotation to achieve a target global rotation
## [param node] Node2D to rotate
## [param target_global_rotation] Desired global rotation in radians
static func _set_node_global_rotation(node: Node2D, target_global_rotation: float) -> void:
	if node.get_parent() == null:
		# No parent - local rotation equals global rotation
		node.rotation = target_global_rotation
		return
	
	# For complex transform hierarchies (especially with skew), we need to use
	# the full transform matrix approach rather than simple rotation arithmetic
	var parent_node: Node = node.get_parent()
	if not parent_node is Node2D:
		# Parent is not a Node2D, treat as no transform
		node.rotation = target_global_rotation
		return
	
	var parent_2d: Node2D = parent_node as Node2D
	
	# Store the original global position to restore after rotation
	var original_global_position: Vector2 = node.global_position
	
	# Create the desired global transform with target rotation at origin
	var target_global_transform: Transform2D = Transform2D()
	target_global_transform = target_global_transform.rotated(target_global_rotation)
	# Don't set origin yet - we'll restore position after rotation
	
	# Calculate what local transform would produce this global transform
	# global_transform = parent_global_transform * local_transform
	# Therefore: local_transform = parent_global_transform.inverse() * global_transform
	var parent_global_transform: Transform2D = parent_2d.global_transform
	var required_local_transform: Transform2D = parent_global_transform.affine_inverse() * target_global_transform
	
	# Extract rotation from the required local transform
	var required_local_rotation: float = required_local_transform.get_rotation()
	
	# Apply the calculated local rotation
	node.rotation = required_local_rotation
	
	# Restore the original global position (rotation may have changed it due to pivot offset)
	node.global_position = original_global_position