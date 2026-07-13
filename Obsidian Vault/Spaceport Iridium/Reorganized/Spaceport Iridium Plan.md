Hi Claude! I am building a 2d videogame in Godot 4 using GDScript called "Spaceport Iridium." It is a cross between SimTower, as you are building a tower (except in space) one room (which I call a module) at a time, and Dwarf Fortress or Rimworld, as you have to manage your population, fulfill their needs, and keep them happy. The view is a 2d vertical cross-section similar to SimTower, where you view the spacestation modules from the side. Station residents need to be able to move from module to module (in order to transfer items and resources or to go to workspaces or sleeping areas) as well as from inside the station to outside (in order to mine the asteroids or construct new modules).

Story
It is the future. Iridium is a valuable element used in space travel that is rare on earth and has become high in demand. The Astral Resource Corporation has identified a number of promising locations to begin mining. A small team has been sent to establish a spaceport here to begin mining operations. You are the onboard AI tasked with management and planning of the station. The company is entrusting you with the goal of future profits. You have been assigned a sub-AI, SAI, to assist with advice or other needs. ("SAI, what do I do?!") To start you have been given a very limited amount of resources and few build options (as ARC has not paid for anything beyond the basics). As you earn income, you can spend that money to expand your options, but also increases the chances that you encounter threats, like pirates who demand "protection" payments. ARC maintains some distant overlordship and will occasionally send inspectors or demand payments, generally a portion of profits, but will also send help in great need (usually at some future cost). (You can eventually demand to be made a "spin-off" independent company, or demand to purchase your independence... or fight for it. All much later-game though.) Breaking free of ARC allows more freedom to travel to new systems as well as reduces "taxes" that you had to pay, but you are less protected as a result (ARC will not send defenders - ARC Asset Integrity Service - if you are raided). (Could maybe even join a different corporation for different bonuses!? Maybe that is New Game+, where you start with a different parent corporation and therefore start with different techs unlocked, different corporate bonuses. Perhaps unlocked by maxing out that corporation's tech tree in the basic game.) There is no defined end-game, it is more of a sandbox game like Dwarf Fortress than something with a defined goal.

## Station Structure
- Modules are built in a 2d non-limited grid. Each module can take up one or more contiguous grid spaces.
- There are four "layers" to the world. Each grid cell has all of these available.
	- Module
		- This is where all the main modules are placed, where pawns work and live
		- There is an implicit "truss" structure layer behind this, visually shown via a tilemap but without actual module placement - unless there is a truss and no module, in which case a "truss" default module is placed. This represents the superstructure holding the station together.
			- I am considering whether to make the truss layer a "real" layer behind the Module layer or whether it is visual clutter and remove it completely
	- Turbolift
		- This is where modules for vertical movement are placed, currently stairs and turbolifts
	- Corridor
		- This is where modules for horizontal movement are placed, currently hallways and airlocks
		- Vertical and horizontal movement are separated so a cell can have, for example, both a hallway and a stairway at the same time
	- Space
		- No modules are placed on this layer, but other objects (asteroids, space trash, other ships) and pawns in space (that have left an airlock to go mine an asteroid, for instance) live here, not aligned specifically to the 2d grid
- Modules can be connected to each other within a layer (hallways, for example) or across layers via a "door" (from a module into a hallway, or a hallway to a turbolift, for example)
	- Controlled by the PathComponent
- Some basic modules are instantly built (hallways, stairways, airlocks, etc) while more complicated ones are built by hand
	- A module starts in a "construction" state with most functionality disabled.
	- It requires resources to be delivered before building can proceed.
	- Pawns then perform work over time to finish it.
	- While in placement mode, blocked/invalid cells should be shown, per layer (module vs. transport vs. whichever layer is active).
	- Flipping a module during placement should re-validate placement rather than trusting the old check.



## Resources
- Various resources are used throughout the game. These are important for trade and are the main reason you are out here in the first place
- Most resources are all identical, but some have individual variance
	-  Mainly useful for **ore** — capturing the specific elemental breakdown of a batch (e.g. "10% metals, 15% carbon, 20% silicates, 3% precious metals, 1% iridium, 30% water") — and for **food quality** levels.
- Two are special and non-tangible:
	- Credits
		- Universal currency accepted by all traders. Some buildings have a credit cost on top of other resource costs. Also used for "research" (buying tech dataprints).
	- Energy
		- Not actually a physical resource but often grouped with them. Produced and used by modules to keep them running.
- Basic resources:
	- Ore
		- Ore is mined from asteroids and contains a number of different resources that are only available once it is processed
	- Ice
		- Mined from comets, contains a different set of resources than ore - mostly water
	- Iron
		- Obtained from processed ore, only useful when processed into Steel
	- Carbon
		- Obtained from processed ore and in small amounts from comets, used in Steel and Polymer production
	- Gold
		- Obtained from processed ore, can be sold or used in some modules
	- Iridium
		- Obtained from processed ore, highly valuable and used in many advanced modules
	- Silicon
		- Obtained from processed ore, used in Electronics
	- Water
		- Obtained from processed ice, used many places
	- Hydrogen
		- Obtained from the solar wind or through splitting water, useful as fusion fuel
	- Oxygen
		- Obtained from the solar wind or through splitting water, essential for life
	- Exotic Elements
		- Obtained from ???, used in high level/exotic modules
		- Needs more thought
		- Possibly "island of stability" elements if we want to go realistic
- Secondary resources:
	- Steel
		- Made from iron and carbon, used in most modules
	- Polymers
		- Made from carbon, used in many things
	- Electronics
		- Made from silicon and gold, used in many advanced things
	- Biomass
		- Created from carbon and water, can be used as food
	- Food
		- Grown in facilities from carbon and water, required for life
- Buildings for resource gathering
	- **Drone Bay** — houses mining drones; has generous storage for ore/ice/gas.
		- **Mining Drone** — leaves the station, mines an asteroid/comet/gas cloud, returns with resources. Can be told to prioritize a resource type, can specialize in ore/ice/gas, and can be upgraded (faster mining, more efficient mining, more cargo space).
		- **Large Mining Drone** — requires a Large Drone Bay; strictly better than the standard drone.
	- **Station Magscoop** — a module attached directly to the station; very slowly gathers gas ions (mostly hydrogen) from solar wind; upgradeable, but generally stays fairly inefficient.
	- **Matter Synthesis** — direct energy-to-matter conversion; extremely inefficient (should be a net loss if used to make hydrogen just to feed back into a fusion reactor).
	- Floating salvage objects in space, with their own inventory, for recovering scrap/deconstruction materials.
- Buildings for resource production
	- Ore refinery
		- Turns ore from asteroids into base resources
	- Ice refinery
		- Turns ice from comets into base resources
	- Smelter
		- Iron + carbon = steel
	- Electrolyzer
		- Water = Oxygen + Hydrogen
	- Poylmer factory
		- Carbon -> polymers
	- Electronics factory
		- Silicon + gold -> electronics
	- (Or perhaps a generic Factory building that could do those plus other conversion?)
- Buildings for specifically food production
	- All require carbon and water in some proportion
	- Algae Vats
		- Low quality
	- Hydroponics Bay
		- Higher quality, specific foods
	- Greenhouse
		- Large, also used for recreation
- Buildings for energy production
	- **Solar Panel** — no fuel required; output depends on sunlight incidence; station starts with two.
	- **Fusion Reactor** — requires hydrogen fuel.
	- **Hydrogen Fuel Cells** — hydrogen + oxygen → energy + water; much less efficient than fusion.
	- Speculative / later-game ideas:
		- Fission (would require adding uranium/plutonium as a resource)
		- Radioisotope Power (similar, but possibly self-contained/no outside refueling needed)
		- Bioelectrics
		- Solar wind
		- Zero-point / vacuum energy / quantum foam
		- Neutrinos
		- Antimatter
		- Dark matter
- Buildings for resource movement
	- **Logistics Bay** — houses Roomba-style robots that only do hauling tasks.
	- **Conveyor Belt module** — sits between two (or more) buildings and automatically pushes goods from one to the other, no manual labor needed.
		  - Could auto-configure based on what's adjacent (per-resource, checking each output storage) — those resources would then stop generating hauling jobs, or have their jobs suspended while the belt runs and re-enabled if the destination fills up.
		  - Individual transfers should be suspendable if the player doesn't want that pairing running.
		  - Transfer could be automatic-only, or have an explicit UI showing what's currently being moved.
	- **Pipes/tubes** — for connecting modules, likely on their own layer. Definitely makes sense for liquids; unclear if it's worth it for solid goods too.
	- Storage priority as a routing tool: an "export" storage bin could have a permanent, very large negative priority, and an "import" bin a permanent large positive priority — though import priority probably needs finer-grained tuning so the player can, say, prioritize getting hydrogen to the reactor specifically.

Other ways of getting resources: buying and selling them from others:
- **Open Market** — buy/sell from traders. A buy/sell screen showing prices — maybe only available while a trader is present, or maybe always visible but only fulfilled when a trader actually arrives. Resources need market prices attached.
- **Contracts** — offer a bonus/higher price for shipping a specific quantity of a resource by a deadline.
- **Events** change market supply, which in turn moves prices.
- **Other stations** in the system can be bought from too, functioning similarly to traders — either as passing traders or as fixed trading stations.

## Pawns
- Pawns are the individuals who do tasks on the station. They include things like robot drones as well as organic crewmembers.
- Pawns exist at a location and can move from place to place.
- Can hold item(s) — likely wants a carrying capacity, which implies items eventually needing weight/encumbrance values.
- Modules will need max-occupancy numbers.
- Movement
	- Pawns can move from place to place by walking through modules. Most movement is done in the Turbolift and Corridor layers - pawns generally can't go directly from one main module to another. They can also go into space, generally via an airlock, which is more free-form.
	- Movement-related modules:
		- **Hallway** — habitable, walkable space; low maintenance cost; embedded in/on every module by default.
		- **Promenade** — a double-level hallway; lets pawns move between floors without needing tubes/lifts. Doubles as the main public social thoroughfare
		- **Stairs** — high movement penalty, low maintenance cost.
		- **Turbolift** — faster travel between floors vertically, a single shaft can have multiple cars ("turbocars") in it.
		- **Teleporter** — instant point-to-point travel; very high energy requirement; its own module rather than part of the transport layer.
- Pawns do most of the work in the station
	- Modules that need something post a notice to a shared job board with a priority — e.g. a processor missing an input posts with priority scaled to how empty its storage is.
	- A module can post more than one notice at once so it doesn't fill up painfully slowly, though it may be worth waiting until the first notice is claimed before posting more, so the board doesn't get spammed.
	- Idea for replacing flat priority with a **utility function** combining distance, pawn wants/needs, and time since the job was posted — then pawns just pick the highest-utility job available. Caveat: this could be expensive to evaluate every frame if not careful (see **05 – Engineering** for the implementation-level version of this concern).
	- Job categories that represent finishing something already in progress (e.g. completing a building under construction) should get a priority boost over starting something new.
- Pawns work in shifts
	- Default to two shifts per day covering full-time station operation.
	- Some number of "hours" (24, or possibly fewer — full 24-hour granularity may not be necessary) to schedule against; default split is roughly 12 hours working, 12 hours off (sleep, eat, etc.).
	- Pawns can be given a default job assignment: if that workspace is running (powered, has input materials, etc.) they'll work there, and otherwise fall back to picking up whatever's available.
	- "Flex" assignments also possible — a pawn with no specific default just picks up any available job (or a more general assignment like "hauling").
- Pawns have needs
	- Health
		- The physical well-being or integrity of the pawn
		- External pawns (arriving from ships, etc.) can bring sickness onto the station.
			- Illness spreads to nearby pawns based on an infectiousness value, tracked via a `DiseaseData` resource.
			- Treated by a Medical Bay module.
	- Nourishment
		- How much food a pawn has eaten
		- Served by modules such as:
			- Dining Hall
			- Restaurants
			- Bars (also provide some Recreation)
	- Sleep
		- How much rest a pawn has gotten
		- Served by modules such as:
			- Sleeping Quarters
			- Hotel Rooms
			- Luxury Spas (which also provide Recreation)
	- Recreation
		- How much fun a pawn has had
		- Served by modules such as
			- Holodeck
			- Shops
	- Happiness
		- Derived value based on all other needs but can have flat modifiers directly
			-  Can also be directly affected by specific situational modifiers — e.g. a penalty for "doing menial work" when a pawn could be doing something more advanced, or a boost from "feeling great" via mood-enhancing additives in food.
			- Open item: ambient environmental effects like noise/vibration from processing units may need to factor into happiness (or health) as well.

## Progression

- Progression is intended to lean mostly on purchasable **licensing rights** rather than a classic tech tree — e.g. buying access from an org like "NeoNeutrino Labs." These unlock new modules and upgrades to existing ones (extra robots for a mining bay, better module efficiency, replacing human workers with AI on certain jobs).
- A dedicated **Science Lab** module could still exist for more unique, experiment-driven research outside the licensing system.
	- Could also reverse-engineer items so that they would not need to be paid for? Or at least for items that are not normally accessible
- **Observatory / Astrometrics** module: spots incoming danger (pirates, solar storms) early, and separately produces ongoing science/research data.
- Science output could also come from **experiments** or from **expeditions** (see below) — including recovering resources/data from destroyed pirate ships.
- Expeditions:
	- Sending a crew out from the station to acquire resources (or, per Research & Science, research data) from elsewhere — asteroids, wrecks, points of interest. Likely requires a module to unlock, which makes it more of a mid/late-game option than an early-game safety net
- Upgrade system:
	- There are global and local unlocks.
	- Global unlocks are multiple different tech trees that are accessed from the main UI. Each unlock requires a certain number of credits as well as the previous techs to be unlocked. Each tree has a specific theme.
	- Global unlocks could include:
		- A new module type
		- Increased efficiency of certain modules
		- New local upgrades available for certain modules
	- Local unlocks provide bonuses specifically to the module they are applied to

## External Arrivals

- Ships travel from a planet to the station — implies the system needs an actual planet present, and probably a `LocationData` resource describing it. Could be shown visually approaching (zooming in as it nears the station, and vice versa on departure).
- People can also teleport in directly from the planet.
- Smaller ships arrive via the Shuttle Docking Bay.
- Larger ships arrive via a Cargo Port — conceptually similar to how *Cities: Skylines* separates road, rail, sea, and air connections, each bringing in different scales of traffic.

## Foreign Relations

Ability to communicate and deal with other stations/planets in the system — negotiating, trading, or otherwise interacting diplomatically. Other stations can also simply be trade partners

## Travel

Ability to warp the entire station to a new system. Late game, requires special Warp Core module.

## Roguelite Elements

- **Random events** — presented as event cards with a choice of responses/solutions.
- **Crises** — larger, "endgame"-scale problems (comparable to the crisis system in *Starsector*) that build up over time and are visible coming before they hit.

## Combat
- Combat is a part of the game that can be avoided in certain ways, but will still affect play
- Pirates, space beasts, and even other corporations may decide to attack your station
	- Sentient creatures can often be negotiated with, such as paying credits to avoid an attack
- Modules have structural values and attacks deplete those. When they reach zero, the module is destroyed
	- Modules that have not been completely destroyed can be repaired
	- Even a fully destroyed module remains as a "damaged truss segment" so that entire pieces of the structure don't become disconnected.
- Many combat-related modules:
	- Ablative Armor
	- Shields
	- Electronic Warfare modules (offensive/defensive)
		- Stuff like armor can't be turned off but perhaps other systems could be hacked
	- Weapons
		- Lasers, railguns, etc


## Endgame
- No particular victory condition
	- Besides being fabulously wealthy?
	- Rimworld (a similar very sandboxy game) does have an end goal - get off the planet - even if many people do not actively aim for it. Perhaps there should be a distant end-goal here too to provide that "out"?
- Losing includes:
	- Station destruction
	- Bankruptcy
	- All crew abandoning the station