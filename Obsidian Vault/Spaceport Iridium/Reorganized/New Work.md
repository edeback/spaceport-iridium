I'd like to create a new Work Item.
The goal is to create a Life Support/Oxygen System. Design:
- Implement basic oxygen and co2 diffusion system
	- Gasses moves from modules that generate it to other connected modules (never space)
	- Gasses have pressures
	- Fairly quick diffusion - we'll assume there are vents between modules without forcing the player to actually construct a ventilation system
- Two ways to restore oxygen
	- Regenerative O2 Scrubber (CO2 -> O2)
		- Removes co2 and releases an equivalent amount of O2
		- Restores breathable air but doesn't increase pressure
		- The starting module comes with a O2 scrubber to provide for the starting station
	- O2 generator (releases O2 directly)
		- Directly adds O2 to the atmosphere to increase pressure
		- Counters hull breaches, accidents
- Ways oxygen is used
	- Crew (non-robot) convert a tiny amount of O2 to CO2 in whatever module they are located
		- If o2 pressure is too low, crew starts taking damage
	- Hull breaches in modules due to combat (not implemented yet) or accidents/events release atmospheric pressure in that module very quickly
- Things not included:
	- Crew in space are assumed to have oxygen stored on them and so won't take damage due to space not having o2
		- Future goal - pawns will have supply of O2 on them which limits the time they can be in space. Not for this task though.
Please write out a Work Item similar to those already created (Goal, Design, Files to Touch, Implementation Order, Edge Cases, Verification) and place it in the Work Items folder. If there is a part of the design that is unclear or needs elaboration, come up with some options and ask me which one to use.


Spacestation Tiers
- Start at 1, up to 5
- To level up, must have an ARC inspection + pay "licensing fee"
	- ARC inspection looks for specific modules built probably?
	- And maybe certain resources shipped?
		- Could be a specific contract you pick up when you are ready for inspection?
- Each tier unlocks new buildings and upgrades (and systems)


Recurring costs:
- Crew wages
- Module upkeep
- ARC Levy/fees
- Perhaps some of this doesn't start until Tier 2?
	- Keeps the pressure from being so awful at the start


Pawn Development:
- Names (from some sort of name generator)



- **CONVEYED movement state** — position-ownership handoffs (turbolift rides; later trams/teleporter charge) become an explicit movement state instead of a suspended `await`, making rides serializable and interrupt-safe. Do it as part of the next major turbolift surgery, not standalone; until then WI-15's cab-save degradation covers save/load. Rule of thumb adopted now: awaits stay for cosmetic waits (door animations), anything that *owns a pawn's position* gets an explicit state.
- **New modules pack** — Magscoop, Hydrogen Fuel Cells, Smelter/Polymer/Electronics factories as buildables (ProcessorComponent + recipes — mostly data work), Promenade, Holodeck.
- **Observatory & science trickle** — second research currency feeding unlock trees; early-warning hook for combat events.
- **Health & disease** — DiseaseData, infection spread, Medical Bay. (Depends: WI-07 visitors.)
- **Minimap & alerts feed** — becomes necessary as stations grow past a few screens.
- **Turbolift Dispatch strategy:** enum on shaft {NEAREST_IDLE (current), COLLECTIVE (elevator-standard: keep direction, serve en-route calls)} — implement COLLECTIVE only if cheap; the panel dropdown can ship with one option and a disabled second. Honest v1: cab count + floor toggles are the value; strategy is stretch.


Combat v1:
- Goal is to set up the framework for the station getting damaged and repaired
- All modules have hit points (HP)
	- Damage should be shown via shader parameter
	- Module health becomes incorporated into efficiency  of other modules - production slows down, solar panels produce less power, etc
- Non-truss modules that hit zero HP are destroyed
	- Should already be automatically replaced by truss modules if none exist there yet
	- Truss modules become "damaged" at zero HP but aren't destroyed (so the station can't split)
- Repair Jobs
	- Pawns can repair damaged modules with time
	- No resources required as long as the module hasn't been completely destroyed
	- Hull breaches (WI-17) now become their own repair job (self-sealing over a long period retained)
- Pirate "raid"
	- Event, either can pay them off (lots of credits) or suffer damage and hull breaches across multiple random modules
	- Actual combat will come later

Combat v2:
- Goal is to create the first space battles and spacestation defenses
- Pirates now come as spaceships
	- Hit points
	- Weapons
		- To start, just "lasers" that target and damage modules
			- Can only target modules that are closest to them, no shooting through to the interior
		- Lasers have visual effects
		- Damage has visual effects
	- Fly around the station but do not collide with it
- Defenses:
	- Weapon modules
		- Have specific firing arcs
		- Use energy and/or resources to fire weapons
		- To start, just lasers - same kind of weapon as the pirates, but target pirate ships in their firing arc
	- Armor plating
		- Modules that exist just as high-HP buffers
	- Shields
		- Absorb damage that would have hit within a circular zone around the shield
		- Different sizes, can be big enough to shield very many hits
		- Have a capacitator that charges slowly with energy
			- Hits deplete the capacitator
			- Once depleted, does not provide protection until recharged
- Outcome
	- Can hail the pirates at any time to offer "surrender"
		- Pay large amount of credits
	- If pirates have taken a lot of damage, they will flee

Logistics automation
- Goal is to make it easier to move goods from module to module
-  Logistics Bay
	- Produces logistics robots that can only take hauling jobs
	- Can spend credits to build more robots (up to a max)
	- Can upgrade (faster robots, more inventory space)
- Conveyor Module
	- 1x1 module that connects to all modules around it
	- Moves resources from one connected module to another connected module
		- Player chooses which module to take from and which to give to as well as which resource is moved
			- Only appropriate storage bays are shown as options - can't take from storage that allows no exports, can't give to storage that doesn't allow imports
		- Has a buffer inventory, can only move a limited number of resources per unit time
	- Can connect to other conveyor modules for more elaborate resource movement

