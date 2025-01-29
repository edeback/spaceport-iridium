extends Node2D

@export var cell_size: Vector2i = Vector2i(64, 64)
@export var start_module: ModuleData
@onready var selector: Node2D = $Selector
@onready var world_manager: WorldManager = $Node

var preview_model : ModuleBase

var debug_path: PackedVector2Array
var selected_modules = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	world_manager.add_module(start_module, Vector2i(5,5))
	Global.current_module_changed.connect(current_module_changed)

func _unhandled_input(event: InputEvent) -> void:
	pass

func current_module_changed() -> void:
	if preview_model != null:
		selector.remove_child(preview_model)
		preview_model.queue_free()
	preview_model = Global.current_module.scene.instantiate()
	preview_model.previewing = true
	selector.add_child(preview_model)
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
func _process(delta: float) -> void:
	var hovered_cell = world_to_cell(get_global_mouse_position())
	if preview_model != null:
		preview_model.module_cell = hovered_cell
		preview_model.update_placeable()
	if preview_model != null and preview_model.can_place:
		var snapped_position = cell_size * hovered_cell
		selector.position = snapped_position
	else:
		selector.position = get_global_mouse_position()
	if Input.is_action_just_pressed("build"):
		if preview_model != null and preview_model.can_place:
			world_manager.add_module(Global.current_module, hovered_cell)
		else:
			select_module(hovered_cell)
	if Input.is_action_just_pressed("remove"):
		world_manager.remove_module_by_cell(hovered_cell)

func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floor((position.x) / cell_size.x), floor((position.y) / cell_size.y))
	
func select_module(cell: Vector2i) -> void:
	var selected_module = world_manager.cell_to_module.get(cell)
	if selected_module != null:
		selected_module.selected = !selected_module.selected
		if selected_module.selected:
			selected_modules[selected_module] = 1
		else:
			selected_modules.erase(selected_module)
		if selected_modules.size() == 2:
			run_pathfinding()
		else:
			debug_path = []
			queue_redraw()
	
func run_pathfinding() -> void:
	var modules = selected_modules.keys()
	debug_path = Global.world_manager.astar.get_point_path(modules[0].module_id, modules[1].module_id)
	queue_redraw()
	
func _draw() -> void:	 		
	var last_point = null
	for next_point in debug_path:
		if last_point == null:
			last_point = next_point
			continue
		draw_line(last_point * Vector2(cell_size) + Vector2(32, 32), next_point * Vector2(cell_size)+ Vector2(32, 32), Color.LAWN_GREEN, 2.5, true) 
		last_point = next_point
