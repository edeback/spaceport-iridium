class_name UITimeScaleSelect
extends MarginContainer

## Clock readout plus pause/speed controls, all routed through TimeManager.
## Deliberately does NOT touch Engine.time_scale or get_tree().paused - the
## sim pauses, the UI keeps running.
##
## WI-50 moved this into the console's 247px time zone and split the readout in
## two: the hour is the largest type in the HUD ([constant UIType.CLOCK], 28px)
## and the cycle is a meta line under it. `TimeManager.format_time()` still
## returns the one-line form for logs; the console needs the two halves at
## different sizes, which is why it formats them itself rather than splitting a
## formatted string back apart.

## What is holding the sim, per holder id - the sentence the control shows when
## the player presses un-pause and nothing happens (WI-58).
##
## The five ids are [constant AlertManager.PAUSE_HOLD] and the four UI holders,
## each declared as a `PAUSE_HOLD` constant on the class that takes the hold.
## They are duplicated here as *keys* rather than referenced, deliberately: this
## file must not depend on a modal it never talks to, and
## [method TimeManager.pause_holders] hands back ids, not objects. The sweep that
## keeps the two lists in step is a test.
##
## Same shape as [CommsPanel]'s `INSPECTION_LABELS`: every entry names what is in
## the way, and none of them is a bare "unavailable".
const HOLD_REASONS: Dictionary[StringName, String] = {
	&"critical_alert": "A critical alert is waiting — click it to resume",
	&"pause_menu": "The menu is open",
	&"event_card": "An event needs an answer",
	&"trade_panel": "A trader is docked",
	&"game_over": "The run is over",
}

## The same five, short enough to render.
##
## Two forms rather than one because the slot is the console's, not this file's:
## the time zone is 247px and the line has room for about twenty characters, so
## "A critical alert is waiting — click it to resume" arrives as `A CRITICAL …`
## and names nothing at all. The short form goes on the line, the sentence goes on
## its tooltip, and both have to name the blocker rather than report one.
const HOLD_LABELS: Dictionary[StringName, String] = {
	&"critical_alert": "Critical alert",
	&"pause_menu": "Menu open",
	&"event_card": "Event waiting",
	&"trade_panel": "Trader docked",
	&"game_over": "Run over",
}

## The widest a hold label may be before the console's time zone ellipses it.
## Pinned by a test, because the failure is silent: an over-long label does not
## overflow, it truncates into something that reads like a different word.
const HOLD_LABEL_MAX: int = 20

## The fallback for a hold these tables do not know - a mod's, or a new one
## somebody added without a sentence. Still names the id, because a bug report
## saying *"held by cargo_inspection"* is worth more than one saying "held".
const UNKNOWN_HOLD: String = "Held by %s"

@onready var clock_label: Label = %ClockLabel
@onready var cycle_label: Label = %CycleLabel
@onready var pause_button: Button = %PauseButton
@onready var speed_buttons: HBoxContainer = %SpeedButtons

var _speed_button_group: ButtonGroup = ButtonGroup.new()
var _preset_buttons: Array[Button] = []

## Why the sim will not resume, for a list of outstanding holders. Empty when
## nothing is holding it - the ordinary case, where the pause button is simply
## the player's own.
##
## Static and [Global]-free so it can be tested directly, and so the sentence is
## derived in one place rather than assembled at each of the four sites that
## might want it.
##
## The **first** holder wins rather than all of them being listed: two holds at
## once is a modal over a critical alert, and one sentence the player can act on
## beats a list they have to parse under time pressure.
static func hold_reason(holders: Array[StringName]) -> String:
	if holders.is_empty():
		return ""
	var first: StringName = holders[0]
	return HOLD_REASONS.get(first, UNKNOWN_HOLD % first)

## The same answer, short enough for the console's cycle line.
static func hold_label(holders: Array[StringName]) -> String:
	if holders.is_empty():
		return ""
	var first: StringName = holders[0]
	return HOLD_LABELS.get(first, UNKNOWN_HOLD % first)

func _ready() -> void:
	var tm: TimeManager = Global.time_manager
	pause_button.toggled.connect(_on_pause_toggled)
	for preset: float in TimeManager.SPEED_PRESETS:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _speed_button_group
		button.focus_mode = Control.FOCUS_NONE
		# The toggled-on look is the variation's own `pressed` box (a LIVE wash),
		# so a speed pill needs no per-state styling of its own.
		button.theme_type_variation = UIType.ACTION_SECONDARY
		button.text = ("%d" % preset if preset == roundf(preset) else "%.1f" % preset) + "×"
		button.button_pressed = is_equal_approx(preset, tm.speed)
		button.pressed.connect(_on_speed_selected.bind(preset))
		speed_buttons.add_child(button)
		_preset_buttons.append(button)
	tm.hour_changed.connect(_on_time_changed)
	tm.cycle_changed.connect(_on_time_changed)
	# A load rewrites the calendar without crossing a boundary, so it announces
	# itself separately (WI-38 A3). The clock is a display-only listener - exactly
	# what calendar_restored is for.
	tm.calendar_restored.connect(_on_calendar_restored)
	tm.pause_state_changed.connect(_on_pause_state_changed)
	tm.speed_changed.connect(_on_speed_changed)
	_refresh_clock()

## Keeps the preset buttons honest when speed is set from elsewhere (loading
## a save, future event cards).
func _on_speed_changed(new_speed: float) -> void:
	for index: int in _preset_buttons.size():
		_preset_buttons[index].set_pressed_no_signal(is_equal_approx(TimeManager.SPEED_PRESETS[index], new_speed))

## The button drives the player's own pause flag; what it *shows* is the combined
## state ([method TimeManager.is_paused]). Un-pausing while something else holds
## the sim therefore snaps straight back to pressed.
##
## That snap-back used to be the *whole* feedback, and WI-58 calls it the clearest
## remaining violation of "a blocked action names its blocker": pressing resume
## and watching the button bounce, or lighting a speed pill while the clock stays
## still, says a control is broken rather than that something else is holding it.
## [method TimeManager.pause_holders] already knew the answer and had exactly one
## consumer in the project - a cheat.
func _on_pause_toggled(toggled_on: bool) -> void:
	Global.time_manager.paused = toggled_on
	pause_button.set_pressed_no_signal(Global.time_manager.is_paused())
	_refresh_hold()

## Keeps the button honest if something else (the pause menu, an event card, an
## outstanding critical alert) is holding the sim.
func _on_pause_state_changed(paused: bool) -> void:
	pause_button.set_pressed_no_signal(paused)
	_refresh_hold()

## Names whatever is holding the sim, **in the cycle line under the clock**.
##
## Not a line of its own, and that is a geometry decision rather than a taste one:
## the console is a fixed 112px and its time zone already spends that on a 28px
## clock, an 11px cycle line and a row of speed pills. A fourth row overflowed the
## strip and clipped its own descenders off the bottom of the screen - which a
## screenshot caught and no headless check could have.
##
## The cycle number is the right thing to give up for it. A sim that will not
## resume is the more urgent fact by a wide margin, the number comes straight back
## when the hold releases, and it stays available on the tooltip meanwhile.
func _refresh_hold() -> void:
	if cycle_label == null or Global.time_manager == null:
		return
	var holders: Array[StringName] = Global.time_manager.pause_holders()
	if holders.is_empty():
		cycle_label.remove_theme_color_override("font_color")
		_refresh_clock()
		return
	cycle_label.text = hold_label(holders).to_upper()
	cycle_label.tooltip_text = "%s · Cycle %d" % [
		hold_reason(holders), Global.time_manager.cycle]
	cycle_label.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)

## Selecting a speed while a hold is outstanding lights the pill and leaves the
## clock still, so the same sentence has to appear here too.
func _on_speed_selected(new_speed: float) -> void:
	Global.time_manager.speed = new_speed
	_refresh_hold()

func _on_time_changed(_value: int) -> void:
	_refresh_clock()

func _on_calendar_restored(_cycle: int, _hour: int) -> void:
	_refresh_clock()

func _refresh_clock() -> void:
	var tm: TimeManager = Global.time_manager
	clock_label.text = "%02d:00" % tm.hour
	# The cycle line is on loan to [method _refresh_hold] while something is
	# holding the sim, so a tick must not write the number back over the sentence.
	if not tm.pause_holders().is_empty():
		return
	cycle_label.text = "CYCLE %d" % tm.cycle
	cycle_label.tooltip_text = ""
