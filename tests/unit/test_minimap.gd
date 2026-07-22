extends GutTest

## Unit tests for WI-34's pure world<->minimap coordinate fit (MinimapTransform).
## Constructed directly - no Global, no nodes, no live world.

const DRAW := Rect2(Vector2(10.0, 20.0), Vector2(200.0, 200.0))
const MIN_SPAN := 900.0

func _fit(world_bounds: Rect2, draw_rect: Rect2 = DRAW, min_span: float = MIN_SPAN) -> MinimapTransform:
	var t := MinimapTransform.new()
	t.configure(world_bounds, draw_rect, min_span)
	return t

# --- min-span clamp ----------------------------------------------------------

func test_small_station_is_clamped_to_min_span() -> void:
	# A 2-cell station (128px) must not zoom past the min world span.
	var t := _fit(Rect2(Vector2(1000.0, 1000.0), Vector2(128.0, 128.0)))
	assert_almost_eq(t.bounds.size.x, MIN_SPAN, 0.001, "world span floored to the minimum")
	assert_almost_eq(t.bounds.size.y, MIN_SPAN, 0.001, "world span floored on both axes")

func test_min_span_expands_around_center() -> void:
	var center := Vector2(1000.0, 1000.0) + Vector2(64.0, 64.0)
	var t := _fit(Rect2(Vector2(1000.0, 1000.0), Vector2(128.0, 128.0)))
	var new_center := t.bounds.position + t.bounds.size * 0.5
	assert_almost_eq(new_center.x, center.x, 0.001, "kept the same center x while growing")
	assert_almost_eq(new_center.y, center.y, 0.001, "kept the same center y while growing")

func test_large_station_keeps_its_own_span() -> void:
	var t := _fit(Rect2(Vector2.ZERO, Vector2(4000.0, 3000.0)))
	assert_almost_eq(t.bounds.size.x, 4000.0, 0.001, "big station past the floor is untouched")
	assert_almost_eq(t.bounds.size.y, 3000.0, 0.001, "big station past the floor is untouched")

# --- uniform (letterbox) fit -------------------------------------------------

func test_scale_is_uniform_and_letterboxed() -> void:
	# Wide 2000x1000 content into a 200x200 box: limited by the wider axis.
	var t := _fit(Rect2(Vector2.ZERO, Vector2(2000.0, 1000.0)))
	assert_almost_eq(t.scale, 200.0 / 2000.0, 0.0001, "uniform scale fits the widest axis")
	# Content height = 1000 * 0.1 = 100, so it's centered vertically in the 200 box:
	# top offset = draw.top + (200 - 100)/2 = 20 + 50 = 70.
	assert_almost_eq(t.offset.y, DRAW.position.y + 50.0, 0.001, "letterboxed vertically about center")
	assert_almost_eq(t.offset.x, DRAW.position.x, 0.001, "flush horizontally (fills the width)")

func test_content_fits_inside_draw_rect() -> void:
	var world := Rect2(Vector2(-500.0, -500.0), Vector2(3000.0, 1200.0))
	var t := _fit(world)
	var tl := t.world_to_map(t.bounds.position)
	var br := t.world_to_map(t.bounds.end)
	assert_gte(tl.x, DRAW.position.x - 0.01, "left edge inside")
	assert_gte(tl.y, DRAW.position.y - 0.01, "top edge inside")
	assert_lte(br.x, DRAW.end.x + 0.01, "right edge inside")
	assert_lte(br.y, DRAW.end.y + 0.01, "bottom edge inside")

# --- roundtrip ---------------------------------------------------------------

func test_world_map_roundtrip() -> void:
	var t := _fit(Rect2(Vector2(-200.0, 300.0), Vector2(2500.0, 1800.0)))
	for world in [Vector2(0.0, 500.0), Vector2(1200.0, 900.0), Vector2(-150.0, 320.0)]:
		var back := t.map_to_world(t.world_to_map(world))
		assert_almost_eq(back.x, world.x, 0.01, "roundtrip x")
		assert_almost_eq(back.y, world.y, 0.01, "roundtrip y")

func test_map_center_maps_to_bounds_center() -> void:
	# With a square content box into a square draw rect, the draw-rect center
	# should map back to the world bounds center.
	var t := _fit(Rect2(Vector2.ZERO, Vector2(1000.0, 1000.0)))
	var draw_center := DRAW.position + DRAW.size * 0.5
	var world := t.map_to_world(draw_center)
	var bounds_center := t.bounds.position + t.bounds.size * 0.5
	assert_almost_eq(world.x, bounds_center.x, 0.01, "center maps to center x")
	assert_almost_eq(world.y, bounds_center.y, 0.01, "center maps to center y")

# --- degenerate guards -------------------------------------------------------

func test_zero_draw_rect_does_not_crash() -> void:
	var t := _fit(Rect2(Vector2.ZERO, Vector2(500.0, 500.0)), Rect2(Vector2.ZERO, Vector2.ZERO))
	assert_eq(t.scale, 1.0, "degenerate draw rect yields a safe unit scale")

func test_zero_world_bounds_uses_min_span() -> void:
	var t := _fit(Rect2(Vector2(500.0, 500.0), Vector2.ZERO))
	assert_almost_eq(t.bounds.size.x, MIN_SPAN, 0.001, "empty content still gets a finite span")
	assert_gt(t.scale, 0.0, "scale stays positive")
