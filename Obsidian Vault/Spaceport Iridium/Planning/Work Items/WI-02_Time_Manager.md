# WI-02 — Game Clock & Simulation Tick

## Goal
A `TimeManager` that owns game time (cycles/days + hours), pause and speed control, and coarse tick signals — then migrate the per-frame polling systems (power, storage job posting, needs decay, resource recalc, market drift) onto ticks. After this, "every N game-hours" is a one-liner anywhere, and fast-forward doesn't multiply per-frame work.

## Design decisions (make once, here)
- **Time base:** real seconds × speed = sim seconds. Constants: `SECONDS_PER_HOUR` (suggest 30 real seconds at 1× — a 24h cycle = 12 min; tune later, keep in one place), `HOURS_PER_CYCLE = 24`.
- **Speed:** `paused: bool` + `speed: float` (presets 0.5/1/2/4). Do **not** use `Engine.time_scale` (it distorts UI animation and input feel); instead TimeManager exposes `sim_delta` each frame and systems consume that. The existing `ui_time_scale_select.gd` is repointed at TimeManager.
- **Ticks:** `signal sim_tick(sim_delta: float)` every frame (scaled, 0 when paused), `signal slow_tick(interval: float)` at 4 Hz sim-time, `signal hour_changed(hour: int)`, `signal cycle_changed(cycle: int)`.
- Pausing stops sim signals entirely; `get_tree().paused` is no longer used for game pause (keep it only if you want a hard UI-freeze pause; process_mode juggling isn't worth it).

## Files to touch
- **New:** `scripts/managers/time_manager.gd`
- `scripts/managers/global.gd` — add `time_manager` slot
- `main.tscn` — add TimeManager node; remove the power call from `scripts/managers/main.gd`
- `scripts/managers/main.gd` — stop driving power per-frame
- `scripts/managers/power_manager.gd` — subscribe to `slow_tick` (power balance 4×/sec is plenty; consumers already latch `powered`)
- `scripts/managers/resource_manager.gd` — recalc on `slow_tick` instead of `_process`
- `scripts/managers/market_manager.gd` — replace `market_update_timer` with `hour_changed` (drift once per game-hour)
- `modules/components/storage_component.gd` — job-posting scan moves from `_process` to `slow_tick` subscription (UI bar update can stay in `_process` or move to `storage_changed`)
- `modules/components/processor_component.gd`, `construction_component.gd`, `sustenance_component.gd`, `mining_component.gd` — consume `sim_delta` (subscribe to `sim_tick` or read `Global.time_manager.sim_delta` in `_process`; pick ONE convention — recommendation: keep `_process` but multiply by `time_manager.speed_or_zero` factor, smallest diff)
- `pawns/pawn_needs_component.gd` — decay in game-hours: replace `hunger_duration_seconds` with `hunger_duration_hours` etc.
- `pawns/pawn_base.gd`, `pawns/pawn_movement_component.gd` — pawn motion and job processing consume scaled delta so pause/speed affects pawns
- `scripts/jobs/job_idle.gd` — its `create_timer(duration, false)` must respect pause/speed → use sim-time waits (`await Global.time_manager.sim_seconds(5.0)` helper)
- `ui/ui_time_scale_select.gd` — repoint to TimeManager; add clock display (or new `ui/clock_display.gd` + scene) showing "Cycle 3, 14:00"
- `scripts/managers/asteroid_manager.gd` — spawn cadence via sim time

## Implementation order
1. Create `TimeManager` with time accumulation, pause/speed, signals, `sim_seconds(duration)` await helper. Register in `Global`. Add to `main.tscn` **above** other managers.
2. Add clock UI (cycle + hour readout) wired to `hour_changed`/`cycle_changed`; convert the time-scale spinbox to pause + speed preset buttons calling TimeManager.
3. Introduce the delta convention: add `Global.time_manager.scale(delta)` (returns `delta * speed`, 0 when paused). Sweep every gameplay `_process(delta)` (components, pawns, jobs via `PawnBase._process`, asteroid drift) to use it. UI scripts keep raw delta.
4. Migrate PowerManager to `slow_tick` (note: `desired_power/consume_power/generate_power` take `delta` — pass the tick interval; batteries integrate over it. Verify battery charge math is per-second based, it is — throughput × delta).
5. Migrate StorageComponent posting scan and ResourceManager recalc to `slow_tick`; MarketManager to `hour_changed`; delete its Timer.
6. Convert `PawnNeedsComponent` durations to game-hours (hunger ≈ satisfied twice per cycle → full-to-empty ~10 game-hours).
7. `Job_Idle` and the turbolift door 2-second reopen delay (`module_turbolift.gd` `create_timer(2)`) → sim-time waits.
8. Playtest pass at 1×/4×/paused.

## Edge cases
- **Pause during pawn `await`s:** `PawnMovementComponent` awaits behavior hooks; those are driven by animation/timers. Sliding-door / turbolift animations use engine time — a pause mid-ride must not deadlock: cab movement consumes sim delta (freezes cleanly); door `AnimatedSprite2D` keeps playing while paused unless you set its `speed_scale` — acceptable v1, note it.
- **Speed change mid-tick:** slow_tick interval measured in sim seconds; changing speed changes real-time frequency — subscribers use the passed interval, so they stay correct.
- **`create_timer` audit:** grep for `create_timer(` — every gameplay use must convert (world_manager startup 1s hack, mining respawn Timer node, drone respawn, turbolift reopen). Timer *nodes* (mining_component `DroneRespawnTimer`, power generation fuel timer) can stay real-time in v1 **only if** their durations are short; better: scale `Timer.paused`/`wait_time` from TimeManager pause/speed — implement a small `SimTimer` wrapper if it gets messy.
- **hour_changed bursts at high speed:** at 4× a game-hour passes every ~7.5 real seconds — fine; but guard against multiple hour increments in one frame (accumulate then emit in a loop).
- Needs decay at 0 speed must be exactly 0 (no drift from float residue).

## Verification
1. Clock UI advances; 1 game-hour ≈ `SECONDS_PER_HOUR` real seconds at 1×, half that at 2×.
2. Pause: pawns freeze mid-corridor, processors stop mid-recipe (progress bar holds), power display static, needs static. Unpause resumes exactly.
3. 4× speed: a processor recipe completes in ¼ real time; hunger drains 4× faster; no error spam; frame rate stable (tick systems should not run 4× — verify slow_tick stays 4 Hz *sim*, i.e. 16 real Hz at 4×… decide and assert: interval is sim-time-based).
4. Power: build solar + processors; power display updates ≤4×/sec but modules still gate correctly on power loss (pull a generator: consumers stop within a tick).
5. Market prices drift once per game-hour (log or watch trade screen).
6. Fuel-burning fusion reactor consumes hydrogen at the same *game-time* rate at 1× and 4×.
7. Regression: full loop — mine, refine, build, construct, eat — at mixed speeds.
