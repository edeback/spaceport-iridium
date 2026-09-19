class_name UnlockNodeCard
extends PanelContainer

## One node in the R&D panel's tech tree. Code-generated (no scene) so the panel
## can lay a whole tree out from the graph.
##
## **Four states, four treatments** (WI-55). The states were always here; what was
## missing was a vocabulary that told them apart at a glance across a 1400px
## panel:
##
## | State | Treatment |
## | --- | --- |
## | Researched | GROWTH edge, `RESEARCHED` |
## | Available, affordable | LIVE edge, **the cost in place of the state label** |
## | Available, unaffordable | dimmed LIVE edge, the cost in meta grey |
## | Locked | dashed edge, dimmed, showing the gate |
##
## "Cost renders in place of the state label when a tech is purchasable" is the
## rule that keeps a card to one line of secondary text: a node never needs to say
## both what it costs and what it is, because a purchasable node's state *is* its
## price.
##
## Costs are **credits and materials**, never research points (program decision
## 5). [member UnlockData.cost] is a `Dictionary[ResourceData, int]` and stays
## that way; the mockup's `120 RP` presumes an income stream this game does not
## have, and inventing one inside a UI rework is not the job.
##
## A locked node shows **one** gate, not both. A node behind an unmet prerequisite
## *and* an unmet station tier prints the prerequisite - the nearer of the two -
## because the second line a card would need to print both is the line that makes
## a grid of these unreadable.

## Card width. Every card and every empty cell is pinned to it so depth columns
## line up down a tree.
const CARD_WIDTH: int = 210
const ICON_SIZE: int = 40

## Godot's [StyleBoxFlat] has no dashed border, so a locked card's edge is drawn
## as the inert EDGE at reduced alpha instead. Same "this one is not for you yet"
## reading, and - unlike a `_draw()` dash pattern - a headless probe can see it.
const LOCKED_EDGE_ALPHA: float = 0.55
## How much of its colour an unaffordable card's edge keeps. Available but out of
## reach is a *dimmer* version of available, not a different state.
const UNAFFORDABLE_EDGE_ALPHA: float = 0.45

var unlock: UnlockData

var _icon: TextureRect
var _name_label: Label
var _state_label: Label
var _button: ActionButton

func setup(u: UnlockData) -> void:
	unlock = u
	custom_minimum_size = Vector2(float(CARD_WIDTH), 0.0)
	# Fixed width (never expand to fill the row) so depth columns line up.
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UIMetrics.UNLOCK_CARD_PAD)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	margin.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIMetrics.UNLOCK_CARD_HEAD_GAP)
	column.add_child(head)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(float(ICON_SIZE), float(ICON_SIZE))
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.texture = unlock.icon
	head.add_child(_icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", UIMetrics.UNLOCK_CARD_TEXT_GAP)
	head.add_child(text)

	_name_label = Label.new()
	_name_label.text = unlock.name
	_name_label.theme_type_variation = UIType.ENTITY_NAME
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_name_label)

	# The one line of secondary text: a cost, a gate, or `RESEARCHED`.
	_state_label = Label.new()
	_state_label.theme_type_variation = UIType.META_LINE
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_state_label)

	_button = ActionButton.create("Research", ActionButton.Weight.PRIMARY)
	_button.pressed.connect(_on_pressed)
	column.add_child(_button)

	# The description is the hover, not a fourth line. Inner controls go
	# transparent to the mouse so hovering anywhere on the card surfaces it; the
	# button keeps its own copy so it works while the button has the cursor.
	if unlock.description != "":
		tooltip_text = unlock.description
		_button.tooltip_text = unlock.description
	for control: Control in [margin, head, text, _icon, _name_label, _state_label]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	refresh()

func _on_pressed() -> void:
	# The panel listens to global_unlock_changed and repaints every card, so this
	# does not update itself.
	Global.unlock_manager.try_unlock(unlock)

## The four treatments, as a state rather than as four call sites that each
## remember to set five properties. [method state_of] is what the panel reads when
## it wants to know what a card is without asking the card.
enum State { RESEARCHED, AFFORDABLE, UNAFFORDABLE, LOCKED }

## Which of the four this node is in right now. Order matters: researched first
## (nothing else can be true of it), then the two gates, then affordability.
static func state_of(node: UnlockData) -> State:
	var manager: UnlockManager = Global.unlock_manager
	if manager.is_unlocked(node):
		return State.RESEARCHED
	if not manager.prerequisites_met(node) or not manager.meets_tier(node):
		return State.LOCKED
	return State.AFFORDABLE if node.can_afford() else State.UNAFFORDABLE

func state() -> State:
	return state_of(unlock)

func refresh() -> void:
	var manager: UnlockManager = Global.unlock_manager
	match state():
		State.RESEARCHED:
			_apply(State.RESEARCHED, UIPalette.GROWTH, 1.0, "Researched", UIPalette.GROWTH)
		State.LOCKED:
			if not manager.prerequisites_met(unlock):
				# The nearer gate wins: a node behind both an unmet prerequisite
				# and an unmet station tier says only that its prerequisite is
				# missing, because the second line it would take to say both is
				# the line that makes a grid of these unreadable.
				_apply(State.LOCKED, UIPalette.EDGE, LOCKED_EDGE_ALPHA,
					"Needs " + _prereq_names(), UIPalette.TEXT_META)
			else:
				# **Station** tier, spelled out. This panel's columns are
				# prerequisite depth and the design labels those "TIER" too; two
				# things called tier in one panel is how a bug gets written, so the
				# one that is ARC's business says which it is.
				#
				# Inert, like the other locked branch (WI-58). It wore amber, which
				# put fifteen amber pixels at rest into a tree of fifteen tier-gated
				# nodes - and WI-54's rule is "locked is a state, not an absence",
				# which is about *rendering* it, not about alarming on it.
				_apply(State.LOCKED, UIPalette.EDGE, LOCKED_EDGE_ALPHA,
					"Needs station tier %d" % unlock.min_tier, UIPalette.TEXT_META)
		State.AFFORDABLE:
			# The cost renders in place of the state label, so a purchasable node
			# never needs two lines.
			_apply(State.AFFORDABLE, UIPalette.LIVE, 1.0, cost_text(), UIPalette.TEXT)
		_:
			_apply(State.UNAFFORDABLE, UIPalette.LIVE, UNAFFORDABLE_EDGE_ALPHA,
				cost_text(), UIPalette.TEXT_META)

func _apply(kind: State, edge: Color, edge_alpha: float, state_text: String,
		state_color: Color) -> void:
	add_theme_stylebox_override("panel", _make_style(UIPalette.tinted(edge, edge_alpha)))
	_state_label.text = state_text.to_upper()
	_state_label.add_theme_color_override("font_color", state_color)
	var dim: bool = kind == State.LOCKED or kind == State.UNAFFORDABLE
	# A researched node has nothing left to buy, so it loses its button entirely
	# rather than wearing a dead one.
	_button.visible = kind != State.RESEARCHED
	_button.disabled = dim
	_button.weight = ActionButton.Weight.SECONDARY if dim else ActionButton.Weight.PRIMARY
	# Dimming the whole card is what makes a locked column read as a block at
	# 1400px, where a border colour alone does not.
	modulate = UIPalette.MODULATE_DIMMED if dim else Color.WHITE
	_name_label.add_theme_color_override("font_color",
		UIPalette.TEXT_META if dim else UIPalette.TEXT_EMPHASIS)

func _make_style(border_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.CONTROL_FILL
	box.set_border_width_all(UIMetrics.BORDER_WIDTH)
	box.border_color = border_color
	box.set_corner_radius_all(0)
	box.set_content_margin_all(2.0)
	return box

## The node's price, as its real resource costs. Public so the panel can print
## the same figure in a tooltip without re-deriving the format.
func cost_text() -> String:
	if unlock.cost.is_empty():
		return "Free"
	var parts: Array[String] = []
	for resource: ResourceData in unlock.cost:
		parts.append("%d %s" % [unlock.cost[resource], resource.name])
	return " · ".join(parts)

func _prereq_names() -> String:
	var parts: Array[String] = []
	for prereq: UnlockData in unlock.prerequisites:
		if prereq != null and not Global.unlock_manager.is_unlocked(prereq):
			parts.append(prereq.name)
	return ", ".join(parts)
