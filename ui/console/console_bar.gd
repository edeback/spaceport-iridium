class_name ConsoleBar
extends Control

## The console (WI-50): the 112px strip welded to the bottom edge that replaces
## the three places navigation used to live - `ui_main.tscn`'s left button
## column, the top-left resource strip, and `overlay_controller`'s hardcoded
## toolbar at x=184.
##
## Three zones, separated by 1px EDGE dividers:
##
##   - [b]Modes, 715px, left.[/b] Seven mode buttons at 5px gaps, then a divider,
##     then AIDE and SYS. Built from [constant ModeManager.ORDER] plus [constant
##     ModeManager.TRAILING], so adding a mode never means authoring a button.
##   - [b]Vitals, flex.[/b] Six pinned chips plus the LEDGER control ([VitalsStrip],
##     WI-52). The console builds it; [UIMain] owns the flyout it opens, because
##     a flyout has to sit *above* the console rather than inside it.
##   - [b]Time, 247px, right.[/b] The clock over the cycle line, and the
##     pause/speed row - `ui_time_scale_select.tscn` reparented, not rewritten.
##
## It is opaque and consumes input across its full height, so a click near the
## bottom of the screen can never fall through to the station behind it. The
## mode zone is a fixed 715px pinned left: `aspect="expand"` hands a wider
## display extra width, and that width belongs to the vitals zone and the play
## area, not to stretched buttons.
##
## Adornment state (which dots and bars are lit) is read from the managers on a
## one-second real-time timer plus the handful of signals that move it. Real
## time, not `slow_tick`: the console is chrome and must not scan four times
## faster because the player pressed 4x.

const TIME_SELECT_SCENE: PackedScene = preload("res://ui/ui_time_scale_select.tscn")

## Console glyphs. Authored SVGs rather than `_draw()` shapes - see [ModeButton].
const GLYPHS: Dictionary[ModeManager.Mode, Texture2D] = {
	ModeManager.Mode.BUILD: preload("res://ui/icons/console/build.svg"),
	ModeManager.Mode.CREW: preload("res://ui/icons/console/crew.svg"),
	ModeManager.Mode.STORES: preload("res://ui/icons/console/stores.svg"),
	ModeManager.Mode.TRADE: preload("res://ui/icons/console/trade.svg"),
	ModeManager.Mode.RND: preload("res://ui/icons/console/research.svg"),
	ModeManager.Mode.COMMS: preload("res://ui/icons/console/comms.svg"),
	ModeManager.Mode.OVERLAY: preload("res://ui/icons/console/overlay.svg"),
	# Past the divider, but a mode like any other since WI-63 gave it a panel.
	ModeManager.Mode.AIDE: preload("res://ui/icons/console/aide.svg"),
}

const SYS_GLYPH: Texture2D = preload("res://ui/icons/console/sys.svg")

## How often the adornments are recomputed, in real seconds.
const ADORNMENT_INTERVAL: float = 1.0

## SYS opens the existing pause menu (program decision 7); AIDE is inert.
signal sys_pressed

var _gradient: TextureRect
var _top_border: ColorRect
var _highlight: ColorRect
var _row: HBoxContainer
var _mode_zone: MarginContainer
var _buttons_row: HBoxContainer
var _divider_a: ColorRect
var _divider_b: ColorRect
var _vitals_zone: MarginContainer
var _time_zone: MarginContainer
var _vitals: VitalsStrip

var _mode_buttons: Dictionary[ModeManager.Mode, ModeButton] = {}
var _manager: ModeManager
## Set by [method bind_overlay]. The overlay bar is the one adornment whose
## source is another UI node rather than a manager.
var _overlay: OverlayController

func _ready() -> void:
	_ensure_refs()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_layout()
	_apply_colors()
	_build_time_zone()
	_build_vitals_zone()
	_build_buttons()
	_connect_adornment_sources()
	refresh_adornments()

func _ensure_refs() -> void:
	if _row != null:
		return
	_gradient = get_node_or_null("Gradient") as TextureRect
	_top_border = get_node_or_null("TopBorder") as ColorRect
	_highlight = get_node_or_null("Highlight") as ColorRect
	_row = get_node_or_null("Row") as HBoxContainer
	_mode_zone = get_node_or_null("Row/ModeZone") as MarginContainer
	_buttons_row = get_node_or_null("Row/ModeZone/Buttons") as HBoxContainer
	_divider_a = get_node_or_null("Row/DividerA") as ColorRect
	_divider_b = get_node_or_null("Row/DividerB") as ColorRect
	_vitals_zone = get_node_or_null("Row/VitalsZone") as MarginContainer
	_time_zone = get_node_or_null("Row/TimeZone") as MarginContainer

# --- public -------------------------------------------------------------------

## The console's flex zone. Public so a caller can mount something beside the
## strip; the strip itself is [method vitals].
func vitals_zone() -> MarginContainer:
	_ensure_refs()
	return _vitals_zone

## The pinned vitals strip (WI-52). [UIMain] needs it to wire the ledger flyout
## the LEDGER chip opens, and a probe needs it to read the pin list back.
func vitals() -> VitalsStrip:
	_ensure_refs()
	return _vitals

## One mode's console button, for a caller that needs to read or drive an
## adornment directly (verification probes; WI-53's alert badges).
func mode_button(mode: ModeManager.Mode) -> ModeButton:
	return _mode_buttons.get(mode)

## Wires the console to the mode registry, both ways: a button press toggles the
## mode, and a mode change (from a button, a hotkey or Esc) re-lights the strip.
## Two-way here rather than in `ui_main.gd` so the console stays the only thing
## that knows how a mode is drawn.
func bind(manager: ModeManager) -> void:
	_manager = manager
	if manager == null:
		return
	manager.mode_changed.connect(_on_mode_changed)
	# Availability tracks the registry rather than being sampled once at bind, so
	# the order of `bind` and `register` cannot matter. WI-56 registers STORES for
	# real; a button left greyed with a stale "arrives later" tooltip because the
	# calls landed the other way round would be a no-op that looks like success.
	manager.registry_changed.connect(_refresh_availability)
	_refresh_active()
	_refresh_availability()

## The overlay bar means "an overlay is painted even though its panel is shut",
## so it tracks the controller rather than the mode registry.
func bind_overlay(controller: OverlayController) -> void:
	_overlay = controller
	if controller != null:
		controller.overlay_mode_changed.connect(_on_overlay_mode_changed)
	refresh_adornments()

# --- layout & colour ----------------------------------------------------------

## The scene authors structure; every number lands here from [UIMetrics], so no
## `.tscn` can hold a console height that disagrees with the design system.
func _apply_layout() -> void:
	_ensure_refs()
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE, true)
	offset_left = 0.0
	offset_right = 0.0
	offset_top = -float(UIMetrics.CONSOLE_HEIGHT)
	offset_bottom = 0.0
	custom_minimum_size.y = float(UIMetrics.CONSOLE_HEIGHT)
	var edge: float = float(UIMetrics.BORDER_WIDTH)
	if _top_border != null:
		_top_border.offset_bottom = edge
	if _highlight != null:
		_highlight.offset_top = edge
		_highlight.offset_bottom = edge * 2.0
	if _row != null:
		_row.offset_top = edge * 2.0
	if _mode_zone != null:
		_mode_zone.custom_minimum_size.x = float(UIMetrics.CONSOLE_MODES_WIDTH)
		_mode_zone.add_theme_constant_override("margin_left", UIMetrics.PANEL_HEADER_PAD)
	if _buttons_row != null:
		_buttons_row.add_theme_constant_override("separation", UIMetrics.MODE_BUTTON_GAP)
	if _time_zone != null:
		_time_zone.custom_minimum_size.x = float(UIMetrics.CONSOLE_TIME_WIDTH)
		for side: String in ["left", "right"]:
			_time_zone.add_theme_constant_override("margin_" + side, UIMetrics.READOUT_CONTENT_PAD)
	if _vitals_zone != null:
		for side: String in ["left", "right"]:
			_vitals_zone.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	for divider: ColorRect in [_divider_a, _divider_b]:
		if divider != null:
			divider.custom_minimum_size = _divider_size()

func _apply_colors() -> void:
	_ensure_refs()
	if _gradient != null:
		_gradient.texture = UIPalette.console_gradient()
	# The console is the only surface in the game with a cyan top border, which
	# is what makes it read as welded to the edge rather than floating over it.
	if _top_border != null:
		_top_border.color = UIPalette.tinted(UIPalette.LIVE, 0.55)
	if _highlight != null:
		_highlight.color = UIPalette.INNER_HIGHLIGHT
	for divider: ColorRect in [_divider_a, _divider_b]:
		if divider != null:
			divider.color = UIPalette.EDGE

# --- buttons ------------------------------------------------------------------

func _build_buttons() -> void:
	_ensure_refs()
	if _buttons_row == null:
		return
	for mode: ModeManager.Mode in ModeManager.ORDER:
		_buttons_row.add_child(_make_mode_button(mode))
	# Seven modes, a divider, then AIDE and SYS. The divider is what stops those
	# two from reading as an eighth and ninth member of the group - AIDE is a mode
	# (WI-63) but it is not one of the seven, which is why it is built from
	# [constant ModeManager.TRAILING] rather than from ORDER.
	_buttons_row.add_child(_make_divider())

	for mode: ModeManager.Mode in ModeManager.TRAILING:
		_buttons_row.add_child(_make_mode_button(mode))

	var sys: ModeButton = ModeButton.create()
	sys.caption = "Sys"
	sys.glyph = SYS_GLYPH
	sys.hotkey = ModeManager.action_hotkey_label(&"toggle_pause_menu")
	sys.tooltip_text = "System menu - save, load, settings"
	sys.pressed.connect(sys_pressed.emit)
	_buttons_row.add_child(sys)

	_assert_fits()

func _make_mode_button(mode: ModeManager.Mode) -> ModeButton:
	var button: ModeButton = ModeButton.create()
	button.caption = ModeManager.label_of(mode)
	button.glyph = GLYPHS.get(mode)
	button.hotkey = ModeManager.hotkey_label(mode)
	button.tooltip_text = "%s (%s)" % [ModeManager.label_of(mode), button.hotkey]
	button.pressed.connect(_on_mode_button_pressed.bind(mode))
	_mode_buttons[mode] = button
	return button

## Warns when the mode row has outgrown its fixed zone. The zone is a fixed
## reserve; the buttons are what actually has to fit in it, and asserting the
## relationship at build time rather than only in a test is what stops an eighth
## mode from silently overflowing into the vitals.
##
## The row is not uniform, so it is measured per child rather than from a flat
## count: it is `n` [ModeButton]s [i]plus[/i] the 1px group divider, and charging
## that divider a full [constant UIMetrics.MODE_BUTTON] width put the total ~69px
## over and warned on every boot about a row that fits. Buttons go through
## [method UIMetrics.mode_zone_width]; anything else contributes its own width
## and one more gap.
func _assert_fits() -> void:
	var buttons: int = 0
	var extras: int = 0
	var extra_width: float = 0.0
	for child: Node in _buttons_row.get_children():
		if child is ModeButton:
			buttons += 1
			continue
		var control: Control = child as Control
		if control == null:
			continue
		extras += 1
		extra_width += control.custom_minimum_size.x
	var consumed: float = (UIMetrics.mode_zone_width(buttons) + extra_width
		+ float(UIMetrics.MODE_BUTTON_GAP * extras))
	# The zone's own left margin is not room the buttons get to use.
	var available: float = float(UIMetrics.CONSOLE_MODES_WIDTH - UIMetrics.PANEL_HEADER_PAD)
	if consumed > available:
		push_warning("ConsoleBar: %d console buttons need %dpx but the mode zone reserves %d"
			% [buttons, int(consumed), int(available)])

## The zone dividers and the mode-group divider are the same hairline in the same
## colour; only the height differs, so they are made in one place.
func _make_divider(height: int = UIMetrics.CONSOLE_TILE_HEIGHT) -> ColorRect:
	var divider := ColorRect.new()
	divider.color = UIPalette.EDGE
	divider.custom_minimum_size = Vector2(float(UIMetrics.BORDER_WIDTH), float(height))
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider

## The taller dividers between the console's three zones.
func _divider_size() -> Vector2:
	return Vector2(float(UIMetrics.BORDER_WIDTH),
		float(UIMetrics.CONSOLE_HEIGHT - 2 * UIMetrics.SCREEN_GUTTER + UIMetrics.CONTENT_PAD))

func _on_mode_button_pressed(mode: ModeManager.Mode) -> void:
	if _manager != null:
		_manager.toggle(mode)

func _on_mode_changed(_new_mode: ModeManager.Mode, _previous: ModeManager.Mode) -> void:
	_refresh_active()

func _refresh_active() -> void:
	for mode: ModeManager.Mode in _mode_buttons:
		_mode_buttons[mode].active = _manager != null and _manager.is_open(mode)

## A mode that cannot be opened (STORES until WI-56 gave it a panel; R&D until
## the station reaches the tier its research needs) renders disabled with its
## reason as the tooltip. Re-run on every
## registry change, and it clears as well as sets - a mode that opens up has to
## get its button, and its ordinary tooltip, back.
func _refresh_availability() -> void:
	if _manager == null:
		return
	for mode: ModeManager.Mode in _mode_buttons:
		var reason: String = _manager.unavailable_reason(mode)
		if reason.is_empty():
			_mode_buttons[mode].set_enabled("%s (%s)" % [
				ModeManager.label_of(mode), _mode_buttons[mode].hotkey])
		else:
			_mode_buttons[mode].set_disabled_with_reason(reason)

# --- time zone ----------------------------------------------------------------

func _build_time_zone() -> void:
	_ensure_refs()
	if _time_zone == null:
		return
	_time_zone.add_child(TIME_SELECT_SCENE.instantiate())

# --- vitals zone --------------------------------------------------------------

func _build_vitals_zone() -> void:
	_ensure_refs()
	if _vitals_zone == null:
		return
	_vitals = VitalsStrip.new()
	_vitals.name = "VitalsStrip"
	_vitals_zone.add_child(_vitals)

# --- adornments ---------------------------------------------------------------

## Everything that can move a dot or a badge. The timer covers the sources with
## no signal of their own (affordability moves whenever a resource does, and
## there is no "the station got richer" signal worth subscribing to at HUD
## granularity); the signals make the rest feel immediate.
func _connect_adornment_sources() -> void:
	SignalBus.trader_arrived.connect(func(_trader: TraderData) -> void: refresh_adornments())
	SignalBus.trader_departed.connect(func(_trader: TraderData) -> void: refresh_adornments())
	SignalBus.global_unlock_changed.connect(refresh_adornments.unbind(1))
	SignalBus.crew_resigning.connect(func(_pawn: PawnBase, _hours: float) -> void: refresh_adornments())
	SignalBus.crew_resignation_cancelled.connect(func(_pawn: PawnBase) -> void: refresh_adornments())
	# The unread badge should move the instant something arrives rather than up to
	# a second later - a transmission and its alert land together, and a badge that
	# lagged the alert feed would read as a bug (WI-57).
	SignalBus.transmissions_changed.connect(refresh_adornments)
	SignalBus.raid_started.connect(func(_strength: float) -> void: refresh_adornments())
	SignalBus.raid_ended.connect(func(_outcome: StringName) -> void: refresh_adornments())
	var timer := Timer.new()
	timer.wait_time = ADORNMENT_INTERVAL
	timer.autostart = true
	# The HUD is real-time by design (TimeManager rule), so this is a plain scene
	# timer rather than sim_seconds: the console must not poll four times faster
	# because the sim is running at 4x.
	timer.timeout.connect(refresh_adornments)
	add_child(timer)

func _on_overlay_mode_changed(_mode: OverlayController.Mode) -> void:
	refresh_adornments()

## The adornment table. Every button exists by the time anything can call this
## (`_build_buttons` runs in `_ready`, before the timer and before `bind`), so
## these are direct assignments - the setters themselves ignore an unchanged
## value, which is what keeps a once-a-second sweep free.
func refresh_adornments() -> void:
	if _mode_buttons.is_empty():
		return
	_mode_buttons[ModeManager.Mode.TRADE].dot = _trader_is_docked()
	_mode_buttons[ModeManager.Mode.RND].dot = _an_unlock_is_affordable()
	_mode_buttons[ModeManager.Mode.CREW].dot = _crew_wants_attention()
	_mode_buttons[ModeManager.Mode.OVERLAY].bar = _overlay != null and _overlay.has_active_mode()
	# The amber count invariant 5 budgets for an unread transmission is spent here
	# and nowhere else: the rows in the Comms feed are cyan, and this one badge is
	# what tells the player to go and look at them (WI-57).
	_mode_buttons[ModeManager.Mode.COMMS].badge = _unread_transmissions()
	# A raid puts a live, expiring decision in the ARC block - the payoff falls
	# while the player is not looking at it, which is exactly what the readiness
	# dot means.
	_mode_buttons[ModeManager.Mode.COMMS].dot = _raid_is_on()

func _trader_is_docked() -> bool:
	return Global.trader_manager != null and Global.trader_manager.visit_active

func _unread_transmissions() -> int:
	var manager: AlertManager = Global.alert_manager
	return manager.unread_transmissions() if manager != null else 0

func _raid_is_on() -> bool:
	return Global.raid_manager != null and Global.raid_manager.active

func _an_unlock_is_affordable() -> bool:
	# The predicate lives on the manager (WI-55): the R&D panel's own header asks
	# the same question, and the console must not be the place it is defined.
	var manager: UnlockManager = Global.unlock_manager
	return manager != null and manager.has_affordable_unlock()

## "There is something here you can do now": somebody is idle, or somebody has
## given notice. Both are things the player can act on from the Crew panel.
##
## The idle test is [method PawnStatus.is_idle] rather than a local one (WI-56).
## It is the same rule the Crew panel's problem line counts with, and a dot that
## lit for a roster the panel then reported as `0 IDLE` would be worse than no
## dot. Two details it carries that a local test kept getting wrong: idle is
## `Job.is_idle_type()` and not `current_job == null` (a pawn with nothing to do
## is handed `idle_wander` immediately, so a null job lasts a frame or two), and
## an **off-shift** pawn with nothing to do is the schedule working rather than a
## staffing problem - without that, the dot was lit every night.
func _crew_wants_attention() -> bool:
	var manager: CrewManager = Global.crew_manager
	if manager == null:
		return false
	for pawn: PawnBase in manager.get_crew():
		var facts: PawnStatus.Facts = PawnStatus.facts_for(pawn)
		if PawnStatus.is_idle(facts) or facts.resigned or facts.resignation_pending:
			return true
	return false
