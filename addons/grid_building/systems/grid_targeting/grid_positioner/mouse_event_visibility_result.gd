## Result for event-driven visibility decisions (mouse events).
class_name MouseEventVisibilityResult
extends RefCounted

var apply: bool = false
var visible: bool = false
var reason: String = ""

func _init(p_apply: bool = false, p_visible: bool = false, p_reason: String = "") -> void:
    apply = p_apply
    visible = p_visible
    reason = p_reason

## Returns a string representation for debugging and test diagnostics
func to_string() -> String:
    return "MouseEventVisibilityResult(apply=%s, visible=%s, reason='%s')" % [str(apply), str(visible), reason]
