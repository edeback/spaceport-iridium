# Resources & Economy

## Core Resources

- **Energy** — used by most modules to operate.
	- **Source**: Power generation modules
		- Can be passive (solar panel) or active (fusion reactor)
- **Water** — used by some modules (mess hall, farms).
- **Credits** — used to buy resources, unlock module blueprints, and build modules.
- **Oxygen** — used by environmental modules.
- **Biomass** — used by food modules; produced as an output by residences and some food modules.



## Processible / Raw Resources

Ore-based resources — mined, then refined:
- Industrial Metals (mix of iron/copper/zinc/aluminum/etc.) — used mainly for module construction.
- Precious Metals (gold/silver/platinum) — mainly for selling; some module uses.
- Iridium — mainly for selling; some module uses.
- Carbon / Silicon — unclear use so far; possibly just filler/trash resources.
- Water (from ice, not ore — also obtainable from comets) — used by some modules; refined into hydrogen/oxygen.

Gas-based resources — require special equipment (magscoops) to gather:
- Oxygen
- Hydrogen — used for thrusters and, combined with a fusion reactor, power generation.

## Resource Quality / Item Variance

Instead of every unit of a resource being identical, individual batches ("stacks") can carry their own item data rather than resources just being a flat count:
- Stacks with different item data don't automatically merge; stacks with *matching* (or close-enough) item data do merge together.
- Mainly useful for **ore** — capturing the specific elemental breakdown of a batch (e.g. "10% metals, 15% carbon, 20% silicates, 3% precious metals, 1% iridium, 30% water") — and for **food quality** levels.

## Storage

- Every storage-capable module has a max capacity and can hold several resource types at once.
- Each resource type stored has a **desired** quantity, acting as a soft (maybe hard) cap that defaults to the storage's max.
- Players choose which resource types a given storage can hold.
- Overflow handling: ability to vent/dump resources that are clogging things up (including venting gasses into space specifically), plus a possible auto-dump toggle.
- Job reservations against storage should be tagged by job ID to keep reserved totals honest.
- The trade/docking module needs a way to pull resources back *out* of its export bin, not just push them in.
- Removing a resource *option* from a storage config shouldn't destroy whatever's already stored — let it sell/drain off naturally instead.

## Energy Sources

Confirmed / near-term:
- **Solar Panel** — no fuel required; output depends on sunlight incidence; station starts with two.
- **Fusion Reactor** — requires hydrogen fuel.
- **Hydrogen Fuel Cells** — hydrogen + oxygen → energy + water; much less efficient than fusion.

Speculative / later-game ideas:
- Fission (would require adding uranium/plutonium as a resource)
- Radioisotope Power (similar, but possibly self-contained/no outside refueling needed)
- Bioelectrics
- Solar wind
- Zero-point / vacuum energy / quantum foam
- Neutrinos
- Antimatter
- Dark matter
- Quark matter

## Resource Gathering

- **Drone Bay** — houses mining drones; has generous storage for ore/ice/gas.
- **Mining Drone** — leaves the station, mines an asteroid/comet/gas cloud, returns with resources. Can be told to prioritize a resource type, can specialize in ore/ice/gas, and can be upgraded (faster mining, more efficient mining, more cargo space).
- **Large Mining Drone** — requires a Large Drone Bay; strictly better than the standard drone.
- **Station Magscoop** — a module attached directly to the station; very slowly gathers gas ions (mostly hydrogen) from solar wind; upgradeable, but generally stays fairly inefficient.
- **Matter Synthesis** — direct energy-to-matter conversion; extremely inefficient (should be a net loss if used to make hydrogen just to feed back into a fusion reactor).
- Floating salvage objects in space, with their own inventory, for recovering scrap/deconstruction materials.

## Markets & Trade

- **Open Market** — buy/sell from traders. A buy/sell screen showing prices — maybe only available while a trader is present, or maybe always visible but only fulfilled when a trader actually arrives. Resources need market prices attached.
- **Contracts** — offer a bonus/higher price for shipping a specific quantity of a resource by a deadline.
- **Events** change market supply, which in turn moves prices.
- **Other stations** in the system can be bought from too, functioning similarly to traders — either as passing traders or as fixed trading stations.

## Money

- Modules cost money to build.
- Resources can be sold for money — ideally by routing them to the docking bay, where they get sold off once picked up by a departing ship.

## Early-Game Balance / Avoiding Dead Ends

Concern: it's easy to burn through all available steel (or similar) with no refining set up yet and no docking bay to buy/sell from, leading to an unrecoverable early "death loop." Some comparisons/ideas for a safety valve:
- Dwarf Fortress has a caravan that shows up once a year regardless of your setup — maybe a similar "trader shows up periodically even without a docking bay" mechanic.
- RimWorld has a steep difficulty curve too, but a lot of early recipes can be made from wood, which is renewable — is there an equivalent renewable fallback here?
- Excursions/expeditions could work as a bailout, but likely require a module to unlock, making them more of a mid-game safety net than an early one.
- A teleporter could allow direct resource transfers — open question of whether it needs its own storage buffer or can teleport straight into another module's storage.
- You are a part of a parent company, you could call them up and plead for resources (to be repaid at a later time). If you don't repay later they will be angry! (or default take your funds)
