# Spaceport Iridium — Technical Specification

*How the game is built today and the remaining large-scale technical goals. Companion to [[00_Design_Document]]. File paths are relative to the project root. Engine: Godot 4.7, GDScript, typed-declaration warnings enabled.*

*Updated 2026-07-17 to reflect completed work through WI-16 plus the in-progress WI-13 (events) / WI-14 (contracts) implementations. Earlier revisions of this doc predate the time, save, crew, trader, event, and contract systems.*

---

## 1. Current Architecture (as of 2026-07-17)

### 1.1 Composition model
The whole game is built on **composition over inheritance**, consistently:

- **Modules** are scenes rooted in `ModuleBase` (`modules/templates/module_base.gd`) with child **components** (`modules/components/*`, all extending `ComponentBase`). A module's behavior = the set of components in its scene: `StorageComponent`, `ProcessorComponent`, `ConstructionComponent`, `PathComponent`, `StructureComponent`, `PowerGeneration/ConsumptionComponent`, `SolarPowerComponent`, `BatteryComponent`, `MiningComponent`, `SustenanceComponent`, `SleepComponent`, `SocialComponent`, `EntertainmentComponent` (the latter three are `RecreationProviderComponent` variants), `TradeComponent`, `CrewRecruitmentComponent`, `LightingComponent`, `SpriteSelectionComponent`.
- **Module identity** is data: `ModuleData` resources (`data/modules/**/*.tres`) carry an `id: StringName` (the save-stable identifier), name, cost, scene reference, tags, layers, flip variants. Build menus, unlock trees, and the save system discover data by scanning `data/` directories via `ResourceScanner` (`scripts/utility/resource_scanner.gd`), which handles exported-build `.remap`/`.import` suffixes — never hand-roll directory scans.
- **Pawns** are `PawnBase` scenes with `PawnComponentBase` children (`PawnMovementComponent`, `PawnInventoryComponent`, `PawnNeedsComponent`, `PawnHealthComponent`, `SocializeComponent`). `MiningDronePawn` subclasses `PawnBase` only to restrict job sourcing. Crew carry a `ScheduleData` (`data/pawns/shift_*.tres`).
- **Jobs** are `JobBase` subclasses (`scripts/jobs/`), each a self-driving state machine given `process_job(delta)` by its pawn. Jobs are `Resource`s, not nodes. Current set: get-resource (hauling), construct, mine, eat, sleep, recreate, collect-pile, store-inventory, move-to-location, leave-station, idle/idle-wander.
- **Components/UI**: each component can supply its own info-panel tab (`has_ui()` / `get_ui()`), so the module info panel assembles itself.

This model is working well and should be preserved. New features should be new components + new `JobBase` subclasses + new `Resource` data types, not new inheritance trees.

### 1.2 Managers (singletons by registration)
`Global` and `SignalBus` are the only autoloads; every other manager is a node under `Managers/` in `main.tscn` that registers itself into `Global.<name>` in `_ready()`. **Tree order = ready order** and it is load-bearing: `TimeManager` must stay first (everything subscribes to its signals in `_ready`), `SaveManager` stays last (it applies a pending load deferred, after every other manager exists).

| Manager | Responsibility |
|---|---|
| `TimeManager` | Game calendar (cycles/hours), pause, speed presets; `sim_tick`/`slow_tick`/`hour_changed`/`cycle_changed` signals; `sim_seconds()` await helper (§1.3) |
| `WorldManager` | Grid occupancy per layer (`cell_to_module` dicts), module add/remove/purchase, truss replacement, layer canvases; world save section |
| `PathManager` | Pawn-traversal `ModuleGraph`; reachability, pathfinding entry points, vertex groups |
| `StructureManager` | Second `ModuleGraph` of physical attachment (for can-remove checks; currently the check is disabled) |
| `PowerManager` | Power balancing across generator/consumer/battery groups on `slow_tick` |
| `TurboliftManager` | Shaft registry; merge/split shafts as lift modules are added/removed; shaft save section |
| `JobManager` | Job board: one priority-sorted queue per `JobBase.Category`, job aging, cross-category merge selection (§1.7) |
| `ResourceManager` | Registry of storable resources; cached-total recalcs on `slow_tick` |
| `MarketManager` | Market stock/prices; hourly drift toward default supply; timed supply modifiers (WI-13 shocks). Lives at `scripts/managers/market_manager.gd` |
| `AsteroidManager` | Spawns/despawns drifting asteroids (not persisted — see §2.2) |
| `AudioManager` | Placeholder: a plain Node holding one looping music `AudioStreamPlayer`, no script yet |
| `UnlockManager` | Global tech-tree state, granted modules, global stat modifiers, local-upgrade catalog |
| `CrewManager` | Crew lifecycle (WI-07): starting-crew spawn, hiring with shuttle arrivals, resignation departures, abandonment lose condition; roster is a live query over the `"pawn"` group |
| `TraderManager` | Trader visits (WI-08): guaranteed caravan cadence, per-visit price snapshots, incremental fulfillment of committed trades on `slow_tick`, net market settlement at departure |
| `EventManager` | Random events (WI-13): loads `EventData` from `data/events/`, paces rolls off calendar signals, owns cooldowns, the pending-card queue, and station-wide timed happiness effects |
| `ContractManager` | Delivery contracts (WI-14): offer/active/history lists, offer generation per trader visit, contract demand registered on the docking bay's `TradeComponent`, deadline resolution on cycle ticks |
| `SaveManager` | Versioned save envelope, id→definition lookups, load orchestration (§1.10) |

Cross-system events go through `SignalBus` typed signals (including the generic `station_alert(message)` feeding the UI alerts strip).

**Bootstrap ordering (WI-18):** the starting station spawns from `Main._ready()` (the root readies after every manager, so every `Global.*` is registered) via `WorldManager.spawn_starting_station()` — no wall-clock timer. `Main` emits `SignalBus.game_bootstrapped` after the spawn; the load path emits it from `SaveManager._apply_pending_load` once every section is applied. `CrewManager` still reacts to `module_added` for the starting-crew spawn.

### 1.3 Time & simulation (WI-02)
`TimeManager` owns game time: cycles of 24 hours, `SECONDS_PER_HOUR` (currently 10.0 — testing value), pause, and speed presets (0.5×–4×). `Engine.time_scale` and `get_tree().paused` are deliberately **not** used — UI stays real-time. Consumption rules (enforced across the codebase):

- Per-frame gameplay `_process` handlers multiply delta by `Global.time_manager.scale(delta)` and early-return on 0.
- Periodic scans subscribe to `slow_tick` (every 0.25 sim-seconds; the passed interval is elapsed sim-time): power balancing, storage job posting, resource total recalc, job aging, trader fulfillment, contract re-sync.
- Calendar behavior uses `hour_changed`/`cycle_changed`: market drift, event rolls, contract deadlines.
- One-shot waits: `await Global.time_manager.sim_seconds(x)`, never `get_tree().create_timer()`.

Because calendar signals only fire from the sim loop, time-driven systems can't advance while paused by construction.

### 1.4 Pathfinding & movement (the most developed subsystem)
- `ModuleGraph` (`scripts/utility/module_graph.gd`): hand-rolled Dijkstra/A* (heuristic currently 0 = Dijkstra, deliberately, so teleporter-style shortcut groups are explored) over vertices = modules/pawns/space nodes. Features:
  - **Groups** mean exactly one thing since WI-15: implicit network cliques (e.g. `"turboshaft_3"`, future teleporter nets) with a per-group cost multiplier (turbolifts 0.5×). Exteriorness is a separate `is_exterior` flag on `ModuleGraphVertex` — construction toggles the flag rather than stealing a `"space"` group.
  - **Subgraph tracking** for O(1) reachability queries, lazily rebuilt when dirty — jobs rely on this being cheap.
  - Goal-predicate searches: pathfind to type / to component type / to arbitrary lambda.
  - Temporary vertex splicing for free-floating space targets (asteroids, debris piles).
- `PathComponent`: per-module micro-graph (`AStar2D` of interior waypoints), doors mapped to layers, path/door behaviors (`PathBehavior` strategy objects: sliding doors, linked doors), sub-path traversal so pawns visibly walk through module interiors.
- **Anchors** (WI-16): positions inside modules are micro-graph anchors — authored (bunks, turbolift queues) or generated at runtime by subdividing interior path edges. Pawns path to a specific anchor via a final-leg sub-path; one-shot anchor claims at arrival plus persistent per-pawn perpendicular render offsets and walk-speed jitter handle overlap **cosmetically** — RVO/physics separation and per-frame neighbor queries are explicitly rejected.
- `PawnMovementComponent`: consumes graph path + per-module sub-paths, awaits behavior hooks (`path_enter`/`path_exit`/`traverse`), watches for module removal/group changes mid-route and re-paths.
- Turbolifts: `TurboliftShaft` (RefCounted) + `TurboliftCab` + `RideRequest`; `path_exit` on a lift module awaits an actual cab ride. Shaft-wide management UI (`turboshaft_panel`) with per-floor toggles and cab count exists (WI-11).

**Remaining weak point:** cab rides own a pawn's position through a suspended `await`, so rides aren't serializable — mid-ride pawns save at the cab's current floor. The planned fix is the explicit CONVEYED movement state (§2.1).

### 1.5 Resources, storage, and hauling
- `ResourceData` (.tres per resource) holds an `id`, market data, and a registry of every `StorageComponent` containing it; totals are cached and recalced on dirty flag per `slow_tick`.
- `StorageComponent` holds `StorageData` per resource (stored, desired, reserved-in/out, active jobs). Editor-set `StorageData` are deep-copied at runtime so scene reloads (save loading) don't inherit mutated shared subresources. The import/export posting scan runs on `slow_tick`, gated by build state (`_posting_active`), with a shared import budget to prevent overcommit.
- `Job_GetResource` resolves the other endpoint at claim time (best reachable source/sink by priority-then-distance), reserves amounts, and moves real `ResourceStack`s.
- **Instance data** (`ItemInstanceData`): ore richness flows end-to-end — mining → inventory → storage → refining, where `ProcessorComponent` uses batch richness as a yield multiplier (WI-09); the selected recipe persists in saves. Stacks merge only within a merge tolerance. Food quality is designed but not yet implemented.
- Priority is the routing language: construction sites import at +99, deconstruction exports at −99, sinks must out-priority sources.
- `ResourcePile` handles floor/space debris outside the storage system, with its own reservation bookkeeping and `Job_CollectPile`. Piles are saved.

### 1.6 Power
On each `slow_tick`: sum desired power over the `power_consumer` group, sum generation over `power_generator`, drain/charge the `battery` group with the difference, then tell each consumer whether it's powered. The passed interval integrates batteries/fuel correctly across pause and fast-forward. Solar output scales by free (unconnected) structure sides. Still uses `get_tree().get_nodes_in_group` per tick — fine at 4 Hz sim-time, but cache membership via registration signals before adding many more modules (§2.3).

### 1.7 Jobs (WI-04)
- `JobManager` keeps one priority-sorted queue per `JobBase.Category` (`HAUL, BUILD, WORK, NEEDS, MOVE, MISC`). Categories are an index/filter, not a ranking — `find_job` merges across queues by `effective_priority()`, so a high-priority MISC job still beats a low-priority HAUL job. Pawns can filter by allowed categories (shift logic uses this).
- `effective_priority()` = base priority + a capped age bonus (jobs age on `slow_tick`), so starved jobs surface without ever crossing the ±99 routing bands.
- Lifecycle is unified: `cancel()` always ends the job; an `_ended` latch guarantees reservations can't double-release and `job_end` fires exactly once. `find_job` cancels (not merely ends) invalid jobs it encounters, so requesters release reservations. Subclass rule: any callback that can fire after the job ends must early-return on `_ended` before mutating state.
- Followup jobs and queued needs go through the pawn's personal `job_queue`, never the shared board.

### 1.8 Population: needs, schedules, crew lifecycle
- `PawnNeedsComponent` (WI-05): hunger, sleep, and recreation decay in **game-hours** via a generic `NeedDef` loop. Below a look-for threshold the pawn queues a personal need job once; below critical the job is promoted to the queue front and a station alert fires — no forced interrupts (that was the old starvation-lock bug). Health is separate (`PawnHealthComponent` — regenerates, future combat/disease); social is not a need but one way to restore recreation (`SocialComponent` is a recreation provider).
- **Happiness** is a derived 0..1 aggregate of need percentages, sibling health, and timed modifiers; it feeds `PawnBase.work_speed()`. Sustained misery below a threshold starts a resignation countdown with a grace window (WI-07); resigned pawns walk to the bay and leave. All crew gone (or dead) → game over.
- **Shifts** (WI-06): crew carry `ScheduleData` (`data/pawns/shift_a/b_schedule.tres`, two 12-hour shifts); the schedule gates which job categories a pawn takes, and off-shift pawns satisfy needs.
- `CrewManager` (WI-07) owns starting-crew spawn (reacting to the starting module's `module_added`, deferred-hop-proof), hiring (credits → shuttle arrival after a delay → new pawn), and the lose condition. Pending hires reference their bay as a layer+cell dictionary so a deconstructed bay refunds instead of dangling.

### 1.9 Economy & outside world
- `MarketManager`: supply-based pricing (buy at 1.5×, sell at 0.5× multipliers over the supply-scaled base price); stock drifts 10% toward *effective* supply each game-hour. Timed supply modifiers (WI-13 market shocks) scale the drift target and snap current stock so price jumps are immediate and decay naturally.
- `TraderManager` (WI-08): a guaranteed caravan docks every `caravan_cycles` for `visit_hours` (first visit arrives early — the early-game safety valve, with a fixed steel-heavy profile from `data/traders/first_caravan.tres`). All trades run against the visiting trader's own inventory (`TraderData`) at prices snapshotted on arrival; committed trades fulfill incrementally on `slow_tick` while docked (charge/credit on fulfillment, never on commit), and the shared market settles the visit's **net** trades only at departure.
- `ContractManager` (WI-14, in progress): offers roll per trader visit (amounts scaled to station stores, premium over locked market price, deadline in cycles); accepting registers contract demand on the docking bay's `TradeComponent` so crew stage goods into the export bin and traders pick them up contract-first. Demand re-syncs lazily on `slow_tick` against whichever constructed bay exists — one mechanism covers accept, load, bay destruction, and replacement. Deadlines resolve on `cycle_changed`; completions feed a reputation counter held for future foreign-relations work.
- `EventManager` (WI-13, in progress): `EventData` .tres (`data/events/`) with conditions, weighted selection, cooldowns, and choice cards (`EventChoice` → `EventEffect` subclasses: credit deltas, market shocks, salvage spawns, happiness modifiers, contract offers). Rolls happen at cycle start plus one random mid-cycle hour, paced by `expected_cycles_between_events`; cards queue and show sequentially (pause-on-open). Station-wide happiness effects live here so late hires receive them and durations survive saves.

### 1.10 Persistence (WI-03)
`SaveManager` owns one versioned JSON file per slot in `user://saves/` (quick save/load bound to input actions). Each system contributes a section via `get_save_data()/load_save_data()`; current sections: `time`, `unlocks`, `resources`, `market`, `world` (modules incl. storage contents with instance data, construction progress, local upgrade tiers), `turbolifts`, `piles`, `pawns`, `crew`, `traders`, `events`, `contracts`.

- **Load strategy is teardown → rebuild:** the parsed save is stashed in a *static* (survives the scene swap), `main.tscn` reloads, and the fresh `SaveManager` applies sections deferred once the whole tree is ready. `SaveManager.is_loading()/has_pending_load()` guards spawn-on-ready code (starting module, starting crew) against duplication.
- **In-flight jobs are deliberately not saved** — the board repopulates from storage deficits/construction states within a tick. (Accepted trade-off for now; serialization is the eventual goal, §2.2.)
- Modules/resources are identified by `id: StringName` on their data resources; `SaveManager` builds id→definition lookups via `ResourceScanner` and warns on missing/duplicate ids. A `_migrations` version-step table exists, empty until the format changes.
- **Known persistence gaps:** asteroid state (ore mix, richness, designations) and `MiningComponent.priority_ore` aren't saved; transient happiness modifiers don't survive load (a modifier-driven pending resignation cancels as "recovered"); mid-ride turbolift pawns serialize at the cab's current floor.

### 1.11 UI
Build menu grouped by module tags; research panel; module info panel with per-component tabs; pawn info panel with needs/inventory/job/schedule tabs; clock + speed controls; alerts strip driven by `SignalBus.station_alert`; trader screen; contracts screen; event cards; turboshaft panel; crew recruitment; game-over screen; placement validity display with flip re-validation and stacked-cell click cycling (WI-10). Missing/future: minimap, main menu, settings, logistics/priority overlay.

---

## 2. Remaining Technical Goals

*(The 2026-07 goals for a simulation tick, save/load, job categories, needs generalization, and the pathfinding semantics decisions have all shipped — see §1. What follows is still open.)*

### 2.1 CONVEYED movement state
Position-ownership handoffs (turbolift rides; later trams/teleporter charge) become an explicit, serializable movement state instead of a suspended `await`. Rule adopted now: awaits stay for cosmetic waits (door animations); anything that *owns a pawn's position* gets an explicit state. Do it as part of the next major turbolift surgery, not standalone — until then the cab-floor save degradation (§1.10) covers save/load.

### 2.2 Save/load completeness
- Serialize in-flight job descriptors (cancel-on-save is painful for gameplay; the developer has confirmed serialization will eventually be necessary).
- Persist asteroids (ore mix, richness range, designations) and per-bay `priority_ore`.
- Persist happiness modifiers (or at least pending resignations caused by them).

### 2.3 Performance posture
Current scale (tens of modules, handfuls of pawns) makes almost nothing hot. The rules to keep it that way:
- No per-frame `get_nodes_in_group` scans in hot paths. The remaining offender is `PowerManager`'s per-`slow_tick` group scans — cache membership via registration signals when module counts grow; that also creates the natural home for per-module power priorities (life support last to brown-out).
- Reachability stays O(1) via subgraphs — protect this invariant.
- Job discovery stays event/claim-driven (the once-per-second search throttle in `PawnBase` plus board queues do this today).
- When storage counts grow: per-resource indices on `ResourceData.registered_storage` (already exists) instead of group scans in `Job_*` searches; unify the near-identical "find best storage/sustenance" loops into one query helper — they've already drifted subtly.
- Later job-selection evolution: utility score (priority + distance + pawn preference + age) evaluated at claim time only, never per-frame.

### 2.4 Testing & tooling
- Still zero automated tests. The godot-ai MCP plugin is installed (editor automation, `test_run`, `game_eval`); adopt **GUT or gdUnit4** minimally for the pure-logic classes: `ModuleGraph`, `StorageData`, `StatModifiers`, `MarketManager` pricing, `LocalUpgradeData` cost scaling, and now contract/event resolution rules.
- Debug hooks exist as input actions (quick save/load, `debug_fire_event`, `debug_offer_contract`) but the `toggle_console` action still has no console behind it. A minimal cheat console (spawn resource, spawn pawn, force unlock, timeskip) pays for itself immediately.
- Keep the typed-GDScript warnings on; they've caught real issues.

### 2.5 Rendering/UX debt
Truss hiding behind modules, solid/sparse tile rendering, module hover interiors, minimap, logistics/priority overlay (make storage-priority routing visible), main menu + settings screens. None block systems work; schedule opportunistically.

### 2.6 Cleanups on the radar
- Animations don't follow the sim time-scale (`AnimationPlayer.speed_scale` needs to track `TimeManager.speed`); `LinkedDoorState` may be leaking speed-changed callbacks.
- `AudioManager` is a scriptless placeholder — needs a real design (buses, module emitters, sim-time awareness) when the audio pass happens.
- `StructureManager.can_remove_module` is still disabled (under-construction modules aren't structure-connected), so a module can be deleted out from under the station.
- Extract magic group strings (`"resource_storage"`, `"power_consumer"`, …) into a constants file.

---

## 3. Conventions (for any implementing model)

- **Data lives in `.tres`** under `data/`; behavior in components; wiring in module scenes under `modules/`. New module = new scene + new ModuleData + (maybe) new component. Balance numbers live in data or exported vars, never code constants.
- Managers register into `Global`; cross-system events go through `SignalBus` typed signals. Don't add new autoloads without need.
- **Every new system ships its `SaveManager` section**, and every saveable data resource gets a stable `id: StringName`.
- New periodic behavior subscribes to `TimeManager` ticks (`slow_tick`/calendar signals), never `_process` polling; per-frame handlers scale by `Global.time_manager.scale(delta)`. Never `Engine.time_scale` or `get_tree().paused`.
- New job types declare a `JobBase.Category`. Jobs must never destroy carried resources on cancel — leftover cargo stays on the pawn for `Job_StoreInventory` or becomes a `ResourcePile`. After any cancel path, reservations must reconcile to zero (the `_ended` latch exists to guarantee this).
- Stat-affecting values on components are read through `owner_module.get_effective_stat(&"stat_name", base)` so upgrades apply (`ProcessorComponent.process_time` is the reference example).
- Directory scans for data discovery go through `ResourceScanner` (exported builds rename files).
- Comments in the codebase explain *why* (race avoidance in followup jobs, reservation semantics); match that bar.
- Tabs for indentation, `class_name` per script, typed everything (project warnings enforce it).
