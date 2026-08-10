class_name OverlayController
extends Control

## WI-35 station overlays. A UI-side (pure view) controller owned by UIMain:
## while a mode is active it writes each visible module's OVERLAY_COLOR shader
## param so the whole station reads one system at a time - power, O2, integrity,
## vibration, or logistics. NOT a game manager: it never mutates sim state, only
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
## reports. So the digit hotkeys moved off the buttons' [Shortcut]s (which only
## fire while their button is visible) and into this node's `_unhandled_input`,
## where they keep working with the panel shut - the stated design.

enum Mode { NONE, POWER, O2, INTEGRITY, VIBRATION, LOGISTICS }

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

## Overlay hotkeys, in panel order: the digit each is bound to by default, and
## the mode it paints. Real input actions rather than raw keycodes (program
## decision 9), so WI-36's remapper lists them, a rebind is possible, and a key
## bound to something else later cannot be silently swallowed here.
const HOTKEY_ACTIONS: Dictionary[StringName, Mode] = {
	&"overlay_clear": Mode.NONE,
	&"overlay_power": Mode.POWER,
	&"overlay_o2": Mode.O2,
	&"overlay_integrity": Mode.INTEGRITY,
	&"overlay_vibration": Mode.VIBRATION,
	&"overlay_logistics": Mode.LOGISTICS,
}

var _mode: Mode = Mode.NONE
var _flow_layer: OverlayFlowLayer
## Currently-breached modules, refreshed on each full pass; only these are
## touched by the per-frame pulse so the animation stays O(breaches), not O(all).
var _pulse_modules: Array[ModuleBase] = []
var _pulse_time: float = 0.0

var _button_group := ButtonGroup.new()
var _legend: Label
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

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	_panel.content().add_child(column)

	var modes := VBoxContainer.new()
	modes.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	modes.add_child(SectionLabel.create("Station view"))
	_button_group.allow_unpress = true
	# Order + hotkeys: 1..5 down the panel, 0 clears. The printed key comes from
	# the live InputMap, so a rebind shows up on the button.
	_add_mode_button(modes, Mode.POWER, "Power", &"overlay_power")
	_add_mode_button(modes, Mode.O2, "O₂", &"overlay_o2")
	_add_mode_button(modes, Mode.INTEGRITY, "Integrity", &"overlay_integrity")
	_add_mode_button(modes, Mode.VIBRATION, "Vibration", &"overlay_vibration")
	_add_mode_button(modes, Mode.LOGISTICS, "Logistics", &"overlay_logistics")
	column.add_child(modes)

	_legend = Label.new()
	_legend.theme_type_variation = UIType.META_LINE
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_legend)

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
	_sync_buttons()
	return _panel

func _add_mode_button(parent: Node, mode: Mode, label: String, action: StringName) -> void:
	var key: String = ModeManager.action_hotkey_label(action)
	var button: ActionButton = ActionButton.create("%s   %s" % [key, label])
	button.toggle_mode = true
	button.button_group = _button_group
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.tooltip_text = "%s overlay (%s)" % [label, key]
	button.set_meta("overlay_mode", mode)
	# Reconcile after the toggle settles: with a radio ButtonGroup, switching
	# fires the old button's toggled(false) and the new one's toggled(true) in an
	# order we don't want to depend on, so we read the group's pressed button once
	# the dust settles rather than reacting to each edge.
	button.toggled.connect(func(_on: bool) -> void: _reconcile_mode.call_deferred())
	parent.add_child(button)

func _on_corridor_display_toggled(toggled_on: bool) -> void:
	if Global.world_manager == null:
		return
	Global.world_manager.show_module_layer(
		WorldManager.StructureLayer.CORRIDOR if toggled_on else WorldManager.StructureLayer.MODULE)

## The overlay hotkeys live here rather than on the buttons because a [Shortcut]
## only fires while its button is visible in the tree, and the whole point of the
## overlay is that it survives its panel being closed.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if ModeManager.text_entry_has_focus(get_viewport()):
		return
	for action: StringName in HOTKEY_ACTIONS:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			set_mode(HOTKEY_ACTIONS[action])
			return

## Esc clears an active overlay, but the decision isn't made here: UIMain ranks
## every Esc claimant in one place (WI-36) and calls set_mode(NONE) when the
## overlay is the topmost one. Handling it locally would have let an active
## overlay outrank a held build preview purely by input-propagation order.
func has_active_mode() -> bool:
	return _mode != Mode.NONE

func _reconcile_mode() -> void:
	var pressed: BaseButton = _button_group.get_pressed_button()
	var new_mode: Mode = Mode.NONE
	if pressed != null and pressed.has_meta("overlay_mode"):
		new_mode = pressed.get_meta("overlay_mode")
	set_mode(new_mode)

## Keep the toolbar's pressed state honest when the mode is set programmatically
## (Esc, a future hotkey path). set_pressed_no_signal avoids re-entering the
## toggled -> reconcile loop.
func _sync_buttons() -> void:
	for button: Button in _button_group.get_buttons():
		var is_mine: bool = button.has_meta("overlay_mode") and button.get_meta("overlay_mode") == _mode
		button.set_pressed_no_signal(is_mine)

# --- mode lifecycle -----------------------------------------------------------

func set_mode(new_mode: Mode) -> void:
	if new_mode == _mode:
		return
	_deactivate()
	_mode = new_mode
	_activate()
	_sync_buttons()
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
## magnitude across its storage components - a construction site's +99 outweighs
## an idle bin). Non-storage modules stay untinted; the flow layer carries the
## arrows and the numeric labels on top.
func _logistics_color(module: ModuleBase) -> Color:
	var best_priority: int = 0
	var found: bool = false
	for component: ComponentBase in module.components:
		if component is StorageComponent:
			var storage: StorageComponent = component as StorageComponent
			if not found or absi(storage.priority) > absi(best_priority):
				best_priority = storage.priority
				found = true
	if not found:
		return OverlayPalette.untinted()
	return OverlayPalette.logistics_color(best_priority)

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
	if Global.world_manager == null or Global.world_manager.pawn_layer == null:
		return
	_flow_layer = OverlayFlowLayer.new()
	_flow_layer.visible = false
	# Parented into the world-following SPACE canvas (above the module layer) so
	# it draws in world coordinates on top of the station, not on the HUD.
	Global.world_manager.pawn_layer.add_child(_flow_layer)

func _refresh_legend() -> void:
	if _legend == null:
		return
	_legend.text = _legend_text()

func _legend_text() -> String:
	match _mode:
		Mode.POWER:
			return "  green = powered · red = no power"
		Mode.O2:
			return "  green = breathable · red = suffocating · pulsing = breach"
		Mode.INTEGRITY:
			return "  green = full HP · red = critical · orange = wreckage"
		Mode.VIBRATION:
			return "  clear = quiet · red = high vibration"
		Mode.LOGISTICS:
			return "  warm = sinks · cool = sources · arrows = active hauls"
	return "  Overlays: pick a mode (1-5), Esc to clear"
