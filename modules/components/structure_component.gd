@tool
class_name StructureComponent
extends ComponentBase

@export var show_debug: bool = false:
	set(new_show):
		show_debug = new_show
		queue_redraw()

@export var connection_points: Array[Vector2i]:
	set(new_points):
		connection_points = new_points
		queue_redraw()
		
var module_connections: Dictionary[ModuleBase, int] = {}

@export var size: Vector2i = Vector2i(2, 2)

func _ready() -> void:
	super()
	size = owner_module.size
	
## Do we maybe have any connection?
func _has_possible_connections() -> bool:
	for point in connection_points:
		if Global.world_manager.has_overlaps(owner_module.module_data.interaction_layer, owner_module.module_cell + point):
			return true
	return false
		
## Find the index of a connection between this and another module. -1 if not found
func _find_connection(other_module: ModuleBase) -> int:
	for index: int in connection_points.size():
		var module: ModuleBase = Global.world_manager.get_module_by_cell(owner_module.module_data.interaction_layer, owner_module.module_cell + connection_points[index])
		if module != null and module == other_module:
			return index
	return -1

## Returns a mapping of connected modules -> their connection point
func _find_connections() -> Dictionary[ModuleBase, int]:
	var connected_modules: Dictionary[ModuleBase, int] = {}
	for index: int in connection_points.size():
		var module: ModuleBase = Global.world_manager.get_module_by_cell(owner_module.module_data.interaction_layer, owner_module.module_cell + connection_points[index])
		if module != null and module != self:
			connected_modules[module] = index
	return connected_modules
	
## Connect to the other module if we can, return if successful
func try_connect(other_module: ModuleBase) -> bool:
	var connected_index: int = _find_connection(other_module)
	if connected_index != -1:
		module_connections[other_module] = connected_index
		return true
	return false

func make_connections() -> void:
	var connected_modules: Dictionary[ModuleBase, int] = _find_connections()
	for module in connected_modules:
		if module.get_structure_component().try_connect(owner_module):
			module_connections[module] = connected_modules[module]
			SignalBus.module_structure_connection_added.emit(owner_module, module, owner_module.module_cell.distance_to(module.module_cell))
	
func manual_connection(other_module: ModuleBase, connection_index: int) -> void:
	module_connections[other_module] = connection_index
			
func remove_connections() -> void:
	for module in module_connections:
		module.get_structure_component().disconnect_from(owner_module)
		SignalBus.module_structure_connection_removed.emit(owner_module.module_id, module.module_id)
	module_connections.clear()
	
func disconnect_from(other_module: ModuleBase) -> void:
	module_connections.erase(other_module)


func _draw() -> void:
	if show_debug && Engine.is_editor_hint():
		for index in connection_points.size():
			var point: Vector2i = connection_points[index]
			var center: Vector2 = Vector2(point * Vector2i(64, 64)) +  Vector2(32, 32)
			draw_circle(center, 12, Color.GREEN)
			draw_string(ThemeDB.fallback_font, center + Vector2(-4, 5), str(index), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.BLACK)
