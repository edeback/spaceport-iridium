# WI-18 — Game Start & Bootstrap Cleanup

## Goal
Remove the magic `await get_tree().create_timer(1.0)` before the starting station spawns (`WorldManager._startup`) and replace it with explicit, deterministic bootstrap ordering. Everything downstream (menu→game transitions in WI-36, deterministic tests in WI-19, save/load timing) gets simpler once "the game is ready" is a defined moment instead of a guessed one.

## Design
- **The root node is the natural barrier.** In Godot, a parent's `_ready` runs after all children's. `main.tscn`'s root (`scripts/managers/main.gd`) is therefore the first code that can rely on *every* manager having registered into `Global.*`. Move the starting-station spawn call there: `Main._ready()` → `Global.world_manager.spawn_starting_station()` (the current `_startup` body minus the timer, made public). `WorldManager._ready` keeps only layer setup.
- **Kill the deferred-hop guesswork.** `seed_starting_atmosphere.call_deferred()` and CrewManager's "react to module_added because we can't know the ordering" workaround exist *because* startup timing was fuzzy. Keep the signal-driven crew spawn (it's robust, not a hack), but atmosphere seeding can become a direct call at the end of `spawn_starting_station()` once the starter modules are placed synchronously — if any starter module still defers component readiness (`add_module(..., defer_ready)`), seed after an explicit `await get_tree().process_frame` with a comment saying exactly which deferral it is waiting out, replacing "2 sim-seconds registration window" fuzz in AtmosphereManager if it becomes redundant.
- **One "game ready" signal.** `SignalBus.game_bootstrapped` emitted by Main after either (a) starting station spawned, or (b) `SaveManager` applied a pending load. UI that currently self-arms on `_ready` can stay as-is; new systems (tests, WI-36 loading screen) get a real hook.
- **Known boot noise:** the "Node needs a parent to be reparented" error from scene-embedded starter pawns (see CLAUDE.md) — if any pawns are still embedded in scenes rather than spawned by CrewManager, remove them as part of this WI so boot logs are clean. A clean boot log is the acceptance bar: this WI is done when `logs_read` after a fresh run shows no startup errors.

## Files to touch
- `scripts/managers/main.gd` — bootstrap orchestration, `game_bootstrapped` emission
- `scripts/managers/world_manager.gd` — `_startup` → public `spawn_starting_station()`, timer removed
- `scripts/managers/atmosphere_manager.gd` — retire the registration-window fuzz if the deterministic seed makes it dead
- `scripts/managers/signal_bus.gd` — `game_bootstrapped`
- `scripts/managers/save_manager.gd` — `_apply_pending_load` emits/coordinates with `game_bootstrapped`
- Any scene still embedding starter pawns (check `main.tscn`)

## Implementation order
1. Extract `spawn_starting_station()`; call from `Main._ready()`; delete the timer.
2. Run and fix whatever the timer was actually papering over (likely tilemap/terrain or deferred component readiness) — fix each cause explicitly rather than re-adding a wait.
3. `game_bootstrapped` signal, emitted on both the new-game and load paths.
4. Boot-noise cleanup (embedded pawns, ModuleBase `print(module_id)` debug print at `module_base.gd:93` can go too).

## Edge cases
- Load path: `spawn_starting_station()` must still early-return when `SaveManager.has_pending_load()` — the save's world section places everything.
- CrewManager's `module_added` starting-crew hook must still fire: starter modules now appear earlier in the frame, but the signal path is unchanged.
- Atmosphere seeding vs. construction-capable starter modules running `ready_blueprint` deferred — this is the one deferral most likely to still need a single-frame wait; document it where it lives.
- `filesystem_manage(op="scan")` not needed (no new class_name), but a full quicksave→quickload cycle is part of verification since load ordering is touched.

## Verification
1. Fresh run: starting station appears immediately (no 1s dead air), crew spawn, atmosphere seeded at full O2 (`Global.atmosphere_manager.debug_dump()`), zero errors in `logs_read(source="game")`.
2. Quicksave → quickload: identical station restored, no double-spawned crew, no double-seeded atmosphere.
3. Run at 4× speed from boot — no ordering race appears when the first sim frames are large.
4. Regression: construction of a new module, hire flow, and trader arrival all work post-change (they consume the managers whose ready order was touched).
