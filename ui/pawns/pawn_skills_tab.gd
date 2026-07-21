class_name PawnSkillsTab
extends PanelContainer

## Skills + traits readout in the pawn info panel (WI-22). A compact traits
## line up top, then one row per SkillData - name, level, and an xp bar toward
## the next level - built dynamically so the fixed sets stay in sync with
## data/ without hand-authored rows. Hidden for pawns without a skills
## component (drones).

var skills: PawnSkillsComponent = null
var traits: PawnTraitsComponent = null
## skill id -> {"level": Label, "bar": ProgressBar} for in-place updates.
var _rows: Dictionary[StringName, Dictionary] = {}

func set_pawn(_pawn: PawnBase) -> void:
	skills = _pawn.get_component_by_type(PawnSkillsComponent) as PawnSkillsComponent
	if skills == null:
		visible = false
		return
	traits = _pawn.get_component_by_type(PawnTraitsComponent) as PawnTraitsComponent
	_build_rows()
	skills.skill_changed.connect(_on_skill_changed)

func _build_rows() -> void:
	var container: VBoxContainer = %SkillRows
	for child: Node in container.get_children():
		child.queue_free()
	_rows.clear()
	_build_traits(container)
	for def: SkillData in SkillData.all():
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		var name_label := Label.new()
		name_label.text = def.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var level_label := Label.new()
		level_label.custom_minimum_size = Vector2(46, 0)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(90, 10)
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.show_percentage = false
		row.add_child(name_label)
		row.add_child(level_label)
		row.add_child(bar)
		container.add_child(row)
		_rows[def.id] = {"level": level_label, "bar": bar}
		_update_row(def)

## Traits summary line above the skills (WI-22): each trait name carries its
## description as a hover tooltip. A HSeparator divides it from the skill rows.
func _build_traits(container: VBoxContainer) -> void:
	var header := Label.new()
	header.add_theme_font_size_override(&"font_size", 11)
	if traits == null or traits.traits.is_empty():
		header.text = "Traits: none"
		header.modulate = Color(1, 1, 1, 0.6)
		container.add_child(header)
	else:
		header.text = "Traits"
		container.add_child(header)
		var names: HBoxContainer = HBoxContainer.new()
		names.add_theme_constant_override(&"separation", 10)
		for trait_data: TraitData in traits.traits:
			var chip := Label.new()
			chip.text = trait_data.display_name
			chip.tooltip_text = trait_data.description
			chip.mouse_filter = Control.MOUSE_FILTER_STOP  # let the tooltip show
			names.add_child(chip)
		container.add_child(names)
	container.add_child(HSeparator.new())

func _update_row(def: SkillData) -> void:
	if not _rows.has(def.id):
		return
	var level: int = skills.get_level(def.id)
	var refs: Dictionary = _rows[def.id]
	var level_label := refs["level"] as Label
	# Show the disease-reduced effective level (WI-31): "Lv 3 (-2)" and a warning
	# tint when a disease is dulling this skill, plain "Lv N" otherwise.
	var malus: int = skills.malus_for(def.id)
	if malus > 0:
		level_label.text = "Lv %d (-%d)" % [skills.effective_level(def.id), malus]
		level_label.modulate = Color(1.0, 0.6, 0.6)
	else:
		level_label.text = "Lv %d" % level
		level_label.modulate = Color.WHITE
	var bar := refs["bar"] as ProgressBar
	if level >= SkillData.MAX_LEVEL:
		bar.value = 1.0
		return
	var to_next: float = def.xp_to_next(level)
	bar.value = clampf(skills.get_xp(def.id) / to_next, 0.0, 1.0) if to_next > 0.0 else 0.0

func _on_skill_changed(skill: StringName) -> void:
	if skill == &"":
		for def: SkillData in SkillData.all():
			_update_row(def)
		return
	var def: SkillData = SkillData.by_id(skill)
	if def != null:
		_update_row(def)
