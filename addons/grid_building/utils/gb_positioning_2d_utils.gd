## GBPositioning2DUtils
## Static utility functions for 2D grid-based positioning and tile movement operations.
##
## This class provides pure functions for common 2D game positioning tasks including:
## - Converting between world coordinates, viewport coordinates, and tile coordinates
## - Moving nodes to tile centers with proper alignment
## - Viewport-to-world coordinate transformations using Camera2D
## - Distance-limited movement with adjacency constraints
## - Direction vector normalization for tile-based movement
##
## All functions are static and depend only on provided parameters, making them
## highly testable and reusable. Extracted from GridPositioner2D to reduce
## class coupling and improve maintainability.
##
## [b]⭐ CAMERA2D REQUIRED[/b] - Add a Camera2D node to your scene before using 
## Grid Building operations. World coordinate calculations from mouse position depend on 
## Camera2D for accurate positioning.
##
## [b]Requirements:[/b] Designed for 2D games using TileMapLayer and Camera2D nodes.
class_name GBPositioning2DUtils
extends RefCounted

## Convert a global position to tile coordinates on the given map.
## Essential function for 2D grid-based games to map world positions to tile indices.
## [param global_position] The world position to convert (e.g., mouse position, node position).
## [param map] The TileMapLayer providing map<->local coordinate conversions.
## [return] The tile coordinate as Vector2i (e.g., Vector2i(5, 3) for tile at column 5, row 3).
static func get_tile_from_global_position(global_position: Vector2, map: TileMapLayer) -> Vector2i:
	var map_position := map.to_local(global_position)
	return map.local_to_map(map_position)

## Move the given node to a specific tile position on the map (centered).
## Positions the node at the exact center of the specified tile for precise 2D alignment.
## [param node] The Node2D to position (e.g., player character, cursor, building preview).
## [param tile] The target tile coordinate (e.g., Vector2i(3, 7) for column 3, row 7).
## [param map] The TileMapLayer providing coordinate conversions and tile size information.
## [return] The Vector2i tile coordinate that the node was moved to (should match input tile).
static func move_to_tile_center(node: Node2D, tile: Vector2i, map: TileMapLayer) -> Vector2i:
	# IMPORTANT: In Godot 4.x, TileMapLayer.map_to_local() returns tile CENTER, not top-left!
	# Adding extra offsets like + tile_size * 0.5 causes systematic 8-pixel positioning errors.
	# This was the root cause of 17 test failures in grid_positioner_input_test.gd (Sept 2025).
	# DO NOT modify this without running coordinate regression tests!
	var tile_center_local := map.map_to_local(tile)
	var tile_center_global := map.to_global(tile_center_local)
	node.global_position = tile_center_global
	return tile

## Move the node to the closest valid tile, respecting settings and map bounds.
## If limit_to_adjacent is true, uses GridTargetingSystem to constrain movement.
## [param node] The Node2D to move.
## [param target_tile] The desired tile coordinate.
## [param source] A source node used by GridTargetingSystem for adjacency queries.
## [param map] The map node providing map<->local conversions.
## [param settings] Targeting settings influencing adjacency/limits.
## [return] The Vector2i tile coordinate that the node was moved to.
static func move_to_closest_valid_tile_center(node: Node2D, target_tile: Vector2i, source: Node2D, map: TileMapLayer, settings: GridTargetingSettings) -> Vector2i:
	var used_rect: Rect2i = map.get_used_rect()
	var resolved_tile: Vector2i = target_tile

	if settings != null and settings.limit_to_adjacent and is_instance_valid(source):
		resolved_tile = limit_tile_to_max_distance(source, target_tile, map, settings, used_rect)
	else:
		resolved_tile = snap_tile_to_region(target_tile, used_rect)

	move_to_tile_center(node, resolved_tile, map)
	return resolved_tile

## Clamp a target tile so it does not exceed the configured max distance from the source node.
## [param source] The node whose tile position is used as the origin for distance checks.
## [param target_tile] Desired tile to move toward.
## [param map] Tile map providing conversions and used rect bounds.
## [param settings] Targeting settings driving adjacency/limit configuration.
## [param region] Optional precomputed map region to avoid repeated get_used_rect() calls.
## [param astar_grid] Optional AStarGrid2D to honour path constraints; when null a heuristic fallback is used.
static func limit_tile_to_max_distance(source: Node2D, target_tile: Vector2i, map: TileMapLayer, settings: GridTargetingSettings, region: Rect2i = Rect2i(), astar_grid: AStarGrid2D = null) -> Vector2i:
	if map == null:
		return target_tile

	var effective_region := region
	if effective_region.size == Vector2i.ZERO:
		effective_region = map.get_used_rect()

	var snapped_target := snap_tile_to_region(target_tile, effective_region)
	if settings == null or not settings.limit_to_adjacent or not is_instance_valid(source):
		return snapped_target

	var max_steps := max(settings.max_tile_distance, 0)
	if max_steps == 0:
		return snap_tile_to_region(get_tile_from_node_position(source, map), effective_region)

	if astar_grid != null:
		var astar_result := _limit_using_astar(source, snapped_target, map, astar_grid, max_steps, effective_region)
		if astar_result != null:
			return astar_result

	return _limit_via_step(source, snapped_target, map, max_steps, settings.diagonal_mode, effective_region)

## Check if a region is valid for snapping operations.
## [param region] The region to validate.
## [return] True if the region is valid (non-empty with positive size).
static func is_region_valid(region: Rect2i) -> bool:
	return region != Rect2i() and region.size.x > 0 and region.size.y > 0

## Snap a tile coordinate into the provided region bounds.
## [param tile] The tile coordinate to snap.
## [param region] The region bounds to snap within.
## [return] The snapped tile coordinate, or original tile if region is invalid.
static func snap_tile_to_region(tile: Vector2i, region: Rect2i) -> Vector2i:
	if not is_region_valid(region):
		return tile
	var min_x := region.position.x
	var max_x := region.position.x + region.size.x - 1
	var min_y := region.position.y
	var max_y := region.position.y + region.size.y - 1
	var snapped := tile
	snapped.x = clamp(snapped.x, min_x, max_x)
	snapped.y = clamp(snapped.y, min_y, max_y)
	return snapped

## Convert a node's global position to its tile coordinate.
## [param node] The Node2D whose position to convert.
## [param map] The map providing coordinate conversions.
## [return] The tile coordinate as Vector2i, or Vector2i.ZERO if inputs are invalid.
static func get_tile_from_node_position(node: Node2D, map: TileMapLayer) -> Vector2i:
	if node == null or map == null:
		return Vector2i.ZERO
	var local := map.to_local(node.global_position)
	return map.local_to_map(local)

static func _limit_using_astar(source: Node2D, target_tile: Vector2i, map: TileMapLayer, astar_grid: AStarGrid2D, max_steps: int, region: Rect2i) -> Variant:
	if astar_grid == null:
		return null
	var source_tile := get_tile_from_node_position(source, map)
	if not astar_grid.is_in_bounds(source_tile.x, source_tile.y):
		return null
	if not astar_grid.is_in_bounds(target_tile.x, target_tile.y):
		return null
	var path: PackedVector2Array = astar_grid.get_point_path(source_tile, target_tile)
	if path.is_empty():
		return snap_tile_to_region(source_tile, region)
	var index := clamp(max_steps, 0, path.size() - 1)
	var waypoint: Vector2 = path[index]
	var tile := Vector2i(int(round(waypoint.x)), int(round(waypoint.y)))
	return snap_tile_to_region(tile, region)

static func _limit_via_step(source: Node2D, target_tile: Vector2i, map: TileMapLayer, max_steps: int, diagonal_mode: int, region: Rect2i) -> Vector2i:
	var current := get_tile_from_node_position(source, map)
	if max_steps <= 0:
		return snap_tile_to_region(current, region)
	var steps := max_steps
	while steps > 0 and current != target_tile:
		var step := _step_toward(current, target_tile, diagonal_mode)
		if step == Vector2i.ZERO:
			break
		current += step
		steps -= 1
	return snap_tile_to_region(current, region)

static func _step_toward(current: Vector2i, target: Vector2i, diagonal_mode: int) -> Vector2i:
	var dx := target.x - current.x
	var dy := target.y - current.y
	if dx == 0 and dy == 0:
		return Vector2i.ZERO
	var step_x := 0
	var step_y := 0
	if dx > 0:
		step_x = 1
	elif dx < 0:
		step_x = -1
	if dy > 0:
		step_y = 1
	elif dy < 0:
		step_y = -1
	if diagonal_mode == AStarGrid2D.DiagonalMode.DIAGONAL_MODE_NEVER and step_x != 0 and step_y != 0:
		if abs(dx) >= abs(dy):
			step_y = 0
		else:
			step_x = 0
	return Vector2i(step_x, step_y)

## Move the node by an absolute tile delta.
## [param node] The node to move.
## [param p_tile_delta] Tile delta as Vector2i (e.g., (1,0) right, (0,1) down, (1,1) down-right).
## [param target_map] The map used for tile <-> local conversions.
## [return] The Vector2i tile coordinate that the node was moved to.
static func move_node_by_tiles(node: Node2D, p_tile_delta: Vector2i, target_map: TileMapLayer) -> Vector2i:
	var current_tile: Vector2i = get_tile_from_node_position(node, target_map)
	var new_tile: Vector2i = current_tile + p_tile_delta
	return move_to_tile_center(node, new_tile, target_map)

## Recenter a node to the viewport/camera center snapped to the map grid.
## [param node] The node to reposition.
## [param map] The tile map providing conversions.
## [param viewport] The viewport providing screen center coordinates.
## [return] The Vector2i tile coordinate that the node was moved to.
## Convert screen coordinates to world coordinates using Camera2D.
## [b]⭐ CORE COORDINATE CONVERSION FUNCTION - REQUIRES CAMERA2D ⭐[/b]
##
## This is the essential coordinate conversion functionality that powers the entire Grid Building system.
## [color=yellow]This function EXPLICITLY REQUIRES Camera2D for pixel-perfect accuracy![/color]
##
## [b]Camera2D Requirements:[/b]
## • Camera2D must be present in viewport ([code]viewport.get_camera_2d()[/code])
## • Camera2D must be enabled ([code]camera.enabled = true[/code])
## • Camera2D should be current ([code]camera.make_current()[/code])
##
## [b]Why Camera2D is Essential:[/b]
## • [color=lime]Zoom Support[/color] - Handles 0.5x, 1x, 2x, 4x zoom levels accurately
## • [color=lime]Camera Panning[/color] - Accounts for camera position and movement
## • [color=lime]Sub-pixel Precision[/color] - Grid building requires exact tile centers
## • [color=lime]Viewport Scaling[/color] - Works with different screen resolutions
## • [color=lime]Canvas Transforms[/color] - Uses proper Godot coordinate pipeline
##
## [b]Alternative Methods Are Insufficient:[/b]
## Canvas transform alone cannot provide the accuracy needed for pixel-perfect grid placement.
## Only Camera2D + canvas transform combination delivers the precision required.
##
## [param screen_pos] Screen position to convert (e.g., from InputEventMouseMotion.position)
## [param viewport] Viewport containing the Camera2D node
## [return] World position corresponding to screen position, or Vector2.ZERO if Camera2D missing
static func convert_screen_to_world_position(screen_pos: Vector2, viewport: Viewport) -> Vector2:
	var camera: Camera2D = viewport.get_camera_2d()
	if not camera:
		push_error("GBPositioning2DUtils: Camera2D not found in viewport. This utilities class requires Camera2D for proper coordinate conversion.")
		return Vector2.ZERO
	
	# Use Godot's proper canvas transform for accurate coordinate conversion
	# This accounts for camera position, zoom, and all canvas transformations
	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	var world_pos: Vector2 = canvas_transform.affine_inverse() * screen_pos
	
	return world_pos

## Convert viewport center coordinates to world position using camera transforms.
## [b]⭐ REQUIRES CAMERA2D - Essential for viewport center calculations[/b]
##
## This function calculates the world position at the center of the viewport, accounting for
## camera position, zoom, and viewport scaling. Critical for centering operations.
##
## [b]Camera2D Dependency:[/b] Uses [method convert_screen_to_world_position] internally,
## which requires Camera2D for accurate coordinate conversion.
##
## [param viewport] The viewport containing the Camera2D node
## [return] The world position at the center of the viewport
## [b]⚠️ Warning:[/b] Returns Vector2.ZERO if Camera2D is missing from viewport
static func viewport_center_to_world_position(viewport: Viewport) -> Vector2:
	var center_viewport: Vector2 = viewport.get_visible_rect().get_center()
	
	# Reuse the correct coordinate conversion logic from convert_screen_to_world_position
	return convert_screen_to_world_position(center_viewport, viewport)

## Move a node to the viewport center, snapped to the grid.
## [b]⭐ REQUIRES CAMERA2D - Essential for viewport-based positioning[/b]
##
## This function positions a node at the exact center of the viewport, snapped to the nearest
## tile on the grid. Perfect for centering cursors, UI elements, or objects at the camera's
## focus point in 2D games with pixel-perfect accuracy.
##
## [b]Camera2D Requirement:[/b] Uses viewport center coordinate conversion, which requires
## Camera2D for accurate screen-to-world transformation. Without Camera2D, positioning
## will be inaccurate and may not account for zoom/pan operations.
##
## [b]Common Use Cases:[/b]
## • Centering grid cursor when camera moves
## • Positioning UI indicators at screen center
## • Snapping objects to viewport focus point
## • Recentering after zoom/pan operations
##
## [param node] The Node2D to reposition (e.g., grid cursor, selection indicator)
## [param map] The TileMapLayer providing coordinate conversions and grid alignment
## [param viewport] The viewport containing the Camera2D node
## [return] The Vector2i tile coordinate where the node was positioned
## [b]⚠️ Warning:[/b] Positioning may be inaccurate if Camera2D is missing
static func move_node_to_tile_at_viewport_center(node: Node2D, map: TileMapLayer, viewport: Viewport) -> Vector2i:
	var world_position: Vector2 = viewport_center_to_world_position(viewport)
	var tile := get_tile_from_global_position(world_position, map)
	return move_to_tile_center(node, tile, map)

## Convert an arbitrary direction vector into an 8-direction tile delta (-1/0/1 per axis).
## Perfect for 2D grid-based movement systems supporting 8-directional input (WASD + diagonals).
## Cardinal and diagonal directions are supported; tiny components are snapped to 0 by threshold.
## [param direction] The input direction from joystick, keyboard, or mouse (any Vector2).
## [param threshold] Components with absolute value below this are treated as 0 (default 0.33).
## [return] Vector2i with components in {-1, 0, 1} representing tile movement direction.
## [b]Example:[/b] Vector2(0.8, -0.2) becomes Vector2i(1, 0) for rightward movement.
static func direction_to_tile_delta(direction: Vector2, threshold: float = 0.33) -> Vector2i:
	if direction == Vector2.ZERO:
		return Vector2i.ZERO
	var n := direction.normalized()
	var sx := 0
	var sy := 0
	if n.x > threshold:
		sx = 1
	elif n.x < -threshold:
		sx = -1
	if n.y > threshold:
		sy = 1
	elif n.y < -threshold:
		sy = -1
	return Vector2i(sx, sy)

 
