# Bugs, Code Issues & Improvement Suggestions

*Found while reading the full codebase (2026-07-13). Bugs are ordered by severity. Fixes for the Confirmed list are bundled as [[WI-01_Bug_Fix_Pass]].*

---

## A. Confirmed Bugs

all fixed

## B. Design-Debt / Known-Disabled Code (already on your radar, confirming)

- `StructureManager.can_remove_module` check is disabled in `remove_module` because under-construction modules aren't structure-connected → you can currently delete a module out from under the station.
- Power system per-frame group scans (`main.gd` → `PowerManager.power_modules`) — your "shouldn't run every frame" TODO stands.
- `ResourceData.cached_total`/`global_total` are `@export`ed runtime state on shared resources — they get written into memory-shared .tres instances; harmless at runtime but confusing in the inspector and a save/load foot-gun. Consider stripping `@export` from runtime fields.

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

1. **Priority-as-routing needs a UI**: the ±99 construction/deconstruction priorities work, but players will eventually need to see/set storage priorities; a single "logistics" overlay showing storage priorities and current flows would expose the whole hauling system's mental model.
2. **Needs decay tuning**: hunger at 600s wall-clock will interact badly with time-scale changes; convert all need durations to game-hours when TimeManager lands.
3. **Job board spam guard**: storage posts one import job per resource at a time (good), but a fully-empty new storeroom posts for every allowed resource simultaneously; consider a per-module concurrent-notice cap (your design note about not spamming the board).
4. **Module removal refunds**: deconstruction returns 100% of materials; consider a configurable refund fraction later for balance.
5. **Teleporter**: exists as a module with behaviors but the design question "does it need its own storage buffer for resource transfer" is unresolved; suggest treating teleporters as a pawn-only shortcut group first (cheap, already supported by graph groups) and resource teleportation as a separate late-game unlock.
6. **Consider extracting magic groups** (`"resource_storage"`, `"power_consumer"`, `"sustenance_component"`, …) into a `Groups` constants file — typo-proofing for the group-string API surface.

## E. Open Questions (need your call, none block Phase 0)

1. Truss: real layer vs. visual placeholder? (Design doc leans placeholder.)
	1. Lets maintain as a placeholder. Truss "modules" are already used when other modules in the Module layer are removed and maintain design intent.
2. How aggressively should unpowered modules fail? (Currently: freeze. Options: decay stored goods, hurt happiness, life-support pressure later.)
	1. Yes, unpowered modules will have negative affects on the pawns and items stored in them.
