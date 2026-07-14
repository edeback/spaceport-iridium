class_name PawnStorageComponent
extends ComponentBase

@export var pawn_scene: PackedScene
@export var capacity: int = 1

var associated_pawns: Array[PawnBase] = []

func _ready() -> void:
	super()

func _exit_tree() -> void:
	# Despawn the pawns this component spawned. They may have been reparented
	# anywhere in the tree (layer canvases, cabs), so queue_free rather than
	# detaching from a parent we no longer are.
	for pawn: PawnBase in associated_pawns:
		if is_instance_valid(pawn):
			pawn.queue_free()
	associated_pawns.clear()
		
func ready_preview() -> void:
	pass
	
func ready_blueprint() -> void:
	pass
	
func ready_constructed() -> void:
	if SaveManager.is_loading():
		return # loaded games restore their pawns from the save's pawn section
	for i in range(capacity):
		var new_pawn: PawnBase = pawn_scene.instantiate() as PawnBase
		new_pawn.current_module = owner_module
		new_pawn.global_position = Global.cell_to_world(owner_module.module_cell, true)
		associated_pawns.append(new_pawn)
		Global.world_manager.pawn_layer.add_child(new_pawn)
