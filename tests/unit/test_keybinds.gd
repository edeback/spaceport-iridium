extends GutTest

## WI-58 stage 5: the rebind conflict scan sees every key the project binds.
##
## `Global.find_binding_conflicts()` iterated [constant Global.REMAPPABLE_ACTIONS],
## which is the remap screen's **display list** - deliberately curated to keep
## Godot's `ui_*` built-ins and the debug hotkeys out of a player-facing menu.
## Using it to answer "what would this key collide with" left three real bindings
## invisible: `ui_aide` (now `mode_aide`, and remappable since WI-63),
## `debug_fire_event` and `debug_offer_contract`. Rebinding
## a mode onto one of their keys created two actions on one key with no swap
## offered and no warning.
##
## The classification is now explicit (remappable + non-remappable), and this
## suite is what keeps it complete: it reads `project.godot`'s own `[input]`
## section, so an action added to neither list fails here rather than silently
## escaping the scan.
##
## Pure: reads a file and two constant arrays. No nodes, no [Global] instance -
## the constants are `const` on the autoload's *script*, reachable without it.

const PROJECT_FILE: String = "res://project.godot"

## Every action name declared in `project.godot`'s `[input]` section.
##
## Parsed from the file rather than read off [InputMap], because [InputMap] also
## holds Godot's built-in `ui_*` actions and there is no runtime way to tell the
## two apart - `ProjectSettings.has_setting("input/ui_cancel")` is true for a
## built-in the project never touched, since the engine registers every one of
## them with a default. The file is the only place the distinction exists.
func _declared_actions() -> Array[String]:
	var out: Array[String] = []
	var in_section: bool = false
	for line: String in FileAccess.get_file_as_string(PROJECT_FILE).split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("["):
			in_section = trimmed == "[input]"
			continue
		if not in_section or not trimmed.ends_with("={"):
			continue
		out.append(trimmed.trim_suffix("={"))
	return out

func test_the_parser_actually_finds_the_input_section() -> void:
	# A sweep whose scan silently returned nothing would pass everything below.
	var declared: Array[String] = _declared_actions()
	assert_gt(declared.size(), 20, "project.godot declares a real action list")
	assert_true(declared.has("build"), "and the parse produced usable names")

## The completeness guard. Every key the project binds has to be classified, or
## it is invisible to conflict detection.
func test_every_declared_action_is_classified() -> void:
	for action: String in _declared_actions():
		var name := StringName(action)
		assert_true(Global.REMAPPABLE_ACTIONS.has(name)
				or Global.NON_REMAPPABLE_ACTIONS.has(name),
			"%s is bound but is in neither action list" % action)

## The reverse: a list entry for an action that no longer exists would have the
## remap screen offering a row that binds nothing.
func test_no_listed_action_has_gone_away() -> void:
	var declared: Array[String] = _declared_actions()
	for name: StringName in Global.REMAPPABLE_ACTIONS:
		assert_true(declared.has(String(name)), "%s is offered but not declared" % name)
	for name: StringName in Global.NON_REMAPPABLE_ACTIONS:
		assert_true(declared.has(String(name)), "%s is scanned but not declared" % name)

## The two lists partition rather than overlap - an action in both would be
## offered in the menu and described as unofferable at the same time.
func test_the_two_lists_do_not_overlap() -> void:
	for name: StringName in Global.NON_REMAPPABLE_ACTIONS:
		assert_false(Global.REMAPPABLE_ACTIONS.has(name),
			"%s is in both lists" % name)

## The bindings that motivated the item. There were three; `ui_aide` became
## `mode_aide` and moved into the player-facing list in WI-63, when AIDE stopped
## being a stub - so the interesting assertion for it is now the opposite one, and
## it lives in `test_mode_manager.gd` with the other seven modes.
func test_the_invisible_bindings_are_now_scanned() -> void:
	for name: StringName in [&"debug_fire_event", &"debug_offer_contract"]:
		assert_true(Global.NON_REMAPPABLE_ACTIONS.has(name),
			"%s is bound, so a rebind onto its key has to be a conflict" % name)
		assert_false(Global.REMAPPABLE_ACTIONS.has(name),
			"%s still stays out of the player-facing menu" % name)

## Godot's own navigation actions must stay out entirely: `ui_cancel` is Escape,
## and the whole Esc ladder hangs off it.
func test_godots_built_in_ui_actions_are_not_scanned() -> void:
	for name: StringName in [&"ui_cancel", &"ui_accept", &"ui_left", &"ui_text_backspace"]:
		assert_false(Global.REMAPPABLE_ACTIONS.has(name), "%s is not offered" % name)
		assert_false(Global.NON_REMAPPABLE_ACTIONS.has(name), "%s is not scanned" % name)

## Every remappable action needs a friendly label, or the swap dialog quotes an
## id at the player.
func test_every_remappable_action_has_a_label() -> void:
	for name: StringName in Global.REMAPPABLE_ACTIONS:
		assert_true(Global.ACTION_LABELS.has(name), "%s has a display label" % name)
