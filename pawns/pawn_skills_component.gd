class_name PawnSkillsComponent
extends PawnComponentBase

## Per-pawn skill levels + xp (WI-22). Skills scale job work-rate via
## skill_mult() and grow with use. Only organic crew carry this component;
## drones spawn without it, so PawnBase.skill_mult()/grant_skill_xp() no-op
## (1.0 / nothing) for them - the same pattern work_speed() uses for pawns
## without a needs component.
##
## Runtime state is {skill_id: {"level": int 0..MAX_LEVEL, "xp": float}}. The
## shared, tunable curve lives in SkillData (data/skills/*.tres).

## Emitted when a skill's level or xp changes so the skills tab can refresh
## without polling. Carries the affected id, or &"" for a blanket refresh.
signal skill_changed(skill: StringName)

var _skills: Dictionary[StringName, Dictionary] = {}

## Temporary per-skill level reductions from active diseases (WI-31), set by
## PawnDiseaseComponent. skill id -> levels subtracted; the effective level floors
## at 0. Not saved - re-derived from disease state on load, like trait modifiers.
var _disease_malus: Dictionary[StringName, int] = {}

func _ready() -> void:
	super()
	# Seed every known skill at level 0 so lookups and the tab always have an
	# entry, even for skills no job trains yet.
	for skill: SkillData in SkillData.all():
		if not _skills.has(skill.id):
			_skills[skill.id] = {"level": 0, "xp": 0.0}

func get_level(skill: StringName) -> int:
	if not _skills.has(skill):
		return 0
	var entry: Dictionary = _skills[skill]
	return int(entry.get("level", 0))

## The level after subtracting any active disease malus, floored at 0 (WI-31).
## Jobs and skill_mult() consult this, not the raw level.
func effective_level(skill: StringName) -> int:
	return maxi(0, get_level(skill) - int(_disease_malus.get(skill, 0)))

## Replace the disease malus overlay and refresh the skills tab. Empty overlay =
## no disease reduction. Called by PawnDiseaseComponent on any change.
func set_disease_malus(overlay: Dictionary[StringName, int]) -> void:
	_disease_malus = overlay
	skill_changed.emit(&"")

## The current malus on `skill` (0 when none) - for the skills tab display.
func malus_for(skill: StringName) -> int:
	return int(_disease_malus.get(skill, 0))

func get_xp(skill: StringName) -> float:
	if not _skills.has(skill):
		return 0.0
	var entry: Dictionary = _skills[skill]
	return float(entry.get("xp", 0.0))

## Work-rate multiplier for `skill` at its effective level. 1.0 for an empty or
## unknown skill so unskilled jobs are unaffected. Reads effective_level so an
## active disease's malus (WI-31) slows the pawn's skilled work.
func skill_mult(skill: StringName) -> float:
	if skill == &"":
		return 1.0
	var def: SkillData = SkillData.by_id(skill)
	if def == null:
		return 1.0
	return def.multiplier_for_level(effective_level(skill))

## Adds xp and rolls any level-ups (a large grant can cross several levels).
## Emits skill_changed once; fires a station_alert + SignalBus signal per level
## gained. No-op for an empty/unknown skill.
func add_xp(skill: StringName, amount: float) -> void:
	if skill == &"" or amount <= 0.0:
		return
	var def: SkillData = SkillData.by_id(skill)
	if def == null:
		return
	if not _skills.has(skill):
		_skills[skill] = {"level": 0, "xp": 0.0}
	var entry: Dictionary = _skills[skill]
	var level: int = int(entry["level"])
	var xp: float = float(entry["xp"]) + amount
	while level < SkillData.MAX_LEVEL and xp >= def.xp_to_next(level):
		xp -= def.xp_to_next(level)
		level += 1
		_announce_level_up(def, level)
	# At the cap there's no next threshold to spend against, so park xp at 0.
	if level >= SkillData.MAX_LEVEL:
		xp = 0.0
	_skills[skill] = {"level": level, "xp": xp}
	skill_changed.emit(skill)

## Sets a skill's level outright (set_skill cheat / rolled crew), resetting xp
## to the new level's floor.
func set_level(skill: StringName, level: int) -> void:
	if SkillData.by_id(skill) == null:
		return
	_skills[skill] = {"level": clampi(level, 0, SkillData.MAX_LEVEL), "xp": 0.0}
	skill_changed.emit(skill)

func _announce_level_up(def: SkillData, new_level: int) -> void:
	var who: String = owner_pawn.pawn_name if not owner_pawn.pawn_name.is_empty() else "A crew member"
	SignalBus.station_alert.emit("%s reached %s level %d" % [who, def.display_name, new_level])
	SignalBus.pawn_skill_leveled.emit(owner_pawn, def.id, new_level)

# --- persistence --------------------------------------------------------------

func save_order() -> int:
	return 30

func save_key() -> StringName:
	return &"skills"

func get_save_data() -> Dictionary:
	var out: Dictionary = {}
	for skill: StringName in _skills:
		var entry: Dictionary = _skills[skill]
		out[String(skill)] = {
			"level": int(entry["level"]),
			"xp": float(entry["xp"]),
		}
	return out

func load_save_data(data: Dictionary) -> void:
	for key: Variant in data:
		var skill := StringName(key)
		# A skill removed from data since the save just drops out.
		if SkillData.by_id(skill) == null:
			continue
		var entry: Dictionary = data[key]
		_skills[skill] = {
			"level": clampi(int(entry.get("level", 0)), 0, SkillData.MAX_LEVEL),
			"xp": maxf(float(entry.get("xp", 0.0)), 0.0),
		}
	skill_changed.emit(&"")
