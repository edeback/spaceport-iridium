# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Spaceport Iridium is a 2D Godot 4.7 (GDScript) game: a cross between SimTower (build a space station one module at a time, viewed as a side-on vertical cross-section) and Dwarf Fortress/RimWorld (manage a population of pawns, fulfill their needs, keep them happy). Station residents move between modules via corridors/turbolifts and go outside through airlocks to mine asteroids or construct modules.

## Planning documents

`Obsidian Vault/Spaceport Iridium/Planning/` holds the authoritative plans: design doc, technical spec, roadmap, `03_Bugs_and_Improvements.md` (known issues), and per-task implementation docs (`Work Items/WI-01…WI-14`) meant to be implemented in order. Check the relevant WI doc before starting feature work. The rest of the Obsidian Vault is raw design notes.

## Running & verifying

- No build step, no test framework, no linter beyond the editor. Typed-GDScript warnings (`untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`) are enabled in project.godot — keep everything typed.
- Run: open in the Godot editor and play `main.tscn`, or `godot --path .` from the repo root. Export preset: `"Windows Desktop"`.
- The godot-ai MCP plugin is installed. Typical verify loop from a Claude Code session: `project_run` → `logs_read(source="game")` / `logs_read(source="editor")` → `game_manage` (inspect nodes, read UI text, send input) → `project_manage(op="stop")`.
  - After creating a **new file with a `class_name`**, run `filesystem_manage(op="scan")` before `project_run`, or the class won't resolve ("Could not find type X in the current scope").
- **Unit tests (GUT, WI-19):** GUT is vendored at `addons/gut/`; pure-logic suites live in `tests/unit/`. Run headless: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` (exits 0 all-green, non-zero on any failure). If new `class_name` files were added since the last editor open, run `godot --headless --import` once first so the global class cache resolves. Tests cover the pure classes only (`ModuleGraph`, `StorageData`, `StatModifiers`, `LocalUpgradeData` cost scaling, `MarketManager` pricing, `ContractData`/`EventData` rules) — construct them directly, don't touch `Global`/`SignalBus`. Keep test code fully typed; `tests/` and `addons/gut/` are excluded from the export preset.
- **Cheat console (Panku, WI-19):** the backtick key opens Panku's REPL in-game; `Global.cheats.<method>(...)` drives `Cheats` (`scripts/utility/cheats.gd`) — `spawn_resource`, `spawn_pawn`, `force_unlock`/`unlock_all`, `add_credits`, `set_time_speed`, `advance_hours`, `fire_event`, `offer_contract`. Every call emits a `station_alert` "CHEAT: …" so a save that used them is self-documenting. Enabling the Panku editor plugin registered the `Panku` autoload; Main installs `Global.cheats` and registers `Global` with the REPL. **Pass ids as plain strings, not `&"…"`** — Godot's `Expression` (what the REPL runs) rejects StringName literals but coerces `String`→`StringName` on the call, e.g. `Global.cheats.spawn_resource("iron_ore", 50, Vector2i(16,8))`.
- `ModuleBase._ready` prints module ids and the scene-embedded starter pawns log a known "Node needs a parent to be reparented" error at boot — pre-existing noise, not a regression signal.

## Architecture

Composition over inheritance, uniformly. New features = new component + new `JobBase` subclass + new `.tres` data, not new class hierarchies.

**Managers** — `Global` and `SignalBus` are the only autoloads. Every other manager (`WorldManager`, `PathManager`, `StructureManager`, `PowerManager`, `JobManager`, `TurboliftManager`, `ResourceManager`, `MarketManager`, `AsteroidManager`, `UnlockManager`, `TimeManager`, `CrewManager`, `TraderManager`, `SaveManager`, `EventManager`, `ContractManager`) is a node in `main.tscn` under `Managers/` that registers itself into `Global.<name>` in `_ready()`. Tree order = ready order; `TimeManager` must stay first. Cross-system events go through `SignalBus` typed signals.

**Modules** — a module is a scene rooted in `ModuleBase` (`modules/templates/module_base.gd`) composed of child components (`modules/components/`): storage, processor, construction, path, structure, power gen/consumption, battery, mining, sustenance, trade, etc. Module *identity* is a `ModuleData` resource (`data/modules/**/*.tres`) carrying costs, tags, layers, and the scene reference. The build menu, unlock trees, and local upgrades are discovered by scanning `data/` directories via `ResourceScanner` (handles exported-build `.remap` suffixes — don't hand-roll directory scans).

**Grid & layers** — `WorldManager` tracks cell→module maps per `StructureLayer` (MODULE, CORRIDOR, TURBOLIFT, SPACE); one cell can hold a module, a corridor, and a turbolift simultaneously. Truss is a placeholder module auto-placed when a real module is removed. Module lifecycle is Preview → Blueprint (construction site) → Built; components implement `ready_preview/ready_blueprint/ready_constructed`.

**Pathfinding** — two separate `ModuleGraph`s: `PathManager` (pawn traversal) and `StructureManager` (physical attachment). The graph supports vertex *groups* (e.g. `"space"`, `"turboshaft_N"`) whose members are implicitly interconnected with a per-group cost multiplier, plus subgraph ids for O(1) `is_reachable` checks — jobs rely on that being cheap. Within a module, `PathComponent` holds an interior `AStar2D` micro-graph, doors mapped to layers, and `PathBehavior` strategy objects (sliding doors, turbolift rides) that `PawnMovementComponent` awaits during traversal.

**Jobs & hauling** — modules post `JobBase` subclasses (`scripts/jobs/`) to `JobManager`'s priority-sorted board; pawns claim and drive them as state machines via `process_job(delta)`. `StorageComponent` posts pull/push jobs from desired-amount deficits/surpluses; **storage priority is the routing language** (construction imports at +99, deconstruction exports at −99, sinks must out-priority sources). Followup jobs and queued needs go through the pawn's personal `job_queue`, never the board. Resource stacks (`ResourceStack` + optional `ItemInstanceData`, e.g. ore richness) move physically: storage → pawn inventory → storage, with reservations on both ends.

**Time** — `TimeManager` owns game time (cycles/hours, `SECONDS_PER_HOUR`), pause, and speed. Rules: per-frame gameplay `_process` handlers multiply delta by `Global.time_manager.scale(delta)` and early-return on 0; periodic scans subscribe to `slow_tick`; calendar behavior uses `hour_changed`/`cycle_changed`; one-shot waits use `await Global.time_manager.sim_seconds(x)`, never `get_tree().create_timer()`. Never use `Engine.time_scale` or `get_tree().paused` — UI stays real-time.

**Unlocks** — `UnlockManager` holds global tech-tree state (`UnlockData` .tres + `UnlockEffect`s) and per-module `LocalUpgradeData`; both feed a `StatModifiers` layer per module instance. Components read tunable stats through `owner_module.get_effective_stat(&"stat", base)` so upgrades apply non-destructively.

## Invariants

- Jobs must never destroy carried resources on cancel: leftovers stay on the pawn (swept by `Job_StoreInventory`) or become a `ResourcePile`.
- Job `cancel(as_failed)` releases the job's storage reservations; after any cancel path, `reserved_withdraw`/`reserved_deposit` must reconcile to zero.
- Placement pays only on success: `WorldManager.add_module` returns null on failure and `purchase_and_add_module` withdraws after. `overlap_module()` has side effects (truss removes itself), so placement can't be pre-validated twice.
- Balance numbers belong in `.tres` data or exported vars, not code constants.
- Tabs for indentation; `class_name` on every script; comments explain *why* (race avoidance, reservation semantics), matching the existing bar.
