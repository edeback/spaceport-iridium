extends GutTest

## The three rules that hold the stat vocabulary together (WI-72 §1, F30).
##
## A stat name is written by an authored upgrade and read by a component, with
## nothing between them but a dictionary key. Before [Stats] existed, a typo on
## either side was an upgrade that charged the player credits and then did
## nothing at all - no error, no warning, no visible difference - and there was
## no way to notice short of measuring the module before and after.
##
## - **authored implies declared:** every stat a shipped `.tres` names is in
##   [constant Stats.DECLARED]. This is the typo check, and it is the one the
##   item was written for.
## - **declared implies read:** every declared stat is read back by some
##   component. A declared stat nobody reads is the *same* dead upgrade, just
##   spelled consistently.
## - **no bare literal:** nothing names a stat as a string any more, so a future
##   typo has to get past the parser first.
##
## A mod's stat is deliberately NOT covered by the first rule at runtime - see
## [method Stats.warn_if_undeclared] and WI-72 §0.3. This suite only sweeps the
## roots [ContentPaths] knows about, which is vanilla plus anything mounted, and
## a mod that ships its own suite can make its own decision.

## Where the game's code lives. `pawns/` is deliberately absent: pawn needs have
## an `add_modifier` of their own that takes MOOD ids, a different vocabulary
## with its own catalogue, and sweeping it here would fail every mood in the game.
const ROOTS: PackedStringArray = ["res://modules", "res://scripts", "res://ui",
	"res://objects", "res://data"]

## The one file allowed to spell a stat out: it is the declaration.
const DECLARATION: String = "res://scripts/utility/stats.gd"

## Writing a stat as a bare string is how a typo gets in. Each needle is a call
## that takes a stat key first. `needs.add_modifier(` is NOT in here even though
## two module components call it - that one takes a mood id.
const BARE_LITERALS: PackedStringArray = [
	"get_effective_stat(&\"",
	"stat_modifiers.set_single_modifier(&\"",
	"stat_modifiers.add_modifier(&\"",
]

# --- reading the shipped content -------------------------------------------------

## Every stat any authored local upgrade names, with the file that named it.
func _authored_local_upgrade_stats() -> Array[Array]:
	var out: Array[Array] = []
	for path: String in ContentPaths.scan(ContentPaths.LOCAL_UPGRADES):
		var upgrade: LocalUpgradeData = ResourceLoader.load(path) as LocalUpgradeData
		if upgrade == null:
			continue
		for spec: StatModifierSpec in upgrade.modifiers:
			if spec != null:
				out.append([spec.stat, path.get_file()])
	return out

## The same for global unlocks, whose stat effects live inside `effects`.
func _authored_unlock_stats() -> Array[Array]:
	var out: Array[Array] = []
	for path: String in ContentPaths.scan(ContentPaths.UNLOCKS):
		var unlock: UnlockData = ResourceLoader.load(path) as UnlockData
		if unlock == null:
			continue
		for effect: UnlockEffect in unlock.effects:
			var stat_effect: StatModifierEffect = effect as StatModifierEffect
			if stat_effect != null:
				out.append([stat_effect.stat, path.get_file()])
	return out

# --- reading the code ------------------------------------------------------------

func _script_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for root: String in ROOTS:
		_collect(root, out)
	return out

func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

## Every code line that names `Stats.SOMETHING` other than to write a modifier.
##
## "Read" is defined by exclusion rather than by looking for `get_effective_stat(`
## because a component may route its reads through a helper - [WeaponComponent]
## does, with a one-line `_stat()`, and that is exactly why WI-72's first census
## of the vocabulary came up three stats short. What a read is NOT is a write to
## the modifier layer, which is what [ModuleBase]'s damage, breakdown and
## adjacency passes and [HeatComponent]'s throttle do.
func _stats_named_in_a_read() -> PackedStringArray:
	var out := PackedStringArray()
	var pattern := RegEx.create_from_string("Stats\\.([A-Z][A-Z0-9_]*)")
	for path: String in _script_paths():
		if path == DECLARATION:
			continue
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code: String = line.strip_edges()
			if code.begins_with("#"):
				continue # prose may name a stat it does not read
			if code.contains("set_single_modifier(") or code.contains("add_modifier("):
				continue # a write, not a read
			for found: RegExMatch in pattern.search_all(code):
				out.append(found.get_string(1))
	return out

# --- the sweep sees what it thinks it sees ----------------------------------------

func test_the_sweep_finds_the_content_and_the_code() -> void:
	assert_gt(Stats.DECLARED.size(), 15, "the vocabulary is declared")
	assert_gt(_authored_local_upgrade_stats().size(), 5, "the scan sees data/local_upgrades/")
	var paths: PackedStringArray = _script_paths()
	assert_gt(paths.size(), 200, "the sweep sees the game's scripts")
	assert_true(paths.has("res://modules/templates/module_base.gd"),
		"including the one that writes four of these stats")

func test_no_stat_is_declared_twice() -> void:
	var seen: Array[StringName] = []
	for stat: StringName in Stats.DECLARED:
		assert_false(seen.has(stat), "'%s' is declared twice" % stat)
		seen.append(stat)

# --- rule 1: authored implies declared ---------------------------------------------

func test_every_authored_local_upgrade_names_a_declared_stat() -> void:
	for entry: Array in _authored_local_upgrade_stats():
		var stat: StringName = entry[0]
		assert_true(Stats.is_declared(stat),
			"%s modifies '%s', which nothing declares - the tier would cost credits and do nothing"
				% [entry[1], stat])

## No shipped unlock carries a [StatModifierEffect] yet - every tunable the tech
## tree touches today is a local upgrade - so this asserts on an empty list, which
## is the point: the day one lands it is swept without anybody remembering to come
## back here. The scan itself is pinned first so "empty" can't mean "looked in the
## wrong place".
func test_every_authored_unlock_effect_names_a_declared_stat() -> void:
	assert_gt(ContentPaths.scan(ContentPaths.UNLOCKS).size(), 5, "the scan sees data/unlocks/")
	for entry: Array in _authored_unlock_stats():
		var stat: StringName = entry[0]
		assert_true(Stats.is_declared(stat),
			"%s registers a global modifier on '%s', which nothing declares" % [entry[1], stat])

func test_no_authored_modifier_has_an_empty_stat() -> void:
	# An empty slot in an authored array reads as `&""`, which is declared by
	# nobody and would otherwise fall through rule 1's message confusingly.
	for entry: Array in _authored_local_upgrade_stats() + _authored_unlock_stats():
		assert_ne(entry[0] as StringName, &"", "%s has a modifier with no stat set" % entry[1])

# --- rule 2: declared implies read ---------------------------------------------------

## The mirror of rule 1, and the reason it matters: a stat that is spelled the
## same in the `.tres` and in [Stats] but that no component ever reads back is
## still an upgrade that does nothing. Consistency is not the same as correctness.
func test_every_declared_stat_is_read_by_something() -> void:
	var read: PackedStringArray = _stats_named_in_a_read()
	for stat: StringName in Stats.DECLARED:
		var constant: String = String(stat).to_upper()
		assert_true(read.has(constant),
			("Stats.%s is declared but no component reads it back through"
			+ " get_effective_stat - an upgrade targeting it would do nothing") % constant)

## The constants mirror their values exactly, which is what lets a grep for either
## one find every site - and what lets the test above compare the two at all.
func test_every_constant_name_mirrors_its_value() -> void:
	var text: String = FileAccess.get_file_as_string(DECLARATION)
	for stat: StringName in Stats.DECLARED:
		var expected: String = "const %s: StringName = &\"%s\"" % [String(stat).to_upper(), stat]
		assert_true(text.contains(expected), "stats.gd declares it as: %s" % expected)

# --- rule 3: no bare literal ----------------------------------------------------------

func test_nothing_names_a_stat_as_a_bare_string() -> void:
	var checked: int = 0
	for path: String in _script_paths():
		if path == DECLARATION:
			continue
		checked += 1
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			var code: String = lines[index].strip_edges()
			if code.begins_with("#"):
				continue # prose may quote the old spelling
			for needle: String in BARE_LITERALS:
				if code.contains(needle):
					fail_test("%s:%d names a stat as a literal - use a Stats constant:  %s"
						% [path, index + 1, code])
	assert_gt(checked, 200, "and read them")

# --- the runtime half (§0.3) ------------------------------------------------------------

func before_each() -> void:
	Stats.clear_warnings_for_test()

func after_each() -> void:
	Stats.clear_warnings_for_test()

func test_a_declared_stat_and_an_empty_one_report_nothing() -> void:
	# push_warning is not something GUT can catch, so these assert the gate rather
	# than the text: neither is even recorded as having been reported.
	Stats.warn_if_undeclared(Stats.PROCESS_TIME, "somewhere.tres")
	Stats.warn_if_undeclared(&"", "somewhere.tres")
	assert_eq(Stats.has_warned_for_test(), [] as Array[StringName])

## A mod's own stat is legitimate and must keep working; all it costs is one line
## in the log, once, however many upgrades name it. The once matters because the
## content scan re-runs on every New Game after a Quit to Menu.
func test_an_undeclared_stat_is_reported_once_and_not_again() -> void:
	Stats.warn_if_undeclared(&"amod.warp_efficiency", "amod/data/local_upgrades/warp.tres")
	Stats.warn_if_undeclared(&"amod.warp_efficiency", "amod/data/local_upgrades/warp_2.tres")
	assert_eq(Stats.has_warned_for_test(), [&"amod.warp_efficiency"] as Array[StringName],
		"one report, and the mod's key is not refused")

## Every shipped upgrade goes through the runtime path without tripping the
## warning - the same fact as rule 1, checked through the code that runs in game
## rather than through the resources directly.
func test_the_shipped_content_trips_no_runtime_warning() -> void:
	for path: String in ContentPaths.scan(ContentPaths.LOCAL_UPGRADES):
		var upgrade: LocalUpgradeData = ResourceLoader.load(path) as LocalUpgradeData
		if upgrade != null:
			upgrade.warn_on_undeclared_stats(path)
	for path: String in ContentPaths.scan(ContentPaths.UNLOCKS):
		var unlock: UnlockData = ResourceLoader.load(path) as UnlockData
		if unlock == null:
			continue
		for effect: UnlockEffect in unlock.effects:
			if effect != null:
				effect.warn_on_undeclared_stats(path)
	assert_eq(Stats.has_warned_for_test(), [] as Array[StringName],
		"vanilla content named a stat nothing declares")
