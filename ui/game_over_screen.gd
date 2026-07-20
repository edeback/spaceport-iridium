class_name GameOverScreen
extends Control

## The run-ended screen (WI-07): originally just crew abandonment, now shared by
## the WI-25 bankruptcy path. The sim pauses underneath; UI stays real-time by
## design, so the buttons keep working. configure() overrides the default title
## and subtitle before the screen is added to the tree.

@onready var _title: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/Title
@onready var _subtitle: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/Subtitle

var _reason: String = ""

## Sets the subtitle to `reason` (and a generic "Game Over" title) when the run
## ended for a reason other than the default crew abandonment. Call before
## add_child; the labels apply it in _ready.
func configure(reason: String) -> void:
	_reason = reason

func _ready() -> void:
	Global.time_manager.paused = true
	if _reason != "":
		_title.text = "Game Over"
		_subtitle.text = _reason

func _on_restart_pressed() -> void:
	Global.time_manager.paused = false
	get_tree().reload_current_scene()

func _on_load_pressed() -> void:
	Global.time_manager.paused = false
	if not Global.save_manager.load_slot(SaveManager.QUICK_SLOT):
		# No quicksave to fall back to - stay on the screen, keep paused.
		Global.time_manager.paused = true
