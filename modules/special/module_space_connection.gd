@tool
class_name ModuleSpaceConnection
extends ModuleBase

func enter_module_from(pawn: PawnBase, _prev_module: ModuleBase = null) -> void:
	if _prev_module:
		pawn.current_module = null
	else:
		pawn.current_module = self
