class_name QuotaTab
extends VBoxContainer

## The `QUOTA` tab of the Comms panel (WI-57 §5): what ARC wants before it will
## promote this station, and how far along the station is.
##
## This is WI-26's promotion block, **moved**. It sat in the Research panel's
## header from WI-26 until WI-55, which took it on loan and said so at the code -
## and the reason it had to move is one line long: the goals were in one panel and
## the button that submits them was nowhere, and once WI-57 gives that button a
## home the two must be in the same place. They are now: the `REQUEST INSPECTION`
## control lives in the Comms panel's permanent ARC block, one block above this
## tab, so a player reading their goals is looking at the thing that acts on them.
##
## Moving it also settles the ambiguity WI-55 flagged: R&D's columns are
## **prerequisite depth** and this is the **station tier**. With the station tier
## living here, "tier" stops meaning two things on one screen.
##
## Read-only. Everything here is reported; the one action is the button above it.

## Gauge width. The panel is 620px, so two goals sit side by side and a third
## wraps - which is why this is an [HFlowContainer] rather than the [HBoxContainer]
## the 1400px Research panel could get away with.
const GOAL_BAR_WIDTH: int = 268

var _section: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	_section = VBoxContainer.new()
	_section.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	add_child(_section)
	# Tier-up re-evaluates everything here; goal progress and inspection state move
	# the bars and the closing note (WI-26).
	SignalBus.station_tier_changed.connect(_on_tier_changed)
	SignalBus.station_tier_progress_changed.connect(refresh)
	refresh()

func _on_tier_changed(_new_tier: int) -> void:
	refresh()

## Rebuilt wholesale. It is a handful of bars and chips that change together, and
## the alternative is a reconciliation pass whose bugs would be invisible until a
## goal quietly stopped tracking.
func refresh() -> void:
	if _section == null:
		return
	for child: Node in _section.get_children():
		_section.remove_child(child)
		child.queue_free()
	var manager: UnlockManager = Global.unlock_manager
	if manager == null:
		return
	var data: TierData = manager.current_tier_data()
	var tier_name: String = data.display_name if data != null and data.display_name != "" else ""
	var heading: SectionLabel = SectionLabel.create(
		"Station tier %d%s" % [manager.current_tier, (" · " + tier_name) if tier_name != "" else ""])
	# Amber: this is ARC's demand of the station, which is one of the four
	# sanctioned uses of the budget (invariant 5).
	heading.accent_color = UIPalette.ATTENTION
	_section.add_child(heading)

	if data == null or data.is_max_goal() or manager.is_max_tier():
		_section.add_child(_note(
			"Top tier reached — the station answers to no further inspection.", UIPalette.GROWTH))
		return

	_build_goals(manager, data)
	_build_facilities(manager, data)
	_section.add_child(_status_note(manager))

## Export goals as gauges. Flowing rather than fixed columns: a modded tier can
## ask for four resources, and a row of four 268px bars in a 620px panel would run
## off the edge.
func _build_goals(manager: UnlockManager, data: TierData) -> void:
	var goals := HFlowContainer.new()
	goals.add_theme_constant_override("h_separation", UIMetrics.SECTION_GAP)
	goals.add_theme_constant_override("v_separation", UIMetrics.ROW_GAP)
	_section.add_child(goals)
	for resource_id: StringName in data.export_goals:
		var goal: int = int(data.export_goals[resource_id])
		var have: int = mini(manager.export_progress_for(resource_id), goal)
		var resource: ResourceData = Global.save_manager.get_resource_by_id(resource_id)
		var label: String = resource.name if resource != null and resource.name != "" \
			else String(resource_id)
		var bar: StatBar = StatBar.create()
		bar.custom_minimum_size.x = float(GOAL_BAR_WIDTH)
		bar.configure("Export %s" % label, float(have) / maxf(float(goal), 1.0),
			"%d / %d" % [have, goal], UIPalette.GROWTH if have >= goal else UIPalette.LIVE)
		goals.add_child(bar)

## The required-facility checklist: the module tags the ARC inspector will tour.
## A missing one is a guaranteed fail, which is why it renders beside the goals
## rather than being discovered when the tour aborts.
##
## Each chip **says** whether it is met rather than only being tinted. The
## Research panel's version was tint-only, and a screenshot of this tab showed
## `Industrial` and `Storage` side by side with one of them missing and the two
## reading as identical: a LIVE wash and an INERT one are six per cent apart on a
## 90px chip. `NEEDED` in amber is the ARC demand it actually is (invariant 5),
## and the count is what turns "build one" into "build one more".
func _build_facilities(manager: UnlockManager, data: TierData) -> void:
	if data.inspection_tags.is_empty():
		return
	var facilities := HFlowContainer.new()
	facilities.add_theme_constant_override("h_separation", UIMetrics.ROW_GAP)
	facilities.add_theme_constant_override("v_separation", UIMetrics.ROW_GAP)
	_section.add_child(facilities)
	for tag: String in data.inspection_tags:
		var count: int = manager.built_module_count_with_tag(tag)
		var chip: Chip = Chip.create()
		chip.configure(tag.capitalize(), "×%d" % count if count > 0 else "Needed",
			Color.TRANSPARENT, UIPalette.Row.LIVE if count > 0 else UIPalette.Row.AMBER)
		chip.tooltip_text = ("The inspector tours one %s module." % tag if count > 0
			else "Build a %s module — the inspector tours one and fails without it." % tag)
		facilities.add_child(chip)

## The closing line. It says what the *button* will do next, because the button is
## the point of this tab - the old wording ("an ARC inspection will be offered
## shortly") described a dice roll that no longer exists.
func _status_note(manager: UnlockManager) -> Label:
	match manager.inspection_block():
		UnlockManager.InspectionBlock.IN_PROGRESS:
			return _note("An ARC inspector is aboard, touring the station.",
				UIPalette.ATTENTION_TEXT)
		UnlockManager.InspectionBlock.COOLING_DOWN:
			return _note("ARC will not return for %d more cycle(s)."
				% manager.inspection_cooldown_remaining(), UIPalette.ATTENTION_TEXT)
		UnlockManager.InspectionBlock.READY:
			return _note("Everything ARC asks for is in place — request the inspection above.",
				UIPalette.GROWTH)
		UnlockManager.InspectionBlock.FACILITY_MISSING:
			return _note("Build a %s before requesting an inspection — the inspector tours one of each."
				% manager.missing_inspection_tag(), UIPalette.TEXT_SECONDARY)
		UnlockManager.InspectionBlock.NO_BAY:
			return _note("Goals met — build a docking bay for the ARC vessel to arrive at.",
				UIPalette.TEXT_SECONDARY)
		_:
			return _note("Meet every export goal and build the required facilities to earn a promotion.",
				UIPalette.TEXT_SECONDARY)

func _note(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UIType.BODY
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	return label
