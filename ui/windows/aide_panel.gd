class_name AidePanel
extends VBoxContainer

## The body of the AIDE mode panel (WI-63 §8): everything SAI has told you, and
## the introduction, replayable.
##
## WI-50 reserved this console slot and its F1 binding and left the button
## disabled with *"Assistance is not available yet"*; the UI rework program named
## the Phase-4 onboarding item as its mount point. This is that item, so the
## button stops lying.
##
## ## Why it exists rather than being cut
##
## Two reasons, and the second is the load-bearing one. An advisory fires **once
## per run** - a player who was mid-placement when it appeared and clicked through
## it has lost it. And skipping the tutorial, from either door, spends every hint
## at once; without somewhere to go afterwards, "Skip Onboarding" would be an
## irreversible decision made on the New Game screen by somebody who has not seen
## the game yet.
##
## ## What it does not do
##
## It does not name the advisories that have not fired. The footer counts them,
## because knowing that SAI still has things to say is useful and knowing what
## they are in advance is a list of mistakes you have not made yet.
##
## It also carries no console adornment. The badge is amber and amber is a budget
## (invariant 5) that Comms already spends its count on; a second counter would be
## the third thing competing for the same glance.

const FOOTER: String = "Click an entry to hear it again"

## What the footer says when there is nothing yet - which is every station for
## its first few cycles, and every station whose player skipped nothing.
const EMPTY_LINE: String = "SAI has not needed to say anything yet"

var _frame: ConsolePanel
var _list: VBoxContainer

static func create() -> ConsolePanel:
	var frame: ConsolePanel = ConsolePanel.create()
	frame.title = "SAI Advisory"
	frame.panel_width = UIMetrics.PANEL_AIDE_WIDTH
	frame.hotkey = ModeManager.hotkey_label(ModeManager.Mode.AIDE)
	frame.footer_text = FOOTER
	frame.footer_variation = UIType.BODY
	var body := AidePanel.new()
	body._frame = frame
	frame.content().add_child(body)
	return body._frame

func _ready() -> void:
	add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	scroll.add_child(_list)

## [ModeManager] hides panels rather than freeing them, so the refresh belongs on
## the open hook - the archive grows while this panel is shut.
func on_opened() -> void:
	_rebuild()

func _rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var manager: TutorialManager = Global.tutorial_manager
	if manager == null:
		return
	_build_introduction(manager)
	_build_archive(manager)
	_apply_footer(manager)

func _build_introduction(manager: TutorialManager) -> void:
	_list.add_child(SectionLabel.create("Introduction"))
	var row: ListRow = ListRow.create()
	var meta: String = "Not yet heard"
	if manager.ledger.skipped:
		meta = "Skipped"
	elif manager.ledger.onboarding_done:
		meta = "Heard"
	row.configure("Welcome aboard", meta, "Replay ▸",
		UIPalette.Row.LIVE if not manager.ledger.onboarding_done else UIPalette.Row.INERT)
	row.pressed.connect(_on_replay_onboarding)
	_list.add_child(row)

func _build_archive(manager: TutorialManager) -> void:
	_list.add_child(SectionLabel.create("Advisories"))
	var given: Array[TutorialHintData] = manager.given_hints()
	if given.is_empty():
		var empty := Label.new()
		empty.text = EMPTY_LINE
		empty.theme_type_variation = UIType.BODY
		empty.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
		_list.add_child(empty)
		return
	for hint: TutorialHintData in given:
		var row: ListRow = ListRow.create()
		var title: String = hint.title if not hint.title.is_empty() else String(hint.id)
		row.configure(title, hint.body, "Replay ▸")
		row.pressed.connect(_on_replay_hint.bind(hint.id))
		_list.add_child(row)

## The count of what is still to come, never the names. Also the one place the
## panel admits the tutorial was skipped, which is the difference the ledger keeps
## [method TutorialLedger.mark_legacy] and [method TutorialLedger.skip] apart for.
func _apply_footer(manager: TutorialManager) -> void:
	if _frame == null:
		return
	var unseen: int = manager.unseen_count()
	if manager.ledger.skipped:
		_frame.footer_text = "Onboarding was skipped · everything above is still replayable"
	elif unseen > 0:
		_frame.footer_text = "%s · %d advisory notice%s not yet given" % [
			FOOTER, unseen, "" if unseen == 1 else "s"]
	else:
		_frame.footer_text = FOOTER

func _on_replay_onboarding() -> void:
	if Global.tutorial_manager != null:
		Global.tutorial_manager.replay_onboarding()

func _on_replay_hint(id: StringName) -> void:
	if Global.tutorial_manager != null:
		Global.tutorial_manager.replay_hint(id)
