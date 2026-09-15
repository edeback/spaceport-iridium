class_name DialogueRunner
extends Node

## The one thing in the game that opens a conversation (WI-62 §6).
##
## Same rule, and the same reasoning, as [method InspectorPanel.select] being the
## only way to raise a selection surface: nothing else may instantiate a balloon.
## Everything that wants to say something calls [method run].
##
## It owns four things:
##
## - **The queue.** Two conversations never overlap. Same shape as
##   [member EventManager.pending_events], same reason.
## - **The balloon's lifecycle.** Deliberately *not* [method
##   DialogueManager.show_dialogue_balloon], which adds the balloon to
##   `get_current_scene()` - that puts its draw order **and** its
##   `_unhandled_input` order at the mercy of tree position. It mounts under
##   [UIMain]. What it draws over is **not** decided by that, though: the balloon
##   is a CanvasLayer, which draws and takes clicks by its layer number. Its
##   [constant DialogueBalloon.LAYER] puts it above the whole HUD, and
##   [constant PauseMenu.LAYER] puts the pause menu above it.
## - **The cast** ([SpeakerCast]) for the current conversation, which is what makes
##   a random face hold still across several lines.
## - **The two state contexts and the access filter** (§3), which is what makes
##   `station` and `story` the vocabulary rather than merely *a* vocabulary.
##
## A conversation that shows no line never mounts a balloon and never stops the
## sim. That is not a special case here: [DialogueBalloon] takes its pause hold
## when it renders its first line, so a cue that is nothing but mutations runs and
## returns null before anything has been shown. It is how a notification event and
## a face-to-face event share one code path.

## Where the runner puts a speaker's own name in the dialogue file. A character
## string that is not one of these is printed verbatim with no portrait - which is
## what makes narration work without ceremony.
const SPEAKER_CONTEXT: String = "station"
const STORY_CONTEXT: String = "story"

const BALLOON_SCENE: PackedScene = preload("res://ui/dialogue/balloon.tscn")

## Everything currently waiting to be said, front = next.
var _queue: Array[Dictionary] = []
var _balloon: DialogueBalloon = null
var _cast: SpeakerCast = null

## id -> definition, discovered from every content root.
var _speakers: Dictionary[StringName, SpeakerData] = {}

var bridge: DialogueBridge
var story: StoryState

func _ready() -> void:
	Global.dialogue_runner = self
	_load_speakers()
	_build_contexts()
	SignalBus.game_over.connect(_on_game_over)

## Unregisters both aliases. A context that outlived the scene swap would have the
## next run's dialogue talking to a freed node, and the addon holds contexts in a
## plain dictionary that nothing else clears.
func _exit_tree() -> void:
	var manager: Node = Engine.get_singleton("DialogueManager") as Node
	if manager != null:
		manager.call(&"unregister_state_context", SPEAKER_CONTEXT)
		manager.call(&"unregister_state_context", STORY_CONTEXT)
	if Global.dialogue_runner == self:
		Global.dialogue_runner = null

func _load_speakers() -> void:
	for path: String in ContentPaths.scan(ContentPaths.SPEAKERS):
		var speaker: SpeakerData = ResourceLoader.load(path) as SpeakerData
		if speaker == null:
			continue
		if not ContentPaths.accept_id(speaker.id, path, "SpeakerData"):
			continue
		_speakers[speaker.id] = speaker

# --- the state contexts ---------------------------------------------------------

## Registers `station` and `story`, and closes the door behind them.
##
## **Every autoload is already in scope whether we want it or not.** The addon's
## `_load_autoloads()` walks the scene-tree root and adds every autoload to
## `game_states` unconditionally - `include_singletons` gates a *different*
## lookup and does not help. So a `.dialogue` file can reach `Global.anything` or
## `SignalBus.anything` by default, and the only lever is
## `validate_member_access`. Setting it is what makes "the bridge is the
## vocabulary" a rule rather than a suggestion, and it is what makes a mod's
## `.dialogue` file safe to run at all (WI-47).
func _build_contexts() -> void:
	bridge = DialogueBridge.new()
	bridge.name = "DialogueBridge"
	add_child(bridge)

	story = StoryState.new()
	story.name = "StoryState"
	add_child(story)

	var manager: Node = Engine.get_singleton("DialogueManager") as Node
	if manager == null:
		push_error("DialogueRunner: the DialogueManager autoload is missing")
		return
	manager.call(&"register_state_context", SPEAKER_CONTEXT, bridge)
	manager.call(&"register_state_context", STORY_CONTEXT, story)
	manager.set(&"validate_member_access", _validate_access)
	# A denied access (or an author's typo) becomes a `push_error` rather than an
	# `assert(false)` that halts the game. A mistake in a `.dialogue` file must not
	# take a player's run down, and a headless probe cannot read a break.
	manager.set(&"ignore_missing_state_values", true)

## Returns "" to allow, or a sentence to deny. Only ever called with an Object -
## the addon guards on `is_instance_valid`, so a String's `.to_upper()` or an
## Array's `.size()` never reaches here.
func _validate_access(thing: Variant, member: StringName, kind: StringName) -> String:
	if thing is DialogueBridge or thing is StoryState or thing is DialogueBalloon:
		return ""
	# The third alias (WI-63). `guide` is registered by [TutorialManager] rather
	# than here - the runner has no business knowing the tutorial exists - but the
	# filter is this file's and has to know what it is allowed to let through.
	if thing is TutorialBridge:
		return ""
	# The addon's own objects: the resource is `self` inside a file, and lines and
	# responses are what a balloon inspects.
	if thing is DialogueResource or thing is DialogueLine or thing is DialogueResponse:
		return ""
	var thing_name: String = "an object"
	if thing is Object:
		var object: Object = thing
		thing_name = object.get_class()
		if object is Node:
			thing_name = String((object as Node).name)
	return ("Dialogue may only reach `station`, `story` and `guide` - refused %s `%s.%s`."
		% [kind, thing_name, member])

# --- running --------------------------------------------------------------------

## Opens `cue` in `resource`, queueing behind anything already talking.
##
## `on_finished` is called when this conversation ends, whether it showed a line
## or not - which is how [EventManager] knows to dequeue an event whose whole
## body was a mutation.
func run(resource: DialogueResource, cue: String = "",
		extra_states: Array = [], on_finished: Callable = Callable()) -> void:
	if resource == null:
		push_error("DialogueRunner: refusing to run a null dialogue resource")
		if on_finished.is_valid():
			on_finished.call()
		return
	_queue.append({
		"resource": resource,
		"cue": cue,
		"states": extra_states,
		"finished": on_finished,
	})
	if _balloon == null:
		_start_next()

## Whether a conversation is on screen or queued.
func is_busy() -> bool:
	return _balloon != null or not _queue.is_empty()

func queued_count() -> int:
	return _queue.size()

## The cast for the conversation currently running, or null. The balloon reads it;
## the probe asserts on it.
func cast() -> SpeakerCast:
	return _cast

func _start_next() -> void:
	if _queue.is_empty():
		_cast = null
		return
	var entry: Dictionary = _queue.pop_front()
	var resource: DialogueResource = entry["resource"]
	_cast = SpeakerCast.new(_speakers, NameGenerator.random_name)
	_balloon = BALLOON_SCENE.instantiate() as DialogueBalloon
	_balloon.cast = _cast
	_balloon.finished.connect(_on_conversation_finished.bind(entry), CONNECT_ONE_SHOT)
	_mount(_balloon)
	# `start` awaits the first line, and every mutation before it runs during that
	# await. A mutation-only cue therefore completes here, having shown nothing.
	_balloon.start(resource, entry["cue"], entry["states"])

## Under [UIMain] when there is one, so draw order and input order are the HUD's
## rather than the scene tree's. Falls back to the scene root for a probe or a
## test harness with no HUD.
func _mount(balloon: DialogueBalloon) -> void:
	var host: Node = Global.ui_main
	if host == null or not is_instance_valid(host):
		host = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(balloon)

func _on_conversation_finished(entry: Dictionary) -> void:
	_balloon = null
	_cast = null
	var callback: Callable = entry.get("finished", Callable())
	if callback.is_valid():
		callback.call()
	# Deferred so a callback that queues the *next* conversation (an event chain
	# resolving immediately) does not re-enter `_start_next` from inside the
	# balloon's own teardown.
	_start_next.call_deferred()

## Ends whatever is on screen now and drops anything queued behind it.
##
## Not new behaviour - [method _on_game_over] has always done exactly this - but
## naming it is what lets the tutorial's skip control end a conversation without
## anything else in the game learning how to touch a balloon. The one-door rule
## (§6, and [method InspectorPanel.select]'s twin) is about who may *open* one;
## closing needs a door too, and this is it.
func abandon() -> void:
	_queue.clear()
	if _balloon != null and is_instance_valid(_balloon):
		_balloon.finish()

## The run is over. Whatever was about to be said no longer matters, and the
## game-over screen owns the frame.
func _on_game_over(_reason: String) -> void:
	abandon()

# --- speakers -------------------------------------------------------------------

func speaker(id: StringName) -> SpeakerData:
	return _speakers.get(id)

## Every declared speaker. The probe sweeps this asserting each resolves a face.
func speakers() -> Array[SpeakerData]:
	return _speakers.values()
