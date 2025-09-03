class_name ModuleTurbolift
extends ModuleBase

func _ready() -> void:
	add_to_group("turbolifts")
	super()

func on_select(new_selected: bool) -> void:
	super(new_selected)
	if new_selected:
		Global.ui_in_game.change_input_mode(UIInGame.InputMode.Turbolift)
	else:
		Global.ui_in_game.change_input_mode(UIInGame.InputMode.None)
	
