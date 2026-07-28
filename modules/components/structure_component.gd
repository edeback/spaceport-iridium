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
		
@export var internal_points: Array[Vector2i] = []:
	set(new_points):
		internal_points = new_points
		queue_redraw()
		
@export var must_be_clear_points: Array[Vector2i] = []:
	set(new_points):
		must_be_clear_points = new_points
		queue_redraw()
		
## Module // Is Door
var module_connections: Dictionary[ModuleBase, bool] = {}

## Guard so the structural attachment pass runs exactly once per placement. A
## module readies twice on the normal build path - ready_blueprint forms the
## structure so the connectivity graph is honest while it's a construction site,
## and ready_constructed re-calls make_connections for the built path. Without
## this, that second pass would re-emit every edge (harmless but wasteful signal
## spam through StructureManager + AdjacencyManager). Cleared on teardown.
var _connections_made: bool = false

@export var size: Vector2i = Vector2i(2, 2)

signal module_connections_changed(new_connections: Dictionary[ModuleBase, bool])

func _ready() -> void:
	super()
	size = owner_module.size
	
	
func can_connect_to(world_cell: Vector2i) -> bool:
	var local_cell: Vector2i = world_cell - owner_module.module_cell
	return connection_points.has(local_cell) or internal_points.has(local_cell)
	
## Do we maybe have any connection?
func _has_possible_connections() -> bool:
	# Connections on this level
	for point in connection_points:
		if Global.world_manager.has_overlaps(owner_module.module_data.interaction_layer, owner_module.module_cell + point):
			return true
	# Connections cross-level
	if Global.world_manager.has_overlaps(owner_module.module_data.connection_layer, owner_module.module_cell, owner_module.size):
		return true
	return false
		
func _has_direct_connection(module: ModuleBase) -> bool:
	for index: int in connection_points.size():
		var test_module: ModuleBase = Global.world_manager.get_module_by_cell(owner_module.module_data.connection_layer, owner_module.module_cell + connection_points[index])
		if test_module == module:
			return true
	return false

func _has_cross_connection(module: ModuleBase) -> bool:
	if module.module_data.interaction_layer != module.module_data.connection_layer:
		for index: int in internal_points.size():
			var test_module: ModuleBase = Global.world_manager.get_module_by_cell(module.module_data.interaction_layer, owner_module.module_cell + internal_points[index])
			if test_module == module:
				return true
	return false

## Modules connected to this on this or other layer
func _find_connections() -> Dictionary[ModuleBase, bool]:
	var connected_modules: Dictionary[ModuleBase, bool] = {}
	for test_point: Vector2i in connection_points:
		var test_module: ModuleBase = Global.world_manager.get_module_by_cell(owner_module.module_data.connection_layer, owner_module.module_cell + test_point)
		if test_module != null and test_module != owner_module:
			connected_modules[test_module] = false
	## Check all other layers for new cross-connections
	for layer: WorldManager.StructureLayer in WorldManager.StructureLayer.values():
		if layer != owner_module.module_data.interaction_layer:
			for test_point: Vector2i in internal_points:
				var test_module: ModuleBase = Global.world_manager.get_module_by_cell(layer, owner_module.module_cell + test_point)
				if test_module != null and test_module != owner_module:
					connected_modules[test_module] = true
	return connected_modules
	
## Connect to the other module if we can, return if successful
func try_connect(other_module: ModuleBase) -> bool:
	if _has_direct_connection(other_module):
		module_connections[other_module] = false
		module_connections_changed.emit(module_connections)
		return true
	elif _has_cross_connection(other_module):
		module_connections[other_module] = true
		module_connections_changed.emit(module_connections)
		return true
	return false

func make_connections() -> void:
	if _connections_made:
		return
	_connections_made = true
	var connected_modules: Dictionary[ModuleBase, bool] = _find_connections()
	for module in connected_modules:
		if module.get_structure_component().try_connect(owner_module):
			module_connections[module] = connected_modules[module]
			SignalBus.module_structure_connection_added.emit(owner_module, module, owner_module.global_position.distance_to(module.global_position))
	module_connections_changed.emit(module_connections)
	
func manual_connection(other_module: ModuleBase, connection_index: int) -> void:
	module_connections[other_module] = connection_index
	module_connections_changed.emit(module_connections)
			
func remove_connections() -> void:
	_connections_made = false
	for module in module_connections:
		module.get_structure_component().disconnect_from(owner_module)
		SignalBus.module_structure_connection_removed.emit(owner_module, module)
	module_connections.clear()
	module_connections_changed.emit(module_connections)
	
func disconnect_from(other_module: ModuleBase) -> void:
	module_connections.erase(other_module)
	module_connections_changed.emit(module_connections)


func _draw() -> void:
	if show_debug && Engine.is_editor_hint():
		for index in connection_points.size():
			var point: Vector2i = connection_points[index]
			var center: Vector2 = Vector2(point * Vector2i(64, 64)) +  Vector2(32, 32)
			draw_circle(center, 12, Color.GREEN)
			draw_string(ThemeDB.fallback_font, center + Vector2(-4, 5), str(index), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.BLACK)
		
		for index in internal_points.size():
			var point: Vector2i = internal_points[index]
			var center: Vector2 = Vector2(point * Vector2i(64, 64)) +  Vector2(32, 32)
			draw_circle(center, 12, Color.LIGHT_SKY_BLUE)
			draw_string(ThemeDB.fallback_font, center + Vector2(-4, 5), str(index), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.BLACK)
		
		for index in must_be_clear_points.size():
			var point: Vector2i = must_be_clear_points[index]
			var center: Vector2 = Vector2(point * Vector2i(64, 64)) +  Vector2(32, 32)
			draw_circle(center, 12, Color.ORANGE_RED)
			draw_string(ThemeDB.fallback_font, center + Vector2(-4, 5), str(index), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.BLACK)
