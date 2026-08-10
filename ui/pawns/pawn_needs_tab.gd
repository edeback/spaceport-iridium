class_name PawnNeedsTab
extends VBoxContainer

## A pawn's needs, and **why their happiness is what it is** (WI-51).
##
## Happiness is the mean of the enabled needs plus the sum of every active
## modifier, clamped into 0..1 (see [MoodCatalog.combine]). Until now the tab
## showed five bars and nothing at all about the second half of that formula -
## there are thirteen modifier sources and the player had no way to learn that
## any of them existed, let alone which one was costing them a crew member.
##
## So under the bars sits the arithmetic: the needs average on its own line, then
## one line per modifier with its sign, its magnitude in percentage points, and
## either how long it has left or what is keeping it alive. The needs-average line
## is the load-bearing one - it is the only way to tell "my crew are miserable
## because the station is failing them" from "my crew are miserable because of a
## run of bad events", and those have completely different fixes.
##
## Code-built rather than authored: it was a fixed five-row scene with 200px
## bars, and the breakdown is a list of unknown length.

## Rebuilt from the pawn's current state on this signal as well as on
## `happiness_changed`, because a modifier can expire without moving happiness
## enough to cross the component's 0.001 emit threshold.
const REFRESH_ON_SLOW_TICK: bool = true

var pawn_needs: PawnNeedsComponent = null
var pawn_health: PawnHealthComponent = null
var pawn_disease: PawnDiseaseComponent = null

var _bars: Dictionary[StringName, StatBar] = {}
var _happiness_bar: StatBar = null
var _breakdown: VBoxContainer = null
var _diseases: VBoxContainer = null

func set_pawn(pawn: PawnBase) -> void:
	name = "Needs"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	pawn_needs = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	pawn_health = pawn.get_component_by_type(PawnHealthComponent) as PawnHealthComponent
	pawn_disease = pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
	_build()
	if pawn_health != null:
		pawn_health.health_changed.connect(func(_v: float) -> void: _refresh_bars())
	if pawn_needs != null:
		if pawn_needs.has_sleep_need:
			pawn_needs.sleep_changed.connect(func(_v: float) -> void: _refresh_bars())
		if pawn_needs.has_hunger_need:
			pawn_needs.hunger_changed.connect(func(_v: float) -> void: _refresh_bars())
		if pawn_needs.has_recreation_need:
			pawn_needs.recreation_changed.connect(func(_v: float) -> void: _refresh_bars())
		pawn_needs.happiness_changed.connect(_on_happiness_changed)
		if REFRESH_ON_SLOW_TICK and Global.time_manager != null:
			Global.time_manager.slow_tick.connect(_on_slow_tick)
	if pawn_disease != null:
		pawn_disease.diseases_changed.connect(_rebuild_diseases)
	_refresh_bars()
	_rebuild_breakdown()
	_rebuild_diseases()

# --- construction ---------------------------------------------------------------

func _build() -> void:
	if pawn_health != null:
		_bars[&"health"] = _add_bar("Health")
	if pawn_needs != null:
		if pawn_needs.has_sleep_need:
			_bars[&"sleep"] = _add_bar("Sleep")
		if pawn_needs.has_hunger_need:
			_bars[&"hunger"] = _add_bar("Hunger")
		if pawn_needs.has_recreation_need:
			_bars[&"recreation"] = _add_bar("Recreation")
	if pawn_needs == null:
		return
	add_child(SectionLabel.create("Happiness"))
	_happiness_bar = _add_bar("Happiness")
	_breakdown = VBoxContainer.new()
	_breakdown.name = "Breakdown"
	_breakdown.add_theme_constant_override("separation", 2)
	add_child(_breakdown)
	_diseases = VBoxContainer.new()
	_diseases.name = "Diseases"
	_diseases.add_theme_constant_override("separation", 2)
	add_child(_diseases)

func _add_bar(label: String) -> StatBar:
	var bar: StatBar = StatBar.create()
	add_child(bar)
	bar.configure(label, 0.0, "")
	return bar

# --- bars -------------------------------------------------------------------

## Below this fraction a need reads amber. It is a *presentation* threshold, not
## the gameplay one: PawnNeedsComponent starts looking for a fix at 30% and calls
## it critical at 5%, and a bar that only changed colour at 5% would be reporting
## the emergency rather than the run-up to it.
const WARN_FRACTION: float = 0.35

func _refresh_bars() -> void:
	if pawn_health != null and _bars.has(&"health"):
		_set_bar(_bars[&"health"], pawn_health.health_percent01())
	if pawn_needs == null:
		return
	if _bars.has(&"sleep"):
		_set_bar(_bars[&"sleep"], pawn_needs.sleep_value / pawn_needs.sleep_max)
	if _bars.has(&"hunger"):
		_set_bar(_bars[&"hunger"], pawn_needs.hunger_value / pawn_needs.hunger_max)
	if _bars.has(&"recreation"):
		_set_bar(_bars[&"recreation"], pawn_needs.recreation_value / pawn_needs.recreation_max)
	if _happiness_bar != null:
		_set_bar(_happiness_bar, pawn_needs.happiness)

func _set_bar(bar: StatBar, fraction: float) -> void:
	var clamped: float = clampf(fraction, 0.0, 1.0)
	bar.set_value(clamped, "%d%%" % int(round(clamped * 100.0)),
		UIPalette.ATTENTION if clamped < WARN_FRACTION else UIPalette.LIVE)

func _on_happiness_changed(_new_happiness: float) -> void:
	_refresh_bars()
	_rebuild_breakdown()

func _on_slow_tick(_interval: float) -> void:
	_rebuild_breakdown()

# --- the breakdown --------------------------------------------------------------

func _rebuild_breakdown() -> void:
	if _breakdown == null or pawn_needs == null:
		return
	for child: Node in _breakdown.get_children():
		_breakdown.remove_child(child)
		child.queue_free()
	_breakdown.add_child(_row("needs average", pawn_needs.needs_average() * 100.0, "",
		UIPalette.TEXT_SECONDARY, false))
	for entry: Dictionary in pawn_needs.get_modifier_breakdown():
		var id: StringName = StringName(entry["id"])
		var value: float = float(entry["value"])
		var row: HBoxContainer = _row(
			MoodCatalog.label_of(id),
			value * 100.0,
			MoodCatalog.duration_text(id, float(entry["hours_remaining"])),
			UIPalette.sign_color(value),
			true)
		var blurb: String = MoodCatalog.blurb_of(id)
		if not blurb.is_empty():
			row.tooltip_text = blurb
			row.mouse_filter = Control.MOUSE_FILTER_STOP # let the tooltip show
		_breakdown.add_child(row)

## `<label>   <±value>   <duration or cause>`. The needs-average line uses the
## same row without a sign, because it is a level rather than a contribution.
func _row(label_text: String, percent: float, trailing: String, tint: Color,
		signed: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = UIType.BODY
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", UIPalette.TEXT)
	row.add_child(label)
	var value := Label.new()
	value.theme_type_variation = UIType.METRIC
	value.text = ("%+d%%" % int(round(percent))) if signed else ("%d%%" % int(round(percent)))
	value.add_theme_color_override("font_color", tint)
	row.add_child(value)
	var trail := Label.new()
	trail.theme_type_variation = UIType.META_LINE
	trail.custom_minimum_size = Vector2(84, 0)
	trail.text = trailing.to_upper()
	trail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trail.add_theme_color_override("font_color", UIPalette.TEXT_META)
	row.add_child(trail)
	return row

# --- diseases (WI-31) -----------------------------------------------------------

func _rebuild_diseases() -> void:
	if _diseases == null:
		return
	for child: Node in _diseases.get_children():
		_diseases.remove_child(child)
		child.queue_free()
	if pawn_disease == null:
		return
	var ids: Array[StringName] = pawn_disease.active_ids()
	if ids.is_empty():
		return # "Healthy" is what an empty list already says
	_diseases.add_child(SectionLabel.create("Diseases"))
	for id: StringName in ids:
		var disease: DiseaseData = DiseaseData.by_id(id)
		if disease == null:
			continue
		var row: ListRow = ListRow.create()
		row.disabled = true
		row.focus_mode = Control.FOCUS_NONE
		row.tooltip_text = disease.description
		_diseases.add_child(row)
		row.configure(
			disease.display_name,
			"stage %d/%d" % [pawn_disease.stage_of(id) + 1, disease.stage_count()],
			"%d%%" % int(round(pawn_disease.treat_fraction(id) * 100.0)),
			UIPalette.Row.AMBER)
