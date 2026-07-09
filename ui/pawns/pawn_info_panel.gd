class_name PawnInfoPanel
extends MarginContainer

@export var data_tabs: TabContainer
var pawn: PawnBase


func set_pawn(_pawn: PawnBase) -> void:
	pawn = _pawn
	if pawn != null:
		%PawnNameLabel.text = pawn.pawn_name
		%AlertLabel.text = ""
		for child_node: Node in data_tabs.get_children():
			child_node.set_pawn(pawn)
	if pawn.movement_component:
		Global.ui_in_game.debug_path_position = pawn.movement_component.get_debug_path_detailed()
		pawn.movement_component.movement_started.connect(_movement_started)
	
func _process(delta: float) -> void:
	set_position(pawn.get_global_transform_with_canvas().get_origin())

func _movement_started() -> void:
	Global.ui_in_game.debug_path_position = pawn.movement_component.get_debug_path_detailed()

func _on_exit_button_pressed() -> void:
	pawn.movement_component.movement_started.disconnect(_movement_started)
	Global.ui_in_game.debug_path_position = []
	queue_free()
