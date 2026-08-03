class_name PawnComponentBase
extends Node2D

@export var ui_info_panel_element: PackedScene

var owner_pawn: PawnBase

signal new_error(component: ComponentBase, error_message: String)

var last_error: String = "":
	get:
		return last_error
	set(new_value):
		if last_error != new_value:
			last_error = new_value
			new_error.emit(self, new_value)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if owner is PawnBase:
		owner_pawn = owner as PawnBase
		owner_pawn.components.append(self)


func has_ui() -> bool:
	return false

func get_ui() -> ModuleComponentUI:
	return null

# --- persistence (WI-47 M2) -----------------------------------------------------
#
# The pawn-side twin of ComponentBase's hooks, and it existed for the same reason:
# SaveManager._load_pawns named needs / health / skills / traits / disease /
# breathing / robot_power / robot_integrity one at a time, so a modded pawn
# component could not persist at all. See component_base.gd for the full rationale.
#
# No saves_per_instance() here: nothing carries two of one pawn component, and an
# unused knob is worse than a missing one. Add it if that ever stops being true.

## Restores after everything the base game does, so a mod component sees a pawn
## that is already whole.
const DEFAULT_SAVE_ORDER: int = 1000

## Position in the restore chain - LOWER RUNS FIRST. Load-bearing; see the vanilla
## overrides. Ties break on registration order.
func save_order() -> int:
	return DEFAULT_SAVE_ORDER

## The key this component's block lands under in the pawn's save entry. Vanilla
## components pin theirs to the string they have always used. The default is the
## node path within the pawn - see ComponentBase.save_key() for the mod-author
## rule that comes with it.
func save_key() -> StringName:
	if owner_pawn == null:
		return StringName(name)
	return StringName(String(owner_pawn.get_path_to(self)))

## This component's state, or {} for "nothing to save". Empty blocks are never
## written, which is how a healthy crew member stays lean in the file.
func get_save_data() -> Dictionary:
	return {}

func load_save_data(_data: Dictionary) -> void:
	pass
