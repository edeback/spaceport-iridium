class_name StandingTab
extends VBoxContainer

## The `STANDING` tab of the Comms panel (WI-62 §5): how the station stands with
## the powers around it.
##
## Comms is the "talk to someone" panel, so it is where the record of who the
## station has been talking to belongs. It is a tab rather than a fourth block
## above the tab strip - which is what the WI sketched - because the ARC block
## already owns that space and its amber is invariant 5's one spend on this panel.
## A second permanent block would push the feed down on every station, including
## the many that have never met anybody.
##
## **This is a record, not a lever, and it says so.** In v1 standing gates
## dialogue and renders here; it does not change arrival pacing, raid frequency or
## prices. Printing a number with no consequence and letting the player infer one
## would be worse than admitting it, so [constant CommsPanel.FOOTER_STANDING]
## admits it - in the frame's footer strip, which is where a panel's standing
## instruction goes, rather than as a row at the bottom of scrolling content.
##
## Read-only. Nothing here is an action - the way to move a standing is to be in
## a conversation and choose something.

## Bar width. The panel is 620px with content padding either side, so one
## standing per row with the band name right-aligned.
const BAR_WIDTH: int = 320

## Which way the bar reads. Built from the band table rather than typed, so
## renaming a band renames this too.
static var SCALE_LABEL: String = "%s to %s" % [
	FactionStanding.band_name(FactionStanding.Band.HOSTILE),
	FactionStanding.band_name(FactionStanding.Band.ALLIED)]

## What an unscored faction prints instead of a band. ARC is the only one today,
## and the reason is worth carrying on screen rather than only in the code: the
## tier ladder already *is* the ARC relationship.
const UNSCORED_NOTE: String = "Measured by your tier, not by a number here"

var _list: VBoxContainer
var _empty: Label

func _ready() -> void:
	add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	var section: SectionLabel = SectionLabel.create("Standing")
	add_child(section)

	_empty = Label.new()
	_empty.theme_type_variation = UIType.META_LINE
	_empty.text = "NOBODY OUT THERE KNOWS YOU YET"
	_empty.add_theme_color_override("font_color", UIPalette.TEXT_META)
	add_child(_empty)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	scroll.add_child(_list)

	refresh()

func refresh() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		child.queue_free()
	var story: StoryState = Global.story_state
	if story == null:
		_empty.visible = true
		return
	var factions: Array[FactionData] = story.factions()
	_empty.visible = factions.is_empty()
	for faction: FactionData in factions:
		_list.add_child(_build_row(faction, story))

func _build_row(faction: FactionData, story: StoryState) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	column.add_child(head)

	var name_label := Label.new()
	name_label.text = faction.display_name
	name_label.theme_type_variation = UIType.ENTITY_NAME
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)

	if faction.scored:
		var value: float = story.standing.standing(faction.id)
		var band: FactionStanding.Band = FactionStanding.band_for(value)
		var tint: Color = _band_color(band)

		var band_label := Label.new()
		band_label.text = FactionStanding.band_name(band).to_upper()
		band_label.theme_type_variation = UIType.META_LINE
		band_label.add_theme_color_override("font_color", tint)
		head.add_child(band_label)

		var bar: StatBar = StatBar.create()
		bar.custom_minimum_size.x = float(BAR_WIDTH)
		# **The bar's label is the scale, not the name.** The head row above it
		# already carries the faction, and a screenshot of the first draft showed
		# every row printing its name twice, once in each type size. What the bar
		# does owe the player is which way it reads, and the ends of the ladder are
		# the honest answer - built from the band table so the two cannot drift.
		bar.configure(SCALE_LABEL, FactionStanding.fraction(value),
			"%+.2f" % value, tint)
		column.add_child(bar)

		var detail := Label.new()
		detail.theme_type_variation = UIType.BODY
		detail.text = FactionStanding.band_detail(band)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
		column.add_child(detail)
	else:
		var unscored := Label.new()
		unscored.theme_type_variation = UIType.META_LINE
		unscored.text = UNSCORED_NOTE.to_upper()
		unscored.add_theme_color_override("font_color", UIPalette.TEXT_META)
		unscored.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		head.add_child(unscored)

		var detail := Label.new()
		detail.theme_type_variation = UIType.BODY
		detail.text = faction.description
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
		column.add_child(detail)
	return column

## Cyan for warm, amber for cold. **Amber is a budget** (invariant 5) and this is
## deliberately inside it: a faction that has turned on you is the same category
## of thing as a falling vital - a state you are meant to notice and can still
## act on. Neutral takes neither and stays secondary text.
func _band_color(band: FactionStanding.Band) -> Color:
	match band:
		FactionStanding.Band.ALLIED, FactionStanding.Band.WARM:
			return UIPalette.LIVE
		FactionStanding.Band.HOSTILE, FactionStanding.Band.COLD:
			return UIPalette.ATTENTION
		_:
			return UIPalette.TEXT_SECONDARY
