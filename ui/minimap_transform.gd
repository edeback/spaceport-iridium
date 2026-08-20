class_name MinimapTransform
extends RefCounted

## Pure world<->minimap coordinate mapping (WI-34). Fits a world-space bounding
## box (modules + asteroids) uniformly into the minimap's draw rectangle,
## letterboxing so aspect ratio is preserved, and clamps a minimum world span so
## a tiny young station doesn't blow up into three giant pixels. Kept free of
## Global/nodes so it unit-tests directly (see tests/unit/test_minimap.gd).

## Map-space pixels per world-space pixel (uniform on both axes).
var scale: float = 1.0
## Map-space top-left where the letterboxed content begins.
var offset: Vector2 = Vector2.ZERO
## The world bounds actually used after the min-span clamp (a small station's
## bounds get grown around their center, so this can be larger than the input).
var bounds: Rect2 = Rect2()

## Recompute scale/offset for `world_bounds` fitted into `draw_rect` (both in
## their own spaces). `min_world_span` grows a degenerate/small box around its
## center so the fit never zooms past a sensible level.
func configure(world_bounds: Rect2, draw_rect: Rect2, min_world_span: float) -> void:
	var span: Vector2 = world_bounds.size
	var center: Vector2 = world_bounds.position + span * 0.5
	span.x = maxf(span.x, min_world_span)
	span.y = maxf(span.y, min_world_span)
	bounds = Rect2(center - span * 0.5, span)
	# Uniform (letterbox) fit; guard the degenerate draw rect so scale stays finite.
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
		scale = 1.0
		offset = draw_rect.position
		return
	scale = minf(draw_rect.size.x / bounds.size.x, draw_rect.size.y / bounds.size.y)
	var content: Vector2 = bounds.size * scale
	offset = draw_rect.position + (draw_rect.size - content) * 0.5

func world_to_map(world: Vector2) -> Vector2:
	return offset + (world - bounds.position) * scale

func map_to_world(map: Vector2) -> Vector2:
	if scale == 0.0:
		return bounds.position
	return bounds.position + (map - offset) / scale

# --- fitted-box hysteresis ----------------------------------------------------

## Settle the box the fit actually uses. Asteroids drift and ships orbit every
## slow_tick, so feeding the raw content AABB straight into configure() rescales
## the whole map several times a second and nothing on it holds still. Rules:
##
##   - Grow immediately whenever `desired` escapes `current` - everything the
##     minimap draws has to stay on the minimap.
##   - Shrink only once `current` is `shrink_ratio` times larger than it needs to
##     be on either axis (the letterbox fit is driven by whichever axis is
##     tighter, so per-axis, not by area).
##   - Either way pad the new box by `slack` of its own span on each side, so the
##     next few ticks of drift land inside it instead of resizing again.
##
## Keep `1 + 2 * slack` comfortably below `shrink_ratio` or the padding added by
## one resize is itself enough to trigger the opposite resize and the map
## oscillates.
static func settle_bounds(current: Rect2, desired: Rect2, slack: float, shrink_ratio: float) -> Rect2:
	# No box yet (first fit): adopt the content outright rather than merging with
	# a meaningless zero-size rect at the origin.
	if current.size.x <= 0.0 or current.size.y <= 0.0:
		return _padded(desired, slack)
	if not current.encloses(desired):
		return _padded(current.merge(desired), slack)
	var too_wide: bool = current.size.x > desired.size.x * shrink_ratio
	var too_tall: bool = current.size.y > desired.size.y * shrink_ratio
	if too_wide or too_tall:
		return _padded(desired, slack)
	return current

static func _padded(box: Rect2, slack: float) -> Rect2:
	if slack <= 0.0:
		return box
	var pad: Vector2 = box.size * slack
	return box.grow_individual(pad.x, pad.y, pad.x, pad.y)

# --- edge contacts ------------------------------------------------------------

## True when `point` (map space) falls outside `rect`. Paired with
## [method clamp_to_map] to decide whether a marker is a real position or a
## direction-only contact on the rim.
static func is_outside(point: Vector2, rect: Rect2) -> bool:
	return point.x < rect.position.x or point.y < rect.position.y \
			or point.x > rect.end.x or point.y > rect.end.y

## `point` pulled onto `rect`, unchanged if it was already inside (WI-61).
##
## Crossing bodies spawn thousands of world-pixels outside the station and are
## deliberately kept out of the fitted box - including them would zoom the whole
## station down to a smudge for a comet's entire crossing. They are drawn on the
## map edge instead, in the direction they lie, which is the radar-contact idiom
## and keeps an approaching comet discoverable.
##
## Returned as a plain Vector2 with the inside/outside test as its own function,
## rather than as a {position, on_edge} dictionary: two typed statics beat one
## untyped dictionary access in a project that has unsafe_property_access on.
static func clamp_to_map(point: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y))
