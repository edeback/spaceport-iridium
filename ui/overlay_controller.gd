class_name OverlayController
extends Control

## WI-35 station overlays. A UI-side (pure view) controller owned by UIMain:
## while a mode is active it writes each visible module's OVERLAY_COLOR shader
## param so the whole station reads one system at a time - power, O2, integrity,
## vibration, logistics, or heat. NOT a game manager: it never mutates sim state, only
## tints. All state is session-only (never saved); a scene reload starts every
## mode off, and fresh module instances default to an alpha-0 (untinted) param.
##
## Value->color lives in the pure OverlayPalette; this class owns the mode
## lifecycle, the per-module iteration, the signal wiring, and (logistics) the
## OverlayFlowLayer that draws arrows/labels on top of the world.
##
## WI-50 turned the free-floating toolbar strip into the OVERLAY console panel.
## The overlay itself is deliberately **not** a mode panel: the tint outlives the
## panel that switched it on, which is exactly what the console button's cyan bar
## reports. So the hotkeys moved off the buttons' [Shortcut]s (which only fire
## while their button is visible) and into this node's `_unhandled_input`, where
## they keep working with the panel shut - the stated design.
##
## WI-54 gave the panel its final body: six [ListRow]s that print their own
## hotkey, and a legend for the active mode only. The legend swatches are
## produced by [OverlayPalette]'s own mode functions rather than named here, so
## the square beside "breathable" is the tint a breathable module actually gets.
##
## The keys are Shift+1…6 with Shift+0 clearing (2026-09-15) - the bare digits
## went to the time speeds - and a key **toggles**: pressing the painted
## overlay's own key again clears it, so Shift+0 is a way back rather than the
## only one. Its row does the same ([method toggled_mode]).

enum Mode { NONE, POWER, O2, INTEGRITY, VIBRATION, LOGISTICS, HEAT }

## Fires whenever the painted overlay changes, so the console can light or clear
## the OVERLAY button's bar. The mode registry is no use for this: the bar means
## "live even though the panel is closed".
signal overlay_mode_changed(mode: Mode)

## Field level treated as "full red" in vibration mode. A single forge's nearest
## structural neighbour sits near 0.5 (intensity 1.0 * falloff 0.5); a module
## boxed in by several industrial emitters climbs toward this. Exported so the
## calibration lives as tunable data, not a buried constant.
@export var vibration_high_ref: float = 1.5

## Breach pulse (O2 mode): breached modules oscillate their tint strength to pull
## the eye. Driven off the real UI clock, so it animates even while paused.
const PULSE_HZ: float = 2.2
const PULSE_MIN_A: float = 0.4
const PULSE_MAX_A: float = 0.95

## Overlay hotkeys, in panel order: Shift plus the digit each is bound to by
## default, and the mode it paints. Real input actions rather than raw keycodes (program
## decision 9), so WI-36's remapper lists them, a rebind is possible, and a key
## bound to something else later cannot be silently swallowed here.
const HOTKEY_ACTIONS: Dictionary[StringName, Mode] = {
	&"overlay_clear": Mode.NONE,
	&"overlay_power": Mode.POWER,
	&"overlay_o2": Mode.O2,
	&"overlay_integrity": Mode.INTEGRITY,
	&"overlay_vibration": Mode.VIBRATION,
	&"overlay_logistics": Mode.LOGISTICS,
	&"overlay_heat": Mode.HEAT,
}

## Mode -> the pure key [OverlayPalette] tables its legend under. Two spellings
## of the same identity, but the pure side must not reach into a [Control] for an
## enum, and the enum must not become a string the sim could persist.
const LEGEND_KEYS: Dictionary[Mode, StringName] = {
	Mode.POWER: OverlayPalette.MODE_POWER,
	Mode.O2: OverlayPalette.MODE_O2,
	Mode.INTEGRITY: OverlayPalette.MODE_INTEGRITY,
	Mode.VIBRATION: OverlayPalette.MODE_VIBRATION,
	Mode.LOGISTICS: OverlayPalette.MODE_LOGISTICS,
	Mode.HEAT: OverlayPalette.MODE_HEAT,
}

## The panel's standing instruction. The one thing about this panel a player has
## to be told, because it is the one thing that does not behave like every other
## mode: closing it does not undo it.
const FOOTER_LINE: String = "The chosen overlay keeps painting the station after this panel closes."

## Side of a legend swatch. Matches the design's 12px chip square.
const LEGEND_SWATCH: int = 12

var _mode: Mode = Mode.NONE
var _flow_layer: OverlayFlowLayer
## Currently-breached modules, refreshed on each full pass; only these are
## touched by the per-frame pulse so the animation stays O(breaches), not O(all).
var _pulse_modules: Array[ModuleBase] = []
var _pulse_time: float = 0.0

## Mode -> its row, so a mode set from a hotkey (or from Esc) can repaint the
## list without the rows having to watch anything. NONE has a row too - the
## "Clear overlay" line is a real entry, not a footnote.
var _rows: Dictionary[Mode, ListRow] = {}
var _legend_section: VBoxContainer
var _legend_rows: VBoxContainer
var _legend_note: Label
var _panel: ConsolePanel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_build_flow_layer()

# --- the OVERLAY panel --------------------------------------------------------

## The mode registry's factory. Built on first open and cached there, and left
## unparented so the manager mounts it on the panel layer - a panel parented to
## this zero-content controller would have nothing to take its height from.
func panel() -> ConsolePanel:
	if _panel != null and is_instance_valid(_panel):
		return _panel
	_panel = ConsolePanel.create()
	_panel.title = "Overlays"
	_panel.panel_width = UIMetrics.PANEL_OVERLAYS_WIDTH
	_panel.content_padding = UIMetrics.CONTENT_PAD
	_panel.hotkey = ModeManager.hotkey_label(ModeManager.Mode.OVERLAY)
	# The footer is the frame's, not a last row of the list: it is a property of
	# the panel (this mode outlives its panel) rather than of what is scrolled
	# into view inside it.
	_panel.footer_text = FOOTER_LINE
	_panel.footer_variation = UIType.BODY

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.content().add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	scroll.add_child(column)

	var modes := VBoxContainer.new()
	modes.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	# Order + hotkeys: Shift+1..6 down the panel, Shift+0 clears. The printed key
	# comes from the live InputMap, so a rebind shows up on the row.
	_add_mode_row(modes, Mode.POWER, "Power", &"overlay_power")
	_add_mode_row(modes, Mode.O2, "Oxygen", &"overlay_o2")
	_add_mode_row(modes, Mode.INTEGRITY, "Integrity", &"overlay_integrity")
	_add_mode_row(modes, Mode.VIBRATION, "Vibration", &"overlay_vibration")
	_add_mode_row(modes, Mode.LOGISTICS, "Logistics", &"overlay_logistics")
	_add_mode_row(modes, Mode.HEAT, "Heat", &"overlay_heat")
	# Clear is the same kind of thing as picking one - it is how you get back to
	# no overlay with the mouse - so it is a row in the same list rather than a
	# button somewhere else. It never takes the live treatment: "no overlay" is
	# the absence of a state, not a state.
	_add_mode_row(modes, Mode.NONE, "Clear overlay", &"overlay_clear")
	column.add_child(modes)

	# The legend for the ACTIVE mode only. Five ramps will not fit in 360px, and
	# four of them would be explaining something the station is not showing.
	_legend_section = VBoxContainer.new()
	_legend_section.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_legend_section.add_child(SectionLabel.create("Legend"))
	_legend_rows = VBoxContainer.new()
	_legend_rows.add_theme_constant_override("separation", 4)
	_legend_section.add_child(_legend_rows)
	_legend_note = Label.new()
	_legend_note.theme_type_variation = UIType.BODY
	_legend_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend_note.add_theme_color_override("font_color", UIPalette.TEXT_META)
	_legend_section.add_child(_legend_note)
	column.add_child(_legend_section)

	# The corridor-display toggle is a real feature the console design has no slot
	# for, and it is the same category of thing as an overlay - a way of looking at
	# the station - so it lands here rather than being dropped with the left column
	# it used to live in.
	var extras := VBoxContainer.new()
	extras.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	extras.add_child(SectionLabel.create("Display"))
	var corridors := CheckBox.new()
	corridors.text = "Display corridors"
	corridors.button_pressed = true
	corridors.focus_mode = Control.FOCUS_NONE
	corridors.toggled.connect(_on_corridor_display_toggled)
	extras.add_child(corridors)
	column.add_child(extras)

	_refresh_legend()
	_sync_rows()
	return _panel

## One overlay row: the mode's name, its number key right-aligned, and the live
## treatment while it is the painted mode.
func _add_mode_row(parent: Node, mode: Mode, label: String, action: StringName) -> void:
	var key: String = ModeManager.action_hotkey_label(action)
	var row: ListRow = ListRow.create()
	row.configure(label, "", key)
	row.tooltip_text = "%s (%s)" % [label, key] if key != "" else label
	# A plain press, not a toggle button: the mode is owned by this controller (the
	# hotkeys set it with the panel shut), so the rows report it rather than
	# holding it. A radio ButtonGroup would have been a second source of truth.
	# The press still toggles the *mode*, exactly as the row's key does.
	row.pressed.connect(toggle_mode.bind(mode))
	parent.add_child(row)
	_rows[mode] = row

func _on_corridor_display_toggled(toggled_on: bool) -> void:
	if Global.world_manager == null:
		return
	Global.world_manager.show_module_layer(
		WorldManager.StructureLayer.CORRIDOR if toggled_on else WorldManager.StructureLayer.MODULE)

## The overlay hotkeys live here rather than on the buttons because a [Shortcut]
## only fires while its button is visible in the tree, and the whole point of the
## overlay is that it survives its panel being closed.
##
## Matched exactly ([method ModeManager.hotkey_pressed]): the bare digits are the
## time speeds, and Godot's default match would fire both on every Shift+digit.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if ModeManager.text_entry_has_focus(get_viewport()):
		return
	for action: StringName in HOTKEY_ACTIONS:
		if ModeManager.hotkey_pressed(event, action):
			get_viewport().set_input_as_handled()
			toggle_mode(HOTKEY_ACTIONS[action])
			return

## What pressing `pressed`'s key or row does while `current` is painted: the
## painted overlay's own key clears it, any other key switches to its overlay,
## and the clear key clears. Static and pure so the rule is tested without a
## station to tint.
static func toggled_mode(current: Mode, pressed: Mode) -> Mode:
	return Mode.NONE if pressed == current else pressed

func toggle_mode(pressed: Mode) -> void:
	set_mode(toggled_mode(_mode, pressed))

## Esc clears an active overlay, but the decision isn't made here: UIMain ranks
## every Esc claimant in one place (WI-36) and calls set_mode(NONE) when the
## overlay is the topmost one. Handling it locally would have let an active
## overlay outrank a held build preview purely by input-propagation order.
func has_active_mode() -> bool:
	return _mode != Mode.NONE

## Keeps the row list honest when the mode is set from anywhere but a click - a
## hotkey with the panel shut, Esc, Shift+0. The rows hold no state of their own,
## so this is a repaint rather than a reconciliation.
func _sync_rows() -> void:
	for mode: Mode in _rows:
		var row: ListRow = _rows[mode]
		if not is_instance_valid(row):
			continue
		var live: bool = mode == _mode and mode != Mode.NONE
		row.set_kind(UIPalette.Row.LIVE if live else UIPalette.Row.INERT)

# --- mode lifecycle -----------------------------------------------------------

func set_mode(new_mode: Mode) -> void:
	if new_mode == _mode:
		return
	_deactivate()
	_mode = new_mode
	_activate()
	_sync_rows()
	_refresh_legend()
	overlay_mode_changed.emit(_mode)

func _activate() -> void:
	if _mode == Mode.NONE:
		return
	_setup_signals()
	if _mode == Mode.LOGISTICS and _flow_layer != null:
		_flow_layer.visible = true
	refresh_all()
	set_process(_mode == Mode.O2)
	_pulse_time = 0.0

func _deactivate() -> void:
	_teardown_signals()
	set_process(false)
	_pulse_modules.clear()
	if _flow_layer != null:
		_flow_layer.visible = false
	_clear_all_tints()

# --- signal wiring ------------------------------------------------------------

func _setup_signals() -> void:
	if Global.time_manager != null:
		_connect(Global.time_manager.slow_tick, _on_slow_tick)
	_connect(SignalBus.module_added, _on_module_added)
	match _mode:
		Mode.O2:
			_connect(SignalBus.module_breach_started, _on_breach_changed)
			_connect(SignalBus.module_breach_sealed, _on_breach_changed)
		Mode.INTEGRITY:
			_connect(SignalBus.module_damaged, _on_module_hp_changed)
			_connect(SignalBus.module_repaired, _on_module_hp_changed)
		Mode.VIBRATION:
			if Global.adjacency_manager != null:
				_connect(Global.adjacency_manager.fields_changed, _on_field_changed)
		Mode.HEAT:
			# One repaint per exchange pass, not per module: every module's
			# temperature moves on every pass, so a per-module signal would be a
			# few hundred refreshes describing one frame's worth of change.
			if Global.heat_manager != null:
				_connect(Global.heat_manager.heat_pass_completed, refresh_all)

func _teardown_signals() -> void:
	if Global.time_manager != null:
		_disconnect(Global.time_manager.slow_tick, _on_slow_tick)
	_disconnect(SignalBus.module_added, _on_module_added)
	_disconnect(SignalBus.module_breach_started, _on_breach_changed)
	_disconnect(SignalBus.module_breach_sealed, _on_breach_changed)
	_disconnect(SignalBus.module_damaged, _on_module_hp_changed)
	_disconnect(SignalBus.module_repaired, _on_module_hp_changed)
	if Global.adjacency_manager != null:
		_disconnect(Global.adjacency_manager.fields_changed, _on_field_changed)
	if Global.heat_manager != null:
		_disconnect(Global.heat_manager.heat_pass_completed, refresh_all)

func _connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)

func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)

# --- signal handlers ----------------------------------------------------------

func _on_slow_tick(_interval: float) -> void:
	refresh_all()

func _on_module_added(module: ModuleBase) -> void:
	# A module built while a mode is live gets tinted immediately rather than
	# waiting for the next full pass.
	_refresh_one(module)

func _on_breach_changed(_module: ModuleBase) -> void:
	# A breach opening/sealing changes which modules pulse; a full pass rebuilds
	# the pulse set. Breaches are rare, so the pass cost is a non-issue.
	refresh_all()

func _on_module_hp_changed(module: ModuleBase, _amount: float) -> void:
	_refresh_one(module)

func _on_field_changed(module: ModuleBase) -> void:
	_refresh_one(module)

# --- tinting ------------------------------------------------------------------

## Re-tint every placed module for the active mode. One cheap pass over the
## deduped module list (values already cached by their own systems); also
## rebuilds the O2 pulse set and refreshes the logistics flow overlay.
func refresh_all() -> void:
	var world: WorldManager = Global.world_manager
	if world == null:
		return
	_pulse_modules.clear()
	for module: ModuleBase in world.id_to_module.values():
		if not is_instance_valid(module):
			continue
		module.set_overlay_color(_color_for(module))
		if _mode == Mode.O2 and _is_breached(module):
			_pulse_modules.append(module)
	if _mode == Mode.LOGISTICS and _flow_layer != null:
		_flow_layer.queue_redraw()

func _refresh_one(module: ModuleBase) -> void:
	if _mode == Mode.NONE or not is_instance_valid(module):
		return
	module.set_overlay_color(_color_for(module))
	if _mode == Mode.LOGISTICS and _flow_layer != null:
		_flow_layer.queue_redraw()

func _clear_all_tints() -> void:
	var world: WorldManager = Global.world_manager
	if world == null:
		return
	for module: ModuleBase in world.id_to_module.values():
		if is_instance_valid(module):
			module.set_overlay_color(OverlayPalette.untinted())

## The overlay color for one module under the active mode. Returns untinted for
## anything the mode has nothing to say about (a passive module in Power, a
## vacuum module in O2, a non-storage module in Logistics, ...).
func _color_for(module: ModuleBase) -> Color:
	match _mode:
		Mode.POWER:
			return _power_color(module)
		Mode.O2:
			return _o2_color(module)
		Mode.INTEGRITY:
			return _integrity_color(module)
		Mode.VIBRATION:
			return _vibration_color(module)
		Mode.LOGISTICS:
			return _logistics_color(module)
		Mode.HEAT:
			return _heat_color(module)
	return OverlayPalette.untinted()

func _power_color(module: ModuleBase) -> Color:
	if not module.is_complete():
		return OverlayPalette.untinted()
	var gen: PowerGenerationComponent = module.get_component_by_type(PowerGenerationComponent) as PowerGenerationComponent
	if gen != null:
		return OverlayPalette.power_color(gen.powered)
	var cons: PowerConsumptionComponent = module.get_component_by_type(PowerConsumptionComponent) as PowerConsumptionComponent
	if cons != null:
		return OverlayPalette.power_color(cons.powered)
	return OverlayPalette.untinted()

func _o2_color(module: ModuleBase) -> Color:
	var atmo: AtmosphereComponent = module.get_atmosphere()
	if atmo == null:
		return OverlayPalette.untinted()
	return OverlayPalette.o2_color(atmo.o2_partial())

func _integrity_color(module: ModuleBase) -> Color:
	if not module.is_complete():
		return OverlayPalette.untinted()
	var is_truss: bool = Global.world_manager != null and module.module_data == Global.world_manager.replacement_module
	return OverlayPalette.integrity_color(module.hp_fraction(), is_truss)

func _vibration_color(module: ModuleBase) -> Color:
	if Global.adjacency_manager == null:
		return OverlayPalette.untinted()
	var field: float = Global.adjacency_manager.get_field(module, &"vibration")
	return OverlayPalette.vibration_color(field, vibration_high_ref)

## Tint a storage module by its most salient routing priority (largest
## Non-storage modules stay untinted; the flow layer carries the arrows and the
## numeric labels on top.
##
## This used to pick the largest-MAGNITUDE priority across a module's storage
## components, because a refinery had two of them and they disagreed. WI-65 made
## that a module-level fact - one bin, one number - so the collapse is gone. A
## deconstruction site can still grow a second bin, hence the loop rather than a
## single lookup, and the first storage the walk finds wins.
func _logistics_color(module: ModuleBase) -> Color:
	for component: ComponentBase in module.components:
		var storage: StorageComponent = component as StorageComponent
		# lists() skips the dead construction bin every built module still carries
		# at +100; routing_priority() reads an export-only bin at the floor it
		# actually ships at rather than its unused `priority` field.
		if storage != null and StoresModel.lists(storage):
			return OverlayPalette.logistics_color(StoresModel.routing_priority(storage))
	return OverlayPalette.untinted()

## Every placed module has a thermal body, so unlike the other modes this one has
## something to say about all of them - truss included, which is exactly where a
## lot of the station's heat is going.
func _heat_color(module: ModuleBase) -> Color:
	if Global.heat_manager == null:
		return OverlayPalette.untinted()
	var component: HeatComponent = Global.heat_manager.get_component(module)
	if component == null:
		# A blueprint or a teardown site: no thermal body, nothing to report.
		return OverlayPalette.untinted()
	return OverlayPalette.heat_color(component.temperature_f)

func _is_breached(module: ModuleBase) -> bool:
	var atmo: AtmosphereComponent = module.get_atmosphere()
	return atmo != null and atmo.is_breached()

# --- breach pulse (O2) --------------------------------------------------------

func _process(delta: float) -> void:
	if _mode != Mode.O2 or _pulse_modules.is_empty():
		return
	_pulse_time += delta
	var phase: float = 0.5 + 0.5 * sin(_pulse_time * TAU * PULSE_HZ)
	var strength: float = lerpf(PULSE_MIN_A, PULSE_MAX_A, phase)
	for module: ModuleBase in _pulse_modules:
		if not is_instance_valid(module):
			continue
		var base: Color = _o2_color(module)
		base.a = strength
		module.set_overlay_color(base)

# --- flow layer + legend ------------------------------------------------------

func _build_flow_layer() -> void:
	if Global.world_manager == null:
		return
	# The world-following SPACE canvas (above the module layer), so the layer
	# draws in world coordinates on top of the station, not on the HUD.
	var space: CanvasLayer = Global.world_manager.get_canvas_for_layer(
			WorldManager.StructureLayer.SPACE)
	if space == null:
		return
	_flow_layer = OverlayFlowLayer.new()
	_flow_layer.visible = false
	space.add_child(_flow_layer)

## Rebuilds the legend for whatever is painted now. The whole section disappears
## with the overlay rather than showing an empty ramp: with nothing painted there
## is nothing to decode, and a legend for a mode the player is not in is four
## rows of noise in the narrowest panel in the game.
func _refresh_legend() -> void:
	if _legend_rows == null or not is_instance_valid(_legend_rows):
		return
	for child: Node in _legend_rows.get_children():
		_legend_rows.remove_child(child)
		child.queue_free()
	var key: StringName = LEGEND_KEYS.get(_mode, &"")
	var stops: Array[OverlayPalette.LegendStop] = OverlayPalette.legend_stops(key)
	_legend_section.visible = not stops.is_empty()
	for stop: OverlayPalette.LegendStop in stops:
		_legend_rows.add_child(_make_legend_row(stop))
	var note: String = OverlayPalette.legend_note(key)
	_legend_note.text = note
	_legend_note.visible = not note.is_empty()

func _make_legend_row(stop: OverlayPalette.LegendStop) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIMetrics.READOUT_HEADER_GAP)
	var swatch := ColorRect.new()
	swatch.color = stop.color
	swatch.custom_minimum_size = Vector2(float(LEGEND_SWATCH), float(LEGEND_SWATCH))
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var label := Label.new()
	# Caps happens where the label is owned (WI-49 §3), not in the palette - the
	# stop names are data, and data does not know it is being rendered as a meta
	# line.
	label.text = stop.label.to_upper()
	label.theme_type_variation = UIType.META_LINE
	row.add_child(label)
	return row
