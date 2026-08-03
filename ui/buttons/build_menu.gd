class_name BuildMenu
extends VBoxContainer

## Station build menu (WI-43): a fixed category rail that opens a floating,
## internally-scrolling icon-grid flyout, plus a live name search and a recently-built
## strip. Replaces the old per-tag FoldableContainer accordion, whose single open
## section could grow taller than the screen and bury every other category with no
## scroll to reach them. The rail's height is bounded by the category count, so it can
## never overflow no matter how many modules unlock.
##
## Grouping/ordering/search/MRU are pure and tested in BuildMenuModel; this node owns
## only the view - button instancing, unlock-driven visibility, and flyout placement.
## It keys on ModuleData.category_id, never tags (tags stay reserved for gameplay).

const MODULE_BUTTON: PackedScene = preload("res://ui/buttons/module_button.tscn")
const RECENT_CAP: int = 5
## Rail category icons are pinned to this square; recent-strip icons to the smaller one.
const RAIL_ICON_PX: int = 64
const RECENT_ICON_PX: int = 40
## Flyout geometry. Width is fixed so the grid wraps predictably; height fits content
## up to the cap, past which the grid scrolls inside instead of pushing off-screen.
const FLYOUT_WIDTH: float = 300.0
const FLYOUT_MAX_HEIGHT: float = 440.0
const FLYOUT_GAP: float = 6.0

## Every non-hidden module, scanned once - the source of truth for grouping, search,
## recent lookups, and unlock reactivity.
var _modules: Array[ModuleData] = []
var _by_id: Dictionary[StringName, ModuleData] = {}
## category id -> Array[ModuleData] (name-sorted), straight from BuildMenuModel.
var _groups: Dictionary = {}
## category id -> its rail Button, so unlock changes can retoggle rail visibility.
var _rail_buttons: Dictionary[StringName, Button] = {}
var _recent_ids: Array[StringName] = []
## The category whose flyout is open, or &"" for search results / closed.
var _open_category: StringName = &""

var _search: LineEdit
var _recent_label: Label
var _recent_row: HFlowContainer
var _rail: VBoxContainer
var _flyout: PanelContainer
var _scroll: ScrollContainer
var _flyout_grid: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_scan_modules()
	_build_search()
	_build_recent()
	_build_rail()
	_build_flyout()
	SignalBus.module_added.connect(_on_module_added)
	# One shared zero-arg handler recomputes everything cheaply; module count is small
	# and unlocks are rare, so fine-grained per-button maps aren't worth it.
	for module_data: ModuleData in _modules:
		module_data.module_lock_changed.connect(_on_module_lock_changed.unbind(1))
	_refresh_rail_visibility()

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

# --- construction --------------------------------------------------------------

func _build_search() -> void:
	_search = LineEdit.new()
	_search.placeholder_text = "Search modules"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_on_search_changed)
	add_child(_search)

func _build_recent() -> void:
	_recent_label = Label.new()
	_recent_label.text = "Recent"
	_recent_label.add_theme_font_size_override("font_size", 11)
	_recent_label.visible = false
	add_child(_recent_label)
	_recent_row = HFlowContainer.new()
	_recent_row.visible = false
	add_child(_recent_row)

func _build_rail() -> void:
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", 2)
	add_child(_rail)
	var categories: Array[StringName] = []
	categories.assign(_groups.keys())
	for category: StringName in BuildMenuModel.category_order(categories):
		_rail.add_child(_make_rail_button(category))

## A rail button: a fixed RAIL_ICON_PX square icon + the category name. Composed from a
## TextureRect rather than Button.icon so the icon is an exact square regardless of the
## source texture - Button.icon/expand_icon can't pin a size while text is present.
func _make_rail_button(category: StringName) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, RAIL_ICON_PX + 8)
	button.clip_text = true
	button.pressed.connect(_on_rail_pressed.bind(category))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -6
	var icon := TextureRect.new()
	icon.texture = _category_icon(category)
	icon.custom_minimum_size = Vector2(RAIL_ICON_PX, RAIL_ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = BuildMenuModel.category_name(category)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	button.add_child(row)
	_rail_buttons[category] = button
	return button

func _build_flyout() -> void:
	# top_level positions the panel in global space and detaches it from this VBox's
	# layout, so it can float over the game view to the right of the rail.
	_flyout = PanelContainer.new()
	_flyout.top_level = true
	_flyout.visible = false
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	_flyout.add_child(margin)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(FLYOUT_WIDTH, 0)
	margin.add_child(_scroll)
	_flyout_grid = VBoxContainer.new()
	# Reserve room for the scrollbar so buttons never sit under it once a tall
	# category scrolls.
	_flyout_grid.custom_minimum_size = Vector2(FLYOUT_WIDTH - 16.0, 0)
	_scroll.add_child(_flyout_grid)
	add_child(_flyout)

## Rail icon for a category: the BuildCategoryData's own cat_icon, or a
## representative module's icon as a fallback for a category that declares none.
## Used to be an inspector dict on this node keyed by the enum - which a mod could
## not add to, and which put display data for scanned content in a scene (WI-47 M5).
func _category_icon(category: StringName) -> Texture2D:
	var icon: Texture2D = BuildCategoryData.icon_of(category)
	if icon != null:
		return icon
	for module_data: ModuleData in _bucket(category):
		if module_data.icon != null:
			return module_data.icon
	return null

# --- rail / flyout interaction -------------------------------------------------

func _on_rail_pressed(category: StringName) -> void:
	if _open_category == category and _flyout.visible:
		close_flyout()
		return
	_search.text = "" # a rail pick overrides any active search
	_open_category = category
	_populate_grid(_bucket(category))
	_flyout.visible = true
	_fit_and_place_flyout.call_deferred()

func _on_search_changed(text: String) -> void:
	var query: String = text.strip_edges()
	if query.is_empty():
		close_flyout() # clearing search dismisses the results flyout
		return
	_open_category = &"" # search results have no rail anchor
	_populate_grid(BuildMenuModel.filter_by_name(_modules, query))
	_flyout.visible = true
	_fit_and_place_flyout.call_deferred()

func flyout_open() -> bool:
	return _flyout.visible

func close_flyout() -> void:
	_flyout.visible = false
	_open_category = &""

## Fits the flyout to its content (capped, then scrolls) and parks it just right of
## the rail, clamped inside the viewport. Deferred so the grid has laid out and
## reported a real minimum size first.
func _fit_and_place_flyout() -> void:
	if not _flyout.visible:
		return
	var content_height: float = _flyout_grid.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(content_height, 0.0, FLYOUT_MAX_HEIGHT)
	# top_level means no parent container ever resizes the panel, and a Control's size
	# only ever grows to meet its minimum - it never shrinks back. Without this, a tall
	# category leaves the panel permanently stretched and later, shorter categories sit
	# in a box of empty space.
	_flyout.reset_size()
	var anchor: Button = _rail_buttons.get(_open_category)
	var y: float = anchor.global_position.y if anchor != null else _search.global_position.y
	var viewport_height: float = get_viewport_rect().size.y
	y = clampf(y, 0.0, maxf(0.0, viewport_height - _scroll.custom_minimum_size.y - 12.0))
	_flyout.global_position = Vector2(global_position.x + size.x + FLYOUT_GAP, y)

## Fills the flyout grid with a category's (or search's) modules. Buttons here keep the
## full ModuleButton look (icon + name); only the rail and recent strip use bare icons.
func _populate_grid(modules: Array[ModuleData]) -> void:
	for child: Node in _flyout_grid.get_children():
		_flyout_grid.remove_child(child)
		child.queue_free()
	for module_data: ModuleData in modules:
		var button := MODULE_BUTTON.instantiate() as ModuleButton
		button.set_moduledata(module_data)
		button.custom_minimum_size = Vector2(0, 40)
		button.visible = module_data.is_unlocked()
		# Picking a module drops into placement mode - dismiss the menu so it stops
		# covering the build area (ModuleButton._on_pressed still runs first).
		button.pressed.connect(close_flyout)
		_flyout_grid.add_child(button)

# --- recently built ------------------------------------------------------------

func _on_module_added(module: ModuleBase) -> void:
	if module == null or module.module_data == null:
		return
	var data: ModuleData = module.module_data
	# Truss is auto-placed whenever a real module is removed - never a player choice,
	# so it must not pollute the recent list.
	if data.hidden or data.id == &"truss_mdata":
		return
	_recent_ids = BuildMenuModel.push_recent(_recent_ids, data.id, RECENT_CAP)
	_rebuild_recent_row()

func _rebuild_recent_row() -> void:
	for child: Node in _recent_row.get_children():
		child.queue_free()
	for id: StringName in _recent_ids:
		var data: ModuleData = _by_id.get(id)
		if data == null:
			continue
		var button := MODULE_BUTTON.instantiate() as ModuleButton
		button.set_moduledata(data)
		# Icon-only fixed square: the strip was eating far too much height as full
		# icon+name buttons. The name still shows on hover via the module tooltip.
		button.text = ""
		button.expand_icon = true
		button.custom_minimum_size = Vector2(RECENT_ICON_PX, RECENT_ICON_PX)
		_recent_row.add_child(button)
	var has_recent: bool = not _recent_ids.is_empty()
	_recent_label.visible = has_recent
	_recent_row.visible = has_recent

# --- unlock reactivity ---------------------------------------------------------

func _on_module_lock_changed() -> void:
	_refresh_rail_visibility()
	if _flyout.visible and _open_category != &"":
		_populate_grid(_bucket(_open_category))
		_fit_and_place_flyout.call_deferred()

func _refresh_rail_visibility() -> void:
	for category: StringName in _rail_buttons:
		_rail_buttons[category].visible = _category_has_unlocked(category)

func _category_has_unlocked(category: StringName) -> bool:
	for module_data: ModuleData in _bucket(category):
		if module_data.is_unlocked():
			return true
	return false

## Typed view into the (untyped-valued) _groups dictionary.
func _bucket(category: StringName) -> Array[ModuleData]:
	var bucket: Array[ModuleData] = _groups.get(category, [] as Array[ModuleData])
	return bucket
