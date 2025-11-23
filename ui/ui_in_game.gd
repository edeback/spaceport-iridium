class_name UIInGame
extends Control

@onready var selector: Node2D = $Selector
@onready var preview_module: PreviewModule = $Selector/PreviewModule
@onready var structure_tile_map: TileMapLayer = $"../StructureTileMap"

@export var module_info_panel: PackedScene
var cur_module_info_panel: ModuleInfoIngamePanel

var debug_path: PackedVector2Array:
	set(new_path):
		debug_path = new_path
		queue_redraw()
		
enum InputMode {None, Module, Structure, Turbolift, Multiplace}

signal input_mode_changed(new_mode: InputMode)

var cur_input_mode: InputMode = InputMode.None
var cur_module: ModuleData = null

var multiplace_start: Vector2i
var preview_multimodules: Array[PreviewModule] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.ui_in_game = self
	pass # Replace with function body.

func change_input_mode(mode: InputMode, module: ModuleData = null) -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	cur_input_mode = mode
	cur_module = module
	preview_module.module_data = module
	input_mode_changed.emit(mode)
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var hovered_cell = Global.world_to_cell(get_global_mouse_position())
		if event.is_action_pressed("build"):
			if cur_module != null and preview_module != null and preview_module.can_place:
				if cur_module.multiplacement:
					preview_module.visible = false
					cur_input_mode = InputMode.Multiplace
					multiplace_start = hovered_cell
				else:
					Global.world_manager.add_module(cur_module, preview_module.last_cell)
			else:
				select_module(hovered_cell)
		if event.is_action_pressed("remove"):
			Global.world_manager.remove_module_by_cell_active_layer(hovered_cell)
	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match cur_input_mode:
		InputMode.None:
			pass
		InputMode.Module:
			update_module_placement()
		InputMode.Structure:
			update_structure_placement()
		InputMode.Turbolift:
			Global.turbolift_manager.update_turboshaft_placement(get_global_mouse_position())
		InputMode.Multiplace:
			update_multiplacement()
			if Input.is_action_just_released("build"):
				finalize_multiplacement()
				
			
func update_multiplacement() -> void:
	var hovered_cell: Vector2i = Global.world_to_cell(get_global_mouse_position() - preview_module.offset + Vector2(Global.CELL_SIZE) / 2)
	var xrange: int = hovered_cell.x - multiplace_start.x
	var yrange: int = hovered_cell.y - multiplace_start.y
	var xdirection: int = 1 if xrange > 0 else -1
	var ydirection: int = 1 if yrange > 0 else -1
	if abs(yrange) > abs(xrange):
		xrange = 0
		yrange = abs(yrange)
	else:
		xrange = abs(xrange)
		yrange = 0
	for x: int in range(xrange + 1):
		for y: int in range(yrange + 1):
			var cell: Vector2i = Vector2i(multiplace_start.x + x * xdirection, multiplace_start.y + y * ydirection)
			if preview_multimodules.size() < x + y + 1:
				preview_multimodules.append(preview_module.duplicate())
				add_child(preview_multimodules.back())
			var previewmod: PreviewModule = preview_multimodules.get(x + y)
			previewmod.visible = true
			previewmod.is_horizontal = yrange == 0
			var snapped_position: Vector2 = Global.cell_to_world(cell) + preview_module.offset
			previewmod.position = snapped_position
			previewmod.module_data = preview_module.module_data
			previewmod.update_placeable(cell, true)
	for i: int in range(preview_multimodules.size(), xrange + yrange + 1, -1):
		var previewmod = preview_multimodules.pop_back()
		if previewmod != null:
			previewmod.queue_free()
			
func finalize_multiplacement() -> void:
	for mod: PreviewModule in preview_multimodules:
		if mod and mod.can_place:
			Global.world_manager.add_module(cur_module, mod.last_cell, mod.is_horizontal)
			mod.queue_free()
	preview_multimodules.clear()
	cur_input_mode = InputMode.Module
	preview_module.visible = true

func update_module_placement() -> void:
	if preview_module != null:
		var hovered_cell: Vector2i = Global.world_to_cell(get_global_mouse_position() - preview_module.offset + Vector2(Global.CELL_SIZE) / 2)
		preview_module.update_placeable(hovered_cell)
		if preview_module.can_place:
			var snapped_position: Vector2 = Global.cell_to_world(hovered_cell) + preview_module.offset
			selector.position = snapped_position
		else:
			selector.position = get_global_mouse_position()

func update_structure_placement() -> void:
	pass

func select_module(cell: Vector2i) -> void:
	var selected_module: ModuleBase = Global.world_manager.get_module_by_cell_active_layer(cell)
	if selected_module != null:
		# Temp comment out this so we just see info panels
		#selected_module.on_select(!selected_module.selected)
		if cur_module_info_panel != null:
			var last_module: ModuleBase = cur_module_info_panel.module_viewed
			cur_module_info_panel.queue_free()
			cur_module_info_panel = null
			if last_module == selected_module:
				# Just toggle off the panel if we're clicking the same module
				return
		var new_info_panel: ModuleInfoIngamePanel = module_info_panel.instantiate() as ModuleInfoIngamePanel
		new_info_panel.set_module(selected_module)
		add_child(new_info_panel)
		new_info_panel.set_position(Global.cell_to_world(cell))
		cur_module_info_panel = new_info_panel

func _draw() -> void:	 		
	var last_point = null
	for next_point in debug_path:
		if last_point == null:
			last_point = next_point
			continue
		draw_line(last_point * Vector2(Global.CELL_SIZE) + Vector2(32, 32), next_point * Vector2(Global.CELL_SIZE)+ Vector2(32, 32), Color.LAWN_GREEN, 2.5, true) 
		last_point = next_point
