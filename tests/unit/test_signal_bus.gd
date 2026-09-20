extends GutTest

## A text sweep over [SignalBus] and the scripts around it (WI-72 §3, F11).
##
## Two questions, both of which had no answer before this suite existed:
##
## - **Is every signal emitted?** `special_path_connection_added` had no emitter
##   at all and had not had one for a long time. A signal nothing raises is not a
##   quiet extension point, it is a listener that will never run, and the only
##   way to find one is to go looking.
## - **Is every signal either used or promised?** Eleven signals have no listener
##   in the base game. That is a legitimate shape - they are the mod API (WI-47) -
##   but "nobody uses it" and "a mod may rely on it" are opposite conclusions, and
##   until WI-72 nothing in the file said which one applied. Now a listener-less
##   signal must be under the `MOD API` heading with a sentence on it, or this
##   suite fails and the author has to decide.
##
## Text-swept rather than reflected, deliberately: `SignalBus.get_signal_list()`
## would answer the first half at runtime, but it cannot see where a signal is
## emitted from or whether anyone documented it, and this suite is pure - no
## autoload, no tree.

const SIGNAL_BUS: String = "res://scripts/managers/signal_bus.gd"

## Where the game's code lives. Same roots as the WI-70 ownership sweep, minus
## `tests/`: a signal connected only by a test is not connected by the game, and
## counting it would let a listener-less signal hide behind its own coverage.
const ROOTS: PackedStringArray = ["res://scripts", "res://modules", "res://pawns",
	"res://data", "res://ui", "res://objects"]

## The line that opens the mod-API section of signal_bus.gd. Everything declared
## after it is promised to mods; everything before it is internal.
const MOD_API_HEADING: String = "# --- MOD API"

## The promise, restated here so it takes two edits to break rather than one. A
## signal in this list must be under the heading in signal_bus.gd, and a signal
## under the heading must be in this list - see the two tests at the foot.
const MOD_API: PackedStringArray = [
	"module_destroyed",
	"ship_destroyed",
	"pawn_skill_leveled",
	"station_alert_raised",
	"event_triggered",
	"contract_offered",
	"contract_accepted",
	"contract_completed",
	"contract_failed",
	"visitor_arrived",
	"visitor_departed",
]

# --- reading the bus ------------------------------------------------------------

func _bus_text() -> String:
	return FileAccess.get_file_as_string(SIGNAL_BUS)

## Every signal the bus declares, in file order.
func _declared() -> PackedStringArray:
	var out := PackedStringArray()
	var pattern := RegEx.create_from_string("^signal\\s+(\\w+)")
	for line: String in _bus_text().split("\n"):
		var found: RegExMatch = pattern.search(line)
		if found != null:
			out.append(found.get_string(1))
	return out

## The ones declared after the MOD API heading.
func _under_the_heading() -> PackedStringArray:
	var text: String = _bus_text()
	var cut: int = text.find(MOD_API_HEADING)
	if cut < 0:
		return PackedStringArray()
	var out := PackedStringArray()
	var pattern := RegEx.create_from_string("^signal\\s+(\\w+)")
	for line: String in text.substr(cut).split("\n"):
		var found: RegExMatch = pattern.search(line)
		if found != null:
			out.append(found.get_string(1))
	return out

# --- reading the game -----------------------------------------------------------

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

## Everything the game's scripts say about signals, as two sets of names. Read in
## one pass because the sweep is 300-odd files and both tests want it.
##
## `emitted` is anything matching `<name>.emit(`, `listened` anything matching
## `<name>.connect(` or `.is_connected(`. Loose on purpose: a name shared with a
## local signal would count as a false *pass*, and the cost of that is one
## undetected dead signal, where a false fail would block a legitimate one.
func _usage() -> Dictionary[StringName, PackedStringArray]:
	var emitted := PackedStringArray()
	var listened := PackedStringArray()
	var emit_pattern := RegEx.create_from_string("(\\w+)\\.emit\\(")
	var listen_pattern := RegEx.create_from_string("(\\w+)\\.(?:connect|is_connected)\\(")
	for path: String in _script_paths():
		if path == SIGNAL_BUS:
			continue
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in emit_pattern.search_all(text):
			emitted.append(found.get_string(1))
		for found: RegExMatch in listen_pattern.search_all(text):
			listened.append(found.get_string(1))
	return {&"emitted": emitted, &"listened": listened}

# --- the sweep sees what it thinks it sees ----------------------------------------

func test_the_sweep_finds_the_bus_and_the_scripts() -> void:
	assert_gt(_declared().size(), 40, "the bus declares its signals where we look for them")
	var paths: PackedStringArray = _script_paths()
	assert_gt(paths.size(), 250, "the sweep sees the game's scripts")
	assert_true(paths.has("res://scripts/managers/alert_manager.gd"),
		"including a manager that both emits and listens")

func test_the_mod_api_heading_is_still_in_the_file() -> void:
	# Every check below is scoped by this heading. Rename it and the suite would
	# quietly decide the bus has no mod API at all.
	assert_true(_bus_text().contains(MOD_API_HEADING),
		"signal_bus.gd still carries the '%s' heading" % MOD_API_HEADING)

# --- the two rules ----------------------------------------------------------------

## A signal nothing raises can never fire. This is the check that found
## `special_path_connection_added`, which had been declared and unemitted since
## the pathing rework and was deleted in WI-72.
func test_every_declared_signal_is_emitted_somewhere() -> void:
	var emitted: PackedStringArray = _usage()[&"emitted"]
	for name: String in _declared():
		assert_true(emitted.has(name),
			"SignalBus.%s is declared but nothing emits it - it is dead, not an extension point"
				% name)

## The other half: a signal nobody listens to is either a promise or a mistake,
## and the file has to say which.
func test_every_listener_less_signal_is_a_declared_mod_api() -> void:
	var listened: PackedStringArray = _usage()[&"listened"]
	for name: String in _declared():
		if listened.has(name):
			continue
		assert_true(MOD_API.has(name),
			("SignalBus.%s has no listener in the base game. Either something should"
			+ " be listening, or it belongs under the MOD API heading with a sentence"
			+ " saying what it promises.") % name)

# --- the list and the file agree ---------------------------------------------------

func test_every_mod_api_signal_is_under_the_heading() -> void:
	var promised: PackedStringArray = _under_the_heading()
	for name: String in MOD_API:
		assert_true(promised.has(name),
			"%s is listed here as mod API but is not declared under the heading in signal_bus.gd"
				% name)

func test_nothing_sits_under_the_heading_uninvited() -> void:
	for name: String in _under_the_heading():
		assert_true(MOD_API.has(name),
			"SignalBus.%s is declared under the MOD API heading but is not in this suite's list"
				% name)

## The promise IS the sentence. A mod-API signal with no doc comment tells a mod
## author nothing about when it fires or what stays valid afterwards, which is
## the whole reason these eleven are gathered rather than merely tolerated.
func test_every_mod_api_signal_carries_its_promise() -> void:
	var lines: PackedStringArray = _bus_text().split("\n")
	for name: String in MOD_API:
		var documented: bool = false
		for index: int in lines.size():
			if not lines[index].begins_with("signal %s" % name):
				continue
			# Walk back over the annotation to the doc comment above it.
			var probe: int = index - 1
			while probe >= 0 and lines[probe].begins_with("@"):
				probe -= 1
			documented = probe >= 0 and lines[probe].begins_with("##")
		assert_true(documented, "SignalBus.%s is promised to mods with no sentence saying what it promises" % name)

# --- the one that was deleted -------------------------------------------------------

## Pinned by name: the WI-72 census found it emitted by nothing and listened to by
## nothing, and it had a signature (`from: Node2D, group: StringName`) that looked
## exactly like a live pathing hook. Re-adding it means re-adding an emitter.
func test_the_emitterless_pathing_signal_stayed_deleted() -> void:
	assert_false(_declared().has("special_path_connection_added"),
		"special_path_connection_added is back - it needs an emitter this time")
