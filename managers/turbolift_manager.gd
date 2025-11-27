class_name TurboliftManager
extends Node

@export var default_shaft:Line2D

var lift_graph:ModuleGraph = ModuleGraph.new()

var placing_turboshaft: bool = false
var start_lift: ModuleTurbolift = null

func _ready() -> void:
	Global.turbolift_manager = self
	SignalBus.module_removed.connect(_on_module_removed)
	default_shaft.reparent(Global.world_manager.layer_data[WorldManager.InteractionLayer.CORRIDOR].canvas)

func add_turboshaft(start: ModuleTurbolift, end: ModuleTurbolift) -> void:
	var existing_shaft = lift_graph.get_edge(start, end)
	if existing_shaft != null:
		print("Trying to add a turboshaft where there is one, skipping")
		return
	lift_graph.add_vertex(start)
	lift_graph.add_vertex(end)
	var newline: Line2D = default_shaft.duplicate()
	newline.visible = true
	newline.clear_points()
	newline.add_point(start.get_global_center())
	newline.add_point(end.get_global_center())
	#newline.reparent(Global.world_manager.layer_data[InteractionLayer.TRANSPORT].canvas)
	Global.world_manager.layer_data[WorldManager.InteractionLayer.CORRIDOR].canvas.add_child(newline)
	lift_graph.add_edge(start, end, 1, newline)
	SignalBus.module_connection_added.emit(start, end, start.module_cell.distance_to(end.module_cell) / 2)
	pass
	
func remove_turboshaft(start: ModuleTurbolift, end: ModuleTurbolift) -> void:
	var edge_data = lift_graph.get_edge(start, end)
	var shaft: Line2D = edge_data.data
	if shaft != null:
		shaft.queue_free()
	lift_graph.remove_edge(start, end)
	SignalBus.module_connection_removed.emit(start, end)
	pass
	
func remove_turbolift(lift: ModuleTurbolift) -> void:
	for edge in lift_graph._vertices[lift as ModuleBase].edges.keys():
		remove_turboshaft(lift, edge.module)
	lift_graph.remove_vertex(lift)
	pass
	
func update_turboshaft_placement(mouse_pos: Vector2) -> void:
	if placing_turboshaft:
		default_shaft.points[1] = mouse_pos
		if Input.is_action_just_pressed("build"):
			var cell = Global.world_to_cell(mouse_pos)
			var module = Global.world_manager.get_module_by_cell_active_layer(cell)
			if module is ModuleTurbolift:
				# Clicked on end turbolift, make a turboshaft, or cancel
				placing_turboshaft = false
				default_shaft.visible = false
				Global.ui_in_game.change_input_mode(UIInGame.InputMode.None)
				if module != start_lift:
					add_turboshaft(start_lift, module)
		if Input.is_action_just_pressed("remove"):
			# Cancel
			placing_turboshaft = false
			default_shaft.visible = false
			Global.ui_in_game.change_input_mode(UIInGame.InputMode.None)
	else:
		if Input.is_action_just_pressed("build"):
			var cell = Global.world_to_cell(mouse_pos)
			var module = Global.world_manager.get_module_by_cell_active_layer(cell)
			if module is ModuleTurbolift:
				# We clicked on a turbolift, start making a turboshaft
				placing_turboshaft = true
				default_shaft.points[0] = module.get_global_center()
				default_shaft.points[1] = mouse_pos
				default_shaft.visible = true
				start_lift = module

func _on_module_removed(module: ModuleBase) -> void:
	if module is ModuleTurbolift:
		remove_turbolift(module)
