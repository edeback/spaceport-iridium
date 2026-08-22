extends GutTest

## A sweep of every authored [EventData], [SpeakerData], [FactionData] and
## [PortraitPool] in the build (WI-62).
##
## The first test here is the most valuable one in the item. An event names a cue
## in a `.dialogue` file by string; a typo in either half is an event that fires,
## logs a transmission, and then **does nothing, forever, silently**. Nothing else
## in the game would ever notice.
##
## This is a content test rather than a logic test, so it loads real resources
## through [ContentPaths] - the same walk the managers do, which means a mod's
## content is swept too.

# --- events -----------------------------------------------------------------------

func _events() -> Array[EventData]:
	var out: Array[EventData] = []
	for path: String in ContentPaths.scan(ContentPaths.EVENTS):
		var event: EventData = ResourceLoader.load(path) as EventData
		if event != null:
			out.append(event)
	return out

func test_the_sweep_actually_finds_events() -> void:
	# A sweep whose scan silently returned nothing would pass everything below it.
	assert_gt(_events().size(), 8, "the scan sees data/events/")

func test_every_event_names_a_dialogue_and_a_cue_that_exists() -> void:
	for event: EventData in _events():
		assert_eq(event.script_problem(), "",
			"event '%s' would fire and do nothing" % event.id)

func test_every_event_has_an_id_and_a_title() -> void:
	for event: EventData in _events():
		assert_ne(event.id, &"", "an event with no id cannot be saved or scheduled")
		assert_false(event.title.is_empty(),
			"event '%s' owes the alert and the Comms row a headline" % event.id)

func test_no_two_events_share_an_id() -> void:
	var seen: Array[StringName] = []
	for event: EventData in _events():
		assert_false(seen.has(event.id), "'%s' is declared twice" % event.id)
		seen.append(event.id)

## Every event logs its `body` to the Comms feed the moment it fires, so an empty
## one leaves a blank row the player cannot make sense of.
func test_every_event_has_a_body_for_the_comms_row() -> void:
	for event: EventData in _events():
		assert_false(event.body.strip_edges().is_empty(),
			"event '%s' logs an empty transmission" % event.id)

func test_no_event_carries_a_null_condition_slot() -> void:
	for event: EventData in _events():
		for condition: EventCondition in event.conditions:
			assert_not_null(condition,
				"event '%s' has an empty condition slot in its authored array" % event.id)

## An event with `weight = 0` and an unreachable `min_cycle` can never turn up on
## a natural roll. That is a legitimate shape - `insolvency_warning` is fired by
## [EconomyManager] and `kestrel_pursuit` by a conversation - but an event that
## nothing fires **and** nothing queues is dead content, and the only way to
## notice is to go looking.
##
## Two callers count: a `.dialogue` file that queues it, and a `.gd` file that
## names it. WI-62 nearly shipped this checking only the first, which declared the
## shipped insolvency card unreachable.
func test_every_scheduled_only_event_is_reachable_from_somewhere() -> void:
	var referenced: PackedStringArray = _queued_event_ids()
	referenced.append_array(_code_referenced_ids())
	for event: EventData in _events():
		if event.weight > 0.0 or event.min_cycle < 999:
			continue
		assert_true(referenced.has(String(event.id)),
			"'%s' can never roll and nothing fires it - it is unreachable" % event.id)

## Any id a `.gd` file names as a [StringName] literal. Deliberately loose: it
## only has to prove *something* points at the event, and a false positive here
## costs nothing while a false negative fails a shipped event.
func _code_referenced_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var pattern := RegEx.create_from_string('&"([a-z0-9_.]+)"')
	for path: String in ResourceScanner.scan_paths("res://scripts", "gd"):
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in pattern.search_all(text):
			out.append(found.get_string(1))
	return out

## Text-scraped rather than parsed: the compiled [DialogueResource] holds mutation
## expressions as token trees, and the source is the thing an author reads.
func _queued_event_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var pattern := RegEx.create_from_string('queue_event\\(\\s*"([^"]+)"')
	for path: String in _dialogue_paths():
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in pattern.search_all(text):
			out.append(found.get_string(1))
	return out

func _dialogue_paths() -> Array[String]:
	return ResourceScanner.scan_paths("res://data/dialogue", "dialogue")

# --- the dialogue files themselves ----------------------------------------------------

func test_every_dialogue_file_compiled() -> void:
	# A file with a syntax error imports as an empty resource rather than failing
	# the build, so "it loaded" is not the same as "it compiled".
	for path: String in _dialogue_paths():
		var resource: DialogueResource = ResourceLoader.load(path) as DialogueResource
		assert_not_null(resource, "%s did not import as a DialogueResource" % path)
		if resource == null:
			continue
		assert_gt(resource.get_cues().size(), 0, "%s declares no cues" % path)
		assert_gt(resource.lines.size(), 0, "%s compiled to nothing" % path)

## Every character a `.dialogue` file names should be a declared [SpeakerData] -
## otherwise it prints verbatim with no portrait, which is the *narration*
## behaviour and is almost never what a name-shaped character string meant.
##
## Narration lines have no character at all, so they never reach this.
func test_every_named_character_is_a_declared_speaker() -> void:
	var declared: Array[StringName] = []
	for speaker: SpeakerData in _speakers():
		declared.append(speaker.id)
	for path: String in _dialogue_paths():
		var resource: DialogueResource = ResourceLoader.load(path) as DialogueResource
		if resource == null:
			continue
		for character: String in resource.character_names:
			if character.is_empty():
				continue
			assert_true(declared.has(StringName(character)),
				"%s names '%s', which has no SpeakerData - it will render nameless"
					% [path.get_file(), character])

## `": "` anywhere in a line splits it into character and text, so a narration
## line containing one silently acquires a speaker made of its own first clause.
## The escape is `\:`, and this is the trap that catches an author out.
func test_no_line_accidentally_names_a_character() -> void:
	for path: String in _dialogue_paths():
		var resource: DialogueResource = ResourceLoader.load(path) as DialogueResource
		if resource == null:
			continue
		for character: String in resource.character_names:
			assert_lt(character.length(), 32,
				"%s has a 'character' called '%s' - almost certainly a colon in prose"
					% [path.get_file(), character])

# --- speakers, factions, pools -----------------------------------------------------------

func _speakers() -> Array[SpeakerData]:
	var out: Array[SpeakerData] = []
	for path: String in ContentPaths.scan(ContentPaths.SPEAKERS):
		var speaker: SpeakerData = ResourceLoader.load(path) as SpeakerData
		if speaker != null:
			out.append(speaker)
	return out

func test_every_speaker_has_an_id_and_a_face() -> void:
	assert_gt(_speakers().size(), 0, "the scan sees data/speakers/")
	for speaker: SpeakerData in _speakers():
		assert_ne(speaker.id, &"", "a speaker with no id can never be named in dialogue")
		assert_true(speaker.has_portrait(),
			"speaker '%s' resolves no face" % speaker.id)

func test_every_speakers_faction_exists() -> void:
	var declared: Array[StringName] = []
	for faction: FactionData in _factions():
		declared.append(faction.id)
	for speaker: SpeakerData in _speakers():
		if speaker.faction == &"":
			continue
		assert_true(declared.has(speaker.faction),
			"speaker '%s' names faction '%s', which does not exist"
				% [speaker.id, speaker.faction])

func _factions() -> Array[FactionData]:
	var out: Array[FactionData] = []
	for path: String in ContentPaths.scan(ContentPaths.FACTIONS):
		var faction: FactionData = ResourceLoader.load(path) as FactionData
		if faction != null:
			out.append(faction)
	return out

func test_every_faction_has_an_id_a_name_and_a_description() -> void:
	assert_gt(_factions().size(), 0, "the scan sees data/factions/")
	for faction: FactionData in _factions():
		assert_ne(faction.id, &"")
		assert_false(faction.display_name.is_empty(), "%s has no name" % faction.id)
		assert_false(faction.description.is_empty(),
			"%s owes the Standing tab a sentence" % faction.id)

## Every faction a `.dialogue` file tries to move must exist **and be scored** -
## `shift_standing` on an unscored faction errors at runtime, which is exactly the
## kind of thing that only shows up on the one branch nobody tested.
func test_every_faction_a_dialogue_shifts_is_scored() -> void:
	var scored: Array[String] = []
	for faction: FactionData in _factions():
		if faction.scored:
			scored.append(String(faction.id))
	var pattern := RegEx.create_from_string('shift_standing\\(\\s*"([^"]+)"')
	for path: String in _dialogue_paths():
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in pattern.search_all(text):
			assert_true(scored.has(found.get_string(1)),
				"%s shifts '%s', which is not a scored faction"
					% [path.get_file(), found.get_string(1)])

## Same shape, for flags: an id a `.dialogue` file writes has to be one
## [StoryFlags] declares, or the write is refused at runtime and the chain breaks
## silently.
func test_every_flag_a_dialogue_touches_is_declared() -> void:
	var flags := StoryFlags.new()
	var pattern := RegEx.create_from_string('(?:set_flag|flag|bump|value)\\(\\s*"([^"]+)"')
	for path: String in _dialogue_paths():
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in pattern.search_all(text):
			var id := StringName(found.get_string(1))
			assert_true(flags.is_declared(id),
				"%s uses flag '%s', which is not in StoryFlags.DECLARED"
					% [path.get_file(), id])

## And for resources: `station.credits(...)` cannot be typo'd, but
## `station.salvage("stell", ...)` can, and it fails at the moment the player
## picks the option rather than at load.
func test_every_resource_id_a_dialogue_names_exists() -> void:
	var known: Array[String] = []
	for path: String in ContentPaths.scan(ContentPaths.RESOURCES):
		var resource: ResourceData = ResourceLoader.load(path) as ResourceData
		if resource != null:
			known.append(String(resource.id))
	var pattern := RegEx.create_from_string(
		'(?:salvage|grant_cargo|market_shock|stock)\\(\\s*"([^"]+)"')
	for path: String in _dialogue_paths():
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in pattern.search_all(text):
			assert_true(known.has(found.get_string(1)),
				"%s names resource '%s', which does not exist"
					% [path.get_file(), found.get_string(1)])

# --- mood ids ----------------------------------------------------------------------------

## The Needs tab breaks every mood modifier down into a cause (WI-51), and for an
## event-driven one it does that by looking the id up in
## [member EventData.mood_ids]. A `station.mood(...)` call whose id is not
## declared prints a modifier the player cannot account for.
func test_every_mood_id_a_dialogue_applies_is_declared_by_its_event() -> void:
	var declared: Array[String] = []
	for event: EventData in _events():
		for mood_id: String in event.mood_ids:
			declared.append(mood_id)
		declared.append("event_" + String(event.id))
	var pattern := RegEx.create_from_string('station\\.mood\\(\\s*"([^"]+)"')
	for path: String in _dialogue_paths():
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in pattern.search_all(text):
			assert_true(declared.has(found.get_string(1)),
				"%s applies mood '%s' - add it to its event's mood_ids"
					% [path.get_file(), found.get_string(1)])
