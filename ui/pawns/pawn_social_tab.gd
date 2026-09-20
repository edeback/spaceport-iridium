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

## Taken from the chrome palette rather than hand-mixed (WI-49: nothing in `ui/`
## names a colour of its own). Growth for a friendship, destructive for a feud,
## body text for indifference, and meta grey for a crewmate they have not met.
##
## These are applied as `font_color` overrides, **never** as `modulate` (WI-58).
## `modulate` multiplies the theme's own colour rather than replacing it, so
## `TEXT_META x TEXT` rendered "Not met" at 2.22:1 and `DESTRUCTIVE x TEXT`
## rendered a feud at 2.62:1 - three of these four failed the contrast floor
## while naming the right colour. It is WI-49's documented `self_modulate` trap
## in its `modulate` form.
const POSITIVE_COLOUR := UIPalette.GROWTH
const NEGATIVE_COLOUR := UIPalette.DESTRUCTIVE
const NEUTRAL_COLOUR := UIPalette.TEXT
const UNMET_COLOUR := UIPalette.TEXT_META

var pawn: PawnBase = null
var social: SocializeComponent = null

func set_pawn(_pawn: PawnBase) -> void:
	pawn = _pawn
	social = _pawn.get_component_by_type(SocializeComponent) as SocializeComponent
	if social == null:
		# Defensive only. WI-51 derives the crew tab set from the pawn's
		# components, so a pawn with no SocializeComponent never gets this tab
		# added in the first place - which is what retired the deferred
		# `set_tab_hidden` dance the old TabContainer needed (WI-48 deviation 7).
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
	row.add_theme_constant_override(&"separation", UIMetrics.INLINE_GAP)
	row.tooltip_text = _row_tooltip(other, record, met)
	row.mouse_filter = Control.MOUSE_FILTER_STOP  # let the tooltip show
	var name_label := Label.new()
	name_label.text = _display_name(other)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var tint: Color = _opinion_colour(value) if met else UNMET_COLOUR
	var status := Label.new()
	status.custom_minimum_size = Vector2(UIMetrics.SOCIAL_STATUS_WIDTH, 0)
	status.text = SocialMath.opinion_label(value) if met else "Not met"
	status.add_theme_color_override("font_color", tint)
	row.add_child(status)
	# Length = how strongly they feel, colour = which way. Empty for an
	# unmet crewmate, so the column still lines up without claiming a reading.
	#
	# A [HatchBar] rather than a tinted [ProgressBar]: `modulate` on a bar
	# multiplies its *track* as well as its fill, so a feud used to darken the
	# groove it sat in. The design's bar takes a fill colour and leaves the track
	# alone (WI-58).
	var bar := HatchBar.new()
	bar.custom_minimum_size = Vector2(UIMetrics.SOCIAL_BAR_WIDTH, 0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.fraction = (absf(value) / SocialMath.OPINION_MAX) if met else 0.0
	bar.fill_color = tint
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
	header.theme_type_variation = UIType.READOUT_LABEL
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
		line.theme_type_variation = UIType.META_LINE
		container.add_child(line)

func _muted_label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	return label

## The names come from a fresh `get_crew()` roster and from this tab's own pawn,
## which its handlers check before repainting - live or null (WI-71 §2c).
func _display_name(target: PawnBase) -> String:
	if target == null:
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
