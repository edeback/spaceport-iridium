extends GutTest

## Unit tests for [CandidateRoller] (WI-59) - the candidate roll, extracted off
## CrewManager so the New Game setup screen can show a pool of recruits before
## main.tscn (and therefore any manager) exists.
##
## The suite's real job is the last section: the setup screen rolls with a bare
## CandidateRoller while the in-game pool rolls with CrewManager's exports, and
## nothing at runtime would ever notice those two drifting apart.

# --- skill roll ---------------------------------------------------------------

func test_every_skill_sits_in_the_low_band_or_the_standout_band() -> void:
	var roller := CandidateRoller.new()
	roller.base_skill_max = 0
	roller.standout_min_level = 4
	roller.standout_max_level = 9
	for attempt: int in 25:
		var skills: Dictionary[StringName, int] = roller.roll_skills()
		for id: StringName in skills:
			var level: int = skills[id]
			var in_low_band: bool = level == 0
			var in_standout_band: bool = level >= 4 and level <= 9
			assert_true(in_low_band or in_standout_band,
				"%s rolled %d - neither low nor a standout" % [id, level])

func test_standout_count_stays_within_its_band() -> void:
	var roller := CandidateRoller.new()
	roller.base_skill_max = 0
	roller.standout_min = 1
	roller.standout_max = 2
	roller.standout_min_level = 4
	for attempt: int in 25:
		var skills: Dictionary[StringName, int] = roller.roll_skills()
		if skills.is_empty():
			continue  # no SkillData installed; the band assertion is vacuous
		var standouts: int = 0
		for id: StringName in skills:
			if skills[id] > 0:
				standouts += 1
		assert_between(standouts, 1, 2, "1-2 standouts, got %d" % standouts)

func test_low_band_respects_its_ceiling() -> void:
	var roller := CandidateRoller.new()
	roller.base_skill_max = 2
	# No standouts at all, so every entry must come from the low roll.
	roller.standout_min = 0
	roller.standout_max = 0
	for attempt: int in 25:
		var skills: Dictionary[StringName, int] = roller.roll_skills()
		for id: StringName in skills:
			assert_between(skills[id], 0, 2, "%s rolled outside 0..2" % id)

# --- tint ---------------------------------------------------------------------

func test_tint_comes_from_the_palette() -> void:
	var roller := CandidateRoller.new()
	roller.tint_palette = [Color.RED, Color.BLUE] as Array[Color]
	for attempt: int in 20:
		var tint: Color = roller.roll_tint()
		assert_true(tint == Color.RED or tint == Color.BLUE, "tint came from the palette")

func test_empty_palette_rolls_white_rather_than_failing() -> void:
	var roller := CandidateRoller.new()
	roller.tint_palette = [] as Array[Color]
	assert_eq(roller.roll_tint(), Color.WHITE)

func test_default_palette_is_not_empty() -> void:
	# An empty default would silently un-tint every starting crew member.
	assert_gt(CandidateRoller.new().tint_palette.size(), 0)

# --- pricing ------------------------------------------------------------------

func test_price_for_a_plain_candidate_is_the_base_cost() -> void:
	var roller := CandidateRoller.new()
	roller.hire_cost = 400
	var candidate := HireCandidate.new()
	assert_eq(roller.price_for(candidate), 400)

func test_price_for_folds_in_the_skill_premium() -> void:
	var roller := CandidateRoller.new()
	roller.hire_cost = 400
	roller.skill_premium_per_level = 0.08
	var candidate := HireCandidate.new()
	candidate.skills = {&"construction": 5, &"mining": 5}
	# 400 * (1 + 10 * 0.08) = 720.
	assert_eq(roller.price_for(candidate), 720)

# --- the candidate's own sentences --------------------------------------------

## A trait id with no .tres behind it - a mod that declared it and was then
## uninstalled - is dropped rather than rendered as a raw id or crashing on the
## null. trait_data() is the one place that filter lives, so both the joined line
## and the per-trait tooltip row inherit it.
func test_an_unknown_trait_id_is_dropped() -> void:
	var candidate := HireCandidate.new()
	candidate.trait_ids.append(&"definitely_not_an_installed_trait")
	assert_eq(candidate.trait_data().size(), 0, "unknown ids resolve to nothing")
	assert_eq(candidate.traits_line(), "", "and leave no stray separator behind")

func test_no_traits_reads_as_an_empty_line() -> void:
	# "" is what callers test to decide whether to draw the row at all.
	assert_eq(HireCandidate.new().traits_line(), "")

func test_no_standout_skills_says_so() -> void:
	var candidate := HireCandidate.new()
	candidate.skills = {&"construction": 1, &"mining": 0}
	assert_eq(candidate.skills_line(), "No standout skills")

# --- the drift guard ----------------------------------------------------------

## CrewManager's exports must still hand the roller exactly what a bare roller
## already has, or the pool the player picks from at New Game and the pool they
## hire from in-game are two different distributions.
func test_crew_manager_defaults_match_a_bare_roller() -> void:
	var manager := CrewManager.new()
	# _ready never runs (not added to the tree), so nothing registers into Global.
	var from_manager: CandidateRoller = manager.make_roller()
	var bare := CandidateRoller.new()
	assert_eq(from_manager.hire_cost, bare.hire_cost, "hire_cost")
	assert_eq(from_manager.skill_premium_per_level, bare.skill_premium_per_level, "skill_premium_per_level")
	assert_eq(from_manager.max_traits_per_crew, bare.max_traits_per_crew, "max_traits_per_crew")
	assert_eq(from_manager.base_skill_max, bare.base_skill_max, "base_skill_max")
	assert_eq(from_manager.standout_min, bare.standout_min, "standout_min")
	assert_eq(from_manager.standout_max, bare.standout_max, "standout_max")
	assert_eq(from_manager.standout_min_level, bare.standout_min_level, "standout_min_level")
	assert_eq(from_manager.standout_max_level, bare.standout_max_level, "standout_max_level")
	assert_eq(from_manager.tint_palette, bare.tint_palette, "tint_palette")
	manager.free()

## The setup screen quotes each candidate's wage from this const because it has
## no EconomyManager to read the export off.
func test_wage_fraction_const_matches_the_export() -> void:
	var economy := EconomyManager.new()
	assert_eq(economy.wage_fraction, EconomyManager.DEFAULT_WAGE_FRACTION)
	economy.free()

## The setup screen requires exactly this many picks, and CrewManager spawns
## exactly this many founders.
func test_starting_crew_const_matches_the_export() -> void:
	var manager := CrewManager.new()
	assert_eq(manager.starting_crew, CrewManager.STARTING_CREW)
	manager.free()
