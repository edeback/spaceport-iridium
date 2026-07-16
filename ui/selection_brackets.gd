class_name SelectionBrackets
extends Node2D

## Corner-bracket selection overlay (WI-10), additive to the SELECTED shader
## tint. Lives on the UIInGame layer (which shares world coordinates - the
## debug-path overlay already draws there with raw cell coords), so brackets
## stay full-opacity even when the target's canvas layer is dimmed, and follow
## moving targets (pawns) across their canvas-layer reparents.

@export var color: Color = Color(1.0, 0.9, 0.2)
@export var thickness: float = 3.0
## Corner arm length as a fraction of the rect's shorter side.
@export var corner_fraction: float = 0.3
@export var padding: float = 4.0

var target: Node2D = null
## Bracket rect in the target's local space.
var target_rect: Rect2

func _ready() -> void:
	visible = false

func show_around(new_target: Node2D, rect: Rect2) -> void:
	target = new_target
	target_rect = rect.grow(padding)
	visible = true
	_follow()
	queue_redraw()

func clear() -> void:
	target = null
	visible = false

## Deselect only if we're still on this node - a newer selection may already
## have retargeted the brackets by the time a deferred close lands.
func clear_if_target(node: Node2D) -> void:
	if target == node:
		clear()

func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(target):
		clear()
		return
	_follow()

func _follow() -> void:
	# A node freed this frame can still be instance-valid while already out of
	# the tree; its "global" position would be garbage, so hold still instead.
	if not target.is_inside_tree():
		return
	var new_position: Vector2 = target.global_position
	if new_position != position:
		position = new_position
		queue_redraw()

func _draw() -> void:
	var arm: float = minf(target_rect.size.x, target_rect.size.y) * corner_fraction
	var top_left: Vector2 = target_rect.position
	var top_right: Vector2 = target_rect.position + Vector2(target_rect.size.x, 0)
	var bottom_left: Vector2 = target_rect.position + Vector2(0, target_rect.size.y)
	var bottom_right: Vector2 = target_rect.end
	draw_line(top_left, top_left + Vector2(arm, 0), color, thickness)
	draw_line(top_left, top_left + Vector2(0, arm), color, thickness)
	draw_line(top_right, top_right + Vector2(-arm, 0), color, thickness)
	draw_line(top_right, top_right + Vector2(0, arm), color, thickness)
	draw_line(bottom_left, bottom_left + Vector2(arm, 0), color, thickness)
	draw_line(bottom_left, bottom_left + Vector2(0, -arm), color, thickness)
	draw_line(bottom_right, bottom_right + Vector2(-arm, 0), color, thickness)
	draw_line(bottom_right, bottom_right + Vector2(0, -arm), color, thickness)
