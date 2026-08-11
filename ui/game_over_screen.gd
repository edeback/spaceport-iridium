class_name GameOverScreen
extends Control

## The run-ended screen (WI-07): originally just crew abandonment, now shared by
## the WI-25 bankruptcy path. The sim pauses underneath; UI stays real-time by
## design, so the buttons keep working. configure() overrides the default title
## and subtitle before the screen is added to the tree.

## This screen's entry in [TimeManager]'s hold set (WI-53). The run is over, so
## the hold is only released on the way out of the scene - and because the flag
## it stops the sim with is no longer the player's own, a save loaded from here
## comes back at whatever pause state it was written at.
const PAUSE_HOLD: StringName = &"game_over"

@onready var _title: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/Title
@onready var _subtitle: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/Subtitle

var _reason: String = ""

## Sets the subtitle to `reason` (and a generic "Game Over" title) when the run
## ended for a reason other than the default crew abandonment. Call before
## add_child; the labels apply it in _ready.
func configure(reason: String) -> void:
	_reason = reason

func _ready() -> void:
	Global.time_manager.hold_pause(PAUSE_HOLD)
	if _reason != "":
		_title.text = "Game Over"
		_subtitle.text = _reason

func _on_restart_pressed() -> void:
	Global.time_manager.release_pause(PAUSE_HOLD)
	# Clear any staged load first (WI-36): a restart must start fresh, not
	# silently reapply a save that was queued but never consumed.
	SaveManager.clear_pending_load()
	get_tree().reload_current_scene()

## Back to the main menu (WI-36). Same exit the pause menu uses, so the managers
## are rebuilt from scratch on the next New Game rather than carrying residue
## from the ended run (the WI-18 bootstrap).
func _on_quit_to_menu_pressed() -> void:
	Global.time_manager.release_pause(PAUSE_HOLD)
	SaveManager.clear_pending_load()
	get_tree().change_scene_to_file(PauseMenu.MAIN_MENU_SCENE)

func _on_load_pressed() -> void:
	Global.time_manager.release_pause(PAUSE_HOLD)
	if not Global.save_manager.load_slot(SaveManager.QUICK_SLOT):
		# No quicksave to fall back to - stay on the screen, keep paused.
		Global.time_manager.hold_pause(PAUSE_HOLD)
