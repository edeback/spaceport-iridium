
- Place support structures
- 


Maybe two views?
- Inside modules
- Transportation
	- Hallways, stairs (service tubes?), turbolift, teleporter (it's own module, not transport layer)
- Can switch between views
	- Transportation cutaway (see hallways, turbolift doors)
	- Transportation detail (click on turbolift to see tubes, click on teleporter to see connections)
	- Module detail (show inside of modules, pawns can still be seen walking by but can't see hallways etc)
- So therefore there are two "layers"
	- Module layer
		- Can also include things like "truss structure" ("integrated truss structure" on the ISS is the backbone) which does nothing but supports transport (hallway)
			- When a module is removed, a truss remains
			- Modules can be placed directly on trusses
		- Modules have specific cells that are the "doorway" cells, where pawns can come in/out
		- Modules are placed with hallways attached if transport doesn't already exist there
	- Transport layer
		- Hallways/stairs/lift/(not teleporter)
		- Must be placed on a module
		- When a module is removed, the transport stays
		- Transport can be removed separately of a module
			- Removing non-hallways leaves a hallway, can remove hallways to leave nothing
	- Will need separate pathfinding for power/pawn movement maybe?
		- Or maybe power is just universal? can't have separately powered sections?
Or maybe turbolifts connected by "turboshafts"
- Turbolifts take up normal module space
- Turboshafts are placed in a new layer interface
	- can be used for other pipes and such?
- Can then go in any direction, horizontal, diagonal, etc
	- Makes pathfinding more complicated probably
Stairs could be from specific multi-level modules
- Plazas or other recreational buildings
- Command center
- Power plants?

Create JobBoard
- Modules that need something will put a notice on the job board with a priority
	- Example: Processor needs an item, places notice on jobboard with priority = empty spots (more empty, higher priority)
	- Modules can place more than one notice (so a module can fill up not horribly slowly)
		- But maybe wait until the first notice is picked up, so the jobboard isn't spammed?

Create pawns
- Exist in a location
- Can move from place to place
- Can hold item(s?)
	- Maybe a carrying capacity? Would need items to have weight/encumbrance
- Modules will need max occupancy numbers

Hook up walkways for modules
- Path along the modules used for pawns to walk to/from
Add navigation system for modules


Maybe add a blinking "no path" symbol for modules that aren't connected to the rest of the station?

Create a docking bay to serve as the source location that modules need to connect to

External pawn arrivals
- Ships fly from planet to station
	- Requires to be a planet in the location
	- New LocationData for place?
	- Can be viewed approaching station (zooms in as it gets closer, vice versa)
- People teleport in from planet
- Smaller ships arrive via docking bay
- Larger ships arrive via cargo port
	- Think connections in City Skylines - roads (cars, busses), seaport, airport, train

Sickness and health
- External pawns can bring in sickness
	- Spreads to nearby pawns relative to infectiousness
	- DiseaseData
- Treated by medical bay
- Noise/vibration? from processing units


May need to use 2d array instead of dictionary
grid=Array()
grid.resize(height);
for i in range(height):
   grid[i]=Array()
   grid[i].resize(width)
   for j in range(width):
      grid\[i\]\[j\]=0