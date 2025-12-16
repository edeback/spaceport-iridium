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
