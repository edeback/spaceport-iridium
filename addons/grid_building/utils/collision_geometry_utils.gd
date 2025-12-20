## Pure, stateless helpers used by the placement/collision mapping pipeline.
## These functions are extracted from the runtime mapper to allow focused unit tests
## and reuse from multiple contexts without side-effects.
##
## [b]Default Overlap Thresholds[/b]
## - Edge epsilon: [code]0.01[/code] (1% tolerance for edge detection)
## - Minimum area fraction: [code]0.05[/code] (5% of tile area required for overlap)
## - Very small polygons (< 5% of tile area) are filtered out to avoid spurious detections
## - For 16×16 tiles, minimum overlap area is 12.8 square units
## - For 32×32 tiles, minimum overlap area is 51.2 square units
##
## [b]Testing Notes[/b]
## - Micro polygons smaller than 5% threshold return zero tiles (by design)
## - Use larger polygons (≥25% tile area) for reliable collision detection in tests
## - Production mapper may use different thresholds for specific shape types
##
## [i]Documentation style[/i]: Comments use BBCode to render nicely in the Godot editor's help panel.
##
## Cross‑references
## - Center‑based tile semantics: Indicator and mapper math assume tile centers; e.g., 16×16 → center offset (+8,+8).
## - Iteration range epsilon: compute_tile_iteration_range applies symmetric epsilons to min/max to avoid fencepost tiles
##   when world bounds align exactly to tile borders (bottom‑inclusive, top‑exclusive in practice).
class_name CollisionGeometryUtils
extends RefCounted

## [b]Dependency[/b]: Calculator providing pure geometry operations such as polygontile overlap.

## [b]Builds a world transform[/b] for a specific collision [code]shape_owner[/code]
## attached to a [code]col_obj[/code] (the owning Node2D).
##
## [b]Order of operations[/b]
## 1) Apply the object’s rotation and scale.
## 2) Apply the shape owner’s local rotation and scale.
## 3) Apply the shape owner’s local offset (position) in the object’s rotated/scaled space.
##
## Returns identity when inputs are invalid.
##
## [b]Parameters[/b]
## - [code]col_obj: Node2D[/code] — The collision object (owner of the shape).
## - [code]shape_owner: Node2D[/code] — The node that carries the local transform for the shape.
##
## [b]Returns[/b]
## - [code]Transform2D[/code] — World transform for the individual shape owner.
##
## [b]Notes[/b]
## - Keeps parity with legacy mapper logic; use when composing per-shape transforms.
## - Does not consider a TileMap’s transform; see the [code]center_tile_for_*[/code] helpers for
##   world↔local conversions against TileMap layers.
static func build_shape_transform(col_obj: Node2D, shape_owner: Node2D) -> Transform2D:
	if col_obj == null or shape_owner == null:
		return Transform2D()
	var shape_transform := Transform2D()
	# Apply object rotation & scale first
	if col_obj.rotation != 0.0:
		shape_transform = shape_transform.rotated(col_obj.rotation)
	if col_obj.scale != Vector2.ONE:
		shape_transform = shape_transform.scaled(col_obj.scale)
	# Apply shape owner's local rotation & scale
	if shape_owner.rotation != 0.0:
		shape_transform = shape_transform.rotated(shape_owner.rotation)
	if shape_owner.scale != Vector2.ONE:
		shape_transform = shape_transform.scaled(shape_owner.scale)
	# Compute local offset relative to object applying object rotation & scale (matches legacy logic)
	var shape_local_offset = shape_owner.position
	if col_obj.rotation != 0.0:
		shape_local_offset = shape_local_offset.rotated(col_obj.rotation)
	if col_obj.scale != Vector2.ONE:
		shape_local_offset *= col_obj.scale
	shape_transform.origin = col_obj.global_position + shape_local_offset
	return shape_transform

## [b]Converts a CollisionPolygon2D to world-space points[/b].
##
## Applies the node’s global transform to each local polygon vertex.
## Returns an empty array when [code]polygon_node[/code] is null.
##
## [b]Parameters[/b]
## - [code]polygon_node: CollisionPolygon2D[/code]
##
## [b]Returns[/b]
## - [code]PackedVector2Array[/code] — World-space vertices.
static func to_world_polygon(polygon_node: CollisionPolygon2D) -> PackedVector2Array:
	var world_points: PackedVector2Array = PackedVector2Array()
	if polygon_node == null:
		return world_points
	var global_xform := polygon_node.get_global_transform()
	for p in polygon_node.polygon:
		world_points.append(global_xform * p)
	return world_points

## [b]Converts world-space bounds to a tile iteration range[/b].
##
## Mirrors mapper iteration by computing the inclusive start tile and an exclusive end tile
## using the TileMap layer’s transform. A small epsilon is subtracted from the max corner to
## avoid fencepost inclusion of a tile when the bounds sit exactly on a tile border.
##
## [b]Parameters[/b]
## - [code]bounds: Rect2[/code] — World-space AABB to iterate over.
## - [code]map: TileMapLayer[/code] — Target TileMap layer.
##
## [b]Returns[/b]
## - [code]Dictionary[/code] — { [code]"start" : Vector2i[/code], [code]"end_exclusive" : Vector2i[/code] }
static func compute_tile_iteration_range(bounds: Rect2, map: TileMapLayer) -> Dictionary:

	# Converts polygon/shape bounds into tile start/end_exclusive range mirroring mapper logic.
	# Returns {"start": Vector2i, "end_exclusive": Vector2i}
	var result := {}

	if map == null:
		return result
	# Nudge the min corner slightly inward to avoid including an extra tile
	# when the polygon bounds sit exactly on a tile boundary. The mapper
	# already subtracts a tiny epsilon from the max corner; apply a small
	# positive epsilon to the min corner for symmetric behavior.
	var epsilon = 0.0001
	var adjusted_min_corner = bounds.position + Vector2(epsilon, epsilon)
	var start_tile = map.local_to_map(map.to_local(adjusted_min_corner))
	var adjusted_max_corner = bounds.position + bounds.size - Vector2(epsilon, epsilon)
	var end_tile_inclusive = map.local_to_map(map.to_local(adjusted_max_corner))
	var end_exclusive = Vector2i(end_tile_inclusive.x + 1, end_tile_inclusive.y + 1)
	result["start"] = start_tile
	result["end_exclusive"] = end_exclusive
	return result

## [b]Computes the center tile[/b] for a polygon positioner node on a given TileMap layer.
## Uses [code]map.to_local()[/code] followed by [code]local_to_map()[/code] to respect map transforms.
## Returns [code]Vector2i.ZERO[/code] if inputs are invalid.
##
## [b]Parameters[/b]
## - [code]map: TileMapLayer[/code]
## - [code]positioner: Node2D[/code]
##
## [b]Returns[/b]
## - [code]Vector2i[/code] — Tile coordinates of the center.
static func center_tile_for_polygon_positioner(map: TileMapLayer, positioner: Node2D) -> Vector2i:
	if map == null or positioner == null:
		return Vector2i.ZERO
	return map.local_to_map(map.to_local(positioner.global_position))

## [b]Computes the center tile[/b] for a collision shape-carrying object on a TileMap layer.
## Uses [code]map.to_local()[/code] followed by [code]local_to_map()[/code] to respect map transforms.
## Returns [code]Vector2i.ZERO[/code] if inputs are invalid.
##
## [b]Parameters[/b]
## - [code]map: TileMapLayer[/code]
## - [code]col_obj: Node2D[/code]
##
## [b]Returns[/b]
## - [code]Vector2i[/code] — Tile coordinates of the center.
static func center_tile_for_shape_object(map: TileMapLayer, col_obj: Node2D) -> Vector2i:
	if map == null or col_obj == null:
		return Vector2i.ZERO
	return map.local_to_map(map.to_local(col_obj.global_position))

## [b]Computes tile offsets[/b] covered by a world-space polygon relative to a [code]center_tile[/code].
##
## This delegates to [code]CollisionGeometryCalculator.calculate_tile_overlap()[/code] with conservative
## defaults suitable for unit tests.
##
## [b]Thresholds[/b]
## - Edge epsilon: [code]0.01[/code] (1% of tile size)
## - Min area fraction: [code]0.05[/code] (5% of tile area)
##
## [b]Parameters[/b]
## - [code]world_points: PackedVector2Array[/code] — Polygon in world space.
## - [code]tile_size: Vector2[/code] — Size of a tile in world units.
## - [code]center_tile: Vector2i[/code] — Origin tile for computing offsets.
## - [code]tile_type: TileSet.TileShape = TileSet.TILE_SHAPE_SQUARE[/code] — Tile shape type.
##
## [b]Returns[/b]
## - [code]Array[Vector2i][/code] — Offsets from [code]center_tile[/code] for all overlapped tiles.
##
## [b]Notes[/b]
## - The production mapper may use different thresholds per shape type; these test defaults
##   are intentionally conservative and stable.
static func compute_polygon_tile_offsets(world_points: PackedVector2Array, tile_size: Vector2, center_tile: Vector2i, tile_shape: TileSet.TileShape = TileSet.TILE_SHAPE_SQUARE, tile_map_layer: TileMapLayer = null) -> Array[Vector2i]:
	# Given world-space polygon points, returns tile offsets relative to center_tile.
	# Uses existing CollisionGeometryCalculator pure logic. Intended for unit tests and refactors.
	var offsets: Array[Vector2i] = []
	if world_points.is_empty():
		return offsets
	# Require a minimum meaningful overlap (~5% of tile area) to consider tile covered.
	# Keep the public helper conservative (5%) so micro-polygons are filtered reliably.
	# Internal AREA_REL_EPS in the calculator provides a small tolerance for borderline cases.
	# Use TileSet.TileShape directly
	var overlapped_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(world_points, tile_size, tile_shape, tile_map_layer, 0.01, 0.05)
	for tile_pos in overlapped_tiles:
		offsets.append(tile_pos - center_tile)
	return offsets

## [b]Checks strict convexity[/b] of a polygon (winding-agnostic).
##
## Uses cross product sign consistency and ignores collinear or duplicate edges.
## Triangles are considered convex.
##
## [b]Parameters[/b]
## - [code]points: PackedVector2Array[/code]
##
## [b]Returns[/b]
## - [code]bool[/code] — [code]true[/code] if the polygon is strictly convex; otherwise [code]false[/code].
static func is_polygon_convex(points: PackedVector2Array) -> bool:
	var n := points.size()
	if n < 4: # triangles always convex
		return true
	var sign := 0
	for i in n:
		var a := points[i]
		var b := points[(i+1) % n]
		var c := points[(i+2) % n]
		var cross := (b - a).cross(c - b)
		if abs(cross) < 0.0001:
			continue
		var curr_sign := signi(cross)
		if sign == 0:
			sign = curr_sign
		elif curr_sign != sign:
			return false
	return true
