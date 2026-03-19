class_name UIMain
extends Control

@export var button_group: PackedScene
@export var button_container: VBoxContainer

@export var resource_display_container: HBoxContainer
@export var resource_display_ui: PackedScene
@export var resources_to_display: Array[ResourceData]

@export var pawn_info_screen: PackedScene
@export var cur_pawn_info: PawnInfoPanel

@export var temp_modules: Array[ModuleData] = []

var module_data_groups: Dictionary = {}
var preview_model : ModuleBase
var skip_emit: bool = false

const MODULE_PATH: String = "res://data/modules/"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_moduledatas()
	create_module_button_groups()
	create_resource_display()
	Global.ui_main = self
	Global.world_manager.show_module_layer(WorldManager.StructureLayer.MODULE)
	Global.world_manager.active_layer_changed.connect(_on_active_layer_changed)
	Global.ui_in_game.input_mode_changed.connect(_on_input_mode_changed)

func get_all_file_paths(path: String) -> Array[String]:
	var file_paths: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var file_path: String = path + "/" + file_name
		if dir.current_is_dir():
			file_paths += get_all_file_paths(file_path)
		elif file_name.get_extension() == "tres":
			file_paths.append(file_path)
		file_name = dir.get_next()
	return file_paths

func load_moduledatas() -> void:
	var current_buttons = button_container.get_children()
	for node in current_buttons:
		button_container.remove_child(node)
		node.queue_free()
	module_data_groups.clear()
	var file_paths: Array[String] = get_all_file_paths(MODULE_PATH)
	for file_path: String in file_paths:
		var module_data: ModuleData = ResourceLoader.load(file_path, "ModuleData")
	#for module_data: ModuleData in temp_modules:
		if module_data.hidden:
			continue
		if module_data.tags.size() == 0:
			module_data_groups.get_or_add("", []).append(module_data)
		for tag: String in module_data.tags:
			module_data_groups.get_or_add(tag, []).append(module_data)
			
			

func create_module_button_groups() -> void:
	for module_data_group: String in module_data_groups:
		var new_button_group = button_group.instantiate() as ModuleButtonGroup
		new_button_group.setup_group(module_data_group, module_data_groups[module_data_group])
		button_container.add_child(new_button_group)
		
func create_resource_display() -> void:
	for node: Node in resource_display_container.get_children():
		node.queue_free()
	for resource_data: ResourceData in resources_to_display:
		var resource_ui: ResourceDisplayUI = resource_display_ui.instantiate() as ResourceDisplayUI
		resource_ui.set_resource(resource_data)
		resource_display_container.add_child(resource_ui)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_check_button_toggled(toggled_on: bool) -> void:
	Global.world_manager.show_module_layer(WorldManager.StructureLayer.CORRIDOR if toggled_on else WorldManager.StructureLayer.MODULE)
	#Global.world_manager.set_module_layer_visibility(WorldManager.StructureLayer.CORRIDOR, toggled_on)

func _on_info_button_pressed() -> void:
	Global.ui_in_game.change_input_mode(UIInGame.InputMode.None)

func _on_input_mode_changed(new_mode: UIInGame.InputMode) -> void:
	%ModuleInfoButton.disabled = (new_mode != UIInGame.InputMode.Module)

func _on_active_layer_changed(new_layer: WorldManager.StructureLayer) -> void:
	skip_emit = true
	%DisplayCorridorsCheckbox.set_pressed_no_signal(new_layer == WorldManager.StructureLayer.CORRIDOR)
	skip_emit = false
	

func _on_interaction_layer_changed(new_layer: int) -> void:
	if not skip_emit:
		Global.world_manager.show_module_layer(new_layer)

func pawn_clicked(pawn: PawnBase) -> void:
	if cur_pawn_info != null:
		cur_pawn_info.queue_free()
		if cur_pawn_info.pawn == pawn:
			# Just close, nothign else
			return
	cur_pawn_info = pawn_info_screen.instantiate()
	cur_pawn_info.set_pawn(pawn)
	add_child(cur_pawn_info)
	
