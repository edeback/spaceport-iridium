# Bugs, Code Issues & Improvement Suggestions

*Found while reading the full codebase (2026-07-13). Bugs are ordered by severity. Fixes for the Confirmed list are bundled as [[WI-01_Bug_Fix_Pass]].*

---

## A. Confirmed Bugs

### A1. Failed placement still charges the player
`WorldManager.purchase_and_add_module()` (scripts/managers/world_manager.gd:72) withdraws the cost **before** calling `add_module()`, but `add_module()` has two failure paths (`is_blocked`, `cancel_add` from `overlap_module`) that free the module and return without refunding. Resources/credits vanish. `add_module` also returns `null` on failure (implicitly, via bare `return`) while being typed `-> ModuleBase`; callers never check.
**Fix direction:** validate placement first, or refund on failure; make `add_module` failure explicit.

### A2. Turbolift cab selection can crash (operator precedence + null deref)
`TurboliftShaft._best_cab_for()` (modules/transport/turbolift_shaft.gd:83-85), third fallback loop:
```gdscript
if cab.is_available() and best_cab == null or cab.get_available_capacity() < best_cab.get_available_capacity():
```
Parses as `(a and b) or c`. When `best_cab == null` and the cab isn't available, `c` dereferences `best_cab.get_available_capacity()` on null → crash. Logic is also wrong when best_cab is set (ignores availability). Same precedence pattern appears (harmlessly) in `split_at()` line 109.

### A3. Turbolift upper collision never disables
`ModuleTurbolift.set_sprite()` (modules/transport/module_turbolift.gd:60-65): both the if and else branches set `collision_upper.disabled = false`. The sprite index math is right, but the top-of-shaft collision is always on (or always off — either way, one branch is wrong).

### A4. Typed-signal emit with wrong type for space connections
`PathComponent.remove_connections()` (modules/components/path_component.gd:299-308) iterates `module_connections`, which can contain plain `Node2D` space nodes (added in `connect_doors()` line 268: `module_connections[space_node] = index`). It then emits `SignalBus.module_path_connection_removed.emit(owner_module, node)` — a signal typed `(from: ModuleBase, to: ModuleBase)` — with a `Node2D`. Runtime error when removing any module that has a direct-to-space door (airlocks).

### A5. Module scanning breaks in exported builds
`UIMain.get_all_file_paths_resourceloader()` (ui/ui_main.gd:80): `file_name.replace(".import", "")` discards its return value (strings are immutable) — and the real issue in exports is `.remap` suffixes on `.tres` files, which the `ends_with("tres")` check will miss. Build menu will be empty in an exported game. Same pattern in `UnlockManager._tres_paths()` uses `DirAccess`, which also needs `.remap` handling in exports.
**Fix direction:** one shared resource-scanning helper that strips `.remap`/`.import` and is used by both; or replace directory scanning with explicit registry resources.

### A6. `ModuleData.can_afford()` / cost withdrawal double-charges materials conceptually
For non-instant modules, `purchase_and_add_module` withdraws only credits, then `ConstructionComponent` requires the material resources to be *delivered* — but `can_afford()` still requires the full material cost to exist station-wide at click time, and those materials are not reserved. Two blueprints placed back-to-back can both pass `can_afford()` against the same steel. Minor now, worth a reservation or at least awareness.

### A7. `Job_MineAsteroid` can add a null-resource stack
`mine_asteroid()` (scripts/jobs/job_mine_asteroid.gd:144-152): `asteroid.mine_resource()` can return `null` (race: another drone empties it the same frame), but a `ResourceStack` is created unconditionally; `add_stacks(null, [stack])` silently drops it, and `resources_mined_count` still increments. Cosmetic, but masks the empty-asteroid case.

### A8. `PawnBase` PREDELETE spawns piles during teardown
`_notification(NOTIFICATION_PREDELETE)` (pawns/pawn_base.gd:162) unconditionally spawns a `ResourcePile` via `Global.world_manager` — on game exit this runs while the tree is being destroyed (null managers / freed parents → error spam). Guard with `is_instance_valid(Global.world_manager)` and empty-inventory check.

### A9. `ModuleGraph` vertices are `Object`s freed manually
`remove_vertex()` calls `old_vertex.free()` — `ModuleGraphVertex` extends Object (checked: scripts/utility/module_graph_vertex.gd), so anything still holding a reference (an in-flight path, `came_from` dict on another thread of logic) dereferences a freed object. Pathfinding results hold `PathPoint.node` (a Node2D, fine) not vertices, so today this is safe-ish, but `pathfind_to_node_in_space` leaks its temp vertex: it's appended to `_linked_groups["space"]` and erased after, but **never freed** → small object leak per space pathfind; and if pathfind throws/early-returns, it stays in the group list. Make vertices `RefCounted`.

### A10. `SustenanceComponent` never disables `_process`
Unlike siblings, it has no `set_process(false)` in preview/blueprint states (modules/components/sustenance_component.gd) — a mess hall blueprint tries to withdraw food every frame. Harmless-looking but wrong-state behavior; also `sustenance_available` isn't clamped against overfill if `sustenance_per_food` changes.

### A11. `Job_Eat` targets a component, eats from wherever it lands
`eat()` grabs `pawn.current_module.get_component_by_type(SustenanceComponent)` instead of using `target_component` — after `find_best_sustenance()` chose a specific one. If the pawn ends movement in a different module (repath, cab quirks), it silently eats from the wrong module or fails. Use the chosen component and re-validate it.

### A12. ~~Comment/behavior mismatch: post-job cooldown doesn't exist~~
`PawnBase._process` accumulates `job_length` **during** a job, so when the job ends, `job_length > 1.0` is already true and the next job starts next frame — the "don't start new jobs more than once a second" throttle only applies to consecutive *failed* searches. Works, but the comment lies; reset `job_length` in `_end_current_job()` if the cooldown is desired.
Response: This works as intended. It is not a post-job cooldown, it is a "don't start new jobs more than once a second" throttle. If the previous job has taken more than a second, we are free to take a _new_ job immediately once it has finished without waiting. The throttle is for when jobs are completed (or, more often, canceled) quickly or repeatedly in order to limit can_do_job checks. If the previous job took a while, this is unnecessary, however. Long jobs should go directly into new jobs without waiting.

## B. Design-Debt / Known-Disabled Code (already on your radar, confirming)

- `StructureManager.can_remove_module` check is disabled in `remove_module` because under-construction modules aren't structure-connected → you can currently delete a module out from under the station.
- `ModuleBase.enter_module_from` reaches into `Global.path_manager.graph._vertices[self]` (private, and KeyErrors if absent) — the "TODO hack for space things."
- `Global.gd` lines 54-85: dead scene-introspection experiments; `market_manager.gd` lives at project root instead of `scripts/managers/`.
- `WorldManager._startup()` awaits a 1-second timer before spawning the start module — manager-ordering hack; replace with explicit bootstrap ordering.
- `JobManager.find_job` `end_job()`s invalid jobs without `cancel()` — the exact lifecycle question from your notes; resolve as "cancel always, cancel implies end."
- Power system per-frame group scans (`main.gd` → `PowerManager.power_modules`) — your "shouldn't run every frame" TODO stands.
- `DockingBay` class is empty; docking is entirely the TradeComponent UI — fine until traders become entities.
- `ResourceData.cached_total`/`global_total` are `@export`ed runtime state on shared resources — they get written into memory-shared .tres instances; harmless at runtime but confusing in the inspector and a save/load foot-gun. Consider stripping `@export` from runtime fields.
- **WI-09 punted persistence**: asteroid state (ore mix, richness range, `designated` flag) and `MiningComponent.priority_ore` are not saved — asteroids aren't in save files at all, so designations and per-bay ore priority reset on load. Selected refinery recipe *is* saved (`ProcessorComponent.get_save_data`). Revisit if/when asteroids get persisted.

## C. Improvement Suggestions (code)

1. **One resource-scan helper** (fixes A5, dedupes `UIMain`/`UnlockManager` scanning, and future data types get it free).
2. **`ModuleGraphVertex` → RefCounted** (A9) and stop manual `free()`.
3. **Event-driven storage job posting**: `StorageComponent._process` runs the deficit/surplus scan every frame per storage; trigger it from `storage_changed` + a slow tick instead.
4. **Cache group membership** in `PowerManager` (listen to a `component_registered` signal or maintain arrays on ready_constructed/exit_tree) — also gives you a natural place for per-module power priorities later (life support last to brown-out).
5. **`Job_GetResource._find_export_storage`/`_find_deposit_storage`** and `Job_StoreInventory/_CollectPile` equivalents scan every storage node with `is_reachable` each — fine now; when storage counts grow, maintain per-resource indices on `ResourceData.registered_storage` (already exists!) instead of `get_nodes_in_group`.
6. **Unify the four near-identical "find best storage/sustenance" loops** (Job_GetResource ×2, Job_StoreInventory, Job_CollectPile, Job_Eat) into one parameterized query helper — they've already drifted subtly (priority comparisons differ).
7. **`ModuleBase.get_path_component()`** uses `get_node("PathComponent")` which errors on modules lacking one; use `get_node_or_null`.
8. **Naming**: `sort_priority_decending` (sp), `capacitator` → `capacitor`, `Poylmer` in design docs.

## D. Design Suggestions & Elaborations

1. **Solar exposure model**: current formula (free structure-connection sides / (connection_points+1)) is a neat proxy but invisible to the player. When you do placement-UX work, add a sun-exposure preview on solar panel placement, and consider day/night or orientation cycles once TimeManager exists — it creates the battery gameplay loop.
	1. Note: This is not invisible as the sprite used changes depending on number of connections. As there are more connections, fewer solar panels are seen in the sprite.
	2. Day/night makes sense for other games but not here as we are not orbiting a planet and therefore don't have day and night. A rare eclipse event could impact sun-exposure but not often and would require other work for it to be visible in-game.
2. **Trade gating**: moving from instant-trade to trader-present trade (design intent) changes early-game pacing a lot. Suggest an intermediate: orders can be *placed* anytime (queue into export bin), fulfillment happens on trader arrival — keeps UI usable and makes the docking bay's export bin meaningful.
3. **Priority-as-routing needs a UI**: the ±99 construction/deconstruction priorities work, but players will eventually need to see/set storage priorities; a single "logistics" overlay showing storage priorities and current flows would expose the whole hauling system's mental model.
4. **Ore richness is plumbed but unused** — refining ignores `OreInstanceData.richness`. This is a small, high-flavor win: yield multiplier on the ore refinery recipe (see [[WI-09_Ore_Variance_Refining]]).
5. **Needs decay tuning**: hunger at 600s wall-clock will interact badly with time-scale changes; convert all need durations to game-hours when TimeManager lands.
6. **`percent_critical` exists but interrupts are disabled** (the starvation-lock comment in PawnNeedsComponent is right). The fix isn't interrupting harder — it's making *food availability* a station alert so the player intervenes, plus letting critical pawns abandon jobs that aren't food-producing. Worth designing before implementing sleep the same way.
7. **Job board spam guard**: storage posts one import job per resource at a time (good), but a fully-empty new storeroom posts for every allowed resource simultaneously; consider a per-module concurrent-notice cap (your design note about not spamming the board).
8. **Module removal refunds**: deconstruction returns 100% of materials; consider a configurable refund fraction later for balance.
9. **Teleporter**: exists as a module with behaviors but the design question "does it need its own storage buffer for resource transfer" is unresolved; suggest treating teleporters as a pawn-only shortcut group first (cheap, already supported by graph groups) and resource teleportation as a separate late-game unlock.
10. **Consider extracting magic groups** (`"resource_storage"`, `"power_consumer"`, `"sustenance_component"`, …) into a `Groups` constants file — typo-proofing for the group-string API surface.

## E. Open Questions (need your call, none block Phase 0)

1. Truss: real layer vs. visual placeholder? (Design doc leans placeholder.)
	1. Lets maintain as a placeholder. Truss "modules" are already used when other modules in the Module layer are removed and maintain design intent.
2. Generic Factory module vs. per-recipe modules? (Tech spec leans per-recipe modules sharing ProcessorComponent.)
	1. I'm aiming for a combination of the two. Different factory _types_ will allow different recipes. This allows some flexibility in resource creation.
3. Should pawns path to *positions* within modules (needed for beds/workstations) — yes eventually; WI-05 assumes "stand anywhere in module" is acceptable for sleep v1.
	1. Yes. Ideally there will be specific points added to the modules to indicate specific places for pawns to move to.
	2. *Planned (2026-07-14):* exactly this, as micro-graph **anchors** (authored + runtime-generated) — see [[WI-16_Micro_Anchors_and_Pawn_Positioning]]. The related group-overloading fix (construction stealing the "space" group) is [[WI-15_Pathfinding_Exterior_Semantics]]; both summarized in tech-spec §2.6.
4. Save/load scope for in-flight jobs: serialize descriptors vs. cancel-on-save? (Spec recommends cancel-on-save v1.)
	1. Cancel-on-save for now but serialization will eventually be necessary as the gameplay impacts for cancelling all jobs is very painful.
5. How aggressively should unpowered modules fail? (Currently: freeze. Options: decay stored goods, hurt happiness, life-support pressure later.)
	1. Yes, unpowered modules will have negative affects on the pawns and items stored in them.
