class_name ModuleButton
extends Button

## One module in the Build panel's flyout (WI-54), and - in [member compact]
## form - one tile in the recently-built strip.
##
## Three states, all of them the same control:
##
##   - **buildable**: icon, name, cost meta line, footprint. The cost goes amber
##     when the station cannot pay for it, which is the affordability cue the old
##     per-resource cost chips carried.
##   - **selected**: the same, plus the module's description and its declared
##     rate/draw line, inline. The design puts the explanation *in the list*
##     rather than in a hover tooltip because that "survives keyboard and
##     controller navigation, and is readable while the ghost is already on the
##     station" - so it also expands on focus, not only on being picked up.
##   - **locked**: dimmed, with the tech that grants it in place of the cost and
##     a lock glyph in place of the footprint. Locked entries stay in the list;
##     hiding them is what made the tech tree illegible.
##
## Layout note, the same one [ListRow] carries: [Button] overrides
## `get_minimum_size()` in C++ and never consults the script virtual, so the only
## channel that can give this row a height that fits two-or-five lines of content
## is `custom_minimum_size`. The content is therefore laid out by an
## anchored container and the height is derived from it in [method _refit], which
## re-runs whenever the content or the width changes - the description autowraps,
## so its height is not known until it has a width.

## Cell footprint of a module whose scene could not be read. Never rendered in
## practice; here so the label is never blank.
const FALLBACK_FOOTPRINT := Vector2i.ONE

## Stands in for the footprint on a locked row.
const LOCK_GLYPH: String = "🔒"

var module_data: ModuleData

## Icon-only tile mode for the recently-built strip: a fixed square, no text at
## all, the name still reachable on hover through the tooltip.
var compact: bool = false:
	set(value):
		compact = value
		_apply_compact()

## True while this is the module the player has picked up. Takes the live row
## treatment and expands.
var selected: bool = false:
	set(value):
		if selected == value:
			return
		selected = value
		_apply_kind()
		_apply_expansion()

## Set by the menu from [method UnlockManager.is_module_granted]. A locked row is
## rendered, dimmed, and does nothing when pressed.
var locked: bool = false
## What a locked row prints where a buildable one prints its cost.
var gating_label: String = ""

var _accent: ColorRect
var _column: VBoxContainer
var _head: HBoxContainer
var _icon: TextureRect
var _text: VBoxContainer
var _name_label: Label
var _cost_label: Label
var _footprint_label: Label
var _description: Label
var _facts: HBoxContainer

var _kind: UIPalette.Row = UIPalette.Row.INERT
var _facts_built: bool = false
var _refitting: bool = false

static func create() -> ModuleButton:
	return (load("res://ui/buttons/module_button.tscn") as PackedScene).instantiate() as ModuleButton

func _ready() -> void:
	_ensure_refs()
	pressed.connect(_on_pressed)
	# Focus is the keyboard/controller half of "selected": the design's whole
	# argument for putting the explanation inline is that it survives navigation,
	# and a row that only opened on a mouse press would not.
	focus_entered.connect(_apply_expansion)
	focus_exited.connect(_apply_expansion)
	if _column != null and not _column.minimum_size_changed.is_connected(_refit):
		_column.minimum_size_changed.connect(_refit)
	# The description autowraps, so its height only becomes knowable once the row
	# has a width - which is one layout pass after it is added.
	resized.connect(_refit)
	_apply_kind()
	_refit()

func _ensure_refs() -> void:
	if _name_label != null:
		return
	_accent = get_node_or_null("Accent") as ColorRect
	_column = get_node_or_null("Column") as VBoxContainer
	_head = get_node_or_null("Column/Head") as HBoxContainer
	_icon = get_node_or_null("Column/Head/Icon") as TextureRect
	_text = get_node_or_null("Column/Head/Text") as VBoxContainer
	_name_label = get_node_or_null("Column/Head/Text/Name") as Label
	_cost_label = get_node_or_null("Column/Head/Text/Cost") as Label
	_footprint_label = get_node_or_null("Column/Head/Footprint") as Label
	_description = get_node_or_null("Column/Description") as Label
	_facts = get_node_or_null("Column/Facts") as HBoxContainer

# --- content -------------------------------------------------------------------

func set_moduledata(data: ModuleData) -> void:
	_ensure_refs()
	module_data = data
	if module_data == null:
		return
	if _icon != null:
		_icon.texture = module_data.icon
	if _name_label != null:
		_name_label.text = module_data.name
	if _description != null:
		_description.text = module_data.description
	_refresh_cost()
	_refresh_footprint()
	# Repaint the cost when the station's stock moves, so a row that was
	# unaffordable stops being amber the moment the ore lands. Connections to a
	# freed node drop themselves, so a row rebuilt on a category change does not
	# leak one.
	for resource: ResourceData in module_data.resource_costs:
		if resource != null and not resource.total_changed.is_connected(_on_stock_changed):
			resource.total_changed.connect(_on_stock_changed)
	_apply_kind()
	_apply_expansion()

## Marks the row as gated behind `label`'s tech. Call after [method
## set_moduledata] - it replaces the cost line.
func set_locked(is_locked: bool, label: String = "") -> void:
	_ensure_refs()
	locked = is_locked
	gating_label = label
	# A locked row is still a row - it reports, it just cannot be acted on - so
	# the whole control dims rather than the parts of it disappearing.
	modulate = UIPalette.MODULATE_LOCKED if locked else Color.WHITE
	mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	_refresh_cost()
	_refresh_footprint()
	_apply_expansion()

func _refresh_cost() -> void:
	if _cost_label == null or module_data == null:
		return
	if locked:
		_cost_label.text = gating_label.to_upper()
		_cost_label.add_theme_color_override("font_color", UIPalette.TEXT_META)
		return
	var text: String = BuildMenuModel.format_cost(module_data.resource_costs)
	_cost_label.text = text
	_cost_label.visible = not text.is_empty()
	# Amber, not red: "cannot pay for this yet" is the same class of thing as a
	# falling vital, and the palette has one colour for that (invariant 5).
	var affordable: bool = module_data.can_afford()
	_cost_label.add_theme_color_override("font_color",
		UIPalette.row_meta(_kind) if affordable else UIPalette.ATTENTION_TEXT)

func _refresh_footprint() -> void:
	if _footprint_label == null:
		return
	if locked:
		_footprint_label.text = LOCK_GLYPH
		_footprint_label.add_theme_color_override("font_color", UIPalette.TEXT_META)
		return
	var footprint: Vector2i = _footprint()
	_footprint_label.text = BuildMenuModel.format_footprint(footprint)
	_footprint_label.add_theme_color_override("font_color",
		UIPalette.LIVE if selected else UIPalette.TEXT_META)

func _footprint() -> Vector2i:
	var facts: ModuleFacts = _facts_for(module_data)
	return facts.footprint if facts != null else FALLBACK_FOOTPRINT

func _on_stock_changed(_total: int) -> void:
	_refresh_cost()

# --- the expanded (selected) block ----------------------------------------------

## The description and the rate/draw line are only built once, and only for a row
## that actually opens - reading a module's declared numbers means instantiating
## its scene, and doing that for every row in a category would cost forty scene
## instantiations to render a list.
func _apply_expansion() -> void:
	_ensure_refs()
	if _description == null or _facts == null:
		return
	var open: bool = not compact and not locked and (selected or has_focus())
	if open and not _facts_built:
		_build_facts()
	_description.visible = open and not _description.text.is_empty()
	_facts.visible = open and _facts.get_child_count() > 0
	_refit()

func _build_facts() -> void:
	_facts_built = true
	var facts: ModuleFacts = _facts_for(module_data)
	if facts == null:
		return
	for part: String in facts.summary_parts():
		var label := Label.new()
		label.text = part
		label.theme_type_variation = UIType.META_LINE
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color",
			UIPalette.ATTENTION_TEXT if BuildMenuModel.fact_is_a_cost(part) else UIPalette.LIVE)
		_facts.add_child(label)

## The scene-read numbers, through the owning menu's cache. The cache lives on
## [BuildMenu] (keyed by [PackedScene], exactly as [PreviewModule]'s preview
## cache is) rather than in a static here, so it dies with the HUD instead of
## holding every inspected scene alive across a Quit-to-Menu. A row with no menu
## above it - a probe, a test harness - reads the scene uncached, which is
## correct if slow and is never the shipping path.
func _facts_for(data: ModuleData) -> ModuleFacts:
	if data == null or data.scene == null:
		return null
	var menu: BuildMenu = _owning_menu()
	if menu == null:
		return ModuleFacts.from_scene(data.scene)
	return menu.facts_for(data.scene)

func _owning_menu() -> BuildMenu:
	var node: Node = get_parent()
	while node != null:
		var menu: BuildMenu = node as BuildMenu
		if menu != null:
			return menu
		node = node.get_parent()
	return null

# --- appearance ------------------------------------------------------------------

func _apply_kind() -> void:
	_ensure_refs()
	if _name_label == null:
		return
	_kind = UIPalette.Row.LIVE if selected else UIPalette.Row.INERT
	var normal: StyleBoxFlat = UIPalette.row_style(_kind)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = UIPalette.tinted(UIPalette.LIVE, normal.bg_color.a + UIPalette.ROW_LIVE_ALPHA)
	add_theme_stylebox_override("hover", hover)
	var down: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	down.bg_color = UIPalette.tinted(UIPalette.LIVE, normal.bg_color.a + UIPalette.ROW_LIVE_ALPHA * 2.0)
	add_theme_stylebox_override("pressed", down)
	if _accent != null:
		_accent.color = UIPalette.row_accent(_kind)
		_accent.custom_minimum_size.x = float(UIPalette.ROW_ACCENT_WIDTH)
	if _column != null:
		# The insets come from the style box, so the padding is stated once rather
		# than in the scene and again here.
		_column.offset_left = normal.content_margin_left
		_column.offset_right = -normal.content_margin_right
		_column.offset_top = normal.content_margin_top
		_column.offset_bottom = -normal.content_margin_bottom
	_name_label.add_theme_color_override("font_color", UIPalette.row_text(_kind))
	_refresh_cost()
	_refresh_footprint()

func _apply_compact() -> void:
	_ensure_refs()
	if _text == null:
		return
	_text.visible = not compact
	_footprint_label.visible = not compact
	if compact:
		_description.visible = false
		_facts.visible = false
	var side: int = UIMetrics.BUILD_RECENT_ICON if compact else UIMetrics.BUILD_ROW_ICON
	_icon.custom_minimum_size = Vector2(float(side), float(side))
	if _accent != null:
		_accent.visible = not compact
	if compact:
		# A fixed square, so a strip of five tiles is exactly as wide as it looks
		# and never re-lays out when a longer module name arrives.
		custom_minimum_size = Vector2(float(side + UIMetrics.BUILD_TILE_INSET * 2), float(side + UIMetrics.BUILD_TILE_INSET * 2))
		_column.offset_left = UIMetrics.BUILD_TILE_INSET
		_column.offset_right = -UIMetrics.BUILD_TILE_INSET
		_column.offset_top = UIMetrics.BUILD_TILE_INSET
		_column.offset_bottom = -UIMetrics.BUILD_TILE_INSET
	_refit()

## Height that fits the content. Only the height: a minimum width would fight the
## panel, which is the thing that knows how wide the list is.
func _refit() -> void:
	_ensure_refs()
	if _column == null or _refitting:
		return
	# Re-entry guard: setting custom_minimum_size can resize the row, and
	# `resized` is one of the two things that calls this.
	_refitting = true
	if not compact:
		var box: StyleBoxFlat = UIPalette.row_style(_kind)
		custom_minimum_size.y = _column.get_combined_minimum_size().y \
			+ box.content_margin_top + box.content_margin_bottom
	_refitting = false

# --- interaction ------------------------------------------------------------------

func _on_pressed() -> void:
	# A locked row is a report, not a control. Pressing it must not drop the
	# player into placement mode holding a module they have not researched.
	if locked or module_data == null or Global.ui_in_game == null:
		return
	Global.ui_in_game.change_input_mode(UIInGame.InputMode.Module, module_data)

func _make_custom_tooltip(_for_text: String) -> Object:
	if module_data == null:
		return null
	var tooltip: ModuleButtonTooltip = (load(
		"res://ui/buttons/module_button_tooltip.tscn") as PackedScene).instantiate() as ModuleButtonTooltip
	tooltip.set_module_data(module_data, locked, gating_label)
	return tooltip
