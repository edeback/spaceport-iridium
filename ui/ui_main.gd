class_name UIMain
extends Control

@export var resource_display_container: HBoxContainer
@export var resource_display_ui: PackedScene
@export var resources_to_display: Array[ResourceData]

@export var pawn_info_screen: PackedScene
var cur_pawn_info: PawnInfoPanel

@export var resource_pile_screen: PackedScene
var cur_resource_pile_screen: ResourcePileInventoryTab

@export var asteroid_info_screen: PackedScene
var cur_asteroid_info_screen: AsteroidInfoPanel

var preview_model : ModuleBase
var skip_emit: bool = false

# Called when the node enters the scene tree for the first time.
var unlock_panel: UnlockPanel

func _ready() -> void:
	# The build menu (rail + flyout) is a self-contained scene mounted in ui_main.tscn;
	# it scans and groups modules by ui_category on its own _ready (WI-43).
	create_resource_display()
	Global.ui_main = self
	Global.ui_in_game.input_mode_changed.connect(_on_input_mode_changed)
	_setup_unlock_ui()
	_setup_alerts_strip()
	_setup_raid_ui()
	_setup_crew_ui()
	SignalBus.game_over.connect(_on_game_over)
	_setup_trader_ui()
	_setup_event_ui()
	_setup_contracts_ui()
	_setup_economy_ui()
	_setup_jobs_ui()
	_setup_minimap_ui()
	_setup_overlay_ui()
	_setup_pause_menu()

## Pause menu (WI-36). Added last so it sits on top of every other HUD panel;
## it claims Esc only when esc_claimed() says nothing else wants it.
var pause_menu: PauseMenu

func _setup_pause_menu() -> void:
	pause_menu = PauseMenu.new()
	add_child(pause_menu)

## Single arbitration point for the Escape key (WI-36). Everything that cancels or
## closes on Esc is ranked here, most-transient first, and Esc always resolves the
## topmost one. The pause menu asks esc_claimed() before opening, so it only ever
## gets the press once nothing else wants it - and because both sides consult the
## same ordering, the outcome doesn't depend on input-propagation order between
## sibling HUD controls.
##
## Some panels (Research, Contracts, Economy) still close themselves on Esc. Their
## handler and this one do the same thing, so whichever runs first wins and the
## result is identical.
func esc_claimed() -> bool:
	return _topmost_esc_claim() != &""

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var claim: StringName = _topmost_esc_claim()
	if claim == &"":
		return # nothing open: the press belongs to the pause menu
	get_viewport().set_input_as_handled()
	_close_esc_claim(claim)

func _topmost_esc_claim() -> StringName:
	# The run is over - the game-over screen owns the frame, and Esc must not
	# reopen anything behind it.
	if _game_over_shown:
		return &"game_over"
	# A held preview is the most transient thing on screen: cancel it first.
	if Global.ui_in_game != null and Global.ui_in_game.cur_input_mode != UIInGame.InputMode.None:
		return &"preview"
	if %BuildMenu.flyout_open():
		return &"flyout"
	# Modal-ish windows next, then the passive info panels.
	if _trader_screen != null and _trader_screen.visible:
		return &"trader"
	if unlock_panel != null and unlock_panel.visible:
		return &"unlocks"
	if _contracts_screen != null and _contracts_screen.visible:
		return &"contracts"
	if _economy_screen != null and _economy_screen.visible:
		return &"economy"
	if _jobs_screen != null and _jobs_screen.visible:
		return &"jobs"
	if overlay_controller != null and overlay_controller.has_active_mode():
		return &"overlay"
	if cur_pawn_info != null and is_instance_valid(cur_pawn_info):
		return &"pawn_info"
	if cur_asteroid_info_screen != null and is_instance_valid(cur_asteroid_info_screen):
		return &"asteroid_info"
	if cur_resource_pile_screen != null and is_instance_valid(cur_resource_pile_screen):
		return &"pile_info"
	if %TurboshaftPanel.visible:
		return &"turboshaft"
	if %ModuleInfoPanel.visible:
		return &"module_info"
	return &""

func _close_esc_claim(claim: StringName) -> void:
	match claim:
		&"game_over":
			pass # nothing to close; the press is simply absorbed
		&"preview":
			Global.ui_in_game.change_input_mode(UIInGame.InputMode.None)
		&"flyout":
			%BuildMenu.close_flyout()
		&"trader":
			_trader_screen.close()
		&"unlocks":
			unlock_panel.visible = false
		&"contracts":
			_contracts_screen.visible = false
		&"economy":
			_economy_screen.visible = false
		&"jobs":
			_jobs_screen.visible = false
		&"overlay":
			overlay_controller.set_mode(OverlayController.Mode.NONE)
		&"pawn_info":
			cur_pawn_info.queue_free()
			cur_pawn_info = null
		&"asteroid_info":
			cur_asteroid_info_screen.queue_free()
			cur_asteroid_info_screen = null
		&"pile_info":
			cur_resource_pile_screen.queue_free()
			cur_resource_pile_screen = null
		&"turboshaft":
			%TurboshaftPanel.close()
		&"module_info":
			close_info_panel()

## Minimal alerts strip (WI-05): critical pawn needs surface as brief
## top-center messages. Informational only - no forced job interrupts, the
## pawn keeps handling its own queue (see PawnNeedsComponent).
var _alerts_box: VBoxContainer
var _active_alerts: Dictionary[String, Label] = {}

func _setup_alerts_strip() -> void:
	_alerts_box = VBoxContainer.new()
	_alerts_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_alerts_box.offset_top = 8
	_alerts_box.alignment = BoxContainer.ALIGNMENT_CENTER
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
	label.add_theme_color_override("font_color", UIPalette.ATTENTION)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alerts_box.add_child(label)
	_active_alerts[key] = label
	# UI runs on wall-clock by design (TimeManager rule: UI stays real-time),
	# so a plain scene-tree timer is correct here, not sim_seconds().
	if get_tree():
		get_tree().create_timer(15.0).timeout.connect(func() -> void:
			_active_alerts.erase(key)
			if is_instance_valid(label):
				label.queue_free()
		)

# --- raid banner (WI-32) ------------------------------------------------------

## Top-strip banner shown while a pirate raid is on: ship count + a "Hail" button
## that pays the shrinking ransom to end the raid. Code-built like the rest of
## the top-bar UI. It refreshes off raid_state_changed (ships lost, price moved).
var _raid_banner: PanelContainer
var _raid_label: Label
var _raid_pay_btn: Button

func _setup_raid_ui() -> void:
	_raid_banner = PanelContainer.new()
	_raid_banner.visible = false
	_raid_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_raid_banner.offset_top = 40
	_raid_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_raid_banner.add_child(row)
	_raid_label = Label.new()
	_raid_label.add_theme_color_override("font_color", UIPalette.ATTENTION)
	row.add_child(_raid_label)
	_raid_pay_btn = Button.new()
	_raid_pay_btn.pressed.connect(_on_raid_hail_pressed)
	row.add_child(_raid_pay_btn)
	add_child(_raid_banner)
	SignalBus.raid_started.connect(func(_strength: float) -> void: _refresh_raid_banner())
	SignalBus.raid_ended.connect(func(_outcome: StringName) -> void: _refresh_raid_banner())
	SignalBus.raid_state_changed.connect(_refresh_raid_banner)

func _on_raid_hail_pressed() -> void:
	if Global.raid_manager != null:
		Global.raid_manager.pay_off()

func _refresh_raid_banner() -> void:
	var mgr: RaidManager = Global.raid_manager
	if mgr == null or not mgr.active:
		_raid_banner.visible = false
		return
	_raid_banner.visible = true
	_raid_label.text = "⚠ RAID — %d hostile ship(s)" % mgr.ship_count()
	var price: int = mgr.current_payoff()
	_raid_pay_btn.text = "Hail: pay off (%d cr)" % price
	_raid_pay_btn.disabled = not mgr.can_pay_off()

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
	# Starting crew also spawns deferred after the first module is added (CrewManager), and its managers ready
	# before this UI - so this deferred call lands after the spawn.
	SignalBus.module_added.connect(func(_module: ModuleBase) -> void: _refresh_crew_count.call_deferred(), CONNECT_ONE_SHOT)

func _refresh_crew_count() -> void:
	if Global.crew_manager != null and is_instance_valid(_crew_count_label):
		_crew_count_label.text = "  Crew: %d" % Global.crew_manager.crew_count()

## Shared by every game-over path (WI-07 crew abandonment, WI-25 bankruptcy).
## The first to fire wins - _game_over_shown keeps the two paths from stacking
## two screens if they trip in the same frame.
func _on_game_over(reason: String) -> void:
	if _game_over_shown:
		return
	_game_over_shown = true
	var screen: GameOverScreen = GAME_OVER_SCENE.instantiate() as GameOverScreen
	if reason != "":
		screen.configure(reason)
	add_child(screen)

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

# --- events & contracts (WI-13 / WI-14) ------------------------------------------

const EVENT_CARD_SCENE: PackedScene = preload("res://ui/windows/event_card.tscn")
const CONTRACTS_SCREEN_SCENE: PackedScene = preload("res://ui/windows/contracts_screen.tscn")

var _contracts_screen: ContractsScreen

## The card manages its own visibility/queue off SignalBus.event_triggered.
func _setup_event_ui() -> void:
	add_child(EVENT_CARD_SCENE.instantiate())

func _setup_contracts_ui() -> void:
	_contracts_screen = CONTRACTS_SCREEN_SCENE.instantiate() as ContractsScreen
	add_child(_contracts_screen)
	_add_side_button("Contracts", func() -> void:
		if _contracts_screen.visible:
			_contracts_screen.visible = false
		else:
			_contracts_screen.open()
	)

## Economy page (WI-25): a top-bar toggle next to Contracts, opening the ledger /
## loan / cost-toggle window. Code-built like the research panel.
var _economy_screen: EconomyScreen

func _setup_economy_ui() -> void:
	_economy_screen = EconomyScreen.new()
	add_child(_economy_screen)
	_add_side_button("Economy", func() -> void:
		if _economy_screen.visible:
			_economy_screen.visible = false
		else:
			_economy_screen.open()
	)

## Job board (WI-44): a top-bar toggle opening the station's work queue - what is
## in progress, what is waiting, and why a chosen pawn will not take a given job.
var _jobs_screen: JobsScreen

func _setup_jobs_ui() -> void:
	_jobs_screen = JobsScreen.new()
	add_child(_jobs_screen)
	_add_side_button("Jobs", func() -> void:
		if _jobs_screen.visible:
			_jobs_screen.visible = false
		else:
			_jobs_screen.open()
	)

## Minimap (WI-34): a self-contained upper-right overview panel. It anchors
## itself to the top-right and manages its own redraw/collapse, so mounting is
## just an add_child on this full-rect HUD control.
const MINIMAP_SCENE: PackedScene = preload("res://ui/minimap.tscn")

func _setup_minimap_ui() -> void:
	add_child(MINIMAP_SCENE.instantiate())

## Station overlays (WI-35): a self-contained UI-side controller that owns its
## own toolbar strip (top bar), hotkeys (1-5, Esc), legend, and the logistics
## flow layer. Pure view - it only writes each module's OVERLAY_COLOR shader
## param while a mode is active, and is session-only (nothing saved).
var overlay_controller: OverlayController

func _setup_overlay_ui() -> void:
	overlay_controller = OverlayController.new()
	add_child(overlay_controller)

func _setup_unlock_ui() -> void:
	unlock_panel = UnlockPanel.new()
	unlock_panel.visible = false
	add_child(unlock_panel)
	_add_side_button("Research", toggle_unlock_panel)

## Adds a button just above the existing "Module Info" button, reusing its
## style so it fits in (Research, Contracts, ...).
func _add_side_button(label: String, on_pressed: Callable) -> Button:
	var info_btn: Button = %ModuleInfoButton
	var info_margin: Node = info_btn.get_parent()
	var side_vbox: Node = info_margin.get_parent()
	var button := Button.new()
	button.text = label
	button.pressed.connect(on_pressed)
	side_vbox.add_child(button)
	side_vbox.move_child(button, info_margin.get_index())
	return button

func toggle_unlock_panel() -> void:
	unlock_panel.visible = not unlock_panel.visible
	if unlock_panel.visible:
		unlock_panel.refresh()

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
	Global.ui_in_game.pawn_brackets.show_around(pawn, _pawn_bracket_rect(pawn))
	# tree_exiting fires on both close paths (exit button and the re-click
	# toggle's queue_free above); clear_if_target keeps a newly selected pawn's
	# brackets alive when the old panel's deferred free lands after them.
	cur_pawn_info.tree_exiting.connect(func() -> void:
		Global.ui_in_game.pawn_brackets.clear_if_target(pawn))

func _pawn_bracket_rect(pawn: PawnBase) -> Rect2:
	if pawn.animated_sprite != null and pawn.animated_sprite.sprite_frames != null:
		var frame_texture: Texture2D = pawn.animated_sprite.sprite_frames.get_frame_texture(pawn.animated_sprite.animation, pawn.animated_sprite.frame)
		if frame_texture != null:
			var sprite_size: Vector2 = frame_texture.get_size() * pawn.animated_sprite.scale
			return Rect2(Vector2(-sprite_size.x / 2,-sprite_size.y), sprite_size)
	return Rect2(Vector2(-16, -24), Vector2(32, 48))
	
func resource_pile_clicked(pile: ResourcePile) -> void:
	if cur_resource_pile_screen != null:
		cur_resource_pile_screen.queue_free()
		if cur_resource_pile_screen.resource_pile == pile:
			return
	cur_resource_pile_screen = resource_pile_screen.instantiate()
	cur_resource_pile_screen.set_resource_pile(pile)
	add_child(cur_resource_pile_screen)

func asteroid_clicked(asteroid: AsteroidBase) -> void:
	if cur_asteroid_info_screen != null:
		var was_same: bool = cur_asteroid_info_screen.asteroid == asteroid
		cur_asteroid_info_screen.queue_free()
		cur_asteroid_info_screen = null
		if was_same:
			return
	cur_asteroid_info_screen = asteroid_info_screen.instantiate() as AsteroidInfoPanel
	cur_asteroid_info_screen.set_asteroid(asteroid)
	add_child(cur_asteroid_info_screen)
	
var _click_cycler: ClickCycler = ClickCycler.new()

## Entry point for module footprint clicks - arbitrates stacked cells and
## cycles through them on repeated clicks (WI-10).
func module_clicked(module: ModuleBase) -> void:
	var cell: Vector2i = Global.world_to_cell(module.get_global_mouse_position())
	var panel_open: bool = %ModuleInfoPanel.visible and %ModuleInfoPanel.module_viewed != null
	var target: ModuleBase = _click_cycler.handle_click(module, cell, panel_open)
	if target == null:
		return
	toggle_info_panel(target)

func toggle_info_panel(selected_module: ModuleBase) -> void:
	# Turbolifts are managed per-shaft (WI-11): any lift in a shaft opens the
	# shaft panel instead of the per-module info panel.
	if selected_module is ModuleTurbolift and selected_module.is_complete():
		close_info_panel()
		%TurboshaftPanel.toggle_for(selected_module as ModuleTurbolift)
		return
	%TurboshaftPanel.close()
	if %ModuleInfoPanel.visible == true and %ModuleInfoPanel.module_viewed == selected_module:
		close_info_panel()
	else:
		%ModuleInfoPanel.set_module(selected_module)
		%ModuleInfoPanel.visible = true

func close_info_panel() -> void:
	%ModuleInfoPanel.set_module(null)
	%ModuleInfoPanel.visible = false
	
