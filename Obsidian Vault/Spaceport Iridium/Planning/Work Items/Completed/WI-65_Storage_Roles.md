# WI-65 — Storage Roles & Strict Input Capacity

> **STATUS: COMPLETE (2026-08-23).** Both stages shipped. **1462 GUT tests, all green** (+42: `test_storage_roles.gd` at 24, `test_processor_allocation.gd` at 12, plus 6 in `test_stores_panel_model.gd` and rewritten autodump/claim coverage in `test_storage_data.gd`) — the suite was green at 1420 before this item, so nothing regressed. Verified further by a **45-check headless probe** driven through a real station, and by **three windowed 1920×1080 screenshots**. Save is **version 3**, migrating v2 in place.
>
> **The probe proves the deadlock end to end**, which is the whole point of stage 2: an algae vats fed only its first ingredient stops at 7 of a 15-unit bay, the second ingredient's 7 stay both depositable *and* reservable, and the recipe runs. Before this item the first ingredient took the whole bay.
>
> **Deviations from the design below:**
> 1. **Eight modules carried two storages, not five.** `algae_tank`, `algae_vats` and `hydroponics_bay` were missed in the survey because their nodes are named `Input`/`Output` rather than `… Storage`, and their output bins carried **no flag overrides at all** — so they were sitting at the scene default `accepts_imports = true`, i.e. a product bay that general storage would happily push biomass *into*. The merge fixes that as a side effect. §Goal below still says five; this is the correction.
> 2. **`EXCLUDED` replaced the planned `hauling_enabled` flag** (§7), on the argument that two booleans have four states, so the enum is a *re-encoding* rather than a lossy one. It has a real user after all: `_start_construction_job()` freezes the bin **with its materials still in it**, which a role-per-slot handles and a "roles only work on empty bins" shortcut would not.
> 3. **`default_role` was not in the design and is load-bearing.** A slot's role is derived rather than saved (§10), but the save block *creates* the slots it restores — so something has to say what role a restored or catch-all slot gets. It is what makes the docking bay's arrivals OUTPUT whatever turns up in them, and what stops a deconstruction site's restored refunds coming back as general stock that is hauled straight back in.
> 4. **`add_stored_resource()` must never re-role an existing slot**, which the design did not anticipate. The save block calls it for every restored resource; re-roling there flips a processor's carefully roled slots to `default_role` on every load. Owners now assign roles explicitly after.
> 5. **Capacity is `max_stored` + a new `output_capacity`, not a re-derived split.** The scenes keep the exact two numbers they already carried (the forge is still 30/20), which the "combined total, split by recipe proportion" reading would have changed on every module.
>
> **What the probe found that the design got wrong:**
> - **`export_priority` grouped `INPUT` with `GENERAL`** and handed a forge's ore back to any storeroom that asked. Caught by `test_storage_roles.gd` on its first run — INPUT refuses exports, same as EXCLUDED.
> - **"No intake slots" is not the same as "export only".** An **empty** storeroom has no slots either, so the first cut of `has_intake_slots()` stripped the priority stepper off every fresh storeroom. It falls back to `default_role` now, and `test_an_empty_storeroom_keeps_its_stepper` pins it.
> - **Two probe checks were wrong, not the code.** A single-ingredient refinery's allocation *is* its whole intake pool, so "capped" and "pool full" are the same event there and the strict-cap assertion proved nothing — it needs a two-ingredient module, which is also the real scenario. And `find_sink` legitimately answers "nowhere" on the starting station, because it ships **full**: a check that cannot tell a routing bug from a full station is not verification.
>
> **What the screenshots caught that 45 probe checks and 1460 tests did not — five defects, and one of them was a functional break:**
> 1. **The mining bay could not hold ore at all.** Its slots are OUTPUT and therefore draw on `output_capacity`, which the scene left at **0** while its 80 sat in `max_stored` — an intake pool nothing on that module could ever use. Every check agreed with itself because the Stores card sums both pools and printed a plausible `0 / 80`. `ready_constructed()` now **asserts** that a bin with OUTPUT slots has an output pool, which is the check the design asked for and the first pass never wrote.
> 2. **The docking bay lost its priority stepper while its own card said "its priority is still yours."** `has_intake_slots()` counted INPUT slots, and the bay grows its staging slots only when a sell order exists. The rule is now about **capacity, not slots** — `max_stored <= 0` means no intake side — which fixes the empty-storeroom case in the same stroke and drops the `default_role` dependency entirely.
> 3. **The inspector's meta line read `HAUL +100` on a refinery the Stores panel had at `+1`.** `get_component_by_type(StorageComponent)` returns the first bin the walk finds, which is **construction's**, sitting at +100 on every module. Pre-existing, and invisible until one module's two numbers could be compared side by side.
> 4. **A mining bay's ore rows read `0 / 0`.** Scene-authored OUTPUT slots kept `desired = 0`, because `_ready()` only initialised the receiving ones. Every slot now starts at the pool it draws on, which is what `add_stored_resource()` already did — the two were disagreeing.
> 5. **An orphaned `Priority` label above a sentence running off the panel edge.** Hiding the stepper left its row label behind; the row is hidden as a unit now.
>
> The remaining visual claim not exercised is the **"Auto-dump above N"** stepper, which needs the dump dialog driven open.
>
> ---
>
> **Two stages, shipped separately.** Stage 1 (§1–§10) is the role change and the merge; stage 2 (§11–§15) makes `desired` a hard cap **on INPUT slots**. They are split because stage 2's blast radius is entirely different from stage 1's — it touches the claim contract, the import budget and the overflow paths — and landing them together would leave no way to tell which one broke hauling. **Stage 1 must be verified green before stage 2 starts.**

## Goal

**Each module carries at most one non-construction `StorageComponent`.** Today **eight** do not — `ore_processor`, `forge`, `electrolysis_processor`, `ice_processor`, `algae_tank`, `algae_vats`, `hydroponics_bay` and `docking_bay_left_base` each carry an input bin and an output bin — and the reason is that direction and priority are both properties of the *component*, so one component cannot both pull a resource in and push a different one out.

The fix is to move **direction** down onto the per-resource slot as a **role**, and to stop authoring the output side's priority at all.

Four deliverables:

1. **`accepts_imports` / `accepts_exports` become one `role` on `StorageData`** — `GENERAL`, `INPUT`, `OUTPUT`, `EXCLUDED`.
2. **OUTPUT slots are pinned to the priority floor**, unsettable and unshown, so a component has exactly one player-facing priority however many roles it holds.
3. **The eight two-storage modules become one-storage modules**, and `ProcessorComponent` / `TradeComponent` each drop a `NodePath`.
4. **`desired` becomes a hard cap on INPUT slots** (stage 2), with the posting target derived from the role and autodump given its own threshold.

Deliverable 2 is what makes the whole thing work, and §2 is about why.

---

# Stage 1 — Roles and the merge

## 1 — Direction is a role on the slot, not two flags on the component

`StorageComponent.accepts_imports` and `accepts_exports` are deleted. `StorageData` gains:

```gdscript
enum Role { GENERAL, INPUT, OUTPUT, EXCLUDED }

@export var role: Role = Role.GENERAL
```

| Role | Receives hauls | Ships hauls out | Who authors it |
|---|---|---|---|
| `GENERAL` | yes | yes | scene default; storerooms, the starting module |
| `INPUT` | yes | **no** | a recipe's ingredients, a mess hall's food, a reactor's fuel, a bay's sell-order staging |
| `OUTPUT` | **no** | yes | a recipe's products, mined ore, arriving purchases, deconstruction refunds |
| `EXCLUDED` | **no** | **no** | a bin frozen out of hauling entirely — see §7 |

**Four roles, not three, because two booleans have four states.** `EXCLUDED` is the fourth corner of the table the flag pair could express, and including it is what makes the refactor a *re-encoding* rather than a lossy one: every state reachable before this item is reachable after it, so the conversion is provably behaviour-preserving. Three roles plus a `hauling_enabled` flag would have said the same thing in two places, and a bin whose flag disagreed with its role would be a state nobody could reason about.

Two flags that were always set in opposition become one word that cannot be set in contradiction. The important property is that **the role is per-slot**, which is the entire reason one component can now do both jobs: a merged refinery bay holds `iron_ore` at `INPUT` and `iron` at `OUTPUT` in the same `storage_data` dictionary.

**A resource is one role at a time.** A recipe naming the same resource as both an input and an output would be ambiguous, and `_sync_storages` must assert against it rather than pick a winner silently.

**Roles govern hauling, not the storage API.** `role` decides what `StorageQuery` will do with a slot and what jobs the bin posts. It does **not** gate `deposit()` / `withdraw_stacks()` / `can_withdraw()` — a processor deposits into its own OUTPUT slot and consumes from its own INPUT slot directly, `ConstructionComponent` consumes materials out of an `EXCLUDED` bin, and `TradeComponent` moves goods in and out of both sides on a sale. Making `EXCLUDED` block the direct API would freeze construction solid, and that is the single most likely way to get this wrong.

## 2 — OUTPUT sits at the priority floor, and is neither settable nor shown

`StoresModel.PRIORITY_MIN` is `-100`, which is already `REFUSE_AT` — the bottom of the band table. An OUTPUT slot resolves to that floor, always. It is not saved per slot, not editable, and not rendered as a stepper.

This is deliberately **not** an offset from the component's own priority. An offset would preserve today's `-1` relationship, but the floor is better on three counts:

- **It ships to more places.** An output at `-1` cannot deliver into a player's `-5` "last resort" bin, because `find_sink` demands *strictly greater*. At `-100` it can. An output bin is a temporary holding spot, not storage — "anywhere but here" is the correct routing for it.
- **It keeps one editable priority per component.** `scripts/utility/stores_model.gd:188` documents, and `test_stores_model.gd` asserts, that priority is editable on **every** bin — deliberately, because priority is the routing language. Because OUTPUT is a role on slots rather than a bin of its own, the *component* still has exactly one editable number and that rule survives the change untouched. An offset scheme would have needed the same thing; a second settable number would have broken it.
- **It deletes a constant.** `JobPriorities.DECONSTRUCTION_EXPORT` (`-99`) exists solely to say "push these refunds anywhere". `modules/components/construction_component.gd:197` sets `accepts_imports = false`, `desired = 0` and that priority together — which is role `OUTPUT` spelled out longhand. The constant is removed and `setup_storage_post_deconstruction()` sets the role instead.

**A module whose slots are all OUTPUT has no priority of its own, and says so.** `mining_bay` is the vanilla case; any module that only produces is the general one. `StoresModel.priority_editable()` becomes false for a component with no `GENERAL`/`INPUT` slot, and the card prints its blocker in place of the stepper:

> This module only exports goods and does not have its own priority.

That is a real behaviour change — today a player can raise the mining bay's priority to hoard ore in the bay — and it is taken deliberately: OUTPUT *implies* `PRIORITY_MIN`, so a settable number on an export-only bin would be a control that does nothing. This is the one exception to the "priority is editable on every bin" rule and it needs writing into `stores_model.gd:188`'s docstring, into `test_stores_model.gd`, and into the CLAUDE.md line that states the rule.

## 3 — Priority resolution moves onto the component; `StorageQuery` asks per resource

`StorageQuery` currently reads `storage.priority` and the two flags at three points (`scripts/utility/storage_query.gd:54`, `:91`, `:101`). All three become per-resource questions:

```gdscript
## The priority this bin exports `resource` at, or REFUSED when it never will.
func export_priority(resource: ResourceData) -> int

## The priority this bin accepts `resource` at, or REFUSED when it never will.
func import_priority(resource: ResourceData) -> int
```

| Role | `import_priority` | `export_priority` |
|---|---|---|
| `GENERAL` | `priority` | `priority` |
| `INPUT` | `priority` | `REFUSED` |
| `OUTPUT` | `REFUSED` | `PRIORITY_MIN` |
| `EXCLUDED` | `REFUSED` | `REFUSED` |

A resource with no slot returns `REFUSED` from both unless `allow_any_resource`, in which case it resolves at the component's default role.

`REFUSED` is a distinct sentinel from `StorageQuery.ANY_PRIORITY` and must not be conflated with it: `ANY_PRIORITY` means *"the caller has no priority to compare against"* and **skips the filter**, which is why a pile or a carried-cargo sweep can be deposited anywhere. A bin that refuses must be rejected on **every** path including those two — so the refusal is checked before the comparison, never expressed as an extreme number.

That distinction is load-bearing today and is easy to lose: `find_sink(ANY_PRIORITY)` skips the priority test entirely, so a `-100` bin is protected by its *role*, never by its number. This is further reason not to show the number for OUTPUT — it is decoration, and the role is the mechanism.

The strict inequalities stay exactly as they are. They are what stops a haul flip-flopping between two equal bins forever, and nothing here changes that argument.

## 4 — Role decides the posting rule

`desired` and the role together decide what a slot asks for:

| Role | Import job posts when | Export job posts when |
|---|---|---|
| `GENERAL` | `stored < desired` | `stored > desired` |
| `INPUT` | `stored < desired` | never in steady state — see §12 |
| `OUTPUT` | never | `stored > 0` |
| `EXCLUDED` | never | never |

`OUTPUT`'s export-on-anything is what `desired = 0` was simulating (`modules/components/processor_component.gd:243`). Saying it as a rule rather than as a magic zero is what lets `desired` become a cap in stage 2 without the output side collapsing — with a strict cap and `desired = 0`, `_try_deposit_output`'s `can_deposit` check (`processor_component.gd:341`) would be false forever and **no processor could ever deposit its own output**.

## 5 — Capacity is per role, and it keeps the numbers the scenes already have

`max_stored` is component-wide today and `space_available()` sums across every slot (`modules/components/storage_component.gd:396`). Merging two bins into one would therefore share one pool between the input and output sides — which means **a backed-up output starves the input**, and at the docking bay means **a large staged sell order silently blocks an incoming purchase** (`scripts/managers/trader_manager.gd:234` gates buys on the arrivals bin's `space_available()` and already raises an `_import_full_alerted` warning the player would now have no way to explain).

So capacity is split by role:

- **`max_stored` keeps its name and its meaning** — the pool for `GENERAL` and `INPUT` slots. Every existing scene value is correct as authored and nothing needs re-tuning.
- **A new `output_capacity: int`** is the pool for `OUTPUT` slots.

`GENERAL` and `INPUT` never coexist on one module in practice (a module either holds stock or consumes it), so two numbers are enough; if that ever stops being true it becomes a third field, not a redesign. `EXCLUDED` slots count against whichever pool they were created in.

The merged scenes therefore carry **the same two numbers they carry today**, moved onto one node: the forge is `max_stored = 30`, `output_capacity = 20`. This deliberately replaces the "combined total, split proportionally by recipe" approach from the design discussion — that made the output buffer a function of the recipe's *arity* (a `5 iron + 1 catalyst → 1 plate` recipe would get one seventh of the pool for its output), which nobody has tuned and which would change behaviour on every existing module. Recipe proportions still distribute `desired` **within** a role's pool, exactly as `_sync_storages` does now (`processor_component.gd:234`).

`space_available()` becomes role-qualified. Every call site must say which pool it means:

| Call site | Pool |
|---|---|
| `StorageComponent._on_slow_tick` import budget | the slot's own role |
| `StorageComponent.can_deposit` | the slot's own role |
| `ProcessorComponent._satisfies_recipe` / `_try_deposit_output` | `OUTPUT` |
| `TraderManager` purchase sizing | `OUTPUT` |
| `StoresModel.Entry.capacity` / `fill()` | see §9 — one meter per role |

**Assert** that a component with `OUTPUT` slots has non-zero `output_capacity`. A silently-zero pool is a processor that never produces, and it is exactly the kind of thing a scene edit introduces without a crash.

## 6 — A recipe's `desired` is an integral number of runs

`_sync_storages` currently splits the input pool by ratio and rounds up (`processor_component.gd:234`):

```gdscript
desired[i] = ceili(qty[i] / total * max_stored)
```

That is wrong in a way nothing notices today and would be load-bearing under §11. Ceiling-rounding each share independently lets the shares **sum above the pool**, and two shipped recipes already do:

| Recipe | pool | today | sum | runs | after | sum |
|---|---|---|---|---|---|---|
| Farm Algae (vats) | 15 | 8, 8 | **16** | 7 | 7, 7 | 14 |
| Grow Plants | 15 | 8, 8 | **16** | 7 | 7, 7 | 14 |
| Farm Algae (tank) | 20 | 10, 10 | 20 | 10 | 10, 10 | 20 |
| Melt Ice | 10 | 10 | 10 | 10 | 10 | 10 |
| Refine ×4 | 20 | 20 | 20 | 10 | 20 | 20 |
| Forge Steel | 30 | 10, 20 | 30 | 10 | 10, 20 | 30 |
| Electrolyze Water | 10 | 10 | 10 | 5 | 10 | 10 |

The replacement allocates by **whole runs** — the same integral number of batches' worth of every ingredient:

```gdscript
var runs: int = floori(max_stored / total)   # total = sum of recipe.inputs.values()
desired[i] = runs * qty[i]
```

Three properties, and they are the whole argument:

- **It cannot overflow the pool.** `sum(desired) == runs * total <= max_stored` by construction, so the per-slot caps of §11 always fit inside the capacity of §5. No rounding rule has to be trusted.
- **The proportions are exactly the consumption proportions**, not an approximation of them, so no ingredient can be stocked in a ratio that starves another — which is the failure §11 exists to prevent, removed at the source rather than caught downstream.
- **It reproduces every shipped value that was already correct** (five of seven configurations above) and fixes the two that were not. This is a bug fix that happens to also be the allocation stage 2 needs, which is why it ships in stage 1.

It undershoots the pool when `total` does not divide `max_stored` — 14 of 15 on the algae vats. That is accepted: the leftover is a unit of slack, and what matters is that the bay holds a whole number of runs.

**`runs < 1` is an authoring error, not a case to clamp.** If `total > max_stored` the bay cannot hold one batch of ingredients, and no allocation rescues that — clamping to `runs = 1` would put the caps' sum *above* the pool, which is precisely the state that lets one ingredient starve another, and the module still could not run a batch even if it filled perfectly. So:

- `ProcessorComponent` recipe eligibility gains a capacity test, so a recipe that cannot fit is never selectable on that module;
- it `push_error`s naming the module and the recipe, because for a mod this is the difference between "my refinery does nothing" and a diagnosable mistake;
- the content sweep pins it for vanilla and for the sample mod (§Tests).

No shipped recipe comes close — the tightest is Electrolyze Water at 5 runs — so the guard is a mod-facing and future-facing one from day one.

**`runs` is worth showing.** "Holds 10 runs' worth" is a more useful readout on the Stores card than a bare desired figure, and it is the number that explains why the slot stops filling where it does.

## 7 — Construction storage is the `EXCLUDED` role's user

`ConstructionComponent` sets **both** flags false to freeze its bin during the preview and construction phases (`construction_component.gd:41`, `:127`), and that is exactly `EXCLUDED`. The lifecycle maps one-for-one:

| Phase | Today | After |
|---|---|---|
| Preview / pre-blueprint | both flags false | slots `EXCLUDED` |
| Building | `accepts_imports = true`, priority `+99` | slots `INPUT`, priority `CONSTRUCTION_IMPORT` |
| Free module (no `resource_costs`) | both flags false, UI hidden | slots `EXCLUDED`, UI hidden |
| Deconstructing | `accepts_imports = false`, priority `-99`, `desired = 0` | slots `OUTPUT` |

Because the freeze is per-slot rather than per-component, the transition is *"re-role every slot"* rather than *"flip a flag"*, and `ConstructionComponent` needs a small helper for it. In practice the frozen states are reached with the bin empty (`empty_all()` runs first at `:41`), so the helper is usually a no-op walk — but it must exist rather than being skipped on the assumption the bin is empty, because deconstruction reaches its transition with stock present.

**Honest caveat:** on vanilla content `EXCLUDED` may never actually be observed on a populated slot, which makes it look like a role with no users. It earns its place anyway — it completes the encoding (§1), it gives a mod a way to author an inert bin, and it is where construction's freeze goes if that freeze ever has to happen with materials already delivered.

The "at most one storage component" rule is therefore **"one storage, plus construction's"** — and that should be written down as the rule rather than left as an exception someone rediscovers.

## 8 — The docking bay stops being hand-configurable

`docking_bay_left_base.tscn` sets `player_configurable = true` on its sell-staging bin, so the player can edit its accepted list and desired amounts by hand — while `TradeComponent` is *also* driving both from the trade sheet and from contract demand (`modules/components/trade_component.gd:109`, `:141`, and the stranded-stock dump at `:62`). Two authorities on one bin, and the sheet wins on every recalculation, so the player's edit silently evaporates.

The flag comes off. The bay's contents are the sheet's: sell orders create `INPUT` slots sized to the order, purchases create `OUTPUT` slots as goods arrive. Its **priority stays editable** — it has INPUT slots, so §2's exception does not apply — and its default stays `JobPriorities.TRADE_EXPORT_BIN` (+3), which is load-bearing (it out-pulls ordinary storerooms at +1 but loses to the kitchen and to construction) and must not quietly reset to the scene default during the merge.

`StoresModel.contents_locked_reason()` needs a sentence for this case — *"Set by the trade sheet"* — because a locked control names its blocker rather than just going grey (WI-54).

Note this is mostly deletion: the sheet-driven half already exists and works. What is being removed is the second way in.

## 9 — Vocabulary and UI

**`StoresModel.priority_label(-100)` stops saying "Refuses."** Nothing the player can configure refuses imports any more — refusal is a role, and roles are not player-set — so the word would be a lie on the only control that can show it. It becomes **"Last choice"**: `<= REFUSE_AT` now means *last in line*, which is what the number actually does. `REFUSE_AT` is renamed with it (`LAST_CHOICE_AT`), and `LEGEND`'s long-form line follows. This is a `test_stores_model.gd` change, not just a string change.

The rest of the UI work:

- **One Stores card per module**, because there is one component per module. Where a module has both roles the card shows **two meters** — an IN meter against `max_stored` and an OUT meter against `output_capacity` — and one priority stepper. `StoresModel.Entry` grows a per-role breakdown; `fill()` becomes per-role.
- **An OUTPUT-only module's card shows no stepper**, and prints §2's sentence in its place.
- **The inspector's Stores tab merges by construction.** The `Stores 2` numbering in `InspectorTabPlan.module_tabs` stays (a deconstruction site still grows a second bin, and the comment at `ui/inspector/inspector_tab_plan.gd:171` stays true), but no vanilla module hits it any more.
- **Slots group by role in the tab**, IN above OUT, with the role as the section heading. A single-role bin prints no heading — same rule as `ModuleStatusTab`'s lone section (WI-64).
- **`ui/windows/ui_storage_component.gd` and `ui/windows/storage_overlays.gd`** both render per-resource `desired` steppers today; both need the role split, and in stage 2 the INPUT/GENERAL distinction from §11 plus the autodump threshold (§15).
- **The logistics overlays lose a hack.** `ui/overlay_controller.gd:421` and `ui/overlay_flow_layer.gd:103` both pick the largest-magnitude priority among a module's storages with `absi()`, which exists *only* because a module can have two. With one component they read `storage.priority` directly.

## 10 — Save migration

Storage saves per instance, keyed by node path under `"storage"` (`storage_component.gd:509`), and `ModuleBase` walks live components rather than enumerating them by hand — that changed in **WI-47 M2**, and the CLAUDE.md line claiming the chain is hand-enumerated is stale for modules (it is still true for `SaveManager._load_pawns`).

So an old save of a forge has two blocks — `"Input Storage"` and `"Output Storage"` — and the new scene has one node. `_warn_orphaned_blocks` will notice and warn, which is the detection mechanism, not the fix.

**Bump `SAVE_VERSION` to 3 and add `_migrate_2_to_3` to the `_migrations` table** (`scripts/managers/save_manager.gd:59`). It folds the pair: contents merge into the surviving node's block, `priority` is taken from the **input** block (the output block's priority is now derived and its saved value is discarded), and each restored slot is assigned its role from the live component's post-`_sync_storages` layout rather than from anything in the save. Roles are **derived, not saved** — the recipe restores before storage does (`ProcessorComponent.save_order()` runs first, deliberately), so the layout is already correct when contents land on top of it.

Name the surviving node consistently — `Storage Bay`, matching the storerooms — so the migration has one target path to write and mods have one convention to follow.

---

# Stage 2 — Strict input capacity

## 11 — `desired` binds on INPUT slots, and only on INPUT slots

The problem strictness solves is specific, and so is the fix:

> A forge's `iron_ore` slot fills to the whole bay. There is no room for `carbon`. The recipe can never run — the forge cannot process what it has, and an INPUT slot does not export, so it cannot get rid of it either. The module is stuck forever.

That is a property of a bin whose contents are **consumed in fixed proportions**. It is not a property of a storeroom, where stock over `desired` is simply surplus and there is an export job already posted to move it. So:

| Role | Is `desired` a hard cap? | Why |
|---|---|---|
| `INPUT` | **yes** | over-filling one ingredient starves another and deadlocks the module |
| `GENERAL` | **no** — target only, as today | surplus exports; nothing is starved by holding it |
| `OUTPUT` | n/a | bounded by `output_capacity`; `desired` is unused (§4) |
| `EXCLUDED` | n/a | no hauling either way |

This is the same shape as the rest of the item: **the role decides direction, the role decides the posting rule, and the role decides whether `desired` binds.** One word answers all three questions and there is no fourth knob.

It also shrinks the change enormously. `_ready` sets `desired = max_stored` for every import-accepting slot (`storage_component.gd:59`) and `add_stored_resource` does the same for new ones (`:100`), so a mess hall, a reactor, a hydroponics bay and an O2 generator all have `desired == max_stored` and are unaffected. The slots where `desired < capacity` and strictness actually bites are exactly two:

- **a processor's run-allocated inputs** (§6) — the case this exists for;
- **the docking bay's sell-order staging**, sized by `_set_slot_desired` (`trade_component.gd:141`).

Both are machine-set, which also means the `allow_any_resource` trap from the earlier draft mostly evaporates: the starting module is `GENERAL` and the bay's arrivals are `OUTPUT`, so no catch-all bin is ever subject to the cap. The `desired = max_stored` default still deserves a comment saying why it exists, but it is no longer load-bearing for those bins.

**Lowering `desired` below current stock still does not dump.** On a `GENERAL` bin the surplus stays and exports, exactly as now. On an `INPUT` bin it sheds — see §12.

## 12 — An over-cap INPUT slot sheds to the overflow pile

Making `desired` a cap opens a hole the old behaviour did not have: an INPUT slot can end up **over** its cap without anything depositing into it, because the cap itself moves.

Two ways that happens, both existing code paths:

- **A recipe change.** `_sync_storages` recomputes every ingredient's run allocation (§6). A resource the new recipe still uses, but at a lower run count or a smaller ratio, is now over cap. Today only resources the new recipe *drops* are handled, by `_clear_input_slot` (`:245`).
- **A sell order shrinks.** `TradeComponent` already handles this one (`trade_component.gd:129` withdraws the surplus, `:62` dumps stranded stock).

Left alone, over-cap INPUT stock is stranded — which is the very deadlock §11 exists to prevent, relocated one step. So `_sync_storages` must shed it, and the mechanism is the one `_clear_input_slot` already uses: **withdraw down to the cap and add the remainder to the module's overflow pile**, after `end_all_jobs()` so reservations reconcile first.

Deliberately a pile and **not** an export job. An export from an INPUT slot would post at the component's priority — a forge input sits at +1 — and `find_sink` demands *strictly greater*, so ordinary storerooms at 0 would refuse it and the goods would have nowhere to go but a construction site. Pile collection uses `find_sink(ANY_PRIORITY)`, which accepts any bin with room. The pile is the path that works, it is already written, and it already keeps the no-silent-resource-loss invariant.

Generalize `_clear_input_slot(resource)` from *"this resource is gone"* to *"this slot is over cap"*, with removal being the case where the cap is zero.

## 13 — The deposit claim becomes a per-slot question on INPUT

`StorageData.can_take_claim` returns `true` unconditionally for `STORAGE_DEPOSIT`, with a comment saying *deposit space is a component-level question, so the reservation is pure bookkeeping* (`modules/components/storage_data.gd`). For `GENERAL` and `OUTPUT` that stays exactly true — their bound is the role's pool, which `StorageData` deliberately cannot see. For `INPUT` it becomes false, and it is the one place where missing the change produces a bug rather than an error:

> Five haulers each reserve a deposit against the same five remaining units under `desired`; four arrive at a full slot.

The fix is a role branch, and it fits the existing architecture rather than fighting it — an INPUT slot's bound is `desired`, which is **slot-local**, so `StorageData` can answer it without reaching for `Global` and its pure GUT suite survives:

```gdscript
if kind == ClaimSpec.Kind.STORAGE_DEPOSIT:
	# INPUT is capped per slot (WI-65 §11), so the reservation has to be real.
	# GENERAL/OUTPUT are bounded by the component's pool, which this class
	# cannot see and deliberately does not try to - whatever picked this bin
	# is what checked there was room.
	if role != Role.INPUT:
		return true
	return stored + reserved_deposit + amount <= desired
```

The shared import budget in `_on_slow_tick` (`storage_component.gd:135`) needs **both** bounds for an INPUT slot after this — the role's pool *and* the per-slot headroom — not just `space_available()`.

## 14 — Overflow stays on the pawn

`find_sink` deliberately probes with one unit rather than the whole load, because *"whatever doesn't fit stays on the pawn and gets swept next tick"* (`storage_query.gd:96`). That path already exists, already works, and does not litter the floor. It stays: a partial deposit into a capped INPUT slot leaves the remainder in the pawn's inventory.

A `ResourcePile` is created **only** when `find_sink` returns null — nowhere in the station will take the goods — which is `PawnBase.start_job()`'s existing fallthrough. Together with §12 that is two pile paths, both pre-existing, and no new one.

## 15 — Autodump gets its own threshold

**This is no longer forced, and ships on its own merits.** Under a blanket strict `desired`, `autodump_amount()` — `stored - desired - reserved_withdraw` (`storage_data.gd:42`) — could never be positive and autodump would have been dead code. With strictness confined to INPUT (§11) that breakage disappears: autodump is only offered on `contents_editable` bins, and once §8 removes the docking bay's flag **every autodump-capable bin is `GENERAL`**, where `desired` is still a target and stock can still exceed it.

It ships anyway because the current arrangement makes two mechanisms race over the same units. With one number, stock above `desired` is simultaneously *"post an export job"* and *"destroy this"*, and which one wins depends on whether a hauler happens to be free. A second threshold turns that into a band:

```gdscript
## Destroy stock above this level. -1 disables. Sits at or above `desired`:
## `desired` is where hauling stops filling, this is where the station starts
## destroying, and the gap between them is the grace the export job gets to
## move the surplus before the vent opens.
@export var autodump_above: int = -1
```

`autodump_amount()` becomes `maxi(stored - autodump_above - reserved_withdraw, 0)`, gated on `autodump_above >= 0`. **The constraint is `autodump_above >= desired`** — the reverse of what a cap-shaped reading would suggest — because a threshold *below* `desired` would destroy stock the bin is still asking to be filled with. Defaulting `autodump_above` to `desired` on enable reproduces today's behaviour exactly, so this is opt-in headroom rather than a retune.

The existing `autodump: bool` is replaced by the sentinel rather than kept beside it — two fields that can disagree about whether dumping is on is a state nobody should have to reason about. The save block writes `autodump_above` and reads a legacy `autodump: true` as `autodump_above = desired`, which is exactly what it meant.

UI: `storage_overlays.gd:259`'s *"Keep dumping the surplus automatically"* checkbox becomes a labelled stepper — **"Auto-dump above N"** — bounded `desired .. max_stored`. `StorageComponent.autodump_warning()` and the amber `UIPalette.Row` treatment on the Stores chip (`ui/windows/stores_module_card.gd:297`) both carry over unchanged; autodump destroys stock, and that warning is the explicit action the resource invariant demands.

---

## Files

**Stage 1**

| File | Change |
|---|---|
| `modules/components/storage_data.gd` | `Role` enum (four values) + `role` |
| `modules/components/storage_component.gd` | delete `accepts_imports`/`accepts_exports`; add `output_capacity`, `import_priority()`, `export_priority()`; role-qualify `space_available()` / `can_deposit()`; save block |
| `scripts/utility/storage_query.gd` | three call sites → the per-resource accessors; `REFUSED` handling on all paths incl. `ANY_PRIORITY` |
| `scripts/jobs/job_priorities.gd` | delete `DECONSTRUCTION_EXPORT` |
| `modules/components/processor_component.gd` | one storage ref; `_sync_storages` assigns roles and allocates `desired` by whole runs (§6); same-resource assert; recipe-fits-the-bay eligibility test; `_satisfies_recipe` / `_try_deposit_output` role-qualified |
| `modules/components/trade_component.gd` | one storage ref; **rename `export_storage` → the sell-staging slots (role `INPUT`) and `import_storage` → the arrivals slots (role `OUTPUT`)** — the current names are the exact inverse of the roles and will read backwards forever if left |
| `modules/components/construction_component.gd` | re-role helper; `EXCLUDED` / `INPUT` / `OUTPUT` per phase |
| 8 module scenes | merge two nodes into `Storage Bay`; add `output_capacity` |
| ~8 module scenes | flags → roles on their slots |
| `modules/docking_bays/docking_bay_left_base.tscn` | drop `player_configurable` |
| `scripts/managers/save_manager.gd` | `SAVE_VERSION = 3`, `_migrate_2_to_3` |
| `scripts/managers/trader_manager.gd`, `contract_manager.gd` | renamed fields, role-qualified `space_available()` |
| `scripts/utility/stores_model.gd` | `REFUSE_AT` → `LAST_CHOICE_AT`, label, `LEGEND`, per-role `Entry`, `priority_editable` exception + its sentence, `contents_locked_reason` for the trade sheet |
| `ui/windows/stores_module_card.gd`, `stores_panel.gd`, `ui_storage_component.gd`, `storage_overlays.gd`, `storage_resource_line.gd` | two meters, role sections, the OUTPUT-only sentence |
| `ui/overlay_controller.gd`, `ui/overlay_flow_layer.gd` | drop the `absi()` collapse |
| `CLAUDE.md` | the priority-always-editable rule gains its OUTPUT-only exception; the hand-enumerated-save-chain line is stale for modules |

**Stage 2**

| File | Change |
|---|---|
| `modules/components/storage_data.gd` | `autodump_above` replaces `autodump`; `autodump_amount()`; `can_take_claim` INPUT branch |
| `modules/components/storage_component.gd` | INPUT-strict `can_deposit`; both bounds in the import budget for INPUT; save block legacy read |
| `modules/components/processor_component.gd` | `_clear_input_slot` generalized to shed over-cap slots (§12) |
| `scripts/jobs/actions/` (deposit actions) | partial deposit leaves the remainder on the pawn |
| `ui/windows/storage_overlays.gd` | checkbox → "Auto-dump above N" stepper, floor `desired` |

## Tests

`StorageData`, `StorageQuery` and `StoresModel` are all pure and already covered, so most of this is testable without a running game.

- **`test_storage_query.gd`** — a source/sink pair per role, all four; that an `OUTPUT` slot is never a sink and an `EXCLUDED` slot is neither, **even when the query passes `ANY_PRIORITY`**. That is the one that catches conflating `REFUSED` with the sentinel.
- **`test_storage_data.gd`** — the four-way role→priority table; `can_take_claim` bounded on INPUT and unbounded on GENERAL/OUTPUT with reservations outstanding; `autodump_amount()` against `autodump_above` including disabled and including `autodump_above > desired`; legacy `autodump: true` reading back as `desired`.
- **`test_stores_model.gd`** — the renamed band and label; per-role `fill()`; `priority_editable` true for a mixed-role component and **false** for an OUTPUT-only one, with a non-empty sentence in the second case; `contents_locked_reason` for the trade-sheet bay.
- **`test_processor_allocation.gd`** (new) — the run allocator over every recipe in `data/`: `sum(desired) <= max_stored` always, `desired[i] / qty[i]` equal across ingredients, and the two algae/hydroponics cases pinned at their corrected values so a future retune of `max_stored` cannot silently reintroduce the overshoot.
- **A content sweep**, in the spirit of WI-62's and WI-63's: walk every `modules/**/*.tscn` and assert **(a)** at most one non-construction `StorageComponent` per module, **(b)** every `OUTPUT`-bearing component has non-zero `output_capacity`, **(c)** no resource is both an input and an output of the same recipe, **(d)** every recipe in `data/recipes/` fits one batch in every module its `processor_tags` reach (§6), including the sample mod's. That sweep is what keeps the invariant true after the item closes, and it is the only test here that would catch a bad scene edit six months from now.

## Verification

Headless probe (the standing fallback), driven through the states rather than asserted from `_ready`:

1. A refinery imports ore into `INPUT`, produces, and exports product from `OUTPUT` — on **one** component.
2. A deconstruction site's refunds reach a storeroom, with `DECONSTRUCTION_EXPORT` gone.
3. Purchases land at the docking bay while a large sell order is staged — the case the shared pool would have broken.
4. Save mid-refine, reload, confirm contents, roles and priority all survive; and separately load a **pre-migration** save of a forge with stock in both bins and confirm the fold.
5. Stage 2 only: **the deadlock this exists for** — a two-ingredient forge fed only its first ingredient, asserting the second ingredient's share stays reservable and the recipe eventually runs. This is the acceptance test for the whole of stage 2; if it does not fail before the change and pass after it, the change is not doing anything.
6. Stage 2 only: N haulers converge on an INPUT slot with headroom for one, and exactly one deposit succeeds.
7. Stage 2 only: swap a running processor's recipe to one with different proportions and confirm the over-cap ingredient reaches a storeroom via the overflow pile rather than stranding.

**Screenshots are part of this**, per the standing rule — every panel item in the UI rework found defects a headless probe could not see. At minimum: a two-role Stores card (both meters, one stepper), the mining bay's stepper-less card with its sentence, a merged inspector Stores tab with IN/OUT sections, a single-role bin showing no heading, the docking bay's locked-contents sentence, and the "Auto-dump above N" stepper.

## Open questions

- **Does `EXCLUDED` ever hold a populated slot on vanilla content?** Probably not (§7). If a pass through the construction lifecycle confirms it never does, that is worth a comment on the enum member rather than a reason to remove it.
- **Should `GENERAL` ever be able to opt into a hard cap?** §11 says no on the grounds that surplus exports. A player who wants a storeroom to hold *exactly* 50 iron has `desired` for the haul target and `autodump_above` for the vent, which between them cover the intent without a third mode. Revisit only if play says otherwise.
- **Outputs share one pool on purpose, and must keep doing so.** A multi-output recipe deposits atomically — `_satisfies_recipe` refuses to run unless *every* product fits — so a blocked H2 slot stalling an electrolysis run is correct: you cannot electrolyse water into just hydrogen. Giving each product its own capped slot would let a run proceed when only some outputs fit, which is either a partial deposit or a silent loss of the rest. `output_capacity` stays a single shared pool and §6's run allocator is deliberately **not** applied to it.
