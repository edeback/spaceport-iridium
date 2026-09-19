extends Control

## Developer readout: the mouse's world position, cell and tilemap cell, top
## right. A release export frees it (WI-68 F5): it sat under the station map at
## 94% opacity, so the numbers bled through faintly - and in full whenever the map
## was collapsed - while ticking every frame for nobody.

@onready var mouse_position: Label = $VBoxContainer/HBoxContainer/MousePosition
@onready var hovered_cell: Label = $VBoxContainer/HBoxContainer2/HoveredCell
@onready var tilemap_cell: Label = $VBoxContainer/HBoxContainer3/TilemapCell

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Global.tilemap:
		var local_mouse_pos: Vector2 = Global.tilemap.get_local_mouse_position()
		var cell: Vector2i = Global.world_to_cell(local_mouse_pos)
		var t_cell: Vector2i = Global.world_to_tilemap_cell(local_mouse_pos)
		mouse_position.text = str(local_mouse_pos)
		hovered_cell.text = str(cell)
		tilemap_cell.text = str(t_cell)
