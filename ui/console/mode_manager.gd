class_name ModeManager
extends Node

## The one place that knows which panel is open (WI-50).
##
## Invariant 1 of the UI rework program: Build, Crew, Stores, Trade, R&D, Comms
## and Overlays are *modes*, not windows. Opening one closes the last, so two
## panels can never coexist - which is why there is no z-order to manage and no
## "close everything" problem, and why Esc collapses from an eleven-branch chain
## to a single `current()` check.
##
## The registry is lazy and cached: `register(mode, factory)` stores a [Callable]
## that is called at most once, the first time that mode is opened. Lazy because
## R&D and Trade are expensive to build and most sessions will not open all
## seven; cached because rebuilding a panel loses its scroll position and its
## filter state, and re-scanning `data/` on every open is wasteful.
##
## **Panels are hidden, not freed, on close.** A panel that holds a live
## subscription it must not service while closed implements `on_opened()` /
## `on_closed()` and connects there. Every panel in the game refreshes only while
## it is on screen; the hooks make that a contract instead of a habit.
##
## Session-only: nothing about which panel was open is saved. A load lands in the
## no-panel state, which is the state Esc returns the player to anyway.
##
## Tree-independent by design - it touches no manager and no autoload, so the GUT
## suite constructs one directly and drives the whole state machine without a
## scene. Only the hotkey handler needs a viewport, and it checks for one.

enum Mode { NONE, BUILD, CREW, STORES, TRADE, RND, COMMS, OVERLAY, AIDE }

## Console order, left to right, for the modes in the main group. The console
## builds its buttons from this list, so adding a mode is one entry here rather
## than a button authored in a scene.
const ORDER: Array[Mode] = [
	Mode.BUILD, Mode.CREW, Mode.STORES, Mode.TRADE, Mode.RND, Mode.COMMS, Mode.OVERLAY,
]

## Modes that live **past the group divider**, beside SYS (WI-63 §8).
##
## AIDE is a mode - it opens a panel, and one-panel-at-a-time has to include it -
## but it is not one of the seven the divider groups, and moving it into [constant
## ORDER] would put it inside that group. Two lists rather than a weakened
## invariant: `test_mode_manager.gd` still asserts the tables account for **every**
## member of [enum Mode], it just knows the console has two zones now.
##
## SYS is deliberately absent. It is not a mode; it opens the pause menu.
const TRAILING: Array[Mode] = [Mode.AIDE]

## Every mode with a console button, in the order they are built.
static func console_order() -> Array[Mode]:
	var out: Array[Mode] = ORDER.duplicate()
	out.append_array(TRAILING)
	return out

## Console button captions and panel titles. Rendered in caps by the widgets that
## own the labels (never `.to_upper()` scattered through panel code).
const LABELS: Dictionary[Mode, String] = {
	Mode.BUILD: "Build",
	Mode.CREW: "Crew",
	Mode.STORES: "Stores",
	Mode.TRADE: "Trade",
	Mode.RND: "R&D",
	Mode.COMMS: "Comms",
	Mode.OVERLAY: "Overlay",
	Mode.AIDE: "Aide",
}

## Mode -> input action. Real actions, not hardcoded keycodes, so WI-36's remapper
## picks them up for free and the printed hotkey follows a rebind.
##
## `mode_stores` is bound to E, not the S the design asked for: S is `camera_down`
## in the WASD pan cluster, and a mode hotkey that also pans the camera is worse
## than a weaker mnemonic. `mode_comms` is G ("signal") because M is spoken for by
## the station map's collapse toggle - see the program doc's hotkey table.
const HOTKEY_ACTIONS: Dictionary[Mode, StringName] = {
	Mode.BUILD: &"mode_build",
	Mode.CREW: &"mode_crew",
	Mode.STORES: &"mode_stores",
	Mode.TRADE: &"mode_trade",
	Mode.RND: &"mode_research",
	Mode.COMMS: &"mode_comms",
	Mode.OVERLAY: &"mode_overlays",
	# Authored in WI-50 as `ui_aide`, inert until WI-63 gave AIDE a panel, and
	# renamed on the way - see [constant Global.REMAPPABLE_ACTIONS] for why the
	# `ui_` prefix was a real hole rather than an aesthetic one. Still F1.
	Mode.AIDE: &"mode_aide",
}

## Emitted after the swap has happened, so a handler that reads `current()` sees
## the new value. Fires exactly once per change, including on close (where
## `new_mode` is NONE).
signal mode_changed(new_mode: Mode, previous: Mode)

## Emitted whenever a mode is registered or declared unavailable, so the console
## can re-derive which buttons are live without the caller having to register
## before it binds.
signal registry_changed

## Where a factory-built panel is added when the factory did not parent it
## itself. Panels that already live in the HUD scene (the ported screens) keep
## their own parent and are only shown and hidden from here.
var mount: Node = null

var _factories: Dictionary[Mode, Callable] = {}
## Modes that exist in the design but have no panel yet, with the reason the
## console button shows as its tooltip. Distinct from "never registered", which
## is a programming error - see [open].
var _unavailable: Dictionary[Mode, String] = {}
var _panels: Dictionary[Mode, Control] = {}
var _current: Mode = Mode.NONE

# --- registration -------------------------------------------------------------

## Declares `mode` openable. `factory` takes no arguments and returns the panel
## [Control]; it is called at most once, on first open.
func register(mode: Mode, factory: Callable) -> void:
	if mode == Mode.NONE:
		push_error("ModeManager: NONE is the closed state, not a registrable mode")
		return
	_factories[mode] = factory
	_unavailable.erase(mode)
	registry_changed.emit()

## Declares `mode` as a console slot that cannot be opened right now - one not
## built yet (STORES, until WI-56), or one the station has not earned (R&D below
## the tier its first node needs, 2026-10-02). `reason` becomes the disabled
## button's tooltip; [method register] with the factory opens it again.
##
## This exists so [open] can tell "declared, not ready" apart from "nobody ever
## registered this", which is a typo and must be loud. A no-op that looks like
## success is exactly the WI-41 `build_module` probe trap.
##
## Closes the mode if it is the open one: its button is about to go dead, and a
## panel left up behind a disabled button could only be shut with Esc.
func register_unavailable(mode: Mode, reason: String) -> void:
	if mode == Mode.NONE:
		return
	if _current == mode:
		close()
	_unavailable[mode] = reason
	_factories.erase(mode)
	registry_changed.emit()

func is_registered(mode: Mode) -> bool:
	return _factories.has(mode) or _unavailable.has(mode)

func is_available(mode: Mode) -> bool:
	return _factories.has(mode)

## "" when the mode is available; otherwise why its button is disabled.
func unavailable_reason(mode: Mode) -> String:
	return _unavailable.get(mode, "")

# --- state --------------------------------------------------------------------

func current() -> Mode:
	return _current

func is_open(mode: Mode) -> bool:
	return _current == mode and mode != Mode.NONE

func has_open_mode() -> bool:
	return _current != Mode.NONE

## The panel for `mode`, building it on first ask. Null for an unavailable or
## unknown mode, and for a factory that returned nothing.
func panel_for(mode: Mode) -> Control:
	var cached: Control = _panels.get(mode)
	if cached != null and is_instance_valid(cached):
		return cached
	if not _factories.has(mode):
		return null
	var built: Variant = (_factories[mode] as Callable).call()
	var panel: Control = built as Control
	if panel == null:
		push_error("ModeManager: the factory for %s produced no Control" % LABELS.get(mode, mode))
		return null
	_panels[mode] = panel
	# A factory is free to parent its own panel (the ported screens are already
	# children of UIMain); anything it leaves orphaned lands on the mount.
	if panel.get_parent() == null and mount != null:
		mount.add_child(panel)
	# A panel's own close control routes through here rather than setting its own
	# `visible`, which would leave `current()` stale and make the next hotkey
	# press close nothing. Duck-typed like the open/closed hooks, so a panel with
	# no close affordance declares nothing.
	if panel.has_signal(&"close_requested"):
		panel.connect(&"close_requested", close)
	panel.visible = false
	return panel

## Every panel this manager has built and can currently see. The probe's
## one-panel-at-a-time assertion reads this.
func visible_panels() -> Array[Control]:
	var out: Array[Control] = []
	for mode: Mode in _panels:
		var panel: Control = _panels[mode]
		if is_instance_valid(panel) and panel.visible:
			out.append(panel)
	return out

# --- transitions --------------------------------------------------------------

## Opens `mode`, closing whatever was open first. Opening the already-open mode
## is a no-op and emits nothing.
func open(mode: Mode) -> void:
	if mode == Mode.NONE:
		close()
		return
	if not is_registered(mode):
		push_error("ModeManager: mode %d was never registered" % mode)
		return
	if not is_available(mode):
		return # declared but not built yet; the button is disabled and says why
	if _current == mode:
		return
	var previous: Mode = _current
	_hide_current()
	_current = mode
	var panel: Control = panel_for(mode)
	if panel != null:
		panel.visible = true
		if panel is ConsolePanel:
			(panel as ConsolePanel).active = true
		# Ambient HUD strips (the alert feed, the overlay flow layer) are mounted
		# after the panels and would otherwise draw across an open panel's header.
		if panel.get_parent() != null:
			panel.move_to_front()
		_notify(panel, &"on_opened")
	mode_changed.emit(mode, previous)

func close() -> void:
	if _current == Mode.NONE:
		return
	var previous: Mode = _current
	_hide_current()
	_current = Mode.NONE
	mode_changed.emit(Mode.NONE, previous)

## Pressing a mode's own button or hotkey while it is open closes it.
func toggle(mode: Mode) -> void:
	if _current == mode:
		close()
	else:
		open(mode)

func _hide_current() -> void:
	if _current == Mode.NONE:
		return
	var panel: Control = _panels.get(_current)
	if panel == null or not is_instance_valid(panel):
		return
	panel.visible = false
	_notify(panel, &"on_closed")

## The open/closed contract. Optional - a panel with no live subscription needs
## neither hook - so it is a `has_method` check rather than an interface nobody
## would implement.
func _notify(panel: Control, hook: StringName) -> void:
	if panel.has_method(hook):
		panel.call(hook)

# --- hotkeys ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Rule the event out before touching the viewport or the InputMap: unhandled
	# input is mostly mouse motion while the player pans, and this handler would
	# otherwise do a focus lookup and fourteen InputMap queries for every one of
	# them. Mouse buttons stay in scope because the remapper accepts them.
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if _text_entry_has_focus():
		return
	for mode: Mode in HOTKEY_ACTIONS:
		if hotkey_pressed(event, HOTKEY_ACTIONS[mode]):
			get_viewport().set_input_as_handled()
			toggle(mode)
			return

## Whether `event` presses `action` **with exactly its bound modifiers** - the one
## way every HUD hotkey handler asks, never a bare `is_action_pressed`.
##
## Godot's default match ignores *extra* modifiers, so an action bound to a bare
## `1` also fires on Shift+1. The overlays are Shift+digit and the time speeds are
## the bare digits (2026-09-15), so under the default every overlay press would
## have changed the speed too, and which handler got there first would have been
## tree order. It is also what makes [method GameSettings.events_conflict] true in
## play: the rebind scan treats Shift+X and X as two keys, which they only are if
## every handler matches exactly.
static func hotkey_pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action, false, true)

func _text_entry_has_focus() -> bool:
	return text_entry_has_focus(get_viewport())

## Typing "steel" into the build menu's search box must not fire mode_stores and
## mode_trade. Every HUD hotkey handler asks this - the mode keys here, the
## overlay keys in [OverlayController], the time keys in [UITimeScaleSelect], the
## map toggle in [UIMain] - so it is one static rather than four copies that drift
## the first time the rule has to widen (a rename field, Panku's REPL, a
## [CodeEdit]). Typing a space or a digit into a search box must not pause the
## game or change its speed.
static func text_entry_has_focus(viewport: Viewport) -> bool:
	if viewport == null:
		return false
	var focused: Control = viewport.gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

# --- labels -------------------------------------------------------------------

## Key names that do not fit a 70px console button. The remap screen has room
## for the full word and keeps using it; only the console abbreviates, which is
## why this lives here rather than in [GameSettings.describe_event].
const HOTKEY_ABBREVIATIONS: Dictionary[String, String] = {
	"ESCAPE": "ESC",
	"SPACE": "SPC",
	"BACKSPACE": "BKSP",
	"DELETE": "DEL",
	"INSERT": "INS",
	"PAGEUP": "PGUP",
	"PAGEDOWN": "PGDN",
	"CONTROL": "CTRL",
	"MIDDLE MOUSE BUTTON": "MMB",
	"LEFT MOUSE BUTTON": "LMB",
	"RIGHT MOUSE BUTTON": "RMB",
	# Build's category cycle prints inside a section label (WI-54), where
	# "BRACELEFT/BRACERIGHT" would be wider than the panel. Godot names keycodes
	# 91/93 "BraceLeft"/"BraceRight" rather than the bracket spelling its own
	# `KEY_BRACKETLEFT` constant suggests, so both are listed - which one
	# `get_keycode_string` returns is not a promise worth relying on.
	"BRACELEFT": "[",
	"BRACERIGHT": "]",
	"BRACKETLEFT": "[",
	"BRACKETRIGHT": "]",
}

## What to print as `mode`'s hotkey - read from the live [InputMap] rather than
## from a constant, so a player who rebinds Build sees their own key on the
## button and in the panel header.
static func hotkey_label(mode: Mode) -> String:
	var action: StringName = HOTKEY_ACTIONS.get(mode, &"")
	return action_hotkey_label(action)

## The same, for the console's non-mode utilities (AIDE, SYS).
static func action_hotkey_label(action: StringName) -> String:
	if action == &"" or not InputMap.has_action(action):
		return ""
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return ""
	# describe_event joins modifiers with " + "; abbreviate each part so a
	# rebind to Ctrl+Delete still fits.
	var parts: Array[String] = []
	for part: String in GameSettings.describe_event(events[0]).to_upper().split(" + "):
		parts.append(HOTKEY_ABBREVIATIONS.get(part, part))
	return "+".join(parts)

static func label_of(mode: Mode) -> String:
	return LABELS.get(mode, "")
