

Current goal:

Money system:
- Modules cost money
- You can sell resources for money
	- Ideally they get transferred to docking bay
	- Then when they get picked up, earn cash

Storage modules:
- "Vent" items? For when things get clogged up with resources you can't use
- Be able to select which items can be stored there and which can't
- Desired sets a soft (maybe hard?) max on an item
	- Desired initial set to max
- ![[Pasted image 20251208125343.png]]
- Also maybe have auto-dump to clear superfluous resources?
- tag reserves by job id so that they always match up
- For trade module, somehow get import/export working? should be a way to get stuff _out_ of the export bin

Life-related buildings:
- Dining hall
- Greenhouses / Hydroponics bay / Algae vats
- Sleeping quarters
- Recreation modules
Plus life-related jobs:
- Sleep
- Eat/drink
- Socialize

QoL:
- Asteroids should have description of resources
- Mass sell for docking bay
- When flipping modules, double check validity
- Hallways should do actual connection check to determine sprite as opposed to existence (can "connect" to airlocks going opposite direction even though not really connected)
- Click on a cell multiple times to get nodes behind the top one (important for corridors + stairs/turbolift + module/truss behind)

Rework:
- Power system to not need to run every frame?
- Refactor jobs
	- More generic jobs/actions
	- System to set chains of actions/jobs and/or to pre-empt them
- Start removing process func as much as possible


Modules:
- Same shape language for similar parts?
- Colorize modules at least so that they can be distinguishable
- Show blocked cells!

"Research" system:
- Can purchase upgrades to modules
	- Extra robots for mining bay, for example
	- Better efficiency on modules
	- Ability to replace workers with AI for certain modules

Pawns:
- Current Job

Construct module system
- Start out with module in "construction" mode
	- Most things disabled
- Require resources
- Then work to build


Transportation modules:
- Fix how connections work (doors, placement) probably by moving them to structure component
- Speed multiple for different "terrain" (mainly turbolifts)
- Ability to turn off the door for turbolifts (stairs?) so they can skip floors
	- Probably have some main "turbolift system" panel to handle all at once instead of going module by module
- Better way of force-rechecking pathfinding when modules change vertex groups, not just when added/removed


current work:
- allow pathfind to specific location in module_graph? (like a position instead of a node2d)
	- pathfind to specific path index inside a module, too
- rework action_pathtotarget to be more general
	- have some sort of edgedata for general things? teleporters
	- ~~also move to character component instead of "action"~~
	- Separate out path movement so that movement can be done by some external force (like turbolifts)
		- Perhaps even make unit a child of the turbolift cab, then cab can move however it wants
			- cab has set of destinations, informs each pawn when it reaches a floor
		- 
- fix module blocking building of other modules, and have some way of showing it visually
- floating objects in space (with inventory) - recover scrap/deconstruction materials


Truss
- Make invisible when behind another module?

Other ways of moving goods around:
- Logistics Bay with roomba-like robots that can only do hauling tasks
- Conveyor Belt module that connects two (or more?) buildings by sitting in-between them
	- Automatically pushes goods from one module to another without needing manual labor
- Alternatively/additionally pipes or other tubes to connect different modules
	- Would need a different layer(?)
	- Liquids certainly, would other goods even make sense?


Time
- Visible clock showing day ("cycle"?) and hour
- Ability to pause, fast forward, slow down