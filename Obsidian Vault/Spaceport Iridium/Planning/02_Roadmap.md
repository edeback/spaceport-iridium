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
| WI-12 | [[WI-12_Storage_QoL\|Storage QoL: venting, config, mass-sell]] | Vent/dump, remove-option-without-destroying, priority visibility |
| WI-13 | [[WI-13_Events_v1\|Random events v1]] | Event-card framework + market shock & ARC levy events; foundation for pirates/crises |
| WI-14 | [[WI-14_Contracts\|Trade contracts]] | Deliver X by cycle Y; uses WI-02 deadlines + WI-08 traders |
| WI-15 | [[WI-15_Pathfinding_Exterior_Semantics\|Pathfinding: `is_exterior` semantics]] | Un-overloads the vertex group field (construction stops stealing the "space" group); unblocks teleporter networks; pairs naturally with WI-11 (same graph loops). From the 2026-07-14 pathfinding discussion |
| WI-16 | [[WI-16_Micro_Anchors_and_Pawn_Positioning\|Micro anchors & pawn positioning]] | Path-to-point-inside-module primitive + authored/generated anchors + cosmetic de-overlap (lanes, jitter); fixes turbolift waiting pop-in; foundation for beds (WI-05), workstations, and future combat form-up |
| WI-17 | [[WI-17_Life_Support_Oxygen\|Life support: oxygen & atmosphere]] | Per-module O2/CO2 simulation, breathing, scrubber/generator machines, hull breaches. Added mid-Phase-2 from the life-support design push |

*Phase 2 leftover: [[WI-12_Storage_QoL\|WI-12 Storage QoL]] is still open — slot it in whenever convenient; WI-27's conveyor endpoint rules assume its import/export config language.*

## Phase 3 — Threat & Expansion

*Full designs in `New Work For Phase 3`; each row links its implementation doc. Ordering logic: pay down the foundations that everything else serializes/animates/tests against → give pawns identity and real work (half the phase reads skills) → stand up the damage framework → make money matter → automate → deepen life on board → real combat → new revenue → the UI shell. Each group ends somewhere playtestable.*

**Foundations & debt**

| # | Work item | Why this order |
|---|---|---|
| WI-18 | [[WI-18_Bootstrap_Cleanup\|Game start & bootstrap cleanup]] | Kills the magic 1-second startup wait; deterministic boot unblocks menu transitions (WI-36) and headless testing (WI-19). Small and first |
| WI-19 | [[WI-19_Testing_and_Tooling\|Testing & tooling: GUT + cheat console]] | Force multiplier for the other seventeen items; cheat console (rides Panku) makes every later WI verifiable in minutes |
| WI-20 | [[WI-20_Movement_and_Animation\|Movement & animation: CONVEYED state]] | Rides become an explicit serializable state (awaits stay for cosmetic door waits); animations sync to TimeManager so 4× stops penalizing doors. Prerequisite for WI-21 |
| WI-21 | [[WI-21_Job_Serialization\|Job & asteroid serialization]] | Pawns keep their jobs across save/load (type + targets, restart stage; board still re-derives); asteroids gain a save section. Every later WI's new jobs ship a save entry against this framework |

**Crew depth**

| # | Work item | Why this order |
|---|---|---|
| WI-22 | [[WI-22_Pawn_Identity\|Pawn identity: names, skills, traits, hiring choice]] | Load-bearing for half the phase: WI-23 consumes skills, WI-25 prices wages off hire cost, combat reads Accuracy, medicine reads Medical |
| WI-23 | [[WI-23_Work_Improvements\|Work improvements: workspaces, manned processing, workstation anchors]] | Assigned workers, processors that need a pawn at the machine, WI-16 anchors gain animations. Combat gunners and doctors reuse all three |

**Threat framework**

| # | Work item | Why this order |
|---|---|---|
| WI-24 | [[WI-24_Combat_Setup\|Combat setup: module HP, repair, breakdowns, pirate extortion]] | The damage/repair framework plus a pay-or-suffer pirate event delivers threat long before ship combat; breakdowns give repair jobs a peacetime purpose |

**Economy with teeth**

| # | Work item | Why this order |
|---|---|---|
| WI-25 | [[WI-25_Economic_Sinks\|Economic sinks: wages, upkeep, ARC levy, bankruptcy]] | Recurring costs force engagement with the whole loop; ships toggled-off until the first inspection. Wages need WI-22's hire pricing |
| WI-26 | [[WI-26_Station_Tiers\|Spacestation tier levels]] | Export goals + walking ARC inspector gate progression; `min_tier` on the existing unlock tree; the first passed inspection switches WI-25's costs on |

**Automation**

| # | Work item | Why this order |
|---|---|---|
| WI-27 | [[WI-27_Logistics_Automation\|Logistics automation: hauler robots & conveyors]] | Robots consume the HAUL category (WI-04); conveyors move goods jobless between neighbor storages. Bigger stations (tiers) need this |
| WI-28 | [[WI-28_Robotic_Needs\|Robotic needs: energy & integrity]] | Makes WI-27's robots (and mining drones) cost something: recharging, a Repair Bay, destruction at zero integrity |

**Life on board**

| # | Work item | Why this order |
|---|---|---|
| WI-29 | [[WI-29_Food_Quality\|Food quality]] | Continuous quality via the ore-richness variance machinery; producer module + worker skill (WI-22/23) set it, meals map it to nourishment and mood |
| WI-30 | [[WI-30_Module_Adjacency\|Module adjacency effects]] | Connection-based vibration/enhancement fields over the structure graph; delivers the purifier/maintenance hooks WI-31 and breakdowns consume |
| WI-31 | [[WI-31_Health_and_Disease\|Health & disease]] | Staged diseases, transmission, Medical Bay + Doctoring (WI-23 workspace, Medical skill); visitor-borne infection hook activates with WI-33 |

**Real combat & new revenue**

| # | Work item | Why this order |
|---|---|---|
| WI-32 | [[WI-32_Combat_v1\|Combat v1: pirate ships & station defenses]] | Ships, lasers, firing-arc turrets, armor, shields, hail/flee — on WI-24's damage framework, with WI-23 gunner hooks ready |
| WI-33 | [[WI-33_Visitors_and_Commerce\|Visitors, tourists, shops & hotels]] | Crew spend WI-25 wages; visitors arrive with wallets and a reputation loop; hooks WI-31 infections. The biggest item, deliberately after its dependencies all exist |

**UI shell & final texture**

| # | Work item | Why this order |
|---|---|---|
| WI-34 | [[WI-34_Minimap\|Minimap]] | Symbolic overview + click-to-jump; needed once stations outgrow a few screens |
| WI-35 | [[WI-35_UI_Overlays\|UI overlays: O2, power, integrity, vibration, logistics]] | One shader-tint overlay system reading WI-17/24/30 data; logistics mode shows priorities and flows |
| WI-36 | [[WI-36_Main_UI_Flow\|Main UI flow: menus, settings, pause]] | Main menu, save slots, keybind remap, pause menu; leans on WI-18's clean bootstrap for scene transitions |
| WI-37 | [[WI-37_Difficulty_Levels\|Difficulty levels]] | Thin data layer over knobs installed by WI-25 (costs), WI-32 (raids), WI-05 (mood); selected in WI-36's New Game flow. Last on purpose |

## Phase 3.5 — Stabilization

*Goal: the same thing Phase 0 wanted — current features stop lying to you — before Phase 4 builds on them. Phase 3 shipped twenty work items without a bug-fix pass between them; the 2026-07-22 audit of [[03_Bugs_and_Improvements]] is the first read of the whole thing as one codebase.*

| # | Work item | Why now |
|---|---|---|
| WI-38 | [[WI-38_Bug_Fix_Pass_2\|Bug-fix pass 2]] | Eight confirmed bugs from the post-WI-37 audit. Two are integrity bugs that corrupt play-tests the way WI-01's did: shield charge isn't saved (a mid-raid reload is a free recharge), and a New Game after Quit to Menu inherits the previous run's credits (verified). Cheap now, and Phase 4 shouldn't be built on top of them |

*Also open from the audit, deliberately not in WI-38: the section C refactors (one storage-query helper, power group caching, a `Groups` constants file) and the section B design debt — chiefly the `can_remove_module` structure check, disabled since Phase 0. Slot them in as convenient; none block Phase 4.*

## Phase 4 — Horizon (design only, no commitments)

ARC relationship arc & independence (turns the WI-25 levy off); expeditions; observatory and research; foreign relations/other stations; pawn factions (faction-styled name generation — WI-22's generator is wrapped for this); module quality tiers (unlocks the deferred Conceited trait); per-pawn sprite variants (asset work); pawn death done properly; crises framework; station warp travel; New Game+ corporations; exotic elements; tutorial (SAI); audio pass (WI-36 creates the Music/Effects buses).

---

### Standing rules for every work item

1. Every new system ships with its `SaveManager` section (after WI-03) and its cheat/debug hooks (after WI-19's console).
2. New periodic behavior subscribes to TimeManager ticks, never `_process` polling (after WI-02).
3. New job types declare a category (after WI-04) and a save/restore entry (after WI-21).
4. Balance numbers live in `.tres` data, not code constants.
5. New pure-logic rules get a GUT unit test (after WI-19).
