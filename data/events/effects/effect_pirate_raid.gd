class_name EventEffectPirateRaid
extends EventEffect

## Starts a real WI-32 pirate raid: a wave of ships flies in and strafes the
## station's exposed modules, fought off with turrets/armor/shields, paid off via
## the raid banner, or waited out. Replaces the WI-24 placeholder that just
## sprayed instant damage across a few modules - the whole fight now lives in
## RaidManager.
##
## Used as the "refuse" outcome of pirate_extortion and as the auto-effect of the
## defenses-era pirate_raid event.

## Wave size. -1 auto-scales from station value (module count + credits); a
## positive value forces a fixed strength for a scripted encounter.
@export var strength_override: float = -1.0

func apply(_event: EventData) -> void:
	if Global.raid_manager == null:
		return
	Global.raid_manager.start_raid(strength_override)

func describe() -> String:
	return "Raiders attack the station"
