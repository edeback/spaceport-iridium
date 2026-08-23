extends GutTest

## [TutorialTarget] - the grammar a `.dialogue` file writes to point at a piece of
## the interface (WI-63 §3).
##
## Parsing is pure and lives here; resolution needs live nodes and is
## [TutorialCoach]'s. That split is the only reason the grammar is testable at
## all, and it is why an unparseable target has to be **loud** - the coach's own
## "target not found this frame" case is legitimate and silent, so a typo that
## reached it would look exactly like a closed panel.

# --- the kinds ------------------------------------------------------------------

func test_every_scheme_parses_to_its_own_kind() -> void:
	assert_eq(TutorialTarget.parse("console:build").kind, TutorialTarget.Kind.CONSOLE)
	assert_eq(TutorialTarget.parse("category:crew").kind, TutorialTarget.Kind.CATEGORY)
	assert_eq(TutorialTarget.parse("module:mess_hall_mdata").kind, TutorialTarget.Kind.MODULE)
	assert_eq(TutorialTarget.parse("vital:derived:crew").kind, TutorialTarget.Kind.VITAL)
	assert_eq(TutorialTarget.parse("subject").kind, TutorialTarget.Kind.SUBJECT)
	assert_eq(TutorialTarget.parse("screen").kind, TutorialTarget.Kind.SCREEN)
	assert_push_error_count(0, "every legal form parses quietly")

func test_the_id_is_everything_after_the_first_colon() -> void:
	# `derived:crew` is a real chip id and `mymod.thing` a real mod id, so the
	# split has to be on the FIRST colon rather than the last, and must not
	# choke on a dot.
	assert_eq(TutorialTarget.parse("vital:derived:crew").id, &"derived:crew")
	assert_eq(TutorialTarget.parse("module:mymod.reactor").id, &"mymod.reactor")

func test_surrounding_whitespace_is_ignored() -> void:
	var target: TutorialTarget = TutorialTarget.parse("  console:build  ")
	assert_eq(target.kind, TutorialTarget.Kind.CONSOLE, "an author's stray space is not an error")
	assert_eq(target.id, &"build")

# --- refusals -------------------------------------------------------------------

func test_an_unknown_scheme_is_invalid_and_loud() -> void:
	var target: TutorialTarget = TutorialTarget.parse("panel:build")
	assert_false(target.is_valid(), "'panel' is not a target kind")
	assert_push_error_count(1, "and says so, naming the string")

func test_an_empty_string_is_invalid_and_loud() -> void:
	assert_false(TutorialTarget.parse("").is_valid(), "nothing is not a target")
	assert_push_error_count(1)

func test_a_scheme_that_needs_an_id_is_refused_without_one() -> void:
	assert_false(TutorialTarget.parse("console").is_valid(), "which console button?")
	assert_false(TutorialTarget.parse("category:").is_valid(), "an empty id is no id")
	assert_push_error_count(2)

## Writing `subject:pawn` looks reasonable and means nothing - the subject is
## whatever the hint was fired about, and there is exactly one.
func test_a_bare_scheme_is_refused_with_an_id() -> void:
	assert_false(TutorialTarget.parse("subject:pawn").is_valid(), "subject takes no id")
	assert_false(TutorialTarget.parse("screen:all").is_valid(), "nor does screen")
	assert_push_error_count(2)

func test_a_default_constructed_target_is_invalid() -> void:
	assert_false(TutorialTarget.new().is_valid(), "the failure value is INVALID")

# --- classification -------------------------------------------------------------

## What the coach asks to decide whether to look for a [Control] at all.
func test_chrome_is_the_four_kinds_that_name_a_control() -> void:
	for text: String in ["console:build", "category:crew", "module:x", "vital:x"]:
		assert_true(TutorialTarget.parse(text).is_chrome(), "'%s' names a control" % text)
	for text: String in ["subject", "screen"]:
		assert_false(TutorialTarget.parse(text).is_chrome(), "'%s' does not" % text)

## SCREEN is the plate on its own - advice about the station rather than about a
## control. Everything else that resolves gets a ring.
func test_only_screen_declines_a_ring() -> void:
	assert_false(TutorialTarget.parse("screen").wants_ring(), "the plate alone")
	assert_true(TutorialTarget.parse("subject").wants_ring(), "a pawn gets framed")
	assert_true(TutorialTarget.parse("console:build").wants_ring(), "so does a button")
	assert_false(TutorialTarget.new().wants_ring(), "and an invalid target draws nothing")

# --- round trip -----------------------------------------------------------------

func test_as_text_round_trips_through_parse() -> void:
	for text: String in ["console:build", "category:crew", "module:mess_hall_mdata",
			"vital:derived:crew", "subject", "screen"]:
		assert_eq(TutorialTarget.parse(text).as_text(), text, "'%s' survives a round trip" % text)

func test_an_invalid_target_describes_itself_as_invalid() -> void:
	assert_eq(TutorialTarget.new().as_text(), "<invalid>", "an error message can name it")
