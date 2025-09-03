class_name UIInGame
extends Control

@onready var selector: Node2D = $Selector
@onready var preview_module: PreviewModule = $Selector/PreviewModule
@onready var structure_tile_map: TileMapLayer = $"../StructureTileMap"

var debug_path: PackedVector2Array:
	set(new_path):
		debug_path = new_path
		queue_redraw()
		
enum InputMode {None, Module, Structure, Turbolift}

var cur_input_mode: InputMode = InputMode.None
var cur_module: ModuleData = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.ui_in_game = self
	pass # Replace with function body.

func change_input_mode(mode: InputMode, module: ModuleData = null) -> void:
	cur_input_mode = mode
	cur_module = module
	preview_module.module_data = module
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match cur_input_mode:
		InputMode.None:
			update_module_placement()
		InputMode.Module:
			update_module_placement()
		InputMode.Structure:
			update_structure_placement()
		InputMode.Turbolift:
			Global.turbolift_manager.update_turboshaft_placement(get_global_mouse_position())

func update_module_placement() -> void:
	var hovered_cell = Global.world_to_cell(get_global_mouse_position())
	if preview_module != null:
		preview_module.update_placeable(hovered_cell)
	if preview_module != null and preview_module.can_place:
		var snapped_position = Global.CELL_SIZE * hovered_cell
		selector.position = snapped_position
	else:
		selector.position = get_global_mouse_position()
	if Input.is_action_just_pressed("build"):
		if preview_module != null and preview_module.can_place:
			Global.world_manager.add_module(cur_module, hovered_cell)
		else:
			select_module(hovered_cell)
	if Input.is_action_just_pressed("remove"):
		Global.world_manager.remove_module_by_cell_active_layer(hovered_cell)

func update_structure_placement() -> void:
	pass



func select_module(cell: Vector2i) -> void:
	var selected_module = Global.world_manager.get_module_by_cell_active_layer(cell)
	if selected_module != null:
		selected_module.on_select(!selected_module.selected)

func _draw() -> void:	 		
	var last_point = null
	for next_point in debug_path:
		if last_point == null:
			last_point = next_point
			continue
		draw_line(last_point * Vector2(Global.CELL_SIZE) + Vector2(32, 32), next_point * Vector2(Global.CELL_SIZE)+ Vector2(32, 32), Color.LAWN_GREEN, 2.5, true) 
		last_point = next_point
