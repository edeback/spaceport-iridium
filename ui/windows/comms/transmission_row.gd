class_name TransmissionRow
extends VBoxContainer

## One row in the Comms panel's `INCOMING` feed (WI-57 §3).
##
## A [ListRow] header - 34px avatar slot, sender, subject line, and a timestamp or
## a `NEW` badge - with the body **folded underneath it**. Clicking the row expands
## it in place; clicking again folds it back.
##
## Expanding in place rather than opening a reader window is the WI's own edge
## case and it is the whole program in miniature: 620px with a 34px avatar fits a
## sender and a subject, not a paragraph, and the obvious fix - a second surface
## for the body - is precisely the twentieth window this rework exists to delete.
##
## **Unread is cyan, not amber.** It matches the alert feed's convention exactly,
## so the two lists teach each other; the amber that invariant 5 budgets for an
## unread transmission is spent once, on the console's COMMS badge, where a single
## amber pixel is doing the work of telling the player to come here at all.
##
## The header is a [ListRow] rather than a hand-rolled panel because that widget
## carries the ellipsis fix (WI-53): a non-autowrapping [Label] reports its full
## text width as its minimum, and a long subject line in a fixed-width panel grows
## out of *both* sides of it. Any list that hand-rolls its row rediscovers that.

## The avatar square. Sized for a faction portrait it does not have yet, which is
## the point - dropping one in later must not re-lay the list out.
const AVATAR_SIZE: int = 34

## Family -> avatar colour, until there are portraits. Deliberately **not** amber
## for ARC: the block above the feed is where ARC spends the budget, and an amber
## square on every second row would empty it.
##
## `arc` and `finance` share a colour on purpose, and a screenshot is what made
## that necessary: an `ARC settlement` and an `ARC inspection inbound` sat two
## rows apart under the same sender name wearing two different avatars, which read
## as two correspondents. The avatar is standing in for a portrait, and ARC has
## one face.
const FAMILY_COLORS: Dictionary[StringName, Color] = {
	&"arc": UIPalette.LIVE,
	&"finance": UIPalette.LIVE,
	&"trader": UIPalette.GROWTH,
	&"contract": UIPalette.LIVE_BRIGHT,
	&"event": UIPalette.TEXT_SECONDARY,
}

## What the row's action slot says while it is unread. The design's `NEW` badge,
## which replaces the timestamp rather than sitting beside it - at 620px less the
## avatar there is room for one of the two.
const UNREAD_BADGE: String = "New"

## Emitted when the row is expanded or folded, so the feed can re-fit around it.
signal toggled(row: TransmissionRow)
## Emitted when the player follows the transmission's route.
signal route_followed(route: StringName)
## Emitted when the player jumps to the transmission's live subject.
signal jump_requested(subject: Node2D)

var entry: TransmissionData = null

var _header: ListRow
var _body_host: PanelContainer
var _body_label: Label
var _action: ActionButton
var _expanded: bool = false

static func create() -> TransmissionRow:
	return TransmissionRow.new()

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build()

func _build() -> void:
	_header = ListRow.create()
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.pressed.connect(_on_header_pressed)
	add_child(_header)

	_body_host = PanelContainer.new()
	_body_host.visible = false
	var box := StyleBoxFlat.new()
	# Darker than the panel, so an open body reads as being *inside* the row it
	# came out of rather than as the next row down.
	box.bg_color = UIPalette.GAUGE_TRACK
	box.border_color = UIPalette.DIVIDER
	box.set_border_width_all(0)
	box.border_width_left = UIPalette.ROW_ACCENT_WIDTH
	box.set_corner_radius_all(0)
	box.content_margin_left = float(UIMetrics.CONTENT_PAD)
	box.content_margin_right = float(UIMetrics.CONTENT_PAD)
	box.content_margin_top = float(UIMetrics.ROW_GAP)
	box.content_margin_bottom = float(UIMetrics.ROW_GAP)
	_body_host.add_theme_stylebox_override("panel", box)
	add_child(_body_host)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_body_host.add_child(column)

	_body_label = Label.new()
	_body_label.theme_type_variation = UIType.BODY
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_color_override("font_color", UIPalette.TEXT)
	column.add_child(_body_label)

	_action = ActionButton.create("Open", ActionButton.Weight.SECONDARY)
	_action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_action.pressed.connect(_on_action_pressed)
	column.add_child(_action)

# --- binding --------------------------------------------------------------------

func bind(transmission: TransmissionData) -> void:
	entry = transmission
	refresh()

## Repaints from the record. Called again whenever the entry's read state moves,
## so the row can go from cyan to inert without the feed rebuilding under the
## player's cursor.
func refresh() -> void:
	if entry == null or _header == null:
		return
	var kind: UIPalette.Row = UIPalette.Row.LIVE if entry.unread else UIPalette.Row.INERT
	_header.configure(entry.sender, entry.subject,
		UNREAD_BADGE if entry.unread else entry.stamp(), kind)
	_header.set_swatch(FAMILY_COLORS.get(entry.family, UIPalette.INERT_ACCENT), AVATAR_SIZE)
	_header.tooltip_text = entry.body if not entry.body.is_empty() else entry.subject
	_body_label.text = entry.body if not entry.body.is_empty() else entry.subject
	# A transmission whose action went stale - an expired contract, a destroyed
	# module - keeps its text and loses its action, exactly like an alert whose
	# subject died.
	_action.visible = entry.has_action() and not _routes_here()
	_action.set_label(_action_label())

## Whether this row's route points at the panel the row is already inside.
##
## Every ARC message carries `route = &"comms"` so that clicking it *in the alert
## feed* lands here - which is right there and absurd here, where a screenshot
## caught an expanded ARC message offering to `OPEN COMMS`. The route stays on the
## record (the alert still needs it); the row just declines to draw a button that
## goes nowhere.
func _routes_here() -> bool:
	return entry != null and entry.subject_node() == null \
		and AlertFeed.ROUTES.get(entry.route, ModeManager.Mode.NONE) == ModeManager.Mode.COMMS

func _action_label() -> String:
	if entry == null:
		return ""
	if entry.subject_node() != null:
		return "Jump to it"
	return "Open %s" % _route_label()

func _route_label() -> String:
	var mode: ModeManager.Mode = AlertFeed.ROUTES.get(entry.route, ModeManager.Mode.NONE)
	return ModeManager.label_of(mode) if mode != ModeManager.Mode.NONE else "it"

# --- interaction ----------------------------------------------------------------

## The header press is *read and expand*, never "follow the route".
##
## Deliberately the opposite split from [AlertRow], where one press does both -
## and the reason is what each list is for. An alert is a thing to dispatch: the
## player clicks it to make it go away and land where it points. A transmission is
## a thing to read, and a row that navigated away the moment it was clicked would
## make reading one impossible.
func _on_header_pressed() -> void:
	set_expanded(not _expanded)

func set_expanded(value: bool) -> void:
	_expanded = value
	_body_host.visible = value
	if value and entry != null and entry.unread and Global.alert_manager != null:
		Global.alert_manager.mark_transmission_read(entry)
	refresh()
	toggled.emit(self)

func is_expanded() -> bool:
	return _expanded

func _on_action_pressed() -> void:
	if entry == null:
		return
	var node: Node2D = entry.subject_node()
	if node != null:
		jump_requested.emit(node)
		return
	if entry.route != &"":
		route_followed.emit(entry.route)
