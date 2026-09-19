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

## False renders the stepper as a **read-only readout**: the number still shows,
## and the buttons and their separators are *hidden*. For a control the player can
## see but may not use - the Trade table with no docking bay built (WI-55), a bin
## whose contents the module decides (WI-58).
##
## Hidden rather than merely disabled, which is a correction to WI-58's first
## pass. "Locked is a state, not an absence" (WI-54) is about the **value**, and
## the value is exactly what stays: a dead `−` and `+` either side of it are two
## controls that look like controls and do nothing, and after WI-58 lifted
## `font_disabled_color` for readability they no longer even read as dim. What is
## left is the number, which is the thing the player came to read.
@export var editable: bool = true:
	set(new_value):
		editable = new_value
		_apply_value()

var _minus: Button
var _plus: Button
var _value_label: Label
var _separators: Array[ColorRect] = []

## Which button is held (-1, 0, +1) and how long for, so repeat and commit are
## driven from one real-time clock rather than two timers that can disagree.
var _held: int = 0
var _held_for: float = 0.0
var _repeats: int = 0
## Set when the value has moved but not yet been committed. Only ever raised
## through [method _mark_dirty], which keeps it paired with the clock that will
## clear it.
var _dirty: bool = false
var _quiet_for: float = 0.0

static func create() -> Stepper:
	return (load(SCENE_PATH) as PackedScene).instantiate() as Stepper

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
	# The two hairlines between the buttons and the number. Painted here rather
	# than authored in the scene, because a `.tscn` colour is a hex literal that no
	# longer tracks [UIPalette] - and these two were EDGE spelled out as floats, in
	# the WI-49 widget library itself (WI-58).
	_separators.clear()
	for path: String in ["Row/SepLeft", "Row/SepRight"]:
		var rect: ColorRect = get_node_or_null(path) as ColorRect
		if rect != null:
			rect.color = UIPalette.EDGE
			_separators.append(rect)

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

## True between the player's first step and the commit that follows it. A caller
## that repaints on a tick asks this before pushing a new value, because a
## refresh landing mid-drag would snatch the number back to whatever the sim last
## agreed with - and the commit that arrives a moment later would then write
## *that* value back out as if the player had chosen it.
func is_editing() -> bool:
	return _held != 0 or _dirty

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
	_mark_dirty()
	value_previewed.emit(value)

## Uncommitted, with the clock that will commit it running. The two move
## together, and that pairing is the whole point of the method.
##
## Assigning `value` in [method _apply_step] can run an entire commit behind that
## method's back: the step that reaches the end of the range disables the button
## under the player's finger, the press is dropped, and the `button_up` that
## follows runs [method _end_hold] -> [method _commit], which stops `_process`.
## Raising `_dirty` afterwards without restarting the clock left the widget
## permanently mid-edit - nothing could ever commit it, and because
## [method is_editing] then answered true forever, every refresh skipped the
## control for the rest of the panel's life. A Trade line held to its cap stopped
## repainting; so did a haul priority dragged to +/-100.
##
## The cost of re-arming is that the reentrant commit and this one both report
## the same number, so a hold that ends *at* the range's end writes twice rather
## than once. Two writes are not sixty, every consumer of [signal value_changed]
## is a plain "the number is now X" setter, and the alternative - a latch on the
## last value emitted - would go stale against the two callers that push `value`
## in directly instead of through [method configure].
func _mark_dirty() -> void:
	_dirty = true
	_quiet_for = 0.0
	set_process(true)

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
		_minus.visible = editable
		_plus.visible = editable
		_minus.disabled = value <= min_value
		_plus.disabled = value >= max_value
	# The hairlines belong to the buttons; a read-only stepper is a bare number,
	# not a number in an empty frame.
	for separator: ColorRect in _separators:
		separator.visible = editable
