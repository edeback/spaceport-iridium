## Manages caching for geometry calculations to improve performance.
extends RefCounted

var _geometry_cache: Dictionary = {}
var _polygon_bounds_cache: Dictionary = {}
var _tile_polygon_cache: Dictionary = {}
var _cache_frame: int = 0

## Invalidates all cached geometry data when setup changes.
func invalidate_cache() -> void:
	_geometry_cache.clear()
	_polygon_bounds_cache.clear()
	_tile_polygon_cache.clear()
	_cache_frame = Engine.get_process_frames()

## Gets cached polygon bounds or calculates and caches if not found.
func get_cached_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var cache_key = str(polygon)
	if _polygon_bounds_cache.has(cache_key):
		return _polygon_bounds_cache[cache_key]
	
	var bounds = GBGeometryMath.get_polygon_bounds(polygon)
	_polygon_bounds_cache[cache_key] = bounds
	return bounds

## Gets cached tile polygon or calculates and caches if not found.
func get_cached_tile_polygon(tile_pos: Vector2, tile_size: Vector2, tile_type: TileSet.TileShape) -> PackedVector2Array:
	var cache_key = "%s_%s_%d" % [tile_pos, tile_size, tile_type]
	if _tile_polygon_cache.has(cache_key):
		return _tile_polygon_cache[cache_key]
	
	var tile_polygon = GBGeometryMath.get_tile_polygon(tile_pos, tile_size, tile_type)
	_tile_polygon_cache[cache_key] = tile_polygon
	return tile_polygon

## Gets cached geometry calculation result or calculates and caches if not found.
func get_cached_geometry_result(cache_key: String, calculation_func: Callable) -> Variant:
	if _geometry_cache.has(cache_key):
		return _geometry_cache[cache_key]
	
	var result = calculation_func.call()
	_geometry_cache[cache_key] = result
	return result
