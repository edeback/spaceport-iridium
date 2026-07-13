class_name UnlockPanel
extends Control

## Global tech-tree panel. A full-rect overlay that dims the game and shows the
## trees stacked vertically, each flowing left-to-right: prerequisite depth is
## the horizontal axis, so same-depth siblings share a column and branches read
## clearly. Rebuilds on every global_unlock_changed so purchasing a node
## re-evaluates its dependents.

## Preferred top-to-bottom ordering of trees; any others follow alphabetically.
const TREE_ORDER: Array[StringName] = [&"power", &"food", &"industrial"]

var _trees_container: VBoxContainer
var _cards: Array[UnlockNodeCard] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	SignalBus.global_unlock_changed.connect(_on_unlock_changed)
	# Content is built lazily on first open (toggle_unlock_panel calls refresh),
	# so we don't build twice while the panel starts hidden.

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()

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
	close_btn.pressed.connect(func() -> void: visible = false)
	title_bar.add_child(close_btn)

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
	for child: Node in _trees_container.get_children():
		child.queue_free()
	_cards.clear()

	var by_tree := _unlocks_by_tree()
	for tree_id: StringName in _ordered_tree_ids(by_tree.keys()):
		_trees_container.add_child(_build_tree(tree_id, by_tree[tree_id]))

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
	header.add_theme_font_size_override("font_size", 18)
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
