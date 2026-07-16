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
	_setup_alerts_strip()
	_setup_crew_ui()
	SignalBus.game_over.connect(_on_game_over)
	_setup_trader_ui()

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

## Minimal alerts strip (WI-05): critical pawn needs surface as brief
## top-center messages. Informational only - no forced job interrupts, the
## pawn keeps handling its own queue (see PawnNeedsComponent).
var _alerts_box: VBoxContainer
var _active_alerts: Dictionary[String, Label] = {}

func _setup_alerts_strip() -> void:
	_alerts_box = VBoxContainer.new()
	_alerts_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_alerts_box.offset_top = 8
	_alerts_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_alerts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_alerts_box)
	SignalBus.pawn_critical_need.connect(_on_pawn_critical_need)
	SignalBus.station_alert.connect(_on_station_alert)
	SignalBus.crew_resigning.connect(_on_crew_resigning)
	SignalBus.crew_resignation_cancelled.connect(_on_crew_resignation_cancelled)
	SignalBus.crew_departed.connect(_on_crew_departed)

func _pawn_label(pawn: PawnBase) -> String:
	return pawn.pawn_name if not pawn.pawn_name.is_empty() else "A crew member"

func _on_pawn_critical_need(pawn: PawnBase, need: StringName) -> void:
	_spawn_alert("%s|%s" % [_pawn_label(pawn), need], "%s: %s critical!" % [_pawn_label(pawn), String(need)])

func _on_station_alert(message: String) -> void:
	_spawn_alert(message, message)

func _on_crew_resigning(pawn: PawnBase, grace_hours: float) -> void:
	_spawn_alert("resign|" + _pawn_label(pawn),
		"%s is fed up and will leave in %d hours unless things improve!" % [_pawn_label(pawn), int(grace_hours)])

func _on_crew_resignation_cancelled(pawn: PawnBase) -> void:
	_spawn_alert("stay|" + _pawn_label(pawn), "%s decided to stay." % _pawn_label(pawn))

func _on_crew_departed(pawn: PawnBase) -> void:
	_spawn_alert("depart|" + _pawn_label(pawn), "%s has left the station." % _pawn_label(pawn))

## Dedupe-keyed transient alert label (shared by every alert source).
func _spawn_alert(key: String, text: String) -> void:
	if _active_alerts.has(key):
		return
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alerts_box.add_child(label)
	_active_alerts[key] = label
	# UI runs on wall-clock by design (TimeManager rule: UI stays real-time),
	# so a plain scene-tree timer is correct here, not sim_seconds().
	get_tree().create_timer(6.0).timeout.connect(func() -> void:
		_active_alerts.erase(key)
		if is_instance_valid(label):
			label.queue_free()
	)

# --- crew count & game over (WI-07) -------------------------------------------

const GAME_OVER_SCENE: PackedScene = preload("res://ui/game_over_screen.tscn")

var _crew_count_label: Label
var _game_over_shown: bool = false

func _setup_crew_ui() -> void:
	_crew_count_label = Label.new()
	resource_display_container.add_child(_crew_count_label)
	SignalBus.crew_hired.connect(func(_pawn: PawnBase) -> void: _refresh_crew_count())
	# Deferred: the departed pawn is still in the tree until end of frame.
	SignalBus.crew_departed.connect(func(_pawn: PawnBase) -> void: _refresh_crew_count.call_deferred())
	Global.save_manager.game_loaded.connect(func(_slot: String) -> void: _refresh_crew_count())
	# Starting crew also spawns deferred (CrewManager), and its managers ready
	# before this UI - so this deferred call lands after the spawn.
	_refresh_crew_count.call_deferred()

func _refresh_crew_count() -> void:
	if Global.crew_manager != null and is_instance_valid(_crew_count_label):
		_crew_count_label.text = "  Crew: %d" % Global.crew_manager.crew_count()

func _on_game_over() -> void:
	if _game_over_shown:
		return
	_game_over_shown = true
	add_child(GAME_OVER_SCENE.instantiate())

# --- trader screen (WI-08) ------------------------------------------------------

const TRADER_SCREEN_SCENE: PackedScene = preload("res://ui/windows/trade/trader_screen.tscn")

var _trader_screen: TraderScreen

func _setup_trader_ui() -> void:
	_trader_screen = TRADER_SCREEN_SCENE.instantiate() as TraderScreen
	_trader_screen.visible = false
	add_child(_trader_screen)
	SignalBus.trader_arrived.connect(_on_trader_arrived)
	SignalBus.trader_departed.connect(_on_trader_departed)

func open_trader_screen() -> void:
	_trader_screen.open()

func _on_trader_arrived(trader: TraderData) -> void:
	_spawn_alert("trader_arrived", "%s has docked!" % trader.trader_name)
	_trader_screen.open()

func _on_trader_departed(trader: TraderData) -> void:
	if _trader_screen.visible:
		_trader_screen.close()
	_spawn_alert("trader_departed", "%s has departed." % trader.trader_name)

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
	
