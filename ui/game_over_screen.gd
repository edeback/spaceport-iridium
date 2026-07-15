class_name GameOverScreen
extends Control

## "Station abandoned" (WI-07): roster hit zero with too few credits to hire
## a replacement. The sim pauses underneath; UI stays real-time by design,
## so the buttons keep working.

func _ready() -> void:
	Global.time_manager.paused = true

func _on_restart_pressed() -> void:
	Global.time_manager.paused = false
	get_tree().reload_current_scene()

func _on_load_pressed() -> void:
	Global.time_manager.paused = false
	if not Global.save_manager.load_slot(SaveManager.QUICK_SLOT):
		# No quicksave to fall back to - stay on the screen, keep paused.
		Global.time_manager.paused = true
