# WI-17 — Life Support: Oxygen & Atmosphere

## Goal
Per-module atmosphere simulation: O2 and CO2 with pressures, quick diffusion between connected modules (implicit vents — no player-built ducting), crew breathing (O2 → CO2) with suffocation damage at low O2, two restoration machines (regenerative O2 scrubber: CO2 → O2; O2 generator: consumes stored `oxygen` resource to raise pressure), and hull-breach venting driven by events (combat hooks in later). Crew in space are exempt — assume suit supply (personal O2 tanks limiting EVA time are a future WI, not this one).

## Design
- **Atmosphere model — two gases, abstract units.** `AtmosphereComponent` (new, `modules/components/`) holds `o2: float`, `co2: float`; `volume` = footprint cell count; `pressure = (o2 + co2) / volume`, per-gas partials likewise. Nominal pressure/breathable-O2/damage/flee thresholds are exported tunables (balance in .tres/exports per the invariant). No inert gas needed: breathing and scrubbing are both 1:1 conversions, so they hold total pressure flat (matching "scrubber restores breathable air but doesn't increase pressure"); only the generator raises pressure and only breaches/expansion lower it. High CO2 is never directly toxic — it harms by displacing the O2 partial, which is emergent.
- **Who has atmosphere:** built, pawn-enterable interior modules — the shared templates (`module_1x2` etc.), hallway, stairs, turbolift, airlocks, docking bay, starting module, crew/processor modules. Truss and exterior hardware (solar panel) don't. Previews and blueprints have none; on `ready_constructed` the module registers at **zero pressure** and fills via diffusion — expanding the station dilutes the air, which is exactly the pressure sink the O2 generator exists to fight. At new-game start (not load), the starting-station modules seed at max pressure.
- **`AtmosphereManager`** (new manager node in `main.tscn` under `Managers/`, `Global.atmosphere_manager`): registry of live AtmosphereComponents; runs diffusion in `_process` scaled by `Global.time_manager.scale(delta)` (early-return on 0). Adjacency comes from PathManager's graph: door edges between two registered modules, plus turbolift-shaft group cliques (treated as ordinary links). Exterior vertices and space never exchange — the only path to space is a breach. Per-gas flow: `k * (partial_a − partial_b) * dt`, clamped so a tick never overshoots equalization; `k` tuned "fairly quick" (a hallway reaches ~90% of neighbor pressure within a game-hour).
- **Breathing:** new `PawnBreathingComponent` on the crew scene only (drones/robots don't get one). Each tick converts a tiny O2 → CO2 amount in `owner_pawn.current_module`'s atmosphere. Skipped when the pawn is in space/exterior or has no current module (shuttle transit). When local O2 partial < damage threshold, `PawnHealthComponent` applies `suffocation_decay_per_hour` instead of regen — same pattern as starvation (rates stack if both; regen never applies while either is active). `SignalBus.pawn_critical_need` / `station_alert` fire as usual via the health critical path.
- **Idle crew flee:** when a crew pawn is idle (Job_Idle/Job_IdleWander or no job) in a module below the flee threshold, BreathingComponent interrupts with a `Job_MoveToLocation` to the nearest breathable module (`PathManager.run_pathfinding_by_func` over atmosphere state). Working crew finish their jobs — player's problem to notice. Check throttled (on `module_changed` + a per-sim-second recheck, never per-frame pathfinding); if nothing breathable is reachable, stay put and retry on a cooldown — no thrashing.
- **O2 Scrubber — `OxygenScrubberComponent`:** converts local CO2 → O2 at `scrub_rate_per_hour` (via `get_effective_stat` so upgrades apply), limited by available CO2. Powered via `PowerConsumptionComponent`; unpowered = stops, CO2 accumulates. The **starting module gains one** (safety net sized for the starting crew). Also a buildable standalone `o2_scrubber` module for expansion.
- **O2 Generator — `OxygenGeneratorComponent`:** powered; input `StorageComponent` with a desired amount of the existing `oxygen` resource (normal sink priority — well below construction's +99; haulers feed it via the standard pull-job flow, supply chain = electrolysis processor or traders). While **local** pressure < an exported target setpoint, consumes stored oxygen and releases it into the local atmosphere (diffusion spreads it); hysteresis band around the setpoint so it doesn't flap. New `modules/life_support/o2_generator.tscn` + mdata, unlocked in the industrial tree near the electrolyzer.
- **Hull breach:** state on AtmosphereComponent (`breach_remaining_hours`). While breached, the module leaks both gases to space at a fast exported rate (module hits near-vacuum in well under an hour; diffusion then drags neighbors down — station-wide slow bleed). **Timed self-seal:** emergency bulkheads close after N game-hours, then the station re-equalizes (repair jobs arrive with combat, later WI). Trigger v1: new `EffectHullBreach` EventEffect (random eligible built module with atmosphere) + a "Micrometeorite Strike" event .tres. `SignalBus` gains `module_breach_started/module_breach_sealed`; alerts on both.
- **UI:** AtmosphereComponent implements `has_ui`/`get_ui` — module panel tab showing total pressure, O2/CO2 partials, breach countdown. Station alert when any module crosses the low-O2 threshold (throttled, once per module per episode). Full station atmosphere overlay = stretch/later.

## Files to touch
- **New:** `modules/components/atmosphere_component.gd/.tscn`, `oxygen_scrubber_component.gd/.tscn`, `oxygen_generator_component.gd/.tscn`
- **New:** `scripts/managers/atmosphere_manager.gd` + `Global` slot + `main.tscn` (after PathManager in tree order — it reads the path graph)
- **New:** `pawns/pawn_breathing_component.gd` (+ crew pawn scene; NOT the mining drone scene)
- **New:** `modules/life_support/o2_generator.tscn`, `o2_scrubber.tscn`; `data/modules/life_support/*_mdata.tres`; `data/unlocks/industrial_tree/` entries
- `modules/special/starting_module.tscn` — add OxygenScrubberComponent (+ its power consumption)
- Module templates & interior scenes (`modules/templates/*.tscn`, hallway, stairs, turbolift, airlocks, docking bay, crew/processor modules) — add AtmosphereComponent
- `pawns/pawn_health_component.gd` — suffocation decay branch beside starvation
- `scripts/managers/signal_bus.gd` — breach signals
- `data/events/effects/effect_hull_breach.gd` + `data/events/micrometeorite_strike.tres`
- `ui/windows/component_ui_panels/atmosphere_component_ui.gd/.tscn`
- `modules/templates/module_base.gd` — atmosphere section in `get_save_data`/`load_save_data` (same pattern as processor/trade)
- Remember: `filesystem_manage(op="scan")` after each new `class_name` file before running

## Implementation order
1. AtmosphereComponent + AtmosphereManager: registration, new-game seeding, diffusion over the path graph, debug readout (console print or F-key dump).
2. Breathing + suffocation damage + space/exterior exemption + alerts.
3. Scrubber component; wire into the starting module; power hookup; verify closed-loop equilibrium with starting crew.
4. O2 generator: component + input storage + module scene + mdata + unlock + build-menu appearance (ResourceScanner picks up the data dir).
5. Breach: vent state, EffectHullBreach, starter event, self-seal, signals/alerts.
6. Idle-crew flee.
7. Atmosphere UI panel; save/load section.

## Edge cases
- Scrubber alone can't outrun a breach (it conserves pressure) — intended; verify messaging pushes the player toward the generator.
- Diffusion + scrubber + generator running together must reach a stable equilibrium, not oscillate (clamped flows, hysteresis on the generator setpoint).
- Module deleted (or deconstructed) while holding gas → gas destroyed with it, breach state discarded; the cell becomes truss, so neighbors simply lose a diffusion edge (no back-fill, no leak). Verify no dangling registry entry.
- Breached module deleted mid-breach → breach dies with it.
- Pawn's `current_module` is a module without atmosphere → breathing no-ops, no damage (covered by suit assumption).
- Crew asleep/eating in a venting module are *not* idle — they take damage until the job ends, then flee. Acceptable v1; note for playtest.
- Idle flee retargets if the refuge module also drops below threshold; if no reachable breathable module exists, cooldown retry — no pathfinding spam.
- Generator input jobs must not starve construction imports (+99 rules) and must stop posting once local pressure sits at setpoint (desired amount stays, stock just stops draining — fine).
- Two breach events on the same module → refresh/extend the timer, don't stack leak rates.
- Save/load: gas amounts + breach remaining-hours per module; mid-flee pawn just re-evaluates on load (Job_MoveToLocation already persists or is safely dropped — verify which).
- Unpowered scrubber AND generator during a brown-out → CO2 climb is the intended death spiral; verify the alert fires well before damage starts.
- Blueprint completing mid-breach next door → registers at vacuum, immediately participates in diffusion (drains neighbors faster) — fine, but verify no NaN/negative gas from the double sink.

## Verification
1. New game: starting module seeded at full O2; crew breathe; scrubber holds O2 steady over several cycles at 4× speed (log O2/CO2 partials — they plateau, don't drift).
2. Build a run of hallways + a sleeping pod → new modules fill by diffusion, station pressure drops proportionally; build + supply an O2 generator (electrolyzer chain or trader-bought oxygen) → pressure recovers to setpoint and holds.
3. Cut scrubber power → CO2 rises/O2 falls station-wide, low-O2 alert fires, crew health decays past the threshold; restore power → recovery, health regens.
4. Force-fire the breach event (`Global.event_manager.fire_event_by_id`/F6): breached module vents to near-vacuum fast, neighbors sag slower, self-seal at the timer, generator refills the station. Alerts on open and seal.
5. Idle crew in the breached module walks to a breathable one; a crew member mid-job stays until the job completes; a drone parked in vacuum takes no damage; a miner EVA in space takes no damage.
6. Save/load mid-breach at half timer and mid-recovery → pressures and breach countdown resume exactly
7. Regression: construction hauling priorities unaffected by generator demand; module add/remove keeps AtmosphereManager registry consistent (no errors in `logs_read`); pathfinding perf unchanged (diffusion iterates edges, not group scans, per the performance posture).
