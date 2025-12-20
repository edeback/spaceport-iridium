## Holds the last mouse input gate/projection snapshot for grid-based input systems
## Provides typed properties and a convenience serializer to Dictionary
class_name GBMouseInputStatus
extends RefCounted

var allowed: bool = false
var world: Vector2 = Vector2.ZERO
var method: int = 0
var method_name: String = ""
var screen: Vector2 = Vector2.ZERO

func _init():
    # defaults set above
    pass

func set_from_values(p_allowed: bool, p_world: Vector2, p_method: int, p_method_name: String, p_screen: Vector2) -> void:
    allowed = p_allowed
    world = p_world
    method = p_method
    method_name = p_method_name
    screen = p_screen

func to_dict() -> Dictionary:
    return {
        "allowed": allowed,
        "world": world,
        "method": method,
        "method_name": method_name,
        "screen": screen,
    }
