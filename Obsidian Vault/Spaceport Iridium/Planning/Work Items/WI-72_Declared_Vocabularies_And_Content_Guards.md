# WI-72 — Declared Vocabularies and Content Guards

> **Status: DONE (2026-09-20).** §0's three decisions were all taken as recommended: the
> listener-less signals are a declared mod API and `special_path_connection_added` is deleted
> (§0.1), `SECONDS_PER_HOUR` stays 10 with its comment corrected (§0.2), and an undeclared stat
> warns at runtime rather than failing (§0.3). Closes **F30**, **F31** and **F11**, and swept the
> balance literals. Verified by **1821 unit tests (99 suites)** and **43 integration tests (11
> suites)**, both green, with each new sweep re-run against a seeded fault to prove it fails.
>
> **What shipped that the plan did not say:**
> - **The vocabulary is twenty-one stats, not eighteen.** `WeaponComponent` routes
>   `weapon_damage`, `weapon_fire_interval` and `weapon_range` through a one-line `_stat()`
>   helper instead of naming `get_effective_stat` at each site, so §1's census — which was a grep
>   for the call — could not see them. That is the finding, not the miss: a helper can hide a
>   stat, so `test_stat_content.gd`'s "declared ⇒ read" rule looks for the **constant** appearing
>   anywhere that is not a write to the modifier layer, rather than for `get_effective_stat(`.
>   `HeatComponent`'s throttle was a twelfth write site §1's file list did not name.
> - **The mod API is eleven signals, not ten.** `module_destroyed` is emitted by
>   `ModuleBase._on_hp_zero` and listened to by nothing — WI-71's F27 deliberately moved
>   `AlertManager` off it onto `module_removed`, which is what left it listener-less. It is the
>   same shape as `ship_destroyed` and is declared with the rest.
> - **The sweep's needles had to distinguish two vocabularies.** §1 says "no `add_modifier(&"` in
>   `modules/`", but `ShopComponent` and `SleepComponent` both call `needs.add_modifier(&"...")`
>   with **mood** ids. The needle is `stat_modifiers.add_modifier(&"`, not `add_modifier(&"`.
> - **The eleven asserts became one virtual, not seven bespoke checks.** `ComponentBase` carries
>   `wiring_fault() -> String` (the rule, pure and readable on a scene that has only been
>   instantiated) and `check_wiring()` (runs it in `_ready`, sets `misconfigured`, `last_error`
>   and one `push_error`). `ModuleBase` then skips **every** lifecycle hook on a misconfigured
>   component — one place, rather than an early return in each of the seven `ready_constructed`s.
>   Two components legitimately never call `super()` in `_ready` (`AtmosphereComponent` and
>   `HeatComponent` are runtime-attached and set `owner_module` themselves); neither states a
>   rule, and a sweep now fails if a third one does, because that rule would never run.
> - **`StorageComponent`'s rule moved earlier and split.** Its assert sat in `ready_constructed`
>   and so raced the processor's `_sync_storages()`, which is what creates the derived OUTPUT
>   slots. The authored half (`has_output_slots()`, or a `default_role` of OUTPUT, with a zero
>   pool) is now checked at `_ready`; the derived half is a rule on `ProcessorComponent` — "a
>   recipe with products needs an output pool" — which is order-independent and names the
>   processor rather than the bin.
> - **`PackedScene.pack()` on an instantiated module is lossy.** §"Verification" 2 wanted a
>   misconfigured scene placed through the fixture. Building it by instantiating the ore
>   processor, clearing the recipe and repacking produced a module whose PathComponent had lost
>   its authored anchors — six `AStar2D` "point doesn't exist" errors on placement, present with
>   or without the recipe change. The fixture is therefore a real inherited `.tscn` under
>   `tests/integration/fixtures/`, which is also the shape a mod actually ships.
> - **GUT's `handled` flag is not a removal.** `get_errors()` keeps every error tracked for the
>   whole test, so a helper that counts unhandled push_errors has to skip `error.handled` or the
>   second call re-reports the first call's error. Worth knowing for any test that asserts on an
>   expected error and then asserts that nothing further happened.
> - **Godot's `RegEx` has no multiline `^` by default,** so a whole-file pattern anchored with
>   `^func ...` matches nothing and every test written on it passes vacuously. Caught by seeding
>   the fault; the sweep reads line by line instead.
> - **§4 found no sites beyond the seven listed.** The grep turned up `path_component`'s
>   `distance * 0.5` halves, `socialize_component`'s two means, `shield_component`'s draw alpha,
>   `module_base`'s pile-drop jitter and `pawn_base`'s speed/lane jitter — all averaging or
>   cosmetic, all left in code as §4 says.
>
> **On §"Verification" 3 (balance unchanged).** The soak is **not** seed-stable: crew skill rolls
> and asteroid composition happen during `boot()`, before a test can call `seed()`, and two runs
> of the unchanged tree differ on mined ore (iron_ore 3 vs 9 across runs). So the A/B was done on
> the numbers themselves rather than on the soak's totals: a throwaway integration probe drove
> market restock over eight hours from a knocked-down stock, forty seeded breakdown rolls (wear/jam
> split, HP lost, and the jammed module's effective `power_output` and `process_time`), and
> `work_speed`/`work_rate` at five happiness values and two skill levels including one where the
> floor binds. Those three signatures are **byte-identical** before and after §4 —
> `27 45 61 75 88 100 110 119`, `wear=20 jams=20 hp_lost=300.0000 jammed_output=50.0000
> jammed_time=20.0000`, and the two work-rate rows — run with the literals restored in place and
> then with the data-driven values. The probe was deleted; defaults equal the literals they
> replaced, so no authored `.tres` changed.

## Goal

"Declared or it does not exist" is one of the codebase's best rules. It already covers `Groups`, `UIType`, `StoryFlags`, `TutorialTriggers`, mood ids and, since WI-68, ledger categories. Each time, the rule arrived *after* a typo had silently turned a feature off. Three vocabularies are still undeclared, and one class of content check still lives in `assert()`, which a release export strips:
- **Stat names (F30).** Eighteen free-form StringNames tie authored upgrades to the components that read them. A typo in an upgrade `.tres` is an upgrade that costs credits and does nothing.
- **Scene wiring (F31).** Eleven `assert`s guard content or setup: a processor with no recipe, a bin with OUTPUT slots and no output pool, a mining bay with no storage. In a release build a bad scene (a mod's, or a hand edit) ships silently and fails later, far from its cause.
- **The mod-facing signals (F11).** Ten `SignalBus` signals are emitted and never listened to, and one is never emitted at all. Nothing says whether they are a mod API or dead.
- **Balance literals.** The invariant says balance numbers live in `.tres` or exported vars. A handful never moved, and one of them is the length of an hour.

## 0 — Decisions for the author (not yet settled)

1. **The ten listener-less signals are a declared mod API, and `special_path_connection_added` is deleted.** *Recommended.* Each one announces something real that a mod would plausibly want: a ship destroyed, a contract offered, a visitor arrived. Keeping them costs nothing. `special_path_connection_added` has no emitter at all. *Alternative:* delete all eleven, and let a mod that needs one add it.
2. **`SECONDS_PER_HOUR` stays 10 and its comment is corrected.** *Recommended.* The constant says "(temp for testing, was 30 sec per hour/12 real min)", but every balance measurement since WI-60 (heat rates, suit holds, soak timings) was taken at 10. Reverting it silently retunes all of them by 3×. *Alternative:* restore 30 and re-measure; that is its own balance item, not a line in this one.
3. **Undeclared stats warn at runtime rather than fail.** *Recommended.* The vanilla content sweep fails a test on any undeclared stat. At runtime, `UnlockManager` and `LocalUpgradeData` `push_warning` once per undeclared stat when they load, so a mod's own stat still works and is still visible in the log. *Alternative:* a `Stats.register()` a mod calls; heavier, and nothing needs it yet.

## Scope

**In:** `Stats` and its sweep (§1), F31's asserts (§2), the signal API block and its test (§3), and the balance literals (§4).

**Out:**
- mood ids (already declared by `MoodCatalog` and `EventData.mood_ids`);
- the UI tokens (WI-58 and WI-68 F6).

## Design

### 1 — `Stats` (F30)

`scripts/utility/stats.gd`, `class_name Stats`, in `Groups`' style: one `const NAME: StringName = &"name"` per stat, grouped by the component that reads it, plus `const DECLARED: Array[StringName]`. The eighteen, from the 2026-09-19 census:

| Read by | Stats |
|---|---|
| processors, mining, power, pathing and breakdowns; also written by `ModuleBase`'s damage, breakdown and adjacency layers | `process_time`, `mining_rate`, `power_output`, `traversal_speed_mult`, `breakdown_chance` |
| heat emitters | `heat_output` |
| life support | `scrub_rate`, `o2_release_rate` |
| shields | `shield_radius`, `shield_charge_rate`, `shield_capacity` |
| crew and commerce | `sleep_quality`, `hotel_rate`, `hotel_mood` |
| logistics | `robot_speed`, `robot_capacity`, `logistics_max_robots`, `conveyor_lanes` |

Code moves to the constants: `ModuleBase`'s damage, breakdown and adjacency writes (`module_base.gd:331–334`, `:364–366`, `:387`), every `get_effective_stat(&"…")`, and the per-component `STAT_*` consts, which become `Stats.X`. The authored `.tres` keep StringNames, so the file format doesn't change.

`tests/unit/test_stat_content.gd` asserts three things:
- **authored ⇒ declared:** every `StatModifierSpec` under `data/local_upgrades/` and every `StatModifierEffect` under `data/unlocks/` names a declared stat. Walk them through `ContentPaths`, as `test_event_content` does;
- **declared ⇒ read:** every declared stat appears in a `get_effective_stat(Stats.X` somewhere in the code. A declared stat nobody reads is an upgrade that does nothing, which is the failure F30 is about;
- **no bare stat literal:** no `get_effective_stat(&"`, `set_single_modifier(&"` or `add_modifier(&"` in `modules/`. Pawn needs' `add_modifier` takes mood ids, a different vocabulary, so exclude `pawns/`.

### 2 — Content checks out of `assert` (F31)

Eleven asserts guard content or setup, across seven files; three more guard genuine internal can't-happens and stay:

| Site | Guards | Becomes |
|---|---|---|
| `processor_component.gd:116–119` | recipe, storage, power set; `time_to_process > 0` | content sweep + runtime check |
| `processor_component.gd:264` | a recipe names a resource as both input and output | recipe sweep (extend `test_recipe_index.gd`) + runtime check |
| `storage_component.gd:110` | OUTPUT slots with `output_capacity` 0 (the real WI-65 defect it was written after) | content sweep + runtime check |
| `mining_component.gd:40–41` | output storage and power set | content sweep + runtime check |
| `logistics_bay_component.gd:39` | power set | content sweep + runtime check |
| `power_generation_component.gd:20` | a fuel-burning generator has an input bin and a fuel | content sweep + runtime check |
| `trade_component.gd:51` | both of the bay's pools are non-zero | content sweep + runtime check |
| `processor_component.gd:386`, `:452`; `storage_data.gd:174` | withdraw/deposit arithmetic that can't fail if the code is right | **stay `assert`** |

- **Content sweep:** `tests/unit/test_module_content.gd` instantiates every module scene that `data/modules/**` points at, *without* adding it to the tree. Only `_init` runs, so nothing reaches `Global`, and WI-68 F12 already made the one exception, `TurboliftCab`, safe. It then checks each component's authored wiring. The first audit's R3 probe instantiated all 142 scenes this way inside a running game; this is the same walk as a permanent test.
- **Runtime check:** each `assert` becomes `push_error` naming the module and the fault, then disables the component (`set_process(false)`, `last_error = "Misconfigured: …"`), so the inspector shows it rather than the game crashing or silently doing nothing. GUT fails any test that triggers a `push_error`, so the unit and integration suites still catch it.

### 3 — `SignalBus`'s mod API (F11)

Per §0.1, delete `special_path_connection_added`. Put the ten under a `## MOD API` heading in `signal_bus.gd`, with a sentence on what each promises:
- `ship_destroyed`;
- `pawn_skill_leveled`;
- `station_alert_raised`;
- `event_triggered`;
- `contract_offered`, `contract_accepted`, `contract_completed`, `contract_failed`;
- `visitor_arrived`, `visitor_departed`.

`tests/unit/test_signal_bus.gd`, a text sweep, asserts two things. Every declared signal is emitted somewhere. Every declared signal is connected somewhere in the tree or appears in the test's `MOD_API` list. A new signal with no emitter, or a mod-API signal nobody documented, then fails.

### 4 — Balance literals

A one-time pass, not a sweep: the pattern is too fuzzy to test mechanically. Known sites:

| Site | Literal | Moves to |
|---|---|---|
| `module_base.gd:355` | `randf() < 0.5`: a breakdown's wear-vs-jam split | `ModuleData.breakdown_wear_chance` |
| `module_base.gd:356` | `max_hp() * 0.15`: a wear breakdown's damage | `ModuleData.breakdown_wear_damage_fraction` |
| `module_base.gd:114` | `BREAKDOWN_EFFICIENCY := 0.5` | `ModuleData.breakdown_efficiency` |
| `pawn_base.gd:337` | `lerpf(0.5, 1.1, happiness)`: work speed from mood | exported on `PawnBase`, or a `PawnData` field |
| `pawn_base.gd:373` | `maxf(0.3, …)`: the work-rate floor | the same place |
| `market_manager.gd:41` | `diff * 0.1`: market restock drift | an export on `MarketManager` |
| `time_manager.gd:16–17` | `SECONDS_PER_HOUR = 10.0` and its "temp for testing" comment | §0.2: the value stays, the comment is corrected |

Defaults equal the current literals, so behaviour is byte-identical. Run a grep for further `randf() <`, `* 0.<digits>` and `lerpf(0.<digits>` in `modules/`, `pawns/` and `scripts/managers/`, and record each extra site found and what was done with it. Cosmetic numbers (sprite jitter, lane offsets, averaging) stay in code.

## Files to touch

| | Files |
|---|---|
| New | `scripts/utility/stats.gd`, `tests/unit/test_stat_content.gd`, `test_module_content.gd`, `test_signal_bus.gd` |
| §1 | `modules/templates/module_base.gd`, every component with a `STAT_*` const or a `get_effective_stat` call, `scripts/managers/unlock_manager.gd` and `data/local_upgrades/local_upgrade_data.gd` (the runtime warning) |
| §2 | the seven component files in §2's table, `tests/unit/test_recipe_index.gd` |
| §3 | `scripts/managers/signal_bus.gd` |
| §4 | `module_base.gd`, `data/modules/module_data.gd`, `pawn_base.gd`, `market_manager.gd`, `time_manager.gd` |
| Docs | `CLAUDE.md` (the declared-vocabulary list gains stats and the mod API; F31's rule "content checks are tests plus `push_error`, never `assert`"), [[01_Technical_Specification]] |

## Implementation order

1. §3: the smallest, and it settles §0.1.
2. §1, with its sweep written first and failing on the current tree's bare literals.
3. §2: the content sweep first, which must pass on today's scenes, then each assert converted.
4. §4, with the full unit and integration suites run after each move to confirm nothing shifted.

## Edge cases

- **A mod's module scene** is not in `data/modules/` and so is not in the content sweep. It hits the runtime check instead, which is the point of converting the asserts.
- **A stat read only by a mod** is undeclared in vanilla, so the runtime warns once (§0.3) and it still works.
- **`heat_output`** is written by `HeatEmitterComponent`'s own const and read through `get_effective_stat`. It is declared like the rest even though no shipped upgrade targets it yet; "declared ⇒ read" holds.
- **Instantiating scenes without a tree** leaves `@onready` vars null and `_ready` unrun. The sweep reads exports only.

## Verification

1. **GUT unit:** the three new suites green. Each fails on a seeded fault: a typo'd stat in a scratch `.tres`, a processor scene with its recipe cleared, and a signal with no emitter.
2. **GUT integration (WI-69):** a misconfigured scene placed through the fixture pushes exactly one error and leaves the station running.
3. **Balance unchanged:** WI-69's 24-hour soak gives the same resource totals (to the unit) before and after §4 with a fixed random seed. Where randomness makes that impossible, compare the soak's invariants and the ledger's per-cycle net within noise, and say which was done.

## Related

- [[WI-41_Group_Constants]]: the shape `Stats` copies.
- [[WI-47_Modding_Support]]: why the signal list is a mod API and why a mod's stat must not fail.
- [[WI-68_Audit_Fix_Pass]] F4: the ledger-category version of this rule.
