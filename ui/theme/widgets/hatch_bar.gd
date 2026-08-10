@tool
class_name HatchBar
extends Control

## The design's gauge fill: a track with a 1px EDGE border and a striped fill
## (the mockup's `repeating-linear-gradient`). Used by [StatBar] and by anything
## else that needs a proportion drawn rather than a number.
##
## Drawn rather than built from nodes because a stripe pattern is four lines of
## `_draw()` and would otherwise be a texture asset that has to be re-authored
## every time the palette moves.
##
## Pure view: it holds a fraction and a colour and nothing else. Callers decide
## what the fraction means and which colour a failing value gets - that rule
## belongs to the caller, not to a bar.

## Stripe period and the width of the lighter stripe within it, in pixels.
const STRIPE_PERIOD: float = 7.0
const STRIPE_LIGHT: float = 5.0

## How much darker the second stripe is than the fill colour.
const STRIPE_DARKEN: float = 0.22

## 0..1. Clamped - a caller computing a ratio cannot make the bar overrun.
@export_range(0.0, 1.0) var fraction: float = 0.0:
	set(value):
		fraction = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var fill_color: Color = UIPalette.LIVE:
	set(value):
		fill_color = value
		queue_redraw()

## Bar height. The design's gauges are 8px; a chunkier bar is legal but should
## be a deliberate choice, not a per-panel accident.
@export var bar_height: int = 8:
	set(value):
		bar_height = maxi(1, value)
		custom_minimum_size.y = float(bar_height)
		queue_redraw()

func _ready() -> void:
	custom_minimum_size.y = float(bar_height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(size.x, float(bar_height)))
	draw_rect(rect, UIPalette.GAUGE_TRACK)
	var fill_width: float = maxf(0.0, (rect.size.x - 2.0) * fraction)
	if fill_width > 0.0:
		var inner := Rect2(Vector2(1.0, 1.0), Vector2(fill_width, rect.size.y - 2.0))
		draw_rect(inner, fill_color)
		# The darker half of each stripe, painted over the flat fill. Clipped to
		# the fill so a partly-full bar's last stripe does not spill past it.
		var dark: Color = fill_color.darkened(STRIPE_DARKEN)
		var x: float = STRIPE_LIGHT
		while x < fill_width:
			var stripe_width: float = minf(STRIPE_PERIOD - STRIPE_LIGHT, fill_width - x)
			draw_rect(Rect2(Vector2(1.0 + x, 1.0), Vector2(stripe_width, inner.size.y)), dark)
			x += STRIPE_PERIOD
	draw_rect(rect, UIPalette.EDGE, false, 1.0)
