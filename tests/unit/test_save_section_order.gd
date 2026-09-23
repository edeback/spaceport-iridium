extends GutTest

## WI-73 §2: the vanilla save-section order, pinned.
##
## `test_save_sections.gd` pins the registry's *sort* - lower numbers first, ties
## on id. This pins the *numbers*: the constraints between vanilla sections used
## to live as comments in eleven files, each choosing its integer by reading the
## others, and nothing failed when one of them moved. They are now one table,
## [constant SaveManager.SECTION_ORDER], and every pair below is a sentence some
## registrant's load actually depends on. Renumber a row and the pair it breaks
## fails here, naming the reason, instead of in a player's load.
##
## Pure: reads a constant and the game's source text, touches no autoload.

## Where the game registers its sections. Same roots as the other source sweeps,
## minus `tests/` (a test registers throwaway sections with literal numbers on
## purpose) and `tools/` (the sample mod is a mod, and mods pass integers).
const ROOTS: PackedStringArray = ["res://scripts", "res://modules", "res://pawns",
	"res://data", "res://ui", "res://objects"]

## Every constraint a registrant states, as [earlier, later, why]. The reason is
## the assertion message, so a failure says what breaks rather than which two
## numbers disagree.
##
## Two that used to be stated are not here, because reading the loads found no
## dependency: asteroids after world (neither load reads the other's objects) and
## raid after world (ships restore around a saved centre, and a turret re-derives
## its aim on its own). Their comments say so now. Sections with no constraint at
## all - visitors, tutorial, vitals - say that at their registration instead.
const BEFORE: Array[Array] = [
	[&"unlocks", &"world", "ready_constructed applies global modifiers and granted-module checks as each module restores"],
	[&"resources", &"economy", "the ledger, loan and insolvency counters restore against the restored balances"],
	[&"world", &"turbolifts", "a shaft's cab budget restores onto the shaft the modules re-merged"],
	[&"world", &"piles", "a pile re-links to the module it sits in"],
	[&"world", &"pawns", "restored jobs resolve their module targets"],
	[&"world", &"crew", "the bunks the Crew panel re-reads on hire_candidates_changed have to be back"],
	[&"world", &"traders", "an active visit re-parks its shuttle at the bay"],
	[&"world", &"contracts", "the Trade panel answers contracts_changed by asking whether there is a bay"],
	[&"asteroids", &"pawns", "restored mining jobs resolve their asteroid by id"],
	[&"piles", &"pawns", "a restored collect job is handed back to its pile, which must already exist (WI-70)"],
	[&"market", &"traders", "a visit's price snapshot restores against the market's stock"],
	[&"market", &"events", "supply shocks re-register without re-snapping stock"],
	[&"pawns", &"crew", "the crew count the Crew panel re-reads on hire_candidates_changed has to be back"],
	[&"pawns", &"events", "station-wide happiness effects re-apply to the loaded crew"],
	[&"events", &"story", "a scheduled event lands on a manager whose own cooldown table is already back"],
]

func _order(id: StringName) -> int:
	return SaveManager.SECTION_ORDER[id]

func _assert_before(earlier: StringName, later: StringName, why: String) -> void:
	assert_lt(_order(earlier), _order(later),
		"%s (%d) must restore before %s (%d): %s" % [earlier, _order(earlier), later, _order(later), why])

# --- the constraints --------------------------------------------------------------

## Every system ticks in the loaded calendar, and time's restore announces itself
## with calendar_restored rather than replaying cycle_changed - so a manager that
## restored before it would settle a phantom cycle (WI-38 A3). The alert and
## transmission logs need it too, so a stamp reads right.
func test_time_restores_before_every_other_section() -> void:
	for id: StringName in SaveManager.SECTION_ORDER:
		if id != &"time":
			_assert_before(&"time", id, "every other section restores into the loaded calendar")

func test_every_stated_constraint_holds() -> void:
	for pair: Array in BEFORE:
		_assert_before(pair[0], pair[1], pair[2])

# --- the table itself ---------------------------------------------------------------

func test_every_constraint_names_a_section_in_the_table() -> void:
	# A pair naming a section that has since been renamed would pass forever by
	# throwing on the lookup in a test nobody reads - so check the names first.
	for pair: Array in BEFORE:
		assert_true(SaveManager.SECTION_ORDER.has(pair[0]), "%s is a vanilla section" % pair[0])
		assert_true(SaveManager.SECTION_ORDER.has(pair[1]), "%s is a vanilla section" % pair[1])

func test_no_two_vanilla_sections_share_a_number() -> void:
	# Two at one order would fall back to the id tiebreak, which is stable but
	# means nobody decided which of them restores first.
	var seen: Dictionary[int, StringName] = {}
	for id: StringName in SaveManager.SECTION_ORDER:
		var order: int = _order(id)
		assert_false(seen.has(order), "%s and %s both sit at %d" % [seen.get(order, &""), id, order])
		seen[order] = id

func test_the_table_holds_every_section_a_save_carries() -> void:
	# The 21 a real save carries, taken from a real save on 2026-09-22. A new
	# section is a new row in the table - and a new name here.
	var expected: Array[StringName] = [&"time", &"unlocks", &"resources", &"market", &"economy",
		&"world", &"asteroids", &"turbolifts", &"piles", &"pawns", &"crew", &"traders", &"events",
		&"story", &"contracts", &"raid", &"visitors", &"tutorial", &"vitals", &"alerts",
		&"transmissions"]
	var actual: Array[StringName] = []
	actual.assign(SaveManager.SECTION_ORDER.keys())
	actual.sort()
	expected.sort()
	assert_eq(actual, expected)

# --- registrants read the table ------------------------------------------------------

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

## Every `register_section(` call in the game, as "path:line: text". The
## definition itself is not a call.
func _registrations() -> PackedStringArray:
	var out := PackedStringArray()
	for path: String in _script_paths():
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			var line: String = lines[index]
			if line.contains("register_section(") and not line.contains("func register_section("):
				out.append("%s:%d: %s" % [path, index + 1, line.strip_edges()])
	return out

func test_the_sweep_finds_every_registration() -> void:
	# One call per section. If this drops, the sweep below is looking in the wrong
	# place and would pass on nothing.
	assert_eq(_registrations().size(), SaveManager.SECTION_ORDER.size())

func test_every_vanilla_registration_reads_its_number_from_the_table() -> void:
	# A literal here is a second place the number lives, which is the drift this
	# table exists to end. The order argument is always on the call's first line.
	var offenders := PackedStringArray()
	for registration: String in _registrations():
		if not registration.contains("SECTION_ORDER["):
			offenders.append(registration)
	assert_eq(offenders, PackedStringArray(), "register_section with its own number")
