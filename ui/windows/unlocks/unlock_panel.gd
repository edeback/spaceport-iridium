class_name UnlockPanel
extends Control

## Global tech-tree panel. A full-rect overlay that dims the game and shows the
## trees stacked vertically, each flowing left-to-right: prerequisite depth is
## the horizontal axis, so same-depth siblings share a column and branches read
## clearly. Rebuilds on every global_unlock_changed so purchasing a node
## re-evaluates its dependents.
##
## WI-50 mounted it as the R&D mode with no internal changes; WI-55 reflows it
## into a 1400px panel with the tiers running left to right. Visibility and Esc
## belong to [ModeManager] now.

## Preferred top-to-bottom ordering of trees; any others follow alphabetically.
const TREE_ORDER: Array[StringName] = [&"power", &"food", &"industrial", &"defense"]

## Asks [ModeManager] to close this mode - see [ContractsScreen].
signal close_requested

var _trees_container: VBoxContainer
var _cards: Array[UnlockNodeCard] = []
## Station tier / promotion-goals header (WI-26).
var _tier_section: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	SignalBus.global_unlock_changed.connect(_on_unlock_changed)
	# Tier-up re-evaluates which nodes are tier-locked; goal progress refreshes
	# the tier panel section (WI-26).
	SignalBus.station_tier_changed.connect(_on_tier_changed)
	SignalBus.station_tier_progress_changed.connect(_on_tier_progress_changed)
	# Content is built lazily on first open (on_opened calls refresh), so we don't
	# build twice while the panel starts hidden.

## [ModeManager]'s open hook. This is also the panel's first build: the shell is
## empty until something asks for a refresh.
func on_opened() -> void:
	refresh()

func _build_shell() -> void:
	# Dimming backdrop that also swallows clicks meant for the game behind it.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var window := PanelContainer.new()
	window.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	window.custom_minimum_size = Vector2(760, 520)
	window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	window.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(window)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	window.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title bar: heading + close button.
	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)
	var title := Label.new()
	title.text = "Research"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 0)
	close_btn.pressed.connect(close_requested.emit)
	title_bar.add_child(close_btn)

	# Station tier / promotion-goals section (WI-26), above the trees. Rebuilt
	# wholesale on tier-up and goal progress.
	_tier_section = VBoxContainer.new()
	_tier_section.add_theme_constant_override("separation", 4)
	vbox.add_child(_tier_section)

	# Scrollable area holding the vertically-stacked trees. Scrolls both ways so
	# deep (wide) trees and many trees both stay reachable.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_trees_container = VBoxContainer.new()
	_trees_container.add_theme_constant_override("separation", 18)
	_trees_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_trees_container)

## Rebuild every tree from scratch.
func refresh() -> void:
	if _trees_container == null:
		return
	_refresh_tier_section()
	for child: Node in _trees_container.get_children():
		child.queue_free()
	_cards.clear()

	var by_tree := _unlocks_by_tree()
	for tree_id: StringName in _ordered_tree_ids(by_tree.keys()):
		_trees_container.add_child(_build_tree(tree_id, by_tree[tree_id]))

## Rebuilds the station-tier header: current tier, promotion goals with progress
## bars, required-facility checklist, and inspection status (WI-26).
func _refresh_tier_section() -> void:
	if _tier_section == null:
		return
	for child: Node in _tier_section.get_children():
		child.queue_free()
	var mgr := Global.unlock_manager
	var tier: int = mgr.current_tier
	var data: TierData = mgr.current_tier_data()
	var tier_name: String = data.display_name if data != null and data.display_name != "" else ""

	var heading := Label.new()
	heading.text = "Station Tier %d%s" % [tier, ("  —  " + tier_name) if tier_name != "" else ""]
	heading.theme_type_variation = UIType.READOUT_LABEL
	_tier_section.add_child(heading)

	if data == null or data.is_max_goal() or mgr.is_max_tier():
		var capped := Label.new()
		capped.text = "Top tier reached — the station answers to no further inspection."
		capped.theme_type_variation = UIType.BODY
		capped.add_theme_color_override("font_color", UIPalette.GROWTH)
		_tier_section.add_child(capped)
		_tier_section.add_child(_section_rule())
		return

	var goals_label := Label.new()
	goals_label.text = "Promotion goals (export the goods, then request an ARC inspection):"
	goals_label.theme_type_variation = UIType.BODY
	goals_label.add_theme_color_override("font_color", UIPalette.TEXT)
	_tier_section.add_child(goals_label)

	# Export goals with progress bars.
	for resource_id: StringName in data.export_goals:
		var goal: int = data.export_goals[resource_id]
		var have: int = mini(mgr.export_progress_for(resource_id), goal)
		var res: ResourceData = Global.save_manager.get_resource_by_id(resource_id)
		var res_name: String = res.name if res != null and res.name != "" else String(resource_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.text = "Export %s" % res_name
		name_label.custom_minimum_size.x = 150
		name_label.theme_type_variation = UIType.BODY
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(180, 14)
		bar.max_value = goal
		bar.value = have
		bar.show_percentage = false
		row.add_child(bar)
		var amount_label := Label.new()
		amount_label.text = "%d / %d" % [have, goal]
		amount_label.theme_type_variation = UIType.BODY
		amount_label.add_theme_color_override("font_color",
			UIPalette.GROWTH if have >= goal else UIPalette.TEXT)
		row.add_child(amount_label)
		_tier_section.add_child(row)

	# Required-facility checklist (module tags the inspector will tour).
	if not data.inspection_tags.is_empty():
		var facilities := Label.new()
		var parts: Array[String] = []
		for tag: String in data.inspection_tags:
			var built: bool = mgr.built_module_count_with_tag(tag) > 0
			parts.append("%s %s" % ["[x]" if built else "[ ]", tag])
		facilities.text = "Required facilities: " + "   ".join(parts)
		facilities.theme_type_variation = UIType.BODY
		facilities.add_theme_color_override("font_color", UIPalette.TEXT)
		_tier_section.add_child(facilities)

	# Inspection status line.
	var status := Label.new()
	status.theme_type_variation = UIType.BODY
	if mgr.is_inspection_active():
		status.text = "An ARC inspector is aboard, touring the station..."
		status.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)
	elif mgr.tier_goals_met():
		status.text = "Goals met — an ARC inspection will be offered shortly."
		status.add_theme_color_override("font_color", UIPalette.GROWTH)
	else:
		status.text = "Meet every goal and build the required facilities to earn an inspection."
		status.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
	_tier_section.add_child(status)
	_tier_section.add_child(_section_rule())

func _section_rule() -> Control:
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.12)
	rule.custom_minimum_size = Vector2(0, 2)
	return rule

## Width every card and spacer is pinned to, so depth columns line up across rows.
const CARD_WIDTH := 210

## One tree, laid out as a grid: prerequisite depth is the column (x), and each
## node shares a row (y) with its prerequisite, so a dependency chain reads along
## a single row and same-depth siblings stack. Empty cells are spacers so the
## columns stay aligned.
func _build_tree(tree_id: StringName, unlocks: Array[UnlockData]) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = String(tree_id).capitalize()
	header.theme_type_variation = UIType.READOUT_LABEL
	block.add_child(header)

	# Same-tree dependency graph: children[node] = nodes that require it.
	var children: Dictionary[UnlockData, Array] = {}
	for unlock: UnlockData in unlocks:
		children[unlock] = [] as Array[UnlockData]
	var roots: Array[UnlockData] = []
	for unlock: UnlockData in unlocks:
		var has_parent := false
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

	# Assign each node a row (a node takes its first child's row; leaves get the
	# next free row), and place it at its depth column.
	var rows: Dictionary[UnlockData, int] = {}
	var counter := 0
	for root: UnlockData in roots:
		counter = _assign_rows(root, children, rows, counter)

	var depth_cache: Dictionary[UnlockData, int] = {}
	var grid: Dictionary[Vector2i, UnlockData] = {}
	var max_depth := 0
	var max_row := 0
	for unlock: UnlockData in unlocks:
		var d := _depth(unlock, depth_cache)
		var r: int = rows.get(unlock, 0)
		while grid.has(Vector2i(d, r)):  # never overlap two cards in one cell
			r += 1
		grid[Vector2i(d, r)] = unlock
		max_depth = max(max_depth, d)
		max_row = max(max_row, r)

	var grid_box := VBoxContainer.new()
	grid_box.add_theme_constant_override("separation", 8)
	for r in range(max_row + 1):
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 16)
		for d in range(max_depth + 1):
			var unlock: UnlockData = grid.get(Vector2i(d, r), null)
			if unlock == null:
				row_box.add_child(_make_spacer())
			else:
				var card := UnlockNodeCard.new()
				card.setup(unlock)
				row_box.add_child(card)
				_cards.append(card)
		grid_box.add_child(row_box)
	block.add_child(grid_box)
	return block

## Depth-first row assignment: a node inherits its first child's row; leaves take
## the next free row. Returns the updated free-row counter.
func _assign_rows(node: UnlockData, children: Dictionary[UnlockData, Array], rows: Dictionary[UnlockData, int], counter: int) -> int:
	if rows.has(node):
		return counter
	var kids: Array = children.get(node, [])
	if kids.is_empty():
		rows[node] = counter
		return counter + 1
	var first_child_row := -1
	for kid: UnlockData in kids:
		counter = _assign_rows(kid, children, rows, counter)
		if first_child_row == -1:
			first_child_row = rows[kid]
	rows[node] = first_child_row
	return counter

func _make_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

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
	var d := 0
	for prereq: UnlockData in unlock.prerequisites:
		if prereq != null and prereq.tree_id == unlock.tree_id:
			d = max(d, _depth(prereq, cache) + 1)
	cache[unlock] = d
	return d

func _on_unlock_changed(_unlock: UnlockData) -> void:
	# Only refresh while visible; hidden panel rebuilds when reopened.
	if visible:
		for card: UnlockNodeCard in _cards:
			card.refresh()

## Tier-up (WI-26): re-evaluate every card's tier lock and the goals header.
func _on_tier_changed(_new_tier: int) -> void:
	if visible:
		_refresh_tier_section()
		for card: UnlockNodeCard in _cards:
			card.refresh()

## Goal progress / inspection state moved: just the header needs it.
func _on_tier_progress_changed() -> void:
	if visible:
		_refresh_tier_section()
