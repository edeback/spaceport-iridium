class_name BuildMenu
extends VBoxContainer

## The body of the BUILD mode panel: a search field, the recently-built strip,
## and a fixed category rail that opens a 340px flyout beside the panel.
##
## WI-43 replaced the old per-tag `FoldableContainer` accordion (whose single
## open section could grow taller than the screen and bury every other category)
## with a rail plus a floating icon grid. WI-54 finished the job against the
## design: the rail entries are [ListRow]s carrying a name, a count and a
## disclosure caret; the flyout is a second [ConsolePanel] welded to the rail's
## right edge with its own 56px header; and **locked modules render** - dimmed,
## with the tech that grants them - instead of being hidden until unlocked.
##
## Two stage, not a drilldown: picking a category never takes the rail away, so
## the player keeps their place and can hop categories without a back step.
##
## Grouping / ordering / search / MRU / locked ordering / gate resolution are all
## pure and tested in [BuildMenuModel]; this node owns only the view. It keys on
## [member ModuleData.category_id], never on tags - tags stay reserved for
## gameplay.

const RECENT_CAP: int = 5

## Side of the flyout header's `◀` collapse control.
const COLLAPSE_CONTROL_SIZE: int = 22

## What the flyout parks beside, and the panel whose active border it takes over
## while it is open. Null means this menu is mounted outside a panel (a probe);
## the flyout then anchors itself at the design's x anyway. The BUILD factory
## sets it to the rail's [ConsolePanel].
var flyout_anchor: ConsolePanel = null

## Every non-hidden module, scanned once - the source of truth for grouping,
## search, recent lookups, and unlock reactivity.
var _modules: Array[ModuleData] = []
var _by_id: Dictionary[StringName, ModuleData] = {}
## category id -> Array[ModuleData], straight from BuildMenuModel.
var _groups: Dictionary = {}
## Rail order, so the cycle keys have something to step through.
var _categories: Array[StringName] = []
## category id -> its rail row, so a category change can repaint the live one.
var _rail_rows: Dictionary[StringName, ListRow] = {}
var _recent_ids: Array[StringName] = []
## The category whose flyout is open, or &"" for search results / closed.
var _open_category: StringName = &""
## The rows currently in the flyout, so the held module's row can be re-marked
## without repopulating the list.
var _module_rows: Array[ModuleButton] = []

## Scene-read module numbers, shared by every row this menu builds and freed with
## it. See [ModuleFacts] for why it is not a static.
var facts_cache: Dictionary[PackedScene, ModuleFacts] = {}

var _search: LineEdit
var _recent_section: SectionLabel
var _recent_row: HFlowContainer
var _rail: VBoxContainer
var _flyout: ConsolePanel
var _flyout_list: VBoxContainer
var _flyout_scroll: ScrollContainer
var _flyout_collapse: Button

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_scan_modules()
	_build_search()
	_build_body()
	_build_flyout()
	SignalBus.module_added.connect(_on_module_added)
	# One shared zero-arg handler recomputes everything cheaply; module count is
	# small and unlocks are rare, so fine-grained per-button maps aren't worth it.
	for module_data: ModuleData in _modules:
		module_data.module_lock_changed.connect(_on_module_lock_changed.unbind(1))
	if Global.ui_in_game != null:
		Global.ui_in_game.input_mode_changed.connect(_on_input_mode_changed)
	_refresh_rail()

func _scan_modules() -> void:
	_modules.clear()
	_by_id.clear()
	for file_path: String in ContentPaths.scan(ContentPaths.MODULES):
		var module_data: ModuleData = ResourceLoader.load(file_path, "ModuleData")
		if module_data == null or module_data.hidden:
			continue
		# Same id gate SaveManager applies. A module the save system refuses is a
		# module the player must not be able to place - otherwise a mod with a
		# badly namespaced id builds fine and vanishes on load.
		if not ContentPaths.accept_id(module_data.id, file_path, "ModuleData"):
			continue
		_modules.append(module_data)
		_by_id[module_data.id] = module_data
	_groups = BuildMenuModel.group_modules(_modules)
	_categories.assign(_groups.keys())
	_categories = BuildMenuModel.category_order(_categories)

# --- construction --------------------------------------------------------------

## The search field is its own full-bleed block with a rule under it, matching
## the design - it is a control that acts on everything below it, not the first
## row of the category list.
func _build_search() -> void:
	var block := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = UIPalette.DIVIDER
	box.set_border_width_all(0)
	box.border_width_bottom = UIMetrics.BORDER_WIDTH
	box.set_corner_radius_all(0)
	block.add_theme_stylebox_override("panel", box)
	add_child(block)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", UIMetrics.CONTENT_PAD)
	pad.add_theme_constant_override("margin_right", UIMetrics.CONTENT_PAD)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 14)
	block.add_child(pad)

	_search = LineEdit.new()
	_search.placeholder_text = "Search all modules…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_on_search_changed)
	pad.add_child(_search)

func _build_body() -> void:
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	pad.add_child(column)

	# Recent sits above CATEGORIES: it is the shortcut past the rail, so it has to
	# be reachable before the rail is.
	_recent_section = SectionLabel.create("Recent")
	_recent_section.visible = false
	column.add_child(_recent_section)
	_recent_row = HFlowContainer.new()
	_recent_row.visible = false
	_recent_row.add_theme_constant_override("h_separation", UIMetrics.ROW_GAP)
	_recent_row.add_theme_constant_override("v_separation", UIMetrics.ROW_GAP)
	column.add_child(_recent_row)

	var categories: SectionLabel = SectionLabel.create("Categories")
	categories.hint = _cycle_hint()
	column.add_child(categories)

	# The rail scrolls inside itself rather than the panel scrolling, so the
	# search field and the section labels never leave the screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_rail = VBoxContainer.new()
	_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rail.add_theme_constant_override("separation", 5)
	scroll.add_child(_rail)
	for category: StringName in _categories:
		_rail.add_child(_make_rail_row(category))

## What the CATEGORIES section prints as its hotkey hint. Read from the live
## [InputMap] rather than hardcoded, so a rebind shows up here and so an unbound
## pair prints nothing at all - a printed hint for a key that does nothing is
## worse than no hint (WI-54 edge case).
func _cycle_hint() -> String:
	var prev: String = ModeManager.action_hotkey_label(&"build_category_prev")
	var next: String = ModeManager.action_hotkey_label(&"build_category_next")
	if prev.is_empty() or next.is_empty():
		return ""
	return "%s/%s" % [prev, next]

## A rail entry: category icon, name, the number of modules the flyout will show,
## and a disclosure caret. The count is what is *shown*, locked entries included,
## because that is what the player finds when they open it.
##
## Count and caret share [ListRow]'s one right-hand slot rather than the count
## going on the row's meta line: the design has them inline beside each other,
## and the meta line sits *under* the name.
func _make_rail_row(category: StringName) -> ListRow:
	var row: ListRow = ListRow.create()
	row.set_icon(_category_icon(category), UIMetrics.BUILD_RAIL_ICON)
	row.pressed.connect(_on_rail_pressed.bind(category))
	_rail_rows[category] = row
	_paint_rail_row(category, row)
	return row

func _paint_rail_row(category: StringName, row: ListRow) -> void:
	var live: bool = category == _open_category
	var label: String = BuildMenuModel.category_name(category)
	var count: int = _bucket(category).size()
	row.configure(label, "", "%d  ▸" % count,
		UIPalette.Row.LIVE if live else UIPalette.Row.INERT)
	row.set_icon(_category_icon(category), UIMetrics.BUILD_RAIL_ICON)
	row.set_action_color(UIPalette.LIVE if live else UIPalette.TEXT_META)
	row.tooltip_text = "%s · %d modules" % [label, count]

## Rail icon for a category: the BuildCategoryData's own cat_icon, or a
## representative module's icon as a fallback for a category that declares none.
func _category_icon(category: StringName) -> Texture2D:
	var icon: Texture2D = BuildCategoryData.icon_of(category)
	if icon != null:
		return icon
	for module_data: ModuleData in _bucket(category):
		if module_data.icon != null:
			return module_data.icon
	return null

## The flyout is a second [ConsolePanel], not a floating popup: it carries the
## same 56px header (the category's name, its count and a collapse control) and
## the same foot as the rail beside it, so 356 + 340 reads as one two-stage
## surface rather than as a panel with a menu on top of it.
##
## `top_level` is what lets it do that from inside the rail's content region: a
## top-level Control resolves its anchors against the viewport, so the frame's
## own [member ConsolePanel.panel_offset_left] lands it at exactly x=356. It
## stays a child of this node, though, because `top_level` detaches the transform
## and *not* the visibility - closing the Build panel has to take the flyout with
## it.
func _build_flyout() -> void:
	_flyout = ConsolePanel.create()
	_flyout.top_level = true
	_flyout.visible = false
	_flyout.panel_offset_left = UIMetrics.PANEL_BUILD_FLYOUT_LEFT
	_flyout.panel_width = UIMetrics.PANEL_BUILD_FLYOUT_WIDTH
	_flyout.content_padding = 14
	_flyout.hotkey = ""
	_flyout.footer_text = "Click to hold · Esc cancel"
	add_child(_flyout)

	_flyout_collapse = Button.new()
	_flyout_collapse.text = "◀"
	_flyout_collapse.focus_mode = Control.FOCUS_NONE
	_flyout_collapse.custom_minimum_size = Vector2(
		float(COLLAPSE_CONTROL_SIZE), float(COLLAPSE_CONTROL_SIZE))
	_flyout_collapse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_flyout_collapse.tooltip_text = "Close this category"
	_flyout_collapse.pressed.connect(close_flyout)
	_flyout.add_header_control(_flyout_collapse)

	_flyout_scroll = ScrollContainer.new()
	_flyout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_flyout_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_flyout.content().add_child(_flyout_scroll)

	_flyout_list = VBoxContainer.new()
	_flyout_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flyout_list.add_theme_constant_override("separation", 7)
	_flyout_scroll.add_child(_flyout_list)

# --- rail / flyout interaction -------------------------------------------------

func _on_rail_pressed(category: StringName) -> void:
	if _open_category == category and flyout_open():
		close_flyout()
		return
	open_category(category)

## Opens one category's flyout. Public because the cycle keys drive it too.
func open_category(category: StringName) -> void:
	if not _groups.has(category):
		return
	_search.text = "" # a rail pick overrides any active search
	_open_category = category
	_flyout.title = BuildMenuModel.category_name(category)
	_flyout_collapse.visible = true
	_populate_list(_bucket(category))
	_show_flyout()

func _on_search_changed(text: String) -> void:
	var query: String = text.strip_edges()
	if query.is_empty():
		close_flyout() # clearing search dismisses the results flyout
		return
	# Search results have no rail anchor, so nothing in the rail goes live and
	# the rail itself never scrolls away - the player keeps their place.
	_open_category = &""
	_flyout.title = "Results"
	_flyout_collapse.visible = false
	_populate_list(BuildMenuModel.filter_by_name(_modules, query))
	_show_flyout()

func _show_flyout() -> void:
	_flyout.visible = true
	# The active border belongs to the outermost edge on screen, so while the
	# flyout is out it wears the cyan and the rail beside it goes inert. That is
	# the design's own detail and it is what makes the pair read as one surface.
	if flyout_anchor != null and is_instance_valid(flyout_anchor):
		flyout_anchor.active = false
	_refresh_rail()

## `is_visible_in_tree`, not `visible`: `top_level` detaches the flyout's
## transform but not its visibility, so closing the Build panel hides the flyout
## while leaving its own `visible` true. Esc's "close the flyout first" level
## would otherwise claim the key for a flyout nobody can see.
func flyout_open() -> bool:
	return _flyout != null and _flyout.is_visible_in_tree()

## The other half of that: the menu puts its own flyout away whenever it stops
## being visible, so reopening Build does not reopen a category the player
## already dismissed. It lives here rather than in whatever mounted the menu,
## because the flyout is this node's to own under any mount.
## The `_flyout` guard is load-bearing: visibility notifications fire on tree
## entry, before `_ready` has built it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _flyout != null and not is_visible_in_tree():
		close_flyout()

func close_flyout() -> void:
	if _flyout == null:
		return
	_flyout.visible = false
	_open_category = &""
	if flyout_anchor != null and is_instance_valid(flyout_anchor):
		flyout_anchor.active = true
	_refresh_rail()

## Fills the flyout with a category's (or a search's) modules. Locked entries are
## rendered dimmed, after the buildable ones, with the tech that grants them -
## the only behaviour change in WI-54, and the one that makes the tech tree
## legible from the build menu.
func _populate_list(modules: Array[ModuleData]) -> void:
	for child: Node in _flyout_list.get_children():
		_flyout_list.remove_child(child)
		child.queue_free()
	_module_rows.clear()
	var unlocks: Array[UnlockData] = _all_unlocks()
	var ordered: Array[ModuleData] = BuildMenuModel.sort_bucket(modules, _is_locked)
	for module_data: ModuleData in ordered:
		var row: ModuleButton = ModuleButton.create()
		_flyout_list.add_child(row)
		row.set_moduledata(module_data)
		if _is_locked.call(module_data):
			row.set_locked(true, BuildMenuModel.gating_label(module_data, unlocks))
		else:
			# Picking a module drops into placement mode - dismiss the flyout so it
			# stops covering the build area. The rail stays.
			row.pressed.connect(close_flyout)
		_module_rows.append(row)
	# Count what is shown, locked entries included, so the header agrees with the
	# list under it.
	_flyout.subtitle = str(ordered.size())
	_mark_held_module()

func _is_locked(module_data: ModuleData) -> bool:
	return module_data != null and not module_data.is_unlocked()

func _all_unlocks() -> Array[UnlockData]:
	if Global.unlock_manager == null:
		return [] as Array[UnlockData]
	return Global.unlock_manager.get_all_unlocks()

## Typed view into the (untyped-valued) _groups dictionary.
func _bucket(category: StringName) -> Array[ModuleData]:
	var bucket: Array[ModuleData] = _groups.get(category, [] as Array[ModuleData])
	return bucket

# --- category cycling -----------------------------------------------------------

## Steps the open category one place along the rail, wrapping. With nothing open
## it opens the first (or last) category rather than doing nothing, so the key is
## a way *into* the rail as well as through it.
##
## `_shortcut_input` rather than `_unhandled_input`: the rail rows are focusable
## [Button]s, and a focused button consumes arrow-style navigation before
## unhandled input ever sees it. The text-focus guard is the shared one every HUD
## hotkey uses (WI-50 contract point 6) - typing "steel" into the search box must
## not cycle the rail.
func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _categories.is_empty():
		return
	if ModeManager.text_entry_has_focus(get_viewport()):
		return
	var step: int = 0
	if event.is_action_pressed(&"build_category_next"):
		step = 1
	elif event.is_action_pressed(&"build_category_prev"):
		step = -1
	if step == 0:
		return
	get_viewport().set_input_as_handled()
	var index: int = _categories.find(_open_category)
	if index < 0:
		index = 0 if step > 0 else _categories.size() - 1
	else:
		index = posmod(index + step, _categories.size())
	open_category(_categories[index])

# --- recently built ------------------------------------------------------------

func _on_module_added(module: ModuleBase) -> void:
	if module == null or module.module_data == null:
		return
	var data: ModuleData = module.module_data
	# Truss is auto-placed whenever a real module is removed - never a player
	# choice, so it must not pollute the recent list.
	if data.hidden or data.id == &"truss_mdata":
		return
	_recent_ids = BuildMenuModel.push_recent(_recent_ids, data.id, RECENT_CAP)
	_rebuild_recent_row()

func _rebuild_recent_row() -> void:
	for child: Node in _recent_row.get_children():
		_recent_row.remove_child(child)
		child.queue_free()
	for id: StringName in _recent_ids:
		var data: ModuleData = _by_id.get(id)
		if data == null:
			continue
		var tile: ModuleButton = ModuleButton.create()
		_recent_row.add_child(tile)
		tile.compact = true
		tile.set_moduledata(data)
		if _is_locked.call(data):
			# A module can be un-granted again on load (UnlockManager clears state
			# before re-applying it), and the recent list outlives that.
			tile.set_locked(true, BuildMenuModel.gating_label(data, _all_unlocks()))
	var has_recent: bool = not _recent_ids.is_empty()
	_recent_section.visible = has_recent
	_recent_row.visible = has_recent

# --- reactivity ---------------------------------------------------------------

func _on_module_lock_changed() -> void:
	_refresh_rail()
	_rebuild_recent_row()
	if flyout_open() and _open_category != &"":
		_populate_list(_bucket(_open_category))

## Repaints the rail: the open category takes the live treatment, and every entry
## restates its count. Unlike WI-43's version this never *hides* a category -
## locked modules are rendered now, so a category whose modules are all
## un-researched has something to show, and the rail stops changing length under
## the player as the tech tree opens up.
func _refresh_rail() -> void:
	for category: StringName in _rail_rows:
		var row: ListRow = _rail_rows[category]
		if is_instance_valid(row):
			_paint_rail_row(category, row)

## The held module's row takes the live treatment and expands, so the list agrees
## with the ghost already on the station.
func _on_input_mode_changed(_mode: UIInGame.InputMode) -> void:
	_mark_held_module()

func _mark_held_module() -> void:
	var held: ModuleData = Global.ui_in_game.cur_module if Global.ui_in_game != null else null
	for row: ModuleButton in _module_rows:
		if is_instance_valid(row):
			row.selected = held != null and row.module_data == held

## The scene-read numbers behind one module's facts line, built on first ask and
## cached for the life of this menu. Rows go through here rather than caching
## their own so switching categories back and forth does not re-instantiate a
## module scene each time.
func facts_for(scene: PackedScene) -> ModuleFacts:
	if scene == null:
		return null
	var cached: ModuleFacts = facts_cache.get(scene)
	if cached == null:
		cached = ModuleFacts.from_scene(scene)
		facts_cache[scene] = cached
	return cached

## Live count of modules shown in a category, for the probe and for tests of the
## header/rail agreement.
func category_count(category: StringName) -> int:
	return _bucket(category).size()

## The flyout frame, so the mount can measure it. Never null once `_ready` ran.
func flyout_panel() -> ConsolePanel:
	return _flyout
