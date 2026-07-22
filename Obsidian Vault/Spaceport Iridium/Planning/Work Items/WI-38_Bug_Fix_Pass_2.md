# WI-38 — Bug-Fix Pass 2

## Goal
Fix the eight confirmed bugs in [[03_Bugs_and_Improvements]] section A (found in the 2026-07-22 post-WI-37 audit). No behavior redesign — smallest correct fix per bug, in the spirit of [[WI-01_Bug_Fix_Pass]]. Two of them (A2, A8) are save/session-integrity bugs and are the reason this is a work item rather than a scattering of drive-by commits.

Deliberately **excluded**: the section C refactors these bugs point at. A5 is fixed in place here, not by building the unified `StorageQuery` helper (C5) — that's its own item so this one stays reviewable.

## Design

Grouped by what they actually are, since the eight split into three real themes plus a tail of one-liners.

### Theme 1 — build-state and save-state gaps in WI-32 combat (A1, A2)

`WeaponComponent` and `ShieldComponent` were built as a pair but only the shield got the two guards every other component has: a build-state gate and a save block.

- **A1**: `WeaponComponent._process` runs from instantiation, so a blueprint turret targets, fires, and draws `active_power_consumption` during construction. Gate it the way the rest of the codebase does — `owner_module.is_complete()`. Note `_tick_beam` should still run (a turret finishing its construction mid-flash shouldn't leave a frozen beam), so the gate goes *after* the beam tick, before the sim-delta work.
- **A2**: shield capacitor charge is runtime-only, so a mid-raid load restores the pirates faithfully and the bubbles to full. Add `get_save_data()`/`load_save_data()` to `ShieldComponent` (`charge` + `online`) and a `"shield"` key in `ModuleBase.get_save_data()`/`load_save_data()`, same shape and same absent-key-means-pristine convention as `sustenance`/`shop`. Load order inside the module matters slightly: restore after `upgrades`, because `effective_capacity()` reads the upgrade-modified stat and the hysteresis re-derivation should judge the restored charge against the *upgraded* capacity.

  `WeaponComponent._fire_cooldown` has the same gap and is deliberately **not** saved — it's a sub-2-second effect and a key for it is noise.

### Theme 2 — state that outlives the run it belongs to (A3, A8)

Both are "something survives a boundary it shouldn't". A8 is the serious one and the user has now reproduced it.

- **A8 (verified)**: `ResourceData.global_total` is mutable runtime state on a shared `.tres`, and Godot's resource cache holds it across the scene swap. WI-36's Quit-to-Menu → New Game therefore starts the new run with the old run's credits and every other `has_global_store` total. Fix in two parts:
  1. **Separate the authored seed from the runtime value.** Rename the exported field to `starting_global_total` (authored, lives in the .tres) and make `global_total` a plain `var`. Do the same to `cached_total` — drop `@export`, it's a pure cache. This also closes design-debt **B3**, which is what caused this.
  2. **Reset on entry to the game scene.** `SaveManager._ready()` already builds the authoritative `_resource_data_by_id` table before anything spawns (Managers/ readies before `Main._ready`, which is what calls `spawn_starting_station`). Reset there, unconditionally: `global_total = starting_global_total`, `cached_total = 0`, `needs_recalc = true`, and `registered_storage.clear()`. Unconditional is right — the load path's `_load_resources` runs afterward and overwrites, and a `has_global_store` resource added *since* a save was written should get its authored seed rather than a stale one.

  The `registered_storage.clear()` is defensive, not known-broken: registration/unregistration is symmetric on `include_in_stats` (`storage_component.gd:102/120/217`), but that array holds `StorageComponent` node references and a single missed `_exit_tree` across a scene swap leaves freed objects in a list that `_recalc_resource` walks. Cheap to make impossible.

- **A3**: `TimeManager.load_save_data` emits `cycle_changed`/`hour_changed` to re-sync listeners, and three managers treat those as real calendar events. `EventManager` is the live bug — `_natural_roll()` can fire a random event on load, before `EventManager.load_save_data` has restored its own state. `MarketManager` and `ContractManager` are currently harmless only by accident of section ordering.

  Fix at the source, not per-listener: skip both emissions in `TimeManager.load_save_data` while `SaveManager.is_loading()`, and instead emit a dedicated `calendar_restored` that only genuine display re-sync listeners subscribe to. Then remove the now-redundant `is_loading()` guards from `EconomyManager._on_cycle_changed` and `UnlockManager._on_cycle_changed` — leaving them would be harmless but would keep implying the emissions still fire.

  Audit while in here: `_apply_pending_load` is one deferred tick after `_ready`, so any manager subscribing to `hour_changed`/`cycle_changed` and doing calendar work is in scope. `advance_hours()` (the cheat) must keep firing both — that path *is* a real calendar skip.

### Theme 3 — storage routing (A4, A5, A7)

- **A4**: `StorageComponent.destroy_resource` bypasses `reserved_withdraw`, so autodump can delete stock a hauler is already walking toward. Clamp the dump at the call site in `_on_slow_tick`: `stored - desired - reserved_withdraw`, skip when ≤ 0. Fix it in the autodump caller rather than inside `destroy_resource`, which is also the module-destruction/eject path where ignoring reservations is correct.
- **A5**: `Job_StoreInventory._find_closest_import_storage` selects purely by distance while `Job_GetResource._find_deposit_storage` selects priority-then-distance, so a pawn sweeping leftovers can dump into a construction site's +99 bin. Give the sweep the same priority-then-distance ordering. It correctly has *no* `priority >` floor (unlike the haul job, which needs one to prevent flip-flopping between two bins) — the sweep must accept any bin that will take the cargo rather than stranding a loaded pawn. Keep it that way and comment why the two differ, or the next reader will "fix" it back.
- **A7**: same function, add the `storage == null` guard its three siblings have.

### Tail (A6)

`SaveManager._apply_pending_load` emits `game_loaded.emit(QUICK_SLOT)` — hardcoded, so every menu load reports `"quicksave"`. `stage_load` doesn't record the slot. Add a `static var _pending_slot: String` next to `_pending_load`, set it in `stage_load`, consume it in `_apply_pending_load`, clear it alongside `clear_pending_load()`.

## Files to touch
- `modules/components/weapon_component.gd` — A1
- `modules/components/shield_component.gd`, `modules/templates/module_base.gd` — A2
- `scripts/managers/time_manager.gd` — A3 (+ `SignalBus` if `calendar_restored` lands there rather than on TimeManager)
- `scripts/managers/economy_manager.gd`, `scripts/managers/unlock_manager.gd` — A3 guard removal
- `ui/ui_time_scale_select.gd`, `ui/ui_in_game.gd` (clock display) — A3, re-subscribe to `calendar_restored`
- `modules/components/storage_component.gd` — A4
- `scripts/jobs/job_store_inventory.gd` — A5, A7
- `scripts/managers/save_manager.gd` — A6 (slot), A8 (reset)
- `data/resources/resource_data.gd` + every `.tres` under `data/resources/` — A8 field rename
- `tests/unit/` — new/updated suites (see below)

## Implementation order
1. **A7** then **A5** — one function, smallest blast radius, warms up the storage area.
2. **A4** — adjacent, same file family.
3. **A1** — self-contained one-liner.
4. **A6** — self-contained, touches SaveManager's statics, which A8 also touches.
5. **A8** — the field rename is the mechanical risk (every resource `.tres` carries `global_total`); do it as a rename + a pass over `data/resources/*.tres`, then the `SaveManager._ready` reset. Re-run the full GUT suite here specifically.
6. **A2** — new save keys; do it after A8 so both save-shape changes land together and get verified in one save/load sweep.
7. **A3** — last, because it changes signal semantics several managers depend on and wants the most careful verification.

## Edge cases
- **A8 / rename**: any `.tres` that authored a non-zero `global_total` (credits at minimum) must carry the value over to `starting_global_total`, or new games start broke. Grep for the old field name across `data/` after the rename and confirm nothing kept it. `SaveManager._get_resources_save`/`_load_resources` keep writing/reading `global_total` — the *save format is unchanged*, only the authored seed field moved.
- **A8 / load path**: reset runs unconditionally in `_ready`, `_load_resources` overwrites one deferred tick later. Verify a loaded game shows the *saved* credits, not the seed — this is the ordering most likely to be got wrong.
- **A8 / difficulty**: confirm starting credits aren't supposed to be a `DifficultyData` knob (WI-37 didn't make them one). If they should be, that's a follow-up, not this WI — note it and move on.
- **A2 / capacity**: a shield saved at full charge whose capacity upgrade is *refunded or absent* on load (upgrade id renamed → `load_upgrade_save_data` warns and skips) restores charge above capacity. Clamp on load.
- **A2 / raid restore**: `RaidManager.load_save_data` respawns ships in the same section pass as the world. Confirm a mid-raid save/load now shows *drained* bubbles and that the hysteresis `_online` state restores rather than re-deriving to `true`.
- **A3 / new game**: `TimeManager` doesn't `load_save_data` at all on a new game, so the guard can't regress that path — but confirm the clock UI still populates from its own `_ready`, not from the emission being removed.
- **A3 / EventManager**: `_roll_midcycle_hour()` is called from both `_ready` and `_on_cycle_changed`. A load must end with exactly one scheduled mid-cycle hour, and it should come from `EventManager.load_save_data`, not from the replay. Check what that section actually restores.
- **A4**: autodump on a bin whose entire stock is reserved → dump amount clamps to 0, no destruction, no error, and the resource stays until the haul completes. Also confirm the module-destruction eject path (`dump_all_to_pile`) is untouched.
- **A5**: a pawn carrying cargo no storage will accept still falls through to "no storage will take this" rather than the priority sort silently returning null (`pawn_base.gd:216` depends on that).
- **A1**: a turret that completes construction *during* a raid must start firing without needing a raid restart — `_outward_valid` is invalidated on `raid_started`, which it will have missed. Verify aim is correct for a turret built mid-raid.

## Verification
1. **A1**: start a raid, place a laser turret blueprint, do not build it → no beam, no damage to ships, power draw stays at `idle_power_consumption`. Finish construction mid-raid → fires, and the arc points outward correctly.
2. **A2**: mid-raid, let a shield drain to ~30%, quick-save, quick-load → charge restores at ~30%, not full. Drain a shield to offline, save/load → still offline until it recharges past `reengage_fraction`.
3. **A3**: load a save repeatedly (5+ times) → no event card fires on load; market prices and supply-modifier timers are identical before and after; the clock UI shows the loaded time. Then confirm a natural event still fires within a few cycles of normal play, and `Global.cheats.advance_hours(48)` still drives events/market/contracts.
4. **A4**: bin with autodump on and desired below stock, with a hauler en route to withdraw from it → the haul completes; stock above `desired + reserved` still dumps.
5. **A5**: with a construction site posting +99 imports nearby, hand a pawn cargo it must sweep (cancel a haul mid-carry) → it deposits into a general store, not the construction bin. Confirm a pawn with nowhere at all to put cargo doesn't deadlock.
6. **A6**: load a named (non-quicksave) slot from the main menu → `game_loaded` reports that slot's name. Add a temporary print if nothing observable listens yet.
7. **A8 (the verified repro)**: new game → `Global.cheats.add_credits(50000)` → Quit to Menu → New Game → credits read the authored starting figure, not 50000+. Repeat with a non-credit `has_global_store` resource. Then: play → save → Quit to Menu → Load → credits are the *saved* value.
8. **GUT**: full suite green (342 baseline). New coverage for the pure parts — `ShieldComponent` charge/online round-trip through its save dict (construct directly, no `Global`), and the A4 dump-amount clamp as a pure `stored/desired/reserved` → amount function if it can be extracted cheaply. Per the invariant, new pure-logic rules get a test; the rest of this WI is guard placement and isn't unit-testable without the tree.
9. **Regression sweep**: build → deconstruct → collect pile; run a full ARC inspection; complete a contract — all still work, since A3 and A8 touch machinery all three depend on.
