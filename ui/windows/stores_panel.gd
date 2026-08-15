class_name StoresPanel
extends VBoxContainer

## The body of the STORES mode panel (WI-56): every bin on the station, its haul
## priority and its contents, at 1080px.
##
## The other panel in this program with **no predecessor**. Comparing two
## storerooms' priorities meant clicking each module in turn, which is the reason
## the routing language is hard to learn: storage priority *is* how the hauling
## system decides where goods go - construction imports at +99, deconstruction
## exports at −99, sinks out-prioritising sources ([StorageQuery]) - and the
## player met it as an unlabelled spinbox, one bin at a time. The legend line
## under the header is the first time the game says out loud what the number does,
## and *"a range that abstract needs its legend on screen, not in a tooltip"* is
## why it is a permanent line rather than a hover.
##
## ## Presentation only
##
## Program decision 4: this panel surfaces and edits **everything WI-12 shipped** -
## per-module haul priority, the per-resource desired amount, current contents,
## the accepted-resource checklist, manual dump with an amount, the auto-dump
## toggle, free space and the fill-meter switch - and adds **no storage
## mechanics**. WI-12's two dropped tasks (the `draining` flag and the trade
## panel's mass-sell) stay dropped; see [01_Technical_Specification] §2.1.
##
## ## Which bins appear
##
## Any [StorageComponent] on a placed module, processor bays and construction
## sites included. Those are not `player_configurable`, so they render with their
## stepper disabled and their contents readable, and the card says why - *"'why is
## the refinery hoarding ore' is a question this panel should answer even where it
## can't be edited"*. A read-only card is a state, not an absence (WI-54).
##
## Row click is [method InspectorPanel.select] plus a camera jump, the same two
## calls the Crew roster makes. This panel does not own a detail view.

## The panel's standing instruction, in the frame's footer strip (WI-54 contract
## point 1) rather than as the last row of a list that scrolls.
const FOOTER: String = "Click a card to inspect · click a chip to dump or auto-dump it"

## Sort captions, in the picker's order.
const SORT_ORDER: Array[StoresModel.Sort] = [
	StoresModel.Sort.PRIORITY, StoresModel.Sort.NAME, StoresModel.Sort.FILL,
]
const SORT_LABELS: Dictionary[StoresModel.Sort, String] = {
	StoresModel.Sort.PRIORITY: "Priority",
	StoresModel.Sort.NAME: "Name",
	StoresModel.Sort.FILL: "Fill",
}

var _frame: ConsolePanel
var _list: VBoxContainer
var _sort_picker: OptionButton
var _empty_label: Label
var _sort: StoresModel.Sort = StoresModel.Sort.PRIORITY
## Component -> its card, so a tick repaints in place rather than rebuilding the
## list under the player's cursor. A rebuild only happens when the *set* of bins
## changes, which is what [method _rebuild] is for.
var _cards: Dictionary[StorageComponent, StoresModuleCard] = {}
## The order the cards are currently in, so a repaint can tell "the same bins in
## the same order" from "something changed".
var _order: Array[StorageComponent] = []

## Builds the frame and mounts this body in it. One call, like the widgets have -
## [UIMain] stays a mount table.
static func create() -> ConsolePanel:
	var frame: ConsolePanel = ConsolePanel.create()
	frame.title = "Stores"
	frame.panel_width = UIMetrics.PANEL_STORES_WIDTH
	frame.content_padding = 0
	frame.hotkey = ModeManager.hotkey_label(ModeManager.Mode.STORES)
	frame.footer_text = FOOTER
	frame.footer_variation = UIType.BODY
	# 1080px still leaves room for the 344px right column and its gutters at 1920,
	# so the inspector stays: a card click fills it, and hiding the thing the click
	# targets would make the panel's own selection pointless.
	var body := StoresPanel.new()
	body._frame = frame
	frame.content().add_child(body)
	return frame

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_body()
	_connect_sources()

# --- construction ------------------------------------------------------------------

func _build_body() -> void:
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	pad.add_child(column)

	column.add_child(_build_legend())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.theme_type_variation = UIType.META_LINE
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_color_override("font_color", UIPalette.TEXT_META)
	_empty_label.text = "NO STORAGE BUILT — EVERY MODULE THAT HOLDS STOCK APPEARS HERE"
	_empty_label.visible = false
	column.add_child(_empty_label)

## The legend and the sort control.
##
## The legend is the load-bearing half: it is the sentence that turns −100…+100
## from an abstract dial into a routing decision, and it is on screen permanently
## because that is where a player learns it. It renders as its own line rather
## than in [member ConsolePanel.footer_text] because the footer already carries the
## panel's interaction instruction, and the two say different kinds of thing.
func _build_legend() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)

	var legend := Label.new()
	legend.theme_type_variation = UIType.META_LINE
	legend.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.text = StoresModel.LEGEND.to_upper()
	column.add_child(legend)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	column.add_child(tools)

	var caption := Label.new()
	caption.text = "SORT"
	caption.theme_type_variation = UIType.READOUT_LABEL
	caption.add_theme_color_override("font_color", UIPalette.TEXT_META)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tools.add_child(caption)

	_sort_picker = OptionButton.new()
	for sort: StoresModel.Sort in SORT_ORDER:
		_sort_picker.add_item(SORT_LABELS[sort])
	_sort_picker.select(0)
	_sort_picker.item_selected.connect(_on_sort_selected)
	tools.add_child(_sort_picker)
	return column

## Everything that can change the list. The slow tick is the contents driver -
## stock moves on hauls, and there is no signal for that worth subscribing to at
## HUD granularity - while the two module signals change *which* bins exist.
func _connect_sources() -> void:
	SignalBus.module_added.connect(_on_modules_changed.unbind(1))
	SignalBus.module_removed.connect(_on_modules_changed.unbind(1))
	if Global.time_manager != null:
		Global.time_manager.slow_tick.connect(_on_slow_tick.unbind(1))

# --- mode hooks -----------------------------------------------------------------------

func on_opened() -> void:
	refresh()

# --- refresh --------------------------------------------------------------------------

func _on_slow_tick() -> void:
	if is_visible_in_tree():
		refresh()

## A module appearing or going away changes the *set* of cards, and the removal
## half is deferred for the same reason the crew roster's is: the module is still
## in the tree when the signal fires and gone by the end of the frame.
func _on_modules_changed() -> void:
	_rebuild_deferred.call_deferred()

func _rebuild_deferred() -> void:
	if is_visible_in_tree():
		refresh()

## Repaints, rebuilding the card list only when the set or the order of bins has
## actually changed.
##
## Rebuilding unconditionally would free and re-create every card on every slow
## tick, which is four times a sim-second - and would take the player's cursor,
## any half-opened stepper drag and the scroll position with it. The order is part
## of the comparison because a sort by fill legitimately reorders as stock moves.
func refresh() -> void:
	if _list == null:
		return
	var entries: Array = StoresModel.sort_entries(_collect_entries(), _sort)
	_apply_header(entries)
	var order: Array[StorageComponent] = []
	for item: Variant in entries:
		order.append((item as StoresModel.Entry).component)
	if order != _order:
		_rebuild(entries, order)
		return
	for item: Variant in entries:
		var entry: StoresModel.Entry = item as StoresModel.Entry
		var card: StoresModuleCard = _cards.get(entry.component)
		if card != null and is_instance_valid(card):
			card.refresh(entry)

func _rebuild(entries: Array, order: Array[StorageComponent]) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_cards.clear()
	_order = order
	for item: Variant in entries:
		var entry: StoresModel.Entry = item as StoresModel.Entry
		var card: StoresModuleCard = StoresModuleCard.create()
		_list.add_child(card)
		card.bind(entry)
		card.selected.connect(_on_card_selected)
		card.changed.connect(refresh)
		_cards[entry.component] = card
	_empty_label.visible = entries.is_empty()

func _apply_header(entries: Array) -> void:
	if _frame == null or not is_instance_valid(_frame):
		return
	_frame.subtitle = StoresModel.subtitle_text(entries)

## Every listed bin, as a flat [StoresModel.Entry] list.
##
## Walks [member WorldManager.id_to_module] rather than the
## [constant Groups.RESOURCE_STORAGE] group, deliberately: a component joins and
## leaves that group as `accepts_exports` flips, so membership is **not** the same
## as "has a StorageComponent" - and a bin that has stopped exporting is still a
## bin whose priority the player may want to see. `id_to_module` is the module
## registry, which is the question actually being asked.
func _collect_entries() -> Array:
	var entries: Array = []
	var world: WorldManager = Global.world_manager
	if world == null:
		return entries
	for module: ModuleBase in world.id_to_module.values():
		if not is_instance_valid(module):
			continue
		var bins: Array[StorageComponent] = []
		for component: ComponentBase in module.components:
			var storage := component as StorageComponent
			if storage != null and StoresModel.lists(storage):
				bins.append(storage)
		for storage: StorageComponent in bins:
			entries.append(_make_entry(module, storage, bins.size() > 1))
	return entries

## A module can carry several bins - a processor has an input bay and an output
## bay - and each is its own card: they have their own priorities and their own
## contents, and merging them would hide exactly the case this panel is for. The
## component's own node name disambiguates them, and only when there is something
## to disambiguate.
func _make_entry(module: ModuleBase, storage: StorageComponent,
		several: bool) -> StoresModel.Entry:
	var entry := StoresModel.Entry.new()
	entry.component = storage
	var module_name: String = module.module_data.name if module.module_data != null \
		and module.module_data.name != "" else module.name
	entry.title = "%s · %s" % [module_name, storage.name] if several else module_name
	entry.cell = module.module_cell
	entry.priority = storage.priority
	entry.stored = storage.max_stored - storage.space_available()
	entry.capacity = storage.max_stored
	# Through the model, not off the flag: the inspector's storage tab and the chip
	# dialog read the same call, so "may I change what this bin holds?" has one
	# answer (WI-58). Priority is a separate question and is never gated on it.
	entry.contents_configurable = StoresModel.contents_editable(storage)
	entry.under_construction = not module.is_complete()
	return entry

# --- interaction -------------------------------------------------------------------------

func _on_sort_selected(index: int) -> void:
	if index < 0 or index >= SORT_ORDER.size():
		return
	_sort = SORT_ORDER[index]
	# The order changes, so the next refresh rebuilds rather than repainting.
	_order.clear()
	refresh()

## The cards currently listed, in display order.
func cards() -> Array[StoresModuleCard]:
	var out: Array[StoresModuleCard] = []
	for child: Node in _list.get_children():
		var card := child as StoresModuleCard
		if card != null:
			out.append(card)
	return out

## [method InspectorPanel.select] toggles when handed the already-selected
## subject, which is right for a click on the station and wrong here - a card
## click that deselected would leave the player looking at nothing. Same guard
## WI-53's jump-to and the Crew roster both use.
func _on_card_selected(module: ModuleBase) -> void:
	if Global.ui_main == null or not is_instance_valid(Global.ui_main):
		return
	var inspector: InspectorPanel = Global.ui_main.inspector
	if inspector == null or not is_instance_valid(inspector):
		return
	if inspector.selected_subject() != module:
		inspector.select(module)
	var target: Node2D = inspector.camera_target()
	var camera: GameCamera = get_viewport().get_camera_2d() as GameCamera
	if camera != null and target != null:
		camera.jump_to(target.global_position)
