## Helpers to normalize tile coverage and prune borderline tiles for mapper heuristics.
##
## Keep shape-size magic numbers out of the CollisionMapper by centralizing tile-range adjustments and pruning logic here.
class_name GBCollisionTileFilter
extends RefCounted
## [b]Collision Tile Filter Utilities[/b]
## Helpers to normalize tile coverage ranges and prune borderline tiles without
## embedding shape-size magic numbers in the mapper implementation.

## [b]Adjust rectangle tile iteration bounds[/b]
## Ensures even tile counts along any axis are expanded to the next odd count for
## symmetric coverage around the rectangle's world center tile.
## [b]Parameters[/b]:
##  • [code]rect_size[/code]: Vector2 – world-space size of the rectangle AABB.
##  • [code]tile_size[/code]: Vector2 – tile size.
##  • [code]center_tile[/code]: Vector2i – tile containing the rectangle's world center.
##  • [code]start_tile[/code], [code]end_exclusive[/code]: Vector2i – raw iteration bounds.
## [b]Returns[/b]: Dictionary – keys: [code]start[/code], [code]end_exclusive[/code].
static func adjust_rect_tile_range(rect_size: Vector2, tile_size: Vector2, center_tile: Vector2i, start_tile: Vector2i, end_exclusive: Vector2i) -> Dictionary:
	var tiles_w = int(ceil(rect_size.x / tile_size.x))
	var tiles_h = int(ceil(rect_size.y / tile_size.y))
	var width_half_span = int(floor(tiles_w / 2.0))
	var height_half_span = int(floor(tiles_h / 2.0))
	# Ensure odd counts: if even, increment span by 1 on the positive side
	if tiles_w % 2 == 0:
		# Increase total width by 1
		width_half_span = tiles_w/2
		tiles_w += 1
	if tiles_h % 2 == 0:
		height_half_span = tiles_h/2
		tiles_h += 1
	var new_start = Vector2i(center_tile.x - int(floor(tiles_w/2.0)), center_tile.y - int(floor(tiles_h/2.0)))
	var new_end_exclusive = Vector2i(new_start.x + tiles_w, new_start.y + tiles_h)
	return {"start": new_start, "end_exclusive": new_end_exclusive}

## [b]Circle tile pruning[/b]
## Generic pruning based on the distance of the tile center from the circle center.
## Excludes extreme corner tiles whose centers lie beyond [code]radius + half_tile[/code] allowance.
## [b]Returns[/b]: bool – [code]true[/code] if the tile is allowed.
static func circle_tile_allowed(circle_center: Vector2, radius: float, tile_center: Vector2, tile_size: Vector2) -> bool:
	var allowance = radius + tile_size.x/2.0
	return circle_center.distance_to(tile_center) <= allowance
