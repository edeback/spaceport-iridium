# WI-45 — Save System Audit

> **Status: COMPLETE (2026-07-30).** All seven findings fixed. Closes **D8** in [[03_Bugs_and_Improvements]] ("audit for unsaved stateful systems"). 505 GUT tests green (484 baseline + 21 in `tests/unit/test_component_persistence.gd`). Save format: three new module keys (`power_consumption`, `power_generation`, `mining`), all absent-key-means-pristine, plus the storage block's nested shape with its legacy branch — pre-WI-45 saves load unchanged and no `SAVE_VERSION` bump was needed.
>
> Deviations and notes:
> - **`ProcessorComponent._yield_residue` is saved, reversing this WI's own first draft** (user call, and the right one). The draft declined it as noise because each entry is under one unit; the rule that actually governs is *no resource loss without a player action that loses them*, which has no size threshold. See A2. This is the only finding whose disposition changed after the doc was written.
> - **A3 turned up a live deadlock the design only half-anticipated.** Restoring `_fuel_seconds_left` without also restoring `powered` leaves a fuel generator dark *forever*: `restart_generation()` only sets `powered = true` on the tick it withdraws a **fresh** unit, and `generate_power()` only burns fuel *while* powered — so a half-burnt generator restored at `powered == false` never burns, never empties, and never re-withdraws. The load path mirrors `disable_generation`'s resume branch to close it, and `test_restored_fuel_comes_back_powered` pins it. Note this was *introduced* by saving the fuel, not pre-existing — before this WI the field always restored as 0 and the generator withdrew a fresh unit.
> - **A2**: the two recipe restores (`recipe`, then `pending_recipe`) are split around the `processing` restore rather than done together, because `select_recipe()` decides queue-vs-apply from `processing`. Both go through one `_load_recipe(path, queued)` helper so the not-in-`available_recipes` warning is written once.
> - **A4**: `get_save_data` now always returns a non-empty dict (it always carries `priority`), so every storage component gets a block where previously an empty bin wrote nothing. Deliberate — priority is meaningful on an empty `allow_any_resource` bin — and the size cost is one small object per bin.
> - **A5** confirmed live: the probe asserts the restored priority reached the bin's already-posted import jobs, which is the half a direct field write misses.
> - Verified in-engine by a temporary 29-check autoload probe (MCP unreliable, per CLAUDE.md) running the real stage → save → **load** → verify cycle across the scene swap, including the legacy-shape storage branch. Probe deleted afterward.
> - Two probe gotchas worth carrying forward: `ore_processor`/`forge`/`hydroponics` are all `requires_worker`, so an unmanned-path test needs `ice_processor`/`algae_tank`/`electrolysis`; and a turbolift lives on the **TURBOLIFT** structure layer, so `get_module_by_cell(MODULE, cell)` silently returns null for it.

## Goal

D8 asked for a one-time sweep: every component with a mutable non-derived field either has a save key or a comment saying why not. This is that sweep plus the fixes it turned up.

The sweep covered every `modules/components/*.gd`, every `scripts/managers/*.gd`, every `pawns/*.gd`, the module scripts under `modules/transport|core|logistics`, and the world objects in `objects/` — field list diffed against the section each one contributes to. Seven findings, six of them fixes and one a documentation gap.

Two findings are **not** unsaved-state bugs at all — they're bugs the sweep walked into while checking whether a field round-trips (A1 and A5). They're in scope because both are one-line fixes in the exact code the audit had open, and leaving a known-wrong load path behind while writing "audited" on the doc would be worse than the scope creep.

**Deliberately excluded:** no save-shape redesign, no `SAVE_VERSION` bump. Every new key follows the established absent-key-means-pristine convention, so pre-WI-45 saves load unchanged. The one shape change (A4, storage) carries an explicit legacy branch instead of a migration.

## Findings and design

### A1 — `TurboliftManager` loads the credit cost into `max_cabs`

[`turbolift_manager.gd:100`](../../../../scripts/managers/turbolift_manager.gd):

```gdscript
var cab_count: int = int(entry.get("cabs", 0))
shaft.max_cabs = cab_cost
```

`cab_count` is computed and discarded; `cab_cost` is `500`. The key is saved correctly — only the load path is wrong. [`turbolift_shaft.gd:64`](../../../../modules/transport/turbolift_shaft.gd) spawns a cab on demand whenever `cabs.size() < max_cabs`, so every loaded save gives every shaft an effectively unlimited cab budget, and the player's purchased-cab count (500 cr each) is meaningless after one save/load.

**Fix:** assign `cab_count`. Floor it at 1 — a shaft with `max_cabs == 0` serves nobody, and a pre-WI-45 save's absent key would otherwise default to exactly that. Note the assignment must *overwrite* rather than accumulate: shafts rebuild from module adjacency during the world load and `TurboliftShaft.merge` sums `max_cabs`, so the rebuilt shaft arrives with one cab per floor before this line runs.

### A2 — unmanned processors destroy an in-flight batch's inputs

[`processor_component.gd:429`](../../../../modules/components/processor_component.gd):

```gdscript
if requires_worker and processing:
    data["processing"] = true
```

`_stepwise_processing` withdraws the batch's inputs up front (`:304`) for unmanned processors exactly as `_manned_processing` does (`:322`). WI-23 added mid-batch resume for the manned path and gated it on `requires_worker`; the unmanned path — which is most processors, including every smelter, scrubber and electrolysis unit — was never revisited. Save/load mid-batch restores `processing = false` and the withdrawn inputs are simply gone.

This is a resource-destruction bug in the spirit of the "jobs must never destroy carried resources on cancel" invariant, just on the module side of the line.

**Fix:** drop `requires_worker and` from both the save condition and the load condition. Nothing else differs between the two paths at rest — `processing`, `current_process_time` and `current_batch_richness` mean the same thing in both, and `_stepwise_processing` picks a restored batch up mid-progress with no extra work.

While in here, **`pending_recipe`** (`:54`) is a queued player choice — a mid-batch recipe switch, deliberately deferred so consumed inputs aren't wasted — and it is dropped by the save. Give it a key alongside the recipe.

**`_yield_residue`** (`:49`) is **saved**. The first draft of this WI declined it as noise — sub-1-unit per output, already discarded on a recipe switch — and that was the wrong call. The governing rule is *the player should never lose resources without doing something that loses them*, and it doesn't have a size threshold: the residue is output their inputs already paid for, and a save/load isn't an action that discards it. A recipe switch dropping the entries the new recipe can't use stays exactly as it is, because that one **is** an explicit player action.

Restore order matters and gives the right semantics for free: residue loads *before* the recipe, so if the restored recipe differs from what the scene authored, `_apply_recipe` prunes the unusable entries exactly as a live switch would. Entries at 0.0, and any output whose `ResourceData` has no save id, aren't written at all.

### A3 — per-module force-shutdown is not saved

`force_off` on both [`power_consumption_component.gd:7`](../../../../modules/components/power_consumption_component.gd) and [`power_generation_component.gd:13`](../../../../modules/components/power_generation_component.gd) is driven by the info panel's Force Shutdown button and neither has a key. Every manually shut-down reactor and consumer silently comes back online on load, which is a live gameplay lever (it's how you brown-out non-essentials during a fuel shortage) reverting itself.

Worth noting the *shaft-level* equivalent already round-trips — `TurboliftShaft.force_shutdown` is saved by `TurboliftManager` and re-applied down onto each floor's power component on load — so the module-level toggle is the only gap, and the two must not fight: the shaft applies its state after the world section, so a shaft-level shutdown correctly wins over a stale per-floor value.

**`PowerGenerationComponent._fuel_seconds_left`** (`:15`) rides along in the same key: up to a whole unit of fuel burn resets on load. Small, but it's free to carry once the block exists, and without it a generator restored mid-burn re-withdraws a fresh unit on the next `restart_generation()`.

**Fix:** `get_save_data()`/`load_save_data()` on both components plus `power_consumption` / `power_generation` keys in `ModuleBase`. Both return `{}` when nothing deviates from pristine, so untouched stations don't grow their saves. No module scene carries two of either component (checked: 31 `PowerConsumptionComponent` nodes, none doubled), so the single `get_component_by_type` lookup every other component key uses is correct here — storage's path-keyed dict is not needed.

Load must go through `disable_generation()` on the generator rather than writing `force_off` directly: the setter is what keeps `powered` consistent with the flag.

### A4 — `StorageComponent.priority` is not saved

[`storage_component.gd:4`](../../../../modules/components/storage_component.gd). `get_save_data` writes `desired` / `stacks` / `autodump` per resource and nothing about the bin itself. The priority spinbox is live on every storage panel — connected unconditionally at [`ui_storage_component.gd:26`](../../../../ui/windows/ui_storage_component.gd), *not* gated on `player_configurable`, range −100..100 — so this is a first-class player setting.

Since storage priority **is** the routing language, a station the player hand-tuned reverts to scene-authored defaults on load and silently re-routes every haul on it. This is the highest-impact unsaved field in the sweep.

**Fix — the one shape change.** The component's save dict is currently a flat resource-id → entry map with no room for a component-level field. Move to:

```
{"priority": <int>, "resources": {<id>: {...}}}
```

and branch on load: `data.has("resources")` → new shape, else the whole dict *is* the legacy resource map. No `SAVE_VERSION` bump and no migration entry — the legacy branch is three lines and reads more honestly than a migration that rewrites every module's storage block. (Checked: no `ResourceData.id` is `"resources"`, so the discriminator can't collide with a real entry.)

Restore through `update_priority()`, not by assigning the field — see A5.

### A5 — the priority UI bypasses `update_priority()`

[`ui_storage_component.gd:83`](../../../../ui/windows/ui_storage_component.gd) does `storage_component.priority = roundi(new_value)`. But [`storage_component.gd:227`](../../../../modules/components/storage_component.gd) exists precisely because that isn't sufficient:

```gdscript
func update_priority(new_priority: int) -> void:
	if priority != new_priority:
		priority = new_priority
		for data: StorageData in storage_data.values():
			data.set_job_priority(new_priority)
```

Already-posted import/export jobs keep their old priority. `JobManager`'s slow-tick re-sort repairs the *ordering* within a few hundred ms (its header comment even names `update_priority` as the reason that re-sort exists) — but only for jobs whose priority actually changed, and these never do. So a bin the player re-prioritized keeps hauling at its old priority until each outstanding job is cancelled and re-posted.

The only current caller of `update_priority` is `TradeComponent`. This is the sole finding that isn't about persistence; it's here because the load path needs the same call and it would be wrong to fix one and not the other.

**Fix:** the UI calls `update_priority()`.

### A6 — `MiningComponent.priority_ore` is not saved

[`mining_component.gd:19`](../../../../modules/components/mining_component.gd). A per-bay player choice steering `FinderAsteroid` when no asteroid is designated. The field's own comment says "not persisted (see 03_Bugs)" — but there is no such entry in `03_Bugs_and_Improvements.md`, so the pointer dangles and the omission was never actually decided, just deferred.

Decide it now in favour of saving: it's a player setting, exactly like the processor's recipe and the shop's type, both of which have keys.

**Fix:** `get_save_data()`/`load_save_data()` on the component storing the ore id, plus a `mining` key on `ModuleBase`. Resolve via `Global.save_manager.get_resource_by_id` on load, the same as `StorageComponent` and `ConveyorComponent` do.

**`_respawn_time_left`** (`:14`) stays unsaved — a ≤5 s drone respawn timer. Comment added.

### A7 — undocumented alert-suppression latches

Correctly derived, correctly unsaved, but silent about it, so each one reads like an oversight to the next auditor. All re-fire one duplicate alert after load and none deserves a key:

- `AtmosphereManager._low_o2_alerted`
- `ContractManager._bay_lost_alerted`
- `TraderManager._import_full_alerted`
- `VisitorPawn._stranded_alerted`
- `PawnHealthComponent._was_critical`

**Fix:** one comment each.

## Verified clean

Recorded so the next sweep doesn't redo the work. Every one of these is derived, rebuilt, or already documented as runtime-only:

Slot pools (sleep / recreation / shop / recharge / robot-repair / medical), `PathComponent` anchor claims and pools, adjacency fields, storage reservations and `import_job`/`export_job`, `ClaimRegistry`, `PathManager`/`StructureManager`/`AdjacencyManager` graphs, `JobManager`'s board, `PowerManager`'s three registries, `VisitorManager._visitor_count` (has an authoritative group-scan accessor), `UnlockManager`'s inspection flags (explicitly commented runtime-only), turboshaft group ids, cab and ride state (pawns save at their drop-off floor by design), `WeaponComponent._fire_cooldown` (declined by WI-38 A2, still right), `PawnMovementComponent`, `MedicalComponent.current_doctor`, `LogisticsBayComponent.robots` (re-registered by each hauler's own save entry), and the `economy` / `event` / `contract` / `crew` / `raid` / `asteroid` / `trader` / `time` / `market` manager sections, each diffed field-by-field.

## Files to touch

- `scripts/managers/turbolift_manager.gd` — A1
- `modules/components/processor_component.gd` — A2
- `modules/components/power_consumption_component.gd`, `modules/components/power_generation_component.gd` — A3
- `modules/components/storage_component.gd` — A4
- `ui/windows/ui_storage_component.gd` — A5
- `modules/components/mining_component.gd` — A6
- `modules/templates/module_base.gd` — A3, A6 keys
- `scripts/managers/atmosphere_manager.gd`, `scripts/managers/contract_manager.gd`, `scripts/managers/trader_manager.gd`, `pawns/visitor_pawn.gd`, `pawns/pawn_health_component.gd` — A7 comments
- `tests/unit/test_component_persistence.gd` — new suite

## Implementation order

1. **A1** — one word, zero blast radius.
2. **A5** then **A4** — same area, and A4's load path depends on A5's method being the way priority is set.
3. **A2**, **A3**, **A6** — the three new/widened save blocks, together so one save/load sweep verifies all of them.
4. **A7** — comments.
5. Tests, then the full GUT suite.

## Edge cases

- **A1**: a shaft whose saved `cabs` predates the key (absent) must land on 1, not 0. Confirm a 3-floor shaft that bought 2 extra cabs reloads at 3, not 5 (merge-derived) and not 500.
- **A2**: restoring `processing = true` on a processor whose *output* bin filled while the game was closed — `_try_deposit_outputs` already returns false and retries, so the batch parks at full progress rather than voiding. Confirm it doesn't re-withdraw inputs.
- **A2 / recipe**: `pending_recipe` restores only when the recipe still resolves and is still in `available_recipes`; otherwise warn and drop, matching what `recipe` already does.
- **A3**: a turboshaft with `force_shutdown` on, saved and loaded — the shaft section runs after the world section, so the shaft's re-apply is the last word. Verify a floor's own restored `force_off` doesn't leave a *disabled* shaft's floors powered.
- **A3 / fuel**: a generator restored mid-burn must not withdraw a fresh unit on its first tick.
- **A4 / legacy**: a pre-WI-45 save's storage block has no `"resources"` key and must load exactly as before, with `priority` left at the scene default. Verify against an actual old save, not a hand-built dict.
- **A4 / trade bins**: `TradeComponent.ready_constructed` calls `update_priority(TRADE_EXPORT_BIN)`. Module load runs after the ready pass, so a saved priority correctly overwrites it — confirm that's what the player expects for a trade bay they re-tuned (it is: the save is the later authority).
- **A6**: a saved `priority_ore` whose `ResourceData` no longer exists warns and falls back to null (no preference), never to a random ore.

## Verification

1. **A1**: buy 2 extra cabs on a 3-floor shaft (5 total), save, load → panel reads 5, and no cab storm. Check a shaft with the key absent from an older save reads ≥1.
2. **A2**: start an unmanned smelter batch, save at ~50%, load → progress resumes at ~50% and the ore is not lost. Repeat with a manned forge (the WI-23 path must not regress).
3. **A2 / recipe**: switch a multi-recipe processor's recipe mid-batch, save, load → the batch finishes on the old recipe and the queued one applies after.
4. **A3**: force-shutdown a reactor and a consumer, save, load → both still off, button still pressed. Un-shutdown, save, load → both on.
5. **A4**: set a bin to priority −20, save, load → still −20, and the Logistics overlay shows the label. Load a pre-WI-45 save → contents and desired amounts intact, no warnings.
6. **A5**: with a haul job already posted against a bin, change its priority → the in-flight job's effective priority changes within one slow tick (check via the Logistics overlay's priority labels).
7. **A6**: set a mining bay's priority ore, save, load → still set; drones still prefer it when nothing is designated.
8. **GUT**: full suite green (393 baseline) plus the new persistence suite. Components are constructed bare (no tree, no `Global`) in the `test_battery_persistence` style — which is what constrains the new `load_save_data` bodies to avoid `Global` on the paths the tests take.
9. **Regression**: build → deconstruct → collect pile; run a trade caravan; ride a turbolift — A1/A4 touch machinery all three depend on.
