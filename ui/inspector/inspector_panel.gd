class_name InspectorPanel
extends Control

## The one selection surface (WI-51, invariant 2), read **bottom-up** since
## 2026-09-13.
##
## Crew, module, asteroid, pile and turboshaft selections all render here, in a
## 420px surface in the bottom-right corner, sitting on the console's top edge.
## Only the tab set changes. It replaces five panels, three of which instantiated
## themselves fresh per click and two of which **chased their subject across the
## screen every frame**.
##
## Three parts, stacked from the floor up:
##
## 1. **The identity strip**, on the console's top edge where the eye already
##    is: the icon, the name, the meta line (and the amber status line when there
##    is one), plus the two things you always want - centre the camera, deselect.
##    Nothing else, and never anything destructive. It never moves: switching or
##    closing tabs changes only what is above it.
## 2. **The tab rail** ([InspectorTabRail]) standing on it.
## 3. **The detail box**, rising out of the open tab and growing upward as far as
##    its page needs, stopped only by the map and alerts above it
##    ([method UIMetrics.inspector_detail_max_height]), past which the page
##    scrolls inside itself.
##
## **Tabs are a toggle, not a selector.** Nothing open is the resting state -
## ~115px of chrome - and pressing the open tab returns to it; a player who only
## wants to know what they clicked never pays for the rest. The open tab is
## remembered **per kind**, "none" included ([method InspectorTabPlan.tab_to_open]
## and [method InspectorTabPlan.tab_after_click] are the rule), so clicking
## through six colonists with Needs open keeps Needs open.
##
## There is **no title bar**. It used to be a [ReadoutPanel] whose 34px header said
## `SELECTED · CREW`; the portrait and name say the same thing in none of the
## height, and the close control moved into the strip. That makes the inspector
## the one right-column tenant that is not a readout frame, which is recorded in
## the program doc beside invariant 6.
##
## Nothing selected is **no panel at all** (2026-09-13). [UIMain] owns this
## panel's `visible` (its `_sync_inspector_visibility()`), because Trade and R&D
## hide it too and two writers would each undo the other.
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

## The tab each kind was last left on - `&""` included, which is how "left
## closed" is remembered. Session-only, like everything else about the HUD's
## open state.
var _last_tab: Dictionary[SelectionKind, StringName] = {}

## The tab whose page is showing, or `&""` for the resting strip.
var _open_tab: StringName = &""

## Pages built so far for the current selection, by tab id. Cleared wholesale on
## every selection change - a page holds a reference to the old subject, so
## keeping one across selections is how a stale panel gets built.
var _pages: Dictionary[StringName, Control] = {}

var _column: VBoxContainer
var _detail: PanelContainer
var _detail_box: StyleBoxFlat
var _scroll: ScrollContainer
var _page_host: MarginContainer
var _page_footer: VBoxContainer
var _footer_slot: MarginContainer
var _rail: InspectorTabRail
var _identity: PanelContainer
var _icon: ColorRect
var _icon_art: TextureRect
var _name_label: Label
var _meta_label: Label
var _status_label: Label
## Re-entrancy latch for [method _refit]: the fit writes a minimum size, which is
## exactly the signal that triggers it.
var _refitting: bool = false

static func create() -> InspectorPanel:
	return (load(SCENE_PATH) as PackedScene).instantiate() as InspectorPanel

func _ready() -> void:
	_build()
	_apply_selection()

# --- public API ----------------------------------------------------------------

## Selects `subject`, resolving its kind and swapping the tab set. Passing the
## already-selected subject deselects it, which is the behaviour all four old
## click handlers had.
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

## The tab whose page is showing, or `&""` when only the strip is. For probes and
## for anything that has to know whether the box is up.
func open_tab() -> StringName:
	return _open_tab

## The node the camera should travel to for the current selection - the other
## half of the jump-to pair WI-53 and WI-56 consume, alongside [method select],
## and what the strip's centre button uses.
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
		_set.tabs_changed.connect(_on_tabs_changed)
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
	_open_tab = &""

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
## freed *between* a deferred signal and the handler that reads it.
##
## One validity check per frame while something is selected, in one place.
## `set_process` is off entirely when nothing is selected.
func _process(_delta: float) -> void:
	if _set != null and not _set.is_alive():
		clear()

func _apply_selection() -> void:
	if _column == null:
		return
	var empty: bool = _kind == SelectionKind.NONE or _set == null
	set_process(not empty)
	if empty:
		# [UIMain] hides the panel off `selection_changed`. It is still emptied, so
		# the next select() never shows the last subject's pages for a frame.
		_clear_pages()
		_rail.set_tabs([])
		_rail.visible = false
		_show_tab(&"")
		return
	refresh_subject()
	_rebuild_tabs(_last_tab.get(_kind, &""))

# --- identity strip -------------------------------------------------------------

## Repaints the identity strip and the open page's footer. Cheap enough that a
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
	var art: Texture2D = _set.icon_texture()
	_icon_art.texture = art
	_icon_art.visible = art != null
	_rebuild_page_footer()
	_refit()

func _on_centre_pressed() -> void:
	var target: Node2D = camera_target()
	var camera: GameCamera = get_viewport().get_camera_2d() as GameCamera
	if target != null and camera != null:
		camera.jump_to(target.global_position)

# --- tabs ----------------------------------------------------------------------

## Rebuilds the rail from the set and opens `preferred` if this subject has it.
func _rebuild_tabs(preferred: StringName) -> void:
	if _set == null:
		return
	# The pages cached for tabs that did not survive the rebuild are dead weight
	# and would be shown again if the tab came back with different contents.
	_clear_pages()
	_rail.set_tabs(InspectorTabPlan.to_strip_defs(_set.tabs()))
	_rail.visible = not _rail.is_empty()
	_show_tab(InspectorTabPlan.tab_to_open(preferred, _rail.tab_ids()))

## The set's tab shape moved under a live selection. The open tab stays open if
## it survived; if it did not, the box closes - but the kind's memory is left
## alone, so the next subject that has the tab still opens on it.
func _on_tabs_changed() -> void:
	_rebuild_tabs(_open_tab)

func _on_tab_pressed(id: StringName) -> void:
	var next: StringName = InspectorTabPlan.tab_after_click(_open_tab, id)
	_last_tab[_kind] = next
	_show_tab(next)

## Shows `id`'s page in the detail box, building it on first use, or closes the
## box for `&""`.
func _show_tab(id: StringName) -> void:
	if id != &"" and _set != null and not _pages.has(id):
		var page: Control = _set.make_page(id)
		if page != null:
			_adopt_page(page)
			_pages[id] = page
			_page_host.add_child(page)
	# A set that declined to build the page (every Status source declined) leaves
	# nothing to show, which is the resting strip rather than an empty box.
	var shown: bool = id != &"" and _pages.has(id)
	_open_tab = id if shown else &""
	for page_id: StringName in _pages:
		var cached: Control = _pages[page_id]
		if is_instance_valid(cached):
			cached.visible = page_id == _open_tab
	_rail.set_open(_open_tab)
	_detail.visible = shown
	_rebuild_page_footer()
	_refit()

## Makes a page fit the inspector and hooks up the one signal a page may raise.
## The flattening itself is [method InspectorTabSet.flatten_page] - the tab sets
## need it too, for the pages WI-64 stacks inside one page.
func _adopt_page(page: Control) -> void:
	InspectorTabSet.flatten_page(page)
	if page.has_signal(&"subject_lost"):
		page.connect(&"subject_lost", _on_subject_lost)
	# The column's own `minimum_size_changed` cannot see the page: it sits inside a
	# [ScrollContainer], which reports a fixed minimum whatever its child asks for.
	# So a page that re-measures after it is mounted - an autowrap label learning
	# its width, which is every page opened from the resting strip, because it is
	# built while the box is still hidden - has to call the fit itself, or the box
	# keeps the height its first, widthless measurement asked for. A screenshot
	# caught that as a blank band under the Status tab.
	page.minimum_size_changed.connect(_queue_refit)

func _clear_pages() -> void:
	for id: StringName in _pages:
		var page: Control = _pages[id]
		if is_instance_valid(page):
			page.queue_free()
	_pages.clear()

func _rebuild_page_footer() -> void:
	if _footer_slot == null:
		return
	for child: Node in _footer_slot.get_children():
		_footer_slot.remove_child(child)
		child.queue_free()
	var row: Control = null
	if _set != null and _open_tab != &"":
		row = _set.page_footer(_open_tab)
	_page_footer.visible = row != null
	if row != null:
		_footer_slot.add_child(row)

# --- geometry ------------------------------------------------------------------

## Sizes the panel to its three parts and grows it upward from its bottom edge.
##
## The bottom edge is the fixed one (the console's top edge) and the top edge
## is what moves, which is why this writes `offset_top` rather than letting the
## size run downward.
##
## The page region is a [ScrollContainer], which reports a **minimum height of
## zero** - it is built to be handed a size, not to ask for one (WI-48's deviation
## 8). So its height is driven from the page's own combined minimum, capped by
## what the column leaves once the strip and rail have theirs.
##
## Measuring **once** is not enough: an autowrapped label reports a minimum height
## computed from its current width, so a page measured before layout has given it
## the panel's width asks for roughly twice the height it will need. So the fit
## re-runs whenever anything in the column changes size.
func _refit() -> void:
	if _column == null or _refitting:
		return
	_refitting = true
	# The strip and rail always fit, whatever the budget handed down (WI-58): a
	# frame that does not contain its own name is worse than one that overhangs
	# its budget by a few pixels. The page is what absorbs a shortfall, by
	# scrolling.
	var resting: float = _identity.get_combined_minimum_size().y
	if _rail.visible:
		resting += _rail.get_combined_minimum_size().y
	var height: float = resting
	if _detail.visible:
		var page: Control = _pages.get(_open_tab, null) as Control
		var page_min: float = page.get_combined_minimum_size().y if is_instance_valid(page) else 0.0
		var chrome: float = _detail_chrome_height()
		var cap: float = float(UIMetrics.inspector_detail_max_height(
			UIMetrics.SCREEN_SIZE.y, top_limit, int(ceilf(resting))))
		var page_height: float = minf(page_min, maxf(0.0, cap - chrome))
		_scroll.custom_minimum_size.y = page_height
		height += chrome + page_height
	else:
		_scroll.custom_minimum_size.y = 0.0
	custom_minimum_size = Vector2(float(UIMetrics.INSPECTOR_WIDTH), ceilf(height))
	offset_top = offset_bottom - custom_minimum_size.y
	_refitting = false

## Everything in the detail box except the scrolling page: its padding, and the
## footer row with the gap above it when the open page has one.
##
## Summed by hand rather than by zeroing the scroll and asking the box, because
## that mutate-measure-mutate dance invalidates the very cache it is about to read.
func _detail_chrome_height() -> float:
	var total: float = _detail_box.get_margin(SIDE_TOP) + _detail_box.get_margin(SIDE_BOTTOM)
	if _page_footer.visible:
		total += float(UIMetrics.INSPECTOR_FOOTER_GAP) + _page_footer.get_combined_minimum_size().y
	return total

## Deferred so a burst of layout changes in one frame settles into a single fit,
## and so the fit never runs inside the notification that caused it.
func _queue_refit() -> void:
	if _refitting:
		return
	_refit.call_deferred()

# --- construction ---------------------------------------------------------------

## The scene is a bare root; everything is built here (program decision 8), so the
## tab sets cannot drift out of sync with a hand-edited layout, and every number
## comes from [UIMetrics].
func _build() -> void:
	# The root only positions. The see-through half of the rail must let a click
	# through to the station, so nothing but the three parts may catch the mouse.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -float(UIMetrics.SCREEN_GUTTER)
	offset_left = offset_right - float(UIMetrics.INSPECTOR_WIDTH)
	offset_bottom = -float(UIMetrics.inspector_bottom_offset())
	offset_top = offset_bottom

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 0)
	_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A page wider than 420px widens the panel rather than clipping (WI-58); it has
	# to widen leftward, away from the screen edge.
	_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_column)
	# The backstop for the fit: fonts settling, an autowrap label learning its
	# width, the rail wrapping onto a second row all change what the column asks
	# for *after* the page was mounted and measured.
	_column.minimum_size_changed.connect(_queue_refit)

	_column.add_child(_build_detail())

	_rail = InspectorTabRail.new()
	_rail.tab_pressed.connect(_on_tab_pressed)
	_column.add_child(_rail)

	_column.add_child(_build_identity())

## The box an open tab rises into: bordered on three sides, open at the bottom
## where it meets the rail, its shadow thrown upward.
func _build_detail() -> PanelContainer:
	_detail = PanelContainer.new()
	_detail.name = "Detail"
	_detail.visible = false
	_detail_box = StyleBoxFlat.new()
	_detail_box.bg_color = UIPalette.tinted(UIPalette.PANEL, UIMetrics.INSPECTOR_ALPHA)
	_detail_box.border_color = UIPalette.ACTIVE_BORDER
	_detail_box.border_width_left = UIMetrics.BORDER_WIDTH
	_detail_box.border_width_right = UIMetrics.BORDER_WIDTH
	_detail_box.border_width_top = UIMetrics.BORDER_WIDTH
	_detail_box.border_width_bottom = 0
	_detail_box.content_margin_left = float(UIMetrics.INSPECTOR_PAD)
	_detail_box.content_margin_right = float(UIMetrics.INSPECTOR_PAD)
	_detail_box.content_margin_top = float(UIMetrics.INSPECTOR_PAD)
	_detail_box.content_margin_bottom = float(UIMetrics.INSPECTOR_PAD + UIMetrics.BORDER_WIDTH)
	_detail_box.shadow_color = UIPalette.READOUT_SHADOW
	_detail_box.shadow_size = UIMetrics.READOUT_SHADOW_SIZE
	_detail_box.shadow_offset = Vector2(0.0, -float(UIMetrics.INSPECTOR_SHADOW_OFFSET))
	_detail.add_theme_stylebox_override("panel", _detail_box)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", UIMetrics.INSPECTOR_FOOTER_GAP)
	_detail.add_child(stack)

	_scroll = ScrollContainer.new()
	_scroll.name = "PageScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(_scroll)

	_page_host = MarginContainer.new()
	_page_host.name = "PageHost"
	_page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_page_host)

	# The footer row under a page: a divider, then whatever the set hands back.
	_page_footer = VBoxContainer.new()
	_page_footer.name = "PageFooter"
	_page_footer.visible = false
	_page_footer.add_theme_constant_override("separation", UIMetrics.INSPECTOR_FOOTER_GAP)
	stack.add_child(_page_footer)
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.color = UIPalette.DIVIDER
	divider.custom_minimum_size.y = float(UIMetrics.BORDER_WIDTH)
	_page_footer.add_child(divider)
	_footer_slot = MarginContainer.new()
	_footer_slot.name = "Slot"
	_page_footer.add_child(_footer_slot)
	return _detail

## The strip on the panel's floor: icon, name block, centre and deselect.
func _build_identity() -> PanelContainer:
	_identity = PanelContainer.new()
	_identity.name = "Identity"
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.tinted(UIPalette.PANEL, UIMetrics.INSPECTOR_ALPHA)
	box.border_color = UIPalette.ACTIVE_BORDER
	box.set_border_width_all(UIMetrics.BORDER_WIDTH)
	# No bottom edge: the strip sits on the console, whose cyan top border is that
	# edge - the same reason a left panel wears no border where it meets the
	# console. Two rules one pixel apart would read as a seam.
	box.border_width_bottom = 0
	# Children start inside the border, so the inner highlight below lands under
	# the top edge rather than over it.
	box.set_content_margin_all(float(UIMetrics.BORDER_WIDTH))
	box.content_margin_bottom = 0.0
	box.shadow_color = UIPalette.READOUT_SHADOW
	box.shadow_size = UIMetrics.READOUT_SHADOW_SIZE
	box.shadow_offset = Vector2(0.0, float(UIMetrics.INSPECTOR_SHADOW_OFFSET))
	_identity.add_theme_stylebox_override("panel", box)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 0)
	_identity.add_child(stack)

	# The 1px inner top highlight every surface wears (invariant 6).
	var highlight := ColorRect.new()
	highlight.name = "Highlight"
	highlight.color = UIPalette.INNER_HIGHLIGHT
	highlight.custom_minimum_size.y = float(UIMetrics.BORDER_WIDTH)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(highlight)

	var pad := MarginContainer.new()
	pad.name = "Pad"
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, UIMetrics.INSPECTOR_PAD)
	stack.add_child(pad)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", UIMetrics.INSPECTOR_STRIP_GAP)
	pad.add_child(row)

	row.add_child(_build_icon())

	var names := VBoxContainer.new()
	names.name = "Names"
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override("separation", UIMetrics.LINE_GAP)
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
	names.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", UIMetrics.INSPECTOR_STRIP_BUTTON_GAP)
	row.add_child(buttons)
	buttons.add_child(_strip_button("Centre", "◎", "Centre the camera on this", _on_centre_pressed))
	buttons.add_child(_strip_button("Close", "✕", "Deselect (Esc)", clear))
	return _identity

## The framed icon: the subject's tint, with its artwork over it when it has any.
func _build_icon() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.name = "IconFrame"
	var side: float = float(UIMetrics.INSPECTOR_ICON_SIZE)
	frame.custom_minimum_size = Vector2(side, side)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.DIVIDER
	box.border_color = UIPalette.ICON_FRAME_BORDER
	box.set_border_width_all(UIMetrics.BORDER_WIDTH)
	box.set_content_margin_all(float(UIMetrics.INSPECTOR_ICON_INSET))
	frame.add_theme_stylebox_override("panel", box)

	_icon = ColorRect.new()
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_icon)

	# Anchored inside the tint rather than replacing it, so a subject with no art
	# still reads as a coloured block instead of a hole.
	_icon_art = TextureRect.new()
	_icon_art.name = "Art"
	_icon_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.add_child(_icon_art)
	return frame

## One of the strip's two square buttons. A secondary [ActionButton] with its
## padding taken out, because the theme's padding is sized for a word and these
## carry one glyph in a 30px square.
func _strip_button(node_name: String, glyph: String, tip: String, action: Callable) -> ActionButton:
	var button: ActionButton = ActionButton.create("", ActionButton.Weight.SECONDARY)
	button.name = node_name
	button.caps = false
	button.set_label(glyph)
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	var side: float = float(UIMetrics.INSPECTOR_STRIP_BUTTON)
	button.custom_minimum_size = Vector2(side, side)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var themed: StyleBox = button.get_theme_stylebox(state, UIType.ACTION_SECONDARY)
		if themed == null:
			continue
		var square: StyleBox = themed.duplicate() as StyleBox
		square.content_margin_left = 0.0
		square.content_margin_right = 0.0
		square.content_margin_top = 0.0
		square.content_margin_bottom = 0.0
		button.add_theme_stylebox_override(state, square)
	button.pressed.connect(action)
	return button
