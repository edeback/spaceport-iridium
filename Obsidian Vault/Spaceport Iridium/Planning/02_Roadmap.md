# Spaceport Iridium — Work Plan / Roadmap

*Ordered plan of work. Each WI links to a full implementation doc in `Planning/Work Items/` (goal, files, steps, edge cases, verification) written to be handed to an implementing model one at a time. Later-phase items are outlined here only — write their docs when they get close, the ground under them will have shifted.*

**Ordering logic:** stabilize what exists → put in the two foundations everything else needs (time, saves) → close the survival/economy loop so the game is *playable* end-to-end → then deepen. Each phase ends in a build you can actually play-test.

---

## Phase 0 — Stabilize & Foundations

*Goal: current features stop lying to you; the two load-bearing systems every later feature depends on exist.*

| #     | Work item                                                       | Why now                                                                                                                                                             |
| ----- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| WI-01 | [[WI-01_Bug_Fix_Pass\|Bug-fix pass]]                 | Confirmed bugs (charge-without-build, turbolift crash, export-build data scan, signal type error) get more expensive to find later, and several corrupt play-tests  |
| WI-02 | [[WI-02_Time_Manager\|Game clock & simulation tick]] | Needs, shifts, traders, market drift, solar cycles, events — all are expressed in game-time. Also retires the per-frame power/storage/needs polling in one stroke   |
| WI-03 | [[WI-03_Save_Load\|Save/load system]]                | Longest-lever foundation; every system added after this must ship its own save section, which is only cheap if the framework exists first. Unblocks long play-tests |

## Phase 1 — Close the Core Loop

*Goal: mine → refine → sell → unlock → expand, with a crew that lives on a schedule and can be gained or lost. The game becomes a game.*

| # | Work item | Why this order |
|---|---|---|
| WI-04 | [[WI-04_Job_System_Refactor\|Job system cleanup & categories]] | Do before adding more job types (sleep, hauling variants, repair); resolves the cancel/end lifecycle questions and adds per-category queues + finish-first boost |
| WI-05 | [[WI-05_Needs_Completion\|Needs: sleep, recreation, social, happiness]] | Turns pawns from robots into crew; consumes WI-02 game-hours; sleeping pods/social/entertainment components already exist as stubs |
| WI-06 | [[WI-06_Shifts_and_Schedules\|Shifts & schedules]] | Thin layer on WI-02 + WI-05: work/rest cycles, per-pawn schedule, off-shift pawns satisfy needs |
| WI-07 | [[WI-07_Crew_Lifecycle\|Crew arrival & departure]] | Population as a resource: crew arrives by shuttle, leaves/dies from neglect → the happiness system gets teeth and the abandonment lose-condition exists |
| WI-08 | [[WI-08_Traders_and_Docking\|Traders, docking flow & the caravan safety valve]] | Moves trade from instant-menu to ship-present fulfillment; periodic guaranteed trader kills the early-game death loop; export bin becomes real |

## Phase 2 — Depth & Texture

*Goal: the loop grows decisions. Mostly parallel-friendly; suggested order below.*

| # | Work item | Notes |
|---|---|---|
| WI-09 | [[WI-09_Ore_Variance_Refining\|Ore richness through refining]] | Small, high flavor-per-effort; variance data already flows end-to-end |
| WI-10 | [[WI-10_Placement_UX\|Placement & selection UX]] | Blocked-cell display, flip re-validation, stacked-cell click cycling, no-path indicator |
| WI-11 | [[WI-11_Turbolift_Management\|Turbolift system panel & floor control]] | Shaft-wide UI, floor skip, cab count, terrain speed multipliers |
| WI-12 | [[Work Items/WI-12_Storage_QoL\|Storage QoL: venting, config, mass-sell]] | Vent/dump, remove-option-without-destroying, priority visibility |
| WI-13 | [[Work Items/WI-13_Events_v1\|Random events v1]] | Event-card framework + market shock & ARC levy events; foundation for pirates/crises |
| WI-14 | [[Work Items/WI-14_Contracts\|Trade contracts]] | Deliver X by cycle Y; uses WI-02 deadlines + WI-08 traders |
| WI-15 | [[WI-15_Pathfinding_Exterior_Semantics\|Pathfinding: `is_exterior` semantics]] | Un-overloads the vertex group field (construction stops stealing the "space" group); unblocks teleporter networks; pairs naturally with WI-11 (same graph loops). From the 2026-07-14 pathfinding discussion |
| WI-16 | [[WI-16_Micro_Anchors_and_Pawn_Positioning\|Micro anchors & pawn positioning]] | Path-to-point-inside-module primitive + authored/generated anchors + cosmetic de-overlap (lanes, jitter); fixes turbolift waiting pop-in; foundation for beds (WI-05), workstations, and future combat form-up |

## Phase 3 — Threat & Expansion (outline only; docs to be written when Phase 2 nears completion)

- **Combat v1** — module structural HP, damaged-truss degradation, repair jobs, one pirate raid event with pay-off option. (Depends: WI-13 events, WI-04 job categories; form-up positioning consumes WI-16's generated anchors.)
- **CONVEYED movement state** — position-ownership handoffs (turbolift rides; later trams/teleporter charge) become an explicit movement state instead of a suspended `await`, making rides serializable and interrupt-safe. Do it as part of the next major turbolift surgery, not standalone; until then WI-15's cab-save degradation covers save/load. Rule of thumb adopted now: awaits stay for cosmetic waits (door animations), anything that *owns a pawn's position* gets an explicit state.
- **New modules pack** — Magscoop, Hydrogen Fuel Cells, Smelter/Polymer/Electronics factories as buildables (ProcessorComponent + recipes — mostly data work), Promenade, Holodeck.
- **Logistics automation** — Logistics Bay (hauler robots reusing MiningDrone pattern), conveyor module. (Depends: WI-04.)
- **Observatory & science trickle** — second research currency feeding unlock trees; early-warning hook for combat events.
- **Health & disease** — DiseaseData, infection spread, Medical Bay. (Depends: WI-07 visitors.)
- **Minimap & alerts feed** — becomes necessary as stations grow past a few screens.
- **Turbolift Dispatch strategy:** enum on shaft {NEAREST_IDLE (current), COLLECTIVE (elevator-standard: keep direction, serve en-route calls)} — implement COLLECTIVE only if cheap; the panel dropdown can ship with one option and a disabled second. Honest v1: cab count + floor toggles are the value; strategy is stretch.

## Phase 4 — Horizon (design only, no commitments)

ARC relationship arc & independence; expeditions; foreign relations/other stations; crises framework; station warp travel; New Game+ corporations; exotic elements; tutorial (SAI); audio pass.

---

### Standing rules for every work item

1. Every new system ships with its `SaveManager` section (after WI-03) and its debug-console hooks (after WI-02's console, if included there).
2. New periodic behavior subscribes to TimeManager ticks, never `_process` polling (after WI-02).
3. New job types declare a category (after WI-04).
4. Balance numbers live in `.tres` data, not code constants.
