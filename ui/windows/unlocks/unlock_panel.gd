class_name UnlockPanel
extends VBoxContainer

## The body of the R&D mode panel (WI-55): the global tech tree at 1400px.
##
## What was already right and is kept: each tree flows **left to right by
## prerequisite depth**, which is the design's own reading order - the eye starts
## at what is done and travels toward what is expensive, and a vertical tree
## fights the panel's shape. The graph layout is not what was wrong.
##
## What changed:
##
##   - the full-rect dimming overlay became a [ConsolePanel] like every other mode;
##   - the four trees stacked vertically in one scroll became **four tabs**, each
##     getting the full width. This is the single biggest legibility win here;
##   - each depth column is labelled and separated, with hairline connectors
##     leading into the cards that have a prerequisite behind them;
##   - the header carries the **credit balance**, because the header carries the
##     budget - and the currency is credits, never research points (program
##     decision 5).
##
## ## The two tiers
##
## The columns are **prerequisite depth**. [member UnlockData.min_tier] is the
## *station* tier (WI-26), a completely different axis, and it renders as a node
## state (`NEEDS STATION TIER 3`) rather than as a column. Everything in this file
## that says `depth` means the column; everything that says `tier` without
## qualification means the station's, exactly as [UnlockManager] uses it.
##
## The station-tier / promotion block at the top is WI-26's and is **on loan**: it
## moves to Comms with the rest of the ARC relationship in WI-57. It stays here
## until then so the goals are not homeless for a week.

## Preferred tab order; any other tree follows alphabetically.
const TREE_ORDER: Array[StringName] = [&"power", &"food", &"industrial", &"defense"]

## Width every card and every empty cell is pinned to, so depth columns line up
## across rows. Mirrors [constant UnlockNodeCard.CARD_WIDTH].
const CARD_WIDTH: int = UnlockNodeCard.CARD_WIDTH
## Horizontal gutter between depth columns - where the connectors live.
const COLUMN_GAP: int = 26
const ROW_GAP: int = 10
## Length of the hairline that leads into a card with a prerequisite behind it.
const CONNECTOR_LENGTH: int = COLUMN_GAP

var _frame: ConsolePanel
var _balance: Chip
var _tabs: TabStrip
var _scroll: ScrollContainer
var _tree_host: Control
var _tier_section: VBoxContainer
var _cards: Array[UnlockNodeCard] = []
## Tab order, so a rebuild can restore the player's tab.
var _tree_ids: Array[StringName] = []
var _open_tree: StringName = &""

## Builds the frame and mounts this body in it - one call, like the widgets have.
static func create() -> ConsolePanel:
	var frame: ConsolePanel = ConsolePanel.create()
	frame.title = "Research"
	frame.panel_width = UIMetrics.PANEL_RD_WIDTH
	frame.content_padding = 0
	frame.hotkey = ModeManager.hotkey_label(ModeManager.Mode.RND)
	# 1400px plus the 344px right column and its gutters is 1764 at 1920: it fits
	# only with the inspector out of the way, and selection means nothing here.
	frame.hides_inspector = true
	var body := UnlockPanel.new()
	body._frame = frame
	frame.content().add_child(body)
	return frame

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_header_control()
	_build_body()
	SignalBus.global_unlock_changed.connect(_on_unlock_changed)
	# Tier-up re-evaluates every node's tier gate; goal progress only moves the
	# promotion block (WI-26).
	SignalBus.station_tier_changed.connect(_on_tier_changed)
	SignalBus.station_tier_progress_changed.connect(_on_tier_progress_changed)
	# Affordability moves whenever credits do, and the header prints the balance.
	var credits: ResourceData = Global.resource_manager.credit_resource \
		if Global.resource_manager != null else null
	if credits != null:
		credits.total_changed.connect(_on_credits_changed)
	# Content is built on first open, so the panel does not build twice while it
	# starts hidden.

## [ModeManager]'s open hook, forwarded by the frame. Also this panel's first
## build: the shell is empty until something asks for a refresh.
func on_opened() -> void:
	refresh()

# --- construction --------------------------------------------------------------

## The credit balance, in the header's one control slot. "The header carries the
## budget" - and it is a balance, not an income: there is no research-point stream
## to project an ETA from, so there is no ETA.
func _build_header_control() -> void:
	_balance = Chip.create()
	_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_frame.add_header_control(_balance)

func _build_body() -> void:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", UIMetrics.CONTENT_PAD)
	pad.add_theme_constant_override("margin_right", UIMetrics.CONTENT_PAD)
	pad.add_theme_constant_override("margin_top", UIMetrics.CONTENT_PAD)
	add_child(pad)

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	pad.add_child(head)

	# WI-26's promotion block, on loan until WI-57 moves it to Comms.
	_tier_section = VBoxContainer.new()
	_tier_section.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	head.add_child(_tier_section)

	_tabs = TabStrip.create()
	_tabs.tab_selected.connect(_on_tab_selected)
	head.add_child(_tabs)

	# The trees scroll inside themselves so the tab strip and the promotion block
	# never leave the screen. Both axes: a deep tree is wider than 1400px, and
	# scroll-x is the answer the WI reserved for exactly that.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll_pad := MarginContainer.new()
	scroll_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "bottom"]:
		scroll_pad.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	scroll_pad.add_theme_constant_override("margin_top", UIMetrics.SECTION_GAP)
	scroll_pad.add_child(_scroll)
	add_child(scroll_pad)

	_tree_host = VBoxContainer.new()
	_tree_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_tree_host)

# --- refresh -------------------------------------------------------------------

## Rebuilds the open tree from scratch, keeping the player's tab.
func refresh() -> void:
	if _tree_host == null:
		return
	_refresh_balance()
	_refresh_tier_section()
	var by_tree: Dictionary = _unlocks_by_tree()
	_tree_ids = _ordered_tree_ids(by_tree.keys())
	var defs: Array = []
	for tree_id: StringName in _tree_ids:
		defs.append({"id": tree_id, "text": String(tree_id).capitalize()})
	# set_tabs keeps the selection if it survives, so a purchase does not throw
	# the player back to `power`.
	_tabs.set_tabs(defs)
	if _open_tree == &"" or not _tree_ids.has(_open_tree):
		_open_tree = _tabs.selected()
	_build_open_tree(by_tree)
	_apply_subtitle()

func _refresh_balance() -> void:
	if Global.resource_manager == null:
		return
	var credits: ResourceData = Global.resource_manager.credit_resource
	_balance.configure("Credits", LedgerModel.format_compact(credits.get_total()),
		Color(0, 0, 0, 0),
		UIPalette.Row.LIVE if Global.unlock_manager.has_affordable_unlock()
		else UIPalette.Row.INERT)

func _apply_subtitle() -> void:
	if _frame == null or not is_instance_valid(_frame):
		return
	if _open_tree == &"":
		_frame.subtitle = ""
		return
	var progress: Vector2i = Global.unlock_manager.tree_progress(_open_tree)
	_frame.subtitle = "%s · %d of %d complete" % [
		String(_open_tree).capitalize(), progress.x, progress.y]

## Repaints without rebuilding. A purchase changes what every *other* node's state
## is, but not the shape of the graph, so the usual case never has to touch the
## layout - which is what keeps the scroll position where the player left it.
func _repaint_cards() -> void:
	for card: UnlockNodeCard in _cards:
		if is_instance_valid(card):
			card.refresh()

func _on_credits_changed(_total: int) -> void:
	if not is_visible_in_tree():
		return
	_refresh_balance()
	_repaint_cards()

func _on_unlock_changed(_unlock: UnlockData) -> void:
	if not is_visible_in_tree():
		return
	_refresh_balance()
	_repaint_cards()
	_apply_subtitle()

## Tier-up (WI-26): re-evaluate every card's tier gate and the promotion block.
func _on_tier_changed(_new_tier: int) -> void:
	if is_visible_in_tree():
		_refresh_tier_section()
		_repaint_cards()

## Goal progress and inspection state moved: only the promotion block needs it.
func _on_tier_progress_changed() -> void:
	if is_visible_in_tree():
		_refresh_tier_section()

## Opens a tree by id, exactly as clicking its tab does.
##
## Public because a caller that reaches for the handler instead - a probe, the
## screenshot driver - swaps the grid while leaving the strip painted on the old
## tab, and the panel then shows one tree under another tree's name. Routing
## through the strip is what keeps the two halves of "which tree is open" from
## being two separate answers.
func select_tree(tree_id: StringName) -> void:
	if _tabs.selected() == tree_id:
		_on_tab_selected(tree_id)
		return
	_tabs.select(tree_id) # emits tab_selected, which lands in _on_tab_selected

## A tab press. This is the one path that *does* rebuild the grid, because the
## grid is a different tree.
func _on_tab_selected(tree_id: StringName) -> void:
	if tree_id == _open_tree:
		return
	_open_tree = tree_id
	_build_open_tree(_unlocks_by_tree())
	_apply_subtitle()
	# A new tree starts at its roots, not at wherever the last one was scrolled to.
	_scroll.scroll_horizontal = 0
	_scroll.scroll_vertical = 0

# --- the promotion block (WI-26, on loan) ---------------------------------------

func _refresh_tier_section() -> void:
	if _tier_section == null:
		return
	for child: Node in _tier_section.get_children():
		_tier_section.remove_child(child)
		child.queue_free()
	var manager: UnlockManager = Global.unlock_manager
	var data: TierData = manager.current_tier_data()
	var tier_name: String = data.display_name if data != null and data.display_name != "" else ""
	var heading: SectionLabel = SectionLabel.create(
		"Station tier %d%s" % [manager.current_tier, (" · " + tier_name) if tier_name != "" else ""])
	heading.accent_color = UIPalette.ATTENTION
	_tier_section.add_child(heading)

	if data == null or data.is_max_goal() or manager.is_max_tier():
		_tier_section.add_child(_note(
			"Top tier reached - the station answers to no further inspection.", UIPalette.GROWTH))
		return

	# Export goals, as bars in a row: at 1400px they fit side by side, where the
	# stacked version wasted the whole width on a 180px bar.
	var goals := HBoxContainer.new()
	goals.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	_tier_section.add_child(goals)
	for resource_id: StringName in data.export_goals:
		var goal: int = data.export_goals[resource_id]
		var have: int = mini(manager.export_progress_for(resource_id), goal)
		var resource: ResourceData = Global.save_manager.get_resource_by_id(resource_id)
		var label: String = resource.name if resource != null and resource.name != "" \
			else String(resource_id)
		var bar: StatBar = StatBar.create()
		bar.custom_minimum_size.x = 220.0
		bar.configure("Export %s" % label, float(have) / maxf(float(goal), 1.0),
			"%d / %d" % [have, goal], UIPalette.GROWTH if have >= goal else UIPalette.LIVE)
		goals.add_child(bar)

	# Required-facility checklist: the module tags the ARC inspector will tour.
	if not data.inspection_tags.is_empty():
		var facilities := HBoxContainer.new()
		facilities.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
		_tier_section.add_child(facilities)
		for tag: String in data.inspection_tags:
			var built: bool = manager.built_module_count_with_tag(tag) > 0
			var chip: Chip = Chip.create()
			chip.configure(tag.capitalize(), "", Color(0, 0, 0, 0),
				UIPalette.Row.LIVE if built else UIPalette.Row.INERT)
			facilities.add_child(chip)

	if manager.is_inspection_active():
		_tier_section.add_child(_note("An ARC inspector is aboard, touring the station.",
			UIPalette.ATTENTION_TEXT))
	elif manager.tier_goals_met():
		_tier_section.add_child(_note("Goals met - an ARC inspection will be offered shortly.",
			UIPalette.GROWTH))
	else:
		_tier_section.add_child(_note(
			"Meet every goal and build the required facilities to earn an inspection.",
			UIPalette.TEXT_SECONDARY))

func _note(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UIType.BODY
	label.add_theme_color_override("font_color", color)
	return label

# --- the tree grid ---------------------------------------------------------------

func _build_open_tree(by_tree: Dictionary) -> void:
	for child: Node in _tree_host.get_children():
		_tree_host.remove_child(child)
		child.queue_free()
	_cards.clear()
	if _open_tree == &"" or not by_tree.has(_open_tree):
		return
	var unlocks: Array[UnlockData] = by_tree[_open_tree]
	if unlocks.is_empty():
		# A mod can ship an empty tree; the tab renders and says so rather than
		# leaving a blank panel that reads as broken.
		_tree_host.add_child(_note("This tree has no research in it.", UIPalette.TEXT_META))
		return
	_tree_host.add_child(_build_tree(unlocks))

## One tree as a grid: prerequisite depth is the column, and each node shares a
## row with its first child so a dependency chain reads along a single row.
func _build_tree(unlocks: Array[UnlockData]) -> Control:
	# Same-tree dependency graph: children[node] = the nodes that require it.
	var children: Dictionary[UnlockData, Array] = {}
	for unlock: UnlockData in unlocks:
		children[unlock] = [] as Array[UnlockData]
	var roots: Array[UnlockData] = []
	for unlock: UnlockData in unlocks:
		var has_parent: bool = false
		for prereq: UnlockData in unlock.prerequisites:
			if prereq != null and children.has(prereq):
				children[prereq].append(unlock)
				has_parent = true
		if not has_parent:
			roots.append(unlock)
	var by_name := func(a: UnlockData, b: UnlockData) -> bool: return a.name < b.name
	roots.sort_custom(by_name)
	for node: UnlockData in children:
		children[node].sort_custom(by_name)

	# Assign each node a row (a node takes its first child's row; leaves take the
	# next free row) and place it at its depth column.
	var rows: Dictionary[UnlockData, int] = {}
	var counter: int = 0
	for root: UnlockData in roots:
		counter = _assign_rows(root, children, rows, counter)

	var depth_cache: Dictionary[UnlockData, int] = {}
	var grid: Dictionary[Vector2i, UnlockData] = {}
	var max_depth: int = 0
	var max_row: int = 0
	for unlock: UnlockData in unlocks:
		var d: int = _depth(unlock, depth_cache)
		var r: int = rows.get(unlock, 0)
		while grid.has(Vector2i(d, r)): # never overlap two cards in one cell
			r += 1
		grid[Vector2i(d, r)] = unlock
		max_depth = maxi(max_depth, d)
		max_row = maxi(max_row, r)

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", ROW_GAP)
	block.add_child(_depth_header(max_depth))
	for r: int in range(max_row + 1):
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 0)
		for d: int in range(max_depth + 1):
			var unlock: UnlockData = grid.get(Vector2i(d, r), null)
			# The gutter is a cell of its own so the connector has somewhere to be.
			row_box.add_child(_connector(unlock, d))
			if unlock == null:
				row_box.add_child(_spacer())
			else:
				var card := UnlockNodeCard.new()
				row_box.add_child(card)
				card.setup(unlock)
				_cards.append(card)
		block.add_child(row_box)
	return block

## The column captions. The design labels these `TIER 1 … TIER 5`; they are
## prerequisite depth, and the station tier a node may also need says
## `NEEDS STATION TIER n` on the card so the two never read as the same thing.
func _depth_header(max_depth: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	for d: int in range(max_depth + 1):
		var gutter := Control.new()
		gutter.custom_minimum_size.x = float(COLUMN_GAP)
		gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gutter)
		var caption := Label.new()
		caption.text = "TIER %d" % (d + 1)
		caption.theme_type_variation = UIType.READOUT_LABEL
		caption.add_theme_color_override("font_color", UIPalette.TEXT_META)
		caption.custom_minimum_size.x = float(CARD_WIDTH)
		row.add_child(caption)
	return row

## The hairline leading into a card that has a prerequisite behind it, drawn as a
## real [ColorRect] in the gutter rather than in a `_draw()` override - headless
## verification cannot see `_draw()` output, which is the same reason WI-50's
## console glyphs are authored SVGs.
func _connector(unlock: UnlockData, depth: int) -> Control:
	var gutter := Control.new()
	gutter.custom_minimum_size.x = float(COLUMN_GAP)
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if unlock == null or depth == 0:
		return gutter
	var line := ColorRect.new()
	# CONTROL_BORDER rather than EDGE: a 1px EDGE hairline over the panel fill is
	# very nearly invisible at 1×, which a screenshot showed and no probe could.
	line.color = UIPalette.CONTROL_BORDER
	line.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	line.offset_left = float(COLUMN_GAP - CONNECTOR_LENGTH)
	line.offset_right = float(COLUMN_GAP)
	line.offset_top = -0.5
	line.offset_bottom = 0.5
	line.grow_vertical = Control.GROW_DIRECTION_BOTH
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gutter.add_child(line)
	return gutter

func _spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(float(CARD_WIDTH), 0.0)
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

## Depth-first row assignment: a node inherits its first child's row; leaves take
## the next free row. Returns the updated free-row counter.
func _assign_rows(node: UnlockData, children: Dictionary[UnlockData, Array],
		rows: Dictionary[UnlockData, int], counter: int) -> int:
	if rows.has(node):
		return counter
	var kids: Array = children.get(node, [])
	if kids.is_empty():
		rows[node] = counter
		return counter + 1
	var first_child_row: int = -1
	for kid: UnlockData in kids:
		counter = _assign_rows(kid, children, rows, counter)
		if first_child_row == -1:
			first_child_row = rows[kid]
	rows[node] = first_child_row
	return counter

func _unlocks_by_tree() -> Dictionary:
	var by_tree: Dictionary = {}
	for unlock: UnlockData in Global.unlock_manager.get_all_unlocks():
		if not by_tree.has(unlock.tree_id):
			by_tree[unlock.tree_id] = [] as Array[UnlockData]
		by_tree[unlock.tree_id].append(unlock)
	return by_tree

func _ordered_tree_ids(ids: Array) -> Array[StringName]:
	var ordered: Array[StringName] = []
	for preferred: StringName in TREE_ORDER:
		if ids.has(preferred):
			ordered.append(preferred)
	var leftovers: Array[StringName] = []
	for id: StringName in ids:
		if not ordered.has(id):
			leftovers.append(id)
	leftovers.sort()
	return ordered + leftovers

## Longest prerequisite chain within the same tree (roots = 0).
func _depth(unlock: UnlockData, cache: Dictionary[UnlockData, int]) -> int:
	if cache.has(unlock):
		return cache[unlock]
	var d: int = 0
	for prereq: UnlockData in unlock.prerequisites:
		if prereq != null and prereq.tree_id == unlock.tree_id:
			d = maxi(d, _depth(prereq, cache) + 1)
	cache[unlock] = d
	return d
