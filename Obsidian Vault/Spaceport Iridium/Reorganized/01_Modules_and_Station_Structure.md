# Modules & Station Structure

## Station Layers & Views

The station is conceptually built from two layers:

- **Module layer** — the buildings themselves. Includes the truss/support structure, which acts as a low-cost placeholder foundation: a truss tile is removed when a module is built over it, and a new truss tile is added back when a module is removed. Modules could also be placeable directly on truss. Each module has specific "doorway" cells where pawns actually enter/exit, and modules get placed with hallway access attached if transport doesn't already reach that cell.
- **Transport layer** — hallways, stairs, turbolifts (teleporters are their own module, not part of this layer). Transport must be placed on top of a module, but it survives if the module underneath is removed, and can also be removed independently of the module.

Open question: does power need its own separate pathfinding/network from pawn movement, or can it just be treated as universal (no separately-powered sections)?

Idea for switchable views so the station isn't all shown at once:
- **Module detail** — see inside modules; pawns visible walking by, but hallways etc. aren't.
- **Transportation cutaway** — see hallways/turbolifts overlaid on the station.
- **Transportation detail** — click a turbolift to see its cabs, click a teleporter to see its connections, etc.

## Movement & Transportation Types

- **Bulkhead** — impassible. Used on mostly-exterior modules (e.g. solar panels) or on parts of multi-block modules.
- **Hallway** — habitable, walkable space; low maintenance cost; embedded in/on every module by default.
- **Promenade** — a double-level hallway; lets pawns move between floors without needing tubes/lifts. Doubles as the main public social thoroughfare (see Habitat & Life Modules below).
- **Stairs** — high movement penalty, low maintenance cost.
- **Turbolift** — point-to-point travel in any direction (vertical/horizontal/diagonal); a single shaft can have multiple cars ("turbocars") in it.
- **Teleporter** — instant point-to-point travel; very high energy requirement; its own module rather than part of the transport layer.

Transportation-specific TODOs:
- Fix how connections (doors, placement) work — probably belongs on the structure component rather than where it currently lives.
- Speed multiplier per "terrain" type, mainly for turbolifts.
- Ability to disable a turbolift door (or a stairwell) so it skips certain floors — likely wants one master "turbolift system" panel to manage all shafts at once instead of going module-by-module.
- A turbolift-specific UI where every module in the shaft is selected together: toggle floors on/off, set number of cars, choose a dispatch strategy.
- A better mechanism for force-rechecking pathfinding when a module's vertex *group* changes, not just when modules are added/removed.
- A blinking "no path" indicator for modules that have gotten disconnected from the rest of the station.

## Automated Logistics

Ways to move goods around without a pawn manually hauling everything:

- **Logistics Bay** — houses Roomba-style robots that only do hauling tasks.
- **Conveyor Belt module** — sits between two (or more) buildings and automatically pushes goods from one to the other, no manual labor needed.
  - Could auto-configure based on what's adjacent (per-resource, checking each output storage) — those resources would then stop generating hauling jobs, or have their jobs suspended while the belt runs and re-enabled if the destination fills up.
  - Individual transfers should be suspendable if the player doesn't want that pairing running.
  - Transfer could be automatic-only, or have an explicit UI showing what's currently being moved.
- **Pipes/tubes** — for connecting modules, likely on their own layer. Definitely makes sense for liquids; unclear if it's worth it for solid goods too.
- Storage priority as a routing tool: an "export" storage bin could have a permanent, very large negative priority, and an "import" bin a permanent large positive priority — though import priority probably needs finer-grained tuning so the player can, say, prioritize getting hydrogen to the reactor specifically.

## External Connections

- **Shuttle Docking Bay** — lets a number of shuttles dock/undock; the station starts with one. Acts as the required "source location" that other modules/logistics ultimately connect out to (e.g. sell orders route resources here).
- **Docking Ring/Pylon** — same idea, but for larger ships.

## Storage / Storerooms

- A **Storeroom** module holds a specific amount of resources; can be general-purpose or configured for specific resource types.
- Storage has a max capacity and can hold multiple resource types at once.
- Each stored resource type has a **desired** amount, which acts as a soft (maybe hard?) cap; desired defaults to the storage's max.
- Players should be able to choose which resource types a given storeroom is allowed to hold.
- A "vent" action for clearing out resources that have become useless clutter, plus a possible auto-dump option that clears superfluous stock automatically.
- Job reservations against a storeroom should be tagged by job ID so reserved amounts always reconcile correctly.
- For the trade/docking module specifically, there needs to be a way to actually get resources back *out* of the export bin (not just import/export flowing one direction).
- Players should be able to remove a stored-item *option* from the docking bay's config and have existing stock sell off naturally, rather than that stock being destroyed outright.

## Construction System

- A module starts in a "construction" state with most functionality disabled.
- It requires resources to be delivered before building can proceed.
- Pawns then perform work over time to finish it.
- While in placement mode, blocked/invalid cells should be shown, per layer (module vs. transport vs. whichever layer is active).
- Flipping a module during placement should re-validate placement rather than trusting the old check.

## Habitat & Life Modules

Life-support / crew-quality-of-life modules:
- Dining Hall
- Greenhouses / Hydroponics Bay / Algae Vats
- Sleeping Quarters — residences are meant to be self-contained, i.e. include their own shower and toilet.
- Recreation Modules
	- Promenade — doubles as the station's main social hub.
	- Holodeck

These pair with the life-related jobs pawns need to perform: sleeping, eating/drinking, socializing (see **03 – Pawns, Jobs & Life** for the job-system side of this).

## Industrial, Science & Combat Modules

- Storeroom — see Storage above.
- Observatory / Astrometrics — spots incoming danger (pirates, solar storms) early, and produces science/research data. See **04 – World, Meta & Progression** for how research output gets used.
- Ablative Armor
- Shields
- Electronic Warfare modules (offensive/defensive)
	- Stuff like armor can't be turned off but perhaps other systems could be hacked
- Weapons
	- Lasers, railguns, etc

## Visual & Polish Ideas

- Give similar module parts (e.g. doors, connectors) a consistent shape language so they read clearly at a glance.
- Colorize modules so different types are easier to tell apart.
- Let players change a module's decor.
- Modules could show an "exterior" shell when not hovered, and reveal the interior (with pawns visible inside) on hover.
- Tiles should distinguish "solid" vs. "sparse" rendering — sparse when 2+ sides are open (showing substructure or exterior detail underneath), solid otherwise. Might actually need to be tracked per-side rather than as a single solid/sparse flag for the whole tile.
- Truss should render invisible when it's sitting behind another module.

