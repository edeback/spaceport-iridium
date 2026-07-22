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

enum Mode { NONE, POWER, O2, INTEGRITY, VIBRATION, LOGISTICS }

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

## Toolbar placement: a horizontal strip in the top bar, nudged right of the
## left-hand module column (176px wide) so it clears it.
const TOOLBAR_LEFT: float = 184.0
const TOOLBAR_TOP: float = 8.0

var _mode: Mode = Mode.NONE
var _flow_layer: OverlayFlowLayer
## Currently-breached modules, refreshed on each full pass; only these are
## touched by the per-frame pulse so the animation stays O(breaches), not O(all).
var _pulse_modules: Array[ModuleBase] = []
var _pulse_time: float = 0.0

var _button_group := ButtonGroup.new()
var _legend: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_build_toolbar()
	_build_flow_layer()

# --- toolbar ------------------------------------------------------------------

func _build_toolbar() -> void:
	var strip := HBoxContainer.new()
	strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	strip.offset_left = TOOLBAR_LEFT
	strip.offset_top = TOOLBAR_TOP
	strip.add_theme_constant_override("separation", 4)
	_button_group.allow_unpress = true
	# Order + hotkeys: 1..5 across the strip.
	_add_mode_button(strip, Mode.POWER, "Power", KEY_1)
	_add_mode_button(strip, Mode.O2, "O₂", KEY_2)
	_add_mode_button(strip, Mode.INTEGRITY, "Integrity", KEY_3)
	_add_mode_button(strip, Mode.VIBRATION, "Vibration", KEY_4)
	_add_mode_button(strip, Mode.LOGISTICS, "Logistics", KEY_5)
	_legend = Label.new()
	_legend.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_legend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip.add_child(_legend)
	add_child(strip)
	_refresh_legend()

func _add_mode_button(strip: HBoxContainer, mode: Mode, label: String, keycode: Key) -> void:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _button_group
	button.focus_mode = Control.FOCUS_NONE
	button.text = "%d %s" % [_hotkey_digit(keycode), label]
	button.shortcut = _make_shortcut(keycode)
	button.tooltip_text = "%s overlay (%d)" % [label, _hotkey_digit(keycode)]
	button.set_meta("overlay_mode", mode)
	# Reconcile after the toggle settles: with a radio ButtonGroup, switching
	# fires the old button's toggled(false) and the new one's toggled(true) in an
	# order we don't want to depend on, so we read the group's pressed button once
	# the dust settles rather than reacting to each edge.
	button.toggled.connect(func(_on: bool) -> void: _reconcile_mode.call_deferred())
	strip.add_child(button)

func _hotkey_digit(keycode: Key) -> int:
	return keycode - KEY_0

func _make_shortcut(keycode: Key) -> Shortcut:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	var sc := Shortcut.new()
	sc.events = [ev]
	return sc

## Esc clears an active overlay. Handled in _shortcut_input so a focused text
## field (the save-slot LineEdit) still eats Esc/keys first, and only consumed
## when a mode is actually on, so it never steals Esc from anything else.
func _shortcut_input(event: InputEvent) -> void:
	if _mode == Mode.NONE:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_mode(Mode.NONE)
		accept_event()

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
