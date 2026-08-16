extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.
##
## The balloon is neither a [ConsolePanel] nor a [ReadoutPanel]: it is a modal
## overlay, the same third kind of surface as the event card and the pause menu.
## What it does share is the console's frame language - PANEL at panel alpha, an
## EDGE border, the 1px inner highlight that makes a surface read as lit from
## above, and the drop shadow that separates it from the station behind it.
##
## The scene authors structure and nothing else: every colour, size, gap and type
## variation comes from [UIPalette] / [UIMetrics] / [UIType], the same split
## [ConsolePanel] uses. A `Color` or a font size authored in `balloon.tscn` is a
## hex literal that stops tracking the palette the moment anyone retunes it, and
## `test_ui_theme.gd` sweeps the scenes for exactly that.

## The dialogue resource
@export var dialogue_resource: DialogueResource

## Start from a given title when using balloon as a [Node] in a scene.
@export var start_from_title: String = ""

## If running as a [Node] in a scene then auto start the dialogue.
@export var auto_start: bool = false

## If all other input is blocked as long as dialogue is shown.
@export var will_block_other_input: bool = true

## The action to use for advancing the dialogue
@export var next_action: StringName = &"ui_accept"

## The action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"

## A sound player for voice lines (if they exist).
@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

## A dictionary to store any ephemeral variables
var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()

## The current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# The dialogue has finished so close the balloon
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

## A cooldown timer for delaying the balloon hide when encountering a mutation.
var mutation_cooldown: Timer = Timer.new()

## The base balloon anchor
@onready var balloon: Control = %Balloon

## The bordered surface itself, positioned and skinned in [method _apply_theme].
@onready var frame: PanelContainer = %Frame

## The 1px inner top highlight every surface in the console UI carries.
@onready var highlight: ColorRect = %Highlight

## Content padding inside the frame.
@onready var pad: MarginContainer = %Pad

## Portrait / text / indicator, left to right.
@onready var body: HBoxContainer = %Body

## The body above the responses.
@onready var column: VBoxContainer = %Column

## The speaking character's portrait
@onready var portrait: TextureRect = %Portrait

## The label showing the name of the currently speaking character
@onready var character_label: Label = %CharacterLabel

## The label showing the currently spoken dialogue
@onready var dialogue_label: DialogueLabel = %DialogueLabel

## The menu of responses
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu

## The slot holding the progress chevron.
@onready var indicator: Control = %Indicator

## Indicator to show that player can progress dialogue.
@onready var progress: Polygon2D = %Progress


func _ready() -> void:
	_apply_theme()
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	# If the responses menu doesn't have a next action set, use this one
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	if auto_start:
		if not is_instance_valid(dialogue_resource):
			assert(false, DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _process(delta: float) -> void:
	if is_instance_valid(dialogue_line):
		progress.visible = not dialogue_label.is_typing and dialogue_line.responses.size() == 0 and not dialogue_line.has_tag("voice")


func _unhandled_input(_event: InputEvent) -> void:
	# Only the balloon is allowed to handle input while it's showing
	if will_block_other_input:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	## Detect a change of locale and update the current dialogue line to show the new language
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio: float = dialogue_label.visible_ratio
		dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


#region Design system


func _apply_theme() -> void:
	_apply_layout()
	_apply_surface()
	_apply_indicator()


## Bottom-centred, one gutter above the console - the same budget the inspector
## takes, so the balloon never covers the console strip.
##
## The frame grows *upward* with its content (`grow_vertical` is BEGIN in the
## scene) because an anchored [Control] clamps its rect up to its combined
## minimum: a zero-height rect at the bottom edge would otherwise expand down
## over the console rather than up into the station.
func _apply_layout() -> void:
	var half: float = float(UIMetrics.DIALOGUE_WIDTH) * 0.5
	frame.offset_left = -half
	frame.offset_right = half
	frame.offset_bottom = -float(UIMetrics.CONSOLE_HEIGHT + UIMetrics.SCREEN_GUTTER)
	frame.offset_top = frame.offset_bottom
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	body.add_theme_constant_override("separation", UIMetrics.CONTENT_PAD)
	column.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	responses_menu.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	var portrait_size := Vector2(
		float(UIMetrics.DIALOGUE_PORTRAIT), float(UIMetrics.DIALOGUE_PORTRAIT))
	portrait.custom_minimum_size = portrait_size
	portrait.custom_maximum_size = portrait_size
	highlight.custom_minimum_size.y = float(UIMetrics.BORDER_WIDTH)


## The surface [ConsolePanel] and [ReadoutPanel] build, less the header: PANEL at
## panel alpha so the station reads faintly through it, and all four EDGE borders
## - unlike a mode panel, the balloon floats free of the viewport edges, so it
## wears the whole frame rather than one seam.
func _apply_surface() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.tinted(UIPalette.PANEL, UIMetrics.PANEL_ALPHA)
	box.border_color = UIPalette.EDGE
	box.set_border_width_all(UIMetrics.BORDER_WIDTH)
	box.set_corner_radius_all(0)
	# Children sit exactly inside the border - `Pad` owns the content padding - so
	# the highlight lands on the first row of pixels within the edge rather than
	# a content-pad's distance in from it.
	box.set_content_margin_all(float(UIMetrics.BORDER_WIDTH))
	box.shadow_size = UIMetrics.PANEL_SHADOW_SIZE
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	frame.add_theme_stylebox_override("panel", box)
	highlight.color = UIPalette.INNER_HIGHLIGHT


## The continue chevron: a downward triangle built from the one constant that
## also sizes the slot it sits in, so the glyph and its reserved space cannot
## disagree. LIVE, because "ready for you" is what cyan means everywhere else in
## the console.
func _apply_indicator() -> void:
	var size: Vector2 = UIMetrics.DIALOGUE_INDICATOR
	indicator.custom_minimum_size = size
	progress.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(size.x * 0.5, size.y), Vector2(size.x, 0.0)])
	progress.color = UIPalette.LIVE


#endregion


## Start some dialogue
func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	show()


## Apply any changes to the balloon given a new [DialogueLine].
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	progress.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")
	var portrait_path: String = "res://assets/external/thirstsector_portraits/%s.png" % dialogue_line.character.to_lower()
	if FileAccess.file_exists(portrait_path):
		portrait.texture = load(portrait_path)
	else:
		# Pick a random one for now
		portrait.texture = load("res://assets/external/thirstsector_portraits/portrait%d.png" % randi_range(12, 49))

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	# Show our balloon
	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	# Wait for next line
	if dialogue_line.has_tag("voice"):
		audio_stream_player.stream = load(dialogue_line.get_tag_value("voice"))
		audio_stream_player.play()
		await audio_stream_player.finished
		next(dialogue_line.next_id)
	elif dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Go to the next line
func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	# See if we need to skip typing of the dialogue
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	# When there are no response options the balloon itself is the clickable thing
	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)


#endregion
