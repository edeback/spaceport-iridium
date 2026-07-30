# Bugs, Code Issues & Improvement Suggestions

*Re-audited 2026-07-22 against the post-WI-37 codebase (~30k lines of GDScript across 243 scripts, 58 GUT suites / 342 tests). The previous pass was 2026-07-13, before WI-01; almost everything in it has since been fixed, so this is a rewrite rather than an edit. Section E records what closed.*

*Findings below come from reading the code; only A8 had been reproduced in-game. Severity ordering is my judgement of player impact. Fixes for the section A list were bundled as [[WI-38_Bug_Fix_Pass_2]], **completed 2026-07-22** — the whole of section A is now closed and recorded in section E. The entries are kept below for the reasoning trail.*

---

## A. Confirmed Bugs — ALL FIXED by [[WI-38_Bug_Fix_Pass_2]]

### A1. Blueprint turrets fire (and draw full power)

`WeaponComponent._process` ([`weapon_component.gd:76`](../../../modules/components/weapon_component.gd)) has no build-state gate. Every sibling combat component gates on `ready_constructed` — `ShieldComponent` only joins the `"shield"` group there (`shield_component.gd:36`), which is what keeps unbuilt bubbles out of `RaidManager.try_shield_absorb`. The turret has no equivalent.

`laser_turret_mdata.tres` sets `instant_build = false`, so a turret spends real construction time as a blueprint. During that window it targets, deals `effective_damage()`, and flips its power draw to `active_power_consumption`. A player under raid can drop turret blueprints and get free defense.

**Fix:** early-return in `_process` unless `owner_module != null and owner_module.is_complete()`.

### A2. Shield capacitors are not saved

`ShieldComponent` has no `get_save_data()`, and `ModuleBase.get_save_data()` ([`module_base.gd:407`](../../../modules/templates/module_base.gd)) has no shield key. `_charge` and `_online` are pure runtime state, so `ready_constructed` re-seeds every bubble to `initial_charge_fraction` (1.0 by default) on load.

This defeats the stated WI-32 design goal: `RaidManager`'s header says a mid-raid save "restores the whole fight so you can't save-scum out of the threat" (`raid_manager.gd:12-14`) — and it does restore the ships, their HP, and the payoff discount. But the *defenses* come back better than they were. Quick-save/quick-load during a raid is a full shield recharge.

**Fix:** a `shield` block in the module save data, same shape as `sustenance`/`shop`. `WeaponComponent._fire_cooldown` has the same gap but is a sub-2-second effect, not worth a key.

### A3. Calendar signals replay on load without an `is_loading()` guard

`TimeManager.load_save_data` deliberately emits `cycle_changed` + `hour_changed` after writing the fields directly, to re-sync listeners (`time_manager.gd:168-171`). Two managers know this and guard:

- `EconomyManager._on_cycle_changed` — `if SaveManager.is_loading(): return` (`economy_manager.gd:197`)
- `UnlockManager._on_cycle_changed` — same (`unlock_manager.gd:298`)

Three do not:

- **`EventManager._on_cycle_changed`** (`event_manager.gd:69`) calls `_roll_midcycle_hour()` and `_natural_roll()`. **Loading a save can immediately fire a random event** — and it fires *before* `EventManager.load_save_data` restores the manager's own state, since events are section 14 of 17.
- `MarketManager._on_hour_changed` (`market_manager.gd:27`) ages every supply modifier by an hour and drifts all prices. Harmless *today* only because the market section loads afterward and overwrites it.
- `ContractManager._on_cycle_changed` (`contract_manager.gd:197`) walks `active` for expiries. Harmless *today* only because `active` is still empty at that point in the section order.

Two of the three are load-bearing on section ordering that isn't documented as load-bearing.

**Fix:** guard once at the source rather than N times at the listeners — either skip the emissions in `TimeManager.load_save_data` while `SaveManager.is_loading()`, or emit a distinct `calendar_restored` signal that only genuine re-sync listeners (clock UI) subscribe to.

### A4. Autodump destroys reserved stock

`StorageComponent._on_slow_tick` dumps `stored - desired` when `autodump` is on (`storage_component.gd:164-167`), and `destroy_resource` goes straight to `data.withdraw_stacks(...)` (`storage_component.gd:238`) without consulting `reserved_withdraw` — unlike every other withdraw path, which routes through `StorageData.can_withdraw`.

So a hauler already walking to that bin with a live withdraw reservation arrives, gets `[]` back from `complete_withdraw_job`, and cancels (`job_get_resource.gd:187`). Reservations *do* reconcile correctly (the cancel path is clean, so the invariant holds), but the trip is wasted and the player sees haul jobs silently fail near an autodump bin.

**Fix:** dump `stored - desired - reserved_withdraw`.

### A5. `Job_StoreInventory` ignores storage priority

`_find_closest_import_storage` (`job_store_inventory.gd:129`) selects purely by squared distance. Its sibling `Job_GetResource._find_deposit_storage` (`job_get_resource.gd:148`) selects by priority-then-distance.

Since storage priority *is* the routing language, a pawn sweeping leftover cargo can dump it into whatever bin happens to be nearest — including a construction site's +99 import bin or a deconstruction site's −99 export bin — after which the material has to be hauled straight back out. This is exactly the drift the 2026-07-13 pass predicted when it flagged the four near-identical query loops (old C6); the loops have now genuinely diverged.

**Fix:** fold both into one query helper (see C5) and give the sweep the same priority preference.

### A6. `game_loaded` always reports the wrong slot

`SaveManager._apply_pending_load` ends with `game_loaded.emit(QUICK_SLOT)` (`save_manager.gd:618`) — hardcoded to `"quicksave"` regardless of which slot was actually staged. `stage_load` never records the slot name anywhere it survives the scene swap. Any listener keying off the slot argument is wrong for every menu load.

**Fix:** stash the slot alongside `_pending_load` in the static, emit that.

### A7. Unguarded cast in the storage sweep

`job_store_inventory.gd:135` reads `storage.accepts_imports` directly off `node as StorageComponent` with no null check. Its three siblings all check (`job_get_resource.gd:126`, `:152`, `job_collect_pile.gd:125`). Anything ever added to the `"resource_storage"` group that isn't a `StorageComponent` is an immediate nil-access crash here and nowhere else. Low likelihood, trivial fix, worth the consistency.

### A8. Verified: New Game after Quit to Menu inherits the previous run's global totals

`ResourceData.global_total` is mutable runtime state living on a shared `.tres` (`resource_data.gd:19`; see B3). Nothing zeroes it on a new game — `Main._ready` only calls `spawn_starting_station()`, and `SaveManager._load_resources` only writes it on the *load* path.

Godot's resource cache holds `credits.tres` across the scene swap, so the mutated total survives. **Reproduced 2026-07-22:** new game → `Global.cheats.add_credits(50000)` → Quit to Menu → New Game → the new run starts with the old run's credits. Applies to every `has_global_store` resource. WI-36 made this reachable for the first time by adding Quit to Menu → New Game inside one process.

**Fix:** separate the authored seed (`starting_global_total`, exported) from the runtime value (`global_total`, plain var — which also closes B3), and reset every resource in `SaveManager._ready()` before the station spawns. See [[WI-38_Bug_Fix_Pass_2]].

---

## B. Design-Debt / Known-Disabled Code

### B1. `can_remove_module` still disabled - FIXED

~~`WorldManager.remove_module` still has the structure check commented out with the same TODO (`world_manager.gd:152-155`): under-construction modules aren't structure-connected, so the check fires constantly. Unchanged since the first audit — this has now been off for the project's entire life.~~

~~Note the scope has shrunk: WI-32's `ModuleBase._on_hp_zero` calls `remove_module(module, false)`, which bypasses the check anyway. Re-enabling it would only affect player-initiated deletes. Either fix the connectivity accounting for blueprints or delete `can_remove_module` and the `structure_check_before_delete` flag, so the codebase stops implying a feature that doesn't exist.~~

### B2. Power scans — *fixed by WI-39*

~~The per-frame scan is gone; `PowerManager` runs on `slow_tick` now with the sim-seconds interval threaded through correctly. What's left is cleanup: three `get_nodes_in_group` scans per tick (see C4), plus dead `power_generators`/`power_consumers` array fields and a block of commented-out `node_grouped`/`node_ungrouped` hooks that describe a caching design that was never built.~~

Closed by WI-39: the three arrays are now real and populated by explicit registration, the group scans are gone, and both halves of the `node_grouped`/`node_ungrouped` sketch (in `power_manager.gd` and `signal_bus.gd`) are deleted.

### B3. Runtime state `@export`ed on shared resources — *fixed by WI-38*

~~`ResourceData.global_total` is where the player's credit balance lives, and `cached_total` is a derived cache. Both are `@export`ed on `@tool` resources shared engine-wide — confusing in the inspector, a save/load foot-gun, and the direct cause of A8.~~

Closed alongside A8: the authored seed is now `starting_global_total` (the only exported one), `global_total` and `cached_total` are plain vars, and `SaveManager._ready` reseeds them on entry to the game scene.

### B4. `SAVE_VERSION` has never left 1

`save_manager.gd:15` has read `1` through WI-22, -24, -25, -26, -27, -28, -29, -31, -32, -33, -36 and -37, every one of which changed the format. The "missing keys default sensibly" convention has genuinely held — but the consequence is there's no way to *reject* a save that's too old to be sane, `_migrations` is empty, and the migration path has never been exercised even once.

Worth bumping at the next actually-breaking change and writing the first migration, if only to prove the machinery works before it's needed under pressure.

### B5. Use-after-`queue_free` ordering in `remove_module`

`world_manager.gd:170-173` calls `module.queue_free()` and then reads `module.module_data` and `module.module_cell` to decide on truss replacement. This works — `queue_free` defers to end of frame — but it's the kind of ordering that breaks silently if anyone ever swaps it for `free()`. Capture what's needed before the free (as the function already does for `replacement_location` and `replacement_points`) and move the call to the end.

### B6. Commented-out code accumulating in hot files

`storage_component.gd:130-146` and `:250-259`; `world_manager.gd:294-302`; `module_base.gd:578-586`. Also empty-but-defined `_process` handlers that still cost an engine call per frame: `world_manager.gd:65-66`. Git has the history — delete these. (The `power_manager.gd` block and its `signal_bus.gd` counterpart are gone — WI-39.)

---

## C. Improvement Suggestions (code)

*Numbering continues the original list; items 1, 2, 3, 6(part), 7 are done and moved to section E.*

**C4. Cache power group membership.** — *done by [[WI-39_Power_Registry]], 2026-07-22.* ~~Three `get_nodes_in_group` calls per slow tick. The commented-out `node_grouped` hooks show the intended design. Maintaining arrays on `ready_constructed`/`_exit_tree` also gives a natural home for per-module power priorities later (life support browns out last). Scoping this also turned up an **unsaved-state bug**: `BatteryComponent.total_power_stored` has no save key, so every battery reloads empty — same class as A2, missed because that pass audited combat components. Folded into the same WI.~~ See section E.

**~~C5. One storage-query helper.~~** **Done — [[WI-40_Storage_Query_Helper]].** The four scanners are now two static queries in `scripts/utility/storage_query.gd`: `StorageQuery.find_source(pawn, resource, trip_cap, below_priority)` and `find_sink(pawn, resource, above_priority)`, with `ANY_PRIORITY` as the explicit "no filter" sentinel the pile and the sweep pass. Priority semantics, the strictness rationale, the sweep asymmetry, and the null-in-group guard are each stated once. Per-resource indexing on `ResourceData.registered_storage` is now a one-function change and is deliberately still open (see 01_Technical_Specification §2.3).

**C8. Naming.** `sort_priority_decending` is gone. `capacitator` → `capacitor` remains (`power_consumption_component.gd:5`).

**~~C9. A `Groups` constants file.~~** **Done — [[WI-41_Group_Constants]].** `scripts/utility/groups.gd` holds 22 `const NAME: StringName = &"name"` entries grouped by owner, and every group-API call site in `.gd` now goes through one. Zero bare group literals remain outside `addons/`. Two things the conversion turned up: `container_required` is entirely addon-internal (`addons/collapsible_container/`) so it never earned a constant, and four groups — `processor`, `turbolifts`, `teleporters`, `stairs` — are joined but scanned by nothing; they kept constants with a comment saying so rather than being deleted silently. `airlock` stays duplicated in the two airlock `.tscn`s by necessity and its constant names them.

**C10. Turrets should read `RaidManager._ships`, not scan the tree.** `WeaponComponent._pick_target` does `get_nodes_in_group(Groups.PIRATE_SHIP)` per turret per frame during a raid (`weapon_component.gd:127`), and `_ensure_outward` walks every module in the station (`weapon_component.gd:148`, cached per raid so this one's fine). `RaidManager` already maintains the authoritative live array. A late-game station with a dozen turrets is doing a dozen redundant tree scans a frame.

**C11. `get_built_modules` is O(cells²).** `world_manager.gd:265-274` dedupes with `result.has(module)` while iterating every cell entry. Called from `RaidManager.compute_strength()`. Irrelevant at current station sizes; swap the linear `has` for a seen-dictionary when it isn't.

**~~C12. `PreviewModule` instantiates a whole module scene per preview update.~~** **Done — [[WI-42_Preview_Metadata_Cache]].** The twelve read values now live in a `ModulePreviewData` inner class, cached in a `Dictionary[PackedScene, ModulePreviewData]` owned by the `PreviewModule` node (an instance member, not a static — it dies with the scene rather than holding every previewed `PackedScene` alive across a Quit-to-Menu boundary, per the A8 lesson). Keying on `PackedScene` rather than `ModuleData` gets flippable modules right for free. One instantiate per distinct scene per session: 47 across the 45 buildable modules. Also fixed a live crash found while verifying — `update_from_module_data` had no null guard on `module_data`, so pressing `flip_module` with nothing selected threw.

**C13. `force_withdraw` and `change_global_total` aren't symmetric.** `change_global_total` recalcs and emits `total_changed`; `force_withdraw` only sets `needs_recalc` (`resource_data.gd:61-64` vs `:88-97`). So hiring a crew member, paying off a raid, buying a module, or purchasing an upgrade doesn't move the credit HUD until `ResourceManager`'s next slow tick fires. Self-healing within 0.25 sim-seconds, so it reads as UI lag rather than a bug — but the two paths should behave the same.

~~**C14. Severance ignores the difficulty dial.** `EconomyManager.wage_for_pawn` runs through `scaled_cost(..., upkeep_multiplier())` (`economy_manager.gd:245-248`); `severance_for` does not (`:382-385`). Possibly deliberate, but it makes severance the only recurring-crew cost the WI-37 multiplier doesn't touch, and nothing says so.~~ Note: Severance is not recurring.

Fixed:
~~**C15. Raid outcome messaging is wrong for mixed outcomes.** `RaidManager._check_end` (`raid_manager.gd:190-203`) only reports `repelled` when `_destroyed_count == 0`. Kill three ships, let two flee, and the player is told "every hostile destroyed." Cheap fix, and it's the last thing the player reads about a fight they just spent five minutes on.~~

---

## D. Design Suggestions & Elaborations

**D4. Module removal refunds.** *(carried forward, still open)* Deconstruction returns 100% of materials. More interesting now that WI-25's economy is live and there's a real reason to want a lossy build/rebuild loop.

**D5. Teleporter.** *(carried forward, still open)* The module and its behaviors exist; the "does it need its own storage buffer for resource transfer" question is still unanswered. Suggestion stands: pawn-only shortcut group first (already supported by `ModuleGraph` vertex groups), resource teleportation as a separate late-game unlock.

**D7. Finish WI-12 (Storage QoL) deliberately.** It's the one Phase-2 leftover, and the autodump feature (most recent commits) is effectively its first slice landing ad hoc — which is how it shipped without the reservation check in A4. Worth doing the rest as a designed pass rather than accreting it.

**~~D8. Audit for unsaved stateful systems.~~** **Done — [[WI-45_Save_System_Audit]], 2026-07-30.** See section E.

~~**D9. Decide on `structure_check_before_delete`.** See B1. Either the connectivity accounting gets fixed for under-construction modules, or the flag, `can_remove_module`, and the commented block all get deleted. Leaving a disabled safety check in place for three phases is worse than either.~~ Fixed

---

## E. Resolved Since the 2026-07-13 Pass

Recorded so the history isn't lost:

- **D8 — the unsaved-stateful-systems sweep** — done by [[WI-45_Save_System_Audit]], 2026-07-30. Every component, manager, pawn component and world object diffed field-by-field against the section it contributes to. Seven findings. Three were unsaved player settings: **storage `priority`** (the routing language itself — a hand-tuned station reverted to scene defaults on every load), both **`force_off` shutdown switches**, and a mining bay's **`priority_ore`**. One was resource destruction: an **unmanned processor** withdraws its batch inputs up front but only the *manned* path was ever given a save key (WI-23 added it and the gate was never revisited), so a save/load mid-batch voided the ore — the fix also carries `pending_recipe` (a queued mid-batch recipe switch that was silently dropped) and `_yield_residue` (sub-1-unit fractional carry-over — small, but still output the player's inputs paid for; the governing rule is no resource loss without a player action that loses them, and it has no size threshold). Two were bugs the sweep walked into rather than unsaved state: **`TurboliftManager` assigned `cab_cost` (500) into `shaft.max_cabs`** instead of the saved count it had just parsed, giving every shaft in every loaded save an unlimited cab budget; and the **storage priority spinbox wrote the field directly** instead of calling `update_priority()`, so already-posted haul jobs kept their old priority indefinitely. The seventh was documentation — five alert-suppression latches that are correctly derived but said nothing about it. The storage save block gained a nested shape (`{"priority", "resources"}`) with a legacy branch rather than a migration; everything else is a new absent-key-means-pristine module key, so `SAVE_VERSION` stayed at 2 and old saves load unchanged. The WI also records the fields confirmed *correctly* unsaved, so the next sweep doesn't redo the work. 505 GUT tests green (+21); verified in-engine by a 29-check headless probe running a real stage → save → load → verify cycle.
- **All of the 2026-07-22 section A** (A1–A8) — fixed by [[WI-38_Bug_Fix_Pass_2]], 2026-07-22. In short: blueprint turrets gated on `is_complete()`; shield capacitor charge/online now saved (module `shield` key, clamped to the upgraded capacity on load); `TimeManager.load_save_data` announces `calendar_restored` instead of replaying `cycle_changed`/`hour_changed`, so no manager does calendar work on load (the `is_loading()` guards in `EconomyManager`/`UnlockManager` came back out); autodump clamps to `stored - desired - reserved_withdraw` via the pure `StorageData.autodump_amount()`; `Job_StoreInventory` sweeps priority-then-distance and null-guards its cast; `game_loaded` reports the staged slot; and `ResourceData` split its authored seed (`starting_global_total`) from runtime `global_total`, reset in `SaveManager._ready` — which also closed **B3**. 351 GUT tests green.
- **C4 — power participant registry, and the battery-charge save bug** — done by [[WI-39_Power_Registry]], 2026-07-22. `PowerManager` now keeps three registration arrays (`power_generators`, `power_consumers`, `batteries`) fed by `register_*`/`unregister_*` calls from the components themselves; the `power_generator`/`power_consumer`/`battery` groups are deleted, as is the `node_grouped`/`node_ungrouped` sketch in both `power_manager.gd` and `signal_bus.gd` — closing **B2** as well. A fourth component lifecycle hook, `ready_deconstructing()`, came with it: a module that has started coming apart now leaves the registries instead of generating and drawing right up until the last plate comes off (never intended — missed when construction was implemented). A deconstructing consumer also goes `powered = false`, so processors/mining bays/conveyors on a teardown site stop rather than running for free. Balance arithmetic is otherwise untouched; iteration order (and so brownout victim order) is still incidental, now registration order instead of tree order, and is documented as such pending the power-priority feature the registry exists to enable. Alongside it, `BatteryComponent.total_power_stored` gained a `battery` save block (clamped to `max_power_stored` on load, absent key = pristine), so banks no longer reload empty. 359 GUT tests green; verified in-engine by a 34-check headless probe.
- **C5 — one storage-query helper** — done by [[WI-40_Storage_Query_Helper]], 2026-07-22. `StorageQuery` (`scripts/utility/storage_query.gd`) replaces the four near-identical scanners with two static queries, `find_source(pawn, resource, trip_cap, below_priority)` and `find_sink(pawn, resource, above_priority)`, sharing one filter+score walk. The strict-and-directional priority rule (what stops an equal-priority haul oscillating) and the deliberate no-filter asymmetry for piles and cargo sweeps are each stated once, at the helper, instead of being implied by four call sites. The scoring is extracted as pure statics plus accumulators (`sink_beats`, `source_beats_partial`, `SinkScorer`, `SourceScorer`) and pinned by a new 18-test `test_storage_query` suite — that rule set is what silently diverged and caused A5. Behavior-preserving: verified by a headless probe that ran the *old* four finders alongside the new ones on a live station across 59 samples, 14,790 checks, zero divergence. Per-resource indexing stays open by design. 377 GUT tests green.
- **All of the original 2026-07-13 section A** (the first nine confirmed bugs) — fixed by WI-01.
- **C1 — one resource-scan helper.** `ResourceScanner` (`scripts/utility/resource_scanner.gd`) now handles exported-build `.remap` suffixes and is used by the build menu, unlock trees, local upgrades and `SaveManager._build_lookups`.
- **C2 — `ModuleGraphVertex` → `RefCounted`.** Done; no manual `free()` remains in `module_graph.gd`.
- **C3 — event-driven storage job posting.** `StorageComponent`'s deficit/surplus scan moved to `_on_slow_tick` (`storage_component.gd:156`); its `_process` is now UI-only and documented as such. The posting scan also gained a shared `import_budget` so several under-desired resources in one bin can't jointly overcommit its free space.
- **C7 — `get_path_component()` null-safety.** Now `get_node_or_null` with a cached result (`module_base.gd:605`).
- **C8 (part) — `sort_priority_decending`.** Gone.
- **D1 — priority-as-routing needs a UI.** Delivered by WI-35: the Logistics overlay mode tints storage modules by routing priority and `OverlayFlowLayer` draws live haul arrows and numeric priority labels.
- **D2 — needs decay in game-hours.** Delivered by `TimeManager`; needs, disease, power, shields and market drift all consume sim-time via `slow_tick`/`hour_changed`.
- **D3 — job board spam guard.** Effectively addressed by the shared `import_budget` (a better mechanism than the per-module concurrent-notice cap originally suggested) plus one-import-job-per-resource slots.
- **D6 — extract magic group strings.** Delivered via C9 / [[WI-41_Group_Constants]] after being promoted to a code item.
