## Polygon Indicator Heuristics
## Extracted from CollisionMapper for deterministic unit testing of indicator generation logic.
class_name PolygonIndicatorHeuristics
extends RefCounted

## Detects if a set of tile offsets forms a hollow (concave/void) pattern based on bounding box density.
## Returns true if (bbox_area > offsets.size() * density_factor)
static func is_hollow(offsets: Array[Vector2i], density_factor: float = 1.5) -> bool:
	if offsets.is_empty():
		return false
	var minx = 999999; var maxx = -999999; var miny = 999999; var maxy = -999999
	for o in offsets:
		minx = min(minx, o.x); maxx = max(maxx, o.x); miny = min(miny, o.y); maxy = max(maxy, o.y)
	var bbox_area: int = (maxx - minx + 1) * (maxy - miny + 1)
	return float(bbox_area) > float(offsets.size()) * density_factor

## Returns true if trapezoid expansion (3/5/5 offsets) should be applied.
## Requirements:
##  - Polygon is convex
##  - Not hollow
##  - Current offsets size <= max_original
##  - Exactly two Y rows present containing -1 and 0 with (0,0) present (pre‑expansion base)
static func should_expand_trapezoid(polygon_is_convex: bool, offsets: Array[Vector2i], ys: Array[int], xs_by_y: Dictionary, hollow: bool, max_original: int = 10) -> bool:
	if not polygon_is_convex or hollow:
		return false
	if offsets.size() == 0 or offsets.size() > max_original:
		return false
	if ys.size() != 2:
		return false
	if not xs_by_y.has(-1) or not xs_by_y.has(0):
		return false
	if Vector2i(0,0) not in offsets:
		return false
	return true

## Generates canonical 13-tile trapezoid offsets (rows y=-1,0,1 => 3/5/5 pattern).
static func generate_trapezoid_offsets() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in [-1,0,1]: result.append(Vector2i(x,-1))
	for x in [-2,-1,0,1,2]: result.append(Vector2i(x,0))
	for x in [-2,-1,0,1,2]: result.append(Vector2i(x,1))
	return result

## Computes precise overlap area between polygon world points and a tile rect (duplicate of S-H clip used for deterministic tests).
static func polygon_tile_overlap_area(polygon: PackedVector2Array, rect: Rect2) -> float:
	if polygon.is_empty():
		return 0.0
	# Bounding box quick reject
	var minx = polygon[0].x; var maxx = minx; var miny = polygon[0].y; var maxy = miny
	for p in polygon:
		minx = min(minx, p.x); maxx = max(maxx, p.x); miny = min(miny, p.y); maxy = max(maxy, p.y)
	if not Rect2(minx, miny, maxx - minx, maxy - miny).intersects(rect, true):
		return 0.0
	var output: PackedVector2Array = polygon
	var left := rect.position.x
	var right := rect.position.x + rect.size.x
	var top := rect.position.y
	var bottom := rect.position.y + rect.size.y
	for boundary in [0,1,2,3]:
		if output.is_empty(): break
		var result: PackedVector2Array = PackedVector2Array()
		var prev: Vector2 = output[output.size()-1]
		var prev_inside := _inside(prev, boundary, left, right, top, bottom)
		for curr in output:
			var curr_inside := _inside(curr, boundary, left, right, top, bottom)
			if curr_inside:
				if not prev_inside: result.append(_intersect(prev, curr, boundary, left, right, top, bottom))
				result.append(curr)
			elif prev_inside:
				result.append(_intersect(prev, curr, boundary, left, right, top, bottom))
			prev = curr; prev_inside = curr_inside
		output = result
	if output.size() < 3:
		return 0.0
	var sum := 0.0
	for i in range(output.size()):
		var a := output[i]
		var b := output[(i + 1) % output.size()]
		sum += a.x * b.y - b.x * a.y
	return abs(sum) * 0.5

static func _inside(p: Vector2, boundary: int, left: float, right: float, top: float, bottom: float) -> bool:
	match boundary:
		0: return p.x >= left - 0.0001
		1: return p.x <= right + 0.0001
		2: return p.y >= top - 0.0001
		3: return p.y <= bottom + 0.0001
		_: return true

static func _intersect(a: Vector2, b: Vector2, boundary: int, left: float, right: float, top: float, bottom: float) -> Vector2:
	var t := 0.0
	match boundary:
		0:
			if abs(b.x - a.x) < 0.0001: return Vector2(left, a.y)
			t = (left - a.x)/(b.x - a.x); return a + (b - a) * t
		1:
			if abs(b.x - a.x) < 0.0001: return Vector2(right, a.y)
			t = (right - a.x)/(b.x - a.x); return a + (b - a) * t
		2:
			if abs(b.y - a.y) < 0.0001: return Vector2(a.x, top)
			t = (top - a.y)/(b.y - a.y); return a + (b - a) * t
		3:
			if abs(b.y - a.y) < 0.0001: return Vector2(a.x, bottom)
			t = (bottom - a.y)/(b.y - a.y); return a + (b - a) * t
		_: return a

## Prunes fringe offsets for concave polygons by removing tiles whose overlap area is below min_area_ratio * tile_area.
## Returns a new array (may be original if no pruning beneficial).
static func prune_concave_fringe(world_points: PackedVector2Array, offsets: Array[Vector2i], center_tile: Vector2i, tile_size: Vector2, min_area_ratio: float = 0.12) -> Array[Vector2i]:
	if offsets.is_empty():
		return offsets

	# If the current offsets nearly fill the bounding box, raise the pruning bar to avoid
	# producing a full bounding-rectangle fill for concave shapes. This specifically
	# targets cases like chevrons/notches where fringe tiles have very small overlap.
	var minx = 999999; var maxx = -999999; var miny = 999999; var maxy = -999999
	for o in offsets:
		minx = min(minx, o.x); maxx = max(maxx, o.x); miny = min(miny, o.y); maxy = max(maxy, o.y)
	var bbox_area: int = (maxx - minx + 1) * (maxy - miny + 1)
	if bbox_area == offsets.size():
		# Fully dense rectangle – increase the minimum overlap requirement to prune notch fringe
		min_area_ratio = max(min_area_ratio, 0.22)
	var tile_area: float = tile_size.x * tile_size.y
	var min_area: float = tile_area * min_area_ratio
	var pruned: Array[Vector2i] = []
	for off in offsets:
		var tile_world := Vector2((center_tile.x + off.x) * tile_size.x, (center_tile.y + off.y) * tile_size.y)
		var rect := Rect2(tile_world, tile_size)
		var area := polygon_tile_overlap_area(world_points, rect)
		if area >= min_area:
			pruned.append(off)
	if pruned.size() > 0 and pruned.size() < offsets.size():
		return pruned
	return offsets
