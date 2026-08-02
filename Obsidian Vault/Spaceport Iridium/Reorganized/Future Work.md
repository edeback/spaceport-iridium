
Localization Prep
- Goal: Make it easier to localize in the future
- Create a localization CSV
- Move existing text in code to using tr("")

Audio
- Goal: Add more interesting sound
- Sounds for module placement, maybe building effects, effects when alerts spawn, etc

Crew O2 Supply
- Goal: Make crew not linger in space
- Crew have O2 supply that depletes in space with time, must return to station to refill or take suffocation damage

- **Turbolift Dispatch strategy:** enum on shaft {NEAREST_IDLE (current), COLLECTIVE (elevator-standard: keep direction, serve en-route calls)} — implement COLLECTIVE only if cheap; the panel dropdown can ship with one option and a disabled second. Honest v1: cab count + floor toggles are the value; strategy is stretch.


**Science**
- Goal: Provide interesting opportunities to unlock exotic technology and learn things ahead of time
- New modules:
	- Research Lab
		- New/different tech tree involving more exotic unlocks
	- Observatory
		- Pawns can do research jobs here to advance science slowly
		- When manned, gives early warning of dangerous events like pirate attacks to give the station time to prepare

Pawn Relationships
- Goal: Give more flavor to the game, add story

Modding?

Tutorial/Onboarding

ARC relationship arc & independence; expeditions; observatory and research, foreign relations/other stations; crises framework; station warp travel; New Game+ corporations; exotic elements; tutorial (SAI); audio pass.


Atmosphere rates not directly set to module size? (so can have large modules that require little atmosphere)

**Biowaste**
- Goal: Provide another resource to manage

"Education" modules? (bonus to skills, add traits, improve productivity directly?)


1. **Solar exposure model**: current formula (free structure-connection sides / (connection_points+1)) is a neat proxy but invisible to the player when placing.
	1. Change preview sprite to use correct image?
	2. Add interesting eclipse events, solar storm that knocks out power, etc



"Skill" to enum from StringName