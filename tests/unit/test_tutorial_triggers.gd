extends GutTest

## [TutorialTriggers] - what SAI is allowed to react to (WI-63 §5).
##
## The declared-id argument is the same one [StoryFlags], [Groups] and [UIType]
## make: a trigger is a bare string on both sides of a contract, and the typo is
## silent in the direction that matters. A hint watching `module_unpowerd` never
## fires, forever, with nothing on screen to say so.

var triggers: TutorialTriggers

func before_each() -> void:
	triggers = TutorialTriggers.new()

# --- the declared table ---------------------------------------------------------

func test_the_vanilla_triggers_are_declared() -> void:
	for id: StringName in [&"module_unreachable", &"module_unpowered", &"trader_arrived",
			&"space_body_arrived", &"crew_resigning", &"need_critical"]:
		assert_true(triggers.is_declared(id), "'%s' is a trigger" % id)

func test_an_undeclared_trigger_is_not_declared() -> void:
	assert_false(triggers.is_declared(&"module_unpowerd"), "a typo is not a trigger")

## Asking a nonexistent trigger about its arity has to be loud. Answering false
## quietly is how a typo survives to ship.
func test_asking_an_undeclared_trigger_about_its_filter_errors() -> void:
	assert_false(triggers.takes_filter(&"nope"), "the fallback is the safe answer")
	assert_push_error_count(1, "but it is still an error")

# --- filters --------------------------------------------------------------------

## The two that carry one, and why: `need_critical` is one watcher serving three
## hints, and `space_body_arrived` lets a mod's own body kind have its own advice.
func test_only_the_two_discriminating_triggers_take_a_filter() -> void:
	assert_true(triggers.takes_filter(&"need_critical"), "hunger / sleep / recreation")
	assert_true(triggers.takes_filter(&"space_body_arrived"), "comet, or a mod's body")
	for id: StringName in [&"module_unreachable", &"module_unpowered",
			&"trader_arrived", &"crew_resigning"]:
		assert_false(triggers.takes_filter(id), "'%s' takes no filter" % id)

# --- mod declarations -----------------------------------------------------------

func test_a_mod_can_declare_its_own_trigger() -> void:
	assert_true(triggers.declare(&"mymod.reactor_hot", false), "declared")
	assert_true(triggers.is_declared(&"mymod.reactor_hot"), "and now exists")
	assert_false(triggers.takes_filter(&"mymod.reactor_hot"), "with the arity it asked for")
	assert_push_error_count(0, "quietly")

## Two mods claiming one trigger would otherwise depend on load order.
func test_redeclaring_an_existing_trigger_is_refused() -> void:
	assert_false(triggers.declare(&"need_critical", false), "a vanilla id is not up for grabs")
	assert_true(triggers.takes_filter(&"need_critical"), "and its arity is unchanged")
	assert_push_error_count(1, "loudly")

func test_declaring_an_empty_id_is_refused() -> void:
	assert_false(triggers.declare(&"", true), "a trigger needs a name")
	assert_push_error_count(1, "loudly")

func test_a_mod_declaration_does_not_leak_into_the_const_table() -> void:
	triggers.declare(&"mymod.thing", true)
	assert_false(TutorialTriggers.DECLARED.has(&"mymod.thing"),
		"the base game's table stays the base game's")

# --- listing --------------------------------------------------------------------

func test_all_lists_vanilla_then_mod_triggers() -> void:
	triggers.declare(&"mymod.thing", false)
	var all: Array[StringName] = triggers.all()
	assert_eq(all.size(), TutorialTriggers.DECLARED.size() + 1, "everything, once")
	assert_eq(all.back(), &"mymod.thing", "mods after vanilla")

func test_all_is_stable_between_calls() -> void:
	assert_eq(triggers.all(), triggers.all(), "a sweep reports in a stable order")
