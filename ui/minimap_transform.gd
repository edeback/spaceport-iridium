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
