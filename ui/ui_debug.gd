extends Control

@onready var mouse_position: Label = $VBoxContainer/HBoxContainer/MousePosition
@onready var hovered_cell: Label = $VBoxContainer/HBoxContainer2/HoveredCell
@onready var tilemap_cell: Label = $VBoxContainer/HBoxContainer3/TilemapCell

#var debug_path: PackedVector2Array:
	#set(new_path):
		#debug_path = new_path
		#queue_redraw()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var local_mouse_pos = Global.tilemap.get_local_mouse_position()
	var cell = Global.world_to_cell(local_mouse_pos)
	var t_cell = Global.world_to_tilemap_cell(local_mouse_pos)
	mouse_position.text = str(local_mouse_pos)
	hovered_cell.text = str(cell)
	tilemap_cell.text = str(t_cell)

#func _draw() -> void:	 		
	#var last_point = null
	#for next_point in debug_path:
		#if last_point == null:
			#last_point = next_point
			#continue
		#draw_line(last_point * Vector2(Global.CELL_SIZE) + Vector2(32, 32), next_point * Vector2(Global.CELL_SIZE)+ Vector2(32, 32), Color.LAWN_GREEN, 2.5, true) 
		#last_point = next_point
