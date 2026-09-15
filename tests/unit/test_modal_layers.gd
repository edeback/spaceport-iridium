extends GutTest

## The stacking order of the UI's canvas layers (2026-09-15).
##
## The HUD, a conversation's balloon and the pause menu each draw on a
## [CanvasLayer], and a CanvasLayer draws - and is hit-tested - by its layer
## number, whatever its place in the tree. The balloon sat at 100 over a pause menu
## mounted on the HUD's layer 10, so the balloon's screen-wide click catcher took
## every click aimed at Resume or Load Game and advanced the conversation instead -
## while the dialogue runner's own comment said it was "below the pause menu".
##
## Pure: reads constants, and two scene files as text.

const MAIN_SCENE: String = "res://main.tscn"
const BALLOON_SCENE: String = "res://ui/dialogue/balloon.tscn"

## The HUD's layer as authored in `main.tscn`, the only place it is stated. -1 if
## the scene no longer has a HUD CanvasLayer with a layer, which the first test
## reports rather than letting the comparisons below pass against it.
func _hud_layer() -> int:
	var in_hud: bool = false
	for line: String in FileAccess.get_file_as_string(MAIN_SCENE).split("\n"):
		if line.begins_with("[node "):
			in_hud = line.contains("name=\"HUD\"") and line.contains("type=\"CanvasLayer\"")
			continue
		if in_hud and line.begins_with("layer = "):
			return int(line.trim_prefix("layer = "))
	return -1

func test_the_hud_layer_is_found() -> void:
	assert_gt(_hud_layer(), -1, "main.tscn authors a HUD CanvasLayer with a layer")

func test_a_conversation_draws_over_the_hud() -> void:
	assert_gt(DialogueBalloon.LAYER, _hud_layer(),
		"the balloon is in front of the console and every panel")

func test_the_pause_menu_draws_over_a_conversation() -> void:
	assert_gt(PauseMenu.LAYER, DialogueBalloon.LAYER,
		"Resume and Load Game take their own clicks while someone is talking")

func test_the_contact_sheet_stays_above_every_ui_layer() -> void:
	assert_gt(Cheats.CONTACT_SHEET_LAYER, PauseMenu.LAYER,
		"a contact sheet photographs the whole UI, pause menu included")

## One source for the number. A layer authored in the scene as well is a second
## value the constant can drift away from, which is how the stated ordering and the
## real one parted company in the first place.
func test_the_balloon_scene_does_not_author_its_own_layer() -> void:
	var text: String = FileAccess.get_file_as_string(BALLOON_SCENE)
	assert_false(text.is_empty(), "the balloon scene was read")
	assert_null(RegEx.create_from_string("(?m)^layer = ").search(text),
		"balloon.tscn leaves its layer to DialogueBalloon.LAYER")
