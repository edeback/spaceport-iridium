## Manage configuration and path queries for AStarGrid2D instances used by grid targeting.
class_name GBAStarPathManager
extends RefCounted

var _grid: AStarGrid2D = AStarGrid2D.new()
var _settings: GridTargetingSettings
var _last_region: Rect2i = Rect2i()

## Optionally configure dependencies during construction.
## [param settings] Targeting settings to apply immediately.
func _init(settings: GridTargetingSettings, p_target_map: TileMapLayer) -> void:
	_settings = settings
	update_region(p_target_map)
	
## Return the managed AStarGrid2D instance.
## [return] The active AStarGrid2D.
func get_grid() -> AStarGrid2D:
	return _grid

## Replace the managed AStarGrid2D instance.
## [param grid] Grid to adopt; when null, a new AStarGrid2D is allocated.
func set_grid(grid: AStarGrid2D) -> bool:
	var new_grid := grid if grid != null else AStarGrid2D.new()
	if _grid == new_grid:
		return false
	_grid = new_grid
	_last_region = Rect2i()
	return true

## Configure the manager using targeting settings and optional logger.
## [param settings] Targeting settings that drive grid configuration.
func configure(settings: GridTargetingSettings) -> void:
	_settings = settings
	_apply_settings()

## Apply the current settings to the managed grid, updating key heuristics and region.
func _apply_settings() -> void:
	if _grid == null or _settings == null:
		return
	_grid.diagonal_mode = _settings.diagonal_mode
	_grid.default_compute_heuristic = _settings.default_compute_heuristic
	_grid.default_estimate_heuristic = _settings.default_estimate_heuristic
	_grid.cell_shape = _settings.cell_shape
	_update_region_from_settings()
	_grid.update()

## Update the grid region using the targeting settings region_size.
func _update_region_from_settings() -> void:
	if _grid == null or _settings == null:
		return
	var size: Vector2i = _settings.region_size
	_grid.region = Rect2(0, 0, float(size.x), float(size.y))

## Respond to a region size change event from GridTargetingSettings.
## [param size] New region size to apply.
func on_region_size_changed(size: Vector2i) -> void:
	if _grid == null:
		return
	_grid.region = Rect2(0, 0, float(size.x), float(size.y))
	_grid.update()

## Respond to a diagonal mode change.
## [param mode] New diagonal mode.
func on_diagonal_mode_changed(mode: AStarGrid2D.DiagonalMode) -> void:
	if _grid == null:
		return
	_grid.diagonal_mode = mode

## Respond to a compute heuristic change.
## [param heuristic] New compute heuristic.
func on_default_compute_heuristic_changed(heuristic: AStarGrid2D.Heuristic) -> void:
	if _grid == null:
		return
	_grid.default_compute_heuristic = heuristic

## Respond to an estimate heuristic change.
## [param heuristic] New estimate heuristic.
func on_default_estimate_heuristic_changed(heuristic: AStarGrid2D.Heuristic) -> void:
	if _grid == null:
		return
	_grid.default_estimate_heuristic = heuristic

## Respond to a cell shape change.
## [param shape] New cell shape.
func on_cell_shape_changed(shape: AStarGrid2D.CellShape) -> void:
	if _grid == null:
		return
	_grid.cell_shape = shape

## Update the cached region bounds from the provided map.
## [param map] Tile map the positioner operates on.
func update_region(map: TileMapLayer) -> void:
	if map == null:
		_last_region = Rect2i()
		return
	var region := map.get_used_rect()
	if region.size == Vector2i.ZERO and _grid != null:
		var grid_region := _grid.region
		region = Rect2i(int(grid_region.position.x), int(grid_region.position.y), int(grid_region.size.x), int(grid_region.size.y))
	_last_region = region

## Update the managed grid when marked dirty.
func update_if_dirty() -> void:
	if _grid == null:
		return
	if _grid.is_dirty():
		_grid.update()

## Resolve the desired target tile by applying region refresh and limiting rules.
## [param source] Node whose tile acts as the origin for adjacency limits.
## [param target_tile] Desired destination tile.
## [param map] Tile map providing region bounds.
## [param settings_override] Optional settings override used during limiting.
## [return] Tile clamped to region and adjacency limits.
func resolve_target_tile(source: Node2D, target_tile: Vector2i, map: TileMapLayer, settings_override: GridTargetingSettings = null) -> Vector2i:
	update_region(map)
	return limit_tile_to_max_distance(source, target_tile, map, settings_override)

## Public facade: return the closest valid tile given a requested tile and a source node.
## This consolidates adjacency & region logic in one place for callers.
func get_closest_valid_tile(requested_tile: Vector2i, source: Node2D, map: TileMapLayer, settings_override: GridTargetingSettings = null) -> Vector2i:
	# Provided for clarity and future extension (e.g., caching, heuristics)
	return resolve_target_tile(source, requested_tile, map, settings_override)

## Limit the desired tile so it does not exceed the configured max distance from the source node.
## [param source] Node whose tile is used as the origin for distance checks.
## [param target_tile] Desired tile to clamp.
## [param map] Map used for conversions and fallback region data.
## [param settings_override] Optional override for targeting settings.
## [return] Tile respecting adjacency and region limits.
func limit_tile_to_max_distance(source: Node2D, target_tile: Vector2i, map: TileMapLayer, settings_override: GridTargetingSettings = null) -> Vector2i:
	if map == null:
		return target_tile

	var settings := settings_override if settings_override != null else _settings
	var region := map.get_used_rect()
	if region.size == Vector2i.ZERO:
		if _last_region.size != Vector2i.ZERO:
			region = _last_region
		elif _grid != null:
			var grid_region := _grid.region
			region = Rect2i(int(grid_region.position.x), int(grid_region.position.y), int(grid_region.size.x), int(grid_region.size.y))

	var snapped_target := GBPositioning2DUtils.snap_tile_to_region(target_tile, region)
	if settings == null or not settings.limit_to_adjacent or not is_instance_valid(source):
		return snapped_target

	var max_steps := max(settings.max_tile_distance, 0)
	var source_tile := _sample_tile_from_node(source, map)
	if max_steps == 0:
		return GBPositioning2DUtils.snap_tile_to_region(source_tile, region)

	var limited := _limit_using_astar(source_tile, snapped_target, max_steps, region)
	if limited != null:
		return limited

	return _limit_via_step(source_tile, snapped_target, max_steps, settings.diagonal_mode, region)

func _limit_using_astar(source_tile: Vector2i, target_tile: Vector2i, max_steps: int, region: Rect2i) -> Variant:
	if _grid == null:
		return null
	if not _grid.is_in_bounds(source_tile.x, source_tile.y):
		return null
	if not _grid.is_in_bounds(target_tile.x, target_tile.y):
		return null
	var path: PackedVector2Array = _grid.get_point_path(source_tile, target_tile)
	if path.is_empty():
		return GBPositioning2DUtils.snap_tile_to_region(source_tile, region)
	var index := clamp(max_steps, 0, path.size() - 1)
	var waypoint: Vector2 = path[index]
	var tile := Vector2i(int(round(waypoint.x)), int(round(waypoint.y)))
	return GBPositioning2DUtils.snap_tile_to_region(tile, region)

func _limit_via_step(current_tile: Vector2i, target_tile: Vector2i, max_steps: int, diagonal_mode: int, region: Rect2i) -> Vector2i:
	var current := current_tile
	var steps := max_steps
	while steps > 0 and current != target_tile:
		var step := _step_toward(current, target_tile, diagonal_mode)
		if step == Vector2i.ZERO:
			break
		current += step
		steps -= 1
	return GBPositioning2DUtils.snap_tile_to_region(current, region)

func _step_toward(current: Vector2i, target: Vector2i, diagonal_mode: int) -> Vector2i:
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

func _sample_tile_from_node(node: Node2D, map: TileMapLayer) -> Vector2i:
	if node == null or map == null:
		return Vector2i.ZERO
	var local := map.to_local(node.global_position)
	return map.local_to_map(local)
