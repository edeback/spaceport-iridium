
**Combat setup work:**
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
- Breakdowns
	- Modules should have a small chance of having a breakdown
	- Directly damage the module or apply a modifier (minus efficiency for example) until a pawn completes a repair job
- Pirate "raid"
	- Event, either can pay them off (lots of credits) or suffer damage and hull breaches across multiple random modules
	- Actual combat will come later

**Combat:**
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

**Logistics automation**
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

**Pawn Identity**
- Goal is to give pawns real variance and make them interesting
- Names
	- Pawns are given a generated name on start
	- Plan on using the m12 Name Generator (https://github.com/monk125/m12-name-generator) but may roll our own
	- v1 - all pawns use same generated style. Future: different factions of pawns will generate names specific to their faction (requires factions)
- Sprite differences
	- v1 - use modulate color to tint each pawn differently
	- Future - use different sprites (requires a lot of asset work)
- Skills
	- Pawns should be better (or worse) at certain things
	- Skill types:
		- Accuracy (with ranged weapons and when manning weapon modules)
		- Skirmishing (melee fighting)
		- Construction (speed at constructing/deconstructing buildings and repairing modules)
		- Mining
		- Growing
		- Crafting (may split this into multiple more-specific skills)
		- Medical
		- Social
		- Intellectual
		- Leadership
	- When a pawn does a job associated with a skill type, it should affect the quality/efficiency of the job done
	- After completing a job, the pawn should gain a tiny amount of experience in the skill associated with that job
- Traits
	- Bonuses / maluses / cosmetic / flavor changes for a pawn
	- Examples:
		- Introvert (no bonus from passive socializing - gains passive recreation bonus when alone in a module)
		- Extrovert (double bonus from passive socializing and higher cap on recreation game from such)
		- Conceited (extra penalties when using low-quality versions of modules, depends on tiers of modules being implemented)
		- Optimist (constant flat buff to happiness)
		- Pessimist (constant flat negative to happiness)
		- Spacer (bonus to happiness when in space)
		- Hardy (takes less damage from all sources)
		- Weak (takes more damage from all sources)
- When you want to hire a pawn, you are given a selection of pawns to choose from
	- You are shown name, skills, traits
	- Hire price is modified by skills and traits - high skills and good traits cost more, low skills and negative traits reduce the price

**Work Improvements**
- Goal: Pawns should feel like they have specific roles and jobs to do
- Pawns should be able to be assigned to certain workspaces
	- Jobs for those workspaces will only be done by those pawns
	- Pawns with assigned workspaces should prioritize jobs given by those workspaces
- Processor components should require pawns to do work for them to complete
	- Instead of simply waiting X seconds, the pawn will have to work there for X seconds
	- Job efficiency should be modified by pawn skills
- Modules which have jobs should have workstations authored (anchors assigned in those modules)
	- Anchors should be expanded to include a specific animation to be played at that spot (interact, interact_back, interact_sit, lay_down, etc)

**Health and Disease**
- Goal: Expand on crew health interactions
- New buildings to improve health
	- Medical Bay - crew can come here to heal health stat and treat disease
		- Doctoring job - pawn needed to ensure treatment goes well
	- Air purifiers - passively reduce the chance infections can spread within a large area
- Each disease has different effects
	- Most slowly drain health over time until treated
	- Many give temporary negatives to skills
	- As a disease progresses without treatment, these effects get worse
- Acquiring disease
	- Visitors may arrive with infectious diseases (requires visitors implemented)
	- Events may cause an outbreak
	- Pawns (non-robotic) sharing the same cell have a chance to transmit disease depending on contagious rate
	- Some diseases are not infectious but are acquired by other ways, like spending too much time in space

**Minimap**
- Goal: All the player to quickly jump to sections of the map
- Simplified overview, not just a smaller version of the main map
	- Square panel in the upper-right corner
	- Silhouette/shapes and colors
		- Modules are squares, asteroids are dots, ships are triangles
- Can click on the minimap to jump to that section of the world


**Movement and Animation update**
- Goal: Make movement interrupt-safe. Align animations with current TimeManager sim (currently they run on engine timescale which does not change).
- **CONVEYED movement state** — position-ownership handoffs (turbolift rides; later trams/teleporter charge) become an explicit movement state instead of a suspended `await`, making rides serializable and interrupt-safe.
	- Ideally nothing in movement requires awaits, even cosmetic ones (like opening doors)
- Sync animation timescales with TimeManager so that a faster game speed means faster animations
	- This is especially noticeable with doors, which currently slow down movement much more (relatively) on high speeds


**Job serialization**
- Goal: A player can save and re-load the game without pawns losing their jobs
- This will require some other parts of the game that aren't currently serialized to be serialized, in particular asteroids

**Economic sinks**
- Goal: Recurring costs force the player to keep making money, which forces them to interact with the rest of the game's systems
- New costs:
	- Crew wages
		- Based on what they would cost to hire - better crewmembers cost more to keep on
		- Crew should have a "fire" option to force them to leave the station (if you don't want to keep paying them)
	- Module upkeep
		- Definable on a per-module basis
	- ARC Levy/fees
		- ARC takes a % of all income earned
		- ARC takes an extra fee every X cycles
- Allow these costs to be turned on or off
	- Game starts with these costs turned off until after the first ARC inspection
	- ARC Levy may be turned off late game (if you separate from ARC)
- Economy info page UI
	- See how much everything is costing you
		- Breaks down each category
- Bankruptcy
	- Can ask for a loan from ARC, repayable in X cycles at 20% interest
	- After an extended period of time with negative credits, game over
		- Warned a few cycles ahead of time that ARC will repossess the station if balance is not returned at least to zero

**Spacestation Tier Levels**
- Goal: Give the game a sense of pacing, slowly unlocking more systems and features to not overwhelm the player to start
- Start at 1, up to 5
- To level up, must have an ARC inspection and meet export goals
	- Export goals
		- A defined set of resources that need to be exported
		- Tracked like a contract except not handled like a contract - just counts goods normally exported, does not take any goods itself
	- ARC inspection
		- After export goals are met, random chance to get an event asking if they are ready for an ARC inspection. This can be denied without penalty, though it means they won't get a chance to get to the next tier until another inspection event fires.
		- ARC ship docks, inspector pawn arrives and paths to several different modules (defined by tier) to ensure everything is in proper order. Must be kept safe. If the inspector is harmed (low oxygen levels), ejected into space (module they're in deconstructed), or cannot path to all requested modules, inspection fails
- Each tier unlocks new buildings and upgrades (and systems)

**Module Adjacency Effects**
- Goal: Make layout of modules matter
- Crew recreation and sleeping facilities should have their effects be penalized by being too close to industrial equipment (due to vibration)
	- Connection-based (since vibration doesn't go through space, can't just use distance in case there is empty space between)
	- Each source defines distance and intensity of negative effects, receivers determine how that translates to penalty (less rest in a sleeping pod, less entertainment in the holodeck, for example)
- Facilities can also be enhanced by nearby other modules
	- Air purifiers reduce disease chance in nearby modules
	- A garden room could increase the desirability of nearby sleeping modules
	- Maintenance Facility could reduce the breakdown chance of nearby industrial modules

**Visitors, Tourists, Shops and Hotels**
- Goal: New sources of revenue
- Stores - places where crew members and visitors can spend money
	- Crew members get paid (if Economic Sinks task is complete) and one place they can spend money is shops
	- General "shop"-type module that can be customized
		- Example options: General Store, Computer Store, Combat Store, Music Shop, Leisure Store, Curiosity Shop
		- They work similarly but have different graphics/prices/benefits to shoppers (usually entertainment)
- Hotel rooms - places where visitors can sleep
	- Crew members stay in crew-specific quarters, visitors can't sleep in them, they must stay in hotel rooms
	- Hotel rooms have different qualities, effectiveness, and cost
- Visitors/Tourists - pawns who visit the station from outside without the intention of staying to work
	- Visitors arrive via ship or teleporter (if one is installed)
	- Visitors come with a certain amount of currency to spend
	- Take advantage of stores and entertainment facilities
	- When they run out of money or happiness they leave
	- If they were happy when they left, more visitors will come
	- If they were unhappy when they left, fewer visitors will come

**Food Quality**
- Goal: Make what the crew eats matter
- New resource: "Food", with quality levels
	- Ideally an optional description should be added so the food can be tagged as a certain type (meat, vegetables, slime, etc)
- Different modules produce food of different quality level
	- Quality level is also determined by the worker used in making the food
	- Hydroponics bay makes better food than an algae tank but worse than a greenhouse, for example
- Eating modules then provide different benefits based upon the food quality provided
	- Higher quality food offers more nourishment
	- High/low quality food may provide a good/bad mood modifier

**Robotic Needs**
- Goal: Make robots more than just free workers
- Robots use energy while they move and do work
	- When energy is low, robots seek out a recharger (either their home module or an independent recharge module) and do a "recharge job" to fill energy back up
	- Robots that reach zero energy move extra slow ("emergency backup power") and can only move to rechargers
- Robots get a health stat
	- Measures the integrity of the robot
	- Lowered mainly through combat damage or "accidents"/malfunctions
	- Does not automatically heal
	- Must go back to a Repair Bay to be repaired
	- If health goes to zero, robot is destroyed

**Main UI Flow**
- Goal: Implement the basic UI flow that someone would expect when starting a game
- Main Menu
	- Where the game starts
	- New Game, Load Saved Game (if one is available), Settings, Quit
- New Game
	- Sets difficulty (if implemented, otherwise goes directly into game)
- Settings
	- Keybind remap, resolution, audio volume for music/effects
- Pause Menu
	- New Game, Save Game, Load Game, Settings, Quit

**Difficulty Levels**
- Goal: Make the game harder/easier for players
- Peaceful
	- No pirate attacks
	- Low upkeep costs
	- Flat mood bonuses
- Easy
	- Low upkeep costs
	- Small flat mood bonus
- Normal
	- No changes
- Hard
	- Higher upkeep costs
	- Small flat mood penalty

**Testing and Tooling**
- Goal: Make it easier to test and debug the game
- Adopt GUT for unit testing
	- Can test pure-logic classes: `ModuleGraph`, `StorageData`, `StatModifiers`, `MarketManager` pricing, `LocalUpgradeData` cost scaling, and now contract/event resolution rules.
- Add a cheat console
	- Spawn resource (type, amount, location)
	- Spawn pawn (location)
	- Force unlock
	- plus all other debug hooks already in place (quick save/load, `debug_fire_event`, `debug_offer_contract`)

**UI Overlays**
- Goal: Provide clarity to certain systems
- When enabled, provides a clear read of:
- O2
	- Green-Red based on O2 pressure
- Power
	- Green if powered, red if not (and requires power)
- Structural Integrity
	- Green if full HP, red if low HP
- Vibration
	- Red if high vibration levels, clear if none
- Logistics
	- Show storage priorities and current flows between modules

**Game Start Manager Cleanup**
- Goal: Remove the need to have a magic 1-second wait before spawning initial modules
- Replace with explicit bootstrap ordering of managers so it is not necessary