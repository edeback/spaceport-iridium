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
const BUILD_CURSOR_HINT_SCENE: PackedScene = preload("res://ui/buttons/build_cursor_hint.tscn")
const MINIMAP_SCENE: PackedScene = preload("res://ui/minimap.tscn")
const ALERT_FEED_SCENE: PackedScene = preload("res://ui/alerts/alert_feed.tscn")
const ALERT_HISTORY_SCENE: PackedScene = preload("res://ui/alerts/alert_history.tscn")
const RAID_READOUT_SCENE: PackedScene = preload("res://ui/alerts/raid_readout.tscn")
const LEDGER_SCENE: PackedScene = preload("res://ui/console/resource_ledger.tscn")
const INSPECTOR_SCENE: PackedScene = preload("res://ui/inspector/inspector_panel.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://ui/game_over_screen.tscn")

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
	_setup_build_cursor_hint()
	_setup_modes()
	# Bound after registration so the console renders every button's real state
	# from the first frame rather than one refresh later. (`registry_changed` makes
	# the order safe either way; this only saves a repaint.)
	console.bind(mode_manager)
	console.bind_overlay(overlay_controller)
	mode_manager.mode_changed.connect(_on_mode_changed)
	_setup_right_column()
	_setup_inspector_ui()
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
	mode_manager.register(ModeManager.Mode.STORES, _make_stores_panel)
	mode_manager.register(ModeManager.Mode.TRADE, _make_trade_panel)
	mode_manager.register(ModeManager.Mode.RND, _make_research_panel)
	mode_manager.register(ModeManager.Mode.COMMS, _make_comms_panel)
	mode_manager.register(ModeManager.Mode.OVERLAY, overlay_controller.panel)
	mode_manager.register(ModeManager.Mode.AIDE, _make_aide_panel)

## The Build panel's menu body, or null before BUILD has ever been opened - it is
## built by a lazy factory like every other panel. A caller that needs a row out
## of it (the coach mark, WI-63) therefore has to tolerate null, which is exactly
## rule 3 of [TutorialCoach]: a target that is not on screen resolves to nothing.
func build_menu() -> BuildMenu:
	return _build_menu

## BUILD: the rail + flyout (WI-43, reframed in WI-54). The panel carries **no**
## content padding: the menu's search block runs full-bleed with its own rule
## under it, which a padded content region would inset by sixteen pixels and
## leave floating.
func _make_build_panel() -> Control:
	var panel: ConsolePanel = ConsolePanel.create()
	panel.title = "Build"
	panel.panel_width = UIMetrics.PANEL_BUILD_WIDTH
	panel.content_padding = 0
	panel.hotkey = ModeManager.hotkey_label(ModeManager.Mode.BUILD)
	# Build's own standing instruction (WI-58). WI-54 §1 and its deviation 5 both
	# say every panel carries one, and WI-57's audit believed R&D was the last one
	# missing - but only Build's *flyout* had a footer, and Build opens with the
	# flyout closed, so the ninth panel opened with none at all.
	# `show_details` (Tab by default) is the third bound hotkey the HUD never
	# printed anywhere. Read from the live InputMap so a rebind follows.
	panel.footer_text = "Pick a category, then a module · %s holds the station's labels open" % (
		ModeManager.action_hotkey_label(&"show_details"))
	panel.footer_variation = UIType.BODY
	_build_menu = BUILD_MENU_SCENE.instantiate() as BuildMenu
	_build_menu.flyout_anchor = panel
	panel.content().add_child(_build_menu)
	return panel

## CREW: the station roster at 660px, with the job board as its second view
## (WI-56). It builds its own frame, so this is one call.
func _make_crew_panel() -> Control:
	return CrewPanel.create()

## AIDE: SAI's archive at 620px (WI-63), and the end of the disabled stub WI-50
## left in the console.
func _make_aide_panel() -> Control:
	return AidePanel.create()

## STORES: every module holding stock, its haul priority and its contents, at
## 1080px (WI-56).
func _make_stores_panel() -> Control:
	return StoresPanel.create()

## TRADE: the order sheet, the docked confirmation and the contracts board, merged
## into one 1180px panel (WI-55). It builds its own frame, so this is one call.
func _make_trade_panel() -> Control:
	return TradePanel.create()

## R&D: the tech tree at 1400px, one tab per tree (WI-55).
func _make_research_panel() -> Control:
	return UnlockPanel.create()

## COMMS: transmissions and the ARC relationship at 620px, with the quota and the
## books as its other two tabs (WI-57). The last mode to get a real panel.
func _make_comms_panel() -> Control:
	return CommsPanel.create()

func _on_sys_pressed() -> void:
	if pause_menu != null:
		pause_menu.toggle()

## Some panels mean to own the whole screen - the mockup hides the inspector
## behind Trade and R&D on the grounds that selection means nothing there.
##
## That is a **per-panel declaration**, never a list of special cases here: a
## panel that wants it exposes a `hides_inspector` property - which since WI-55 is
## [member ConsolePanel.hides_inspector], set by Trade and R&D - read duck-typed
## exactly the way [ModeManager] finds `on_opened` / `on_closed`. A panel that
## declares nothing leaves the inspector alone, which is the right default for the
## five narrow modes.
func _on_mode_changed(new_mode: ModeManager.Mode, _previous: ModeManager.Mode) -> void:
	var panel: Control = null
	if new_mode != ModeManager.Mode.NONE:
		panel = mode_manager.panel_for(new_mode)
	# `get()` on an undeclared property returns null, and `bool(null)` is not a
	# thing GDScript will build - so the presence test has to be the type check,
	# not a cast.
	var declared: Variant = panel.get(&"hides_inspector") if panel != null else null
	_mode_hides_inspector = declared is bool and bool(declared)
	_sync_inspector_visibility()

## Whether the open mode has claimed the whole screen - one of the two inputs to
## [method _sync_inspector_visibility].
var _mode_hides_inspector: bool = false

## The inspector's one visibility rule, with both of its inputs in one place:
## something is selected, and the open mode has not claimed the screen.
##
## Nothing selected is **no inspector at all** (2026-09-13). WI-51 kept a
## nothing-selected line so the bottom-right would teach the player where
## selection lives; in play it was a permanent box that said nothing. The panel
## never sets its own `visible` - two writers (this and `hides_inspector`) would
## each undo the other.
func _sync_inspector_visibility() -> void:
	if inspector == null or not is_instance_valid(inspector):
		return
	inspector.visible = inspector.has_selection() and not _mode_hides_inspector

## Station overlays (WI-35): a self-contained UI-side controller that owns the
## overlay tint, the digit hotkeys, and the logistics flow layer. Its panel is
## the OVERLAY mode; the tint deliberately outlives that panel, which is what the
## console button's cyan bar reports.
func _setup_overlay_ui() -> void:
	overlay_controller = OverlayController.new()
	add_child(overlay_controller)

## The held module's attached label (WI-54). Mounted here rather than by the
## Build panel because closing Build while holding a module deliberately keeps
## the ghost - so its instruction has to outlive the panel that started it. It
## follows the cursor, ignores the mouse, and is invisible unless something is
## actually held.
var _build_cursor_hint: BuildCursorHint

func _setup_build_cursor_hint() -> void:
	_build_cursor_hint = BUILD_CURSOR_HINT_SCENE.instantiate() as BuildCursorHint
	add_child(_build_cursor_hint)

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
	# WI-55 removed the fourth level here. The trader screen was a modal that
	# paused the sim and therefore outranked a mode; folded into the Trade panel it
	# *is* a mode, and its docked pause is a named hold that the panel releases on
	# close - so Esc closing the mode releases it, with no separate claim.
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
	# The map's height and its fold hotkey, from code rather than from the scene
	# (WI-58). `content_height = 206` was authored in `minimap.tscn` as a hand-typed
	# restatement of this subtraction, which left STATION_MAP_HEIGHT with no runtime
	# consumer at all; and `toggle_map` was bound, documented in WI-49 as a
	# readout-header action, and printed nowhere.
	_map_readout.content_height = UIMetrics.STATION_MAP_HEIGHT - UIMetrics.READOUT_HEADER_HEIGHT
	# The station's name is the map's header (WI-59) - the readout sits at the top
	# of the right column, so it is the one piece of permanent HUD furniture the
	# name can own. `minimap.tscn`'s authored "Station Map" stays as the label for
	# a nameless save; ReadoutPanel upper-cases whatever it is given.
	_map_readout.label = Global.station_display_name()
	_map_readout.add_action(_hotkey_hint(&"toggle_map"))
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

## The hotkey chip a readout header carries. Read from the live [InputMap] through
## the same helper the console's mode buttons use, so a rebind follows.
func _hotkey_hint(action: StringName) -> Label:
	var hint := Label.new()
	hint.name = "Hotkey"
	hint.theme_type_variation = UIType.HOTKEY
	hint.text = ModeManager.action_hotkey_label(action)
	hint.add_theme_color_override("font_color", UIPalette.TEXT_META)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.visible = not hint.text.is_empty()
	return hint

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
	# The feed's cap depends on whether the raid readout is currently stacked above
	# it, so it is handed in before the stack is measured rather than baked into a
	# constant (WI-58). The feed is the tenant that yields: it has a `+ n more` row
	# and a history flyout to overflow into, and the inspector below it has
	# nowhere - which is how a raid plus a full feed used to leave the selection
	# surface with a zero-height content region.
	if _alert_feed != null and is_instance_valid(_alert_feed):
		var raid_up: bool = (_raid_readout != null and is_instance_valid(_raid_readout)
			and _raid_readout.visible)
		_alert_feed.height_budget = UIMetrics.alert_feed_max_height(raid_up)
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

# --- conversations (WI-62) ------------------------------------------------------
#
# There is no mount call here, and that is the point. [DialogueRunner] builds a
# [DialogueBalloon] when something has to be said and adds it to this node - so a
# conversation lands above the mode panels and below the pause menu, in the slot
# the WI-13 event card used to occupy, without the HUD having to know when one is
# coming. The runner is also the only thing allowed to do it.
#
# The balloon is deliberately **not** on the Esc ladder below: a conversation is
# something you answer, and an Esc that dismisses it is an answer given without
# being read. Same considered exception as an outstanding critical alert.

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
	_sync_feed_to_selection()
	_sync_inspector_visibility()

## Selection brackets follow the inspector rather than the panels. Module
## brackets are driven by `ModuleBase.selected`, which the module and turboshaft
## tab sets raise and drop; the pawn brackets have no such flag, so they are
## pointed from here. Selecting anything that is not a pawn clears them, which is
## what "only one thing is selected" means on screen.
func _on_selection_changed(selection_kind: InspectorPanel.SelectionKind) -> void:
	_sync_feed_to_selection()
	_sync_inspector_visibility()
	if Global.ui_in_game == null:
		return
	var pawn: PawnBase = null
	if selection_kind == InspectorPanel.SelectionKind.CREW:
		pawn = inspector.selected_subject() as PawnBase
	Global.ui_in_game.set_selected_pawn(pawn)

## The feed collapses to one row while something is selected, so the inspector
## gets the column instead of reading through its 220px floor. The feed's own
## `minimum_size_changed` re-stacks the column too; queueing here as well means
## the inspector's new `top_limit` never waits on whether the fit changed size.
func _sync_feed_to_selection() -> void:
	if _alert_feed == null or not is_instance_valid(_alert_feed) or inspector == null:
		return
	_alert_feed.compact = inspector.has_selection()
	_queue_column_layout()

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
