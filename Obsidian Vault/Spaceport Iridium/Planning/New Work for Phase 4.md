Goal: Add detail to the world and show it to the player. Expanding on existing systems, better UI.

**Pawn Interactions:** (Already written up, WI-48)
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

**Audio:**
- Goal: Add sounds for feedback and immersion
- Create a system to easily play sounds at positions
- New sounds:
	- On module placement (can be unique per module type)
	- When a module is clicked on (again unique per module)
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

**Starting Flow:**
- Select 2 pawns from a pool of candidates to start with (instead of starting completely randomly)
	- Each candidate in the pool has their Name, Traits, and Skills displayed so the player can make appropriate choices
- Each pawn can be separately randomized any number of times

**Star and Planet Variations:**
- Use Deep-Fold's Pixel Planet generator to create planets and stars instead of creating sprite sheets
	- Copied to assets/external/pixel_planets
	- Original at: https://github.com/Deep-Fold/PixelPlanets
- 

**Stars, Planets and Other Stations:**
- Right now we only ever see one system, but in the future we will be travelling to different systems with different stars, planets, and optional other stations in the distance.
- The system we are in should hold some data on the star (required), planet (optional), and other bodies (like stations, optional).
	- Also ore type richness that feeds into the spawned asteroids

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

**UI Rework:**
- Merge UI panels into one larger system, and give them a unified look
- https://claude.ai/design/p/d4fdab39-dde5-4ff9-9aba-4ae13578fe3e?file=Iridium+UI+Spec.dc.html
- Also improve existing panels:
	- **Pawn Inspect Pane:**
		- Goal: Be able to see all the details of a pawn
		- "Needs" pane should also break out all the mood modifiers that go into the "happiness" calculation
		- New "Relationships" pane for describing relationships (requires relationships to be implemented first)
	- **Alerts:**
		- "High priority" alerts should require the player to click to dismiss them, so they aren't missed
			- Low priority alerts - someone is hungry, for example, can be transient
			- Critical alerts should additionally pause the game until acknowledged
		- Alerts that specifically mention a pawn or module can be clicked on to jump to that pawn or module
		- There should be a log of those high/critical priority alerts so the player can go back and see what has happened

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

