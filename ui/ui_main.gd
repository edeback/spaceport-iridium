class_name UIMain
extends Control

@export var button_group: PackedScene
@export var button_container: VBoxContainer

@export var resource_display_container: HBoxContainer
@export var resource_display_ui: PackedScene
@export var resources_to_display: Array[ResourceData]

@export var pawn_info_screen: PackedScene
var cur_pawn_info: PawnInfoPanel

@export var resource_pile_screen: PackedScene
var cur_resource_pile_screen: ResourcePileInventoryTab

@export var temp_modules: Array[ModuleData] = []

# Dictionary[String, Array[ModuleData]]
var module_data_groups: Dictionary = {}
var preview_model : ModuleBase
var skip_emit: bool = false

const MODULE_PATH: String = "res://data/modules/"

# Called when the node enters the scene tree for the first time.
var unlock_panel: UnlockPanel

func _ready() -> void:
	load_moduledatas()
	create_module_button_groups()
	create_resource_display()
	Global.ui_main = self
	Global.ui_in_game.input_mode_changed.connect(_on_input_mode_changed)
	_setup_unlock_ui()
	_setup_save_ui()

## Minimal save/load controls next to the Research button: slot name field +
## Save/Load buttons. F5/F9 quick-slot shortcuts live on SaveManager.
func _setup_save_ui() -> void:
	var info_btn: Button = %ModuleInfoButton
	var info_margin: Node = info_btn.get_parent()
	var side_vbox: Node = info_margin.get_parent()
	var row := HBoxContainer.new()
	var slot_edit := LineEdit.new()
	slot_edit.text = SaveManager.QUICK_SLOT
	slot_edit.custom_minimum_size.x = 110
	row.add_child(slot_edit)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(func() -> void:
		if not slot_edit.text.strip_edges().is_empty():
			Global.save_manager.save_slot(slot_edit.text.strip_edges())
	)
	row.add_child(save_btn)
	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(func() -> void:
		if not slot_edit.text.strip_edges().is_empty():
			Global.save_manager.load_slot(slot_edit.text.strip_edges())
	)
	row.add_child(load_btn)
	side_vbox.add_child(row)
	side_vbox.move_child(row, info_margin.get_index())

func _setup_unlock_ui() -> void:
	unlock_panel = UnlockPanel.new()
	unlock_panel.visible = false
	add_child(unlock_panel)

	# Add a "Research" button just above the existing "Module Info" button,
	# reusing its style so it fits in.
	var info_btn: Button = %ModuleInfoButton
	var info_margin: Node = info_btn.get_parent()
	var side_vbox: Node = info_margin.get_parent()
	var research_btn := Button.new()
	research_btn.text = "Research"
	var style: StyleBox = info_btn.get_theme_stylebox("normal")
	if style != null:
		research_btn.add_theme_stylebox_override("normal", style)
	research_btn.pressed.connect(toggle_unlock_panel)
	side_vbox.add_child(research_btn)
	side_vbox.move_child(research_btn, info_margin.get_index())

func toggle_unlock_panel() -> void:
	unlock_panel.visible = not unlock_panel.visible
	if unlock_panel.visible:
		unlock_panel.refresh()

func load_moduledatas() -> void:
	var current_buttons = button_container.get_children()
	for node in current_buttons:
		button_container.remove_child(node)
		node.queue_free()
	module_data_groups.clear()
	var file_paths: Array[String] = ResourceScanner.scan_paths(MODULE_PATH)
	for file_path: String in file_paths:
		var module_data: ModuleData = ResourceLoader.load(file_path, "ModuleData")
	#for module_data: ModuleData in temp_modules:
		if module_data.hidden:
			continue
		if module_data.tags.size() == 0:
			module_data_groups.get_or_add("", [] as Array[ModuleData]).append(module_data)
		for tag: String in module_data.tags:
			module_data_groups.get_or_add(tag, [] as Array[ModuleData]).append(module_data)
			
			

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

func _on_info_button_pressed() -> void:
	Global.ui_in_game.change_input_mode(UIInGame.InputMode.None)

func _on_input_mode_changed(new_mode: UIInGame.InputMode) -> void:
	%ModuleInfoButton.disabled = (new_mode != UIInGame.InputMode.Module)

func pawn_clicked(pawn: PawnBase) -> void:
	if cur_pawn_info != null:
		cur_pawn_info.queue_free()
		if cur_pawn_info.pawn == pawn:
			# Just close, nothing else
			return
	cur_pawn_info = pawn_info_screen.instantiate()
	cur_pawn_info.set_pawn(pawn)
	add_child(cur_pawn_info)
	
func resource_pile_clicked(pile: ResourcePile) -> void:
	if cur_resource_pile_screen != null:
		cur_resource_pile_screen.queue_free()
		if cur_resource_pile_screen.resource_pile == pile:
			return
	cur_resource_pile_screen = resource_pile_screen.instantiate()
	cur_resource_pile_screen.set_resource_pile(pile)
	add_child(cur_resource_pile_screen)
	
func toggle_info_panel(selected_module: ModuleBase) -> void:
	if %ModuleInfoPanel.visible == true and %ModuleInfoPanel.module_viewed == selected_module:
		close_info_panel()
	else:
		%ModuleInfoPanel.set_module(selected_module)
		%ModuleInfoPanel.visible = true	

func close_info_panel() -> void:
	%ModuleInfoPanel.set_module(null)
	%ModuleInfoPanel.visible = false
	
