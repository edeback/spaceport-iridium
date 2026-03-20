@tool
class_name ModuleBase
extends ObjectBase

@export var sprite: Sprite2D
@onready var footprint: Area2D = $Offset/Footprint
@onready var nameplate: Label = $Offset/Sprite/Nameplate
@export var replacement_on_delete: ModuleData

@export var size: Vector2i = Vector2i(1, 1)
@export var show_debug: bool = true:
	set(new_show_debug):
		show_debug = new_show_debug
		queue_redraw()
		
@export var blocks_building: bool = true
@export var can_delete: bool = true
@export var structure_check_before_delete: bool = true

@export var offset: Node2D

var module_id: int = -1
var module_cell: Vector2i
var module_data: ModuleData
var is_horizontal: bool = true

var module_connections: Dictionary[ModuleBase, bool] = {}

var jobs = {}

var _cached_path_component: PathComponent = null
var _cached_structure_component: StructureComponent = null


const SHADER_PARAM_PREVIEW = "PREVIEW"
const SHADER_PARAM_PLACEABLE = "PLACEABLE"
const SHADER_PARAM_SELECTED = "SELECTED"
const SHADER_PARAM_PROGRESS = "PROGRESS"

var previewing: bool = false:
	get:
		return previewing
	set(new_value):
		previewing = new_value
		_update_shader()

var can_place: bool = true:
	get:
		return can_place
	set(new_value):
		if can_place != new_value:
			can_place = new_value
			_update_shader()
			
var selected: bool = false:
	get:
		return selected
	set(new_value):
		if selected != new_value:
			selected = new_value
			_update_shader()
			SignalBus.module_selected.emit(self)
			
var progress: float = 1.0:
	set(new_value):
		new_value = clamp(new_value, 0.0, 1.0)
		if new_value != progress:
			progress = new_value
			_update_shader()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(module_id)
	if (sprite && sprite.material != null):
		sprite.material = sprite.material.duplicate()
	_update_shader()
	if module_data != null:
		nameplate.text = module_data.name
	elif nameplate != null:
		nameplate.text = ""
	add_to_group("module")
	if SignalBus.is_node_ready():
		SignalBus.module_added.emit(self)
	on_place()
	
func ready_preview() -> void:
	for component: ComponentBase in components:
		component.ready_preview()

func ready_blueprint() -> void:
	for component: ComponentBase in components:
		component.ready_blueprint()
	
func ready_constructed() -> void:
	for component: ComponentBase in components:
		component.ready_constructed()
	make_connections()

func on_place() -> void:
	if get_structure_component() != null and module_data.interaction_layer == WorldManager.StructureLayer.MODULE:
		var cells: Array[Vector2i] = []
		for internal_point: Vector2i in get_structure_component().internal_points:
			cells.append(module_cell + internal_point)
		Global.tilemap.set_cells_terrain_connect(cells, 0, 0)
	pass
	
func pre_delete() -> void:
	pass

func on_select(new_selected: bool) -> void:
	self.selected = new_selected
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#if previewing:
		#can_place = _check_if_placeable()
	#else:
		#can_place = true
	#pass
	
#func _physics_process(delta: float) -> void:
#	pass
	
func _update_shader() -> void:
	if (get_sprite() && get_sprite().material != null):
		get_sprite().material.set_shader_parameter(SHADER_PARAM_PREVIEW, previewing)
		get_sprite().material.set_shader_parameter(SHADER_PARAM_PLACEABLE, can_place)
		get_sprite().material.set_shader_parameter(SHADER_PARAM_SELECTED, selected)
		get_sprite().material.set_shader_parameter(SHADER_PARAM_PROGRESS, progress)
		
func get_path_component() -> PathComponent:
	if _cached_path_component:
		return _cached_path_component
	_cached_path_component = get_node("PathComponent")
	return _cached_path_component
	
func get_structure_component() -> StructureComponent:
	if _cached_structure_component:
		return _cached_structure_component
	_cached_structure_component = get_node("StructureComponent")
	return _cached_structure_component
	
func make_connections() -> void:
	if get_path_component() != null:
		get_path_component().make_connections()
	if get_structure_component() != null:
		get_structure_component().make_connections()

func remove_connections() -> void:
	if get_path_component() != null:
		get_path_component().remove_connections()
	if get_structure_component() != null:
		get_structure_component().remove_connections()
	
func get_global_center() -> Vector2:
	return global_position + Vector2(Global.CELL_SIZE * size) / 2
	
func enter_module_from(pawn: PawnBase, _prev_module: ModuleBase = null) -> void:
	pawn.current_module = self
	
func get_sprite() -> Sprite2D:
	return sprite

## True if this overlap requires us to cancel a build
func overlap_module(_new_module: ModuleData, _is_horizontal: bool) -> bool:
	return true

func show_label() -> void:
	if nameplate != null:
		nameplate.visible = true

func hide_label() -> void:
	if nameplate != null:
		nameplate.visible = false

func get_random_position_on_module() -> Vector2:
	return global_position + get_structure_component().internal_points.pick_random() * Global.CELL_SIZE + randf() * Global.CELL_SIZE

func _on_footprint_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		#if sprite.is_pixel_opaque(sprite.to_local(get_global_mouse_position())):
			#print("clicked " + module_data.name)
			if event.is_action_pressed("build"):
					get_viewport().set_input_as_handled()
					Global.ui_in_game.toggle_info_panel(self)
					#on_select(!selected)
			if event.is_action_pressed("remove"):
				get_viewport().set_input_as_handled()
				Global.world_manager.remove_module(self)
