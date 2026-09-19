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
	for world: Vector2 in [Vector2(0.0, 500.0), Vector2(1200.0, 900.0), Vector2(-150.0, 320.0)]:
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

# --- fitted-box hysteresis ---------------------------------------------------

const SLACK := 0.12
const SHRINK := 1.6

func _settle(current: Rect2, desired: Rect2) -> Rect2:
	return MinimapTransform.settle_bounds(current, desired, SLACK, SHRINK)

func test_first_fit_adopts_the_content() -> void:
	var desired := Rect2(Vector2(100.0, 100.0), Vector2(1000.0, 1000.0))
	var settled := _settle(Rect2(), desired)
	assert_true(settled.encloses(desired), "empty starting box takes the content")
	assert_almost_eq(settled.size.x, 1000.0 * (1.0 + 2.0 * SLACK), 0.001, "padded by the slack")

func test_drifting_inside_the_box_does_not_resize() -> void:
	# The whole point: an asteroid wandering within the current box must leave the
	# fit completely untouched, so the map holds still.
	var current := Rect2(Vector2.ZERO, Vector2(2000.0, 2000.0))
	var settled := _settle(current, Rect2(Vector2(400.0, 300.0), Vector2(1400.0, 1500.0)))
	assert_eq(settled, current, "no resize while the content stays inside")

func test_content_escaping_grows_immediately() -> void:
	var current := Rect2(Vector2.ZERO, Vector2(2000.0, 2000.0))
	var desired := Rect2(Vector2(-300.0, 500.0), Vector2(900.0, 900.0))
	var settled := _settle(current, desired)
	assert_true(settled.encloses(desired), "the escaped content is visible again")
	assert_true(settled.encloses(current), "growth never drops what was already shown")

func test_growth_overshoots_so_continued_drift_is_free() -> void:
	# A rock drifting steadily outward should not resize the map every tick: the
	# slack added by one growth has to absorb the next several steps.
	var box := Rect2(Vector2.ZERO, Vector2(2000.0, 2000.0))
	var edge := 2000.0
	var resizes := 0
	for i in 12:
		edge += 20.0
		var desired := Rect2(Vector2.ZERO, Vector2(edge, 2000.0))
		var next := _settle(box, desired)
		if next != box:
			resizes += 1
		box = next
		assert_true(box.encloses(desired), "content stays inside at step %d" % i)
	assert_lt(resizes, 3, "240px of outward drift costs at most a couple of resizes")

func test_small_shrink_is_ignored() -> void:
	var current := Rect2(Vector2.ZERO, Vector2(2000.0, 2000.0))
	# 25% smaller - visible, but nowhere near worth rescaling the whole map for.
	var settled := _settle(current, Rect2(Vector2(250.0, 250.0), Vector2(1500.0, 1500.0)))
	assert_eq(settled, current, "the box holds until the content is much smaller")

func test_large_shrink_refits() -> void:
	# Raid over, the far-flung ships are gone: the map should come back in.
	var current := Rect2(Vector2.ZERO, Vector2(4000.0, 4000.0))
	var desired := Rect2(Vector2(1800.0, 1800.0), Vector2(600.0, 600.0))
	var settled := _settle(current, desired)
	assert_lt(settled.size.x, current.size.x * 0.5, "refitted down to the real content")
	assert_true(settled.encloses(desired), "and the content is still fully inside")

func test_resize_does_not_trigger_its_own_opposite() -> void:
	# The invariant tying the two constants together: settling twice on unchanged
	# content must be a fixed point, or the map oscillates every tick.
	var desired := Rect2(Vector2(500.0, 500.0), Vector2(700.0, 1300.0))
	var once := _settle(Rect2(Vector2.ZERO, Vector2(6000.0, 6000.0)), desired)
	var twice := _settle(once, desired)
	assert_eq(twice, once, "second pass on the same content is a no-op")

# --- edge contacts (WI-61) ---------------------------------------------------

func test_a_point_inside_the_map_is_not_an_edge_contact() -> void:
	var inside := Vector2(100.0, 120.0)
	assert_false(MinimapTransform.is_outside(inside, DRAW), "well within the map")
	assert_eq(MinimapTransform.clamp_to_map(inside, DRAW), inside, "and left exactly where it is")

func test_a_point_on_the_border_counts_as_inside() -> void:
	# The transition case: a comet crossing the boundary must not flicker between
	# a rim contact and an ordinary dot.
	for corner: Vector2 in [DRAW.position, DRAW.end,
			Vector2(DRAW.position.x, DRAW.end.y), Vector2(DRAW.end.x, DRAW.position.y)]:
		assert_false(MinimapTransform.is_outside(corner, DRAW), "exactly on the edge is inside")
		assert_eq(MinimapTransform.clamp_to_map(corner, DRAW), corner, "so it does not move")

func test_far_contacts_are_pulled_onto_the_rim_in_every_direction() -> void:
	var centre: Vector2 = DRAW.get_center()
	for offset: Vector2 in [Vector2(5000.0, 0.0), Vector2(-5000.0, 0.0),
			Vector2(0.0, 5000.0), Vector2(0.0, -5000.0),
			Vector2(5000.0, 5000.0), Vector2(-5000.0, -5000.0)]:
		var far: Vector2 = centre + offset
		assert_true(MinimapTransform.is_outside(far, DRAW), "a comet thousands of px out")
		var clamped: Vector2 = MinimapTransform.clamp_to_map(far, DRAW)
		assert_true(DRAW.has_point(clamped) or _on_border(clamped),
				"lands on the map rather than off it")
		# The contact has to keep its bearing, or it is pointing at the wrong sky.
		assert_eq(signf(clamped.x - centre.x), signf(offset.x), "keeps its x bearing")
		assert_eq(signf(clamped.y - centre.y), signf(offset.y), "keeps its y bearing")

func _on_border(point: Vector2) -> bool:
	return is_equal_approx(point.x, DRAW.position.x) or is_equal_approx(point.x, DRAW.end.x) \
			or is_equal_approx(point.y, DRAW.position.y) or is_equal_approx(point.y, DRAW.end.y)
