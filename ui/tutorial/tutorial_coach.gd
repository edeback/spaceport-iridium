class_name TutorialCoach
extends Control

## The coach mark (WI-63 §3): a ring around a piece of the interface and a plate
## saying what to do with it.
##
## ## It is a fourth kind of surface, and it says so
##
## The console UI has three: the [ConsolePanel] (a mode), the [ReadoutPanel] (the
## right column), and the modal overlay (pause menu, game-over, balloon). This is
## none of them - it owns no content, it points at chrome that already exists, and
## there is at most one in existence at a time. [04_UI_Rework_Program] asks a new
## surface to declare which of the existing kinds it is; the honest answer here is
## "a fourth", which is written down rather than fudged.
##
## ## Four rules
##
## 1. **The ring is [constant UIPalette.LIVE], never [constant
##    UIPalette.ATTENTION].** Invariant 5: amber is a budget spent on breach,
##    falling vital, unread transmission and ARC. A tutorial pointer is not an
##    emergency - it is *"this one, right now"*, which is what cyan already means
##    everywhere in the console. The pulse, which nothing else in the HUD does, is
##    what makes it unmistakable without spending the budget.
## 2. **The pulse is real-time.** [method TimeManager.animation_speed] returns 0
##    while paused and the tutorial runs entirely while the sim is held, so a
##    pulse on sim time would sit frozen for the whole onboarding. This node is
##    deliberately **not** in the [constant Groups.SIM_ANIMATION] group.
## 3. **It re-resolves its target every frame.** A panel can close under it. When
##    the target cannot be found the ring hides and *the plate stays*, so the
##    instruction survives - a mark that vanished with its target would leave a
##    paused game with nothing on screen explaining why.
## 4. **It names no colour, size or type variation.** Everything comes from
##    [UIPalette] / [UIMetrics] / [UIType], and `tutorial_coach.tscn` is swept by
##    `test_ui_theme.gd` like every other scene under `ui/`. It must never be
##    added to that sweep's exemption list.
## 5. **It exists only while somebody is talking.** See [method
##    _outlived_its_conversation] - it takes itself down rather than trusting
##    every path that can end a conversation to remember to.
##
## The plate carries SAI's face and name because the balloon hides itself while a
## gate is waiting (the addon hides it on any non-inline mutation), and the
## console's pause line still reads "In conversation". The plate is what keeps
## that claim true.

const SCENE_PATH: String = "res://ui/tutorial/tutorial_coach.tscn"

## Emitted when the skip control is pressed. [TutorialManager] wires it to
## [method TutorialBridge.abandon]; this node does not know what skipping means.
signal skip_pressed

static func create() -> TutorialCoach:
	return (load(SCENE_PATH) as PackedScene).instantiate() as TutorialCoach

@onready var ring: Panel = $Ring
@onready var plate: PanelContainer = $Plate
@onready var pad: MarginContainer = $Plate/Pad
@onready var row: HBoxContainer = $Plate/Pad/Row
@onready var portrait: TextureRect = $Plate/Pad/Row/Portrait
@onready var column: VBoxContainer = $Plate/Pad/Row/Column
@onready var speaker_label: Label = $Plate/Pad/Row/Column/Speaker
@onready var caption_label: Label = $Plate/Pad/Row/Column/Caption
@onready var skip_row: HBoxContainer = $Plate/Pad/Row/Column/SkipRow
@onready var highlight: ColorRect = $Plate/Highlight

var _skip: ActionButton
## What is being pointed at, or null when nothing is up.
var _target: TutorialTarget = null
## The world subject, for [constant TutorialTarget.Kind.SUBJECT].
var _subject: Node = null
## Real seconds since the mark went up, for the pulse.
var _elapsed: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The coach must never eat a click meant for the control it is pointing at -
	# which is the entire point of it. Only the plate (and its skip button) take
	# input, and the ring is explicitly transparent.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_skip()
	_apply_theme()
	visible = false
	set_process(false)

func _build_skip() -> void:
	_skip = ActionButton.create("Skip the tutorial", ActionButton.Weight.DESTRUCTIVE)
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	skip_row.add_child(_skip)

# --- design system ------------------------------------------------------------

func _apply_theme() -> void:
	# Width is fixed and height is the content's - see [method _place_plate]. A
	# bare [Panel] was the first draft and reported a zero minimum height, so the
	# frame drew nothing and the text spilled over the console. Only a screenshot
	# showed it; a [PanelContainer] measures its child and cannot have that bug.
	plate.custom_minimum_size.x = float(UIMetrics.COACH_PLATE_WIDTH)
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	row.add_theme_constant_override("separation", UIMetrics.CONTENT_PAD)
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	var face := Vector2(float(UIMetrics.COACH_PORTRAIT), float(UIMetrics.COACH_PORTRAIT))
	portrait.custom_minimum_size = face
	portrait.custom_maximum_size = face
	highlight.custom_minimum_size.y = float(UIMetrics.BORDER_WIDTH)
	highlight.color = UIPalette.INNER_HIGHLIGHT
	speaker_label.add_theme_color_override("font_color", UIPalette.LIVE)
	caption_label.add_theme_color_override("font_color", UIPalette.TEXT_EMPHASIS)
	plate.add_theme_stylebox_override("panel", _plate_box())
	ring.add_theme_stylebox_override("panel", _ring_box())

## The frame [ConsolePanel] and the balloon wear, less the header: PANEL at panel
## alpha so the station reads faintly through it, all four EDGE borders because
## the plate floats free of every viewport edge, and the shared drop shadow.
func _plate_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.tinted(UIPalette.PANEL, UIMetrics.PANEL_ALPHA)
	box.border_color = UIPalette.LIVE
	box.set_border_width_all(UIMetrics.BORDER_WIDTH)
	box.set_corner_radius_all(0)
	box.set_content_margin_all(float(UIMetrics.BORDER_WIDTH))
	box.shadow_size = UIMetrics.PANEL_SHADOW_SIZE
	box.shadow_color = UIPalette.PANEL_SHADOW
	return box

## Border only - the ring frames a live control and must not tint it.
func _ring_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = UIPalette.LIVE
	box.set_border_width_all(UIMetrics.COACH_RING_WIDTH)
	box.set_corner_radius_all(0)
	return box

# --- raising and clearing -----------------------------------------------------

## Points at `target`, captioned `caption`. Replaces whatever was up: there is
## one mark, the same way there is one open mode and one selection.
func show_mark(target: TutorialTarget, caption: String, subject: Node = null) -> void:
	_target = target
	_subject = subject
	_elapsed = 0.0
	caption_label.text = caption
	speaker_label.text = _speaker_name()
	portrait.texture = _speaker_portrait()
	portrait.visible = portrait.texture != null
	visible = true
	set_process(true)
	_reposition()

func clear_mark() -> void:
	_target = null
	_subject = null
	visible = false
	set_process(false)

func is_marking() -> bool:
	return visible and _target != null

## What the mark is currently pointing at, for the probe and the cheat dump.
func marked_target() -> TutorialTarget:
	return _target

## Whether the ring is currently drawn - false for a SCREEN mark and for a target
## that could not be resolved. The probe asserts on this; so does rule 3.
func ring_visible() -> bool:
	return ring.visible

# --- the frame loop -----------------------------------------------------------

func _process(delta: float) -> void:
	# Real delta, deliberately unscaled - rule 2.
	_elapsed += delta
	if _outlived_its_conversation():
		clear_mark()
		return
	_reposition()
	_pulse()

## Rule 5, found by the probe: **a mark exists only while somebody is talking.**
##
## The mark is raised by a mutation inside a conversation, so it has no meaning
## outside one. [TutorialManager] clears it on the two finish callbacks it owns,
## but those are not the only ways a conversation can end - a game over, a quit to
## menu, or any future caller of [method DialogueRunner.abandon] all bypass them,
## and each would leave a plate and a pulsing ring on screen with nothing behind
## them. Asking the runner every frame makes that impossible rather than merely
## unlikely, which is the same argument rule 3 makes about the target.
##
## A null runner means there is no conversation system at all (a probe, a test
## harness), and a mark raised by hand in that situation is deliberate.
func _outlived_its_conversation() -> bool:
	var runner: DialogueRunner = Global.dialogue_runner
	return runner != null and is_instance_valid(runner) and not runner.is_busy()

## Rule 3. Resolution happens every frame rather than once at `show_mark`, because
## the flyout row this points at is built when the flyout opens and freed when it
## closes, and the console button moves when the window is resized.
func _reposition() -> void:
	if _target == null:
		return
	var rect: Rect2 = _resolve_rect()
	var found: bool = rect.size.x > 0.0 and rect.size.y > 0.0
	ring.visible = found and _target.wants_ring()
	if ring.visible:
		var padded: Rect2 = rect.grow(float(UIMetrics.COACH_RING_PAD))
		ring.position = padded.position
		ring.size = padded.size
	_place_plate(rect if found else Rect2())

## Beside the ring where there is room, otherwise centred at the top of the play
## area. Never *over* the ring: the plate exists to explain the control, and a
## plate covering it would be worse than no plate.
##
## It can still land over another panel - a mark on a console chip has the right
## column beside it and nowhere else to go on a 1080p screen. That is accepted:
## the plate is transient, the player is being told to look at one specific thing,
## and moving it far enough to clear every panel would move it away from the thing
## it is pointing at.
func _place_plate(rect: Rect2) -> void:
	var screen: Vector2 = size
	# Width first, then height: the caption autowraps, so its minimum height is
	# only meaningful once the container knows how wide it is. Running every frame
	# means the second frame has the right answer even when the first does not -
	# the same converge-rather-than-measure-once approach WI-51 landed on.
	plate.size.x = float(UIMetrics.COACH_PLATE_WIDTH)
	var plate_size := Vector2(
		float(UIMetrics.COACH_PLATE_WIDTH), plate.get_combined_minimum_size().y)
	plate.size = plate_size
	if rect.size.x <= 0.0:
		# Unresolved, or a SCREEN mark: centred near the **top** of the play area.
		#
		# The obvious slot - centred one gutter above the console - is exactly
		# where the balloon lives, and the balloon is a [CanvasLayer], so it draws
		# over every ordinary child of [UIMain] including this. A plate placed
		# there is invisible whenever anybody is talking, which for a SCREEN mark
		# is always. Only a screenshot showed it; the mark was up and correct and
		# simply behind something.
		plate.position = Vector2(
			(screen.x - plate_size.x) * 0.5, float(UIMetrics.SCREEN_GUTTER))
		return
	var gap: float = float(UIMetrics.COACH_PLATE_GAP + UIMetrics.COACH_RING_PAD)
	# Right of the target by preference; left when that would run off the edge.
	var x: float = rect.end.x + gap
	if x + plate_size.x > screen.x - float(UIMetrics.SCREEN_GUTTER):
		x = rect.position.x - gap - plate_size.x
	# Vertically centred on the target, then clamped into the play area so the
	# plate never slides under the console or off the top.
	var y: float = rect.get_center().y - plate_size.y * 0.5
	var top: float = float(UIMetrics.SCREEN_GUTTER)
	var bottom: float = (screen.y - float(UIMetrics.CONSOLE_HEIGHT)
		- float(UIMetrics.SCREEN_GUTTER) - plate_size.y)
	plate.position = Vector2(
		clampf(x, float(UIMetrics.SCREEN_GUTTER), maxf(top, screen.x - plate_size.x)),
		clampf(y, top, maxf(top, bottom)))

## Rule 1's other half: the ring breathes rather than blinking. A sine over a
## fixed real-time period, so two marks raised at different moments look the same.
func _pulse() -> void:
	if not ring.visible:
		return
	var phase: float = fmod(_elapsed, UIMetrics.COACH_PULSE_PERIOD) / UIMetrics.COACH_PULSE_PERIOD
	var wave: float = (sin(phase * TAU) + 1.0) * 0.5
	ring.modulate.a = lerpf(
		UIMetrics.COACH_PULSE_MIN_ALPHA, UIMetrics.COACH_PULSE_MAX_ALPHA, wave)

# --- resolution ---------------------------------------------------------------

## The screen rect of whatever [member _target] names, or a zero rect when it
## cannot be found right now. Never errors on a miss: a target that is legitimately
## absent this frame (the flyout is shut) is rule 3's normal case, not a fault.
func _resolve_rect() -> Rect2:
	match _target.kind:
		TutorialTarget.Kind.CONSOLE:
			return _control_rect(_console_button())
		TutorialTarget.Kind.CATEGORY:
			var menu: BuildMenu = _build_menu()
			return _control_rect(menu.rail_row(_target.id) if menu != null else null)
		TutorialTarget.Kind.MODULE:
			var menu: BuildMenu = _build_menu()
			return _control_rect(menu.list_row(_target.id) if menu != null else null)
		TutorialTarget.Kind.VITAL:
			var strip: VitalsStrip = _vitals()
			return _control_rect(strip.chip(_target.id) if strip != null else null)
		TutorialTarget.Kind.SUBJECT:
			return _subject_rect()
	return Rect2()

## The target is re-resolved from the live HUD every frame, so each lookup above
## answers with a control that is in the tree or with null (WI-71 §2c).
func _control_rect(control: Control) -> Rect2:
	if control == null or not control.is_visible_in_tree():
		return Rect2()
	return control.get_global_rect()

## A world subject's footprint, projected into screen space through the camera's
## canvas transform. A pawn walking while the mark is up therefore keeps the ring.
func _subject_rect() -> Rect2:
	if _subject == null or not is_instance_valid(_subject):
		return Rect2()
	var node2d: Node2D = _subject as Node2D
	if node2d == null or not node2d.is_inside_tree():
		return Rect2()
	var transform: Transform2D = node2d.get_viewport().get_canvas_transform()
	var local: Rect2 = _subject_local_rect(node2d)
	var top_left: Vector2 = transform * (node2d.global_position + local.position)
	return Rect2(top_left, local.size * transform.get_scale())

## A module's footprint is its cell size; a pawn's is a body-sized box above its
## feet, matching what [SelectionBrackets] frames.
func _subject_local_rect(node2d: Node2D) -> Rect2:
	if node2d is ModuleBase:
		var module: ModuleBase = node2d
		return Rect2(Vector2.ZERO, Vector2(module.size * Global.CELL_SIZE))
	return Rect2(Vector2(-16, -40), Vector2(32, 48))

# --- the speaker --------------------------------------------------------------

## SAI, resolved from content rather than hardcoded, so a mod that replaces the
## station AI replaces the coach's face with it.
func _speaker() -> SpeakerData:
	var runner: DialogueRunner = Global.dialogue_runner
	return runner.speaker(TutorialManager.SPEAKER_ID) if runner != null else null

func _speaker_name() -> String:
	var data: SpeakerData = _speaker()
	return data.display_name if data != null and not data.display_name.is_empty() else "SAI"

func _speaker_portrait() -> Texture2D:
	var data: SpeakerData = _speaker()
	return data.portrait if data != null else null

# --- HUD lookups --------------------------------------------------------------

func _console_button() -> ModeButton:
	var main: UIMain = Global.ui_main
	if main == null or main.console == null:
		return null
	for mode: ModeManager.Mode in ModeManager.LABELS:
		if ModeManager.LABELS[mode].to_lower() != String(_target.id).to_lower():
			continue
		return main.console.mode_button(mode)
	return null

func _build_menu() -> BuildMenu:
	var main: UIMain = Global.ui_main
	return main.build_menu() if main != null else null

func _vitals() -> VitalsStrip:
	var main: UIMain = Global.ui_main
	if main == null or main.console == null:
		return null
	return main.console.vitals()
