class_name PawnOpinion
extends RefCounted

## One pawn's standing with one other pawn (WI-48) - the record a chat writes
## and the Social tab reads.
##
## Directional on purpose: A's record of B and B's record of A are separate
## objects with separate values. A chat's outcome (good or bad) is shared by the
## pair, but how far it moves each of them is computed from their own current
## standing, so one-sided regard is a state the system can actually reach.
##
## Its own class rather than an inner one because three systems hold these:
## SocializeComponent writes them, the Social tab renders them, and the cheats
## poke them.

## -100..+100, 0 = indifferent. See SocialMath.OPINION_MAX.
var value: float = 0.0
## How many chats this pair has had. 0 means never met, which the UI says out
## loud - "haven't spoken" and "indifferent" are different things.
var chats: int = 0
## Calendar stamp of the last chat, for the UI and for partner weighting. Stored
## as cycle+hour rather than an accumulator so it stays readable in the save
## file and needs no separate clock.
var last_cycle: int = 0
var last_hour: int = 0
var last_positive: bool = true

## Absolute game-hours of the last chat, or -INF when the pair has never spoken
## (so "hours since" comes out INF and partner weighting reads them as unmet).
func stamp_hours() -> float:
	if chats <= 0:
		return -INF
	return float(last_cycle - 1) * float(TimeManager.HOURS_PER_CYCLE) + float(last_hour)

func to_dict() -> Dictionary:
	return {
		"value": value,
		"chats": chats,
		"cycle": last_cycle,
		"hour": last_hour,
		"positive": last_positive,
	}

static func from_dict(data: Dictionary) -> PawnOpinion:
	var record := PawnOpinion.new()
	record.value = clampf(float(data.get("value", 0.0)), -SocialMath.OPINION_MAX, SocialMath.OPINION_MAX)
	record.chats = maxi(int(data.get("chats", 0)), 0)
	record.last_cycle = int(data.get("cycle", 0))
	record.last_hour = int(data.get("hour", 0))
	record.last_positive = bool(data.get("positive", true))
	return record
