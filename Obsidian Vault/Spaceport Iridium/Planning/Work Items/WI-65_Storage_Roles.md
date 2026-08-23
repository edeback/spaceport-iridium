# WI-65 — Storage Roles & Strict Capacity

> **Two stages, shipped separately.** Stage 1 (§1–§9) is the role change and the merge; stage 2 (§10–§12) makes `desired` a hard cap. They are split because stage 2's blast radius is entirely different from stage 1's — it touches the claim contract, the import budget and the overflow paths — and landing them together would leave no way to tell which one broke hauling. **Stage 1 must be verified green before stage 2 starts.**

## Goal

**Each module carries at most one non-construction `StorageComponent`.** Today five do not — `ore_processor`, `forge`, `electrolysis_processor`, `ice_processor` and `docking_bay_left_base` each carry an input bin and an output bin — and the reason is that direction and priority are both properties of the *component*, so one component cannot both pull a resource in and push a different one out.

The fix is to move **direction** down onto the per-resource slot as a **role**, and to stop authoring the output side's priority at all.

Four deliverables:

1. **`accepts_imports` / `accepts_exports` become one `role` on `StorageData`** — `INPUT`, `OUTPUT`, `GENERAL`.
2. **OUTPUT slots are pinned to the priority floor**, unsettable and unshown, so a component has exactly one player-facing priority however many roles it holds.
3. **The five two-storage modules become one-storage modules**, and `ProcessorComponent` / `TradeComponent` each drop a `NodePath`.
4. **`desired` becomes a hard per-resource cap** (stage 2), with the posting target derived from the role and autodump given its own threshold.

Deliverable 2 is what makes the whole thing work, and §2 is about why.

---

# Stage 1 — Roles and the merge

## 1 — Direction is a role on the slot, not two flags on the component

`StorageComponent.accepts_imports` and `accepts_exports` are deleted. `StorageData` gains:

```gdscript
enum Role { GENERAL, INPUT, OUTPUT }

@export var role: Role = Role.GENERAL
```

| Role | Receives hauls | Ships hauls out | Who authors it |
|---|---|---|---|
| `GENERAL` | yes | yes | scene default; storerooms, the starting module |
| `INPUT` | yes | **no** | a recipe's ingredients, a mess hall's food, a reactor's fuel, a bay's sell-order staging |
| `OUTPUT` | **no** | yes | a recipe's products, mined ore, arriving purchases, deconstruction refunds |

Two flags that were always set in opposition become one word that cannot be set in contradiction. `accepts_imports = false, accepts_exports = false` — the state `ConstructionComponent` uses to freeze a bin (`modules/components/construction_component.gd:41`) — is not expressible as a role and must not be; see §6.

The important property is that **the role is per-slot**, which is the entire reason one component can now do both jobs: a merged refinery bay holds `iron_ore` at `INPUT` and `iron` at `OUTPUT` in the same `storage_data` dictionary.

**A resource is one role at a time.** A recipe naming the same resource as both an input and an output would be ambiguous, and `_sync_storages` must assert against it rather than pick a winner silently.

## 2 — OUTPUT sits at the priority floor, and is neither settable nor shown

`StoresModel.PRIORITY_MIN` is `-100`, which is already `REFUSE_AT` — the bottom of the band table. An OUTPUT slot resolves to that floor, always. It is not saved per slot, not editable, and not rendered as a stepper.

This is deliberately **not** an offset from the component's own priority. An offset would preserve today's `-1` relationship, but the floor is better on three counts:

- **It ships to more places.** An output at `-1` cannot deliver into a player's `-5` "last resort" bin, because `find_sink` demands *strictly greater*. At `-100` it can. An output bin is a temporary holding spot, not storage — "anywhere but here" is the correct routing for it.
- **It keeps one editable priority per component.** `scripts/utility/stores_model.gd:188` documents, and `test_stores_model.gd` asserts, that priority is editable on **every** bin — deliberately, because priority is the routing language. Because OUTPUT is a role on slots rather than a bin of its own, the *component* still has exactly one editable number and that rule survives the change untouched. An offset scheme would have needed the same thing; a second settable number would have broken it.
- **It deletes a constant.** `JobPriorities.DECONSTRUCTION_EXPORT` (`-99`) exists solely to say "push these refunds anywhere". `modules/components/construction_component.gd:197` sets `accepts_imports = false`, `desired = 0` and that priority together — which is role `OUTPUT` spelled out longhand. The constant is removed and `setup_storage_post_deconstruction()` sets the role instead.

**Known loss, accepted:** `mining_bay` is the one module whose slots are *all* OUTPUT, so it loses its priority stepper entirely. Today a player can raise it to hoard ore in the bay. That lever goes. It is worth naming in the Stores card rather than leaving a blank where a control used to be — see §8.

## 3 — Priority resolution moves onto the component; `StorageQuery` asks per resource

`StorageQuery` currently reads `storage.priority` and the two flags at three points (`scripts/utility/storage_query.gd:54`, `:91`, `:101`). All three become per-resource questions:

```gdscript
## The priority this bin exports `resource` at, or REFUSED when it never will.
func export_priority(resource: ResourceData) -> int

## The priority this bin accepts `resource` at, or REFUSED when it never will.
func import_priority(resource: ResourceData) -> int
```

`GENERAL` and `INPUT` return the component's `priority`; `OUTPUT` returns `StoresModel.PRIORITY_MIN` from `export_priority` and `REFUSED` from `import_priority`. A resource with no slot returns `REFUSED` unless `allow_any_resource`.

`REFUSED` is a distinct sentinel from `StorageQuery.ANY_PRIORITY` and must not be conflated with it: `ANY_PRIORITY` means *"the caller has no priority to compare against"* and **skips the filter**, which is why a pile or a carried-cargo sweep can be deposited anywhere. A bin that refuses must be rejected on **every** path including those two — so the refusal is checked before the comparison, never expressed as an extreme number.

That distinction is load-bearing today and is easy to lose: `find_sink(ANY_PRIORITY)` skips the priority test entirely, so a `-100` bin is protected by its *role*, never by its number. This is further reason not to show the number for OUTPUT — it is decoration, and the role is the mechanism.

The strict inequalities stay exactly as they are. They are what stops a haul flip-flopping between two equal bins forever, and nothing here changes that argument.

## 4 — Role decides the posting rule

`desired` gets one meaning — **the cap** — and the role supplies the target, which is what resolves the collision that would otherwise brick every processor (see §10).

| Role | Import job posts when | Export job posts when |
|---|---|---|
| `GENERAL` | `stored < desired` | `stored > desired` |
| `INPUT` | `stored < desired` | never |
| `OUTPUT` | never | `stored > 0` |

`OUTPUT`'s export-on-anything is what `desired = 0` was simulating (`modules/components/processor_component.gd:243`). Saying it as a rule rather than as a magic zero is what lets `desired` become a cap in stage 2 without the output side collapsing — with a strict cap and `desired = 0`, `_try_deposit_output`'s `can_deposit` check (`processor_component.gd:341`) would be false forever and **no processor could ever deposit its own output**.

## 5 — Capacity is per role, and it keeps the numbers the scenes already have

`max_stored` is component-wide today and `space_available()` sums across every slot (`modules/components/storage_component.gd:396`). Merging two bins into one would therefore share one pool between the input and output sides — which means **a backed-up output starves the input**, and at the docking bay means **a large staged sell order silently blocks an incoming purchase** (`scripts/managers/trader_manager.gd:234` gates buys on the arrivals bin's `space_available()` and already raises an `_import_full_alerted` warning the player would now have no way to explain).

So capacity is split by role:

- **`max_stored` keeps its name and its meaning** — the pool for `GENERAL` and `INPUT` slots. Every existing scene value is correct as authored and nothing needs re-tuning.
- **A new `output_capacity: int`** is the pool for `OUTPUT` slots.

`GENERAL` and `INPUT` never coexist on one module in practice (a module either holds stock or consumes it), so two numbers are enough; if that ever stops being true it becomes a third field, not a redesign.

The merged scenes therefore carry **the same two numbers they carry today**, moved onto one node: the forge is `max_stored = 30`, `output_capacity = 20`. This deliberately replaces the "combined total, split proportionally by recipe" approach from the design discussion — that made the output buffer a function of the recipe's *arity* (a `5 iron + 1 catalyst → 1 plate` recipe would get one seventh of the pool for its output), which nobody has tuned and which would change behaviour on every existing module. Recipe proportions still distribute `desired` **within** a role's pool, exactly as `_sync_storages` does now (`processor_component.gd:234`).

`space_available()` becomes role-qualified. Every call site must say which pool it means:

| Call site | Pool |
|---|---|
| `StorageComponent._on_slow_tick` import budget | the slot's own role |
| `StorageComponent.can_deposit` | the slot's own role |
| `ProcessorComponent._satisfies_recipe` / `_try_deposit_output` | `OUTPUT` |
| `TraderManager` purchase sizing | `OUTPUT` |
| `StoresModel.Entry.capacity` / `fill()` | see §8 — one meter per role |

**Assert** that a component with `OUTPUT` slots has non-zero `output_capacity`. A silently-zero pool is a processor that never produces, and it is exactly the kind of thing a scene edit introduces without a crash.

## 6 — Construction storage keeps its own path

`ConstructionComponent` sets **both** flags false to freeze its bin during the preview and construction phases (`construction_component.gd:41`, `:127`). That state is not a role and must not become one — adding a `FROZEN` role would put a fourth word in the vocabulary that only one component ever uses.

Instead the freeze moves to the component: `StorageComponent.hauling_enabled: bool` (default true), checked before role resolution in both `export_priority` and `import_priority`. That is one flag with one owner, and the whole of what the deleted pair was doing that a role cannot express.

The rest of the construction lifecycle maps cleanly:

| Phase | Today | After |
|---|---|---|
| Preview / pre-blueprint | both flags false | `hauling_enabled = false` |
| Building | `accepts_imports = true`, priority `+99` | slots `INPUT`, priority `CONSTRUCTION_IMPORT` |
| Deconstructing | `accepts_imports = false`, priority `-99`, `desired = 0` | slots `OUTPUT` |

The "at most one storage component" rule is therefore **"one storage, plus construction's"** — and that should be written down as the rule rather than left as an exception someone rediscovers.

## 7 — The docking bay stops being hand-configurable

`docking_bay_left_base.tscn` sets `player_configurable = true` on its sell-staging bin, so the player can edit its accepted list and desired amounts by hand — while `TradeComponent` is *also* driving both from the trade sheet and from contract demand (`modules/components/trade_component.gd:109`, `:141`, and the stranded-stock dump at `:62`). Two authorities on one bin, and the sheet wins on every recalculation, so the player's edit silently evaporates.

The flag comes off. The bay's contents are the sheet's: sell orders create `INPUT` slots sized to the order, purchases create `OUTPUT` slots as goods arrive. Its **priority stays editable** like every other component's, and its default stays `JobPriorities.TRADE_EXPORT_BIN` (+3) — that number is load-bearing (it out-pulls ordinary storerooms at +1 but loses to the kitchen and to construction) and merging must not quietly reset it to the scene default.

`StoresModel.contents_locked_reason()` needs a sentence for this case — *"Set by the trade sheet"* — because a locked control names its blocker rather than just going grey (WI-54).

Note this is mostly deletion: the sheet-driven half already exists and works. What is being removed is the second way in.

## 8 — Vocabulary and UI

**`StoresModel.priority_label(-100)` stops saying "Refuses."** Nothing the player can configure refuses imports any more — refusal is a role, and roles are not player-set — so the word would be a lie on the only control that can show it. It becomes **"Last choice"**: `<= REFUSE_AT` now means *last in line*, which is what the number actually does. `REFUSE_AT` is renamed with it (`LAST_CHOICE_AT`), and `LEGEND`'s long-form line follows. This is a `test_stores_model.gd` change, not just a string change.

The rest of the UI work:

- **One Stores card per module**, because there is one component per module. Where a module has both roles the card shows **two meters** — an IN meter against `max_stored` and an OUT meter against `output_capacity` — and one priority stepper. `StoresModel.Entry` grows a per-role breakdown; `fill()` becomes per-role.
- **The inspector's Stores tab merges by construction.** The `Stores 2` numbering in `InspectorTabPlan.module_tabs` stays (a deconstruction site still grows a second bin, and the comment at `ui/inspector/inspector_tab_plan.gd:171` stays true), but no vanilla module hits it any more.
- **Slots group by role in the tab**, IN above OUT, with the role as the section heading. A single-role bin prints no heading — same rule as `ModuleStatusTab`'s lone section (WI-64).
- **The mining bay's card has no stepper.** It needs a sentence saying why, on the control's own row: *"Output only — always pushes out."* A blocked action names its blocker on its own control (WI-54).
- **`ui/windows/ui_storage_component.gd` and `ui/windows/storage_overlays.gd`** both render per-resource `desired` steppers today; both need the role split and, in stage 2, the autodump threshold (§12).
- **The logistics overlays lose a hack.** `ui/overlay_controller.gd:421` and `ui/overlay_flow_layer.gd:103` both pick the largest-magnitude priority among a module's storages with `absi()`, which exists *only* because a module can have two. With one component they read `storage.priority` directly.

## 9 — Save migration

Storage saves per instance, keyed by node path under `"storage"` (`storage_component.gd:509`), and `ModuleBase` walks live components rather than enumerating them by hand — that changed in **WI-47 M2**, and the CLAUDE.md line claiming the chain is hand-enumerated is stale for modules (it is still true for `SaveManager._load_pawns`).

So an old save of a forge has two blocks — `"Input Storage"` and `"Output Storage"` — and the new scene has one node. `_warn_orphaned_blocks` will notice and warn, which is the detection mechanism, not the fix.

**Bump `SAVE_VERSION` to 3 and add `_migrate_2_to_3` to the `_migrations` table** (`scripts/managers/save_manager.gd:59`). It folds the pair: contents merge into the surviving node's block, `priority` is taken from the **input** block (the output block's priority is now derived and its saved value is discarded), and each restored slot is assigned its role from the live component's post-`_sync_storages` layout rather than from anything in the save. Roles are **derived, not saved** — the recipe restores before storage does (`ProcessorComponent.save_order()` runs first, deliberately), so the layout is already correct when contents land on top of it.

Name the surviving node consistently — `Storage Bay`, matching the storerooms — so the migration has one target path to write and mods have one convention to follow.

---

# Stage 2 — Strict capacity

## 10 — `desired` becomes a hard cap

Today `desired` is a *target*: it drives job posting, and the only physical bound is `max_stored`. After stage 2, a deposit that would take a slot over `desired` is refused.

Why this is safe for existing content: `_ready` sets `desired = max_stored` for every import-accepting slot (`storage_component.gd:59`) and `add_stored_resource` does the same for new ones (`:100`). So a default storeroom's cap is its capacity and nothing changes. Strictness only bites where `desired < capacity` — a processor's recipe-proportioned inputs, and a player who has deliberately lowered a number.

**Trap:** that default is what keeps `allow_any_resource` bins (the starting module, the docking bay's arrivals) working at all. If a new slot ever defaults to `desired = 0` instead, every catch-all bin bricks at once. The default deserves a comment saying so.

**Lowering `desired` below current stock does not dump.** The surplus stays and an export job posts for it, exactly as it does now. That is the no-silent-resource-loss invariant, and it is also why §12 exists.

## 11 — The deposit claim becomes a per-resource question

`StorageData.can_take_claim` returns `true` unconditionally for `STORAGE_DEPOSIT`, with a comment saying *deposit space is a component-level question, so the reservation is pure bookkeeping* (`modules/components/storage_data.gd`). **Strict `desired` makes that comment false**, and it is the one place where missing the change produces a bug rather than an error:

> Five haulers each reserve a deposit against the same five remaining units under `desired`; four arrive at a full slot.

The fix is one line and its comment:

```gdscript
if kind == ClaimSpec.Kind.STORAGE_DEPOSIT:
	return stored + reserved_deposit + amount <= desired
```

The shared import budget in `_on_slow_tick` (`storage_component.gd:135`) needs **both** bounds after this — the role's pool *and* the per-slot headroom — not just `space_available()`.

## 12 — Overflow stays on the pawn, and autodump gets its own number

**Overflow.** `find_sink` deliberately probes with one unit rather than the whole load, because *"whatever doesn't fit stays on the pawn and gets swept next tick"* (`storage_query.gd:96`). That path already exists, already works, and does not litter the floor. It stays: a partial deposit leaves the remainder in the pawn's inventory. A `ResourcePile` is created **only** when `find_sink` returns null — nowhere in the station will take the goods — which is `PawnBase.start_job()`'s existing fallthrough. One new pile path, not two.

**Autodump.** `autodump_amount()` is `stored - desired - reserved_withdraw` (`storage_data.gd:42`). Once `desired` is a hard cap, `stored` can never exceed it and **autodump can never fire**. It needs its own threshold:

```gdscript
## Destroy stock above this level. -1 disables. Must sit below `desired`:
## `desired` is where hauling stops filling, this is where the station starts
## destroying, and they are different decisions.
@export var autodump_above: int = -1
```

`autodump_amount()` becomes `maxi(stored - autodump_above - reserved_withdraw, 0)`, gated on `autodump_above >= 0`. The existing `autodump: bool` is replaced by the sentinel rather than kept beside it — two fields that can disagree about whether dumping is on is a state nobody should have to reason about. The save block writes `autodump_above` and reads a legacy `autodump: true` as `autodump_above = desired`, which is exactly what it meant.

UI: `storage_overlays.gd:259`'s *"Keep dumping the surplus automatically"* checkbox becomes a labelled stepper — **"Auto-dump above N"** — bounded `0 .. desired`. `StorageComponent.autodump_warning()` and the amber `UIPalette.Row` treatment on the Stores chip (`ui/windows/stores_module_card.gd:297`) both carry over unchanged; autodump destroys stock, and that warning is the explicit action the resource invariant demands.

---

## Files

**Stage 1**

| File | Change |
|---|---|
| `modules/components/storage_data.gd` | `Role` enum + `role` |
| `modules/components/storage_component.gd` | delete `accepts_imports`/`accepts_exports`; add `hauling_enabled`, `output_capacity`, `import_priority()`, `export_priority()`; role-qualify `space_available()` / `can_deposit()`; save block |
| `scripts/utility/storage_query.gd` | three call sites → the per-resource accessors; `REFUSED` handling on all paths incl. `ANY_PRIORITY` |
| `scripts/jobs/job_priorities.gd` | delete `DECONSTRUCTION_EXPORT` |
| `modules/components/processor_component.gd` | one storage ref; `_sync_storages` assigns roles; same-resource assert; `_satisfies_recipe` / `_try_deposit_output` role-qualified |
| `modules/components/trade_component.gd` | one storage ref; **rename `export_storage` → the sell-staging slots (role `INPUT`) and `import_storage` → the arrivals slots (role `OUTPUT`)** — the current names are the exact inverse of the roles and will read backwards forever if left |
| `modules/components/construction_component.gd` | `hauling_enabled` + roles instead of the flag pairs |
| 5 module scenes | merge two nodes into `Storage Bay`; add `output_capacity` |
| ~8 module scenes | flags → roles on their slots |
| `scripts/managers/save_manager.gd` | `SAVE_VERSION = 3`, `_migrate_2_to_3` |
| `scripts/managers/trader_manager.gd`, `contract_manager.gd` | renamed fields, role-qualified `space_available()` |
| `scripts/utility/stores_model.gd` | `REFUSE_AT` → `LAST_CHOICE_AT`, label, `LEGEND`, per-role `Entry` |
| `ui/windows/stores_module_card.gd`, `stores_panel.gd`, `ui_storage_component.gd`, `storage_overlays.gd`, `storage_resource_line.gd` | two meters, role sections, the mining-bay sentence |
| `ui/overlay_controller.gd`, `ui/overlay_flow_layer.gd` | drop the `absi()` collapse |

**Stage 2**

| File | Change |
|---|---|
| `modules/components/storage_data.gd` | `autodump_above` replaces `autodump`; `autodump_amount()`; `can_take_claim` deposit bound |
| `modules/components/storage_component.gd` | strict `can_deposit`; both bounds in the import budget; save block legacy read |
| `scripts/jobs/actions/` (deposit actions) | partial deposit leaves the remainder on the pawn |
| `ui/windows/storage_overlays.gd` | checkbox → "Auto-dump above N" stepper |

## Tests

`StorageData`, `StorageQuery` and `StoresModel` are all pure and already covered, so most of this is testable without a running game.

- **`test_storage_query.gd`** — a source/sink pair per role combination, including that an `OUTPUT` slot is never a sink **even when the query passes `ANY_PRIORITY`**. That is the one that catches conflating `REFUSED` with the sentinel.
- **`test_storage_data.gd`** — role→priority resolution; the `can_take_claim` deposit bound with reservations outstanding; `autodump_amount()` against `autodump_above` including disabled; legacy `autodump: true` reading back as `desired`.
- **`test_stores_model.gd`** — the renamed band and label; per-role `fill()`; `priority_editable` still true for every component; the OUTPUT-only card's blocked sentence is non-empty.
- **A content sweep**, in the spirit of WI-62's and WI-63's: walk every `modules/**/*.tscn` and assert **(a)** at most one non-construction `StorageComponent` per module, **(b)** every `OUTPUT`-bearing component has non-zero `output_capacity`, **(c)** no resource is both an input and an output of the same recipe. That sweep is what keeps the invariant true after the item closes, and it is the only test here that would catch a bad scene edit six months from now.

## Verification

Headless probe (the standing fallback), driven through the states rather than asserted from `_ready`:

1. A refinery imports ore into `INPUT`, produces, and exports product from `OUTPUT` — on **one** component.
2. A deconstruction site's refunds reach a storeroom, with `DECONSTRUCTION_EXPORT` gone.
3. Purchases land at the docking bay while a large sell order is staged — the case the shared pool would have broken.
4. Save mid-refine, reload, confirm contents, roles and priority all survive; and separately load a **pre-migration** save of a forge with stock in both bins and confirm the fold.
5. Stage 2 only: N haulers converge on a slot with headroom for one, and exactly one deposit succeeds.

**Screenshots are part of this**, per the standing rule — every panel item in the UI rework found defects a headless probe could not see. At minimum: a two-role Stores card (both meters, one stepper), the mining bay's stepper-less card with its sentence, a merged inspector Stores tab with IN/OUT sections, a single-role bin showing no heading, and the "Auto-dump above N" stepper.

## Open questions

- **Does the mining bay want its lever back?** If hoarding ore in the bay turns out to matter, the answer is a `GENERAL` slot at a player-set priority rather than a settable OUTPUT — do not reintroduce an editable floor.
- **`hauling_enabled` vs. a fourth role.** Shipping it as a component flag on the argument that only `ConstructionComponent` uses it. If a second caller ever appears, revisit — two users would make it a role after all.
- **Should a player-set `desired` on a `GENERAL` bin really be a hard cap?** It is the honest reading of the number, but it is also the change most likely to surprise a player mid-game, and it will put goods on pawns (and occasionally on the floor) in stations that currently never do. Worth playing before committing to stage 2.
