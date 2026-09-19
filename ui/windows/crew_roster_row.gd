class_name CrewRosterRow
extends Button

## One crew member in the Crew panel's roster (WI-56):
## `swatch · name / status / location · morale`.
##
## Not a [ListRow], and the reason is the design's: *"status is the primary
## column"*. A `ListRow` puts a name over a meta line with one right-hand slot,
## which would force the status sentence into either the meta position (where it
## reads as a subtitle of the name rather than as the thing the player is
## scanning) or the action slot (where it would be ellipsed to nothing). This row
## carries **three** stacked lines and a gauge, so it is its own control - built
## on the same [Button] skeleton and the same [UIPalette.Row] treatments, so it
## still behaves and reads like every other row in the game.
##
## Code-built rather than a `.tscn` for the same reason [UnlockNodeCard] is: a
## row whose whole layout is four labels and a bar gains nothing from a scene file
## that a second author then has to keep in step with the constants here.
##
## **Morale is a bar, not a number** - *"bars are comparable at a glance down a
## column; numbers are not"*. The number stays for players who want it and goes
## amber below [constant PawnStatus.UNHAPPY_BELOW], which is the same threshold
## the panel's problem line counts with.

## Side of the identity swatch. Matches [constant ListRow.SWATCH_SIZE] so the two
## kinds of row line up where a panel mixes them.
const SWATCH_SIZE: int = 24
## Width of the morale block. Fixed, so a two-digit morale and a three-digit one
## do not shunt the status column sideways down the list.
const MORALE_WIDTH: int = 92
const MORALE_BAR_HEIGHT: int = 8

var pawn: PawnBase = null

var _accent: ColorRect
var _swatch: ColorRect
var _name_label: Label
var _status_label: Label
var _meta_label: Label
var _morale_value: Label
var _morale_bar: HatchBar
var _row: HBoxContainer
var _kind: UIPalette.Row = UIPalette.Row.INERT

static func create() -> CrewRosterRow:
	var row := CrewRosterRow.new()
	row._build()
	return row

## Everything below the button itself. Called by [method create] rather than from
## `_ready`, so a caller can configure the row before it is ever mounted - the
## same lazy-refs discipline [ConsolePanel] follows, for the same reason.
func _build() -> void:
	if _row != null:
		return
	focus_mode = Control.FOCUS_NONE
	clip_text = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_accent = ColorRect.new()
	_accent.name = "Accent"
	_accent.set_anchors_preset(Control.PRESET_LEFT_WIDE, true)
	_accent.offset_right = float(UIPalette.ROW_ACCENT_WIDTH)
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_accent)

	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", UIMetrics.READOUT_HEADER_GAP)
	add_child(_row)

	_swatch = ColorRect.new()
	_swatch.name = "Swatch"
	_swatch.custom_minimum_size = Vector2(float(SWATCH_SIZE), float(SWATCH_SIZE))
	_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_swatch)

	var text := VBoxContainer.new()
	text.name = "Text"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", UIMetrics.LINE_GAP)
	_row.add_child(text)

	_name_label = _make_label(UIType.ENTITY_NAME)
	text.add_child(_name_label)
	# The status sentence, in the middle: the design's primary column, and the one
	# line whose colour carries meaning.
	_status_label = _make_label(UIType.BODY)
	text.add_child(_status_label)
	_meta_label = _make_label(UIType.META_LINE)
	text.add_child(_meta_label)

	var morale := VBoxContainer.new()
	morale.name = "Morale"
	morale.custom_minimum_size.x = float(MORALE_WIDTH)
	morale.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	morale.mouse_filter = Control.MOUSE_FILTER_IGNORE
	morale.add_theme_constant_override("separation", UIMetrics.ITEM_GAP)
	_row.add_child(morale)

	_morale_value = _make_label(UIType.METRIC)
	_morale_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	morale.add_child(_morale_value)

	_morale_bar = HatchBar.new()
	_morale_bar.bar_height = MORALE_BAR_HEIGHT
	morale.add_child(_morale_bar)

	set_kind(UIPalette.Row.INERT)

## Every label in this row is single-line and ellipsed, which is load-bearing
## rather than cosmetic (the WI-53 trap): a non-autowrapping [Label] reports its
## full text width as its minimum size, and the inner `Row` is anchored with
## `grow_horizontal = BOTH` - so a long status sentence would grow the row out of
## both sides of the panel rather than merely overflowing it.
func _make_label(variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# --- content -----------------------------------------------------------------------

## Paints the row from a live pawn. `happiness` is passed in rather than read here
## because the panel already has it (it sorts on it) and a robot or a visitor has
## none - see [method set_morale].
func bind(crew: PawnBase) -> void:
	pawn = crew
	if pawn == null or not is_instance_valid(pawn):
		return
	_swatch.color = pawn.animated_sprite.modulate if pawn.animated_sprite != null \
		else UIPalette.tinted(UIPalette.LIVE, 0.6)
	_name_label.text = pawn.pawn_name if not pawn.pawn_name.is_empty() else "Crew member"
	refresh()

## Re-reads everything that moves. Cheap enough to run for every row on a slow
## tick: one [PawnStatus.Facts] build per pawn, no allocation beyond it.
func refresh() -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	var facts: PawnStatus.Facts = PawnStatus.facts_for(pawn)
	var line: PawnStatus.Line = PawnStatus.describe(facts)
	_status_label.text = line.text
	_status_label.add_theme_color_override("font_color", PawnStatus.tone_color(line.tone))
	_meta_label.text = _meta_for(facts).to_upper()
	set_kind(PawnStatus.tone_row(line.tone))
	# set_kind resets the status colour along with the rest of the row, so the tone
	# is re-applied after it. An amber row's sentence must stay amber.
	_status_label.add_theme_color_override("font_color", PawnStatus.tone_color(line.tone))
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	set_morale(needs.happiness if needs != null else -1.0)
	tooltip_text = "%s — %s" % [_name_label.text, line.text]

## Location, plus the grace window for a crew member who has given notice. *"A
## resigning crew member stays listed, amber, with their grace window in the meta
## line - that is precisely a row the player must not miss."*
func _meta_for(facts: PawnStatus.Facts) -> String:
	var parts: Array[String] = [PawnStatus.location_of(pawn)]
	if facts.resignation_pending or facts.resigned:
		parts.append("notice given")
	elif not facts.on_shift:
		parts.append("off shift")
	return " · ".join(parts)

## `-1.0` hides the gauge entirely, for a pawn that has no morale to report. A
## zero-length bar would read as "miserable" rather than as "not applicable".
func set_morale(happiness: float) -> void:
	var known: bool = happiness >= 0.0
	_morale_value.visible = known
	_morale_bar.visible = known
	if not known:
		return
	var fraction: float = clampf(happiness, 0.0, 1.0)
	var tint: Color = UIPalette.ATTENTION if fraction < PawnStatus.UNHAPPY_BELOW else UIPalette.LIVE
	_morale_value.text = "%d%%" % roundi(fraction * 100.0)
	_morale_value.add_theme_color_override("font_color", tint)
	_morale_bar.fill_color = tint
	_morale_bar.fraction = fraction

# --- treatment ---------------------------------------------------------------------

## The three row treatments, applied exactly as [ListRow] applies them - hover and
## press *lift* the row rather than restyling it, so its state still reads through
## the interaction.
func set_kind(kind: UIPalette.Row) -> void:
	_kind = kind
	var normal: StyleBoxFlat = UIPalette.row_style(kind)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = UIPalette.tinted(UIPalette.LIVE,
		maxf(normal.bg_color.a, 0.0) + UIPalette.ROW_LIVE_ALPHA)
	add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = UIPalette.tinted(UIPalette.LIVE,
		maxf(normal.bg_color.a, 0.0) + UIPalette.ROW_LIVE_ALPHA * 2.0)
	add_theme_stylebox_override("pressed", pressed)
	_accent.color = UIPalette.row_accent(kind)
	_row.offset_left = normal.content_margin_left
	_row.offset_right = -normal.content_margin_right
	_row.offset_top = normal.content_margin_top
	_row.offset_bottom = -normal.content_margin_bottom
	_name_label.add_theme_color_override("font_color", UIPalette.row_text(kind))
	_meta_label.add_theme_color_override("font_color", UIPalette.row_meta(kind))
	_refit()

## Marks the row whose pawn is the current inspector selection. Cyan, so the
## roster agrees with the surface it fills - one detail view, two ways in.
func set_selected(selected: bool) -> void:
	if selected and _kind != UIPalette.Row.AMBER:
		set_kind(UIPalette.Row.LIVE)

func _ready() -> void:
	_build()
	if not _row.minimum_size_changed.is_connected(_refit):
		_row.minimum_size_changed.connect(_refit)
	_refit()

## Gives the row a height that fits its three lines.
##
## The content is laid out by anchors inside the button rather than by a
## container, so nothing derives a height for it. Overriding `_get_minimum_size()`
## does **not** work: [Button] overrides `get_minimum_size()` in C++ and never
## consults the script virtual, so `custom_minimum_size` is the one channel that
## gets through. Same trap [ListRow] documents; same fix.
func _refit() -> void:
	if _row == null:
		return
	var box: StyleBoxFlat = UIPalette.row_style(_kind)
	custom_minimum_size.y = _row.get_combined_minimum_size().y \
		+ box.content_margin_top + box.content_margin_bottom
