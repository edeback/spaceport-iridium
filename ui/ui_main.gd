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

var preview_model : ModuleBase
var skip_emit: bool = false

const CONSOLE_BAR_SCENE: PackedScene = preload("res://ui/console/console_bar.tscn")
const BUILD_MENU_SCENE: PackedScene = preload("res://ui/buttons/build_menu.tscn")
const CONTRACTS_SCREEN_SCENE: PackedScene = preload("res://ui/windows/contracts_screen.tscn")
const EVENT_CARD_SCENE: PackedScene = preload("res://ui/windows/event_card.tscn")
const TRADER_SCREEN_SCENE: PackedScene = preload("res://ui/windows/trade/trader_screen.tscn")
const MINIMAP_SCENE: PackedScene = preload("res://ui/minimap.tscn")
const ALERT_FEED_SCENE: PackedScene = preload("res://ui/alerts/alert_feed.tscn")
const ALERT_HISTORY_SCENE: PackedScene = preload("res://ui/alerts/alert_history.tscn")
const RAID_READOUT_SCENE: PackedScene = preload("res://ui/alerts/raid_readout.tscn")
const LEDGER_SCENE: PackedScene = preload("res://ui/console/resource_ledger.tscn")
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
	_setup_console()
	_setup_overlay_ui()
	_setup_modes()
	# Bound after registration so the console can render STORES disabled from the
	# first frame rather than one refresh later.
	console.bind(mode_manager)
	console.bind_overlay(overlay_controller)
	mode_manager.mode_changed.connect(_on_mode_changed)
	_setup_right_column()
	_setup_inspector_ui()
	_setup_trader_ui()
	_setup_event_ui()
	_setup_pause_menu()
	# Last, once every readout and the inspector exist: the column measures itself
	# and hands the inspector its ceiling.
	_layout_right_column()

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
	_setup_ledger()

## The resource ledger (WI-52). Built by this file rather than by the console
## because it is a flyout: it has to sit *above* the console strip, and a child
## of the console would be clipped by it.
##
## Deliberately not a mode (invariant 1's one exception) - checking stock
## mid-build must not close Build - so [ModeManager] never sees it and Esc ranks
## it by hand, above the open mode.
var ledger: ResourceLedger

func _setup_ledger() -> void:
	ledger = LEDGER_SCENE.instantiate() as ResourceLedger
	add_child(ledger)
	ledger.strip = console.vitals()
	console.vitals().ledger_toggled.connect(ledger.toggle)

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
##
## **An outstanding critical alert is deliberately not on this ladder** (WI-53).
## Acknowledging one is a click on the alert and only that: the player hammers
## Esc, and an acknowledgement Esc can satisfy is an acknowledgement that gets
## satisfied without being read - which would leave the tier that stops the game
## with nothing to show for it. This is the one considered exception to WI-36's
## "Esc is always an exit" invariant, and it belongs here rather than in a doc.
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
	# The resource ledger is the other flyout and ranks with them, for a slightly
	# different reason: it is deliberately allowed to coexist with an open mode
	# (WI-52), so Esc must take it away before the panel it is sitting over.
	if ledger != null and is_instance_valid(ledger) and ledger.is_open():
		return &"ledger"
	# The alert log is the third, on the same terms (WI-53).
	if _alert_history != null and is_instance_valid(_alert_history) and _alert_history.is_open():
		return &"alert_log"
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
		&"ledger":
			ledger.close()
		&"alert_log":
			_alert_history.close()
		&"trader":
			_trader_screen.close()
		&"mode":
			mode_manager.close()
		&"selection":
			inspector.clear()
		&"overlay":
			overlay_controller.set_mode(OverlayController.Mode.NONE)

# --- the right column (WI-34, WI-51, WI-53) -----------------------------------

## Station map, alert feed, live-raid readout, and the inspector under them.
## Invariant 3: left is doing, right is watching - these own the right edge
## permanently and never move sideways.
##
## What replaced the old alerts strip: `_setup_alerts_strip()` built a top-centre
## column of red [Label]s and `_spawn_alert()` added one per message, deduped by
## text and freed by a fifteen-second timer. Every alert was the same colour, the
## same size, in the same place, for the same fifteen seconds, and then gone
## forever. All five of the signals it handled are [AlertManager]'s now, which is
## where they can be given a tier and a subject.
var _map_readout: ReadoutPanel
var _alert_feed: AlertFeed
var _raid_readout: RaidReadout

func _setup_right_column() -> void:
	# Minimap (WI-34): the top of the column. It manages its own redraw and
	# collapse, so mounting is just an add_child.
	_map_readout = MINIMAP_SCENE.instantiate() as ReadoutPanel
	add_child(_map_readout)

	_alert_feed = ALERT_FEED_SCENE.instantiate() as AlertFeed
	add_child(_alert_feed)
	_alert_feed.history_requested.connect(_on_history_requested)

	# The raid readout is only mounted while a raid is on (it hides itself), so
	# it is the reason the column has to be re-stacked rather than laid out once.
	_raid_readout = RAID_READOUT_SCENE.instantiate() as RaidReadout
	add_child(_raid_readout)

	_alert_history = ALERT_HISTORY_SCENE.instantiate() as AlertHistory
	add_child(_alert_history)

	for readout: ReadoutPanel in _column_readouts():
		readout.minimum_size_changed.connect(_queue_column_layout)
		readout.visibility_changed.connect(_queue_column_layout)

## Top to bottom. Order is the layout.
func _column_readouts() -> Array[ReadoutPanel]:
	return [_map_readout, _raid_readout, _alert_feed] as Array[ReadoutPanel]

var _laying_out_column: bool = false

## Stacks the right column from the top and tells the inspector where it ends.
##
## The column has to be a stack rather than three anchored constants because two
## of the three readouts change height: the map folds, and the alert feed grows
## with its rows (and the raid readout appears and disappears entirely). Baking a
## worst case into [constant UIMetrics.INSPECTOR_TOP_LIMIT] instead would cost
## the inspector three hundred pixels on the ordinary station where the feed is
## empty and no raid is on - so the measurement is live and the constant is only
## the floor.
func _layout_right_column() -> void:
	if _laying_out_column:
		return
	_laying_out_column = true
	var y: float = float(UIMetrics.SCREEN_GUTTER)
	for readout: ReadoutPanel in _column_readouts():
		if readout == null or not is_instance_valid(readout) or not readout.visible:
			continue
		readout.offset_top = y
		readout.fit_height()
		y = readout.offset_bottom + float(UIMetrics.SCREEN_GUTTER)
	if _alert_history != null and is_instance_valid(_alert_history):
		# The flyout hangs off the feed's header, so it tracks the feed rather
		# than the bottom of the stack.
		_alert_history.offset_top = _alert_feed.offset_top if _alert_feed != null else y
		_alert_history.fit_height()
	if inspector != null and is_instance_valid(inspector):
		inspector.top_limit = int(y)
	_laying_out_column = false

## Deferred so a burst of size changes in one frame settles into one stack, and
## so the stack never runs inside the notification that caused it.
func _queue_column_layout() -> void:
	if _laying_out_column:
		return
	_layout_right_column.call_deferred()

## The alert log (WI-53). Owned here rather than by the feed for the same reason
## the resource ledger is: a flyout has to sit beside the column, and a child of
## a 344px readout would be clipped by it.
##
## It is the **second** deliberate exception to invariant 1's one-panel rule
## (the ledger was the first, WI-52). Same argument: it is a readout raised from
## a permanent readout rather than a workspace, and closing Build to read what
## just happened is exactly the interruption the invariant exists to prevent.
var _alert_history: AlertHistory

func _on_history_requested() -> void:
	if _alert_history != null:
		_alert_history.toggle()

# --- game over (WI-07) --------------------------------------------------------

## The crew count used to be a Label appended to the old resource strip and
## refreshed off four signals. It is a derived vitals chip now (WI-52), polled
## with the rest of the strip, so the signal wiring went with the label.
var _game_over_shown: bool = false

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
	SignalBus.trader_departed.connect(_on_trader_departed)

func open_trader_screen() -> void:
	_trader_screen.open()

## WI-50 deliberately dropped the auto-open. Under exclusive mounting, an
## incoming trader force-closing the player's open Build panel mid-placement is
## hostile, so arrival raises an alert and lights TRADE's readiness dot (the
## console listens to the same signal) instead of stealing the screen. The trade
## itself is still one click away, from the docking bay's own panel - and since
## WI-53 the arrival alert's subject *is* the docking bay, so its JUMP lands
## there. Both alerts are [AlertManager]'s now; this handler only has to close a
## screen the departing trader has left nobody to trade with.
func _on_trader_departed(_trader: TraderData) -> void:
	if _trader_screen.visible:
		_trader_screen.close()

# --- events (WI-13) -------------------------------------------------------------

## The card manages its own visibility/queue off SignalBus.event_triggered. It is
## a modal, not a mode: it sits above the console and is not routed through
## ModeManager.
func _setup_event_ui() -> void:
	add_child(EVENT_CARD_SCENE.instantiate())

## The two readout hotkeys that are not modes: M folds the station map, L opens
## the resource ledger. Both go through the same text-focus guard every other HUD
## hotkey uses (WI-50 contract point 6) - typing "steel" into the build search
## must not fold the map.
func _shortcut_input(event: InputEvent) -> void:
	if ModeManager.text_entry_has_focus(get_viewport()):
		return
	if event.is_action_pressed("toggle_map"):
		if _map_readout == null or not is_instance_valid(_map_readout):
			return
		get_viewport().set_input_as_handled()
		_map_readout.toggle_collapsed()
	elif event.is_action_pressed("toggle_ledger"):
		if ledger == null or not is_instance_valid(ledger):
			return
		get_viewport().set_input_as_handled()
		ledger.toggle()

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
