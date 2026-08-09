class_name SocialMath

## Every rule behind pawn chats (WI-48), as pure functions.
##
## Nothing here touches Global, SignalBus or the tree - SocializeComponent owns
## the state and the tunables and passes them in, this file owns the shape of
## the curves. That split is what makes the balance testable: "does a pair that
## works together drift positive?" is a question about opinion_delta() and
## positive_chance(), and it can be answered without a station.
##
## Balance numbers live on socialize_component.tscn, not here. The only
## constants in this file are the ones that define the coordinate system
## (the opinion range) or guard against a divide-by-zero.

## Opinions run -OPINION_MAX..+OPINION_MAX with 0 = indifferent. Symmetric on
## purpose: "how much they dislike you" needs the same resolution as the other
## direction, and the UI bands are mirrored.
const OPINION_MAX: float = 100.0

## A chat interval can never fall below this, however a trait multiplier is
## authored. A 0.0 multiplier would otherwise mean "chat every tick".
const MIN_CHAT_INTERVAL_HOURS: float = 0.05

## Relative pick weight for a crewmate this pawn has never spoken to. Above the
## 1.0 ceiling a known partner can reach, so new hires get talked to first.
const UNMET_PARTNER_WEIGHT: float = 4.0

## Floor on a known partner's weight - the person you just spoke to becomes
## unlikely, never impossible. Two crew alone on a station must keep talking.
const MIN_PARTNER_WEIGHT: float = 0.05

## The weights that turn a pair's state into "how likely is this to go well?".
## A class rather than eight loose parameters because every caller passes the
## whole set, and a test that only wants to vary one shouldn't restate the rest.
class ChatTuning extends RefCounted:
	## Chance before any modifier. The "people who work together usually like
	## each other" trend is entirely this number being well above 0.5.
	var base_chance: float = 0.75
	## How much the pair's existing opinion pulls the odds. Positive feedback in
	## both directions - it's what makes friendships and feuds self-sustaining.
	var opinion_weight: float = 0.35
	## How much aligned/conflicting personality traits pull the odds.
	var affinity_weight: float = 0.20
	## How much the pair's social skill moves the odds - mostly up, mildly down
	## for a pair of bores. Set to 0.0 to unhook the skill.
	var skill_weight: float = 0.10
	## Hard bounds. Neither spiral may ever latch: a feud that reaches 0% good
	## chats can never recover, and that reads as a bug rather than a grudge.
	var min_chance: float = 0.05
	var max_chance: float = 0.97

## Odds that one chat goes well. `opinion_mean` is the mean of the two
## directional opinions (a conversation is a shared event, so both parties'
## feelings set the tone); `affinity` and `skill_term` come from the helpers
## below.
static func positive_chance(opinion_mean: float, affinity: float, skill_term: float, tuning: ChatTuning) -> float:
	var chance: float = tuning.base_chance \
		+ tuning.opinion_weight * clampf(opinion_mean / OPINION_MAX, -1.0, 1.0) \
		+ tuning.affinity_weight * clampf(affinity, -1.0, 1.0) \
		+ tuning.skill_weight * clampf(skill_term, -1.0, 1.0)
	return clampf(chance, tuning.min_chance, tuning.max_chance)

## How far one chat moves this pawn's opinion of the other. Signed: positive
## chats return >= 0, negative chats <= 0.
##
## The step scales with the distance left to the extreme it's heading for, so
## opinions approach +/-OPINION_MAX and never cross it - `magnitude` is the step
## taken from neutral, and it shrinks to nothing at the far end. Note the
## asymmetry that falls out of this and is wanted: climbing out of -90 moves
## almost twice as fast as it does from neutral, so a feud is recoverable when
## the pair starts getting along, while a settled friendship stops inflating.
static func opinion_delta(current: float, positive: bool, magnitude: float) -> float:
	var target: float = OPINION_MAX if positive else -OPINION_MAX
	var span: float = (target - clampf(current, -OPINION_MAX, OPINION_MAX)) / OPINION_MAX
	return maxf(magnitude, 0.0) * span

## Happiness offset from sharing a room with people this pawn has opinions
## about. Zero across the whole neutral band, then ramping linearly to
## +/-max_offset at the extremes.
##
## The band is the point: ordinary acquaintances must not move mood at all, or
## every pawn carries a permanent nonzero company modifier and the readout
## becomes noise.
static func mood_offset(mean_opinion: float, neutral_band: float, max_offset: float) -> float:
	var magnitude: float = absf(mean_opinion)
	if magnitude <= neutral_band:
		return 0.0
	var span: float = OPINION_MAX - neutral_band
	if span <= 0.0:
		return 0.0
	var ramp: float = clampf((magnitude - neutral_band) / span, 0.0, 1.0)
	return signf(mean_opinion) * ramp * max_offset

## Game-hours this pawn waits between wanting to chat. `trait_multiplier` is the
## product of their traits' chat_interval_multiplier (Extrovert 0.5, Introvert
## 2.0), so it shortens and lengthens rather than replacing the base.
static func chat_interval(base_hours: float, trait_multiplier: float) -> float:
	return maxf(base_hours * trait_multiplier, MIN_CHAT_INTERVAL_HOURS)

## How well two pawns' personalities sit together, -1 (every shared axis
## opposed) to +1 (every shared axis aligned).
##
## An axis is a named opposition - "mood" holds Optimist +1 and Pessimist -1 -
## and the product of two polarities is positive when they agree and negative
## when they clash. Traits on axes the other pawn has no trait on contribute
## nothing: not having an opinion about something is not a disagreement.
## Averaged over the contributing axes so one shared axis reads as strongly as
## three do, rather than a pawn with more traits dominating.
static func trait_affinity(axes_a: Dictionary[StringName, float], axes_b: Dictionary[StringName, float]) -> float:
	var total: float = 0.0
	var shared: int = 0
	for axis: StringName in axes_a:
		if not axes_b.has(axis):
			continue
		var polarity_a: float = clampf(axes_a[axis], -1.0, 1.0)
		var polarity_b: float = clampf(axes_b[axis], -1.0, 1.0)
		if is_zero_approx(polarity_a) or is_zero_approx(polarity_b):
			continue
		total += polarity_a * polarity_b
		shared += 1
	if shared == 0:
		return 0.0
	return clampf(total / float(shared), -1.0, 1.0)

## The pair's social skill as a term running from `floor_term` (mean level 0 -
## a bore) through 0 at `neutral_level` (average company) to +1.0 at
## `max_level` (a genuinely good conversationalist).
##
## Deliberately two slopes, not one line: the penalty side is shallow and the
## bonus side is steep, so having no social skill is a mild drag while having a
## lot of it is worth real odds. Callers pass EFFECTIVE levels, so a disease
## dulling the social skill (WI-31) can push a pawn from average company into
## being a bore.
static func skill_term(level_a: int, level_b: int, max_level: int, neutral_level: int, floor_term: float) -> float:
	if max_level <= 0:
		return 0.0
	var mean: float = clampf((float(level_a) + float(level_b)) * 0.5, 0.0, float(max_level))
	var neutral: float = clampf(float(neutral_level), 0.0, float(max_level))
	if mean < neutral:
		# neutral > 0 here, since mean floors at 0 and can't be below 0.
		return floor_term * (neutral - mean) / neutral
	var span: float = float(max_level) - neutral
	if span <= 0.0:
		return 0.0
	return clampf((mean - neutral) / span, 0.0, 1.0)

## Relative likelihood of picking this partner for the next chat. Favours the
## unmet and the long-unspoken so a pair doesn't monopolise each other while a
## new hire stands unspoken to in the same room.
##
## `hours_since_last` is game-hours since this pair last spoke (INF is fine);
## `chats` is 0 for someone never met. Partners are back to full weight once
## `refresh_hours` have passed.
static func partner_weight(hours_since_last: float, chats: int, refresh_hours: float) -> float:
	if chats <= 0:
		return UNMET_PARTNER_WEIGHT
	if refresh_hours <= 0.0:
		return 1.0
	if hours_since_last == INF:
		return 1.0
	return clampf(hours_since_last / refresh_hours, MIN_PARTNER_WEIGHT, 1.0)

## The player-facing word for an opinion value. Bands are mirrored around zero
## and the neutral one is wide, matching the mood band's "most people are just
## colleagues" premise.
static func opinion_label(opinion: float) -> String:
	if opinion <= -60.0:
		return "Hostile"
	if opinion <= -20.0:
		return "Cold"
	if opinion < 20.0:
		return "Neutral"
	if opinion < 60.0:
		return "Friendly"
	return "Close"
