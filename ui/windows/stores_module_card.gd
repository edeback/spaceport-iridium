class_name StoresModuleCard
extends PanelContainer

## One storage bin in the Stores panel (WI-56):
## `name / location · fill · priority stepper · contents chips`.
##
## **The stepper is the only editable control on the card and gets the widest hit
## target** - the design is explicit about it, because haul priority is the one
## number on this screen that changes how the station behaves. Sign is carried by
## colour as well as by the number: cyan pulls stock in, amber pushes it away
## ([method StoresModel.priority_color], which is the shared sign rule, not a
## second table).
##
## **Contents are chips, not a table.** *"Modules hold two or three resource
## types, not thirty, so chips read faster than columns and wrap cleanly as
## storage tech grows."* A bin mid-cargo-sweep can hold many more, so the row is
## capped and summarised - a card must not grow unbounded.
##
## ## The one rule this card must not break
##
## Priority writes go through [method StorageComponent.update_priority], never a
## field assignment. Assigning `priority` alone leaves already-posted import and
## export jobs at their old priority, and [JobManager]'s re-sort cannot repair an
## ordering nothing told it had changed - a real WI-45 finding (A5) that a
## station-wide panel makes eight times easier to hit. The [Stepper]'s commit rule
## is the other half: holding `+` from −100 to +100 must produce **one** re-sort,
## not two hundred, which is the case that widget was built for.
##
## Code-built rather than a `.tscn`, like [UnlockNodeCard]: the layout is a header
## row and a wrap of chips, and a scene file would only be a second place for the
## constants below to disagree with themselves.

## How many content chips a card shows before it summarises the rest. An
## `allow_any_resource` bin mid-sweep is the case this exists for.
const MAX_CHIPS: int = 8

## Fixed column widths, so a name gaining a character does not shunt the stepper
## sideways down a 1080px list.
const NAME_MIN_WIDTH: int = 260
## Wide enough for the [Stepper] scene (106px) with the widest caption
## [method StoresModel.priority_label] produces centred under it.
const PRIORITY_COLUMN: int = 170
const FILL_WIDTH: int = 120
## Side of a content chip's resource icon.
const CHIP_ICON: int = 16

## A card was clicked: fill the shared inspector with this module.
signal selected(module: ModuleBase)
## An overlay changed something, so the panel should repaint now rather than on
## its next tick.
signal changed

var component: StorageComponent = null

var _name_button: Button
var _names: VBoxContainer
var _name_label: Label
var _meta_label: Label
var _priority_caption: Label
var _stepper: Stepper
var _fill_bar: HatchBar
var _fill_label: Label
var _chips: HFlowContainer
var _edit_button: ActionButton
var _locked_note: Label

static func create() -> StoresModuleCard:
	var card := StoresModuleCard.new()
	card._build()
	return card

# --- construction ------------------------------------------------------------------

func _build() -> void:
	if _name_label != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _card_style())

	var pad := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	pad.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	column.add_child(head)

	head.add_child(_build_name_block())
	head.add_child(_build_fill_block())
	head.add_child(_build_priority_block())

	_edit_button = ActionButton.create("Edit", ActionButton.Weight.SECONDARY)
	_edit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_edit_button.pressed.connect(_on_edit_pressed)
	head.add_child(_edit_button)

	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", UIMetrics.ROW_GAP)
	_chips.add_theme_constant_override("v_separation", UIMetrics.ROW_GAP)
	column.add_child(_chips)

	# A read-only card **says so**; it is not hidden (WI-54: locked is a state, not
	# an absence). "Why is the refinery hoarding ore" is a question this panel
	# should answer even where the answer cannot be edited.
	_locked_note = _label(UIType.META_LINE)
	_locked_note.add_theme_color_override("font_color", UIPalette.TEXT_META)
	_locked_note.visible = false
	column.add_child(_locked_note)

## The name and location, as the card's click target.
##
## A [Button] with anchored children, and its height driven from theirs: [Button]
## overrides `get_minimum_size()` in C++ and never consults a script's, so
## `custom_minimum_size` is the only channel that gets through - and it has to
## re-run on `minimum_size_changed`, because a label learns its own height only
## once layout has given it a width. Same pair of traps [ListRow] documents.
func _build_name_block() -> Button:
	_name_button = Button.new()
	_name_button.flat = true
	_name_button.focus_mode = Control.FOCUS_NONE
	_name_button.custom_minimum_size.x = float(NAME_MIN_WIDTH)
	_name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_button.pressed.connect(_on_open_pressed)

	_names = VBoxContainer.new()
	_names.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_names.add_theme_constant_override("separation", 2)
	_name_button.add_child(_names)
	_names.minimum_size_changed.connect(_refit_name_block)

	_name_label = _label(UIType.ENTITY_NAME)
	_names.add_child(_name_label)
	_meta_label = _label(UIType.META_LINE)
	_meta_label.add_theme_color_override("font_color", UIPalette.TEXT_META)
	_names.add_child(_meta_label)
	_refit_name_block()
	return _name_button

func _refit_name_block() -> void:
	if _names == null or _name_button == null:
		return
	_name_button.custom_minimum_size.y = _names.get_combined_minimum_size().y

func _build_fill_block() -> VBoxContainer:
	var fill := VBoxContainer.new()
	fill.custom_minimum_size.x = float(FILL_WIDTH)
	fill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fill.add_theme_constant_override("separation", 4)
	_fill_label = _label(UIType.METRIC)
	_fill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fill.add_child(_fill_label)
	_fill_bar = HatchBar.new()
	fill.add_child(_fill_bar)
	return fill

func _build_priority_block() -> VBoxContainer:
	var priority := VBoxContainer.new()
	priority.custom_minimum_size.x = float(PRIORITY_COLUMN)
	priority.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	priority.add_theme_constant_override("separation", 4)
	_stepper = Stepper.create()
	_stepper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stepper.value_changed.connect(_on_priority_committed)
	_stepper.value_previewed.connect(_apply_priority_caption)
	priority.add_child(_stepper)
	# The caption under the number is what turns an abstract −100…+100 into a
	# routing decision. It follows the stepper's *preview* as well as its commit,
	# so the words move with the number under the player's thumb.
	_priority_caption = _label(UIType.META_LINE)
	_priority_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	priority.add_child(_priority_caption)
	return priority

func _ready() -> void:
	_build()

func _label(variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.CONTROL_FILL
	box.border_color = UIPalette.DIVIDER
	box.set_border_width_all(UIMetrics.BORDER_WIDTH)
	box.set_corner_radius_all(0)
	return box

# --- content --------------------------------------------------------------------

func bind(entry: StoresModel.Entry) -> void:
	_build()
	component = entry.component
	_name_label.text = entry.title
	_name_button.tooltip_text = entry.title
	# Step 1, not a coarser grid: the range is 201 values and a step of 5 would put
	# `0` out of reach from the scene default of 1. The hold-repeat covers the
	# distance and the commit rule covers the cost of crossing it.
	_stepper.configure(entry.priority, StoresModel.PRIORITY_MIN, StoresModel.PRIORITY_MAX, 1, true)
	_stepper.editable = entry.configurable
	refresh(entry)

## Repaints everything that moves. Called on the panel's slow tick as well as on
## bind, so it has to be safe to run while the player is mid-drag - which is what
## [method Stepper.is_editing] is for: a tick landing mid-drag would otherwise
## snatch the number back to whatever the sim last agreed with, and the commit a
## moment later would write *that* value out as if the player had chosen it.
func refresh(entry: StoresModel.Entry) -> void:
	if component == null or not is_instance_valid(component):
		return
	_meta_label.text = _meta_text(entry).to_upper()
	if not _stepper.is_editing():
		_stepper.value = entry.priority
		_apply_priority_caption(entry.priority)
	var fraction: float = entry.fill()
	_fill_label.text = "%d / %d" % [entry.stored, entry.capacity]
	_fill_bar.fraction = fraction
	# A full bin stops accepting deliveries, which is a routing fact and therefore
	# worth the amber; anything below that is just a level.
	_fill_bar.fill_color = UIPalette.ATTENTION if fraction >= 1.0 else UIPalette.LIVE
	_edit_button.tooltip_text = "Accepted resources and the fill meter"
	_locked_note.text = _locked_text(entry).to_upper()
	_locked_note.visible = not _locked_note.text.is_empty()
	_rebuild_chips()

func _meta_text(entry: StoresModel.Entry) -> String:
	var parts: Array[String] = ["Cell %d,%d" % [entry.cell.x, entry.cell.y]]
	parts.append("%d free" % maxi(entry.capacity - entry.stored, 0))
	if entry.under_construction:
		parts.append("Under construction")
	return " · ".join(parts)

func _locked_text(entry: StoresModel.Entry) -> String:
	if entry.configurable:
		return ""
	if entry.under_construction:
		return "Construction site — the build sets what it imports"
	return "Set by the module — readable here, edited where it is produced"

## One chip per stored resource: amount against desired, and for a
## variance-carrying resource the bin's average richness or quality - the same
## `14 (72%)` form the inspector's storage tab prints.
##
## Capped and summarised, because an `allow_any_resource` bin mid-cargo-sweep can
## hold a dozen types and the card must not grow unbounded.
func _rebuild_chips() -> void:
	for child: Node in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	var shown: int = 0
	var hidden: int = 0
	for resource: ResourceData in component.storage_data:
		if shown >= MAX_CHIPS:
			hidden += 1
			continue
		_chips.add_child(_make_chip(resource, component.storage_data[resource]))
		shown += 1
	if hidden > 0:
		var more: Chip = Chip.create()
		more.configure("+%d more" % hidden)
		_chips.add_child(more)
	if shown == 0 and hidden == 0:
		var empty: Chip = Chip.create()
		empty.configure("Empty")
		_chips.add_child(empty)

## A **clickable** chip: a [Button] wearing [method Chip.chip_style]. Not a [Chip]
## with a `gui_input` handler - hover, press and focus come from the theme or they
## come from four hand-rolled reimplementations (WI-49), and this is a control the
## player uses to destroy resources.
##
## Auto-dump is a visible per-chip state (amber, with a glyph) rather than a
## setting buried in a modal about something else: a *silently destroying* setting
## must be visible from the overview.
func _make_chip(resource: ResourceData, data: StorageData) -> Button:
	var kind: UIPalette.Row = UIPalette.Row.AMBER if data.autodump else UIPalette.Row.INERT
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = "%s  %s" % [resource.name, _chip_value(resource, data)]
	button.icon = resource.icon
	button.add_theme_constant_override("icon_max_width", CHIP_ICON)
	button.tooltip_text = "%s — keep %d · click to set the desired amount, dump or auto-dump" % [
		resource.name, data.desired]
	var style: StyleBoxFlat = Chip.chip_style(kind)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	var hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover.bg_color = UIPalette.tinted(UIPalette.LIVE,
		maxf(style.bg_color.a, 0.0) + UIPalette.ROW_LIVE_ALPHA)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", UIPalette.row_text(kind))
	button.pressed.connect(_on_chip_pressed.bind(resource))
	return button

func _chip_value(resource: ResourceData, data: StorageData) -> String:
	var text: String = str(data.stored)
	if data.desired != data.stored:
		text += "/%d" % data.desired
	if resource.has_variance:
		var average: float = data.average_instance_value()
		if average >= 0.0:
			text += " (%d%%)" % roundi(average * 100.0)
	if data.autodump:
		text += " ⌦"
	return text

# --- interaction -----------------------------------------------------------------

## The committed value only. [Stepper] fires this on release or after a quiet
## period, which is what keeps a drag across the whole range to one re-sort.
## This card's priority control, so a probe or a screenshot driver can move it
## through the same commit path the player's thumb does. Reaching past the widget
## and calling [method StorageComponent.update_priority] directly would assert
## nothing about the one rule this card exists to keep.
func priority_stepper() -> Stepper:
	return _stepper

func _on_priority_committed(value: int) -> void:
	if component == null or not is_instance_valid(component):
		return
	# update_priority, never a field write: a bare assignment leaves already-posted
	# haul jobs at their old priority (WI-45 A5).
	component.update_priority(value)
	_apply_priority_caption(value)

func _apply_priority_caption(value: int) -> void:
	_priority_caption.text = StoresModel.priority_label(value).to_upper()
	_priority_caption.add_theme_color_override("font_color", StoresModel.priority_color(value))

func _on_open_pressed() -> void:
	if component != null and is_instance_valid(component) and component.owner_module != null:
		selected.emit(component.owner_module)

func _on_edit_pressed() -> void:
	StorageOverlays.open_edit(Global.ui_main, component, _on_overlay_applied)

func _on_chip_pressed(resource: ResourceData) -> void:
	StorageOverlays.open_resource(Global.ui_main, component, resource, _on_overlay_applied)

func _on_overlay_applied() -> void:
	changed.emit()
