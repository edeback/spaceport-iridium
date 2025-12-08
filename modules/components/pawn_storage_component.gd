class_name PawnStorageComponent
extends ComponentBase

@export var pawn_scene: PackedScene
@export var capacity: int = 1

var associated_pawns: Array[PawnBase] = []

func _ready() -> void:
	super()
	for i in range(capacity):
		var new_pawn: PawnBase = pawn_scene.instantiate() as PawnBase
		new_pawn.current_module = owner_module
		new_pawn.global_position = Global.cell_to_world(owner_module.module_cell, true)
		associated_pawns.append(new_pawn)
		Global.world_manager.pawn_layer.add_child(new_pawn)

func _exit_tree() -> void:
	for pawn: PawnBase in associated_pawns:
		Global.world_manager.pawn_layer.remove_child(pawn)
		
