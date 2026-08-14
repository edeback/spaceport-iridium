# Module Brainstorm

Raw idea pool for new modules, new resources, and the order they'd unlock in. Nothing here is committed — it's meant to be mined for Work Items.

Format for each entry: **Name | Category | Effect | Prerequisites**. Everything else (costs, footprint, sprite, components, stats) gets filled in when a module graduates into a WI.

Conventions used below:
- **Category** = `ui_category` (build-menu bucket). New categories are marked `[NEW CAT]`.
- **Prerequisites** = the unlock's `prerequisites` + `min_tier`, and any module that must physically exist first.
- ⚠️ marks ideas that need a **new system**, not just a new component + `.tres`. Cost is called out per section.
- 🎲 marks the deliberately risky ones.

---

## Part 1 — The resource spine

The single biggest expansion lever isn't modules, it's **sinks**. Right now silicon, gold, iridium and biowaste are produced (or produceable) with nowhere to go but the market, which flattens everything into "make number go up." Every resource below exists to give an existing dead-end resource a consumer, and each one buys 3–8 modules' worth of design space.

### 1a. Electronics chain — gives **silicon** and **gold** a purpose

| Resource | Made from | Made by | Consumed by |
|---|---|---|---|
| Silicon Wafer | silicon | Wafer Fab | Electronics Assembly |
| Circuitry | wafer + gold | Electronics Assembly | advanced module build costs, Spare Parts, Data Cores, robots |
| Data Core | circuitry + silicon | Data Foundry | Research Lab (consumed as research fuel) |

The key move: **research is a physical logistics problem.** Data Cores are hauled to the lab like any other stack, so science competes for storage, haulers and priorities instead of being an invisible counter. That's the most "this game specifically" version of a tech tree I can think of, and it makes the Research Lab a factory the player has to *feed*.

### 1b. Chemical chain — gives **carbon** and **hydrogen** a second use

| Resource | Made from | Made by | Consumed by |
|---|---|---|---|
| Polymer | carbon + hydrogen | Polymer Reactor | Consumer Goods, seals, medical, textiles |
| Ceramics | silicon + carbon | Kiln | armor plating, heat shielding, high-temp modules |
| Coolant | water + polymer | Chem Plant | reactors, arc furnaces, turrets (heat system) |
| Consumer Goods | polymer + biomass | Fabricator | **shops sell these from real storage**; high-value export |

Consumer Goods are the important one: they turn commerce from an abstract credit faucet into the terminal sink of an actual production line. Market Hall sells physical stock; run out and income stops.

### 1c. Bio loop — finally gives **biowaste** a job

| Resource      | Made from           | Made by    | Consumed by                                          |
| ------------- | ------------------- | ---------- | ---------------------------------------------------- |
| Fertilizer    | biowaste + water    | Bioreactor | Hydroponics/Vertical Farm yield boost                |
| Methane       | biowaste            | Bioreactor | Combustion Generator, Polymer Reactor feedstock      |
| Medigel       | biomass + polymer   | Pharmacy   | Medical Bay treatment speed, disease cure rate       |
| Prepared Meal | biomass (+ quality) | Galley     | eaten directly; carries cook skill into food quality |

Closing the waste loop is the classic satisfying colony-sim beat, and `biowaste` already exists as a resource with no consumer — this is the cheapest big win on the list.

### 1d. Fuel & isotopes — gives **hydrogen/oxygen** an economy

| Resource | Made from | Made by | Consumed by |
|---|---|---|---|
| Ship Fuel | hydrogen + oxygen | Cryo Plant | **sold to docked ships** — service income, not goods income |
| Deuterium | water | Isotope Separator | Deuterium Fusion Core (3× fusion output) |
| Fissile Pellets | uranium ore | Ore Processor recipe | Fission Reactor |
| Helium-3 | comet ice / gas skimming | Gas Skimmer | endgame fusion, exotic research |
| Antimatter | enormous power input | Containment Ring | Antimatter Reactor, warp |

Ship Fuel is the sleeper hit: it makes the Docking Bay an *industrial customer* rather than a trade window, and gives the electrolyzer chain a reason to run at scale.

### 1e. Salvage & upkeep — gives the damage system a supply chain

| Resource | Made from | Made by | Consumed by |
|---|---|---|---|
| Scrap | wreckage, deconstruction, derelicts | Salvage Press / Salvage Hangar | Recycler |
| Spare Parts | steel + circuitry | Machine Shop | **repair jobs, breakdown prevention, robot repair** |
| Shells | steel + carbon | Ammunition Plant | Missile Battery, Railgun, Flak |

Spare Parts is a quiet structural change with a big payoff: right now repair and maintenance are free (just labour). Making them consume a manufactured good means a damaged station has a *material* cost, raids have an economic aftermath, and the Machine Shop becomes a module you genuinely can't skip.

### 1f. Exotics — endgame

| Resource | Made from | Made by | Consumed by |
|---|---|---|---|
| Exotic Matter | anomalies, deep survey | Anomaly Containment | warp coils, prototype tech |
| Iridium Alloy | steel + iridium | Alloy Furnace | tier-4/5 module build costs, warp spine, capital armor |
| Warp Coil | iridium alloy + exotic matter | Warp Coil Assembly | Jump Drive |

Iridium Alloy matters thematically: the station is called Iridium and iridium currently does nothing but sell. Making it the structural keystone of every late module retroactively justifies the whole name.

### 1g. New raw material worth adding

**Uranium Ore** — a fourth asteroid type. Cheap to add (mirrors existing ore→refined pattern), immediately unlocks fission, and pairs naturally with the radiation field below. Optional: it's only found in *depleted* or *distant* fields, so it costs travel time.

---

## Part 2 — New station-wide systems, ranked by cost/payoff

Each of these is a shared substrate that several modules below depend on. Listed cheapest-first.

| System | What it adds | Cost | Payoff |
|---|---|---|---|
| **New adjacency fields** (heat, radiation, filth, prestige, security) | More `AdjacencyEffectSpec` entries; the manager already propagates named fields with falloff | Very low — data + a few consumers | Huge. Turns placement into a real puzzle for ~5 new field types |
| **Perishability** | Food quality decays over time unless in a Cold Vault | Low — quality already exists on `ItemInstanceData` | Makes cold storage and logistics distance matter |
| **Heat/thermal** ⚠️ | Modules emit heat; insufficient radiator capacity throttles them | Medium — station-wide budget like power, or purely field-based | Radiators, heat exchangers, coolant, "hot side / cold side" station layouts |
| **Research points** ⚠️ | A second unlock currency earned by labs, spent on an exotic tree | Medium — `UnlockManager` already has trees and costs | An entire second progression axis, decoupled from credits |
| **Ship services** ⚠️ | Docked ships request fuel/repair/resupply as fulfillable contracts | Medium — extends `TraderManager`/`ContractManager` | Turns docks into a whole gameplay pillar |
| **Sub-grids** ⚠️🎲 | Breaker panels split power into independently browning-out zones with priorities | Medium-high — `PowerManager` is currently one pool | Brownout triage becomes a decision; makes batteries positional |
| **Hygiene need** ⚠️ | New `PawnNeedsComponent` axis; lavatories, showers, filth field | Medium — new need + modules + filth | Very Rimworld; also the most "do we actually want this?" one |
| **Crime & security** ⚠️🎲 | Visitors/crew can steal; guards, brig, surveillance field | High | Gives visitors a downside and defense a peacetime job |
| **Boarding** ⚠️🎲 | Raiders land and fight inside the station | High | Turns raids from a shooting gallery into a defense-in-depth problem |
| **Expeditions** ⚠️🎲 | Crew leave on a shuttle for N cycles, return with loot/nothing/dead | High | Off-map content, exotic material source, real stakes |

---

## Part 3 — Modules

### Industry & Refining

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Arc Furnace | Industry | Smelts iron and carbon into steel at triple the Forge's rate, for heavy power draw and a large heat output | Forge; T3; Thermal Control (if heat ships) |
| Alloy Furnace | Industry | Fuses steel and iridium into Iridium Alloy, the structural material of every tier-4+ module | Forge, iridium refining; T4 |
| Kiln | Industry | Bakes silicon and carbon into Ceramics for armor and heat shielding | Forge; T3 |
| Polymer Reactor | Industry | Cracks carbon and hydrogen into Polymer | Electrolyzer; T3 |
| Chem Plant | Industry | Combines water and polymer into Coolant, consumed by reactors and heavy industry | Polymer Reactor; T3 |
| Machine Shop | Industry | Turns steel and circuitry into Spare Parts, which every repair job and maintenance visit now consumes | Forge, Maintenance Facility, Electronics Assembly; T3 |
| Recycler | Industry | Breaks Scrap back down into base metals at a 40% loss | Ore Processor; T2 |
| Salvage Press | Industry | Compacts module wreckage and deconstruction debris into Scrap instead of destroying it | Recycler; T2 |
| Ore Sorter | Industry | Pre-sorts mixed ore feeding an adjacent Ore Processor, raising its refined yield | Ore Processor; T2 |
| Isotope Separator | Industry | Concentrates water into Deuterium, a fusion fuel worth three hydrogen per unit | Electrolyzer; T4 |
| Cryo Plant | Industry | Liquefies hydrogen and oxygen into Ship Fuel for sale to docked vessels | Electrolyzer, Docking Bay; T3 |
| Fabricator | Industry | Assembles polymer and biomass into Consumer Goods, the stock that shops actually sell | Polymer Reactor, Shop; T3 |
| Ammunition Plant | Industry | Manufactures Shells from steel and carbon for kinetic weapons | Forge, Missile Battery; T3 |
| Textile Loom | Industry | Weaves polymer and biomass into Fabric, consumed by bedding upgrades and Consumer Goods | Polymer Reactor; T3 |
| Nanofabricator 🎲 | Industry | Converts any refined material into any other at a brutal energy exchange rate — the ultimate bottleneck bypass | Research: Matter Compilation; T5 |

*Risk note on the Nanofabricator: it can trivialize every chain above it. Gate it at T5, make the energy cost genuinely painful, and treat it as a "you have won the logistics game, here's your trophy" item rather than a tool.*

### Electronics & Science `[NEW CAT: Science]`

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Wafer Fab | Science | Slices silicon into Silicon Wafers; nearby vibration wrecks its yield, so it wants a quiet corner | Silicon refining; T3 |
| Electronics Assembly | Science | Assembles wafers and gold into Circuitry, required by every advanced module's build cost | Wafer Fab; T3 |
| Data Foundry | Science | Burns circuitry and silicon into Data Cores — the physical fuel of the research tree | Electronics Assembly; T3 |
| Research Lab | Science | Scientists consume hauled Data Cores to generate research points, unlocking the exotic tech tree | Data Foundry; T3 |
| Observatory | Science | A manned watch post that gives several hours' warning of incoming raids and events, and surveys distant asteroid fields | Research Lab; T3 |
| Materials Lab | Science | Analyzes a sample of each ore to permanently raise refining yields for that ore station-wide | Research Lab; T4 |
| Assay Lab | Science | Reveals asteroid richness before drones commit to a field, and flags depleted rocks | Observatory; T3 |
| Xenobiology Lab 🎲 | Science | Studies alien samples for large research gains — and occasionally releases something | Research Lab, Shuttle Bay; T4 |
| Prototype Bay | Science | Spends a large research block on a single one-off module that outperforms its production version and cannot be rebuilt | Research Lab; T4 |
| Cartography Office | Science | Charts new fields and anomalies, generating expedition destinations | Observatory; T4 |
| AI Core 🎲 | Science | A station intelligence that automates one chosen subsystem (hauling priorities, repair dispatch, or power triage) — and generates an event chain if it's ever damaged | Research: Cognition; T5 |

*The Science tree is the natural home for a **second unlock currency**. Credits buy the industrial/crew/commerce trees; research points buy exotics. That keeps the two progression axes from collapsing into each other.*

### Food & Bio

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Galley | Food | A cook turns biomass into Prepared Meals whose quality is set by their Cooking skill, not just the ingredients | Mess Hall; T2 |
| Bioreactor | Food | Digests biowaste into Fertilizer and Methane, closing the station's waste loop | Algae Tank; T2 |
| Vertical Farm | Food | Triples hydroponics throughput for heavy power and water, and consumes Fertilizer as an optional yield booster | Hydroponics Bay, Bioreactor; T3 |
| Mushroom Farm | Food | Grows low-quality biomass from biowaste in the dark — no lighting, no power, thrives in filth | Bioreactor; T2 |
| Aquaculture Bay | Food | Converts water and fertilizer into high-quality biomass at a large water cost | Hydroponics Bay; T3 |
| Culture Vats | Food | Grows vat protein — the highest quality ceiling in the game, at the highest input cost | Aquaculture Bay, Pharmacy; T4 |
| Insect Vats 🎲 | Food | Enormous protein yield from biowaste; crew take a mood hit when they find out, unless they have the right trait | Bioreactor; T2 |
| Arboretum | Crew | A slow trickle of premium food plus the strongest greenery field in the game, over a wide radius | Garden, Hydroponics Bay; T3 |
| Distillery 🎲 | Commerce | Ferments biomass into Spirits: a high-margin shop good that lifts mood, then takes it back the next morning | Galley; T3 |
| Pharmacy | Crew | Produces Medigel from biomass and polymer, multiplying Medical Bay treatment speed and disease cure rates | Medical Bay, Polymer Reactor; T3 |
| Gene Lab | Science | Researches crop strains: higher yield, low-light tolerance, or blight resistance | Research Lab, Vertical Farm; T4 |

### Life Support & Sanitation

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Emergency Bulkhead | Core | Auto-seals on a pressure drop, isolating the breached section from the rest of the station's atmosphere | T2 |
| Pressure Regulator | Life Support | Manually vents a chosen module to vacuum — kills fires, sterilizes an infected ward, or evacuates a section on purpose | Emergency Bulkhead; T3 |
| Water Reclaimer | Life Support | Recovers water from biowaste and station humidity, closing the water loop | Ice Processor; T2 |
| Waste Incinerator | Life Support | Burns biowaste for a trickle of power and a lot of heat — the no-logistics escape valve for players who don't want a bio loop | T2 |
| Sanitation Plant ⚠️ | Life Support | Processes lavatory output into biowaste and suppresses the filth field station-wide | Lavatory; T2 |
| Lavatory ⚠️ | Life Support | Satisfies the Hygiene need; consumes water, produces biowaste | T1 (if hygiene ships) |
| Shower Block ⚠️ | Life Support | Restores Hygiene fully; unwashed crew take mood penalties and catch disease more readily | Lavatory; T2 |
| Atmospheric Mixer | Life Support | Widens the safe pressure band, so breaches take far longer to become lethal | O2 Generator; T3 |
| Isolation Ward | Crew | Quarantines an infected pawn, cutting transmission to zero while they're treated | Medical Bay, Air Purifier; T3 |
| Cryo-Sleep Bay 🎲 | Crew | Puts surplus crew into stasis: they draw no wages, eat nothing, and need nothing — but can't work until thawed | Research: Stasis; T4 |
| EVA Prep Room | Crew | Pre-suits crew next to an airlock, cutting EVA turnaround time and slowing Void Sickness accrual | Airlock; T2 |
| Escape Pod Bay | Crew | On catastrophic decompression or station loss, crew evacuate instead of dying — you lose their labour, not their lives | T3 |

### Power & Thermal

| Module                                      | Category | Effect                                                                                                                                  | Prerequisites                         |
| ------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| Fuel Cell Stack                             | Power    | Burns stored hydrogen and oxygen for instant on-demand power — the emergency generator                                                  | Electrolyzer; T2                      |
| Combustion Generator                        | Power    | Burns Methane for steady mid-tier power without a reactor's capital cost                                                                | Bioreactor; T2                        |
| Flywheel Bank                               | Power    | A cheap early battery alternative with fast discharge — and a heavy vibration field that ruins sleep nearby                             | T2                                    |
| Solar Concentrator                          | Power    | Boosts every adjacent Solar Panel's output substantially; produces nothing on its own                                                   | Solar Panel; T2                       |
| Radiator Array ⚠️                           | Power    | An exterior fin that dumps station heat to space; without enough radiator capacity, hot modules throttle themselves                     | T3                                    |
| Heat Exchanger ⚠️                           | Power    | Harvests waste heat from adjacent industry back into usable power, rewarding tightly clustered hot modules                              | Radiator Array; T3                    |
| RTG (Radioisotope Thermoelectric Generator) | Power    | Small, constant, unconditional power that never breaks and needs no fuel — and bathes its neighbourhood in radiation                    | Uranium refining; T3                  |
| Fission Reactor                             | Power    | Large steady output from Fissile Pellets; emits radiation and demands coolant, and a damaged one is a genuine emergency                 | RTG, Chem Plant; T4                   |
| Deuterium Fusion Core                       | Power    | A Fusion Reactor variant burning Deuterium at triple output                                                                             | Fusion Reactor, Isotope Separator; T4 |
| Capacitor Bank                              | Power    | A fast-discharge reserve that only feeds weapons and shields during a raid, so your guns can't brown out life support                   | Shield Generator; T3                  |
| Breaker Panel ⚠️🎲                          | Power    | Splits the station into independent sub-grids with their own priorities, so a shortfall browns out the smelters instead of the hospital | T3                                    |
| Antimatter Reactor 🎲                       | Power    | Colossal output from trace fuel. If it takes a hit while running, the station loses that district                                       | Research: Containment; T5             |
| Solar Sail Farm                             | Power    | Vast exterior arrays generating enormous power at the cost of an enormous exterior footprint that raiders will find first               | Solar Concentrator; T4                |

### Logistics & Transport

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Cargo Lift | Logistics | A vertical conveyor moving resources between floors without a pawn or a turbolift ride | Conveyor; T2 |
| Mag-Rail Spine | Logistics | A long, high-throughput horizontal belt that spans many cells for less than the equivalent conveyor chain | Conveyor; T3 |
| Pneumatic Tube | Logistics | Instant point-to-point transfer between any two storages on the station, at low throughput and high cost per link | Circuitry; T3 |
| Sorting Depot | Logistics | Sets desired amounts across every storage in a radius from one panel, and auto-balances stock between them | Logistics Bay; T3 |
| Constructor Drone Bay | Logistics | Builds and deconstructs blueprints without pulling crew off other work | Logistics Bay, Mining Bay; T3 |
| Auto-Stacker | Storage | Raises the capacity of every adjacent storage module and speeds hauls in and out of them | Large Storage; T3 |
| Tug Bay 🎲 | Logistics | Exterior tugs drag whole asteroids into close orbit, cutting drone travel time dramatically | Mining Bay; T4 |
| Drone Control Tower | Logistics | Raises the drone and hauler cap station-wide and improves their pathing efficiency | Logistics Bay, Circuitry; T3 |

### Storage

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Bulk Silo | Storage | Enormous capacity for exactly one resource type, chosen at placement | Large Storage; T3 |
| Cryo Tank | Storage | Stores gases at high density — required to hold hydrogen, oxygen or Ship Fuel above a small threshold | Electrolyzer; T2 |
| Cold Vault ⚠️ | Storage | Preserves food quality indefinitely; food stored anywhere else slowly degrades | Galley; T2 |
| Hazmat Locker | Storage | The only legal home for fissile material, exotics and antimatter; anywhere else and it irradiates the neighbours | Fission Reactor; T4 |
| Vault | Commerce | Secure storage that thieves and boarders cannot empty | Security Office; T3 |

### Crew & Habitation

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Barracks | Crew | Four cheap bunks in one footprint, at a shared-quarters mood penalty — the early-game density answer | Sleeping Pod; T1 |
| Private Quarters | Crew | A single high-comfort room with a large mood bonus and a footprint to match | Sleeping Pod; T3 |
| Officer's Suite | Crew | Assignable luxury quarters; its occupant gets a station-wide work-speed aura while their mood holds | Private Quarters; T4 |
| Gym | Crew | Recreation that also builds a Fitness stat: faster movement, more carry weight, better disease resistance | Holodeck; T2 |
| Library | Crew | Recreation that passively trains whichever skill the reading pawn is weakest in | T2 |
| Training Sim | Crew | Crew can take a dedicated training job to raise one chosen skill — pure time and power spent on future output | Library, Holodeck; T3 |
| Chapel | Crew | Quiet recreation that builds a slow, durable mood buffer; strongly trait-dependent | T2 |
| Observation Lounge | Crew | Recreation whose mood bonus scales with how much open space lies outside its window | T2 |
| Zero-G Rec Sphere | Crew | Top-tier recreation, but it demands a 3×3 unobstructed footprint | Holodeck; T4 |
| Counselling Office | Crew | A therapist job that strips negative mood modifiers off a struggling pawn before they break | Medical Bay; T3 |
| Memorial | Crew | Records the dead; crew passing by grieve less, and the wall gets longer | T2 |
| Crèche 🎲 | Crew | Long-term: crew form attachments and the station begins growing its own next generation instead of hiring | Private Quarters; T5 |
| Cloning Vats 🎲 | Exotic | Prints new crew from biomass — cheaper than hiring, deeply unpopular with everyone who watches it happen | Xenobiology Lab; T5 |

### Commerce & Tourism

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Market Hall | Commerce | A storefront that sells physical Consumer Goods out of station storage — no stock, no income | Fabricator, Shop; T3 |
| Broker's Office | Commerce | Reveals market price trends and lets you set standing buy/sell orders that execute automatically | Docking Bay; T3 |
| Capsule Hostel | Commerce | Cheap bulk lodging that draws high volumes of low-spending, low-prestige visitors | Hotel Room; T2 |
| Spa | Commerce | Paid recreation with the strongest mood restore available, at a heavy water cost | Water Reclaimer; T3 |
| Casino 🎲 | Commerce | Enormous per-visitor income, a rougher class of visitor, and a standing crime problem | Shop; T4 |
| Concert Hall | Commerce | Scheduled shows that pull a burst of visitors and lift station-wide mood for a cycle afterward | Holodeck; T4 |
| Paid Observation Deck | Commerce | Tourist attraction whose ticket income scales with station prestige | Observation Lounge; T3 |
| Advertising Beacon | Commerce | Raises visitor arrival rate and slows reputation decay | Docking Bay; T3 |
| Credit Union | Commerce | Crew deposit wages instead of hoarding them, returning part of the wage bill to the station as float | T4 |
| Customs Office | Docks | Taxes arriving traffic and screens for contraband; required once traffic passes a threshold | Docking Bay; T3 |

### Docks & Ship Services `[NEW CAT: Docks]`

Splitting docks out of Commerce is worth it on its own — it's currently one module in the wrong bucket, and it's the most under-exploited system in the game.

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Refueling Depot | Docks | Sells Ship Fuel to docked vessels for steady service income independent of the goods market | Cryo Plant; T3 |
| Ship Repair Yard | Docks | Consumes steel and Spare Parts to repair damaged visiting ships for credits | Machine Shop; T4 |
| Cargo Terminal | Docks | A larger berth that admits bulk freighters and unlocks high-volume shipping contracts | Docking Bay; T3 |
| Traffic Control Tower | Docks | A manned post that raises the number of simultaneously docked ships and cuts arrival delays | Docking Bay; T3 |
| Quarantine Dock | Docks | Screens arrivals for disease before they ever enter the station proper | Medical Bay, Docking Bay; T3 |
| Bulk Cargo Airlock | Docks | Traders load and unload directly from an adjacent warehouse, skipping pawn hauling entirely, for a cut of the sale | Cargo Terminal; T4 |
| Salvage Hangar 🎲 | Docks | Tows in derelict hulks; a deconstruction job strips them for Scrap and occasionally something far better | Salvage Press; T4 |
| Shuttle Bay 🎲 | Docks | Launches crewed expeditions that return after several cycles with exotic materials, new contacts, injuries, or nobody | Cartography Office; T4 |

### Defense & Security

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Flak Cluster | Defense | Short-ranged, cheap, hits several raiders at once — the volume answer to swarms | Laser Turret; T3 |
| Missile Battery | Defense | Slow, long-ranged, very high damage; consumes Shells hauled from storage | Laser Turret, Ammunition Plant; T3 |
| Railgun | Defense | Devastating single shots that need a full capacitor charge between each one | Capacitor Bank; T4 |
| Targeting Radar | Defense | Raises the accuracy and range of every turret in a radius — a soft, high-value target worth defending | Circuitry; T3 |
| Decoy Beacon | Defense | Draws raider fire onto itself and away from anything that matters | Circuitry; T3 |
| Armory | Defense | Arms crew as a militia when a raid or boarding starts | Machine Shop; T4 |
| Blast Door ⚠️ | Defense | A corridor chokepoint that boarders must cut through, buying the militia time to form up | Armory; T4 |
| Security Office ⚠️ | Defense | Guards patrol on a beat, suppressing theft, breaking up fights, and responding first to boarders | T3 |
| Brig ⚠️ | Defense | Holds arrested crew and visitors until they cool off or ship out | Security Office; T3 |
| Surveillance Hub ⚠️ | Defense | Projects a security field that suppresses crime across everything it covers | Security Office, Circuitry; T4 |
| Point-Defense Grid | Defense | Automatically intercepts incoming missiles and boarding pods before they land | Targeting Radar; T5 |

### Exotic & Endgame `[NEW CAT: Exotic]`

| Module | Category | Effect | Prerequisites |
|---|---|---|---|
| Anomaly Containment 🎲 | Exotic | Holds a captured anomaly that slowly bleeds Exotic Matter — and periodically does something the manual didn't cover | Xenobiology Lab; T5 |
| Warp Coil Assembly | Exotic | Winds Iridium Alloy and Exotic Matter into Warp Coils | Alloy Furnace, Anomaly Containment; T5 |
| Jump Drive 🎲 | Exotic | Moves the entire station to a new system: new asteroid types, new markets, new threat level, everything you didn't bolt down left behind | Warp Coil Assembly; T5 |
| Gravity Ring | Exotic | Removes zero-G maluses station-wide, improving long-term crew health and mobility | Research: Gravitics; T5 |
| Quantum Relay | Exotic | Instant pawn transit between any two relays, at a per-use energy cost that hurts | Teleporter; T5 |
| Independence Broadcaster 🎲🎲 | Special | Severs the station from ARC: no more levy, no more inspections, no more tier gates — and permanently higher raid frequency, worse prices, and no rescue when things go wrong | T5, all inspections passed |
| ARC Liaison Office | Special | The other path: reduces the levy skim and softens inspection requirements, at the cost of periodic Authority demands you can't refuse | T4 |

*The Broadcaster/Liaison pair is the biggest single idea in this document. It turns the tier ladder from a checklist into a **choice**: keep climbing ARC's ladder for stability, or cut loose at T5 and play a harder, freer endgame. It also gives the existing inspection and levy systems a narrative payoff they don't currently have.*

---

## Part 4 — Ordering

### 4a. Suggested tree structure

Existing trees: `industrial`, `power`, `food`, `crew`, `commerce`, `defense`. Proposed additions:

- **`logistics`** — split out of `industrial`, which is currently carrying conveyor/bay/storage/recharge/repair on top of all refining. It's the most overloaded tree in the game.
- **`science`** — the research chain; the only tree bought with **research points** instead of credits.
- **`docks`** — ship services.
- **`exotic`** — T5 only, gated behind research, not credits.

### 4b. Tier ladder placement

**T1 — Outpost** *(export: iron ore)*
Barracks. EVA Prep Room. Lavatory (if hygiene ships). Nothing else — T1 should stay claustrophobic.

**T2 — Waystation** *(export: iron ore + steel)*
The loop-closing tier. Bioreactor, Water Reclaimer, Waste Incinerator, Mushroom Farm, Galley, Cold Vault, Cryo Tank, Recycler, Salvage Press, Ore Sorter, Fuel Cell Stack, Combustion Generator, Flywheel Bank, Solar Concentrator, Cargo Lift, Emergency Bulkhead, Gym, Library, Chapel, Observation Lounge, Memorial, Capsule Hostel, Shower Block, Sanitation Plant, Insect Vats.

**T3 — Station** *(export: steel + gold)* — **the electronics tier**
The chain that defines the midgame: Wafer Fab → Electronics Assembly → Data Foundry → Research Lab. Alongside it: Polymer Reactor, Chem Plant, Kiln, Fabricator, Machine Shop, Cryo Plant, Arc Furnace, Vertical Farm, Aquaculture Bay, Arboretum, Pharmacy, Distillery, Ammunition Plant, Textile Loom, RTG, Radiator Array, Heat Exchanger, Capacitor Bank, Breaker Panel, Mag-Rail Spine, Pneumatic Tube, Sorting Depot, Constructor Drone Bay, Drone Control Tower, Auto-Stacker, Bulk Silo, Vault, Private Quarters, Training Sim, Counselling Office, Isolation Ward, Escape Pod Bay, Atmospheric Mixer, Pressure Regulator, Market Hall, Broker's Office, Spa, Advertising Beacon, Paid Observation Deck, Customs Office, Refueling Depot, Cargo Terminal, Traffic Control Tower, Quarantine Dock, Observatory, Assay Lab, Flak Cluster, Missile Battery, Targeting Radar, Decoy Beacon, Security Office, Brig.

**T4 — Complex** *(export: steel + iridium — suggest adding `circuitry` or `consumer_goods`)*
Alloy Furnace, Isotope Separator, Fission Reactor, Deuterium Fusion Core, Solar Sail Farm, Hazmat Locker, Materials Lab, Gene Lab, Xenobiology Lab, Prototype Bay, Cartography Office, Culture Vats, Cryo-Sleep Bay, Officer's Suite, Zero-G Rec Sphere, Casino, Concert Hall, Credit Union, Ship Repair Yard, Bulk Cargo Airlock, Salvage Hangar, Shuttle Bay, Tug Bay, Railgun, Armory, Blast Door, Surveillance Hub, ARC Liaison Office.

**T5 — Spaceport** *(currently no export goals — suggest `iridium_alloy` + `data_core`, so the endgame has a summit)*
Nanofabricator, AI Core, Antimatter Reactor, Point-Defense Grid, Anomaly Containment, Warp Coil Assembly, Jump Drive, Gravity Ring, Quantum Relay, Crèche, Cloning Vats, Independence Broadcaster.

### 4c. Critical-path chains (read left to right)

```
Ore Processor → Wafer Fab → Electronics Assembly → Data Foundry → Research Lab → [exotic tree]
                                     ↓
                          Machine Shop (Spare Parts) → repairs, robots, Ship Repair Yard

Electrolyzer → Polymer Reactor → Fabricator → Market Hall  (goods income)
            → Cryo Plant → Refueling Depot                 (service income)
            → Isotope Separator → Deuterium Fusion Core    (power)

Algae Tank → Bioreactor → Fertilizer → Vertical Farm → Culture Vats
                       → Methane → Combustion Generator
                       → Mushroom Farm

Forge → Arc Furnace → Alloy Furnace → Warp Coil Assembly → Jump Drive
     → Kiln → armor/heat shielding

Mining Bay → Uranium Ore → RTG → Fission Reactor → (radiation, coolant, Hazmat Locker)
```

Note the deliberate shape: **three separate income streams** — goods (Fabricator→Market Hall), services (Cryo Plant→Refueling Depot), and raw export (existing) — that a player can specialize into. That's the strongest structural argument for this whole list.

---

## Part 5 — The swings worth taking

Ranked by how much they'd change the game, not by how safe they are.

1. **Independence Broadcaster / ARC Liaison** — makes the entire existing tier-and-levy system into a real decision with a T5 fork. Largest payoff-to-code ratio here.
2. **Spare Parts** — one resource that retroactively gives damage, breakdowns, raids and robots an economic consequence.
3. **Research as physical Data Cores** — a tech tree that is also a factory. Nothing else on this list is as distinctively *this game*.
4. **Ship services (fuel, repair, terminal)** — turns the most under-used system into a third income pillar.
5. **Jump Drive** — the station moves. Enormous scope, and the only idea here that creates a whole second act.
6. **Heat & radiators** — the cheapest new *spatial* constraint; makes exterior placement a puzzle rather than a formality.
7. **Breaker panels / sub-grids** — brownouts become triage decisions instead of a global failure state.
8. **Boarding + security** — the honest answer to "what do 40 crew do when the shooting starts."
9. **Expeditions via Shuttle Bay** — off-map risk with on-map consequences, and the natural home for exotic materials.
10. **Crèche / cloning** — the station becomes self-sustaining in people, not just resources. Correct thematic endpoint for T5, enormous scope.

## Part 6 — Cheapest wins

Modules that need **no new system** — just a new `.tres`, an existing component, and maybe a recipe. Good candidates for a fill-in-the-gaps WI:

Barracks · Bulk Silo · Cryo Tank · Auto-Stacker · Solar Concentrator · Fuel Cell Stack · Flywheel Bank · Arc Furnace · Kiln · Polymer Reactor · Ore Sorter · Recycler · Bioreactor · Mushroom Farm · Vertical Farm · Aquaculture Bay · Arboretum · Galley · Water Reclaimer · Waste Incinerator · Gym · Library · Chapel · Observation Lounge · Memorial · Private Quarters · Capsule Hostel · Spa · Advertising Beacon · Cargo Lift · Mag-Rail Spine · Flak Cluster · Decoy Beacon · Wafer Fab · Electronics Assembly · Fabricator · Machine Shop · Cryo Plant · Refueling Depot.

That's ~38 modules and 8 new resources reachable inside the existing architecture: new `.tres` + recipe + an existing component, plus unlock entries. Everything ⚠️-marked above is a separate, larger conversation.
