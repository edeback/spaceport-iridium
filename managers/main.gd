extends Node

@onready var structure_tile_map: TileMapLayer = $StructureTileMap

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.tilemap = structure_tile_map
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.power_manager != null:
		Global.power_manager.power_modules(delta)
	pass
