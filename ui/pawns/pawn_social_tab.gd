class_name PawnSocialTab
extends PanelContainer

## Who this pawn knows and what they make of them (WI-48).
##
## One row per other crew member - name, the word for how they feel, and a bar
## whose LENGTH is the strength of the feeling and whose COLOUR is its
## direction. A -100..+100 bar would sit half-full at indifference and read as
## mild approval, which is the wrong story.
##
## Crew they have never spoken to say so rather than showing "Neutral": not
## knowing someone and being indifferent to them are different states, and the
## panel is the only place that distinction is visible.
##
## Hidden for pawns with no SocializeComponent (robots, visitors) - the same
## component check that keeps them out of the system in the first place.

## Rows this far from zero get a colour; inside it everyone reads as neutral.
## Matches SocialMath.opinion_label's Neutral band so the word and the tint can
## never disagree.
const COLOUR_THRESHOLD: float = 20.0

## The tab grows with the roster up to this, then scrolls.
##
## It has to be driven from code because a ScrollContainer reports a minimum
## height of ZERO - it is built to be handed a size, not to ask for one - and
## every other tab in this panel sizes the panel to its own content instead.
## Left to itself the scroll collapsed to nothing and the tab rendered empty
## even though the rows underneath were correct.
const MAX_CONTENT_HEIGHT: float = 260.0

const POSITIVE_COLOUR := Color(0.55, 0.9, 0.6)
const NEGATIVE_COLOUR := Color(0.95, 0.55, 0.55)
const NEUTRAL_COLOUR := Color(1.0, 1.0, 1.0, 0.7)
const UNMET_COLOUR := Color(1.0, 1.0, 1.0, 0.45)

var pawn: PawnBase = null
var social: SocializeComponent = null

func set_pawn(_pawn: PawnBase) -> void:
	pawn = _pawn
	social = _pawn.get_component_by_type(SocializeComponent) as SocializeComponent
	if social == null:
		_hide_tab()
		return
	SignalBus.pawns_chatted.connect(_on_pawns_chatted)
	# The roster is read fresh on every rebuild, so a hire or a departure while
	# the panel is open would otherwise leave a stale row behind.
	SignalBus.crew_hired.connect(_on_roster_changed)
	SignalBus.crew_departed.connect(_on_roster_changed)
	# Backstop for the height fit below: a later layout pass (font metrics
	# settling, the panel entering the tree) can change what the rows ask for
	# after _rebuild has already measured them.
	(%SocialRows as Control).minimum_size_changed.connect(_fit_scroll_height)
	_rebuild()

## A TabContainer keeps drawing the tab button for a hidden child, so hiding the
## control alone would leave a robot with an empty "Social" tab.
func _hide_tab() -> void:
	visible = false
	var tabs := get_parent() as TabContainer
	if tabs != null:
		# Deferred: a TabContainer rebuilds its tab bar after children are added,
		# so a set_tab_hidden issued in the same frame as the add lands on an
		# index the bar does not have yet and silently does nothing - which left
		# robots with an empty Social tab button.
		tabs.set_tab_hidden.call_deferred(get_index(), true)

func _rebuild() -> void:
	var container: VBoxContainer = %SocialRows
	for child: Node in container.get_children():
		child.queue_free()
	_build_crew_rows(container)
	container.add_child(HSeparator.new())
	_build_log(container)
	_fit_scroll_height()

## Sizes the scroll to its content, capped. Deliberately synchronous and
## tree-agnostic: `ui_main` calls set_pawn on the panel BEFORE adding it to the
## tree, so anything here that awaited a frame or touched get_tree() would run
## against a null tree.
func _fit_scroll_height() -> void:
	var rows := %SocialRows as Control
	var scroll := rows.get_parent() as ScrollContainer
	if scroll == null:
		return
	scroll.custom_minimum_size.y = minf(rows.get_combined_minimum_size().y, MAX_CONTENT_HEIGHT)

func _build_crew_rows(container: VBoxContainer) -> void:
	# get_crew() already excludes robots and visitors, which is exactly the set
	# that can hold opinions.
	var others: Array[PawnBase] = []
	for crew: PawnBase in Global.crew_manager.get_crew():
		if crew != pawn:
			others.append(crew)
	if others.is_empty():
		container.add_child(_muted_label("No other crew aboard.", UNMET_COLOUR))
		return
	# Friends at the top, feuds at the bottom, everyone they don't have strong
	# feelings about in between.
	others.sort_custom(func(a: PawnBase, b: PawnBase) -> bool:
		return social.opinion_of(a.pawn_id) > social.opinion_of(b.pawn_id))
	for other: PawnBase in others:
		container.add_child(_make_row(other))

func _make_row(other: PawnBase) -> HBoxContainer:
	var record: PawnOpinion = social.record_of(other.pawn_id)
	var met: bool = record != null and record.chats > 0
	var value: float = record.value if record != null else 0.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.tooltip_text = _row_tooltip(other, record, met)
	row.mouse_filter = Control.MOUSE_FILTER_STOP  # let the tooltip show
	var name_label := Label.new()
	name_label.text = _display_name(other)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var status := Label.new()
	status.custom_minimum_size = Vector2(72, 0)
	status.text = SocialMath.opinion_label(value) if met else "Not met"
	status.modulate = _opinion_colour(value) if met else UNMET_COLOUR
	row.add_child(status)
	# Length = how strongly they feel, colour = which way. Empty for an
	# unmet crewmate, so the column still lines up without claiming a reading.
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(80, 10)
	bar.min_value = 0.0
	bar.max_value = SocialMath.OPINION_MAX
	bar.value = absf(value) if met else 0.0
	bar.show_percentage = false
	bar.modulate = _opinion_colour(value) if met else UNMET_COLOUR
	row.add_child(bar)
	return row

func _row_tooltip(other: PawnBase, record: PawnOpinion, met: bool) -> String:
	if not met:
		return "%s hasn't spoken to %s yet." % [_display_name(pawn), _display_name(other)]
	return "Opinion %+.0f · %d chat%s · last spoke %s" % [
		record.value,
		record.chats,
		"" if record.chats == 1 else "s",
		_format_stamp(record.last_cycle, record.last_hour),
	]

func _build_log(container: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Recent chats"
	header.add_theme_font_size_override(&"font_size", 11)
	container.add_child(header)
	var entries: Array[Dictionary] = social.recent_chats()
	if entries.is_empty():
		container.add_child(_muted_label("Nothing to report.", UNMET_COLOUR))
		return
	for entry: Dictionary in entries:
		var positive: bool = bool(entry.get("positive", true))
		var partner_name: String = String(entry.get("name", ""))
		if partner_name.is_empty():
			partner_name = "a crew member"
		var line := _muted_label("%s · %s — %s (%+.0f)" % [
			_format_stamp(int(entry.get("cycle", 0)), int(entry.get("hour", 0))),
			partner_name,
			"went well" if positive else "went badly",
			float(entry.get("delta", 0.0)),
		], POSITIVE_COLOUR if positive else NEGATIVE_COLOUR)
		line.add_theme_font_size_override(&"font_size", 11)
		container.add_child(line)

func _muted_label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = colour
	return label

func _display_name(target: PawnBase) -> String:
	if target == null or not is_instance_valid(target):
		return "Crew member"
	return target.pawn_name if not target.pawn_name.is_empty() else "Crew member"

func _format_stamp(cycle: int, hour: int) -> String:
	return "C%d %02d:00" % [cycle, hour]

func _opinion_colour(value: float) -> Color:
	if value >= COLOUR_THRESHOLD:
		return POSITIVE_COLOUR
	if value <= -COLOUR_THRESHOLD:
		return NEGATIVE_COLOUR
	return NEUTRAL_COLOUR

func _on_pawns_chatted(a: PawnBase, b: PawnBase, _positive: bool, _delta: float) -> void:
	if not is_instance_valid(pawn):
		return
	if a == pawn or b == pawn:
		_rebuild()

func _on_roster_changed(_pawn: PawnBase) -> void:
	if is_instance_valid(pawn) and social != null:
		_rebuild()
