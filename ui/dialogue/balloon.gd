class_name DialogueBalloon
extends CanvasLayer
## The one surface in the game that shows somebody saying something (WI-62).
##
## The balloon is neither a [ConsolePanel] nor a [ReadoutPanel]: it is a modal
## overlay, the same third kind of surface as the pause menu and the game-over
## screen. What it does share is the console's frame language - PANEL at panel
## alpha, an EDGE border, the 1px inner highlight that makes a surface read as lit
## from above, and the drop shadow that separates it from the station behind it.
##
## The scene authors structure and nothing else: every colour, size, gap and type
## variation comes from [UIPalette] / [UIMetrics] / [UIType], the same split
## [ConsolePanel] uses. A `Color` or a font size authored in `balloon.tscn` is a
## hex literal that stops tracking the palette the moment anyone retunes it, and
## `test_ui_theme.gd` sweeps the scenes for exactly that. This scene is **not** on
## that sweep's exemption list and must not be added to it.
##
## ## Four rules it carries (WI-62 §1)
##
## 1. **The pause hold is taken late.** [constant PAUSE_HOLD] is claimed when the
##    first real line renders, not in `_ready`. A cue that is nothing but
##    mutations returns null before anything is shown, so it never stops the sim -
##    which is how a notification event and a face-to-face event share one path
##    with no branch in [EventManager].
## 2. **`ui_cancel` is never swallowed.** Blocking all other input is what makes a
##    modal modal, but taking Esc would take the pause menu away, and the event
##    card this replaces never did that.
## 3. **The balloon is not on the Esc ladder.** Same considered exception as an
##    outstanding critical alert ([method UIMain._topmost_esc_claim]): a
##    conversation is something you answer, and an Esc that dismisses it is an
##    answer given without being read.
## 4. **A blocked response names its blocker on itself.** `hide_failed_responses`
##    stays false deliberately, so a response gated by an `[if …]` renders
##    disabled with its reason - the console UI's standing rule, applied here.
##
## ## The speaker
##
## The character at the head of a line is a [SpeakerData] id, resolved through the
## conversation's [SpeakerCast]. The cast is the whole of the brief's "the image
## should be stable over several lines" requirement: a speaker is resolved **once
## per conversation, not once per line**.

## Emitted when the conversation ends, whether or not it ever showed a line.
## [DialogueRunner] listens for it; nothing else should.
signal finished

## This balloon's entry in [TimeManager]'s hold set. A named hold rather than a
## remembered-prior-state flag, so a conversation and a critical alert can stop
## the sim at the same time without un-pausing each other.
const PAUSE_HOLD: StringName = &"dialogue"

## The dialogue resource
@export var dialogue_resource: DialogueResource

## Start from a given cue when using balloon as a [Node] in a scene.
@export var start_from_cue: String = ""

## If running as a [Node] in a scene then auto start the dialogue.
@export var auto_start: bool = false

## If all other input is blocked as long as dialogue is shown.
@export var will_block_other_input: bool = true

## The action to use for advancing the dialogue
@export var next_action: StringName = &"ui_accept"

## The action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"

## Who is in this conversation. Handed in by [DialogueRunner] before `start`; a
## balloon run standalone from the editor's Test Scene builds an empty one, which
## makes every character fall back to printing verbatim.
var cast: SpeakerCast = null

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
## Whether [constant PAUSE_HOLD] is currently ours. Rule 1: set by the first
## rendered line, cleared exactly once on the way out.
var _holding_pause: bool = false
## Latched so `finished` fires once even if the conversation ends twice (a null
## line and a `finish()` racing a game-over).
var _ended: bool = false

## The current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# The dialogue has finished so close the balloon
			finish()
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
	# Rule 4: a gated response renders, disabled, with its reason. Hiding it would
	# leave the player with no way to learn that the option exists.
	responses_menu.hide_failed_responses = false
	# ...and focus is wired by hand, after [method _label_blocked_responses] has had
	# its say. [DialogueResponsesMenu.configure_focus] indexes `get_menu_items()[0]`
	# unguarded, and that list excludes every disallowed row - so an all-blocked
	# line makes the addon throw "Out of bounds get index '0'" one frame before our
	# escape hatch exists. Deferring the call until the hatch is in place is the
	# whole fix, and it costs one line.
	responses_menu.auto_configure_focus = false

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	if auto_start:
		if not is_instance_valid(dialogue_resource):
			assert(false, DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _exit_tree() -> void:
	# Belt and braces: `finish()` releases the hold on every ordinary path, but a
	# balloon freed by a scene swap mid-conversation would otherwise leave the sim
	# stopped with nothing on screen to explain why.
	_release_pause()


func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_line):
		progress.visible = not dialogue_label.is_typing and dialogue_line.responses.size() == 0 and not dialogue_line.has_tag("voice")


## Rule 2. Blocking all other input is what makes a modal modal - but `ui_cancel`
## is the pause menu's, and taking it would leave a player mid-conversation unable
## to reach save/quit. The event card this replaces never took it either.
func _unhandled_input(event: InputEvent) -> void:
	if not will_block_other_input:
		return
	if event.is_action(&"ui_cancel"):
		return
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
	box.shadow_color = UIPalette.PANEL_SHADOW
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
func start(with_dialogue_resource: DialogueResource = null, cue: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not cue.is_empty():
		start_from_cue = cue
	# Every mutation before the first line runs inside this await. A cue that is
	# nothing but mutations therefore completes here, having shown nothing and -
	# rule 1 - having never taken the pause hold.
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_cue, temporary_game_states)
	show()


## Ends the conversation now, releasing the sim and freeing the balloon. The one
## exit; the null-line branch of `dialogue_line` and [DialogueRunner]'s game-over
## handler both come through here.
func finish() -> void:
	if _ended:
		return
	_ended = true
	_release_pause()
	balloon.hide()
	finished.emit()
	queue_free()


## Apply any changes to the balloon given a new [DialogueLine].
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	# Rule 1: the first line the player actually sees is what stops the sim.
	_hold_pause()

	progress.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	_apply_speaker()

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses
	_label_blocked_responses()

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
		# Real-time, not sim-time: the sim is held while a line is on screen, so
		# `TimeManager.sim_seconds` would never come back.
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Name and face, from the conversation's cast (WI-62 §4).
##
## The cast resolves a character **once**, so a pool-drawn face holds still for
## every line the speaker has. The placeholder this replaces rolled a new portrait
## here, on every line.
func _apply_speaker() -> void:
	var character: String = tr(dialogue_line.character, "dialogue")
	if cast == null:
		# Standalone (the editor's Test Scene, a probe with no runner): print the
		# character verbatim and show no face.
		character_label.visible = not character.is_empty()
		character_label.text = character
		portrait.texture = null
		portrait.visible = false
		return
	var member: SpeakerCast.Member = cast.resolve(character)
	character_label.visible = not member.display_name.is_empty()
	character_label.text = member.display_name
	portrait.texture = member.portrait()
	# The slot collapses rather than reserving 128px of nothing: narration is a
	# legitimate line and it should read as full-width prose.
	portrait.visible = portrait.texture != null


## Rule 4, plus the all-blocked guard. The rules themselves are [ResponseRules],
## where a GUT suite can reach them; this is the part that has to touch widgets.
##
## [DialogueResponsesMenu] has already disabled a failed response and suffixed its
## node name with "Disallowed"; what it cannot do is say *why*, because only the
## author knows.
func _label_blocked_responses() -> void:
	var responses: Array = dialogue_line.responses
	if responses.is_empty():
		return
	for item: Node in responses_menu.get_children():
		if not item.has_meta("response"):
			continue
		var response: DialogueResponse = item.get_meta("response") as DialogueResponse
		if response == null or response.is_allowed:
			continue
		var button: Button = item as Button
		if button == null:
			continue
		var label: String = ResponseRules.label_for(response)
		if button is ActionButton:
			(button as ActionButton).set_label(label)
		else:
			button.text = label
	if ResponseRules.is_all_blocked(responses):
		# Every option gated is an authoring mistake, not a game state: the player
		# is looking at a modal with no way out. Say so loudly and give them the
		# door - and do it *before* focus is wired, or the addon indexes an empty
		# list (see `auto_configure_focus` in `_ready`).
		push_error("DialogueBalloon: every response at line '%s' is blocked - the "
			% dialogue_line.id + "conversation would have had no way forward")
		responses_menu.add_child(_build_escape_hatch())
	responses_menu.configure_focus()


func _build_escape_hatch() -> Button:
	var button: ActionButton = ActionButton.create(
		ResponseRules.NO_OPTION_LABEL, ActionButton.Weight.SECONDARY)
	button.name = "ResponseEscape"
	button.caps = false
	button.set_label(ResponseRules.NO_OPTION_LABEL)
	# [DialogueResponsesMenu.configure_focus] reads `response` off every item it
	# wires, so the hatch has to carry one - and it carries a **real** response
	# pointing at END rather than a sentinel, so every path downstream (the click
	# handler, the keyboard handler, `next()`) works unmodified.
	#
	# `set_meta(name, null)` would have been the obvious sentinel and is a trap:
	# in Godot 4 a null value *deletes* the entry, so `get_meta("response")` then
	# errors on the very item that was supposed to carry it.
	var escape_response := DialogueResponse.new()
	escape_response.text = ResponseRules.NO_OPTION_LABEL
	escape_response.next_id = DMConstants.ID_END
	button.set_meta("response", escape_response)
	# Belt and braces alongside the menu's own click routing: `finish()` is latched,
	# so the duplicate costs nothing and a mouse click works even if focus wiring
	# did not happen.
	button.pressed.connect(finish)
	return button


## Go to the next line
func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


#region Pause


func _hold_pause() -> void:
	if _holding_pause or Global.time_manager == null:
		return
	_holding_pause = true
	Global.time_manager.hold_pause(PAUSE_HOLD)


func _release_pause() -> void:
	if not _holding_pause:
		return
	_holding_pause = false
	if Global.time_manager != null and is_instance_valid(Global.time_manager):
		Global.time_manager.release_pause(PAUSE_HOLD)


#endregion

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
