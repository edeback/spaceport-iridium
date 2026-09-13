class_name InspectorPanel
extends ReadoutPanel

## The one selection surface (WI-51, invariant 2).
##
## Crew, module, asteroid, pile and turboshaft selections all render here, into a
## 420px [ReadoutPanel] welded to the bottom-right corner one gutter above the
## console. Only the tab set changes. It replaces five panels, three of which
## instantiated themselves fresh per click and two of which **chased their
## subject across the screen every frame** - which is the clearest single symptom
## of the problem this program exists to fix: a panel that overlaps the station,
## overlaps other panels, moves while you read it, and leaves selection with no
## fixed place to be.
##
## The panel grows *upward* with its content and stops at
## [constant UIMetrics.INSPECTOR_TOP_LIMIT]; past that its tab content scrolls
## inside itself rather than climbing into the readouts above.
##
## Nothing selected is **no panel at all** (2026-09-13). WI-51 kept a caret-blinking
## nothing-selected line so the bottom-right would teach the player where
## selection lives; in play it was a permanent box that said nothing. [UIMain]
## owns this panel's `visible` (its `_sync_inspector_visibility()`), because
## Trade and R&D hide it too and two writers would each undo the other.
##
## One entry point: [method select]. Nothing else in the game may instantiate a
## selection surface - WI-53's alerts and WI-56's roster rows both come through
## here.

const SCENE_PATH: String = "res://ui/inspector/inspector_panel.tscn"

## Which tab set is mounted. CORRIDOR is deliberately absent: corridors are
## [ModuleBase] instances on the CORRIDOR layer and resolve as MODULE with
## whatever components they carry, which needs no special case.
enum SelectionKind { NONE, CREW, MODULE, ASTEROID, PILE, TURBOSHAFT }

## Emitted after the selection settles, so the Esc ladder and anything watching
## selection (brackets, WI-56's roster highlight) can react to one signal instead
## of polling.
signal selection_changed(kind: SelectionKind)

## Y the panel's top edge may not cross, pushed in by [UIMain] as the readouts
## above it change height (WI-53).
##
## The inspector shares the right column with the station map, the alert feed and
## the live-raid readout, and two of those three come and go. A constant would
## have to encode the worst case, which costs the inspector three hundred pixels
## on the ordinary station where the feed is empty - so the column measures
## itself and tells the inspector where it currently ends.
var top_limit: int = UIMetrics.INSPECTOR_TOP_LIMIT:
	set(value):
		var clamped: int = maxi(value, 0)
		if top_limit == clamped:
			return
		top_limit = clamped
		_queue_refit()

var _kind: SelectionKind = SelectionKind.NONE
var _subject: Variant = null
var _set: InspectorTabSet = null

## The tab each kind was last left on, so clicking through five crew members does
## not send you back to Needs every time.
var _last_tab: Dictionary[SelectionKind, StringName] = {}

## Pages built so far for the current selection, by tab id. Cleared wholesale on
## every selection change - a page holds a reference to the old subject, so
## keeping one across selections is how a stale panel gets built.
var _pages: Dictionary[StringName, Control] = {}

var _column: VBoxContainer
var _subject_block: VBoxContainer
var _icon: ColorRect
var _icon_art: TextureRect
var _name_label: Label
var _meta_label: Label
var _status_label: Label
var _bars: VBoxContainer
var _tabs: TabStrip
var _scroll: ScrollContainer
var _page_host: MarginContainer
var _footer: HBoxContainer
## Re-entrancy latch for [method _refit]: the fit writes a minimum size, which is
## exactly the signal that triggers it.
var _refitting: bool = false

static func create() -> InspectorPanel:
	return load(SCENE_PATH).instantiate() as InspectorPanel

func _ready() -> void:
	super()
	_build_body()
	_apply_selection()

# --- public API ----------------------------------------------------------------

## Selects `subject`, resolving its kind and swapping the tab set. Passing the
## already-selected subject deselects it, which is the behaviour all four old
## click handlers had; what changes is the visual result - the panel shows its
## nothing-selected line instead of disappearing.
##
## `null` clears. An unrecognised subject also clears rather than erroring: this
## is the entry point every click path in the game funnels into, and a hard
## failure there would take the HUD down over a stray click.
func select(subject: Variant) -> void:
	if subject != null and _subject != null and subject == _subject:
		clear()
		return
	_mount(subject)

func clear() -> void:
	_mount(null)

func selected_subject() -> Variant:
	return _subject

func kind() -> SelectionKind:
	return _kind

func has_selection() -> bool:
	return _kind != SelectionKind.NONE

## The node the camera should travel to for the current selection - the other
## half of the jump-to pair WI-53 and WI-56 consume, alongside [method select].
func camera_target() -> Node2D:
	return _set.camera_target() if _set != null else null

## Which tab set a subject resolves to. Static so a probe can assert the mapping
## without mounting anything.
static func kind_of(subject: Variant) -> SelectionKind:
	if subject == null:
		return SelectionKind.NONE
	var object: Object = subject as Object
	if object != null and not is_instance_valid(object):
		return SelectionKind.NONE
	if subject is PawnBase:
		return SelectionKind.CREW
	if subject is AsteroidBase:
		return SelectionKind.ASTEROID
	if subject is ResourcePile:
		return SelectionKind.PILE
	# A lift that is still a blueprint has no shaft to manage, so it inspects as
	# the module it currently is - matching what clicking one did before.
	if subject is ModuleTurbolift and (subject as ModuleTurbolift).is_complete():
		return SelectionKind.TURBOSHAFT
	if subject is ModuleBase:
		return SelectionKind.MODULE
	return SelectionKind.NONE

# --- mounting ------------------------------------------------------------------

func _mount(subject: Variant) -> void:
	_teardown()
	_kind = kind_of(subject)
	_subject = subject if _kind != SelectionKind.NONE else null
	if _kind != SelectionKind.NONE:
		_set = _make_set(_kind)
		add_child(_set)
		_set.subject_lost.connect(_on_subject_lost)
		_set.subject_changed.connect(refresh_subject)
		_set.tabs_changed.connect(_rebuild_tabs)
		_set.bind(_subject)
	_apply_selection()
	selection_changed.emit(_kind)

func _teardown() -> void:
	_clear_pages()
	if _set != null and is_instance_valid(_set):
		# Freed rather than hidden: a set holds live connections to its subject,
		# and a set still listening to a module the player deselected would repaint
		# a panel that is showing something else.
		_set.queue_free()
	_set = null
	_subject = null
	_kind = SelectionKind.NONE

func _make_set(for_kind: SelectionKind) -> InspectorTabSet:
	match for_kind:
		SelectionKind.CREW:
			return CrewTabSet.new()
		SelectionKind.MODULE:
			return ModuleTabSet.new()
		SelectionKind.ASTEROID:
			return AsteroidTabSet.new()
		SelectionKind.PILE:
			return PileTabSet.new()
		SelectionKind.TURBOSHAFT:
			return TurboshaftTabSet.new()
		_:
			return InspectorTabSet.new()

## The one path for "the thing I was showing is gone", shared by all five kinds:
## a destroyed module, a mined-out asteroid, a collected pile, a fired crew
## member, a merged shaft.
##
## Deferred because the usual sender is a despawn signal, and rebuilding the
## panel inside one is how a half-freed subject gets read.
func _on_subject_lost() -> void:
	clear.call_deferred()

## The backstop under [signal InspectorTabSet.subject_lost]: a subject can be
## freed with no signal at all (a `queue_free` from anywhere), and it can be
## freed *between* a deferred signal and the handler that reads it - which is
## exactly what `is_instance_valid` guards in the panels this replaces.
##
## One validity check per frame while something is selected, in one place, rather
## than the five per-panel `_process` handlers that used to also reposition
## themselves. `set_process` is off entirely when nothing is selected.
func _process(_delta: float) -> void:
	if _set != null and not _set.is_alive():
		clear()

func _apply_selection() -> void:
	if _column == null:
		return
	var empty: bool = _kind == SelectionKind.NONE or _set == null
	set_process(not empty)
	if empty:
		# [UIMain] hides the frame off `selection_changed`. It is still emptied, so
		# the next select() never shows the last subject's pages for a frame.
		_clear_pages()
		_tabs.set_tabs([])
		return
	# The caption comes from the mounted tab set's kind_label() - a static table
	# here could not say "Comet" for a body that resolves as ASTEROID (WI-61).
	label = "Selected · " + _set.kind_label()
	accent_color = UIPalette.LIVE
	refresh_subject()
	_rebuild_tabs()

# --- subject block -------------------------------------------------------------

## Repaints everything above the tab strip, plus the footer. Cheap enough that a
## tab set is free to call it on any change rather than working out which field
## moved.
func refresh_subject() -> void:
	if _set == null or _name_label == null:
		return
	if not _set.is_alive():
		_on_subject_lost()
		return
	_name_label.text = _set.subject_name()
	var meta: String = _set.meta_text()
	_meta_label.text = meta.to_upper()
	_meta_label.visible = not meta.is_empty()
	var status: String = _set.status_text()
	_status_label.text = status
	_status_label.visible = not status.is_empty()
	var tint: Color = _set.icon_color()
	_icon.color = tint
	_icon.visible = tint.a > 0.0
	var art: Texture2D = _set.icon_texture()
	_icon_art.texture = art
	_icon_art.visible = art != null
	_rebuild_bars()
	_rebuild_footer()
	_refit()

func _rebuild_bars() -> void:
	for child: Node in _bars.get_children():
		_bars.remove_child(child)
		child.queue_free()
	var specs: Array[Dictionary] = _set.subject_bars()
	_bars.visible = not specs.is_empty()
	for spec: Dictionary in specs:
		var bar: StatBar = StatBar.create()
		_bars.add_child(bar)
		bar.configure(String(spec.get("label", "")), float(spec.get("fraction", 0.0)),
			String(spec.get("value", "")), spec.get("tint", UIPalette.LIVE))

func _rebuild_footer() -> void:
	for child: Node in _footer.get_children():
		_footer.remove_child(child)
		child.queue_free()
	var actions: Array[Control] = _set.footer_actions()
	_footer.visible = not actions.is_empty()
	for action: Control in actions:
		_footer.add_child(action)

# --- tabs ----------------------------------------------------------------------

func _rebuild_tabs() -> void:
	if _set == null:
		return
	var defs: Array[Dictionary] = _set.tabs()
	# The pages cached for tabs that did not survive the rebuild are dead weight
	# and would be shown again if the tab came back with different contents.
	_clear_pages()
	_tabs.set_tabs(InspectorTabPlan.to_strip_defs(defs))
	var remembered: StringName = _last_tab.get(_kind, &"")
	if remembered != &"":
		_tabs.select(remembered)
	_show_page(_tabs.selected())

func _on_tab_selected(id: StringName) -> void:
	_last_tab[_kind] = id
	_show_page(id)

func _show_page(id: StringName) -> void:
	for page_id: StringName in _pages:
		var cached: Control = _pages[page_id]
		if is_instance_valid(cached):
			cached.visible = page_id == id
	if id == &"" or _set == null:
		_refit()
		return
	if not _pages.has(id):
		var page: Control = _set.make_page(id)
		if page == null:
			_refit()
			return
		_adopt_page(page)
		_pages[id] = page
		_page_host.add_child(page)
	_pages[id].visible = true
	_refit()

## Makes a page fit the inspector and hooks up the one signal a page may raise.
## The flattening itself is [method InspectorTabSet.flatten_page] - the tab sets
## need it too, for the pages WI-64 stacks inside one page.
func _adopt_page(page: Control) -> void:
	InspectorTabSet.flatten_page(page)
	if page.has_signal(&"subject_lost"):
		page.connect(&"subject_lost", _on_subject_lost)

func _clear_pages() -> void:
	for id: StringName in _pages:
		var page: Control = _pages[id]
		if is_instance_valid(page):
			page.queue_free()
	_pages.clear()

# --- geometry ------------------------------------------------------------------

## Grows the panel upward from its bottom edge.
##
## [ReadoutPanel.fit_height] grows *downward* from `offset_top`, which is right
## for the map at the top of the right column and wrong here: the inspector's
## bottom edge is the fixed one (a gutter above the console) and its top edge is
## what moves as tab content changes.
func fit_height() -> void:
	offset_top = offset_bottom - custom_minimum_size.y

## Sizes the content region to what the current tab set asks for, capped so the
## panel never climbs into the readouts above it.
##
## The page region is a [ScrollContainer], which reports a **minimum height of
## zero** - it is built to be handed a size, not to ask for one. That is WI-48's
## deviation 8 verbatim, and left alone it collapses the page to nothing while
## every value inside it is correct. So the height is driven from the page's own
## combined minimum, synchronously and without touching `get_tree()`, because the
## panel is configured before it is mounted.
##
## Measuring **once** is not enough, which is the other half of that lesson: an
## autowrapped label (the processor tab's recipe line) reports a minimum height
## computed from its current width, so a page measured before layout has given it
## the panel's 400px asks for roughly twice the height it will actually need.
## Left latched, the panel rendered at its full 668px cap around three lines of
## content. So the fit re-runs whenever anything below it changes size.
func _refit() -> void:
	if _column == null or _refitting:
		return
	_refitting = true
	var page: Control = _visible_page()
	var page_min: float = page.get_combined_minimum_size().y if page != null else 0.0
	var chrome: float = _chrome_height()
	var budget: float = float(UIMetrics.inspector_max_content_height(
		UIMetrics.SCREEN_SIZE.y, top_limit))
	var page_height: float = minf(page_min, maxf(0.0, budget - chrome))
	_scroll.custom_minimum_size.y = page_height
	# The frame must always contain its own chrome, even if the budget handed down
	# is hostile (WI-58). Capping at the budget alone let the subject block, tab
	# strip and footer render *outside* the panel's rect on a column where the
	# readouts above had eaten the room - a frame that does not contain its
	# contents is worse than a frame that overhangs its budget by a few pixels.
	# The page region is what absorbs the shortfall, by scrolling.
	content_height = int(ceilf(maxf(chrome, minf(chrome + page_height, budget))))
	_refitting = false

## Everything in the column except the scrolling page region, plus the gaps
## between the visible parts and the content padding.
##
## Summed by hand rather than by zeroing the scroll and asking the column,
## because that mutate-measure-mutate dance invalidates the very cache it is
## about to read and makes the result depend on when it was called.
func _chrome_height() -> float:
	var total: float = 0.0
	var shown: int = 0
	for child: Node in _column.get_children():
		var control: Control = child as Control
		if control == null or not control.visible:
			continue
		shown += 1
		if control != _scroll:
			total += control.get_combined_minimum_size().y
	total += float(maxi(shown - 1, 0)) * float(UIMetrics.ROW_GAP)
	return total + float(content_padding) * 2.0

## Deferred so a burst of layout changes in one frame settles into a single fit,
## and so the fit never runs inside the notification that caused it.
func _queue_refit() -> void:
	if _refitting:
		return
	_refit.call_deferred()

func _visible_page() -> Control:
	for id: StringName in _pages:
		var page: Control = _pages[id]
		if is_instance_valid(page) and page.visible:
			return page
	return null

# --- construction ---------------------------------------------------------------

## The frame is the scene; the body is built here (program decision 8). Nothing
## below is authored in `inspector_panel.tscn`, so the tab sets cannot drift out
## of sync with a hand-edited layout.
func _build_body() -> void:
	panel_width = UIMetrics.INSPECTOR_WIDTH
	drop_shadow = true
	content_padding = UIMetrics.READOUT_CONTENT_PAD

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	content().add_child(_column)
	# The backstop for the fit: fonts settling, an autowrap label learning its
	# width, a flow container wrapping onto a second row all change what the
	# content asks for *after* the page was mounted and measured.
	_column.minimum_size_changed.connect(_queue_refit)

	_column.add_child(_build_subject_block())

	_tabs = TabStrip.create()
	_tabs.name = "Tabs"
	_tabs.tab_selected.connect(_on_tab_selected)
	_column.add_child(_tabs)

	_scroll = ScrollContainer.new()
	_scroll.name = "PageScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_column.add_child(_scroll)

	_page_host = MarginContainer.new()
	_page_host.name = "PageHost"
	_page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_page_host)

	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_column.add_child(_footer)

	var close := Button.new()
	close.name = "Close"
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Deselect"
	close.pressed.connect(clear)
	add_action(close)

func _build_subject_block() -> VBoxContainer:
	_subject_block = VBoxContainer.new()
	_subject_block.name = "Subject"
	_subject_block.add_theme_constant_override("separation", UIMetrics.ROW_GAP)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", UIMetrics.READOUT_HEADER_GAP)
	_subject_block.add_child(row)

	_icon = ColorRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(
		float(UIMetrics.INSPECTOR_ICON_SIZE), float(UIMetrics.INSPECTOR_ICON_SIZE))
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)

	# The module's own artwork over its tint, when it has any. Anchored inside the
	# swatch rather than replacing it, so a subject with no art still reads as a
	# coloured block instead of a hole.
	_icon_art = TextureRect.new()
	_icon_art.name = "Art"
	_icon_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.add_child(_icon_art)

	var names := VBoxContainer.new()
	names.name = "Names"
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override("separation", 2)
	row.add_child(names)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.theme_type_variation = UIType.ENTITY_NAME_LARGE
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(_name_label)

	_meta_label = Label.new()
	_meta_label.name = "Meta"
	_meta_label.theme_type_variation = UIType.META_LINE
	_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(_meta_label)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.theme_type_variation = UIType.META_LINE
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)
	_subject_block.add_child(_status_label)

	_bars = VBoxContainer.new()
	_bars.name = "Bars"
	_bars.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_subject_block.add_child(_bars)

	return _subject_block
