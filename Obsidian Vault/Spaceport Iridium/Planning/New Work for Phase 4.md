Goal: Add detail to the world and show it to the player. Expanding on existing systems, better UI.

**Pawn Interactions:** (Already written up and complete, WI-48)
- Goal: Pawns should have meaningful interactions with each other. Give more flavor to the game, add story.
- Pawns now "chat" occasionally when they are in the same module
	- This replaces the current "passive recreation boost" when two pawns are in the same module
	- Pawns can chat if both have not chatted with anyone in the past hour, modified by traits
		- "Extrovert" trait now halves the time it takes before the pawn wants to chat again
		- "Introvert" trait now doubles the time it takes before the pawn wants to chat again
	- When pawns "chat" they should record that interaction - who it was with, and what sort of effect it had
	- As before, robots do not participate in chats
- Chats can be positive or negative
	- More likely overall to be positive, unless the pawns already dislike each other
		- Random, biased positive, but weighted based on their current opinions of each other and their traits
		- The general trend should be that people who work together usually like each other
	- A positive chat provides a recreation boost (as this is replacing the passive recreation boost)
	- A conflict in traits (optimist vs pessimist, for example) makes it more likely to have a negative chat, while aligned traits make it more likely to have a positive chats
- When pawns share a module, they get a small boost or penalty to their mood based upon if they like each other or not, with a moderate-sized "neutral" zone around zero where mood is not impacted
- New UI panel on the Pawn Inspect window
	- Lists each other crewmember and their opinion of that crewmember (no robots)

**UI Rework:** (Written up as [[Spaceport Iridium/Planning/04_UI_Rework_Program]] — nine work items, WI-49 … WI-57)
- Goal: Merge UI panels into one larger system, and give them a unified look
- This was designed in Claude Design and that project is exported at assets/external/spaceport-iridium-ui-layout
	- The implementation is in `Iridium Console UI Spec.dc.html`
	- Please read the README as well as the UI Spec in full, as it details what the final output should look like
- Note that this mockup does not necessary reflect the exact content of some of the tabs. For example, a crewmember has more tabs in its inspector than in the mockup, make sure to port all the tabs from the current game. The mockup is more of a style guide.
- Some notes and improvements:
	- **Pawn Inspect Pane:**
		- Goal: Be able to see all the details of a pawn
		- "Needs" pane should also break out all the mood modifiers that go into the "happiness" calculation
	- **Alerts:**
		- "High priority" alerts should require the player to click to dismiss them, so they aren't missed
			- Low priority alerts - someone is hungry, for example, can be transient
			- Critical alerts should additionally pause the game until acknowledged
		- Alerts that specifically mention a pawn or module can be clicked on to jump to that pawn or module
		- There should be a log of those high/critical priority alerts so the player can go back and see what has happened
	- **Crew:**
		- The "Show All Jobs" button is what displays the same content as the current "Jobs" screen, both the jobs taken by the crew as well as the ones not yet picked up.
	- **R&D:**
		- The mockup describes research points, but that is for a not-yet-designed system, continue to use credits as the resource to spend to unlock technology
	- **Comms:**
		- Instead of the Inspection event firing randomly, the "Contact ARC" button allows the player to pick when they are ready for an inspection.

**Starting Flow:** (Complete, WI-59 — [[WI-59_Starting_Flow]])
- Goal: Give some more personalization to the beginning of the game
- Select 2 pawns from a pool of candidates to start with (instead of starting completely randomly)
	- Each candidate in the pool has their Name, Traits, and Skills displayed so the player can make appropriate choices
	- Each pawn can be separately randomized any number of times
- Give the station a name
	- Name becomes default save file name
	- Name is displayed at the top of the minimap

**Heat System:** (Written up as [[WI-60_Heat_System]])
- Goal: Add heat, a new station-wide adjacency system for modules to hook into. This will give station layout more meaning, and add new module possibilities
- Modules can (optionally) produce or consume Heat
	- A Forge would produce a lot of heat.
	- An Ore Processor produces a moderate amount of heat.
	- A Radiator (new module) eliminates (consumes) heat, based on the number of free spaces around it (like how a Solar Panel produces power)
- Modules exchange heat with other modules that surround them
	- This is a decently quick process - hours, not cycles
	- Modules that have sides open to empty space also radiate a small amount of heat to space based on the amount of heat they have and how exposed to space they are. This allows them to slowly come to equilibrium instead of heating up forever
- Modules are also affected by heat
	- High temperatures will throttle the production rate of some modules
		- This also throttles the heat production of those modules - the Forge should produce heat proportional to how much is produces, and also only produce heat while working
	- Extreme (high or low) temperatures will also impact the effectiveness of some modules, like sleeping pods
- Pawns prefer habitable temperatures (40-90F to start, to give a decent amount of leeway)
	- Slightly outside the habitable range (20-39F, 91-110F) gives a mood penalty (too cold, too hot)
	- Far outside the habitable range starts to hurt the pawn
	- Droids are immune
	- Pawns in space are immune (due to being in a spacesuit)
	- Due to this, the starting module will produce some heat so the pawns don't immediately freeze
- An overlay showing the current heat values of modules is needed

**Comets:** (Written up as [[WI-61_Comets]])
- Goal: Add comets, a new type of asteroid with different movement patterns and different resources
- Instead of being in a specific zone, like asteroids, a comet spawns a ways external from the station (in any direction), moves across the play area (it can go "behind" the station), and despawns some ways away on the other side
- Comets spawn more occasionally than asteroids - there should be 0-2 spawned at any one time
- Comets have a different spread of resources than asteroids. They contain:
	- Ice (always, a lot)
	- Carbon (always, a moderate amount)
	- Silicon Ore (sometimes, a little)
- Otherwise, comets work very similarly to asteroids
	- You can click on them to view their resources
	- They can be prioritized
	- Mining drones will mine them and return their resources to the station
	- When their resources are exhausted, they disintegrate
- Uses assets/external/blue_comet.png as the graphic
	- The "forward" position is at the bottom-left
	- The comet should always be pointing in the direction of motion
	- They don't rotate, unlike asteroids

**Audio:**
- Goal: Add sounds for feedback and immersion
- Create a system to easily play sounds at positions
	- Use `AudioStreamPlayer2D`
- New sounds:
	- On module placement (can be unique per module type)
	- When a module is clicked on (again can have unique override per module)
	- When an alert is triggered
	- When the trader arrives
	- Combat sounds (firing and when a target is hit)


**Dialogue:**
- Dialogue Manager
	- Documentation in https://github.com/nathanhoad/godot_dialogue_manager/blob/main/README.md
- Events change to using this to display choices.
- Events gain images to display, or portraits of whoever the player is talking to
	- Such as a pirate or trader

**Tutorial/Onboarding:**
- Automatically triggered when a game starts
	- Option when creating a game to "Skip Onboarding"
- Needs dialogue work implemented first



**Star and Planet Variations:**
- Use Deep-Fold's Pixel Planet generator to create planets and stars instead of creating sprite sheets
	- Copied to assets/external/pixel_planets
	- Original at: https://github.com/Deep-Fold/PixelPlanets
- 

**Stars, Planets and Other Stations:**
- Right now we only ever see one system, but in the future we will be travelling to different systems with different stars, planets, and optional other stations in the distance.
- The system we are in should hold some data on the star (required), planet (optional), and other bodies (like stations, optional).
	- Also ore type richness that feeds into the spawned asteroids
	- Space temperature - hotter/colder solar systems, based on the local star, will require different station setups

**New Combat Options**:
- Pirates have new options for ships, difficulty level of pirate fleet increases as the station grows larger/richer
	- 
- Xenobeasts, different types of ships
- Invasions
	- Pirates take over an empty docking bay (and prevent traders from arriving while there) and attack pawns inside
	- New internal defenses
		- Security door upgrade to hallway?
		- Security droids
		- Pawns get weapons
- Able to "call in support" from ARC
	- ARC sends in a few ships, scaling with attack difficulty
	- No cost now, but ARC will demand "reimbursement for costs" later
	- Should be enough to fend off the attack, though still with some station damage
		- Mainly an option if you don't have the funds or defenses at the moment
		- Should be less direct cost than paying them off, though you'd still have to deal with any damage they inflict before they are driven off


**Pawn Relationships:**
- Goal: Pawns should form relationships with each other, a stronger form of interactions


**Pawn Death:**
- When health goes to zero, the pawn should die
- Pawns nearby (in the same module) as well as pawns with relationships should get a heavy mood penalty for a long time
- Pawn must be disposed of
	- Ejected? Incinerated?
- Pawn can be memorialized to lesson mood penalty
	- Module of "Memorial to XX"
		- Or maybe a general "Memorial" building that unlocks after the first pawn dies
		- Then each death can be recorded there?
	- Memorials are also a small recreation location

**More Events:**
- More!

