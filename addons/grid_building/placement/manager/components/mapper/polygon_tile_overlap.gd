## Utility functions for polygon-tile overlap calculations.
## 
## Provides static methods for geometric calculations used by both
## CollisionMapper and PolygonTileMapper to avoid code duplication.
class_name PolygonTileOverlap

## Compute precise overlap area (world units^2) between a polygon and a rectangular tile using
## Sutherland–Hodgman clipping followed by the shoelace formula.
## [b]Parameters[/b]:
##  • [code]polygon[/code]: PackedVector2Array – world points.
##  • [code]rect[/code]: Rect2 – tile rect in world.
## [b]Returns[/b]: float – overlap area (>= 0).
static func compute_overlap_area(polygon: PackedVector2Array, rect: Rect2) -> float:
	if polygon.is_empty():
		return 0.0
	
	# Quick bounds check
	var poly_bounds = _compute_polygon_bounds(polygon)
	if not poly_bounds.intersects(rect, true):
		return 0.0
	
	# Sutherland-Hodgman clipping
	var clipped = _clip_polygon_to_rect(polygon, rect)
	if clipped.size() < 3:
		return 0.0
	
	return _compute_polygon_area(clipped)

## Helper: Compute polygon bounding rectangle
static func _compute_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	
	var min_pt = polygon[0]
	var max_pt = polygon[0]
	
	for p in polygon:
		min_pt.x = min(min_pt.x, p.x)
		min_pt.y = min(min_pt.y, p.y)
		max_pt.x = max(max_pt.x, p.x)
		max_pt.y = max(max_pt.y, p.y)
	
	return Rect2(min_pt, max_pt - min_pt)

## Helper: Clip polygon against rectangle using Sutherland-Hodgman algorithm
static func _clip_polygon_to_rect(polygon: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var output = polygon
	var boundaries = [
		{"type": "left", "value": rect.position.x},
		{"type": "right", "value": rect.position.x + rect.size.x},
		{"type": "top", "value": rect.position.y},
		{"type": "bottom", "value": rect.position.y + rect.size.y}
	]
	
	for boundary in boundaries:
		if output.is_empty():
			break
		
		var result: PackedVector2Array = PackedVector2Array()
		if output.size() > 0:
			var prev = output[output.size() - 1]
			var prev_inside = _point_inside_boundary(prev, boundary)
			
			for curr in output:
				var curr_inside = _point_inside_boundary(curr, boundary)
				
				if curr_inside:
					if not prev_inside:
						result.append(_compute_intersection(prev, curr, boundary))
					result.append(curr)
				elif prev_inside:
					result.append(_compute_intersection(prev, curr, boundary))
				
				prev = curr
				prev_inside = curr_inside
		
		output = result
	
	return output

## Helper: Test if point is inside clipping boundary
static func _point_inside_boundary(point: Vector2, boundary: Dictionary) -> bool:
	var epsilon = 0.0001
	match boundary.type:
		"left": return point.x >= boundary.value - epsilon
		"right": return point.x <= boundary.value + epsilon
		"top": return point.y >= boundary.value - epsilon
		"bottom": return point.y <= boundary.value + epsilon
		_: return true

## Helper: Compute line-boundary intersection
static func _compute_intersection(a: Vector2, b: Vector2, boundary: Dictionary) -> Vector2:
	var t = 0.0
	match boundary.type:
		"left", "right":
			if abs(b.x - a.x) < 0.0001:
				return Vector2(boundary.value, a.y)
			t = (boundary.value - a.x) / (b.x - a.x)
		"top", "bottom":
			if abs(b.y - a.y) < 0.0001:
				return Vector2(a.x, boundary.value)
			t = (boundary.value - a.y) / (b.y - a.y)
	
	return a + (b - a) * t

## Helper: Compute polygon area using shoelace formula
static func _compute_polygon_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	
	var sum = 0.0
	for i in polygon.size():
		var a = polygon[i]
		var b = polygon[(i + 1) % polygon.size()]
		sum += a.x * b.y - b.x * a.y
	
	return abs(sum) * 0.5
