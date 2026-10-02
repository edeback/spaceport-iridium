extends GutTest

## Unit tests for WI-50's mode state machine ([ModeManager]) - the "exactly one
## panel is open" rule (invariant 1) that Esc, the console buttons and the mode
## hotkeys all resolve through.
##
## The manager is constructed directly and never added to the tree, so `_ready`
## and `_unhandled_input` never run and nothing touches Global or SignalBus. Its
## panels are bare [Control]s: the manager only ever shows, hides and asks them
## for their optional lifecycle hooks, so a real panel would prove nothing extra.

## A stand-in panel that records the hooks it was sent, so the open/closed
## contract can be asserted without a live screen behind it.
class HookPanel:
	extends Control
	var opened: int = 0
	var closed: int = 0
	func on_opened() -> void:
		opened += 1
	func on_closed() -> void:
		closed += 1

var _built: int = 0

func before_each() -> void:
	_built = 0

func _manager() -> ModeManager:
	return autofree(ModeManager.new()) as ModeManager

func _panel() -> Control:
	return autofree(Control.new()) as Control

func _hook_panel() -> HookPanel:
	return autofree(HookPanel.new()) as HookPanel

## A factory that counts its own calls, so "built at most once" is observable.
func _counting_factory(panel: Control) -> Callable:
	return func() -> Control:
		_built += 1
		return panel

# --- registration -------------------------------------------------------------

func test_a_fresh_manager_has_nothing_open() -> void:
	var manager := _manager()
	assert_eq(manager.current(), ModeManager.Mode.NONE, "nothing is open at rest")
	assert_false(manager.has_open_mode(), "and has_open_mode agrees")

func test_registering_makes_a_mode_available() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.BUILD, _counting_factory(_panel()))
	assert_true(manager.is_registered(ModeManager.Mode.BUILD), "registered")
	assert_true(manager.is_available(ModeManager.Mode.BUILD), "and available")
	assert_eq(manager.unavailable_reason(ModeManager.Mode.BUILD), "", "with nothing to explain")

## STORES has a console slot before it has a panel (until WI-56). "Declared but
## not built" must be distinguishable from "never registered", because only one
## of the two is a typo.
func test_an_unavailable_mode_is_registered_but_not_available() -> void:
	var manager := _manager()
	manager.register_unavailable(ModeManager.Mode.STORES, "Coming in a later update")
	assert_true(manager.is_registered(ModeManager.Mode.STORES), "declared")
	assert_false(manager.is_available(ModeManager.Mode.STORES), "but not openable")
	assert_eq(manager.unavailable_reason(ModeManager.Mode.STORES), "Coming in a later update",
		"and the button can say why")

func test_registering_over_an_unavailable_mode_clears_the_reason() -> void:
	var manager := _manager()
	manager.register_unavailable(ModeManager.Mode.STORES, "not yet")
	manager.register(ModeManager.Mode.STORES, _counting_factory(_panel()))
	assert_true(manager.is_available(ModeManager.Mode.STORES), "now openable")
	assert_eq(manager.unavailable_reason(ModeManager.Mode.STORES), "", "and no longer disabled")

func test_none_cannot_be_registered() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.NONE, _counting_factory(_panel()))
	assert_push_error("not a registrable mode")
	assert_false(manager.is_registered(ModeManager.Mode.NONE), "NONE stays the closed state")

# --- lazy, cached factories ---------------------------------------------------

func test_a_factory_is_not_called_until_the_mode_is_opened() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.RND, _counting_factory(_panel()))
	assert_eq(_built, 0, "registration builds nothing - R&D is expensive and may never be opened")

func test_a_factory_is_called_at_most_once() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.RND, _counting_factory(_panel()))
	manager.open(ModeManager.Mode.RND)
	manager.close()
	manager.open(ModeManager.Mode.RND)
	assert_eq(_built, 1, "the panel is cached, so scroll position and filters survive a close")

func test_a_factory_that_returns_nothing_errors() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.RND, func() -> Control: return null)
	assert_null(manager.panel_for(ModeManager.Mode.RND), "no panel")
	assert_push_error("produced no Control")

func test_panel_for_an_unknown_mode_is_null_and_quiet() -> void:
	var manager := _manager()
	assert_null(manager.panel_for(ModeManager.Mode.TRADE), "asking for a panel is not opening one")

# --- open / close / toggle ----------------------------------------------------

func test_open_shows_the_panel_and_emits_once() -> void:
	var manager := _manager()
	var panel := _panel()
	manager.register(ModeManager.Mode.BUILD, _counting_factory(panel))
	watch_signals(manager)
	manager.open(ModeManager.Mode.BUILD)
	assert_eq(manager.current(), ModeManager.Mode.BUILD, "build is the open mode")
	assert_true(panel.visible, "and its panel is showing")
	assert_signal_emit_count(manager, "mode_changed", 1, "one change, one signal")
	assert_signal_emitted_with_parameters(manager, "mode_changed",
		[ModeManager.Mode.BUILD, ModeManager.Mode.NONE], 0)

## The load-bearing rule: two panels can never coexist.
func test_opening_a_second_mode_closes_the_first() -> void:
	var manager := _manager()
	var build := _panel()
	var trade := _panel()
	manager.register(ModeManager.Mode.BUILD, _counting_factory(build))
	manager.register(ModeManager.Mode.TRADE, _counting_factory(trade))
	manager.open(ModeManager.Mode.BUILD)
	watch_signals(manager)
	manager.open(ModeManager.Mode.TRADE)
	assert_false(build.visible, "the previous panel is hidden")
	assert_true(trade.visible, "the new one is shown")
	assert_eq(manager.visible_panels().size(), 1, "exactly one panel is visible")
	assert_signal_emit_count(manager, "mode_changed", 1, "a swap is one change, not a close plus an open")
	assert_signal_emitted_with_parameters(manager, "mode_changed",
		[ModeManager.Mode.TRADE, ModeManager.Mode.BUILD], 0)

func test_reopening_the_open_mode_changes_nothing() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.BUILD, _counting_factory(_panel()))
	manager.open(ModeManager.Mode.BUILD)
	watch_signals(manager)
	manager.open(ModeManager.Mode.BUILD)
	assert_eq(manager.current(), ModeManager.Mode.BUILD, "still open")
	assert_signal_emit_count(manager, "mode_changed", 0, "no change, no signal")

func test_close_hides_the_panel_and_reports_the_previous_mode() -> void:
	var manager := _manager()
	var panel := _panel()
	manager.register(ModeManager.Mode.CREW, _counting_factory(panel))
	manager.open(ModeManager.Mode.CREW)
	watch_signals(manager)
	manager.close()
	assert_eq(manager.current(), ModeManager.Mode.NONE, "back to the no-panel state")
	assert_false(panel.visible, "and the panel is hidden, not freed")
	assert_true(is_instance_valid(panel), "hidden, not freed - closing must not lose panel state")
	assert_signal_emitted_with_parameters(manager, "mode_changed",
		[ModeManager.Mode.NONE, ModeManager.Mode.CREW], 0)

func test_close_on_nothing_is_a_no_op() -> void:
	var manager := _manager()
	watch_signals(manager)
	manager.close()
	assert_eq(manager.current(), ModeManager.Mode.NONE, "still closed")
	assert_signal_emit_count(manager, "mode_changed", 0, "closing nothing announces nothing")

func test_open_none_is_close() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.CREW, _counting_factory(_panel()))
	manager.open(ModeManager.Mode.CREW)
	manager.open(ModeManager.Mode.NONE)
	assert_eq(manager.current(), ModeManager.Mode.NONE, "opening NONE is the closed state")

func test_toggle_opens_then_closes_the_same_mode() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.OVERLAY, _counting_factory(_panel()))
	manager.toggle(ModeManager.Mode.OVERLAY)
	assert_eq(manager.current(), ModeManager.Mode.OVERLAY, "first press opens")
	manager.toggle(ModeManager.Mode.OVERLAY)
	assert_eq(manager.current(), ModeManager.Mode.NONE, "pressing the active mode's key closes it")

func test_toggle_from_another_mode_swaps_rather_than_closing() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.BUILD, _counting_factory(_panel()))
	manager.register(ModeManager.Mode.CREW, _counting_factory(_panel()))
	manager.open(ModeManager.Mode.BUILD)
	manager.toggle(ModeManager.Mode.CREW)
	assert_eq(manager.current(), ModeManager.Mode.CREW, "another mode's key swaps to it")

# --- error rather than silent no-op -------------------------------------------

## A no-op that looks like success wastes a whole verification cycle - the WI-41
## `build_module` probe trap. An unregistered mode is a typo and says so.
func test_opening_an_unregistered_mode_errors_and_changes_nothing() -> void:
	var manager := _manager()
	watch_signals(manager)
	manager.open(ModeManager.Mode.COMMS)
	assert_push_error("never registered")
	assert_eq(manager.current(), ModeManager.Mode.NONE, "state is untouched")
	assert_signal_emit_count(manager, "mode_changed", 0, "and nothing was announced")

## An unavailable mode is a *declared* gap, not a mistake, so it is quiet.
func test_opening_an_unavailable_mode_is_quiet_and_changes_nothing() -> void:
	var manager := _manager()
	manager.register_unavailable(ModeManager.Mode.STORES, "not yet")
	watch_signals(manager)
	manager.open(ModeManager.Mode.STORES)
	assert_push_error_count(0, "a declared gap is not an error")
	assert_eq(manager.current(), ModeManager.Mode.NONE, "nothing opened")
	assert_signal_emit_count(manager, "mode_changed", 0, "and nothing was announced")

func test_an_unavailable_mode_does_not_close_the_open_one() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.BUILD, _counting_factory(_panel()))
	manager.register_unavailable(ModeManager.Mode.STORES, "not yet")
	manager.open(ModeManager.Mode.BUILD)
	manager.open(ModeManager.Mode.STORES)
	assert_eq(manager.current(), ModeManager.Mode.BUILD,
		"a dead button must not close the panel the player was using")

## A mode the station loses access to (R&D's tier gate, 2026-10-02) closes if it
## is open: its button is about to go dead, and only Esc could shut it then.
func test_declaring_the_open_mode_unavailable_closes_it() -> void:
	var manager := _manager()
	var panel := _hook_panel()
	manager.register(ModeManager.Mode.RND, _counting_factory(panel))
	manager.open(ModeManager.Mode.RND)
	watch_signals(manager)
	manager.register_unavailable(ModeManager.Mode.RND, "Unlocks at Tier 2")
	assert_eq(manager.current(), ModeManager.Mode.NONE, "the gated mode is closed")
	assert_false(panel.visible, "its panel is hidden")
	assert_eq(panel.closed, 1, "and told, so a live subscription is dropped")
	assert_signal_emitted_with_parameters(manager, "mode_changed",
		[ModeManager.Mode.NONE, ModeManager.Mode.RND], 0)

## Gating one mode leaves another open one alone.
func test_declaring_another_mode_unavailable_leaves_the_open_one() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.BUILD, _counting_factory(_panel()))
	manager.register(ModeManager.Mode.RND, _counting_factory(_panel()))
	manager.open(ModeManager.Mode.BUILD)
	manager.register_unavailable(ModeManager.Mode.RND, "Unlocks at Tier 2")
	assert_eq(manager.current(), ModeManager.Mode.BUILD, "build stays open")

## A gate that lifts keeps the panel it already built: re-registering the same
## factory must not rebuild it.
func test_a_gate_that_lifts_reuses_the_built_panel() -> void:
	var manager := _manager()
	var factory: Callable = _counting_factory(_panel())
	manager.register(ModeManager.Mode.RND, factory)
	manager.open(ModeManager.Mode.RND)
	manager.register_unavailable(ModeManager.Mode.RND, "Unlocks at Tier 2")
	manager.register(ModeManager.Mode.RND, factory)
	manager.open(ModeManager.Mode.RND)
	assert_eq(manager.current(), ModeManager.Mode.RND, "open again")
	assert_eq(_built, 1, "on the same panel")

# --- the open/closed hooks ----------------------------------------------------

func test_hooks_fire_on_open_and_close() -> void:
	var manager := _manager()
	var panel := _hook_panel()
	manager.register(ModeManager.Mode.CREW, _counting_factory(panel))
	manager.open(ModeManager.Mode.CREW)
	assert_eq(panel.opened, 1, "on_opened fired")
	assert_eq(panel.closed, 0, "and nothing else")
	manager.close()
	assert_eq(panel.closed, 1, "on_closed fired, so a live subscription can be dropped")

func test_a_swap_closes_the_outgoing_panel_before_opening_the_incoming_one() -> void:
	var manager := _manager()
	var build := _hook_panel()
	var crew := _hook_panel()
	manager.register(ModeManager.Mode.BUILD, _counting_factory(build))
	manager.register(ModeManager.Mode.CREW, _counting_factory(crew))
	manager.open(ModeManager.Mode.BUILD)
	manager.open(ModeManager.Mode.CREW)
	assert_eq(build.closed, 1, "the outgoing panel was told")
	assert_eq(crew.opened, 1, "and so was the incoming one")

## Every panel is a plain Control as far as the manager is concerned; the hooks
## are optional and a panel without them must not error.
func test_a_panel_without_hooks_is_fine() -> void:
	var manager := _manager()
	manager.register(ModeManager.Mode.TRADE, _counting_factory(_panel()))
	manager.open(ModeManager.Mode.TRADE)
	manager.close()
	assert_push_error_count(0, "hooks are optional")

# --- the mode table -----------------------------------------------------------

## The console builds its buttons from ORDER and TRAILING, the panels take their
## titles from LABELS and their printed hotkey from HOTKEY_ACTIONS. A mode missing
## from any of them renders as a blank button or an unreachable panel.
##
## Two zones since WI-63, not one: AIDE is a mode (it opens a panel, and
## one-panel-at-a-time has to include it) but it sits past the group divider
## beside SYS, so putting it in ORDER would move it inside the group of seven.
## The invariant is unchanged - **every** member of the enum is accounted for
## exactly once - it just spans two lists now.
func test_every_mode_appears_exactly_once_in_the_console_order() -> void:
	var slots: Array[ModeManager.Mode] = ModeManager.console_order()
	for value: int in ModeManager.Mode.values():
		if value == ModeManager.Mode.NONE:
			continue
		assert_eq(slots.count(value), 1,
			"mode %d has exactly one console slot" % value)
	assert_eq(slots.size(), ModeManager.Mode.size() - 1,
		"ORDER plus TRAILING covers every mode but NONE")

## The two zones are disjoint. A mode in both would build two buttons, and the
## second would silently win the `_mode_buttons` entry.
func test_the_two_console_zones_do_not_overlap() -> void:
	for mode: ModeManager.Mode in ModeManager.TRAILING:
		assert_false(ModeManager.ORDER.has(mode),
			"mode %d is in exactly one console zone" % mode)

func test_every_mode_has_a_label_and_a_hotkey_action() -> void:
	for mode: ModeManager.Mode in ModeManager.console_order():
		assert_false(ModeManager.label_of(mode).is_empty(), "mode %d has a label" % mode)
		assert_true(ModeManager.HOTKEY_ACTIONS.has(mode), "mode %d has a hotkey action" % mode)

## Two modes on one key would make the second unreachable, and the collision
## would only show up as "why does T open Crew".
func test_no_two_modes_share_a_hotkey_action() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for mode: ModeManager.Mode in ModeManager.HOTKEY_ACTIONS:
		var action: StringName = ModeManager.HOTKEY_ACTIONS[mode]
		assert_false(seen.has(action), "%s is bound to exactly one mode" % action)
		seen[action] = true

## Every hotkey the HUD reads, in one list, so the collision scan below covers
## the whole surface rather than just the mode keys.
func _hud_hotkey_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for mode: ModeManager.Mode in ModeManager.HOTKEY_ACTIONS:
		actions.append(ModeManager.HOTKEY_ACTIONS[mode])
	for action: StringName in OverlayController.HOTKEY_ACTIONS:
		actions.append(action)
	actions.append(UITimeScaleSelect.PAUSE_ACTION)
	for action: StringName in UITimeScaleSelect.SPEED_ACTIONS:
		actions.append(action)
	actions.append(&"toggle_map")
	return actions

func test_every_hud_hotkey_action_exists_in_the_input_map() -> void:
	for action: StringName in _hud_hotkey_actions():
		assert_true(InputMap.has_action(action), "%s is a real input action" % action)

## HUD hotkeys must not collide with the WASD camera pan or any other bound
## action - a key that both opens Stores and pans the camera down is a bug the
## player experiences as the station sliding away under an opening panel. The
## overlay keys are in scope because WI-50 moved them onto real actions; before
## that they consumed every bare digit press before the action system saw it.
## Since 2026-09-15 the overlays (Shift+digit) and the speeds (bare digit) share
## physical keys, which this scan accepts because `events_conflict` compares
## modifiers - and which is only true in play because of the exact match pinned
## below.
func test_hud_hotkeys_do_not_collide_with_other_bound_actions() -> void:
	var hud: Array[StringName] = _hud_hotkey_actions()
	for action: StringName in hud:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			for other: StringName in InputMap.get_actions():
				if other == action or String(other).begins_with("ui_"):
					continue
				for bound: InputEvent in InputMap.action_get_events(other):
					assert_false(GameSettings.events_conflict(event, bound),
						"%s (%s) does not collide with %s" % [
							action, GameSettings.describe_event(event), other])

## Every HUD hotkey has to be rebindable, or WI-36's remapper cannot show it and
## the conflict check above has nothing to compare against. `toggle_ledger` is
## deliberately excluded until WI-52 gives it behaviour.
func test_every_hud_hotkey_is_offered_by_the_remapper() -> void:
	for action: StringName in _hud_hotkey_actions():
		assert_true(Global.REMAPPABLE_ACTIONS.has(action),
			"%s appears in the keybind remapper" % action)

# --- digits: speeds bare, overlays on Shift (2026-09-15) -----------------------

func _press(physical: Key, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.shift_pressed = shift
	event.pressed = true
	return event

## The reason `hotkey_pressed` exists. Godot's default match ignores extra
## modifiers, so an action bound to a bare 1 fires on Shift+1 as well - every
## overlay press would also have changed the speed.
func test_shift_digit_paints_an_overlay_and_leaves_the_speed_alone() -> void:
	var shift_one: InputEventKey = _press(KEY_1, true)
	assert_true(ModeManager.hotkey_pressed(shift_one, &"overlay_power"), "Shift+1 paints power")
	assert_false(ModeManager.hotkey_pressed(shift_one, &"time_speed_half"),
		"and is not also the 1 key")
	assert_true(ModeManager.hotkey_pressed(_press(KEY_0, true), &"overlay_clear"),
		"Shift+0 clears")

func test_the_bare_digits_count_up_the_speeds() -> void:
	var expected: Dictionary[Key, StringName] = {
		KEY_1: &"time_speed_half",
		KEY_2: &"time_speed_normal",
		KEY_3: &"time_speed_double",
		KEY_4: &"time_speed_quad",
	}
	for key: Key in expected:
		var press: InputEventKey = _press(key)
		assert_true(ModeManager.hotkey_pressed(press, expected[key]),
			"%s is %s" % [OS.get_keycode_string(key), expected[key]])
		for overlay: StringName in OverlayController.HOTKEY_ACTIONS:
			assert_false(ModeManager.hotkey_pressed(press, overlay),
				"a bare %s paints no overlay" % OS.get_keycode_string(key))

func test_space_is_pause() -> void:
	assert_true(ModeManager.hotkey_pressed(_press(KEY_SPACE), UITimeScaleSelect.PAUSE_ACTION),
		"Space pauses")
	assert_false(ModeManager.hotkey_pressed(_press(KEY_SPACE, true), UITimeScaleSelect.PAUSE_ACTION),
		"Shift+Space is a different key")

func test_an_unknown_action_is_never_pressed() -> void:
	assert_false(ModeManager.hotkey_pressed(_press(KEY_1), &"no_such_action"),
		"a missing action is a no, not an InputMap error")

## Keyed by action, so the check is that the two lists agree: a pill with no key
## is unreachable from the keyboard, and a key with no pill lights nothing.
func test_every_speed_pill_has_one_key_and_every_key_a_pill() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for preset: float in TimeManager.SPEED_PRESETS:
		var action: StringName = UITimeScaleSelect.speed_action(preset)
		assert_ne(action, &"", "%.1f× has a hotkey" % preset)
		assert_false(seen.has(action), "%s selects exactly one speed" % action)
		seen[action] = true
	assert_eq(seen.size(), UITimeScaleSelect.SPEED_ACTIONS.size(),
		"and no key names a speed with no pill")

## A key toggles its own overlay; the clear key still clears.
func test_an_overlay_key_toggles_its_own_overlay() -> void:
	var none: OverlayController.Mode = OverlayController.Mode.NONE
	var power: OverlayController.Mode = OverlayController.Mode.POWER
	var o2: OverlayController.Mode = OverlayController.Mode.O2
	assert_eq(OverlayController.toggled_mode(none, power), power, "from nothing it paints")
	assert_eq(OverlayController.toggled_mode(power, power), none, "its own key again clears it")
	assert_eq(OverlayController.toggled_mode(power, o2), o2, "another key switches rather than clears")
	assert_eq(OverlayController.toggled_mode(power, none), none, "Shift+0 still clears")
	assert_eq(OverlayController.toggled_mode(none, none), none, "and clearing nothing is nothing")
