extends GutTest

## R&D stays shut until the station reaches the tier its research opens at
## (2026-10-02): every node that does not start owned needs Tier 2, so a new
## station's console shows the button disabled and saying why, and a promotion -
## or a load of a promoted station - gives it back with its ordinary tooltip.

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

func _modes() -> ModeManager:
	return Global.ui_main.mode_manager

func _button() -> ModeButton:
	return Global.ui_main.console.mode_button(ModeManager.Mode.RND)

## The tooltip every enabled console button carries: its label and its key.
func _open_tooltip() -> String:
	return "%s (%s)" % [ModeManager.label_of(ModeManager.Mode.RND),
		ModeManager.hotkey_label(ModeManager.Mode.RND)]

func _promote() -> void:
	Global.unlock_manager.advance_tier()
	assert_eq(Global.unlock_manager.current_tier, 2, "promoted to Tier 2")

func test_the_shipped_tree_opens_research_at_tier_two() -> void:
	assert_eq(Global.unlock_manager.research_opens_at_tier(), 2,
		"every node that does not start owned needs Tier 2 or more")

func test_a_new_station_has_research_disabled_and_says_why() -> void:
	assert_eq(Global.unlock_manager.current_tier, 1, "a new station is Tier 1")
	assert_true(_button().disabled, "the R&D button is disabled")
	assert_eq(_button().tooltip_text, "Unlocks at Tier 2", "and its tooltip names the gate")
	assert_false(_modes().is_available(ModeManager.Mode.RND), "the mode cannot be opened")

func test_a_disabled_research_mode_does_not_open() -> void:
	_modes().toggle(ModeManager.Mode.RND)
	assert_eq(_modes().current(), ModeManager.Mode.NONE, "the hotkey's path opens nothing")
	assert_push_error_count(0, "a declared gate is not an error")

func test_promotion_gives_research_back() -> void:
	_promote()
	assert_false(_button().disabled, "the R&D button is enabled")
	assert_eq(_button().tooltip_text, _open_tooltip(), "and its gate tooltip is gone")
	_modes().toggle(ModeManager.Mode.RND)
	assert_eq(_modes().current(), ModeManager.Mode.RND, "and it opens")
	assert_true(_modes().panel_for(ModeManager.Mode.RND).visible, "onto the research panel")

func test_a_promoted_station_reloads_with_research_open() -> void:
	_promote()
	assert_true(await fx.save_and_reload())
	assert_eq(Global.unlock_manager.current_tier, 2, "the tier survives the load")
	assert_false(_button().disabled, "the R&D button is enabled after the load")
	assert_eq(_button().tooltip_text, _open_tooltip(), "with its ordinary tooltip")

func test_a_tier_one_station_reloads_with_research_still_shut() -> void:
	assert_true(await fx.save_and_reload())
	assert_true(_button().disabled, "still disabled after the load")
	assert_eq(_button().tooltip_text, "Unlocks at Tier 2", "and still says why")
