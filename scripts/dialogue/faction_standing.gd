class_name FactionStanding
extends RefCounted

## How the station stands with the powers around it (WI-62 §5).
##
## The game had no such number before this. [ContractManager]'s `reputation` is a
## count of contracts completed and [VisitorManager]'s is a 0-1 satisfaction
## float; both answer a different question, and overloading either would make one
## number mean two things - the failure this codebase keeps deleting.
##
## **What it does today:** it gates dialogue and it renders in Comms. Nothing
## else. A number with no consequence is a promise the game has not kept, so it is
## written down rather than discovered later; WI-62 §5 names the three places it
## should hook into next ([VisitorManager] arrival pacing, [RaidManager] wave
## pacing, [MarketManager] prices) and deliberately leaves them alone.
##
## Pure: no [Global], no nodes. [StoryState] owns an instance.

const MINIMUM: float = -1.0
const MAXIMUM: float = 1.0

## Where a fresh station starts with everyone: indifferent.
const NEUTRAL: float = 0.0

## Five bands, because a decimal is not a sentence. The UI never prints the
## float; it prints one of these.
enum Band {
	HOSTILE,
	COLD,
	NEUTRAL_BAND,
	WARM,
	ALLIED,
}

## The band boundaries, symmetric about zero on purpose - a station that has done
## equal harm and equal good to two factions must read the same distance from
## neutral in both directions.
const COLD_CEILING: float = -0.2
const HOSTILE_CEILING: float = -0.6
const WARM_FLOOR: float = 0.2
const ALLIED_FLOOR: float = 0.6

const BAND_NAMES: Dictionary[Band, String] = {
	Band.HOSTILE: "Hostile",
	Band.COLD: "Cold",
	Band.NEUTRAL_BAND: "Neutral",
	Band.WARM: "Warm",
	Band.ALLIED: "Allied",
}

## What each band means in play, for the tooltip. Honest about the fact that it
## is currently a record rather than a lever.
const BAND_DETAILS: Dictionary[Band, String] = {
	Band.HOSTILE: "They will not deal with you, and they remember why.",
	Band.COLD: "They have not forgotten. Doors that were open are not.",
	Band.NEUTRAL_BAND: "You are a name on a docking manifest and nothing more.",
	Band.WARM: "They will hear you out, and say so where it is overheard.",
	Band.ALLIED: "They consider the station theirs to look after.",
}

## faction id -> standing. Only shifted factions are stored; an unmentioned
## faction reads [constant NEUTRAL], so adding one needs no migration.
var _values: Dictionary[StringName, float] = {}

# --- the band ladder ------------------------------------------------------------

## Which band `value` falls in. The boundaries belong to the outer bands
## (-0.2 is COLD, +0.2 is WARM), leaving NEUTRAL as the open interval between
## them - symmetric, and it means "neutral" is something you have to actually
## still be rather than something you fall back into by rounding.
static func band_for(value: float) -> Band:
	if value <= HOSTILE_CEILING:
		return Band.HOSTILE
	if value <= COLD_CEILING:
		return Band.COLD
	if value < WARM_FLOOR:
		return Band.NEUTRAL_BAND
	if value < ALLIED_FLOOR:
		return Band.WARM
	return Band.ALLIED

static func band_name(band: Band) -> String:
	return BAND_NAMES.get(band, "Unknown")

static func band_detail(band: Band) -> String:
	return BAND_DETAILS.get(band, "")

## 0..1, for a [StatBar] fill. -1 fills nothing, +1 fills the bar.
static func fraction(value: float) -> float:
	return clampf((value - MINIMUM) / (MAXIMUM - MINIMUM), 0.0, 1.0)

# --- values ---------------------------------------------------------------------

func standing(faction_id: StringName) -> float:
	return _values.get(faction_id, NEUTRAL)

func band_of(faction_id: StringName) -> Band:
	return band_for(standing(faction_id))

## Sets an absolute value, clamped. Returns what it landed on.
func set_standing(faction_id: StringName, value: float) -> float:
	if faction_id == &"":
		push_error("FactionStanding: refusing a standing with no faction id")
		return NEUTRAL
	var clamped: float = clampf(value, MINIMUM, MAXIMUM)
	if is_equal_approx(clamped, NEUTRAL):
		_values.erase(faction_id)
	else:
		_values[faction_id] = clamped
	return clamped

## Moves a standing by `delta`, clamped. Returns the new value.
##
## Clamping here rather than in the caller is what lets a `.dialogue` file say
## `shift_standing("authority", -0.2)` four times without having to know that the
## floor exists.
func shift(faction_id: StringName, delta: float) -> float:
	return set_standing(faction_id, standing(faction_id) + delta)

## Every faction that has moved off neutral. Shared; do not mutate.
func moved_factions() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _values:
		out.append(id)
	return out

func clear() -> void:
	_values.clear()

func to_save() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in _values:
		out[String(id)] = _values[id]
	return out

## Unknown ids are kept rather than dropped, unlike [StoryFlags]. A faction is
## content that may come back with a mod, and a standing is a *relationship* -
## losing it because the definition was briefly absent would be worse than
## carrying a value nothing currently reads.
func from_save(data: Dictionary) -> void:
	_values.clear()
	for key: String in data:
		set_standing(StringName(key), float(data[key]))
