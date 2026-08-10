class_name UIMain
extends Control

## The HUD root. After WI-50 this is a mount table plus the Esc ladder, and
## nothing else: navigation lives in [ConsoleBar], "what is open" lives in
## [ModeManager], and every panel is registered here as a factory rather than
## wired up by hand.
##
## Draw order is the order things are added in [method _ready], and it matters:
## ambient strips first, then the mode panels (an opened panel is the thing the
## player just asked for, so it draws over the alert feed), then the console,
## then the right column, then the modals, then the pause menu last.

## Reparented into the console's vitals zone on ready. WI-52 replaces its
## contents with the pinned-vitals strip and the ledger chip; this item only
## moves the existing resource display into the zone as-is.
@export var vitals_strip: Control
@export var resource_display_container: HBoxContainer
@export var resource_display_ui: PackedScene
@export var resources_to_display: Array[ResourceData]

var preview_model : ModuleBase
var skip_emit: bool = false

const CONSOLE_BAR_SCENE: PackedScene = preload("res://ui/console/console_bar.tscn")
const BUILD_MENU_SCENE: PackedScene = preload("res://ui/buttons/build_menu.tscn")
const CONTRACTS_SCREEN_SCENE: PackedScene = preload("res://ui/windows/contracts_screen.tscn")
const EVENT_CARD_SCENE: PackedScene = preload("res://ui/windows/event_card.tscn")
const TRADER_SCREEN_SCENE: PackedScene = preload("res://ui/windows/trade/trader_screen.tscn")
const MINIMAP_SCENE: PackedScene = preload("res://ui/minimap.tscn")
const INSPECTOR_SCENE: PackedScene = preload("res://ui/inspector/inspector_panel.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://ui/game_over_screen.tscn")

## STORES has a console slot before it has a panel. A disabled button that says
## why is better than a hidden one, and it proves the console layout at full
## width from day one.
const STORES_REASON: String = "Station stores arrive in a later update"

var console: ConsoleBar
var mode_manager: ModeManager
## Every mode panel is mounted here rather than directly on the HUD, so that
## `move_to_front()` on open raises a panel above the ambient strips without ever
## raising it above the modals or the pause menu.
var _panel_layer: Control

var overlay_controller: OverlayController
## The build menu is the one panel body this file keeps a handle on, because Esc
## level 2 asks it whether its flyout is open. Every other panel is reachable
## through `mode_manager.panel_for()` and does not need a field here.
var _build_menu: BuildMenu

func _ready() -> void:
	Global.ui_main = self
	SignalBus.game_over.connect(_on_game_over)
	create_resource_display()
	_setup_alerts_strip()
	_setup_raid_ui()
	_setup_crew_ui()
	_setup_console()
	_setup_overlay_ui()
	_setup_modes()
	# Bound after registration so the console can render STORES disabled from the
	# first frame rather than one refresh later.
	console.bind(mode_manager)
	console.bind_overlay(overlay_controller)
	mode_manager.mode_changed.connect(_on_mode_changed)
	_setup_minimap_ui()
	_setup_inspector_ui()
	_setup_trader_ui()
	_setup_event_ui()
	_setup_pause_menu()

# --- console & modes ----------------------------------------------------------

func _setup_console() -> void:
	_panel_layer = Control.new()
	_panel_layer.name = "PanelLayer"
	_panel_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The layer is a mounting point, not a surface: it must never eat a click
	# meant for the station between two panels.
	_panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_layer)

	mode_manager = ModeManager.new()
	mode_manager.name = "ModeManager"
	mode_manager.mount = _panel_layer
	add_child(mode_manager)

	console = CONSOLE_BAR_SCENE.instantiate() as ConsoleBar
	add_child(console)
	console.sys_pressed.connect(_on_sys_pressed)
	_mount_vitals_strip()

## The resource strip is authored in this scene (it carries the energy readout's
## exported label path) and moved into the console's middle zone here. It is
## wrapped in a scroll container because seventeen resource tiles are wider than
## the flex zone: without it the strip's minimum width would push the time zone
## off the right edge. WI-52 replaces the whole thing with six pinned vitals and
## a ledger chip, at which point the wrapper goes.
func _mount_vitals_strip() -> void:
	if vitals_strip == null or console == null:
		return
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	console.vitals_zone().add_child(scroll)
	vitals_strip.get_parent().remove_child(vitals_strip)
	scroll.add_child(vitals_strip)

## The mode table. Adding a mode is a line here plus a factory, and the factory
## is not called until the player first opens that mode.
func _setup_modes() -> void:
	mode_manager.register(ModeManager.Mode.BUILD, _make_build_panel)
	mode_manager.register(ModeManager.Mode.CREW, _make_crew_panel)
	mode_manager.register_unavailable(ModeManager.Mode.STORES, STORES_REASON)
	mode_manager.register(ModeManager.Mode.TRADE, _make_trade_panel)
	mode_manager.register(ModeManager.Mode.RND, _make_research_panel)
	mode_manager.register(ModeManager.Mode.COMMS, _make_comms_panel)
	mode_manager.register(ModeManager.Mode.OVERLAY, overlay_controller.panel)

## BUILD: the WI-43 rail + flyout, lifted out of the old left column into the
## frame. The menu is unchanged apart from being told what to park its flyout
## beside.
func _make_build_panel() -> Control:
	var panel: ConsolePanel = ConsolePanel.create()
	panel.title = "Build"
	panel.panel_width = UIMetrics.PANEL_BUILD_WIDTH
	panel.content_padding = UIMetrics.CONTENT_PAD
	panel.hotkey = ModeManager.hotkey_label(ModeManager.Mode.BUILD)
	_build_menu = BUILD_MENU_SCENE.instantiate() as BuildMenu
	_build_menu.flyout_anchor = panel
	panel.content().add_child(_build_menu)
	return panel

## CREW: the job board, until WI-56 puts the roster in front of it.
func _make_crew_panel() -> Control:
	return JobsScreen.new()

## TRADE: the contracts board temporarily *is* the Trade mode. WI-55 merges the
## two trade screens into the real panel and makes this a tab of it.
func _make_trade_panel() -> Control:
	return CONTRACTS_SCREEN_SCENE.instantiate() as ContractsScreen

func _make_research_panel() -> Control:
	return UnlockPanel.new()

## COMMS: the economy page, until WI-57 makes it a tab of the ARC panel.
func _make_comms_panel() -> Control:
	return EconomyScreen.new()

func _on_sys_pressed() -> void:
	if pause_menu != null:
		pause_menu.toggle()

## Some panels mean to own the whole screen - the mockup hides the inspector
## behind Trade and R&D on the grounds that selection means nothing there.
##
## That is a **per-panel declaration**, never a list of special cases here: a
## panel that wants it exposes a `hides_inspector` property, which is read
## duck-typed exactly the way [ModeManager] finds `on_opened` / `on_closed`. A
## panel that declares nothing leaves the inspector alone, which is the right
## default for the five narrow modes.
func _on_mode_changed(new_mode: ModeManager.Mode, _previous: ModeManager.Mode) -> void:
	if inspector == null or not is_instance_valid(inspector):
		return
	var panel: Control = null
	if new_mode != ModeManager.Mode.NONE:
		panel = mode_manager.panel_for(new_mode)
	# `get()` on an undeclared property returns null, and `bool(null)` is not a
	# thing GDScript will build - so the presence test has to be the type check,
	# not a cast.
	var declared: Variant = panel.get(&"hides_inspector") if panel != null else null
	inspector.visible = not (declared is bool and bool(declared))

## Station overlays (WI-35): a self-contained UI-side controller that owns the
## overlay tint, the digit hotkeys, and the logistics flow layer. Its panel is
## the OVERLAY mode; the tint deliberately outlives that panel, which is what the
## console button's cyan bar reports.
func _setup_overlay_ui() -> void:
	overlay_controller = OverlayController.new()
	add_child(overlay_controller)

## Pause menu (WI-36). Added last so it sits on top of every other HUD panel;
## it claims Esc only when esc_claimed() says nothing else wants it.
var pause_menu: PauseMenu

func _setup_pause_menu() -> void:
	pause_menu = PauseMenu.new()
	add_child(pause_menu)

# --- Escape -------------------------------------------------------------------

## Single arbitration point for the Escape key (WI-36, rewritten in WI-50).
## Everything that cancels or closes on Esc is ranked here, most-transient first,
## and Esc always resolves the topmost one. The pause menu asks esc_claimed()
## before opening, so it only ever gets the press once nothing else wants it -
## and because both sides consult the same ordering, the outcome doesn't depend
## on input-propagation order between sibling HUD controls.
##
## Exclusive mounting is what shrank this from eleven named claims to five
## levels: seven of those claims collapsed into one `has_open_mode()` check,
## because the layout now guarantees there is at most one panel to close. The
## remaining selection block is WI-51's to collapse the same way.
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
	# 1. A held preview is the most transient thing on screen: cancel it first.
	if Global.ui_in_game != null and Global.ui_in_game.cur_input_mode != UIInGame.InputMode.None:
		return &"preview"
	# 2. A console flyout is a child of something else and closes before it.
	if _build_menu != null and _build_menu.flyout_open():
		return &"flyout"
	# The trader screen is a modal that pauses the sim; it is not a mode and
	# outranks one. WI-55 folds it into the Trade panel and this level goes.
	if _trader_screen != null and _trader_screen.visible:
		return &"trader"
	# 3. The open mode. One check, not seven.
	if mode_manager != null and mode_manager.has_open_mode():
		return &"mode"
	# 4. The current selection. One check, not five (WI-51): every kind of
	# selection renders into the same inspector, so there is only ever one thing
	# here to close.
	if inspector != null and is_instance_valid(inspector) and inspector.has_selection():
		return &"selection"
	# Last: a painted overlay. It is ranked below everything because the overlay
	# is designed to outlive its panel - Esc must never take it away while the
	# player still has something else open. `0` clears it directly.
	if overlay_controller != null and overlay_controller.has_active_mode():
		return &"overlay"
	return &""

func _close_esc_claim(claim: StringName) -> void:
	match claim:
		&"game_over":
			pass # nothing to close; the press is simply absorbed
		&"preview":
			Global.ui_in_game.change_input_mode(UIInGame.InputMode.None)
		&"flyout":
			_build_menu.close_flyout()
		&"trader":
			_trader_screen.close()
		&"mode":
			mode_manager.close()
		&"selection":
			inspector.clear()
		&"overlay":
			overlay_controller.set_mode(OverlayController.Mode.NONE)

## Minimal alerts strip (WI-05): critical pawn needs surface as brief
## top-center messages. Informational only - no forced job interrupts, the
## pawn keeps handling its own queue (see PawnNeedsComponent).
##
## WI-53 replaces this with the severity-ranked alert feed in the right column.
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
## that pays the shrinking ransom to end the raid. It refreshes off
## raid_state_changed (ships lost, price moved).
##
## WI-50's cleanup list says this goes; it stays because its replacement doesn't
## exist yet. The banner is the only way to reach `pay_off()`, so deleting it now
## would remove a real action from the game for the length of three work items.
## WI-53 turns it into a critical alert and WI-57 gives ARC its own surface.
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

var _crew_count_label: Label
var _game_over_shown: bool = false

## The crew count rides along in the vitals strip until WI-52 turns it into a
## proper vital chip.
func _setup_crew_ui() -> void:
	_crew_count_label = Label.new()
	_crew_count_label.theme_type_variation = UIType.METRIC
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

var _trader_screen: TraderScreen

func _setup_trader_ui() -> void:
	_trader_screen = TRADER_SCREEN_SCENE.instantiate() as TraderScreen
	_trader_screen.visible = false
	add_child(_trader_screen)
	SignalBus.trader_arrived.connect(_on_trader_arrived)
	SignalBus.trader_departed.connect(_on_trader_departed)

func open_trader_screen() -> void:
	_trader_screen.open()

## WI-50 deliberately dropped the auto-open. Under exclusive mounting, an
## incoming trader force-closing the player's open Build panel mid-placement is
## hostile, so arrival raises an alert and lights TRADE's readiness dot (the
## console listens to the same signal) instead of stealing the screen. The trade
## itself is still one click away, from the docking bay's own panel.
func _on_trader_arrived(trader: TraderData) -> void:
	_spawn_alert("trader_arrived", "%s has docked - open the docking bay to trade." % trader.trader_name)

func _on_trader_departed(trader: TraderData) -> void:
	if _trader_screen.visible:
		_trader_screen.close()
	_spawn_alert("trader_departed", "%s has departed." % trader.trader_name)

# --- events (WI-13) -------------------------------------------------------------

## The card manages its own visibility/queue off SignalBus.event_triggered. It is
## a modal, not a mode: it sits above the console and is not routed through
## ModeManager.
func _setup_event_ui() -> void:
	add_child(EVENT_CARD_SCENE.instantiate())

## Minimap (WI-34): the top of the permanent right column. It anchors itself and
## manages its own redraw/collapse, so mounting is just an add_child.
func _setup_minimap_ui() -> void:
	var minimap: ReadoutPanel = MINIMAP_SCENE.instantiate() as ReadoutPanel
	add_child(minimap)
	_map_readout = minimap

## The station map's collapse toggle, so the printed `M` on its header does
## something. The action exists in its own right (the program doc settles M for
## the map and G for Comms); wiring it here is what keeps the two from drifting.
var _map_readout: ReadoutPanel

func _shortcut_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_map"):
		return
	if _map_readout == null or not is_instance_valid(_map_readout):
		return
	if ModeManager.text_entry_has_focus(get_viewport()):
		return
	get_viewport().set_input_as_handled()
	_map_readout.toggle_collapsed()

func create_resource_display() -> void:
	for node: Node in resource_display_container.get_children():
		node.queue_free()
	for resource_data: ResourceData in resources_to_display:
		var resource_ui: ResourceDisplayUI = resource_display_ui.instantiate() as ResourceDisplayUI
		resource_ui.set_resource(resource_data)
		resource_display_container.add_child(resource_ui)

# --- selection (WI-51) ---------------------------------------------------------

## The bottom-right selection surface. Every click path in the game funnels into
## `inspector.select()`; nothing else may instantiate a selection surface.
var inspector: InspectorPanel

## Mounted after the map so it draws above the ambient strips, and before the
## modals so it never draws over one. It anchors itself to the bottom-right and
## grows upward with its content, so mounting is just an add_child.
func _setup_inspector_ui() -> void:
	inspector = INSPECTOR_SCENE.instantiate() as InspectorPanel
	add_child(inspector)
	inspector.selection_changed.connect(_on_selection_changed)

## Selection brackets follow the inspector rather than the panels. Module
## brackets are driven by `ModuleBase.selected`, which the module and turboshaft
## tab sets raise and drop; the pawn brackets have no such flag, so they are
## pointed from here. Selecting anything that is not a pawn clears them, which is
## what "only one thing is selected" means on screen.
func _on_selection_changed(selection_kind: InspectorPanel.SelectionKind) -> void:
	if Global.ui_in_game == null:
		return
	var pawn: PawnBase = null
	if selection_kind == InspectorPanel.SelectionKind.CREW:
		pawn = inspector.selected_subject() as PawnBase
	Global.ui_in_game.set_selected_pawn(pawn)

func pawn_clicked(pawn: PawnBase) -> void:
	inspector.select(pawn)

func resource_pile_clicked(pile: ResourcePile) -> void:
	inspector.select(pile)

func asteroid_clicked(asteroid: AsteroidBase) -> void:
	inspector.select(asteroid)

var _click_cycler: ClickCycler = ClickCycler.new()

## Entry point for module footprint clicks. [ClickCycler] still arbitrates
## stacked cells and cycles through them on repeated clicks (WI-10) - that is a
## different problem from what the panel does with the answer, which is why it
## survives the collapse unchanged.
##
## Turbolifts need no branch here any more: [InspectorPanel.kind_of] resolves a
## finished lift to the TURBOSHAFT tab set, so "a lift opens something else" is a
## property of the selection rather than of this handler.
func module_clicked(module: ModuleBase) -> void:
	var cell: Vector2i = Global.world_to_cell(module.get_global_mouse_position())
	var target: ModuleBase = _click_cycler.handle_click(
		module, cell, inspector.selected_subject() is ModuleBase)
	if target == null:
		return
	inspector.select(target)
