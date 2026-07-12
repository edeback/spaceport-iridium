extends Node

@export var structure_tile_map: TileMapLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.tilemap = structure_tile_map
	get_viewport().set_physics_object_picking_sort(true)
	#get_viewport().set_physics_object_picking_first_only(true)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.power_manager != null:
		Global.power_manager.power_modules(delta)
	pass
