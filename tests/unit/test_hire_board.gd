extends GutTest

## Unit tests for [HireBoard] - which blocker the Crew panel's HIRE page prints
## above the list, and which stays on a single candidate's card.
##
## Pure: constructs nothing, touches no Global and no SignalBus. The sentences
## fed in are the ones [CrewManager.hire_block_reason] produces; this suite never
## asserts *why* a hire is blocked, only who says so.

const PODS: String = "No free sleeping pods"
const CREDITS: String = "Not enough credits"

# --- shared_reason -------------------------------------------------------------

func test_nothing_blocked_hoists_nothing() -> void:
	assert_eq(HireBoard.shared_reason(["", "", ""] as Array[String]), "",
		"three unblocked cards give the page nothing to say")

func test_a_blocker_every_card_shares_is_the_pages() -> void:
	assert_eq(HireBoard.shared_reason([PODS, PODS, PODS] as Array[String]), PODS,
		"one sentence, printed once")

func test_a_blocker_only_some_cards_have_stays_on_them() -> void:
	assert_eq(HireBoard.shared_reason([CREDITS, "", CREDITS] as Array[String]), "",
		"one affordable candidate makes the price a per-card fact")

func test_two_different_blockers_are_never_hoisted() -> void:
	assert_eq(HireBoard.shared_reason([PODS, CREDITS] as Array[String]), "",
		"hoisting one of them would say the other did not apply")

## The single-card case is the one that decides whether "shared" means "every
## card" or "more than one card". It means every card: a lone blocked candidate
## on a page of one IS the page's whole story.
func test_one_blocked_card_is_the_whole_page() -> void:
	assert_eq(HireBoard.shared_reason([PODS] as Array[String]), PODS,
		"the only card's blocker is the page's")

## An empty pool has no shared anything, and a sentence printed over an empty
## list has nothing to explain.
func test_an_empty_pool_hoists_nothing() -> void:
	assert_eq(HireBoard.shared_reason([] as Array[String]), "",
		"no candidates, no page-level blocker")

# --- gate_reason ---------------------------------------------------------------

func test_no_bay_gates_the_whole_page() -> void:
	assert_eq(HireBoard.gate_reason(false, ["", ""] as Array[String]),
		HireBoard.NO_BAY_REASON,
		"nowhere to dock blocks the page even when the manager objects to nothing")

## The bay gate out-ranks the manager's own sentence rather than stacking with
## it: with nowhere to dock it does not matter whether the station could afford
## the fare, and printing both would make the player fix the wrong thing first.
func test_the_bay_gate_outranks_a_shared_blocker() -> void:
	assert_eq(HireBoard.gate_reason(false, [CREDITS, CREDITS] as Array[String]),
		HireBoard.NO_BAY_REASON, "one blocker at a time, the structural one first")

func test_a_bay_plus_a_shared_blocker_gates_on_the_blocker() -> void:
	assert_eq(HireBoard.gate_reason(true, [PODS, PODS] as Array[String]), PODS)

func test_a_bay_and_nothing_shared_gates_on_nothing() -> void:
	assert_eq(HireBoard.gate_reason(true, [CREDITS, ""] as Array[String]), "")

func test_the_bay_reason_names_the_fix() -> void:
	# The sentence is what a player with no docking bay reads first, so it has to
	# say what to do, not merely what is wrong.
	assert_true(HireBoard.NO_BAY_REASON.to_lower().contains("build"),
		"the gate tells the player what to build: %s" % HireBoard.NO_BAY_REASON)

# --- card_reason ---------------------------------------------------------------

func test_a_card_stays_silent_when_the_page_already_said_it() -> void:
	assert_eq(HireBoard.card_reason(PODS, PODS), "",
		"the page prints it once; the row underneath does not repeat it")

func test_a_card_says_a_blocker_the_page_did_not() -> void:
	assert_eq(HireBoard.card_reason(CREDITS, ""), CREDITS)

## The docking-bay case: the manager has no objection to any candidate, so the
## cards have nothing of their own to add to the gate.
func test_an_unblocked_card_under_a_gate_says_nothing() -> void:
	assert_eq(HireBoard.card_reason("", HireBoard.NO_BAY_REASON), "")

func test_an_unblocked_card_with_no_gate_says_nothing() -> void:
	assert_eq(HireBoard.card_reason("", ""), "")

# --- can_hire ------------------------------------------------------------------

func test_a_clear_card_under_no_gate_is_pressable() -> void:
	assert_true(HireBoard.can_hire("", ""))

func test_a_gate_blocks_a_card_with_no_reason_of_its_own() -> void:
	assert_false(HireBoard.can_hire("", HireBoard.NO_BAY_REASON),
		"this is the whole docking-bay gate: every button off, no card blamed")

func test_a_cards_own_reason_blocks_it_under_no_gate() -> void:
	assert_false(HireBoard.can_hire(CREDITS, ""))

## The end-to-end shape the panel actually renders: three candidates, one
## affordable, a bay present. Exactly one button lives and exactly two rows talk.
func test_the_mixed_page_reads_correctly() -> void:
	var reasons: Array[String] = [CREDITS, "", CREDITS]
	var gate: String = HireBoard.gate_reason(true, reasons)
	assert_eq(gate, "", "nothing is hoisted")
	var talking: int = 0
	var pressable: int = 0
	for reason: String in reasons:
		if not HireBoard.card_reason(reason, gate).is_empty():
			talking += 1
		if HireBoard.can_hire(reason, gate):
			pressable += 1
	assert_eq(talking, 2, "the two priced-out rows say so")
	assert_eq(pressable, 1, "the affordable one is the only live button")

## And the gated shape: nothing is affordable-or-not because nothing can dock.
func test_the_gated_page_reads_correctly() -> void:
	var reasons: Array[String] = ["", "", ""]
	var gate: String = HireBoard.gate_reason(false, reasons)
	assert_eq(gate, HireBoard.NO_BAY_REASON)
	for reason: String in reasons:
		assert_eq(HireBoard.card_reason(reason, gate), "", "no row repeats the gate")
		assert_false(HireBoard.can_hire(reason, gate), "no row is pressable")
