# Spaceport Iridium — Design Document

*A living reference for the developer. Describes the intended game, not the current build. See [[01_Technical_Specification]] for how it is/will be built, [[02_Roadmap]] for the order of work, and [[03_Bugs_and_Improvements]] for current issues.*

---

## 1. Pitch

**Spaceport Iridium** is a 2D side-view space-station builder: *SimTower*'s one-room-at-a-time vertical cross-section crossed with *RimWorld/Dwarf Fortress* colony simulation. You are the station's management AI, building an iridium-mining outpost for the Astral Resource Corporation (ARC), keeping a crew of pawns alive, productive, and happy while turning a profit — and eventually deciding whether to stay under ARC's thumb or break free.

**Fantasy:** watching a cutaway ant-farm of a living station you designed, where every crate of ore is physically hauled by someone through corridors you placed.

**Genre anchors:**
- *SimTower / Project Highrise* — spatial layout puzzle, transport capacity as the core constraint, side-view legibility.
- *RimWorld / Dwarf Fortress* — pawns with needs, a job board, emergent stories, event-driven pressure, no fixed victory condition.
- *Starsector* (crises), *Cities: Skylines* (tiered external connections) as secondary references.

## 2. Design Pillars

Use these to test every feature:

1. **Everything is physical.** Resources occupy storage, get carried by pawns through real corridors, and can pile up on the floor. No abstract teleporting inventory (until the player unlocks literal teleporters).
2. **Layout is the puzzle.** Where you put a module matters: hauling distance, transport congestion, solar exposure, doorway adjacency. The station cross-section itself is the strategy board.
3. **The crew is the engine.** Nothing happens without pawns (or their robotic stand-ins). Automation is earned, not default — replacing pawn labor is a progression reward.
4. **Profit under pressure.** Credits are the universal motivator: ARC demands them, pirates extort them, tech unlocks cost them. Money is earned by physically shipping goods out.
5. **Sandbox with teeth.** No forced end state, but real lose conditions (destruction, bankruptcy, crew abandonment) and escalating threats that scale with your success.

## 3. World & Story Frame

- **Setting:** an asteroid field rich in iridium. Player is the station's onboard AI; SAI is the tutorial/advisor sub-AI voice.
- **ARC - Astral Resource Corporation (parent corp):** takes a cut of profits, sends inspectors, demands payments, but will bail you out in crisis (at future cost). Late game: buy, negotiate, or fight for independence. Independence trades protection (ARC Asset Integrity Service defense) for freedom (lower taxes, system travel).
- **New Game+ (far future):** start under a different parent corporation with different starting techs/bonuses, unlocked by maxing that corp's tree in a prior run.
- **Endgame:** sandbox. Lose by station destruction, bankruptcy, or total crew abandonment. A distant aspirational goal (RimWorld-style "escape hatch") is worth adding eventually — candidate: full independence + first station warp.

## 4. The Station

### 4.1 Grid & Layers
Modules are placed on an unbounded 2D grid (64px cells). Every cell has four co-existing layers:

| Layer | Contents | Notes |
|---|---|---|
| **Module** | Main functional rooms; implicit truss superstructure | Truss is a placeholder module auto-placed when a real module is removed |
| **Corridor** | Horizontal movement: hallways, airlocks | Separate from vertical so a cell can hold hallway + stairs simultaneously |
| **Turbolift** | Vertical movement: stairs, turbolift shafts | |
| **Space** | Asteroids, debris piles, drones/pawns on EVA | Not grid-aligned |

Modules connect within a layer (hallway↔hallway) or across layers via doors (module→hallway, hallway→turbolift). Pawns can exit to space through airlocks.

**Open question (carry-over):** should the truss be a real fourth buildable layer or stay a visual placeholder? Current lean: keep as placeholder module; a real layer adds cost without clear play value. Revisit when combat needs "damaged truss segments."

### 4.2 Construction
- Simple modules (hallway, stairs, truss, airlock) build instantly for credits.
- Complex modules: place blueprint → pawns deliver required materials → pawns spend work-time constructing → module activates. Deconstruction reverses this and leaves materials to be hauled away.
- Placement UX requirements: show blocked/invalid cells per active layer; re-validate on flip; multi-place by dragging (exists for hallways etc.).

### 4.3 Transport
- **Bulkhead** — impassable filler on multi-cell/exterior modules.
- **Hallway** — the default walkable connector.
- **Promenade** (future) — two-story hallway that doubles as the social hub.
- **Stairs** — cheap, slow (needs movement penalty).
- **Turbolift** — shafts of stacked modules with one or more cabs; dispatch logic already simulates pickups/dropoffs. Needs: per-floor enable/disable, cab count management, dispatch strategy selection, one master UI per shaft.
- **Teleporter** — instant point-to-point, heavy energy cost; its own module, not a transport-layer entity.

Transport capacity should become the mid-game bottleneck the way elevators are in SimTower — this only bites once pawn counts grow and shifts synchronize movement spikes.

## 5. Resources & Economy

### 5.1 Resource List
**Special:** Credits (universal currency, also research cost), Energy (produced/consumed live, not stored except in batteries).

**Raw:** Ore (elemental breakdown varies per batch), Ice (mostly water), gases from solar wind (hydrogen, oxygen).

**Refined from ore:** Iron, Carbon, Gold, Iridium, Silicon; from ice: Water; from water: Hydrogen + Oxygen (electrolysis).

**Manufactured:** Steel (iron+carbon), Polymers (carbon), Electronics (silicon+gold), Biomass (carbon+water), Food (grown; carries quality).

**Exotic Elements** — late-game, source TBD ("island of stability" flavor).

### 5.2 Resource Variance
Most resources are fungible integers. Two carry per-batch instance data:
- **Ore richness** — elemental breakdown of the batch; refining a rich batch yields more/better outputs. (Richness value already flows from mining through storage; refining does not use it yet.)
- **Food quality** — affects need satisfaction/happiness.
Stacks merge only when instance data is within a merge tolerance.

### 5.3 Gathering
- **Mining Bay / Drone Bay** — hosts mining drones that fly to asteroids, mine, and return. Drone upgrades: speed, efficiency, cargo. Large variant later.
- **Station Magscoop** — slow passive gas intake (mostly hydrogen).
- **Matter Synthesis** — energy→matter, deliberately net-negative for energy loops.
- **Salvage** — floating debris piles with inventories (exists: overflow/deconstruction piles; extend to wrecks).

### 5.4 Production Chain
Ore Refinery, Ice Refinery, Smelter, Electrolyzer, Polymer Factory, Electronics Factory, plus food chain: Algae Vats (low quality) → Hydroponics Bay (better) → Greenhouse (large, doubles as recreation).
**Decision to make:** individual buildings vs. a generic "Factory" module with selectable recipes. Current lean: individual modules (clearer silhouette, per-module upgrades), sharing one ProcessorComponent implementation — which is what the code already does.

### 5.5 Energy
Producers: Solar Panels (free, scales with exposure — implemented as fewer neighbors = more output), Fusion Reactor (hydrogen), Hydrogen Fuel Cells (H+O→energy+water, worse than fusion). Batteries buffer. Later ideas: fission, RTG, antimatter, etc.
Energy is computed per tick: total generation vs. total demand; shortfall drains batteries; unpowered modules stop working and (later) hurt morale.

### 5.6 Trade & Money
- **Docking Bay** — the physical gateway. Sell orders route goods here; ships take them away. Import bin needs a working "pull back out" flow.
- **Market** — supply-based pricing already: price = base × 2^(deficit/supply), buy at 1.5×, sell at 0.5×. Market supply drifts back toward default over time; events will shock it.
- **Traders** — goods should move only when a ship is present (currently trade is instant from the docking bay UI). A periodic "caravan" trader that shows up regardless of player setup is the early-game bailout (Dwarf Fortress model).
- **Contracts** — deliver X of resource by deadline for a premium; penalties for failure.
- **ARC levies** — periodic profit skim; pleading for emergency resources creates debt (with consequences for default).

### 5.7 Early-Game Death-Loop Protections
Known risk: spend all steel before refining/trade exists → unrecoverable. Mitigations (layered):
1. Periodic trader arrives regardless of docking infrastructure (or docking bay is starting equipment — it currently is).
2. ARC emergency loan (repay later or face consequences).
3. Deconstruction refunds materials (exists).
4. Starting loadout tuned so a refinery + drone bay is always reachable.

## 6. Pawns

### 6.1 Kinds
Organic crew (needs, happiness, shifts) and robotic pawns (mining drones exist; logistics robots later). Both use the same pawn/job framework; robots simply have no needs and are bound to a parent module.

### 6.2 Needs
- **Organic** pawns (most/all crew and visitors, for now):
	- **Hunger** (implemented: decays, pawn queues an Eat job below 30%, eats at a Sustenance module).
	- **Sleep** — How much rest a pawn has gotten. Improved by sleeping pods/quarters; hotel rooms and spas later.
	- **Recreation** — How much enjoyment a pawn has had. Improved by holodeck, shops, bars, general socializing
	- **Health** — Current state of the body. Reduced by injury, sickness (DiseaseData, infection spread from visitors), treated in a Medical Bay. Late phase.
	- **Happiness** — derived from the others plus situational modifiers (menial-work penalty, food-quality boost, ambient noise/vibration penalties). Consequences: productivity, and ultimately crew departure (a lose-condition input).
- **Robotic** pawns (drones)
	- **Energy** - Slowly drains, recharged at their home module or recharger modules. Low energy causes slow movement/work, zero energy only allows it to move (slowly) back to the recharger (on "backup power")
	- **Health** - Structural integrity. At zero, is destroyed. No native self-heal, must be repaired

### 6.3 Jobs
- Shared job board; modules post notices with priority (storage posts hauling requests scaled to deficit; construction sites post build jobs).
- Pawns pick the best job they can do; carry inventories are stack-aware; interrupted jobs never destroy cargo (falls back to Store Inventory sweep / floor piles).
- **Planned evolution:** job categories with per-category queues; "finish what's started" priority boost; eventually a utility score (priority + distance + pawn preference + age of posting) evaluated cheaply (event-driven, not per-frame).
- **Assignments:** pawns get a default workplace; if it's operable they work there, else fall back to the board. "Flex" pawns just take the board.

### 6.4 Schedule
Game clock with day cycles ("cycles") and hours; two default 12-hour shifts so the station runs continuously. Off-shift pawns sleep/eat/recreate. Time controls: pause / speed presets (basic Engine.time_scale hook exists).

## 7. Progression

Two scopes, both implemented in skeleton form:
- **Global unlocks** — themed tech trees (power, food, industrial so far) bought with credits (framed as *licensing rights* from orgs like "NeoNeutrino Labs" — flavor to reinforce the corporate setting). Effects: grant new module types, module-type-wide stat modifiers, and revealing local upgrades.
- **Local upgrades** — per-module-instance, tiered purchases (e.g., processor speed) stacking stat modifiers on that one module.

Later additions: Science Lab (experiment-driven research outside licensing), reverse-engineering, Observatory/Astrometrics (early warning + research trickle), science from expeditions and pirate wrecks.

## 8. Outside World

- **External arrivals:** planet → station ships (needs a planet + LocationData concept). Shuttles via Docking Bay; big freighters via Cargo Port (tiered connections à la Cities: Skylines). Teleport-in visitors later.
- **Foreign relations:** other stations as trade partners / diplomacy targets.
- **Natural(ish) Disasters:** meteor swarm, solar flares, dangerous xenobeasts
- **Events (roguelite):** random event cards with choices; market shocks; inspections.
- **Crises:** slow-building, visible-from-afar endgame threats (Starsector model). Pirates demand protection money; can be negotiated with.
- **Combat:** modules have structural HP; destroyed modules degrade to damaged truss (station never disconnects). Defensive modules: armor, shields, EW, lasers/railguns. Combat should stay avoidable-at-a-cost.
- **Travel:** late-game Warp Core moves the whole station to a new system.

## 9. UI

- Build menu grouped by module tags (exists), research panel (exists), module info panel with per-component tabs (exists), pawn info panel with needs/inventory/job tabs (exists).
- Needed: clock + calendar display, minimap (SimTower-style), power display polish, alerts/notifications feed, turbolift shaft panel, trade/contract screens, event card popups.
- View modes (exploration idea): module detail vs. transport cutaway vs. transport detail (turbolift cabs, teleporter links). Layer-dimming toggle exists as a first pass.
- Station alerts: Warnings to the player when things are going to have a problem (or already have one)
	- Personal alerts: Individual pawns that are having a hard time should also be noticeable such that the player can examine them and address the problem

## 10. Losing

- **Station destruction** (combat/crisis).
- **Bankruptcy** — credits below zero past grace, or unpayable ARC debt.
- **Abandonment** — all crew leave (happiness collapse) or die.
Each needs clear approach warnings — losing should feel earned, DF-style "losing is fun."
