# WI-03 — Save/Load System

## Goal
A central `SaveManager` that serializes the full game state to versioned JSON in `user://saves/`, with per-system save sections following the pattern `UnlockManager` already implements (`get_save_data()` / `load_save_data()`). V1 scope: everything needed to quit and resume a session — modules (with construction state, storage contents, upgrades), pawns (position, needs, inventory), global resources, market, unlocks, time. **In-flight jobs are NOT serialized** — on save, jobs are simply not persisted; on load, the board repopulates naturally from storage deficits/construction states within a tick.

## Prerequisites / decisions
- **Stable ids:** add `@export var id: StringName` to `ModuleData` and `ResourceData` (like `UnlockData.id`). Populate every `.tres` (18 resources, ~30 modules — mechanical edit; the id should match the file stem, e.g. `&"ore_processor"`). `SaveManager` builds id→resource lookups via the `ResourceScanner` from WI-01. Warn on empty/duplicate ids at startup.
- **Format:** single JSON file per save slot: `{version, timestamp, sections: {time, resources, market, unlocks, world, pawns}}`. Human-readable while debugging; move to binary later if size demands.
- **Load strategy:** full teardown → rebuild. Loading starts from a clean scene (reload `main.tscn`), then applies sections. Do not try to diff/patch a live world.

## Files to touch
- **New:** `scripts/managers/save_manager.gd`
- `scripts/managers/global.gd` — `save_manager` slot
- `main.tscn` — SaveManager node
- `data/modules/module_data.gd`, `data/resources/resource_data.gd` — `id` field; every `.tres` under `data/modules/`, `data/resources/` — set ids
- `scripts/managers/world_manager.gd` — `get_save_data()`: iterate `id_to_module`; `load_save_data()`: re-place modules via `add_module` (bypassing purchase); suppress `_startup()` when loading
- `modules/templates/module_base.gd` — per-module `get_save_data()/load_save_data()` aggregating component data + existing `get_upgrade_save_data()`
- `modules/components/storage_component.gd`, `storage_data.gd` — serialize `storage_data` per resource: stored stacks (amount + instance_data), desired. Reserved amounts and jobs are NOT saved (jobs aren't persisted)
- `data/resources/resource_stack.gd` / `item_instance_data.gd` / `ore_instance_data.gd` — `to_dict()/from_dict()` for instance data (type tag + fields; v1 knows `ore` richness and generic)
- `modules/components/construction_component.gd` — save `current_state`, `work_seconds_done`
- `pawns/pawn_base.gd`, `pawn_needs_component.gd`, `pawn_inventory_component.gd` — save position, `current_module` (by module save-id), need values, carried stacks
- `scripts/managers/unlock_manager.gd` — already done; SaveManager calls its dict API (turn `auto_persist` off by default permanently; slot save owns persistence now)
- `scripts/managers/market_manager.gd` — stock per resource id
- `scripts/managers/time_manager.gd` — cycle/hour/speed
- UI: pause-menu or debug buttons for Save/Load (minimal: two buttons + slot name field; `ui/ui_main.gd`)
- `scripts/managers/turbolift_manager.gd` — nothing saved; shafts rebuild automatically as lift modules re-add themselves (verify)

## Implementation order
1. Ids on ModuleData/ResourceData + startup validation + lookup tables in SaveManager.
2. Stack/instance-data `to_dict/from_dict`.
3. Module save: WorldManager section. Save order per module: id, cell, `is_horizontal`, flipped (must be **stored on ModuleBase at placement** — currently flip choice isn't retained; add `var flipped: bool` set in `add_module`), build_state, construction progress, storage, upgrades. **Runtime pawns-in-scenes caveat:** `PawnStorageComponent.ready_constructed()` spawns pawns — on load this would double-spawn; add a `spawning_suppressed` flag SaveManager sets during load (pawns come from the pawn section instead).
4. Pawn save/load (skip `MiningDronePawn` — drones are respawned by their `MiningComponent`; mark drones with a `transient` flag checked by the pawn serializer; their cargo is acceptable loss v1).
5. Manager sections (resources global totals — credits use `has_global_store`, market, unlocks, time).
6. Load flow: `SaveManager.load_slot(name)` → store pending data → `get_tree().reload_current_scene()` → managers `_ready` → SaveManager applies sections in order: time → unlocks → resources/market → world (modules) → pawns. Ordering matters: unlocks before world so granted-module checks and global stat modifiers exist before `ready_constructed` runs (`apply_global_modifiers` is called there).
7. Save/Load UI + F5/F9 debug bindings.
8. Version field + a `migrations: Dictionary[int, Callable]` stub.

## Edge cases
- Module mid-construction with partially delivered materials → storage section restores delivered amounts; `ConstructionComponent` must transition to the right state (`NotStarted` with materials → posts job next tick; `Constructing` → **downgrade to NotStarted if work started but job is gone** — simplest: save work_seconds_done and let `ready_for_construction()` re-post; it will, since state NotStarted re-checks).
- Deconstructing module (`Deconstructing`/`Deconstructed` states) — reload as `Deconstructed` with its export storage; verify the removal path resumes.
- Pawn saved inside a turbolift cab / mid-space-EVA → v1 rule: on load, pawns whose `current_module` is gone or who were in transit spawn at their last position with `current_module = null` (space) if no module at that cell; they will path home via airlock. Document this as acceptable.
- Pawn carrying stacks with ore instance data → richness survives round-trip.
- A `.tres` id renamed between save and load → warn and skip that module/resource, don't crash the load.
- Overflow `ResourcePile`s: v1 decision — save piles (position, contents, parent module by id) or drop them? Recommend **save them**; they're player-visible property. Files: `data/resources/resource_pile.gd` to_dict/from_dict + a piles subsection of world.
- Saving while paused (WI-02) → time section stores paused state; load resumes paused.
- Two modules occupying same cell across layers (corridor over module) → order within world section is placement-order (`id_to_module` insertion order); hallway auto-placement in `connect_doors` must be suppressed during load (modules load with their connections re-derived — `make_connections` runs in `ready_constructed`; auto-hallway only triggers when `door_required` and no module present, which after full load is satisfied; ensure module load order = all modules placed *then* `ready_constructed` pass, two-phase, to avoid order-dependent door hookups).
- **Two-phase load is the big one:** phase 1 instantiate/place all modules in Blueprint-suppressed mode; phase 2 call `ready_constructed`/`ready_blueprint` per saved state. `WorldManager.add_module` currently auto-calls these — add an optional `defer_ready: bool` parameter.

## Verification
1. Build a station (10+ modules: storage with mixed contents incl. rich ore, one module mid-construction, one turbolift shaft, mining bay with drones, upgraded processor, some unlocks purchased). Save. Quit to desktop. Relaunch, load: station identical — check module positions, storage tabs, upgrade tiers, research panel state, credits, clock.
2. Within one slow-tick of loading, hauling jobs repopulate (watch pawns resume work) and the under-construction module continues.
3. Save/load twice back-to-back (load → immediately save → load) → stable (no drift/duplication — especially pawn count and truss tiles).
4. Corrupt the JSON (truncate) → load fails gracefully with a warning, game stays at current state.
5. Load a save after deleting one module `.tres` id → warning logged, rest of station loads.
6. File inspection: JSON contains no engine paths for ids (only StringName ids), version field present.
