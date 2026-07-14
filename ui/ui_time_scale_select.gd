class_name UITimeScaleSelect
extends MarginContainer

## Clock readout plus pause/speed controls, all routed through TimeManager.
## Deliberately does NOT touch Engine.time_scale or get_tree().paused - the
## sim pauses, the UI keeps running.

@onready var clock_label: Label = %ClockLabel
@onready var pause_button: CheckButton = %PauseButton
@onready var speed_buttons: HBoxContainer = %SpeedButtons

var _speed_button_group: ButtonGroup = ButtonGroup.new()
var _preset_buttons: Array[Button] = []

func _ready() -> void:
	var tm: TimeManager = Global.time_manager
	pause_button.toggled.connect(_on_pause_toggled)
	for preset: float in TimeManager.SPEED_PRESETS:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _speed_button_group
		button.text = ("%d" % preset if preset == roundf(preset) else "%.1f" % preset) + "x"
		button.button_pressed = is_equal_approx(preset, tm.speed)
		button.pressed.connect(_on_speed_selected.bind(preset))
		speed_buttons.add_child(button)
		_preset_buttons.append(button)
	tm.hour_changed.connect(_on_time_changed)
	tm.cycle_changed.connect(_on_time_changed)
	tm.pause_state_changed.connect(_on_pause_state_changed)
	tm.speed_changed.connect(_on_speed_changed)
	_refresh_clock()

## Keeps the preset buttons honest when speed is set from elsewhere (loading
## a save, future event cards).
func _on_speed_changed(new_speed: float) -> void:
	for index: int in _preset_buttons.size():
		_preset_buttons[index].set_pressed_no_signal(is_equal_approx(TimeManager.SPEED_PRESETS[index], new_speed))

func _on_pause_toggled(toggled_on: bool) -> void:
	Global.time_manager.paused = toggled_on

## Keeps the button honest if something else (a future event card, hotkey)
## pauses the sim.
func _on_pause_state_changed(paused: bool) -> void:
	pause_button.set_pressed_no_signal(paused)

func _on_speed_selected(new_speed: float) -> void:
	Global.time_manager.speed = new_speed

func _on_time_changed(_value: int) -> void:
	_refresh_clock()

func _refresh_clock() -> void:
	clock_label.text = Global.time_manager.format_time()
