

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
- ![[Pasted image 20251208125343.png]]
- Also maybe have auto-dump to clear superfluous resources?
- tag reserves by job id so that they always match up

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

Pawns:
- Current Job

Construct module system
- Start out with module in "construction" mode
	- Most things disabled
- Require resources
- Then work to build


Transportation modules:
- Make turbolifts actually work
- Fix how connections work (doors, placement) probably by moving them to structure component


current work:
- allow pathfind to specific location in module_graph? (like a position instead of a node2d)
- Give pawns the tag of being in space or not (maybe?)
- rework action_pathtotarget to be more general
- tag teleporters in a special group, "space" side of airlocks in a special group
- link airlock outsides to insides
	- Maybe put door logic into path_component? Door to "space" layer?