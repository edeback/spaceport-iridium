class_name BuildCursorHint
extends PanelContainer

## The label attached to a held module's ghost (WI-54): its name, what it costs,
## and how to flip it, following the cursor.
##
## "Once picked up, the module becomes a ghost under the cursor with its cost and
## rotate hint attached, so the instruction is where the player is looking."
##
## Two deliberate placements:
##
##   - **Not drawn in [PreviewModule]'s `_draw`.** `_draw` output is the one thing
##     headless verification cannot see, and there is no reason to make the
##     build flow the exception. This is an ordinary [Control] with an ordinary
##     [Label] in it, which a probe can read.
##   - **Parented to the HUD, not to the Build panel.** Closing Build while
##     holding a module keeps the ghost (WI-50 edge case), so the hint has to
##     outlive the panel that started it.
##
## It reads [UIInGame] and writes nothing: the held module, the flip key and the
## costs are all already state somewhere else.

const SCENE_PATH: String = "res://ui/buttons/build_cursor_hint.tscn"

## Gap between the cursor and the label's top-left corner. Below and right, so
## the label never sits under the pointer itself.
const CURSOR_OFFSET := Vector2(18.0, 22.0)

## Kept this far inside the viewport, so a ghost near the right or bottom edge
## does not push its own instruction off screen.
const SCREEN_MARGIN: float = 8.0

var _label: Label

static func create() -> BuildCursorHint:
	return load(SCENE_PATH).instantiate() as BuildCursorHint

func _ready() -> void:
	_label = get_node_or_null("Pad/Label") as Label
	# A hint must never eat the click that places the module it is describing.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	visible = false
	_apply_style()
	set_process(false)
	if Global.ui_in_game != null:
		Global.ui_in_game.input_mode_changed.connect(_on_input_mode_changed)

func _apply_style() -> void:
	var box := StyleBoxFlat.new()
	# Nearly opaque: it sits over the station, and a translucent instruction over
	# a busy hull is unreadable exactly when it matters.
	box.bg_color = UIPalette.tinted(UIPalette.PANEL, 0.95)
	box.border_color = UIPalette.ACTIVE_BORDER
	box.set_border_width_all(UIMetrics.BORDER_WIDTH)
	box.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", box)
	if _label != null:
		_label.add_theme_color_override("font_color", UIPalette.LIVE_BRIGHT)

func _on_input_mode_changed(mode: UIInGame.InputMode) -> void:
	# MULTIPLACE is a drag of the module already held, so the hint stays up.
	var holding: bool = mode == UIInGame.InputMode.Module or mode == UIInGame.InputMode.Multiplace
	visible = holding and _refresh_text()
	set_process(visible)
	if visible:
		_follow_cursor()

## The hint line: `MINING DRILL · 12 STEEL · 4 SILICON · F FLIP`. Returns false
## when there is nothing to describe, which is what hides the label.
##
## The flip half is printed only for a module that can actually flip, and the key
## comes from the live [InputMap] - the design's "R ROTATE" is this game's
## `flip_module`, and a hint for a key that does nothing is worse than no hint.
func _refresh_text() -> bool:
	if _label == null or Global.ui_in_game == null:
		return false
	var data: ModuleData = Global.ui_in_game.cur_module
	if data == null:
		return false
	var parts: Array[String] = [data.name.to_upper()]
	var cost: String = BuildMenuModel.format_cost(data.resource_costs)
	if not cost.is_empty():
		parts.append(cost)
	if data.flippable:
		var key: String = ModeManager.action_hotkey_label(&"flip_module")
		if not key.is_empty():
			parts.append("%s FLIP" % key)
	_label.text = BuildMenuModel.META_SEPARATOR.join(parts)
	return true

## Follows the pointer in real time rather than on the sim clock: the ghost it
## annotates is drawn every frame whether or not the game is paused.
func _process(_delta: float) -> void:
	_follow_cursor()

func _follow_cursor() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var target: Vector2 = get_global_mouse_position() + CURSOR_OFFSET
	# reset_size first: the label's width changes with the module, and a Control
	# only ever grows to meet its minimum - it never shrinks back on its own, so
	# without this the box stays as wide as the widest module ever held.
	reset_size()
	target.x = clampf(target.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport.x - size.x - SCREEN_MARGIN))
	target.y = clampf(target.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport.y - size.y - SCREEN_MARGIN))
	global_position = target
