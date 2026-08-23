class_name TutorialBridge
extends Node

## Everything a conversation may do to **the interface** (WI-63 §2), exposed to
## dialogue under the alias `guide`.
##
## WI-62 fixed the vocabulary at two aliases: `station` for what a conversation
## does to the simulation, `story` for what it remembers. This is the third, and
## it is a third rather than more verbs on `station` because it does a
## categorically different thing: **it is the only alias that touches the
## interface, and the only one that can block a conversation.**
##
## `station.credits(-300)` returns immediately and changes the sim.
## `guide.await_mode("build")` changes nothing and does not return until the
## player opens the Build panel. Folding a verb that suspends the conversation
## into the alias whose whole contract is "what this does to the simulation" would
## make that contract stop being true.
##
## ## How blocking works
##
## The addon awaits mutations: `dialogue_manager.gd` resolves a mutation with
## `return await thing.callv(method, args)`, and `_mutate` awaits that for any
## mutation not explicitly marked non-blocking. A verb here that is a GDScript
## coroutine therefore suspends the whole conversation until it returns. That is
## why this item needs no step machine of its own - **the onboarding script *is*
## the state machine**, written in the order the player experiences it, in a file
## an author can read.
##
## ## The two rules every wait obeys
##
## 1. **A wait whose condition is already true returns immediately** and arms
##    nothing. A player who opened Build before SAI asked must not be stuck
##    waiting for them to open it again.
## 2. **After [method abandon], every subsequent wait returns immediately.**
##    Ending the conversation is what actually happens, but the latch has to exist
##    regardless: a wait already suspended when abandon lands has to come back,
##    and the wait after it must not re-suspend. Without this, skipping the
##    tutorial stalls on the next gate with the sim held.
##
## **Ids arrive as plain `String`**, as everywhere else dialogue calls into the
## game: Godot's [Expression] rejects a `&"…"` literal outright.

## Emitted when a suspended wait's condition comes true, or when the tutorial is
## abandoned. One signal for both, because a wait must not care which happened.
signal step_resolved

## Emitted when a gate arms or clears, so [TutorialManager]'s probe surface and
## the cheat console can report what the player is being waited on.
signal waiting_changed(description: String)

## The coach mark this bridge raises. Handed over by [TutorialManager] once the
## HUD exists; null in a headless probe, where every `point` call is a no-op and
## the waits still work.
var coach: TutorialCoach = null

## What the current hint is about - a [PawnBase] or a [ModuleBase], or null for
## the onboarding and for hints whose trigger supplies nothing. Set by
## [TutorialManager] immediately before the conversation opens.
var subject: Node = null

## Whether this conversation was *supposed* to have a subject - [member
## TutorialHintData.has_subject].
##
## It exists to keep two different situations from producing the same message. A
## dialogue that asks for a subject its trigger never provides is an authoring
## mistake and must be loud. A subject that was alive when the hint fired and has
## since been freed - the crew member resigned and took the next ship while the
## advisory was queued behind another conversation - is ordinary, and erroring
## about it would train everybody to ignore the error that matters.
var expects_subject: bool = false

## The condition a suspended wait is watching, or an invalid Callable. Exactly one
## wait can be outstanding, because exactly one conversation can be on screen.
var _pending: Callable = Callable()
## Human-readable, for `dump_tutorial()` and the probe.
var _pending_description: String = ""
## Rule 2's latch.
var _abandoned: bool = false

func _ready() -> void:
	name = "TutorialBridge"

# --- wiring ---------------------------------------------------------------------

## Subscribes to everything a wait can be resolved by. Called by
## [TutorialManager] once the HUD is up, because three of the four sources are UI
## nodes that do not exist while the managers are readying.
##
## Connected once and never disconnected: these fire rarely (a mode change, a
## module placed), the handler is a single `is_valid()` test when nothing is
## waiting, and a connect/disconnect dance around each wait is a leak waiting to
## be written.
##
## **Idempotent, and called again on every mode change.** [BuildMenu] is built by
## a lazy factory (WI-50) - it does not exist until the player first opens BUILD,
## which is long after the HUD is up. Binding only once at bootstrap therefore
## left `flyout_changed` permanently unconnected, and the onboarding's "choose the
## Crew category" gate could never resolve: the player clicked the category, the
## conversation did not move, and the simulation stayed held with no way forward
## but the skip control. A mode change is exactly the moment the menu comes into
## existence, so re-binding there closes it with no polling.
func bind_sources() -> void:
	if not SignalBus.module_added.is_connected(_on_source_changed_module):
		SignalBus.module_added.connect(_on_source_changed_module)
	var main: UIMain = Global.ui_main
	if main != null and main.mode_manager != null:
		if not main.mode_manager.mode_changed.is_connected(_on_source_changed_mode):
			main.mode_manager.mode_changed.connect(_on_source_changed_mode)
	var menu: BuildMenu = _build_menu()
	if menu != null and not menu.flyout_changed.is_connected(recheck):
		menu.flyout_changed.connect(recheck)
	var in_game: UIInGame = Global.ui_in_game
	if in_game != null and not in_game.input_mode_changed.is_connected(_on_source_changed_input):
		in_game.input_mode_changed.connect(_on_source_changed_input)

# Three shims rather than three `.unbind(n)` call sites, so the arity each source
# carries is written down next to the source rather than as a bare number.
func _on_source_changed_module(_module: ModuleBase) -> void:
	recheck()

func _on_source_changed_mode(_new_mode: ModeManager.Mode, _previous: ModeManager.Mode) -> void:
	# The panel behind this mode has just been built if it did not exist. See
	# [method bind_sources] - this is how the lazily-built Build menu ever gets
	# listened to.
	bind_sources()
	recheck()

func _on_source_changed_input(_mode: UIInGame.InputMode) -> void:
	recheck()

## Re-tests the outstanding wait. Public because the cheat console drives it and
## because [TutorialManager] pokes it once after the HUD binds, in case the
## condition came true during the bind.
func recheck() -> void:
	if not _pending.is_valid():
		return
	if not bool(_pending.call()):
		return
	_pending = Callable()
	_pending_description = ""
	waiting_changed.emit("")
	step_resolved.emit()

## What the player is being waited on, or "" for nothing.
func waiting_for() -> String:
	return _pending_description

func is_waiting() -> bool:
	return _pending.is_valid()

## Re-arms for a new conversation. [TutorialManager] calls this before every run,
## because rule 2's latch must not outlive the tutorial it was set during - a
## skipped onboarding would otherwise make every later hint's gates no-ops.
func reset() -> void:
	_abandoned = false
	_pending = Callable()
	_pending_description = ""
	subject = null
	expects_subject = false

func was_abandoned() -> bool:
	return _abandoned

# --- pointing -------------------------------------------------------------------

## `$> guide.point("console:build", "Open the Build panel")`.
##
## Raises the coach mark on `target`, replacing whatever it was pointing at. The
## caption is the imperative; the prose belongs in the balloon line above it.
func point(target: String, caption: String) -> void:
	var parsed: TutorialTarget = TutorialTarget.parse(target)
	if not parsed.is_valid():
		return # parse() already errored, naming the string
	if coach == null or not is_instance_valid(coach):
		return # headless: the waits still work, there is simply nothing to draw on
	coach.show_mark(parsed, caption, subject)

## `$> guide.point_at_subject("This one")` - the pawn or module this hint is
## about.
##
## Selects it through [method InspectorPanel.select], which is the only sanctioned
## way to raise a selection surface and already draws the brackets and the shader
## tint. It does take the player's inspector away from whatever they had open;
## that is the same trade the alert feed's JUMP already makes, and a hint fires at
## most once.
func point_at_subject(caption: String) -> void:
	if subject == null or not is_instance_valid(subject):
		if not expects_subject:
			push_error("guide.point_at_subject: this conversation has no subject")
		return
	_select_subject()
	if coach == null or not is_instance_valid(coach):
		return
	coach.show_mark(TutorialTarget.new(TutorialTarget.Kind.SUBJECT), caption, subject)

## [method InspectorPanel.select] *toggles* on the already-selected subject, so a
## caller that does not check first can deselect the very thing it meant to point
## at. Every list row in the game does this check; so does this.
func _select_subject() -> void:
	var main: UIMain = Global.ui_main
	if main == null or main.inspector == null:
		return
	if main.inspector.selected_subject() == subject:
		return
	main.inspector.select(subject)

## `$> guide.clear_point()`.
func clear_point() -> void:
	if coach != null and is_instance_valid(coach):
		coach.clear_mark()

## `{{ guide.subject_name() }}` - who or what this hint is about.
func subject_name() -> String:
	if subject == null or not is_instance_valid(subject):
		return "that"
	if subject is PawnBase:
		var pawn: PawnBase = subject
		return pawn.pawn_name if not pawn.pawn_name.is_empty() else "A crew member"
	if subject is ModuleBase:
		var module: ModuleBase = subject
		if module.module_data != null:
			return module.module_data.name
		return "that module"
	return "that"

# --- waiting --------------------------------------------------------------------

## `$> guide.await_mode("build")` - until that console panel is open.
func await_mode(mode_id: String) -> void:
	var mode: ModeManager.Mode = _mode_by_id(mode_id)
	if mode == ModeManager.Mode.NONE:
		push_error("guide.await_mode: no such console mode '%s'" % mode_id)
		return
	await _suspend(_is_mode_open.bind(mode), "open the %s panel" % mode_id)

## `$> guide.await_category("crew")` - until the Build rail has that category
## showing.
func await_category(category_id: String) -> void:
	await _suspend(_is_category_open.bind(StringName(category_id)),
		"open the %s build category" % category_id)

## `$> guide.await_module_picked("mess_hall_mdata")` - until that module is the
## one on the cursor.
func await_module_picked(module_id: String) -> void:
	await _suspend(_is_module_held.bind(StringName(module_id)),
		"pick up the %s" % module_id)

## `$> guide.await_module_placed("mess_hall_mdata")` - until one exists on the
## grid. A blueprint counts: placement is the action being taught, and
## construction cannot start until the conversation ends and the sim resumes.
func await_module_placed(module_id: String) -> void:
	await _suspend(_is_module_placed.bind(StringName(module_id)),
		"place the %s" % module_id)

## The whole of both rules. Returns without suspending when the tutorial has been
## abandoned or the condition already holds; otherwise arms and waits.
func _suspend(check: Callable, description: String) -> void:
	if _abandoned:
		return
	if bool(check.call()):
		return
	_pending = check
	_pending_description = description
	waiting_changed.emit(description)
	await step_resolved

# --- conditions -----------------------------------------------------------------
# Each is a plain predicate over live state, never a remembered "it happened"
# flag. A player who satisfies a step, undoes it, and redoes it must not be able
# to get ahead of the script - and, more importantly, a step re-entered after a
# reload reads the world rather than a latch nothing saved.

func _is_mode_open(mode: ModeManager.Mode) -> bool:
	var main: UIMain = Global.ui_main
	if main == null or main.mode_manager == null:
		return false
	return main.mode_manager.is_open(mode)

func _is_category_open(category: StringName) -> bool:
	var menu: BuildMenu = _build_menu()
	if menu == null:
		return false
	return menu.flyout_open() and menu.open_category_id() == category

func _is_module_held(module_id: StringName) -> bool:
	var in_game: UIInGame = Global.ui_in_game
	if in_game == null or in_game.cur_module == null:
		return false
	return in_game.cur_module.id == module_id

func _is_module_placed(module_id: StringName) -> bool:
	if Global.world_manager == null or Global.save_manager == null:
		return false
	var data: ModuleData = Global.save_manager.get_module_data_by_id(module_id)
	if data == null:
		push_error("guide.await_module_placed: no such module id '%s'" % module_id)
		return true # never gate on a target that cannot exist
	return not Global.world_manager.get_modules_by_type(data).is_empty()

# --- abandoning -----------------------------------------------------------------

## `$> guide.abandon()`, and what the coach mark's skip control calls.
##
## Resolves the outstanding wait, sets rule 2's latch so every later wait in this
## conversation returns immediately, and asks [TutorialManager] to close the
## whole thing down. The order matters: the latch has to be set *before* the
## resolve, or the resumed conversation reaches its next gate and suspends again.
func abandon() -> void:
	_abandoned = true
	clear_point()
	if _pending.is_valid():
		_pending = Callable()
		_pending_description = ""
		waiting_changed.emit("")
		step_resolved.emit()
	if Global.tutorial_manager != null:
		Global.tutorial_manager.skip_tutorial()

# --- lookups --------------------------------------------------------------------

## The mode whose [constant ModeManager.LABELS] entry matches `id`,
## case-insensitively. Matching on the label rather than on the enum's integer
## keeps `.dialogue` files readable and keeps them working if the enum is
## reordered.
func _mode_by_id(id: String) -> ModeManager.Mode:
	var wanted: String = id.strip_edges().to_lower()
	for mode: ModeManager.Mode in ModeManager.LABELS:
		if ModeManager.LABELS[mode].to_lower() == wanted:
			return mode
	return ModeManager.Mode.NONE

func _build_menu() -> BuildMenu:
	var main: UIMain = Global.ui_main
	return main.build_menu() if main != null else null
