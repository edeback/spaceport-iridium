# Bugs, Code Issues & Improvement Suggestions

*Found while reading the full codebase (2026-07-13). Bugs are ordered by severity. Fixes for the Confirmed list are bundled as [[WI-01_Bug_Fix_Pass]].*

---

## A. Confirmed Bugs

all fixed

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
