class_name UIInGame
extends Control

@onready var selector: Node2D = $Selector
@onready var preview_module: PreviewModule = $Selector/PreviewModule

var debug_path_cell: PackedVector2Array:
	set(new_path):
		debug_path_cell = new_path
		queue_redraw()
		
var debug_path_position: PackedVector2Array:
	set(new_path):
		debug_path_position = new_path
		queue_redraw()
		
enum InputMode {None, Module, Structure, Turbolift, Multiplace}

signal input_mode_changed(new_mode: InputMode)

var cur_input_mode: InputMode = InputMode.None
var cur_module: ModuleData = null

var multiplace_start: Vector2i
var preview_multimodules: Array[PreviewModule] = []

var last_hovered_cell: Vector2i

## Selection brackets (WI-10): module and pawn selection each get their own
## instance - both info panels can be open at once.
var module_brackets: SelectionBrackets
var pawn_brackets: SelectionBrackets

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.ui_in_game = self
	module_brackets = SelectionBrackets.new()
	add_child(module_brackets)
	pawn_brackets = SelectionBrackets.new()
	pawn_brackets.padding = 0
	add_child(pawn_brackets)
	SignalBus.module_selected.connect(_on_module_selected)

## ModuleBase.selected emits on every change, select and deselect alike.
func _on_module_selected(module: ModuleBase) -> void:
	if module.selected:
		module_brackets.show_around(module, Rect2(Vector2.ZERO, Vector2(module.size * Global.CELL_SIZE)))
	else:
		module_brackets.clear_if_target(module)

func change_input_mode(mode: InputMode, module: ModuleData = null) -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	cur_input_mode = mode
	cur_module = module
	preview_module.module_data = module
	input_mode_changed.emit(mode)
	if module:
		preview_module.visible = true
	else:
		preview_module.visible = false
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var hovered_cell: Vector2i = Global.world_to_cell(get_global_mouse_position())
		if event.is_action_pressed("build"):
			if cur_module != null and preview_module != null and preview_module.can_place:
				if cur_module.multiplacement != WorldManager.Multiplacement.NONE:
					preview_module.visible = false
					cur_input_mode = InputMode.Multiplace
					multiplace_start = hovered_cell
				else:
					Global.world_manager.purchase_and_add_module(cur_module, preview_module.last_cell, preview_module.flipped)
					update_module_placement(true)
				get_viewport().set_input_as_handled()
		if event.is_action_pressed("remove"):
				if cur_input_mode != InputMode.None:
					change_input_mode(InputMode.None)
					get_viewport().set_input_as_handled()
	if event is InputEventKey:
		if event.is_action_pressed("flip_module"):
			preview_module.flipped = not preview_module.flipped
			# The flipped variant has its own structure points - revalidate now
			# rather than waiting for the mouse to move to a new cell.
			update_module_placement(true)
		if event.is_action_pressed("show_details"):
			get_tree().call_group("module", "show_label")
		if event.is_action_released("show_details"):
			get_tree().call_group("module", "hide_label")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
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
	if last_hovered_cell == hovered_cell and preview_multimodules.size() > 0:
		return
	last_hovered_cell = hovered_cell
	var xrange: int = hovered_cell.x - multiplace_start.x
	var yrange: int = hovered_cell.y - multiplace_start.y
	var xdirection: int = 1 if xrange > 0 else -1
	var ydirection: int = 1 if yrange > 0 else -1
	xrange = abs(xrange)
	yrange = abs(yrange)
	if preview_module.module_data.multiplacement == WorldManager.Multiplacement.HORIZONTAL:
		yrange = 0
	elif preview_module.module_data.multiplacement == WorldManager.Multiplacement.VERTICAL:
		xrange = 0
	while preview_multimodules.size() < (xrange + 1) * (yrange + 1):
		preview_multimodules.append(preview_module.duplicate())
		add_child(preview_multimodules.back())
	for i: int in range(preview_multimodules.size(), (xrange + 1) * (yrange + 1), -1):
		var previewmod: PreviewModule = preview_multimodules.pop_back()
		if previewmod != null:
			remove_child(previewmod)
			previewmod.queue_free()
	for x: int in range(xrange + 1):
		for y: int in range(yrange + 1):
			var cell: Vector2i = Vector2i(multiplace_start.x + x * xdirection, multiplace_start.y + y * ydirection)
			var previewmod: PreviewModule = preview_multimodules.get(y * (xrange + 1) + x)
			previewmod.visible = true
			var snapped_position: Vector2 = Global.cell_to_world(cell) + preview_module.offset
			previewmod.position = snapped_position
			previewmod.module_data = preview_module.module_data
			previewmod.update_placeable(cell, preview_module.module_data.ignore_multiplacement_connection_check)

			
func finalize_multiplacement() -> void:
	for mod: PreviewModule in preview_multimodules:
		if mod:
			if mod.can_place:
				Global.world_manager.purchase_and_add_module(cur_module, mod.last_cell)
			mod.queue_free()
	preview_multimodules.clear()
	cur_input_mode = InputMode.Module
	update_module_placement(true)
	preview_module.visible = true

func update_module_placement(force: bool = false) -> void:
	if preview_module != null:
		var hovered_cell: Vector2i = Global.world_to_cell(get_global_mouse_position() - preview_module.offset + Vector2(Global.CELL_SIZE) / 2)
		if hovered_cell != last_hovered_cell or force:
			preview_module.update_placeable(hovered_cell)
		# Always grid-snap, even when invalid: the per-cell blocked overlay is
		# only meaningful if the preview sits on the cells being judged.
		selector.position = Global.cell_to_world(hovered_cell) + preview_module.offset
		last_hovered_cell = hovered_cell

func update_structure_placement() -> void:
	pass

func _draw() -> void:	 		
	var last_point: Variant = null
	for next_point in debug_path_cell:
		if last_point == null:
			last_point = next_point
			continue
		draw_line(last_point * Vector2(Global.CELL_SIZE) + Vector2(32, 32), next_point * Vector2(Global.CELL_SIZE)+ Vector2(32, 32), Color.LAWN_GREEN, 2.5, true) 
		last_point = next_point
	last_point = null
	for next_point in debug_path_position:
		if last_point == null:
			last_point = next_point
			continue
		draw_line(last_point, next_point, Color.AQUA, 1, true) 
		last_point = next_point
