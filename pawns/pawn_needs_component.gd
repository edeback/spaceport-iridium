class_name PawnNeedsComponent
extends PawnComponentBase

## The decaying needs (hunger, sleep, recreation) plus derived happiness.
##
## Health is deliberately NOT here - it regenerates instead of decaying and
## grows combat/disease interactions later; see PawnHealthComponent. Social
## is not a need at all: socializing is one way of restoring recreation
## (SocialComponent is a recreation provider - WI-05).
##
## Each need follows the same loop (generalized via NeedDef): decay in
## game-hours; below percent_to_look_for_needs queue a personal job once
## (never the shared board, and never re-queued while one is pending); below
## percent_critical promote the queued job to the queue front and raise a
## station alert. No forced interrupts - that's the old starvation-lock bug.

@export var percent_critical: float = 5
@export var percent_to_look_for_needs: float = 30

@export var has_hunger_need: bool = false
@export var hunger_max: float = 100
@export var hunger_value: float = 100:
	set(new_hunger):
		new_hunger = clampf(new_hunger, 0, hunger_max)
		if hunger_value != new_hunger:
			hunger_value = new_hunger
			hunger_changed.emit(hunger_value)
signal hunger_changed(new_hunger: float)
## Game-hours from full to empty. ~12h means a pawn eats roughly twice per cycle.
@export var hunger_duration_hours: float = 24.0

@export var has_sleep_need: bool = false
@export var sleep_max: float = 100
@export var sleep_value: float = 100:
	set(new_sleep):
		new_sleep = clampf(new_sleep, 0, sleep_max)
		if sleep_value != new_sleep:
			sleep_value = new_sleep
			sleep_changed.emit(sleep_value)
signal sleep_changed(new_sleep: float)
## Game-hours from full to empty. As this is not paused during sleeping, 24h means one rest per cycle.
@export var sleep_duration_hours: float = 24.0

@export var has_recreation_need: bool = false
@export var recreation_max: float = 100
@export var recreation_value: float = 100:
	set(new_recreation):
		new_recreation = clampf(new_recreation, 0, recreation_max)
		if recreation_value != new_recreation:
			recreation_value = new_recreation
			recreation_changed.emit(recreation_value)
signal recreation_changed(new_recreation: float)
## Game-hours from full to empty.
@export var recreation_duration_hours: float = 24.0

## 0..1: weighted mean of enabled need percentages (plus sibling health, if
## the pawn has a PawnHealthComponent) plus timed modifiers. Consumed by
## PawnBase.work_speed().
var happiness: float = 1.0
signal happiness_changed(new_happiness: float)

# --- resignation (WI-07) ------------------------------------------------------
## Happiness below this (0..1) counts as miserable.
@export var resignation_threshold: float = 0.2
## Continuous misery hours before the pawn decides to leave.
@export var hours_to_resignation: float = 12.0
## Grace window after deciding: recovering above the threshold cancels.
@export var resignation_grace_hours: float = 6.0

var resignation_pending: bool = false
## Latched once the grace window expires - the decision is final.
var resigned: bool = false
var _misery_hours: float = 0.0
var _grace_remaining: float = 0.0

## One row per enabled need so _process stays a single generic loop instead
## of three copy-pasted blocks. Callables rather than raw refs because the
## exported per-need vars must stay individually editable in the inspector.
class NeedDef:
	var need_name: StringName
	var get_value: Callable
	var set_value: Callable
	var get_max: Callable
	var duration_hours: float
	var make_job: Callable
	var pending_job: Job = null
	var was_critical: bool = false

	func percent() -> float:
		return float(get_value.call()) / float(get_max.call()) * 100.0

var _needs: Array[NeedDef] = []
## id -> Vector2(value, remaining game-hours; INF = until removed).
var _modifiers: Dictionary[StringName, Vector2] = {}

func _ready() -> void:
	super()
	if has_hunger_need and hunger_duration_hours > 0:
		_needs.append(_make_def(&"hunger",
			func() -> float: return hunger_value,
			func(v: float) -> void: hunger_value = v,
			func() -> float: return hunger_max,
			hunger_duration_hours,
			func() -> Job: return Job.of(&"eat")))
	if has_sleep_need and sleep_duration_hours > 0:
		_needs.append(_make_def(&"sleep",
			func() -> float: return sleep_value,
			func(v: float) -> void: sleep_value = v,
			func() -> float: return sleep_max,
			sleep_duration_hours,
			func() -> Job: return Job.of(&"sleep")))
	if has_recreation_need and recreation_duration_hours > 0:
		_needs.append(_make_def(&"recreation",
			func() -> float: return recreation_value,
			func(v: float) -> void: recreation_value = v,
			func() -> float: return recreation_max,
			recreation_duration_hours,
			_make_recreation_job))
	_apply_difficulty_modifier()

## The permanent, station-wide happiness offset the chosen difficulty carries
## (WI-37). Applied here rather than through EventManager's station-effect
## machinery because that machinery is duration-based - it would tick this one
## away - whereas difficulty holds for the life of the run.
##
## Doing it in _ready means it needs no re-application hooks at all: a new hire, a
## pawn restored from a save, and a starting crew member all run this exactly
## once. The modifier is INF-duration, so add_modifier is idempotent under the
## single &"difficulty" id (no stacking across loads) and get_save_data skips it -
## it is re-derived from Global.difficulty every time, never persisted.
##
## Visitors are excluded: difficulty tunes how hard the STATION is to run, and a
## guest's mood is the reputation loop's own signal (WI-33).
func _apply_difficulty_modifier() -> void:
	if owner_pawn != null and owner_pawn.is_visitor:
		return
	var offset: float = Global.difficulty_mood_offset()
	if is_zero_approx(offset):
		return
	add_modifier(&"difficulty", offset)

## Recreation can be satisfied at a shop (paid, WI-33) or a free provider. Prefer
## a shop when the pawn can afford a reachable one - that's the money loop crew and
## visitors both feed. Both map to the "recreation" need (see
## _need_name_for_job) so only one is ever pending at a time.
func _make_recreation_job() -> Job:
	# The finder is the affordability gate now, so "can they shop?" and "where do
	# they shop?" can no longer answer differently - which is what the static
	# has_affordable_shop() helper on the old job existed to keep in sync by hand.
	if Finder_Shop.new().find(null, owner_pawn) != null:
		return Job.of(&"shop")
	return Job.of(&"recreate")

func _make_def(need_name: StringName, get_value: Callable, set_value: Callable, get_max: Callable, duration_hours: float, make_job: Callable) -> NeedDef:
	var def := NeedDef.new()
	def.need_name = need_name
	def.get_value = get_value
	def.set_value = set_value
	def.get_max = get_max
	def.duration_hours = duration_hours
	def.make_job = make_job
	return def

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	for need: NeedDef in _needs:
		need.set_value.call(float(need.get_value.call()) - sim_hours / need.duration_hours * float(need.get_max.call()))
		var percent: float = need.percent()
		if percent < percent_to_look_for_needs and need.pending_job == null:
			var job: Job = need.make_job.call()
			need.pending_job = job
			job.job_end.connect(_on_need_job_end.bind(need))
			owner_pawn.queue_job(job) # start when free
		if percent < percent_critical:
			if not need.was_critical:
				need.was_critical = true
				SignalBus.pawn_critical_need.emit(owner_pawn, need.need_name)
				_promote_critical_jobs()
		elif need.was_critical:
			need.was_critical = false
	# Exhaustion floor (WI-05): collapsed-from-tiredness needs positioning work
	# that doesn't exist; a heavy happiness penalty is the v1 consequence.
	if has_sleep_need:
		if sleep_value <= 0.0:
			add_modifier(&"exhausted", -0.2)
		else:
			remove_modifier(&"exhausted")
	_tick_modifiers(sim_hours)
	_recompute_happiness()
	_tick_resignation(sim_hours)

func _on_need_job_end(need: NeedDef) -> void:
	need.pending_job = null

## WI-21: adopt a needs job restored from a save so the decay loop treats it as
## the already-pending job for its need instead of queuing a second one. On load
## the component is fresh (pending_job is null), so without this a persisted
## eat/sleep/recreate job in the pawn's queue would be doubled by the first
## _process tick. Matched to its need by job id; no-op for anything else.
func adopt_restored_need_job(job: Job) -> void:
	var target_name: StringName = _need_name_for_job(job)
	if target_name == &"":
		return
	for need: NeedDef in _needs:
		if need.need_name == target_name:
			if need.pending_job == null:
				need.pending_job = job
				job.job_end.connect(_on_need_job_end.bind(need))
			return

func _need_name_for_job(job: Job) -> StringName:
	if job.is_type(&"eat"):
		return &"hunger"
	if job.is_type(&"sleep"):
		return &"sleep"
	if job.is_type(&"recreate") or job.is_type(&"shop"):
		return &"recreation"
	return &""

## Most-critical-percentage first: promote in descending-percent order so the
## worst-off need is pushed to the queue front last and ends up frontmost.
func _promote_critical_jobs() -> void:
	var criticals: Array[NeedDef] = []
	for need: NeedDef in _needs:
		if need.was_critical and need.pending_job != null:
			criticals.append(need)
	criticals.sort_custom(func(a: NeedDef, b: NeedDef) -> bool: return a.percent() > b.percent())
	for need: NeedDef in criticals:
		owner_pawn.promote_queued_job(need.pending_job)

# --- resignation (WI-07) --------------------------------------------------------

## Sustained misery -> pending resignation (alert + grace window) -> final.
## Recovery above the threshold at ANY point before the window expires
## resets everything; once `resigned` latches, CrewManager walks them out.
func _tick_resignation(sim_hours: float) -> void:
	if resigned:
		return
	if happiness >= resignation_threshold:
		_misery_hours = 0.0
		if resignation_pending:
			resignation_pending = false
			SignalBus.crew_resignation_cancelled.emit(owner_pawn)
		return
	_misery_hours += sim_hours
	if not resignation_pending:
		if _misery_hours >= hours_to_resignation:
			resignation_pending = true
			_grace_remaining = resignation_grace_hours
			SignalBus.crew_resigning.emit(owner_pawn, resignation_grace_hours)
	else:
		_grace_remaining -= sim_hours
		if _grace_remaining <= 0.0:
			resignation_pending = false
			resigned = true
			SignalBus.crew_resigned.emit(owner_pawn)

# --- happiness ----------------------------------------------------------------

## Timed happiness modifiers - where menial-work penalties, food-quality
## boosts, and event effects plug in. value adds directly to the 0..1
## happiness after the needs mean; duration_hours <= 0 means "until
## remove_modifier() is called". Re-adding an id refreshes it.
func add_modifier(id: StringName, value: float, duration_hours: float = 0.0) -> void:
	_modifiers[id] = Vector2(value, duration_hours if duration_hours > 0.0 else INF)

func remove_modifier(id: StringName) -> void:
	_modifiers.erase(id)

func _tick_modifiers(sim_hours: float) -> void:
	for id: StringName in _modifiers.keys():
		var modifier: Vector2 = _modifiers[id]
		if modifier.y == INF:
			continue
		modifier.y -= sim_hours
		if modifier.y <= 0.0:
			_modifiers.erase(id)
		else:
			_modifiers[id] = modifier

func _recompute_happiness() -> void:
	var total: float = 0.0
	var count: int = 0
	for need: NeedDef in _needs:
		total += clampf(need.percent() / 100.0, 0.0, 1.0)
		count += 1
	# Health contributes but lives in its own component; absent means
	# excluded from the mean, not counted as 0.
	var health: PawnHealthComponent = owner_pawn.get_component_by_type(PawnHealthComponent) as PawnHealthComponent
	if health != null:
		total += health.health_percent01()
		count += 1
	var new_happiness: float = (total / count) if count > 0 else 1.0
	for id: StringName in _modifiers:
		new_happiness += _modifiers[id].x
	new_happiness = clampf(new_happiness, 0.0, 1.0)
	if absf(new_happiness - happiness) > 0.001:
		happiness = new_happiness
		happiness_changed.emit(happiness)

# --- persistence -------------------------------------------------------------

func save_order() -> int:
	return 10

func save_key() -> StringName:
	return &"needs"

func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"hunger": hunger_value,
		"sleep": sleep_value,
		"recreation": recreation_value,
		"misery_hours": _misery_hours,
		"resignation_pending": resignation_pending,
		"grace_remaining": _grace_remaining,
		"resigned": resigned,
	}
	# Persist only finite-duration modifiers (good_meal/bad_meal, WI-29). INF ones
	# are re-derived every tick (exhausted from sleep; event modifiers re-applied
	# by their source), and INF doesn't round-trip through JSON anyway.
	var mods: Dictionary = {}
	for id: StringName in _modifiers:
		var m: Vector2 = _modifiers[id]
		if m.y != INF:
			mods[String(id)] = [m.x, m.y]
	if not mods.is_empty():
		data["modifiers"] = mods
	return data

func load_save_data(data: Dictionary) -> void:
	hunger_value = float(data.get("hunger", hunger_value))
	sleep_value = float(data.get("sleep", sleep_value))
	# Pre-WI-05 saves called this need "entertainment".
	recreation_value = float(data.get("recreation", data.get("entertainment", recreation_value)))
	_misery_hours = float(data.get("misery_hours", 0.0))
	resignation_pending = bool(data.get("resignation_pending", false))
	_grace_remaining = float(data.get("grace_remaining", 0.0))
	resigned = bool(data.get("resigned", false))
	# Timed modifiers (WI-29 good_meal/bad_meal). Missing key on older saves =
	# none restored, same as before this persisted.
	var mods: Dictionary = data.get("modifiers", {})
	for id_str: String in mods:
		var arr: Array = mods[id_str]
		if arr.size() >= 2:
			_modifiers[StringName(id_str)] = Vector2(float(arr[0]), float(arr[1]))
	if resigned:
		# The decision was already final when saved - resume the walkout once
		# the tree settles (CrewManager reacts by issuing the leave job).
		(func() -> void: SignalBus.crew_resigned.emit(owner_pawn)).call_deferred()
