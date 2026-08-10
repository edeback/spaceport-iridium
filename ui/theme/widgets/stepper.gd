@tool
class_name Stepper
extends PanelContainer

## `−  value  +` with a wide hit target and a sign-coloured value (WI-49).
##
## Replaces three different [SpinBox] setups, one of which needed its own theme
## (`spinbox_theme.tres`) to be usable at all. Used by Stores (haul priority,
## −100…+100), Trade order lines, and per-resource desired amounts.
##
## **The commit rule is the point of this widget.** Storage priority goes
## through `update_priority()`, which re-sorts and re-posts jobs (WI-45 A5) -
## so holding `+` from −100 to +100 must not fire 200 re-sorts. The displayed
## value moves immediately, but [signal value_changed] fires only once the
## player stops: on button release, or after [constant COMMIT_DELAY] of
## quiet. Callers that need the live number for a readout use
## [signal value_previewed], which is free to fire on every step.

const SCENE_PATH: String = "res://ui/theme/widgets/stepper.tscn"

## Real seconds of quiet before an uncommitted change is committed. UI is
## real-time by design (the TimeManager rule), so this is wall-clock and stays
## honest while the sim is paused.
const COMMIT_DELAY: float = 0.25
## How long a button must be held before it starts repeating, and the interval
## between repeats after that.
const REPEAT_DELAY: float = 0.4
const REPEAT_INTERVAL: float = 0.06

## The committed value - what the caller should act on.
signal value_changed(value: int)
## Every step, including ones that will be superseded. For live readouts only;
## never do work in response to this.
signal value_previewed(value: int)

@export var value: int = 0:
	set(new_value):
		value = clampi(new_value, min_value, max_value)
		_apply_value()
@export var min_value: int = 0:
	set(new_value):
		min_value = new_value
		value = value
@export var max_value: int = 100:
	set(new_value):
		max_value = new_value
		value = value
@export var step: int = 1
## Renders "+60" rather than "60" for positives. Correct for a signed range like
## haul priority, wrong for a count.
@export var show_sign: bool = false:
	set(new_value):
		show_sign = new_value
		_apply_value()
## Colours the value by sign ([method UIPalette.sign_color]). Off for a plain
## count, where a grey zero and a cyan one would read as a state that is not
## there.
@export var sign_colored: bool = false:
	set(new_value):
		sign_colored = new_value
		_apply_value()

var _minus: Button
var _plus: Button
var _value_label: Label

## Which button is held (-1, 0, +1) and how long for, so repeat and commit are
## driven from one real-time clock rather than two timers that can disagree.
var _held: int = 0
var _held_for: float = 0.0
var _repeats: int = 0
## Set when the value has moved but not yet been committed.
var _dirty: bool = false
var _quiet_for: float = 0.0

static func create() -> Stepper:
	return load(SCENE_PATH).instantiate() as Stepper

func _ready() -> void:
	_ensure_refs()
	if _minus == null:
		return
	_minus.button_down.connect(func() -> void: _begin_hold(-1))
	_plus.button_down.connect(func() -> void: _begin_hold(1))
	_minus.button_up.connect(_end_hold)
	_plus.button_up.connect(_end_hold)
	set_process(false)
	_apply_value()

func _ensure_refs() -> void:
	if _value_label != null:
		return
	_minus = get_node_or_null("Row/Minus") as Button
	_plus = get_node_or_null("Row/Plus") as Button
	_value_label = get_node_or_null("Row/Value") as Label

## Sets the range and the current value without emitting - for a panel wiring a
## stepper up to state it just read.
func configure(current: int, minimum: int, maximum: int, step_size: int = 1,
		signed: bool = true) -> void:
	min_value = minimum
	max_value = maximum
	step = step_size
	show_sign = signed
	sign_colored = signed
	value = current
	_dirty = false

# --- interaction --------------------------------------------------------------

func _begin_hold(direction: int) -> void:
	_held = direction
	_held_for = 0.0
	_repeats = 0
	_apply_step(direction)
	set_process(true)

func _end_hold() -> void:
	_held = 0
	# Releasing is an unambiguous "I am done", so it commits without waiting out
	# the quiet period.
	_commit()

## Real-time, deliberately: this is UI, and a stepper that repeated at sim speed
## would be uncontrollable at 4x and dead while paused.
func _process(delta: float) -> void:
	if _held != 0:
		_held_for += delta
		var due: int = 0 if _held_for < REPEAT_DELAY else \
			int((_held_for - REPEAT_DELAY) / REPEAT_INTERVAL) + 1
		while _repeats < due:
			_repeats += 1
			_apply_step(_held)
		return
	if _dirty:
		_quiet_for += delta
		if _quiet_for >= COMMIT_DELAY:
			_commit()
		return
	set_process(false)

func _apply_step(direction: int) -> void:
	var before: int = value
	value = value + direction * step
	if value == before:
		return # already at the end of the range
	_dirty = true
	_quiet_for = 0.0
	value_previewed.emit(value)

func _commit() -> void:
	if not _dirty:
		set_process(_held != 0)
		return
	_dirty = false
	_quiet_for = 0.0
	set_process(_held != 0)
	value_changed.emit(value)

func _apply_value() -> void:
	_ensure_refs()
	if _value_label == null:
		return
	_value_label.text = ("%+d" % value) if show_sign else str(value)
	_value_label.add_theme_color_override("font_color",
		UIPalette.sign_color(float(value)) if sign_colored else UIPalette.LIVE_BRIGHT)
	if _minus != null:
		_minus.disabled = value <= min_value
		_plus.disabled = value >= max_value
