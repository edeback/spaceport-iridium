extends GutTest

## [SpeakerCast] and [PortraitPool] (WI-62 §4).
##
## The property under test is the brief's: *"an image can be required but random -
## if so, the image should be stable over several lines of conversation."* The
## rule that satisfies it is that a speaker is resolved **once per conversation,
## not once per line**, and what it replaces is a real defect - the placeholder
## rolled `randi_range(12, 49)` inside `apply_dialogue_line`, so a pirate's face
## changed every time he opened his mouth.
##
## The catalogue and the name roller are injected, which is what lets this run
## without the plaintext name trees behind [NameGenerator].
##
## Pure: constructed directly, no [Global], no nodes.

const PORTRAIT_DIR: String = "res://assets/external/thirstsector_portraits"

var _next_name: int = 0

func before_each() -> void:
	_next_name = 0

## A counter rather than a real generator, so a repeated name is a real failure
## rather than a coincidence.
func _roller() -> String:
	_next_name += 1
	return "Name%d" % _next_name

func _pool(pool_id: StringName, prefix: String,
		excluded: PackedStringArray = PackedStringArray()) -> PortraitPool:
	var pool := PortraitPool.new()
	pool.id = pool_id
	pool.directory = PORTRAIT_DIR
	pool.prefix = prefix
	pool.excluded_prefixes = excluded
	pool.extension = "png"
	return pool

func _speaker(speaker_id: StringName, pool: PortraitPool = null,
		display_name: String = "") -> SpeakerData:
	var speaker := SpeakerData.new()
	speaker.id = speaker_id
	speaker.display_name = display_name
	speaker.portrait_pool = pool
	return speaker

func _catalog(speakers: Array[SpeakerData]) -> Dictionary[StringName, SpeakerData]:
	var out: Dictionary[StringName, SpeakerData] = {}
	for speaker: SpeakerData in speakers:
		out[speaker.id] = speaker
	return out

func _cast(speakers: Array[SpeakerData], seed_value: int = 1234) -> SpeakerCast:
	return SpeakerCast.new(_catalog(speakers), _roller, seed_value)

# --- the stability property --------------------------------------------------------

func test_a_speaker_resolves_to_the_same_face_and_name_every_line() -> void:
	var cast := _cast([_speaker(&"pirate_captain", _pool(&"pirate", "portrait_pirate"))])
	var first: SpeakerCast.Member = cast.resolve("pirate_captain")
	for line: int in 8:
		var again: SpeakerCast.Member = cast.resolve("pirate_captain")
		assert_eq(again.portrait_path, first.portrait_path, "the face holds still")
		assert_eq(again.display_name, first.display_name, "and so does the name")

func test_the_name_is_rolled_once_not_once_per_line() -> void:
	var cast := _cast([_speaker(&"pirate_captain", _pool(&"pirate", "portrait_pirate"))])
	cast.resolve("pirate_captain")
	cast.resolve("pirate_captain")
	cast.resolve("pirate_captain")
	assert_eq(_next_name, 1, "the roller is called once for the whole conversation")

func test_a_fresh_conversation_gets_a_fresh_cast() -> void:
	var speakers: Array[SpeakerData] = [
		_speaker(&"pirate_captain", _pool(&"pirate", "portrait_pirate"))]
	var first: SpeakerCast.Member = _cast(speakers, 11).resolve("pirate_captain")
	var second: SpeakerCast.Member = _cast(speakers, 9999).resolve("pirate_captain")
	assert_ne(first.portrait_path, second.portrait_path,
		"stability is per conversation, not forever")

func test_has_resolved_reports_the_stability_directly() -> void:
	var cast := _cast([_speaker(&"pirate_captain", _pool(&"pirate", "portrait_pirate"))])
	assert_false(cast.has_resolved("pirate_captain"))
	cast.resolve("pirate_captain")
	assert_true(cast.has_resolved("pirate_captain"))

# --- distinctness --------------------------------------------------------------------

func test_two_speakers_from_one_pool_do_not_share_a_face() -> void:
	# A two-hander where both parties look identical reads as a bug even though
	# each roll was fair on its own.
	var pool: PortraitPool = _pool(&"pirate", "portrait_pirate")
	var cast := _cast([_speaker(&"one", pool), _speaker(&"two", pool)])
	assert_ne(cast.resolve("one").portrait_path, cast.resolve("two").portrait_path)

func test_a_pool_with_fewer_faces_than_speakers_repeats_rather_than_hanging() -> void:
	# A content problem, and repeating a face is a better answer than looping.
	var pool: PortraitPool = _pool(&"mercenary", "portrait_mercenary")
	var speakers: Array[SpeakerData] = []
	var count: int = pool.size() + 2
	for index: int in count:
		speakers.append(_speaker(StringName("s%d" % index), pool))
	var cast := _cast(speakers)
	for index: int in count:
		assert_false(cast.resolve("s%d" % index).portrait_path.is_empty())

# --- determinism ---------------------------------------------------------------------

func test_the_same_seed_produces_the_same_cast() -> void:
	var speakers: Array[SpeakerData] = [
		_speaker(&"a", _pool(&"pirate", "portrait_pirate")),
		_speaker(&"b", _pool(&"pirate", "portrait_pirate"))]
	var first := _cast(speakers, 4242)
	_next_name = 0
	var second := _cast(speakers, 4242)
	assert_eq(first.resolve("a").portrait_path, second.resolve("a").portrait_path)

# --- unknown characters ----------------------------------------------------------------

func test_an_unknown_character_prints_verbatim_with_no_face() -> void:
	# The narration path. It must not warn: a line with no speaker at all is
	# legitimate, and half the converted events use one.
	var cast := _cast([])
	var member: SpeakerCast.Member = cast.resolve("Long-range sensors")
	assert_false(member.known)
	assert_eq(member.display_name, "Long-range sensors")
	assert_eq(member.portrait_path, "")
	assert_null(member.portrait())

func test_an_authored_display_name_beats_the_roller() -> void:
	var cast := _cast([_speaker(&"sai", null, "SAI")])
	assert_eq(cast.resolve("sai").display_name, "SAI")
	assert_eq(_next_name, 1, "the roll still happens, it is simply not used")

# --- the pools themselves ---------------------------------------------------------------

func test_every_shipped_pool_matched_something() -> void:
	for path: String in ContentPaths.scan(ContentPaths.PORTRAITS):
		var pool: PortraitPool = ResourceLoader.load(path) as PortraitPool
		assert_not_null(pool, "%s is a PortraitPool" % path)
		if pool == null:
			continue
		assert_gt(pool.size(), 0, "%s matched no faces - check its prefix" % pool.id)

func test_the_civilian_pool_excludes_the_faction_prefixes() -> void:
	# `portrait` is a prefix of `portrait_pirate`, so without the exclusion list
	# the civilian pool would silently contain every face in the game.
	var civilian: PortraitPool = _pool(&"civilian", "portrait", PackedStringArray([
		"portrait_pirate", "portrait_luddic", "portrait_hegemony", "portrait_diktat",
		"portrait_league", "portrait_corporate", "portrait_mercenary"]))
	var everything: PortraitPool = _pool(&"everything", "portrait")
	assert_gt(civilian.size(), 0)
	assert_lt(civilian.size(), everything.size(),
		"the exclusions actually excluded something")
	for path: String in civilian.paths():
		assert_false(path.get_file().begins_with("portrait_"),
			"%s is a faction face and should not be in the civilian pool" % path)

## The `portrait19` case, pinned. The vanilla art runs `portrait12`…`portrait18`
## then `portrait20`…`portrait49` - there is no `portrait19`. Any code that builds
## a path from a numeric range asks for a missing file one time in thirty-seven;
## a directory listing cannot. This test exists so nobody reintroduces the range.
func test_a_pool_with_a_hole_in_its_numbering_resolves_every_entry() -> void:
	var pool: PortraitPool = _pool(&"civilian", "portrait", PackedStringArray([
		"portrait_pirate", "portrait_luddic", "portrait_hegemony", "portrait_diktat",
		"portrait_league", "portrait_corporate", "portrait_mercenary"]))
	var names: PackedStringArray = PackedStringArray()
	for path: String in pool.paths():
		names.append(path.get_file())
	assert_true(names.has("portrait18.png"), "the pool spans the hole")
	assert_true(names.has("portrait20.png"))
	assert_false(names.has("portrait19.png"), "and portrait19 genuinely does not exist")
	for index: int in pool.size():
		assert_true(FileAccess.file_exists(pool.path_at(index)),
			"every index in the pool is a file that is really there")

func test_path_at_wraps_rather_than_clamping() -> void:
	var pool: PortraitPool = _pool(&"mercenary", "portrait_mercenary")
	assert_eq(pool.path_at(pool.size()), pool.path_at(0))
	assert_eq(pool.path_at(-1), pool.path_at(pool.size() - 1))

func test_an_empty_pool_falls_back_rather_than_breaking() -> void:
	var pool: PortraitPool = _pool(&"nothing", "no_such_prefix")
	assert_true(pool.is_empty())
	assert_eq(pool.path_at(0), "")
	var cast := _cast([_speaker(&"ghost", pool)])
	var member: SpeakerCast.Member = cast.resolve("ghost")
	assert_true(member.known, "a declared speaker is still a speaker")
	assert_eq(member.portrait_path, "", "it simply has no face")

func test_a_missing_directory_is_empty_rather_than_an_error() -> void:
	var pool := PortraitPool.new()
	pool.id = &"gone"
	pool.directory = "res://data/portraits/a_mod_that_was_removed"
	assert_true(pool.is_empty())
