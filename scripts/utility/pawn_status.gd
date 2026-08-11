class_name PawnStatus
extends RefCounted

## One sentence about what a pawn is doing, and one tone to draw it in (WI-56).
##
## Three surfaces asked this question and each answered it differently:
## `JobsScreen` composed `report() - subtask_report()`, `RobotVitalsTab` had its
## own six-branch `state_text()`, and the inspector's Job tab printed the literal
## word "Nothing" for a null job. Three sentences for one state is how **"Idle"
## and "No job" end up meaning the same thing on two screens** - and the crew
## roster is a column of exactly this text, forty rows deep, where a disagreement
## is impossible to miss.
##
## ## Why a [Facts] record rather than a pawn
##
## The rules are pure and are tested as such; a live [PawnBase] cannot be
## constructed in a GUT suite (its `_ready` reaches for `Global.path_manager`).
## So the rules take a plain record and [method of] is the one adapter that reads
## a pawn into one. Everything interesting is on the pure side.
##
## ## The tones
##
## The design's words are *"cyan working, grey transitional, dim idle, amber
## emergency"*. Amber is a budget (invariant 5), so [constant Tone.ALERT] is a
## closed set of three things - a resignation, a critical need, a drone out of
## power - and nothing else in a crew roster spends it.

## What a status sentence is drawn in. The colour itself is [method tone_color];
## the enum exists so the rule survives being read by something that is not a
## [Control].
enum Tone {
	## Cyan. The pawn is doing station work.
	WORKING,
	## Grey. Travelling, sleeping, eating, taking a break - purposeful, but not
	## work the player is waiting on.
	TRANSIT,
	## Dim. Nothing to do, or off duty. What the player is scanning for.
	IDLE,
	## Amber. Resigning, starving, or out of power.
	ALERT,
}

# --- sentences ------------------------------------------------------------------
#
# Every literal the status column can print, named. A roster, a job board and an
# inspector tab that share a constant cannot drift; three that share a habit can.

const TEXT_LEAVING: String = "Leaving the station"
const TEXT_RESIGNING: String = "Fed up — about to walk out"
const TEXT_NO_POWER: String = "Out of power — crawling"
const TEXT_RECHARGING: String = "Recharging"
const TEXT_REPAIRING: String = "Getting repaired"
const TEXT_SEEKING_CHARGER: String = "Seeking a charger"
const TEXT_OFF_DUTY: String = "Off duty"
## Two different absences, and the player can act on the difference: no job at
## all is the gap between one job and the next, an idle-type job is the board
## having had nothing this pawn could take.
const TEXT_BETWEEN_JOBS: String = "Idle — between jobs"
const TEXT_NO_WORK: String = "Idle — no work available"
const TEXT_WORKING: String = "Working"

## Job ids this class asks about by name. Three, all of them robot states that
## have no other way of being told apart from ordinary work.
const JOB_RECHARGE: StringName = &"recharge"
const JOB_GET_REPAIRED: StringName = &"get_repaired"

## Below this happiness a crew member counts as unhappy, and the morale number
## goes amber. The design's *"turns amber below 50"*, as a fraction.
const UNHAPPY_BELOW: float = 0.5

## Everything the rules need to know about one pawn. A record, not a view: the
## adapter fills it, the statics reason over it, and a test builds one by hand.
class Facts extends RefCounted:
	## False while the pawn is between jobs. Not the same as [member idle_job].
	var has_job: bool = false
	## The job's own headline, already composed by [method Job.report] from its
	## targets. Empty when there is no job.
	var report: String = ""
	## `idle` / `idle_wander` - the pawn chose to loiter because nothing else was
	## available.
	var idle_job: bool = false
	var job_id: StringName = &""
	var category: JobData.Category = JobData.Category.MISC
	## The current action is a movement in flight, which is what makes a haul read
	## as transit while the pawn is still walking to the crate.
	var moving: bool = false
	## Schedule state. A pawn with no schedule (drones) is always on duty.
	var on_shift: bool = true
	var robot: bool = false
	var robot_out_of_power: bool = false
	var robot_wants_charge: bool = false
	## Any enabled need is in its critical band.
	var critical_need: bool = false
	var resignation_pending: bool = false
	var resigned: bool = false
	var visitor: bool = false

## A sentence and the tone to draw it in - what every caller actually wants, so
## none of them has to call two statics and risk pairing the wrong two answers.
class Line extends RefCounted:
	var text: String = ""
	var tone: Tone = Tone.IDLE

	static func of(line_text: String, line_tone: Tone) -> Line:
		var line := Line.new()
		line.text = line_text
		line.tone = line_tone
		return line

# --- the rules ------------------------------------------------------------------

## The status line for `facts`. Order is the rule: the things that can end a pawn
## (leaving, starving, out of charge) outrank whatever they happen to be doing
## while it happens, because a starving pawn walking to the galley is still the
## row the player has to look at.
static func describe(facts: Facts) -> Line:
	if facts == null:
		return Line.of(TEXT_BETWEEN_JOBS, Tone.IDLE)
	if facts.resigned:
		return Line.of(TEXT_LEAVING, Tone.ALERT)
	if facts.resignation_pending:
		return Line.of(TEXT_RESIGNING, Tone.ALERT)
	if facts.robot:
		return _robot_line(facts)
	# The sentence and the tone are decided separately, which is what lets a
	# starving pawn keep the sentence that says whether they are already on their
	# way to fix it while the row goes amber anyway.
	var text: String = _activity_text(facts)
	if facts.critical_need:
		return Line.of(text, Tone.ALERT)
	if not facts.has_job or facts.idle_job:
		return Line.of(text, Tone.IDLE)
	return Line.of(text, tone_of(facts))

## What the pawn is doing, with no opinion about how urgent it is.
##
## An idle-type job deliberately does **not** print its own report ("Wandering to
## Corridor"): the job is a way of occupying a pawn with nothing to do, and
## printing it would dress the absence the player is scanning for up as activity.
static func _activity_text(facts: Facts) -> String:
	if not facts.has_job:
		return TEXT_BETWEEN_JOBS
	if facts.idle_job:
		# Off duty is not idleness - it is the schedule working - so it says so,
		# and the footer's idle count leaves it alone (see [method is_idle]).
		return TEXT_OFF_DUTY if not facts.on_shift else TEXT_NO_WORK
	return facts.report if not facts.report.strip_edges().is_empty() else TEXT_WORKING

## A drone's state, in the order the states can mask each other: no power beats
## everything, an active recharge beats *wanting* one, and a drone with nothing
## to do reads as idle rather than as working at nothing.
static func _robot_line(facts: Facts) -> Line:
	if facts.robot_out_of_power:
		return Line.of(TEXT_NO_POWER, Tone.ALERT)
	if facts.job_id == JOB_RECHARGE:
		return Line.of(TEXT_RECHARGING, Tone.TRANSIT)
	if facts.job_id == JOB_GET_REPAIRED:
		return Line.of(TEXT_REPAIRING, Tone.TRANSIT)
	if facts.robot_wants_charge:
		return Line.of(TEXT_SEEKING_CHARGER, Tone.TRANSIT)
	if not facts.has_job or facts.idle_job:
		# A drone has no schedule, so its idle text never reaches TEXT_OFF_DUTY.
		return Line.of(_activity_text(facts), Tone.IDLE)
	return Line.of(_activity_text(facts), tone_of(facts))

## The tone of a pawn that is genuinely doing something. Movement wins over the
## category: a hauler halfway to the crate has not started hauling yet, and the
## grey says so without the sentence having to change under the player's eye.
static func tone_of(facts: Facts) -> Tone:
	if facts == null:
		return Tone.IDLE
	if facts.moving:
		return Tone.TRANSIT
	match facts.category:
		JobData.Category.HAUL, JobData.Category.BUILD, JobData.Category.WORK:
			return Tone.WORKING
		_:
			return Tone.TRANSIT

## Is this pawn a row the player should act on?
##
## **On shift and with no work**, which is narrower than "has no real job": an
## off-duty crew member wandering the promenade at 03:00 is the schedule doing
## its job, and counting them would put a permanent `4 IDLE` in the roster's
## problem line that no amount of building would ever clear.
##
## Robots and visitors are never idle in this sense - neither is staff, and
## neither has a shift.
static func is_idle(facts: Facts) -> bool:
	if facts == null or facts.robot or facts.visitor or facts.resigned:
		return false
	if not facts.on_shift:
		return false
	return not facts.has_job or facts.idle_job

# --- the roster's filters and sort -------------------------------------------------

## The panel's four filter pills.
enum Filter { ALL, ON_SHIFT, IDLE, UNHAPPY }

## The three sort orders. STATUS is the default because it puts the **actionable**
## rows at the top, which is the whole reason a roster exists as a list rather
## than as a count.
enum Sort { STATUS, MORALE, NAME }

## Does this crew member survive `filter`? `happiness` is `-1.0` for a pawn with
## no morale to read, which fails UNHAPPY rather than passing it - "no reading" is
## not a low reading.
static func passes(facts: Facts, happiness: float, filter: Filter) -> bool:
	if facts == null:
		return false
	match filter:
		Filter.ON_SHIFT:
			return facts.on_shift
		Filter.IDLE:
			return is_idle(facts)
		Filter.UNHAPPY:
			# A resignation is the extreme of unhappy, so it belongs in this bucket
			# whatever the number currently says - a pawn can recover above the
			# threshold *during* their grace window and still be walking out.
			return facts.resigned or facts.resignation_pending \
				or (happiness >= 0.0 and happiness < UNHAPPY_BELOW)
		_:
			return true

## Ordering key for [constant Sort.STATUS]: lower sorts first.
##
## Amber outranks idle, which the WI's "idle first" does not say and which falls
## out of the same argument: the top of the list is for rows the player has to do
## something about, and somebody walking out is a shorter fuse than somebody
## standing around.
static func sort_bucket(facts: Facts) -> int:
	match describe(facts).tone:
		Tone.ALERT:
			return 0
		Tone.IDLE:
			return 1
		Tone.TRANSIT:
			return 2
		_:
			return 3

## Total order over the roster, so a sort is stable and never depends on scan
## order. Every comparison falls through to the name, which is unique enough in
## practice and - unlike an instance id - does not shuffle across a reload.
static func compares_before(a: Facts, a_happiness: float, a_name: String,
		b: Facts, b_happiness: float, b_name: String, sort: Sort) -> bool:
	match sort:
		Sort.MORALE:
			if not is_equal_approx(a_happiness, b_happiness):
				return a_happiness < b_happiness
		Sort.NAME:
			pass
		_:
			var bucket_a: int = sort_bucket(a)
			var bucket_b: int = sort_bucket(b)
			if bucket_a != bucket_b:
				return bucket_a < bucket_b
			if not is_equal_approx(a_happiness, b_happiness):
				return a_happiness < b_happiness
	return a_name.naturalnocasecmp_to(b_name) < 0

## The colour a tone draws in. Here rather than in each panel so the roster, the
## board and the inspector cannot disagree about what amber means.
static func tone_color(tone: Tone) -> Color:
	match tone:
		Tone.WORKING:
			return UIPalette.LIVE
		Tone.TRANSIT:
			return UIPalette.TEXT_SECONDARY
		Tone.ALERT:
			return UIPalette.ATTENTION_TEXT
		_:
			return UIPalette.TEXT_META

## The row treatment a status implies. Only the two ends are treatments - a
## working pawn is not "selected" and a transiting one is not a warning - so
## everything between reads inert.
static func tone_row(tone: Tone) -> UIPalette.Row:
	return UIPalette.Row.AMBER if tone == Tone.ALERT else UIPalette.Row.INERT

# --- the roster's problem line ---------------------------------------------------

## What the Crew panel's footer says about the whole roster: *"idle count,
## unhappy count, bunks short - so the panel answers 'is my crew fine?' without
## reading six rows"*.
class Summary extends RefCounted:
	var idle: int = 0
	var unhappy: int = 0
	var leaving: int = 0
	var bunks_short: int = 0

	## True when every term is zero - the state the footer draws in grey.
	func is_clear() -> bool:
		return idle == 0 and unhappy == 0 and leaving == 0 and bunks_short == 0

## Counts the roster's problems. `happiness` runs parallel to `facts` (one entry
## per crew member); `bunks` is [method CrewManager.sleep_capacity].
##
## Bunks short is `crew - bunks` clamped at zero - *"a real failure the game
## currently only surfaces as a needs decay nobody connects to a cause"*. It
## counts the whole roster, resigning members included: they are still sleeping
## here tonight.
static func summarize(facts: Array, happiness: Array, bunks: int) -> Summary:
	var summary := Summary.new()
	for i: int in facts.size():
		var entry: Facts = facts[i] as Facts
		if entry == null:
			continue
		if is_idle(entry):
			summary.idle += 1
		if entry.resigned or entry.resignation_pending:
			summary.leaving += 1
		elif i < happiness.size() and float(happiness[i]) < UNHAPPY_BELOW:
			# Someone already walking out is counted as leaving, not as unhappy -
			# they are the same person and two amber terms for one problem
			# overstates it.
			summary.unhappy += 1
	summary.bunks_short = maxi(facts.size() - maxi(bunks, 0), 0)
	return summary

## The footer sentence. Every term is printed even at zero, because a line that
## changes *length* as the station degrades is a line the eye has to re-read;
## only the colour moves.
static func summary_text(summary: Summary) -> String:
	if summary == null:
		return ""
	return "%d IDLE · %d UNHAPPY · %d LEAVING · %d BUNKS SHORT" % [
		summary.idle, summary.unhappy, summary.leaving, summary.bunks_short]

static func summary_color(summary: Summary) -> Color:
	if summary == null or summary.is_clear():
		return UIPalette.TEXT_META
	return UIPalette.ATTENTION_TEXT

# --- the adapter ------------------------------------------------------------------

## Reads a live pawn into [Facts]. The **only** place in the game that turns a
## pawn into a status, so a fourth surface wanting one adds a caller rather than
## a fourth set of rules.
static func facts_for(pawn: PawnBase) -> Facts:
	var facts := Facts.new()
	if pawn == null or not is_instance_valid(pawn):
		return facts
	facts.visitor = pawn.is_visitor
	facts.on_shift = pawn.is_on_shift()
	facts.moving = pawn.movement_component != null and pawn.movement_component.is_traveling()
	var job: Job = pawn.current_job
	if job != null and not job.is_ended():
		facts.has_job = true
		facts.report = job.report()
		facts.idle_job = job.is_idle_type()
		facts.job_id = job.data.id if job.data != null else &""
		facts.category = job.get_category()
	var robot := pawn as RobotPawnBase
	if robot != null:
		facts.robot = true
		var power: RobotPowerComponent = robot.power_component
		if power != null:
			facts.robot_out_of_power = power.must_recharge()
			facts.robot_wants_charge = power.wants_recharge()
		return facts
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs != null:
		facts.critical_need = needs.has_critical_need()
		facts.resignation_pending = needs.resignation_pending
		facts.resigned = needs.resigned
	return facts

## The one call a view makes: pawn in, sentence and tone out.
static func of(pawn: PawnBase) -> Line:
	return describe(facts_for(pawn))

## Where a pawn currently is, for the roster's meta line.
##
## `current_module` is null for two completely different reasons and the player
## can act on the difference: riding a turbolift (the cab owns the pawn's
## position) versus being outside in vacuum, where Void Sickness accrues. So the
## movement state is consulted before falling back to "outside".
static func location_of(pawn: PawnBase) -> String:
	if pawn == null or not is_instance_valid(pawn):
		return ""
	if pawn.current_module != null and is_instance_valid(pawn.current_module):
		var data: ModuleData = pawn.current_module.module_data
		if data != null and data.name != "":
			return data.name
		return pawn.current_module.name
	var movement: PawnMovementComponent = pawn.movement_component
	if movement != null and movement.state == PawnMovementComponent.State.Conveyed:
		return "In a turbolift"
	return "Outside the station"
