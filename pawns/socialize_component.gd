class_name SocializeComponent
extends PawnComponentBase

## Chats and opinions (WI-48).
##
## Two crew who share a module talk, occasionally, and it goes well or it
## doesn't. A good chat pays recreation; a bad one leaves a short sour mood. All
## of it is remembered: this component is both the chat driver and the ledger of
## what this pawn thinks of everyone they have ever spoken to.
##
## This replaced WI-05's passive company drip - recreation trickling up for as
## long as anyone else stood in the room. The drip had no cause the player could
## point at; a chat has a partner, a verdict and a line in the log.
##
## Driver and ledger live in one component deliberately:
##   - the driver is the ledger's only writer, so splitting them buys a
##     cross-component lookup per resolution and nothing else;
##   - it keeps the save block singular;
##   - and "carries this component = participates" stays exactly one rule.
##     Robots and drones don't have it, so they neither chat nor hold opinions
##     without a single is-robot check anywhere. Visitors don't have it either
##     (visitor_pawn.tscn), which is what keeps guests out of the crew's social
##     life for now - adding them later is a scene edit, not a code change.
##
## Balance guard inherited from WI-05 and still mandatory: chat recreation stops
## hard at social_cap_percent, so the recreation JOB stays the only way to fill
## the bar and the only lever above half happiness from that need.
##
## The one thing here that is not chat-related is the Introvert solitude drip,
## which is kept as it was: it doesn't involve another pawn, so chats don't
## replace it.

## Recomputed company mood modifier (see _refresh_company_modifier). One id, so
## it can never stack or leak when the pawn walks out of the room.
const MOOD_MOD_ID: StringName = &"company"
## Short sour mood after a chat that went badly. Finite, so it persists and
## ticks down through PawnNeedsComponent like the WI-29 meal modifiers.
const BAD_CHAT_MOD_ID: StringName = &"bad_chat"
const SOCIAL_SKILL: StringName = &"social"
## How many chats the Social tab's log remembers.
const RECENT_LOG_MAX: int = 10
## Ceiling on the idle accumulator. Nothing reads it past the chat interval, and
## an unbounded float would grow all run and land in every save.
const MAX_TRACKED_IDLE_HOURS: float = 999.0

@export_group("Chat pacing")
## Game-hours a pawn waits between wanting to chat, before traits.
@export var base_chat_interval_hours: float = 1.0
## Game-hours after which a previous partner is back to full pick weight. Below
## this they're less likely than someone this pawn hasn't spoken to lately.
@export var partner_refresh_hours: float = 24.0

@export_group("Chat outcome")
## Odds a chat goes well before any modifier. Well above 0.5 on purpose: this
## number IS the "people who work together usually like each other" trend.
@export var base_positive_chance: float = 0.75
## How hard existing opinion pulls the odds - the feedback that makes
## friendships and feuds self-sustaining.
@export var opinion_weight: float = 0.35
## How hard aligned/conflicting traits pull the odds.
@export var affinity_weight: float = 0.20
## How much the pair's social skill moves the odds. 0.0 unhooks it entirely.
@export var skill_weight: float = 0.10
## Mean social skill at which a pair is exactly average company. Below it the
## skill term goes (mildly) negative, above it positive.
@export var social_skill_neutral_level: int = 3
## The skill term at social skill 0 - being a bore is a small penalty, where
## being a great conversationalist (level 10, term +1.0) is a large bonus.
@export var social_skill_floor: float = -0.1
## Hard bounds on the odds, so neither spiral can latch.
@export var min_positive_chance: float = 0.05
@export var max_positive_chance: float = 0.97
## Opinion points one chat is worth, rolled in a band. These are the step taken
## from neutral; SocialMath.opinion_delta shrinks it near the extremes.
@export var positive_magnitude_min: float = 4.0
@export var positive_magnitude_max: float = 9.0
@export var negative_magnitude_min: float = 3.0
@export var negative_magnitude_max: float = 8.0

@export_group("Payout")
## Recreation points one good chat pays, before the pawn's trait multiplier.
@export var chat_recreation: float = 8.0
## Chat recreation never lifts recreation above this percent of max (WI-05).
@export var social_cap_percent: float = 50.0
## Social xp both participants earn per chat.
@export var chat_skill_xp: float = 1.0
## Happiness offset and duration after a chat that went badly.
@export var bad_chat_mood_offset: float = -0.05
@export var bad_chat_mood_hours: float = 4.0

@export_group("Company mood")
## Opinions inside +/-this move mood not at all. Wide on purpose: most crew are
## just colleagues, and a permanent nonzero modifier on everyone is noise.
@export var mood_neutral_band: float = 25.0
## Happiness offset at the extremes of the scale.
@export var mood_max_offset: float = 0.06

@export_group("Solitude (WI-22)")
## Recreation per game-hour an Introvert gains while ALONE in a module. Capped
## by social_cap_percent like chat recreation is.
@export var solitude_fun_per_hour: float = 9.0

## partner pawn_id -> this pawn's standing with them. Only ever grows: a fired
## crew member's entry is kept (it's a few bytes, and the Phase-4 death work
## wants "who knew them"), and resolves lazily against the live roster.
var _opinions: Dictionary[int, PawnOpinion] = {}
## Game-hours since this pawn last chatted with anyone. The cooldown is per
## pawn, not per partner.
var _hours_since_chat: float = 0.0
## Newest-first ring of recent chats for the Social tab.
var _recent: Array[Dictionary] = []

var _needs: PawnNeedsComponent = null

func _ready() -> void:
	super()
	# Cheap periodic check, not per-frame - this is exactly what slow_tick is
	# for. Connections die with the node, no explicit disconnect needed.
	Global.time_manager.slow_tick.connect(_on_slow_tick)
	# Walking into or out of a room changes who this pawn is standing with, and
	# the mood modifier must not lag a tick behind them.
	if owner_pawn != null:
		owner_pawn.module_changed.connect(_on_module_changed)

# --- the loop ------------------------------------------------------------------

func _on_slow_tick(interval: float) -> void:
	if owner_pawn == null:
		return
	var sim_hours: float = interval / TimeManager.SECONDS_PER_HOUR
	_hours_since_chat = minf(_hours_since_chat + sim_hours, MAX_TRACKED_IDLE_HOURS)
	if owner_pawn.current_module == null:
		# Outside. Clearing the modifier here is what stops a spacewalk from
		# carrying the mess hall's company mood along with it.
		_refresh_company_modifier([] as Array[SocializeComponent])
		return
	var asleep: bool = is_asleep()
	var wants_chat: bool = not asleep and is_ready_to_chat()
	var solitary: bool = not asleep and _prefers_solitude()
	# The group scan is the expensive part, so it only runs when its answer can
	# change something: a pawn actually off cooldown, an Introvert checking
	# they're alone, or a pawn with opinions that could be moving their mood.
	if not wants_chat and not solitary and _opinions.is_empty():
		return
	var present: Array[SocializeComponent] = _present()
	_refresh_company_modifier(present)
	if solitary:
		_tick_solitude(sim_hours, present.is_empty())
	if not wants_chat:
		return
	var partner: SocializeComponent = _pick_partner(present)
	if partner != null:
		_resolve_chat(partner)

func _on_module_changed() -> void:
	# Nothing to refresh before this pawn has met anyone: the modifier is only
	# ever added from a nonempty ledger, and the ledger never shrinks.
	if _opinions.is_empty() or owner_pawn == null:
		return
	_refresh_company_modifier(_present())

## Game-hours this pawn waits between chats, after their traits.
func chat_interval() -> float:
	var traits: PawnTraitsComponent = owner_pawn.get_traits_component() if owner_pawn != null else null
	var multiplier: float = traits.chat_interval_multiplier() if traits != null else 1.0
	return SocialMath.chat_interval(base_chat_interval_hours, multiplier)

func is_ready_to_chat() -> bool:
	return _hours_since_chat >= chat_interval()

## A pawn in a bunk is not company. Public because the partner scan asks it of
## other pawns' components.
func is_asleep() -> bool:
	if owner_pawn == null:
		return false
	var job: Job = owner_pawn.current_job
	return job != null and job.is_type(&"sleep")

func _prefers_solitude() -> bool:
	var traits: PawnTraitsComponent = owner_pawn.get_traits_component()
	return traits != null and traits.prefers_solitude()

## Everyone else in this module who can hold up their end of a conversation
## (i.e. has a SocializeComponent - robots and visitors don't). Sleepers are
## included: they're still in the room for mood purposes, and _pick_partner
## filters them out separately.
func _present() -> Array[SocializeComponent]:
	var out: Array[SocializeComponent] = []
	var here: ModuleBase = owner_pawn.current_module
	if here == null:
		return out
	for node: Node in get_tree().get_nodes_in_group(Groups.PAWN):
		var other: PawnBase = node as PawnBase
		if other == null or other == owner_pawn or other.current_module != here:
			continue
		var social: SocializeComponent = other.get_component_by_type(SocializeComponent) as SocializeComponent
		if social != null:
			out.append(social)
	return out

## One partner from those present and also off cooldown, weighted against
## recency so an established pair doesn't monopolise each other while a new hire
## stands unspoken to in the same room.
func _pick_partner(present: Array[SocializeComponent]) -> SocializeComponent:
	var candidates: Array[SocializeComponent] = []
	var weights: Array[float] = []
	var total: float = 0.0
	var now: float = _now_hours()
	for other: SocializeComponent in present:
		if other.is_asleep() or not other.is_ready_to_chat():
			continue
		var record: PawnOpinion = _opinions.get(other.owner_pawn.pawn_id, null)
		var weight: float = SocialMath.partner_weight(
				now - record.stamp_hours() if record != null else INF,
				record.chats if record != null else 0,
				partner_refresh_hours)
		candidates.append(other)
		weights.append(weight)
		total += weight
	if candidates.is_empty() or total <= 0.0:
		return null
	var roll: float = randf() * total
	for i: int in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]

## One chat, one shared verdict, two independently-sized opinion shifts.
func _resolve_chat(partner: SocializeComponent) -> void:
	var mean_opinion: float = (opinion_of(partner.owner_pawn.pawn_id)
			+ partner.opinion_of(owner_pawn.pawn_id)) * 0.5
	var affinity: float = SocialMath.trait_affinity(_social_axes(), partner._social_axes())
	var skill: float = SocialMath.skill_term(_social_level(), partner._social_level(),
			SkillData.MAX_LEVEL, social_skill_neutral_level, social_skill_floor)
	var positive: bool = randf() < SocialMath.positive_chance(mean_opinion, affinity, skill, _chat_tuning())
	var magnitude: float = randf_range(positive_magnitude_min, positive_magnitude_max) if positive \
			else randf_range(negative_magnitude_min, negative_magnitude_max)
	# Both cooldowns reset inside the resolution: whichever component ticked
	# first initiates, and the partner's own tick this same interval finds
	# itself on cooldown. That is what makes a double resolution impossible
	# without depending on the order slow_tick reaches subscribers in.
	_hours_since_chat = 0.0
	partner._hours_since_chat = 0.0
	var my_delta: float = _apply_outcome(partner.owner_pawn, positive, magnitude)
	var their_delta: float = partner._apply_outcome(owner_pawn, positive, magnitude)
	SignalBus.pawns_chatted.emit(owner_pawn, partner.owner_pawn, positive, (my_delta + their_delta) * 0.5)

## Applies a resolved chat to THIS pawn only; the partner's component does the
## same for itself. Returns the opinion shift.
func _apply_outcome(partner_pawn: PawnBase, positive: bool, magnitude: float) -> float:
	var record: PawnOpinion = _record_for(partner_pawn.pawn_id)
	var delta: float = SocialMath.opinion_delta(record.value, positive, magnitude)
	record.value = clampf(record.value + delta, -SocialMath.OPINION_MAX, SocialMath.OPINION_MAX)
	record.chats += 1
	record.last_cycle = Global.time_manager.cycle
	record.last_hour = Global.time_manager.hour
	record.last_positive = positive
	if positive:
		_grant_chat_recreation()
	else:
		var needs: PawnNeedsComponent = _needs_component()
		if needs != null:
			needs.add_modifier(BAD_CHAT_MOD_ID, bad_chat_mood_offset, bad_chat_mood_hours)
	_log_chat(partner_pawn, positive, delta)
	owner_pawn.grant_skill_xp(SOCIAL_SKILL, chat_skill_xp)
	return delta

## Recreation from a good chat, hard-stopped at the WI-05 passive cap. A pawn
## already above the cap still chats and still moves opinions - only the payout
## is clipped, or a well-entertained crew would stop having a social life.
func _grant_chat_recreation() -> void:
	var needs: PawnNeedsComponent = _needs_component()
	if needs == null or not needs.has_recreation_need:
		return
	var cap: float = _recreation_cap(needs)
	if needs.recreation_value >= cap:
		return
	var traits: PawnTraitsComponent = owner_pawn.get_traits_component()
	var multiplier: float = traits.chat_recreation_multiplier() if traits != null else 1.0
	needs.recreation_value = minf(needs.recreation_value + chat_recreation * multiplier, cap)

## Introvert-only (WI-22): recharges while ALONE in a module. Not replaced by
## chats, because no other pawn is involved.
func _tick_solitude(sim_hours: float, alone: bool) -> void:
	if not alone:
		return
	var needs: PawnNeedsComponent = _needs_component()
	if needs == null or not needs.has_recreation_need:
		return
	var cap: float = _recreation_cap(needs)
	if needs.recreation_value >= cap:
		return
	needs.recreation_value = minf(needs.recreation_value + solitude_fun_per_hour * sim_hours, cap)

## Mood from the company this pawn is currently keeping. Derived state - never
## saved, recomputed here and re-derived on the first tick after a load.
##
## Crew this pawn has never spoken to are skipped rather than averaged in as
## zeroes: one friend in a room of strangers should read as a friend, not as a
## diluted quarter of one.
func _refresh_company_modifier(present: Array[SocializeComponent]) -> void:
	var needs: PawnNeedsComponent = _needs_component()
	if needs == null:
		return
	var total: float = 0.0
	var count: int = 0
	for other: SocializeComponent in present:
		var record: PawnOpinion = _opinions.get(other.owner_pawn.pawn_id, null)
		if record == null:
			continue
		total += record.value
		count += 1
	var offset: float = 0.0
	if count > 0:
		offset = SocialMath.mood_offset(total / float(count), mood_neutral_band, mood_max_offset)
	if is_zero_approx(offset):
		needs.remove_modifier(MOOD_MOD_ID)
	else:
		needs.add_modifier(MOOD_MOD_ID, offset)

func _log_chat(partner_pawn: PawnBase, positive: bool, delta: float) -> void:
	# The partner's name is snapshotted rather than resolved on read: by the time
	# the panel shows this line they may have been fired and despawned, and
	# "chatted with someone" is a worse story than a name.
	_recent.push_front({
		"with": partner_pawn.pawn_id,
		"name": partner_pawn.pawn_name,
		"positive": positive,
		"delta": delta,
		"cycle": Global.time_manager.cycle,
		"hour": Global.time_manager.hour,
	})
	while _recent.size() > RECENT_LOG_MAX:
		_recent.pop_back()

# --- queries (UI, cheats, the partner scan) --------------------------------------

## This pawn's standing with `pawn_id`; 0.0 for someone they've never met.
func opinion_of(pawn_id: int) -> float:
	var record: PawnOpinion = _opinions.get(pawn_id, null)
	return record.value if record != null else 0.0

## The full record, or null when the pair has never spoken.
func record_of(pawn_id: int) -> PawnOpinion:
	return _opinions.get(pawn_id, null)

## Newest-first, and a copy - callers must not edit the ledger's log.
func recent_chats() -> Array[Dictionary]:
	return _recent.duplicate()

## Debug/cheat setter. Marks the pair as having spoken so the panel reads
## "Friendly", not "Haven't spoken" next to a nonzero bar.
func set_opinion(pawn_id: int, value: float) -> void:
	var record: PawnOpinion = _record_for(pawn_id)
	record.value = clampf(value, -SocialMath.OPINION_MAX, SocialMath.OPINION_MAX)
	if record.chats <= 0:
		record.chats = 1
		record.last_cycle = Global.time_manager.cycle
		record.last_hour = Global.time_manager.hour

## Resolve a chat right now, ignoring cooldowns and where either pawn is (the
## force_chat cheat). False when the pair can't chat at all.
func force_chat(other: SocializeComponent) -> bool:
	if other == null or other == self or other.owner_pawn == null or owner_pawn == null:
		return false
	_resolve_chat(other)
	return true

func _record_for(pawn_id: int) -> PawnOpinion:
	var record: PawnOpinion = _opinions.get(pawn_id, null)
	if record == null:
		record = PawnOpinion.new()
		_opinions[pawn_id] = record
	return record

func _chat_tuning() -> SocialMath.ChatTuning:
	var tuning := SocialMath.ChatTuning.new()
	tuning.base_chance = base_positive_chance
	tuning.opinion_weight = opinion_weight
	tuning.affinity_weight = affinity_weight
	tuning.skill_weight = skill_weight
	tuning.min_chance = min_positive_chance
	tuning.max_chance = max_positive_chance
	return tuning

func _social_axes() -> Dictionary[StringName, float]:
	var traits: PawnTraitsComponent = owner_pawn.get_traits_component()
	return traits.social_axes() if traits != null else {}

## Effective, not raw: a disease dulling the social skill (WI-31) can push a
## pawn from average company down into being a bore, for free.
func _social_level() -> int:
	var skills: PawnSkillsComponent = owner_pawn.get_skills_component()
	return skills.effective_level(SOCIAL_SKILL) if skills != null else 0

func _recreation_cap(needs: PawnNeedsComponent) -> float:
	return needs.recreation_max * social_cap_percent / 100.0

func _needs_component() -> PawnNeedsComponent:
	if _needs == null and owner_pawn != null:
		_needs = owner_pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	return _needs

func _now_hours() -> float:
	var time: TimeManager = Global.time_manager
	return float(time.cycle - 1) * float(TimeManager.HOURS_PER_CYCLE) + float(time.hour)

# --- persistence -----------------------------------------------------------------
# The ledger, the cooldown and the log. NOT the company mood modifier - that is
# derived state, re-added by the first slow_tick after the load.

func save_order() -> int:
	return 55

func save_key() -> StringName:
	return &"social"

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	var opinions: Dictionary = {}
	for pawn_id: int in _opinions:
		opinions[str(pawn_id)] = _opinions[pawn_id].to_dict()
	if not opinions.is_empty():
		data["opinions"] = opinions
	if _hours_since_chat > 0.0:
		data["hours_since_chat"] = _hours_since_chat
	if not _recent.is_empty():
		data["recent"] = _recent.duplicate(true)
	return data

func load_save_data(data: Dictionary) -> void:
	_opinions.clear()
	var opinions: Dictionary = data.get("opinions", {})
	for key: Variant in opinions:
		# pawn_ids are ints; JSON hands them back as string keys. The counter
		# they come from is monotonic and load bumps it past every restored id,
		# so a key can never come to point at a different pawn.
		_opinions[int(String(key))] = PawnOpinion.from_dict(opinions[key])
	_hours_since_chat = float(data.get("hours_since_chat", 0.0))
	_recent.clear()
	for entry: Variant in data.get("recent", []):
		if entry is Dictionary:
			_recent.append(_chat_from_dict(entry as Dictionary))

## One logged chat, re-typed after the JSON round trip (WI-68 F10).
##
## JSON has a single number type, so every int in the log came back a float and
## went out again as one on the next save. Harmless while nothing keys on these,
## but `with` is a pawn_id, and the first lookup keyed on it would miss - 6.0 and
## 6 are different Dictionary keys.
static func _chat_from_dict(entry: Dictionary) -> Dictionary:
	return {
		"with": int(entry.get("with", 0)),
		"name": str(entry.get("name", "")),
		"positive": bool(entry.get("positive", false)),
		"delta": float(entry.get("delta", 0.0)),
		"cycle": int(entry.get("cycle", 0)),
		"hour": int(entry.get("hour", 0)),
	}
