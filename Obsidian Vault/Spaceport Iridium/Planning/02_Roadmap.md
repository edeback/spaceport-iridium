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

*Phase 2 is complete. [[WI-12_Storage_QoL\|WI-12 Storage QoL]] — the long-standing leftover — shipped **2026-07-19**, partly by direct editing rather than as a tracked pass, with two of its tasks dropped: the `draining` flag (unchecking a stocked resource **dumps it to the module's overflow pile** for haulers to collect, rather than draining in place via normal hauls) and the trade-panel mass-sell button (never built). Everything else landed: the accepted-resource checklist, per-resource desired amounts, component priority editing, dump-with-confirmation, and a saved auto-dump toggle. WI-27's conveyor endpoint rules depend on that config language and have it.*

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

| #     | Work item                                                                      | Why this order                                                                                                                         |
| ----- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| WI-34 | [[WI-34_Minimap\|Minimap]]                                                     | Symbolic overview + click-to-jump; needed once stations outgrow a few screens                                                          |
| WI-35 | [[WI-35_UI_Overlays\|UI overlays: O2, power, integrity, vibration, logistics]] | One shader-tint overlay system reading WI-17/24/30 data; logistics mode shows priorities and flows                                     |
| WI-36 | [[WI-36_Main_UI_Flow\|Main UI flow: menus, settings, pause]]                   | Main menu, save slots, keybind remap, pause menu; leans on WI-18's clean bootstrap for scene transitions                               |
| WI-37 | [[WI-37_Difficulty_Levels\|Difficulty levels]]                                 | Thin data layer over knobs installed by WI-25 (costs), WI-32 (raids), WI-05 (mood); selected in WI-36's New Game flow. Last on purpose |

## Phase 3.5 — Stabilization

*Goal: the same thing Phase 0 wanted — current features stop lying to you — before Phase 4 builds on them. Phase 3 shipped twenty work items without a bug-fix pass between them; the 2026-07-22 audit of [[03_Bugs_and_Improvements]] is the first read of the whole thing as one codebase.*

| # | Work item | Why this order |
|---|---|---|
| WI-38 | [[WI-38_Bug_Fix_Pass_2\|Bug-fix pass 2]] | **Done 2026-07-22.** Eight confirmed bugs from the post-WI-37 audit. Two are integrity bugs that corrupt play-tests the way WI-01's did: shield charge isn't saved (a mid-raid reload is a free recharge), and a New Game after Quit to Menu inherits the previous run's credits (verified). Bugs before refactors — and WI-40 needs its A5 fix |
| WI-39 | [[WI-39_Power_Registry\|Power registry]] | **Done 2026-07-22.** Retires `PowerManager`'s per-tick group scans for explicit registration, finishing the caching its dead fields and commented-out hooks have been promising since Phase 0 (closes the B2 remnant). The registry is where per-module power priority lands later, so life support can brown out last. Also deletes three groups before WI-41 has to convert them. Carries one bug WI-38 missed: battery charge isn't saved — same unsaved-field class as A2, found while scoping this |
| WI-40 | [[WI-40_Storage_Query_Helper\|Storage query helper]] | **Done 2026-07-22.** Four near-identical "find best storage" loops become one — the duplication that let A5 drift unnoticed. Cheap now that WI-38 fixed the one that diverged: two of the four are byte-identical and the collapse is mechanical. Gives per-resource storage indexing exactly one place to land when station sizes demand it |
| WI-41 | [[WI-41_Group_Constants\|Group constants]] | **Done 2026-07-22.** 22 group names (not 24 — `container_required` turned out to be addon-internal, and WI-39 had already deleted the three power groups) now live in `Groups`; 75 call sites across 52 files converted, zero bare literals left in `.gd`. Mechanical, so it went after WI-39 and WI-40 deleted the call sites it would otherwise have had to convert. Surfaced four joined-but-never-scanned groups as a side effect |
| WI-42 | [[WI-42_Preview_Metadata_Cache\|Preview metadata cache]] | **Done 2026-07-22.** Build preview no longer instantiates a whole module scene on every rotate, flip and menu selection — twelve static values per `PackedScene`, cached on the `PreviewModule` node. 47 instantiates per session instead of one per preview change. Shipped as designed in one file; also caught a live crash (flip with nothing selected) that had nothing to do with the cache |
| WI-43 | [[WI-43_Build_Menu\|Build menu reorganization]] | **Done 2026-07-27.** The per-tag `FoldableContainer` accordion had outgrown the screen — 40+ modules across a dozen tags. Replaced by a fixed category rail opening a floating flyout grid, plus search and a recently-built strip. Grouping moved off the multi-purpose `tags` field onto a new single-value `ModuleData.UICategory` enum, so `tags` stays reserved for gameplay. The first of the second wave: Phase 3.5 reopened once WI-42 shipped and the UI/job debt became the obvious next thing |
| WI-44 | [[WI-44_Job_System_Refactor\|Job system refactor (actions/toils)]] | **Done 2026-07-28 → 07-30.** The big one. Twenty-one `JobBase` subclasses, each hand-rolling movement plumbing, reservation bookkeeping, a state enum and a save/restore pair, collapse into `JobData` (.tres) + `JobDriver` + a shared action/finder library + a unified claim registry. `JobSerializer`'s hand-maintained type→factory table is gone: a job type is known to the save system because its `.tres` exists. The legacy `JobBase` system is deleted, not coexisting. Second-guessing this one's size was correct — seven stages — but every later item is cheaper for it |
| WI-45 | [[WI-45_Save_System_Audit\|Save system audit]] | **Done 2026-07-30.** Closes D8. Every component with a mutable non-derived field either got a save key or a comment saying why not. Seven findings, and the two biggest are gameplay-visible: storage priority wasn't saved (a hand-tuned station silently re-routes every haul on load, and priority *is* the routing language), and unmanned processors destroyed an in-flight batch's inputs. Went after WI-44 deliberately — auditing persistence before the job system stopped moving would have audited the wrong thing |
| WI-46 | [[WI-46_Structure_Connectivity\|Structure connectivity]] | **Done 2026-08-02.** Re-enables the `can_remove_module` delete guard that had been off since Phase 0 — the section-B/D9 debt noted below, now closed. Root cause was blueprints never forming their structural edges (`ready_blueprint` didn't connect them), so any construction in progress made the old whole-graph "is it one component?" test refuse *every* deletion. Fixed in three parts: blueprints connect the moment they're placed, the split test became a local cut-vertex check immune to unrelated islands, and the guard is back with a `station_alert` on refusal. Small and self-contained; slotted ahead of modding because it was a standing correctness hole, not a refactor. 505 GUT green (+7 cut-vertex tests) |
| WI-47 | [[WI-47_Modding_Support\|Modding support]] | **Stages 1–4 done 2026-08-02/03; stage 5 (patch ops) deliberately deferred.** Stages 1–3 were the load-bearing part and were pure refactors — components and pawn components now own their save blocks through hooks (`ModuleBase` no longer hardcodes every type), save sections are registered rather than a literal dict, and there is a mod loader. Stage 4 added the content kinds (categories, scenes, recipes, ships, pawn kinds) and an audit sweep. The **sample mod acceptance test passed with zero core edits**, which was the whole bar. Sat in 3.5 rather than Phase 4 because it's the same bargain the rest of the phase made — the three dispatch tables it deleted are exactly the ones every Phase-4 feature would otherwise keep growing. 616 GUT green |

*Ordering logic: bugs first, then the two structural duplications (power, storage), then the mechanical rename over the smaller surface that leaves. WI-42 sits off to the side. The second wave (WI-43 onward) is the same principle applied to what the first wave exposed: the build menu had outgrown its layout, the job system had outgrown its inheritance tree, and neither could be audited until it stopped moving.*

**Phase 3.5's first wave completed 2026-07-22** (WI-38…42, 377 GUT tests green). It reopened for a second wave — WI-43 through WI-47 — because Phase 4 kept turning out to be blocked on the same three things. **Phase 3.5 is now closed:** WI-43, 44 and 45 done 2026-07-30, WI-46 on 2026-08-02, and WI-47's stages 1–4 by 2026-08-03 (stage 5, patch ops, deferred by choice). The Phase-2 leftover WI-12 (Storage QoL) also shipped, on 2026-07-19 — see the Phase 2 note above for the two tasks it dropped. **Phase 4 is underway:** WI-48 (pawn interactions) landed 2026-08-09 at 688 GUT green, and the UI rework is [[Spaceport Iridium/Planning/04_UI_Rework_Program]] plus WI-49…WI-57. **WI-49 (the design system) shipped 2026-08-10 at 739 GUT green** — the theme is no longer empty, the palette/metrics/type scale are code, and `ConsolePanel`/`ReadoutPanel` plus eight widgets exist for WI-50 onward to build on. **WI-50 (console + modes) shipped the same day at 768 GUT green** — the 112px console replaces the left button column, the top-left resource strip and the overlay toolbar; six of the seven modes are mounted behind a lazy-factory `ModeManager` that guarantees one panel at a time; and the Esc chain fell from eleven named claims to a five-level ladder. Every ported screen still does exactly what it did, which is the property that makes the seven panel items after it independently shippable. **WI-51 (the inspector) shipped the same day at 823 GUT green** — five selection panels became one 420px bottom-right surface with a swapped tab set, the two that chased their subject across the screen every frame are gone, the Esc ladder lost four more claims, and the Needs tab finally breaks out every mood modifier feeding the happiness number. **WI-52 (vitals + ledger) shipped the same day at 866 GUT green** — the hardcoded seventeen-tile resource strip became six player-curated chips plus a four-column ledger flyout holding everything, the game gained a per-cycle rate for the first time (`ResourceRateTracker`, sim-time and least-squares), pins persist per save, and C13 is fixed so spending credits moves the number immediately. **WI-53 (alerts) shipped the same day at 901 GUT green** — and it is the one item in the program with real gameplay consequence: alerts now carry a severity, HIGH ones stay until they are clicked, and the six CRITICAL ones **hold the simulation stopped until acknowledged**. The top-centre strip of interchangeable red labels became a right-column feed with jump-to-subject, coalescing and a saved history log; the raid banner became a critical alert plus a proper readout; and `TimeManager` gained a reference-counted pause, which fixed a latent bug the four existing modal pausers already had with each other. **WI-54 (Build + Overlays) shipped the same day at 935 GUT green** — the two narrow panels, proving the frame at 356+340 and 360px, and the one behaviour change worth having: un-researched modules now *render*, dimmed, with the tech that grants them, instead of being hidden until unlocked. **WI-55 (Trade + R&D) shipped 2026-08-11 at 965 GUT green** — the two widest panels, and the biggest deletion in the program: the order sheet, the docked-trader modal and the contracts board became one 1180px panel with two tabs and **one signed stepper per commodity** (positive sells, negative buys), gaining an `AVAIL` column that finally stops the player committing stock a hauler has already claimed; the tech tree became four tabs at 1400px with a real state vocabulary on every node. Three screens were deleted outright and the Esc ladder lost its last modal level, so nothing outside the mode system claims Esc any more. **WI-56 (Crew + Stores) shipped the same day at 1033 GUT green** — the two panels with no predecessor, and the first station-wide views of information that previously existed only per-entity: a crew roster answering "is my crew fine?" in one glance (status sentence, morale bar, and a footer problem line that finally names the bunk shortage nobody could connect to a cause), and a Stores panel that puts every bin's haul priority on one screen with the legend that explains what the number does. `PawnStatus` is now the one place in the game that turns a pawn into a sentence, which three surfaces used to answer three ways. **WI-57 (Comms + retirement) shipped the same day at 1060 GUT green, and closes the whole program.** The last mode got its panel — a 620px Comms surface whose permanent amber ARC block turns promotion from a per-cycle coin flip into a button the player presses when they are ready, with each blocked state naming its own blocker; the economy screen became its FINANCE tab and WI-26's quota block moved in from Research, so the goals and the button that submits them are finally in one place. Alongside it, a small saved transmission log gives the notifications that deserve to be re-read somewhere to live, kept sharply distinct from alerts (an alert is "look at this now"; a transmission is "this arrived, read it later" — and unlike alerts, repeats do not collapse). The retirement sweep found almost nothing left to delete, which was the point: `ui_main.gd` ends the program at **481 lines, ten fewer than it started**, its runtime child list is exactly the allowed set, every console mode has a real panel, and `SAVE_VERSION` never moved. **The UI rework is complete.**

*From the audit, the section B design debt was chiefly the `can_remove_module` structure check, disabled since Phase 0. That decision is now made and shipped as WI-46 — the "fix the blueprint connectivity accounting" fork, not "delete the flag." Anything else lingering in section B is minor and doesn't block Phase 4.*


**Phase 4 progress note (2026-08-20):** beyond the UI rework, Phase 4 has shipped [[WI-48_Pawn_Interactions]], [[WI-59_Starting_Flow]], [[WI-60_Heat_System]] and [[WI-61_Comets]]. WI-61 added a second kind of mineable body — a comet crossing the play area behind the station with an ice/carbon/silicon yield — and in doing so turned `AsteroidManager`'s per-kind knobs into scanned `SpaceBodyProfile` data, which is the hook **Stars, Planets and Other Stations** will need for per-system ore richness. Phase 4's ordering is still not settled, so the tables below are unchanged. **Update (2026-08-22): [[WI-62_Dialogue]] has landed at 1316 GUT green**, and it is the largest deletion since WI-55. Events no longer have `choices` or `auto_effects`: an event is a `.tres` that decides *whether* it happens plus a `.dialogue` file that decides what is said and what it does, so `EventChoice`, `EventEffect` and its nine subclasses are gone along with the WI-13 event card. In their place is one conversational modal — the dialogue balloon — and one curated vocabulary a `.dialogue` file may reach: `station` for what a conversation does to the simulation, `story` for what it remembers. The chaining that buys is the point of the item: a saved flag store, faction standing, and a scheduled-event queue, demonstrated by the brief's *Damaged Ship Needs Help* running four hours into a follow-up whose opening line depends on what the player chose. Speakers gained faces (143 portraits behind eight scanned pools) resolved **once per conversation** rather than once per line. This is the prerequisite the Tutorial/Onboarding item was waiting on; SAI exists as a speaker with nothing yet to say. **Update (2026-08-22): [[WI-63_Tutorial]] has landed at 1381 GUT green**, and SAI now has one. Phase 4 therefore has a tutorial: an onboarding conversation that runs on the first frame of a new game and walks the player through placing their first module, plus eight one-shot advisories armed against the failures a station actually walks into. The mechanism is a **third dialogue alias**, `guide`, whose verbs can *block* a conversation until the player acts — which means the onboarding script is the state machine and there is no step table in code — and a **coach mark**, the first surface in the console UI that can point at a piece of the interface. That is what finally turned AIDE on, closing the last deferred stub of the UI rework program. "Skip Onboarding" sits on the New Game screen beside the difficulty picker, and everything skipped stays replayable from AIDE.

## Phase 4 — Horizon (design only, no commitments)

ARC relationship arc & independence (turns the WI-25 levy off); expeditions; observatory and research; foreign relations/other stations; pawn factions (faction-styled name generation — WI-22's generator is wrapped for this); module quality tiers (unlocks the deferred Conceited trait); per-pawn sprite variants (asset work); pawn death done properly; crises framework; station warp travel; New Game+ corporations; exotic elements; audio pass (WI-36 creates the Music/Effects buses).


## Phase 4.5 — Hardening

*Goal: polish and harden what Phase 4 built. The first six items come from the two audits of 2026-09-18 ([[03_Bugs_and_Improvements]]) and the [[05_Architecture_Review]] written alongside them. They follow [[WI-68_Audit_Fix_Pass]], which fixed the first audit's confirmed bugs and merged on 2026-09-19. Where WI-68 fixed findings one at a time, these close whole classes. All seven are done (WI-75 on 2026-09-23), which closes the phase. WI-69 through WI-73 took their §0 on the recommended defaults, WI-74 took the author's own F34 rule, and WI-75 took the author's §0.3: rides are saved, under the rule that saving and reloading must not change the game.*

| # | Work item | Why this order |
|---|---|---|
| WI-69 | [[WI-69_Integration_Test_Fixture\|Integration test fixture]] | First, because every item after it is verified against it. Boots the real `main.tscn` under GUT, so the managers, components and pawns (the untested half, where every audit finding lived) get tests. The first audit's runtime probes become permanent, and the open job bugs are pinned as known-broken tests. **Done 2026-09-19:** 9 integration suites and 31 tests (~35 s), plus F39 found and fixed. |
| WI-70 | [[WI-70_Job_Ownership_Contract\|Job ownership contract]] | The two real bugs: a save taken mid-deconstruction **loses the refund** (F38, confirmed), and an interrupted builder strands the site (F25). Then one `JobSlot` for eleven owners and a declared owner per job type, so a load stops posting duplicates (F26). **Done 2026-09-19:** all four fixed, plus F40 found and fixed (restored jobs had never actually resumed); the per-load leak it was to hunt turned out not to exist. |
| WI-71 | [[WI-71_Reference_Hygiene\|Reference hygiene]] | One written rule for holding a node you don't own, the 35-site F24 census triaged, stale alert rows (F27), the door hooks that latch a pawn's travel flag (F28), and source sweeps so it can't erode. **Done 2026-09-19:** 36 sites (not 35), two more measured Godot 4.7 facts, and the coroutine half split out to WI-75. |
| WI-72 | [[WI-72_Declared_Vocabularies_And_Content_Guards\|Declared vocabularies & content guards]] | Stat names become declared (F30), content checks move out of release-stripped `assert` into sweeps (F31), `SignalBus` gets a declared mod API (F11), and the balance literals move to data. Independent of 70 and 71. **Done 2026-09-20:** 21 stats (not 17) and 11 mod-API signals (not 10); the eleven asserts became one `wiring_fault()` virtual plus a sweep over every module scene; §4's moves A/B-checked byte-identical. |
| WI-73 | [[WI-73_Save_Orchestration\|Save orchestration]] | Pins manager ready order and save-section order with tests, moves the pawn-kind save branches onto the pawn classes, splits `SaveManager`, and corrects four stale persistence statements. After WI-70, which takes the job half of the same path. **Done 2026-09-22:** the real quicksave re-saves byte-identical across it; two stated section constraints turned out not to exist, and deleting the `is` chain unmasked a preload cycle (F41, fixed). |
| WI-74 | [[WI-74_Layering_And_Consolidations\|Layering & consolidations]] | One `start_job` instead of four, content caches that can be invalidated (unblocks WI-47 stage 5), the simulation stops calling the HUD (F33), and three small leftovers (F34, F36, F37). Last, because its job-picking change builds on WI-70. **Done 2026-09-22:** a cancelled blueprint refunds its whole fee and so does a finished deconstruction, paid from a saved per-module receipt so nothing the game placed for free pays out. |
| WI-75 | [[WI-75_Movement_Without_Coroutines\|Movement without coroutines]] | Split out of WI-71 on 2026-09-19: doors alone can't finish it, because the movement component awaits `path_exit` and the turbolift awaits through boarding. Takes all 37 awaits in the movement pipeline - doors, teleporter, queueing, boarding, the cab and the component's own chain - so a freed module can't strand a pawn and `is_traveling()` stops lying. The biggest item here and the one WI-69's fixture exists to make affordable. **Done 2026-09-23:** every wait a walk can hit is a state, and the whole walk - path, door wait, lift ride, cabs, doors - is saved, so a save forked into a live run and a reloaded run gives the same trace sample for sample. Found and fixed F43 (saves rounded every float to 14 digits), F44 and F45. |

---

### Standing rules for every work item

1. Every new system ships with its `SaveManager` section (after WI-03) and its cheat/debug hooks (after WI-19's console).
2. New periodic behavior subscribes to TimeManager ticks, never `_process` polling (after WI-02).
3. New job types declare a category (after WI-04) and a save/restore entry (after WI-21).
4. Balance numbers live in `.tres` data, not code constants.
5. New pure-logic rules get a GUT unit test (after WI-19).
