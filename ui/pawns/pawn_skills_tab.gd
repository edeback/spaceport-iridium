class_name PawnSkillsTab
extends PanelContainer

## Skills + traits readout in the inspector's crew tab set (WI-22, restyled onto
## the widget library by WI-51). A compact traits line up top, then one [StatBar]
## per SkillData - name, level, and progress toward the next level - built
## dynamically so the fixed sets stay in sync with `data/` without hand-authored
## rows.
##
## The pawn always has a skills component by the time this tab exists: the crew
## tab set only adds Skills for a pawn that carries one, so the drone case that
## used to hide the whole control is handled a step earlier now.

var skills: PawnSkillsComponent = null
var traits: PawnTraitsComponent = null
## skill id -> its bar, for in-place updates.
var _rows: Dictionary[StringName, StatBar] = {}

func set_pawn(_pawn: PawnBase) -> void:
	skills = _pawn.get_component_by_type(PawnSkillsComponent) as PawnSkillsComponent
	if skills == null:
		return
	traits = _pawn.get_component_by_type(PawnTraitsComponent) as PawnTraitsComponent
	_build_rows()
	skills.skill_changed.connect(_on_skill_changed)

func _build_rows() -> void:
	var container: VBoxContainer = %SkillRows
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
	_rows.clear()
	_build_traits(container)
	container.add_child(SectionLabel.create("Skills"))
	for def: SkillData in SkillData.all():
		var bar: StatBar = StatBar.create()
		container.add_child(bar)
		_rows[def.id] = bar
		_update_row(def)

## Traits summary above the skills (WI-22): each trait is a [Chip] carrying its
## description as a hover tooltip.
func _build_traits(container: VBoxContainer) -> void:
	container.add_child(SectionLabel.create("Traits"))
	if traits == null or traits.traits.is_empty():
		var none := Label.new()
		none.text = "None"
		none.theme_type_variation = UIType.META_LINE
		none.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
		container.add_child(none)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UIMetrics.ROW_GAP)
	for trait_data: TraitData in traits.traits:
		var chip: Chip = Chip.create()
		row.add_child(chip)
		chip.configure(trait_data.display_name, "", Color(0.0, 0.0, 0.0, 0.0),
			UIPalette.Row.LIVE)
		chip.tooltip_text = trait_data.description
		chip.mouse_filter = Control.MOUSE_FILTER_STOP # let the tooltip show
	container.add_child(row)

func _update_row(def: SkillData) -> void:
	if not _rows.has(def.id):
		return
	var level: int = skills.get_level(def.id)
	# Show the disease-reduced effective level (WI-31): "Lv 3 (-2)" in the
	# destructive tint when a disease is dulling this skill, plain "Lv N"
	# otherwise.
	var malus: int = skills.malus_for(def.id)
	var text: String = "Lv %d" % level
	var tint: Color = UIPalette.LIVE
	if malus > 0:
		text = "Lv %d (-%d)" % [skills.effective_level(def.id), malus]
		tint = UIPalette.DESTRUCTIVE
	var fraction: float = 1.0
	if level < SkillData.MAX_LEVEL:
		var to_next: float = def.xp_to_next(level)
		fraction = clampf(skills.get_xp(def.id) / to_next, 0.0, 1.0) if to_next > 0.0 else 0.0
	_rows[def.id].configure(def.display_name, fraction, text, tint)

func _on_skill_changed(skill: StringName) -> void:
	if skill == &"":
		for def: SkillData in SkillData.all():
			_update_row(def)
		return
	var def: SkillData = SkillData.by_id(skill)
	if def != null:
		_update_row(def)
