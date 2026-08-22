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

**Comets:** (Complete, WI-61 — [[WI-61_Comets]])
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

**Dialogue:** (Complete, WI-62 — [[WI-62_Dialogue]])
- Goal: Add more flavor and immersiveness to the game by allowing the player to interact with actual characters instead of just text boxes.
	- This also sets up the ability to have a character ("SAI") to interact with for the tutorial/onboarding
- Instead of interacting with passive descriptive text boxes (as in the current Event system), the player should interact with characters (when appropriate), such as a Pirate Captain when pirates attack, or a Trader when a trade contract is offered.
- I've added and enabled the Dialogue Manager addon
	- Documentation in https://github.com/nathanhoad/godot_dialogue_manager/blob/main/README.md
	- Note that this is the newest Dialogue Manager, released only a few days ago, and so has some changes compared to older versions, so previous examples may not be completely accurate
	- balloon.gd and balloon.tscn is the in-project starter dialogue balloon, copied mostly from the example but changed to fit this game's style
	- Dialogue can call functions and set variables, so much of the current event structure should be usable
- Events change to using this to display choices.
- Events gain images to display, or portraits of whoever the player is talking to
	- Such as a pirate or trader
	- An image can be required but random - if so, the image should be stable over several lines of conversation
	- Initial portraits for characters are in assets/external/thirstsector_portraits
- Events can now be written in .dialogue files
- This also leads to chaining events, where the choices in one can affect the choices and outcomes in a future event
- Example chaining event:
	- **Damaged Ship Needs Help**
		- A damaged ship is coming in at high burn from the outer system. They request docking permission but don't have time to give more information.
			- Prerequisite: Docking bay exists and is free
			- Permission granted. Possible results:
				- Ship arrives and thanks you. They were a trader, and offload some random resources as payment.
				- Ship arrives and gives a credit reward. However, they were being chased by pirates (triggers a pirate attack)
				- Ship arrives, was being chased by local authorities. They demand you turn the captain over for a bounty. Captain responds that he'll double it to ignore them.
					- Turn him in: positive reputation with local faction, small credit bounty
					- Feign ignorance: negative reputation with local faction, large hush money payment
			- Permission denied. Possible results:
				- Ship alters course toward an inner planet. Minor rep hit with local faction.
				- Ship attempts to alter course, engines explode. Minor damage to the station and scrap scattered around the station
				- Pirates are seen disabling the engines and boarding the ship. Major rep hit with local faction.
				- Local authorities are seen disabling the engines and boarding the ship. You receive a message indicating they captured a fugitive. No effect.

**Tutorial/Onboarding:** (Written up as [[WI-63_Tutorial]] — the brief below is its input. SAI already exists as a `SpeakerData` with a real portrait and nothing to say, and `StoryFlags.DECLARED` already carries the `sai_introduced` flag WI-62 left for this item to set. The design's load-bearing call is a third dialogue alias, `guide`, whose verbs can *block* a conversation until the player acts — plus a coach mark, the first surface in the console UI that can point at a piece of the interface, which is what finally turns AIDE on.)
- Goal: Give the player a way to learn how to play the game.
- Currently, the game has a pile of systems that the player has to manage, but the information on how to actually use those systems successfully is scant. There are certain things a player must do at the start to keep everyone alive and happy, but it is not obvious without a lot of trial and error, at which point you have probably already lost.
- Automatically triggered when a game starts
	- Option when creating a game to "Skip Onboarding"
- First introduces you to SAI, the Subprocess AI that has been charged with helping to inform you how to properly run the station.
	- The game is paused at this point and cannot be unpaused until after the tutorial is completed, so you don't accidentally starve your crew while reading dialogue
	- SAI explains that you have been charged with building a profitable spacestation by your parent company, the Astral Resource Corporation (ARC). A small core of a station has been towed here, but it's now up to you to develop and expand it while keeping your human resources safe.
	- Your crew needs food, oxygen, a bed to sleep in and ways to relax, but it's up to you to build them. All modules also require power to run.
	- You've been authorized to build a limited set of modules. Once you have proven that the station is established (by building some modules and shipping goods), ARC will authorize additional modules that can be constructed.
- Then SAI directs you to your first task, adding a Mess Hall to the station.
	- Highlight the "Build" option, tell the player they need to click it, and wait for it to be opened
	- Highlight the "Crew" option, tell the player they need to click it, and wait for it to be opened
	- Highlight the "Mess Hall" option, tell the player they need to click it, and wait for that
	- Tell the player to place the Mess Hall adjacent to one of the sides of the station and click for it to be placed, wait for it to be placed
	- Note that most modules need to be constructed by the crew out of materials, including the Mess Hall, and that the crew will automatically construct it
	- Note that the modules in Core are prefabricated and are placed instantly. Mention that the crew will need to get to the Mess Hall after it is built, so they will need stairs or a corridor or both to get to its door
	- All other placements are up to the player, but it should be a priority to build all the essentials
	- After that is closed, the game unpauses
- The rest of the SAI instructions happen when specifically triggered. They are mostly just informative, bringing up a dialogue box but not forcing any specific tasks
- Help text is only triggered once for each kind of trigger:
	- A module has no path to station
		- SAI appears and the module is highlighted. SAI mentions that crew will not be able to get to this module until it is connected to the rest of the station by corridors and/or stairs. They are located in Build -> Core.
	- A module has no power
		- SAI appears and the module is highlighted. SAI mentions that a module will not work without power. Solar Panels are available in Build -> Power. They work most effectively when they are maximally exposed to sunlight, so don't build modules directly around them, including other solar panels.
	- A trader arrives
		-  SAI appears and the Trade button is highlighted. SAI notes that you can buy and sell resources from traders, which can be very important before all your industrial chains are set up. It's also important to ship enough iron ore to make ARC happy with your progress. Make sure you place your order early to ensure it gets fulfilled before the trader leaves - you can also set up trade orders early, before the trader arrives, so that they're ready to go as soon as one gets there.
	- A comet appears
		- SAI appears and notes that comets are important sources of ice and carbon, but aren't around very long, so take advantage of them while they last.
	- A crewmember is unhappy enough to leave
		- SAI appears and the specific crewmember is highlighted. SAI mentions that unhappy crew will leave the station after a short while, so make sure their needs are met. If everyone leaves and you can't afford a new hire, ARC will confiscate the station (and you lose).
	- A crewmember has critically low recreation
		- SAI appears and the specific crewmember is highlighted. SAI mentions that crew need to be able to relax - the mess hall is one place, make sure it is easily accessible. Placing other modules that are more effective recreation sources can help even more.
	- A crewmember has critically low sleep
		- SAI appears and the specific crewmember is highlighted. SAI mentions that crew need to be able to sleep, which means that they both need a bed available and a way to get to that bed. The number of crew vs available beds is located in the bottom console, make sure there are always enough beds for everyone.
	- A crewmember has critically low hunger
		- SAI appears and the specific crewmember is highlighted. SAI mentions that crew need to be able to eat - if they starve, they also become hurt and may eventually die. Make sure that there is a mess hall available with a way to get there, and that there is food available to be consumed there. If there is not enough, buy more from a trader or grow some.

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

