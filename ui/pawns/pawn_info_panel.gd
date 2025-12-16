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
	

func _process(delta: float) -> void:
	set_position(pawn.get_global_transform_with_canvas().get_origin())

func _on_exit_button_pressed() -> void:
	queue_free()
