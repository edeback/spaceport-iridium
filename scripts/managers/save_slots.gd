class_name SaveSlots
extends RefCounted

## The save files themselves (WI-73 §4, out of SaveManager): where a slot lives,
## reading and writing one, listing them, what a slot says about itself without
## being loaded, and migrating an old one up to [constant SAVE_VERSION].
##
## Everything here is static, because the main menu lists, summarizes, deletes and
## stages saves before any SaveManager node exists (WI-36). Nothing here knows about
## sections or the running game: SaveManager builds the envelope, this file stores
## it, and SaveManager applies what comes back.

const SAVE_VERSION: int = 3
const SAVE_DIR: String = "user://saves/"

## Where slots are read and written. [constant SAVE_DIR] everywhere but the
## integration suite (WI-69), which points it at a directory of its own so a
## test's save/reload never lands in the player's real `user://saves/`. Static
## for the same reason [member SaveManager._pending_load] is: the path has to be the same on
## both sides of the scene swap a load performs.
static var _save_dir: String = SAVE_DIR

## version -> Callable(data: Dictionary) -> Dictionary, upgrading one version
## step. A version with no entry cannot be migrated, and [method summarize] greys
## its Load button out.
static var _migrations: Dictionary[int, Callable] = {
	1: _migrate_1_to_2,
	2: _migrate_2_to_3,
}

# --- where slots live -----------------------------------------------------------

## Test seam (WI-69): redirects every slot read, write, listing and delete to
## `dir`, which must end in a slash. [StationFixture] sets it on boot and passes
## [constant SAVE_DIR] back on teardown. Nothing in the game calls this.
static func set_save_dir_for_test(dir: String) -> void:
	_save_dir = dir

static func save_dir() -> String:
	return _save_dir

static func slot_path(slot: String) -> String:
	return _save_dir + slot + ".json"

static func slot_exists(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))

static func delete_slot(slot: String) -> bool:
	if not slot_exists(slot):
		return false
	return DirAccess.remove_absolute(slot_path(slot)) == OK

# --- reading and writing ---------------------------------------------------------

## Writes an envelope to `slot`, creating the save directory if it has to.
## Returns the open error rather than raising it: a save that fails leaves the game
## running, and the caller decides what to say.
static func write_slot(slot: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(_save_dir)
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save file for writing: " + slot_path(slot))
		return FileAccess.get_open_error()
	# Full precision (WI-75): the default writes a float to 14 significant digits,
	# so a timer came back a few 1e-15 off - enough to end a door wait or a cab's
	# stop a frame early or late after a load, which is exactly the difference a
	# reload must not make. 17 digits round-trip every double exactly.
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.close()
	return OK

## Parses a slot file into its envelope dictionary. Returns {} for anything
## missing, unopenable or malformed - callers treat that as "no such save".
static func read_slot(slot: String) -> Dictionary:
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("No save file: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file: " + path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not (parsed as Dictionary).has("sections"):
		push_warning("Save file is malformed: " + path)
		return {}
	return parsed as Dictionary

## Every slot in user://saves/, newest first. One row per file, each already
## summarized for display - see summarize().
static func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(_save_dir)
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var slot: String = file_name.get_basename()
		var data: Dictionary = read_slot(slot)
		if data.is_empty():
			continue
		out.append(summarize(data, slot))
	# Newest first. Timestamps are Time.get_datetime_string_from_system(), which
	# is ISO-8601, so lexical order is chronological order.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("timestamp", "")) > String(b.get("timestamp", "")))
	return out

# --- what a slot says about itself ------------------------------------------------

## Pure: parsed envelope -> the row the slot list renders. Pre-WI-36 saves have
## no meta block, so the values are recovered from the sections instead (cheap:
## time and resources are tiny, and the pawn list only needs its size). The
## legacy crew figure is approximate - the saved pawn list also holds robots and
## visitors, which crew_count() excludes - but it's a slot subtitle, not a stat.
static func summarize(data: Dictionary, slot: String) -> Dictionary:
	var sections: Dictionary = data.get("sections", {})
	var meta: Dictionary = data.get("meta", {})
	var time_section: Dictionary = sections.get("time", {})
	var resources: Dictionary = sections.get("resources", {})
	var pawns: Array = sections.get("pawns", [])
	return {
		"slot": slot,
		"timestamp": String(data.get("timestamp", "")),
		"version": int(data.get("version", 0)),
		# A version this build can't migrate still lists (so the player can see and
		# delete it), but the menu greys out its Load button.
		"loadable": int(data.get("version", 0)) == SAVE_VERSION or _migrations.has(int(data.get("version", 0))),
		"cycle": int(meta.get("cycle", time_section.get("cycle", 0))),
		"hour": int(meta.get("hour", time_section.get("hour", 0))),
		"credits": int(meta.get("credits", resources.get("credits", 0))),
		"crew": int(meta.get("crew", pawns.size())),
		"tier": int(meta.get("tier", 1)),
		# WI-37. Pre-WI-37 saves carry neither key and read back as Normal, which is
		# also the difficulty they will actually load at.
		"difficulty": String(read_difficulty(data)),
		# WI-47 M11. Absent on pre-WI-47 saves, which correctly reads as "no mods".
		"mods": meta.get("mods", []),
	}

## "Cycle 4, 14:00 · 12340 cr · 6 crew" - the one-line subtitle for a slot row.
static func describe_slot(info: Dictionary) -> String:
	return "Cycle %d, %02d:00 · %d cr · %d crew · Tier %d · %s" % [
		int(info.get("cycle", 0)), int(info.get("hour", 0)),
		int(info.get("credits", 0)), int(info.get("crew", 0)), int(info.get("tier", 1)),
		difficulty_label(StringName(String(info.get("difficulty", DifficultyData.DEFAULT_ID))))]

## Display name for a saved difficulty id, falling back to the id itself if the
## .tres it names has since been renamed or removed.
static func difficulty_label(difficulty_id: StringName) -> String:
	var data: DifficultyData = DifficultyData.by_id(difficulty_id)
	return data.display_name if data != null else String(difficulty_id).capitalize()

## Player-typed slot names become file names, so anything that could walk out of
## user://saves/ (separators, dots, colons) is folded to underscores. Returns ""
## for a name with nothing usable left, which callers reject.
static func sanitize_slot_name(name: String) -> String:
	const ALLOWED: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_"
	var out: String = ""
	for character: String in name.strip_edges():
		out += character if ALLOWED.contains(character) else "_"
	out = out.strip_edges()
	# A name made entirely of separators would produce an unreachable file.
	for character: String in out:
		if character != "_" and character != "-" and character != " ":
			return out
	return ""

## The difficulty a parsed envelope was played at. Prefers the authoritative
## sections field, falls back to the meta summary, then to Normal - which is what
## every pre-WI-37 save (neither key present) resolves to.
static func read_difficulty(data: Dictionary) -> StringName:
	var sections: Dictionary = data.get("sections", {})
	var from_section: String = String(sections.get("difficulty", ""))
	if from_section != "":
		return StringName(from_section)
	var meta: Dictionary = data.get("meta", {})
	return StringName(String(meta.get("difficulty", String(DifficultyData.DEFAULT_ID))))

## The station name a parsed envelope was saved with (WI-59). Same precedence as
## read_difficulty: authoritative sections field, then the meta summary, then ""
## - which is what every pre-WI-59 save (neither key present) resolves to, and
## which Global.station_display_name() renders as the default name.
static func read_station_name(data: Dictionary) -> String:
	var sections: Dictionary = data.get("sections", {})
	var from_section: String = String(sections.get("station", ""))
	if from_section != "":
		return from_section
	var meta: Dictionary = data.get("meta", {})
	return String(meta.get("station", ""))

## The star and planet a parsed envelope was played under (WI-66).
##
## A save with no `system` block - every pre-WI-66 save - gets the legacy sky
## rather than a fresh roll. That is one specific sky, the same on every load,
## which is the property that matters: it is NOT the sky that save had, and that
## one-time change is deliberate, the same bargain WI-61 struck when every
## pre-WI-61 body restored as a belt asteroid. The block is written on the next
## save, so it stops being a fallback the first time the player saves.
##
## Note SAVE_VERSION does not move for this: an absent key has a correct answer,
## which is what a migration would have had to invent.
static func read_star_system(data: Dictionary) -> StarSystemData:
	var sections: Dictionary = data.get("sections", {})
	var block: Variant = sections.get("system", null)
	if block is Dictionary and not (block as Dictionary).is_empty():
		return StarSystemData.from_dict(block as Dictionary)
	return StarSystemGenerator.legacy()

# --- mod drift (WI-47 M11) ---------------------------------------------------------

## Mods this save was written with that aren't loaded now, plus mods whose version
## has changed. Pure - takes the record list rather than reading a save - so the
## slot browser and the load path share one rule.
##
## A mod present at a DIFFERENT version counts as drift too: a mod that renamed its
## ids between versions is indistinguishable from a missing one at load time.
## Extra mods installed since the save are NOT drift - additive content that wasn't
## there before is the normal, working case.
static func mod_drift(saved_records: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var loaded: Dictionary[String, String] = {}
	for record: Dictionary in ModManager.mod_records():
		loaded[String(record.get("id", ""))] = String(record.get("version", ""))
	for entry: Variant in saved_records:
		# Hand-edited or truncated saves reach here too; a malformed entry is
		# skipped rather than reported as a missing mod nobody can install.
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = entry
		var id: String = String(record.get("id", ""))
		if id == "":
			continue
		var version: String = String(record.get("version", ""))
		if not loaded.has(id):
			out.append("%s (%s) is not installed" % [id, version])
		elif loaded[id] != version:
			out.append("%s was saved at %s, installed version is %s" % [id, version, loaded[id]])
	return out

# --- migration --------------------------------------------------------------------

## Steps a parsed envelope up through the migration table as far as it goes. A
## version the table cannot step past comes back as it is, and
## [method SaveManager.stage_load] refuses it on the version check.
static func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	while version < SAVE_VERSION:
		if not _migrations.has(version):
			break # unmigratable - stage_load rejects it on the version check
		data = _migrations[version].call(data)
		var new_version: int = int(data.get("version", version))
		if new_version <= version:
			break # defensive: a migration must advance the version
		version = new_version
	return data

## v1 -> v2 (WI-44): in-flight jobs changed shape completely. A v1 job entry is
## {"type": "<job class id>", ...} written by the old per-class serializers; a v2
## entry is {"def": "<JobData id>", "index": <action>, ...} written by
## Job.to_dict(). There is no honest mapping between them - the v1 form records a
## job's STATE ENUM, and the action a resumed job should re-enter has to be
## derived from a driver that did not exist when the save was written.
##
## So they are dropped rather than translated. Everything a dropped job would
## have done gets re-derived on load anyway: board jobs are re-posted by their
## components, needs re-queue from the decay loop, and a pawn left holding cargo
## sweeps it into storage. The cost is one interrupted trip per pawn, once, on
## the first load of an old save - which is exactly the behaviour WI-44 replaced
## for every load, so nothing is lost that the old system guaranteed.
static func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	var pawns: Array = data.get("pawns", [])
	for entry: Variant in pawns:
		var pawn_entry: Dictionary = entry as Dictionary
		if pawn_entry == null:
			continue
		pawn_entry.erase("current_job")
		pawn_entry.erase("job_queue")
	data["version"] = 2
	return data

## v2 -> v3 (WI-65): a module's input bin and output bin became one bin.
##
## A v2 save of a refinery has two blocks under `storage`, keyed by node path -
## "Input Storage" and "Output Storage", or "Input"/"Output" on the growers - and
## the v3 scene has one node called "Storage Bay". Left alone, ModuleBase's walk
## iterates live components and would restore neither: both saved paths are
## orphans, and the player's ore and iron would silently vanish, which is exactly
## what _warn_orphaned_blocks exists to shout about.
##
## So the pair is folded. Contents merge (the two never held the same resource -
## one side's ingredients, the other's products), and the priority is taken from
## the INPUT block: an output slot's priority is derived from its role in v3 and
## whatever the old export bin was tuned to no longer means anything.
##
## Roles themselves are NOT written here. They are derived on load by whatever
## configures the bin - the recipe for a processor, the order sheet for a bay -
## all of which run in the ready pass, before this block is applied. A v2 save
## that named a recipe which has since changed would otherwise restore slots
## roled for a recipe that no longer exists.
static func _migrate_2_to_3(data: Dictionary) -> Dictionary:
	var sections: Dictionary = data.get("sections", {})
	var world: Dictionary = sections.get("world", {})
	for entry: Variant in world.get("modules", []):
		var module: Dictionary = entry as Dictionary
		if module == null or not module.has("storage"):
			continue
		var bins: Dictionary = module["storage"]
		var input_key: String = ""
		var output_key: String = ""
		for key: String in bins:
			var lowered: String = key.to_lower()
			if lowered.begins_with("input"):
				input_key = key
			elif lowered.begins_with("output"):
				output_key = key
		if input_key == "" or output_key == "":
			continue
		var merged: Dictionary = bins[input_key]
		var resources: Dictionary = merged.get("resources", {})
		for id_str: String in Dictionary(bins[output_key]).get("resources", {}):
			# An id in both blocks would be a resource that was an ingredient AND a
			# product of the same recipe, which v3 asserts against. Keep the input
			# side rather than guessing, and say so.
			if resources.has(id_str):
				push_warning("WI-65 migration: %s appears in both bins of a module, keeping the input side"
					% id_str)
				continue
			resources[id_str] = Dictionary(bins[output_key])["resources"][id_str]
		merged["resources"] = resources
		bins.erase(input_key)
		bins.erase(output_key)
		bins["Storage Bay"] = merged
	data["version"] = 3
	return data
