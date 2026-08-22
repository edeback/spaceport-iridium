extends GutTest

## [StoryFlags] (WI-62 §5): what a conversation is allowed to remember.
##
## The property under test is that a flag is **declared**. A `.dialogue` file
## writes a bare string on one side of the contract and reads it back on the other,
## and the typo is silent in the direction that matters -
## `flag("kestrel_dockd")` reads false forever and the chain simply never
## continues. Everything below exists to make that failure loud.
##
## Pure: constructed directly, no [Global], no [SignalBus].

var flags: StoryFlags

func before_each() -> void:
	flags = StoryFlags.new()

# --- declaration ---------------------------------------------------------------

func test_the_shipped_table_is_not_empty() -> void:
	assert_gt(StoryFlags.DECLARED.size(), 0,
		"the base game declares its own flags; an empty table means the chain has none")

func test_every_declared_flag_reads_its_default_before_anything_sets_it() -> void:
	for id: StringName in StoryFlags.DECLARED:
		assert_eq(flags.flag(id), StoryFlags.DECLARED[id],
			"%s reads its declared default on a fresh run" % id)

func test_an_undeclared_flag_write_is_refused_loudly() -> void:
	assert_false(flags.is_declared(&"kestrel_dockd"))
	assert_false(flags.set_flag(&"kestrel_dockd", true),
		"a typo must not create a new flag")
	assert_push_error("no such flag", "and it says so rather than swallowing it")

func test_an_undeclared_flag_read_is_refused_loudly() -> void:
	# The half that actually bites: a typo on the *read* side would otherwise be
	# indistinguishable from a chain the player never triggered.
	assert_false(flags.is_set(&"kestrel_dockd"))
	assert_push_error("no such flag")

func test_a_mod_can_declare_its_own_flag() -> void:
	assert_true(flags.declare(&"mymod.met_the_ferryman", false))
	assert_true(flags.set_flag(&"mymod.met_the_ferryman", true))
	assert_true(flags.is_set(&"mymod.met_the_ferryman"))

func test_a_mod_cannot_redefine_an_existing_flag() -> void:
	# Two mods claiming one id would otherwise resolve by load order.
	var existing: StringName = StoryFlags.DECLARED.keys()[0]
	assert_false(flags.declare(existing, 99),
		"re-declaring is refused rather than overwritten")
	assert_push_error("already declared")
	assert_eq(flags.default_for(existing), StoryFlags.DECLARED[existing])

func test_an_empty_id_is_refused() -> void:
	assert_false(flags.declare(&"", false))
	assert_push_error("no id")

# --- reading and writing --------------------------------------------------------

func test_set_and_read_a_bool() -> void:
	assert_true(flags.set_flag(&"kestrel_docked", true))
	assert_true(flags.is_set(&"kestrel_docked"))
	assert_eq(flags.flag(&"kestrel_docked"), true)

func test_bump_counts_up_and_returns_the_new_value() -> void:
	assert_eq(flags.bump(&"distress_hails_answered"), 1)
	assert_eq(flags.bump(&"distress_hails_answered", 2), 3)
	assert_eq(flags.flag(&"distress_hails_answered"), 3)

func test_bump_refuses_a_non_numeric_flag() -> void:
	assert_eq(flags.bump(&"kestrel_docked"), 0,
		"adding one to a bool is a mistake in the dialogue, not a coercion")
	assert_push_error("not a number")

func test_is_set_is_truthy_across_the_storage_types() -> void:
	# The one coercion, and it exists so `[if story.flag("x") /]` works without the
	# author knowing whether the flag is a bool or a counter.
	assert_false(flags.is_set(&"distress_hails_answered"), "zero is not set")
	flags.bump(&"distress_hails_answered")
	assert_true(flags.is_set(&"distress_hails_answered"), "a positive count is set")

func test_clear_returns_everything_to_its_default() -> void:
	flags.set_flag(&"kestrel_docked", true)
	flags.clear()
	assert_false(flags.is_set(&"kestrel_docked"))

# --- persistence ----------------------------------------------------------------

func test_only_the_deltas_are_saved() -> void:
	assert_eq(flags.to_save().size(), 0, "a run that decided nothing saves nothing")
	flags.set_flag(&"kestrel_docked", true)
	assert_eq(flags.to_save().size(), 1)

func test_setting_a_flag_back_to_its_default_drops_it_from_the_save() -> void:
	flags.set_flag(&"kestrel_docked", true)
	flags.set_flag(&"kestrel_docked", false)
	assert_eq(flags.to_save().size(), 0,
		"the save carries what the run changed, not a copy of the table")

func test_round_trip() -> void:
	flags.set_flag(&"kestrel_docked", true)
	flags.bump(&"distress_hails_answered", 4)
	var restored := StoryFlags.new()
	restored.from_save(flags.to_save())
	assert_true(restored.is_set(&"kestrel_docked"))
	assert_eq(restored.flag(&"distress_hails_answered"), 4)

## JSON has no int. A counter that comes back as 4.0 makes `bump` produce 5.0,
## which then renders as "5.0" wherever a dialogue interpolates it.
func test_a_counter_survives_json_as_an_int() -> void:
	var restored := StoryFlags.new()
	restored.from_save({"distress_hails_answered": 4.0})
	assert_eq(typeof(restored.flag(&"distress_hails_answered")), TYPE_INT,
		"a float from JSON is coerced back to the declared type")
	assert_eq(restored.bump(&"distress_hails_answered"), 5)

func test_an_unknown_saved_flag_is_dropped_rather_than_resurrected() -> void:
	# A mod was removed. Keeping the value would let it come back later carrying
	# a decision from a run that no longer makes sense.
	var restored := StoryFlags.new()
	restored.from_save({"someone_elses_flag": true})
	assert_eq(restored.to_save().size(), 0)

func test_a_newly_declared_flag_needs_no_migration() -> void:
	# The absent-key-means-default rule is what lets WI-63 add a flag without
	# touching SAVE_VERSION.
	var restored := StoryFlags.new()
	restored.from_save({})
	for id: StringName in StoryFlags.DECLARED:
		assert_eq(restored.flag(id), StoryFlags.DECLARED[id])
