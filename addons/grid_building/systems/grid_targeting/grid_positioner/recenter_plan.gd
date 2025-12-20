## Typed result for recentering plan.
class_name RecenterPlan
extends RefCounted

var target_source: String
var target_world: Vector2

func _init(p_target_source: String = "", p_target_world: Vector2 = Vector2.ZERO) -> void:
	target_source = p_target_source
	target_world = p_target_world