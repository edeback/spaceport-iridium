# WI-47 — Modding Support

> **Status: SPIKE + STAGE 1 DONE (2026-08-02). Stages 2–5 not started.** Sized as a multi-stage item in the WI-44 mould — stages 1–3 are pure refactors of existing behaviour and are the whole load-bearing part; stages 4–5 are additive and can be dropped or deferred without stranding anything.
>
> **The M9 spike passed: 29 checks green in all four of {editor, exported build} × {text-script pack, binary-token pack}.** Mod scripts load, extend vanilla classes and dispatch through them; mod `.tres` resolve vanilla scripts by uid and by path; a vanilla `JobData` inside a mod pack resolves a mod `JobDriver`. Nothing in stages 1–5 needs redesigning. Two things the spike changed: M9's constraint is **sharper** than written (a mod script cannot name its own `class_name` either) and **less serious** than feared (`preload()`/`load()` by path substitutes completely), and M1 gains a hard requirement to mount with `replace_files = false`. Full results in M9 below.
>
> **Stage 4 COMPLETE 2026-08-03** — all five items (M5, M6, M8-recipes, M7-ships, M10), the sample mod exercising every extension point, and the "not yet audited" sweep. 616 GUT green plus six in-game runs. The WI's own acceptance test passed with **zero core edits** (verification 6).
>
> **Everything in this WI is now done except stage 5 (M8 patch ops), which was deferred by design** until a real mod asks for it. The one other open thread is `NameGenerator`'s word lists — a real but cosmetic gap the sweep chose not to invent an extension point for.
>
> **Stage 3 (M3, M4, M11) shipped**: save sections are a registry, instance data resolves per-resource, and `meta.mods` records what wrote a save. 574 GUT green, plus a 9-check in-game round trip. **Next: stage 4 (M5, M6, M8-recipes, M7-ships, M10) — additive and independent, each can ship or slip alone.**
>
> **Stage 2 (M2) shipped**: `get_save_data()`/`load_save_data()`/`save_key()`/`save_order()` on both component bases; `ModuleBase`'s fifteen-lookup chain and `SaveManager`'s eight-lookup pawn chain are now walks. 562 GUT green. Acceptance test passed: a save written by the **pre-refactor** code (21 modules, 3 pawns, 11 distinct component blocks) loads under the new walk and re-saves value-for-value identical apart from the one documented shape change. **Next: stage 3 (M3, M4, M11).**
>
> **Stage 1 (M1) shipped**: `ModManager` autoload + `ContentPaths` + id namespacing, all 13 scan sites converted. 549 GUT green (505 baseline + 44 new in `test_content_paths.gd` / `test_mod_registry.gd`), plus a 15-check headless probe that mounts the real sample mod and finds its job type and its resource in the real registries, and a fail-soft pass over five broken mods. Save-neutral. **Next: stage 2 (M2), component save hooks.**

## Goal

Let a player drop a folder into `user://mods/` and add content — modules (with new components and research values), module upgrades, jobs, resources, threats, pawn variations — without touching the game's source.

The architecture is already most of the way there and nobody planned it that way. Composition-over-inheritance, `.tres`-as-identity, stable `StringName` ids, `ResourceScanner` directory discovery, and WI-44's `JobData` + `driver: Script` split are exactly the bones a mod system needs. What's missing is (a) any loader at all, and (b) three hand-maintained dispatch tables that silently exclude anything a mod adds.

So this is not "build a modding system". It's "finish the one that accidentally exists, and delete the three places that block it."

## Scope decisions

1. **Additive mods are the target; patching vanilla content is stage 5 and may not happen.** A mod that *adds* an ore, a refinery and a tech node is the use case. A mod that *changes iron's price* is a different and much nastier problem (see M8) and is deliberately parked behind the additive path working.
2. **`.pck` mods, not loose files.** `ProjectSettings.load_resource_pack()` is the only mechanism that works identically in editor and export. Loose-folder mods are a dev-loop convenience that can come later behind the same registry.
3. **GDScript in mods is allowed and expected.** Half the extension points (`UnlockEffect`, `EventEffect`, `JobDriver`, `TargetFinder`, `PathBehavior`) are "subclass a script". Refusing script mods would gut the system. This carries a real constraint — see M9.
4. **Fail soft, always.** A broken mod degrades to missing content plus a log line; it never takes the game down. [`world_manager.gd:203`](../../../../scripts/managers/world_manager.gd) already does exactly this for unknown module ids and is the model.
5. **No `SAVE_VERSION` bump if it can be helped.** Stages 2 and 3 move where save data is *produced from*, not what it looks like. The keys stay byte-identical; see M2.
6. **Not in scope:** Steam Workshop or any distribution channel, a mod browser UI, sandboxing/untrusted-code mitigation, localisation of mod strings, mod-vs-mod dependency resolution beyond a declared load order.
7. **The save records the mods that wrote it, and loading without them warns.** Decided rather than left open — it freezes part of the `meta` shape, so stage 3 can't start without it. See M11.

## What already works

Recorded up front so nobody rebuilds it.

- **Content is discovered, not enumerated.** 13 `ResourceScanner.scan_paths` call sites across 12 distinct roots (modules, resources, difficulty, diseases, shops, skills, traits, jobs, events, unlocks, local_upgrades, tiers). Drop a `.tres` in the right folder and it exists.
- **Polymorphism-by-Resource-subclass** is used consistently: `UnlockEffect`, `EventCondition`, `EventEffect`, `PathBehavior`, `AdjacencyEffectSpec`, `StatModifierSpec`. New script subclass = new behaviour, zero core edits.
- **WI-44's job system is the template.** [`JobData`](../../../../scripts/jobs/job_data.gd) + `driver: Script` + a composable action/finder library + [`JobDataRegistry`](../../../../scripts/jobs/job_data_registry.gd). A modded job type needs no core edit *including in the save system* — the registry was built specifically to kill the hand-maintained `JobSerializer` table, and it did. Every other extension point in this WI should end up shaped like this one.
- **`ComponentBase._ready()` self-registers** into `owner_module.components`; `PawnComponentBase._ready()` does the same into `owner_pawn.components`. A mod component inside a mod module scene is live with no wiring.
- **Saves key on string ids**, and pawns already restore via `entry["scene"]` → `load(scene_path)` ([`save_manager.gd:744`](../../../../scripts/managers/save_manager.gd)), so a modded pawn scene round-trips today.
- **Unknown ids already fail soft.** A modded save opened in vanilla loses the modded modules and keeps the rest. That is the correct behaviour and it's free.

## Findings and design

### M1 — There is no loader

> **DONE 2026-08-02 (stage 1).** What shipped, and where it differs from the design below:
>
> - **`scripts/managers/mod_manager.gd`** — autoload, first in `project.godot`, ahead of `Global`. No `class_name` (an autoload and a global class can't share a name; `global.gd` and `signal_bus.gd` set the precedent), and it deliberately touches neither `Global` nor `SignalBus`, because neither exists yet when it runs.
> - **The manifest lives OUTSIDE the `.pck`**, at `user://mods/<folder>/mod.json` next to it. Not a style choice: `load_resource_pack()` has no counterpart, so a mounted pack can never be unmounted, so every decision about whether to load a mod at all has to be made from something readable *before* mounting. This is the one real departure from the design as written.
> - **`scripts/mods/mod_manifest.gd` + `mod_registry.gd`** — the manifest shape and all the ordering/validation rules, pure and unit-tested. `ModManager` is only filesystem and mounting.
> - **`scripts/utility/content_paths.gd`** — `roots_for(kind)` as designed, plus `scan(kind)` (what the 13 sites actually call, one line each) and `accept_id()`, the namespacing gate.
> - **Ordering is alphabetical among equals**, via `String` comparison. `Array[StringName].sort()` compares the names' interned *pointers*, so it yields an order that is stable within a run and meaningless between runs — a live bug the tests caught.
> - **Two mods claiming one id drops both**, as decided. **A missing dependency drops transitively.** **A `game_version` mismatch warns and loads anyway**, matching M11's decided posture.
> - **Known gap, not closed:** mods can't *shadow* vanilla files (that's what `replace_files = false` buys), but a pack *can* add files at `res://data/...` paths vanilla doesn't use, and those scan as base-game content and bypass namespacing. Closing it would need a "which pack did this file come from" API that doesn't exist. It also isn't a security boundary — mods run arbitrary GDScript by design (decision 6) — so it stays a documented mod-author rule.

Every scan root is a `const String` baked to `res://`: 11 named constants (`MODULE_PATH`, `UNLOCK_PATH`, `TIER_PATH`, `LOCAL_UPGRADE_PATH`, `JOB_PATH`, `EVENT_PATH`, `DISEASES_PATH`, `SKILLS_PATH`, `TRAITS_PATH`, `SHOPS_PATH`, `DIFFICULTY_PATH`) plus two inline strings in [`save_manager.gd:101,105`](../../../../scripts/managers/save_manager.gd). Nothing calls `load_resource_pack`.

**Fix.** Two new pieces:

- **`ModManager`** — autoload, ordered *before* `Global`. Scans `user://mods/*/mod.json`, validates the manifest (`id`, `name`, `version`, `game_version`, optional `deps` and `load_after`), topo-sorts, `ProjectSettings.load_resource_pack(path, false)`s each `.pck` in order, and records what loaded plus what failed and why.
- **`ContentPaths`** — the roots registry. `ContentPaths.roots_for(&"modules")` returns `["res://data/modules/", "res://mods/coolmod/data/modules/", …]`; the 13 call sites loop it instead of taking a const. Base game roots register themselves so vanilla is just "mod zero" and the code path is never untested.

Mod `.pck`s mount into `res://mods/<id>/` by convention rather than overwriting `res://data/`, so a mod can never shadow a vanilla file by accident — shadowing becomes an explicit stage-5 operation.

**`replace_files = false` is mandatory, not stylistic** (M9 spike finding 2). An exported pack ships `res://.godot/global_script_class_cache.cfg`, `res://.godot/uid_cache.bin` and `res://project.binary` whether the author wants it to or not; the default `true` hands a mod the power to shadow those and every vanilla resource. The manifest is also the *only* thing `ModManager` may read with `FileAccess`: a pack exported with binary-token scripts stores `res://….gdc` + `res://….gd.remap`, so `FileAccess` on a mod script's `.gd` path returns `ERR_FILE_NOT_FOUND` while `ResourceLoader` resolves it fine (finding 4).

**Id namespacing.** Mod content ids must be `modid.thing`. [`SaveManager._register_id`](../../../../scripts/managers/save_manager.gd) currently warns and *keeps the first* on a duplicate, which is load-order-dependent and easy to miss. Make a collision between two *different* mods a hard, surfaced error (mod list screen, not just `push_warning`), and validate the prefix at load. Vanilla ids stay unprefixed — they're the reserved namespace.

### M2 — Components cannot save state

> **DONE 2026-08-02 (stage 2).** Four hooks on `ComponentBase` and `PawnComponentBase` — `get_save_data()`, `load_save_data()`, `save_key()`, `save_order()` — plus `saves_per_instance()` on the module side. `ModuleBase` lost 155 lines; `SaveManager._load_pawns` and `_get_pawns_save` lost their eight-lookup chains. Deviations from the design below, all deliberate:
>
> - **Methods, not exported vars.** `save_order`/`save_key` are virtual methods, not `@export`s. An exported int shows up in the inspector on every component in every module scene, so a scene-level override could silently reorder loading for one module — and ordering is exactly the thing whose failure only shows up in modded saves. A method is a property of the component *type*, which is what it actually is.
> - **One order, not two.** Save order and load order genuinely differed (save wrote storage third, load restored it fourth; shield was written mid-file but restored after upgrades). One number now serves both, taking the *load* order as the real one, so the file's keys come out in restore order. That changes key ORDER in newly written saves, which is not semantic — the acceptance test compares parsed structures, not bytes.
> - **`save_order` defaults to 1000, not 0.** The WI's own edge case asked for this to be checked: at 0 a mod component would restore *before* construction and storage, the one place it could break vanilla's constraints from outside. At 1000 it restores last, seeing a module that is already whole. A unit test asserts every vanilla component sorts below it.
> - **One shape change: `traits`.** Its block was a bare `Array` of ids and is now `{"ids": [...]}`. Forced, not chosen: GDScript **rejects narrowing an overridden parameter** (base `load_save_data(Variant)` + child `(Dictionary)` is a parse error; return-type covariance *is* allowed, which is why `get_save_data()` needed no changes). So one shared parameter type has to serve every component, and a bare Array can't. `SaveManager._migrate_pawn_block` wraps the legacy form on the way in — verified against a genuine pre-refactor save.
> - **Pawns with no needs/health/skills/traits component** (robots, visitors) no longer get empty `"needs": {}` blocks written for them. A component that isn't there can't write a block; the load side has always tolerated the key being absent.
> - The `UPGRADE_SAVE_ORDER` constant splits the module walk, because local upgrades are module-level data that has to restore *between* two groups of components — the shield clamps its charge against the upgrade-modified capacity.
>
> **Acceptance test** (the WI's own, run for real): `git stash` the stage-2 diff → build a 21-module station with 11 distinct component block types and 3 pawns → save → restore the diff → load that save under the new walk → re-save → structural diff. Result: **every key value-for-value identical**, the only differences being the three expected `traits` ones. The legacy `["optimist"]` Array loaded and re-saved as `{"ids": ["optimist"]}` with the trait intact.
>
> `tests/unit/test_component_save_contract.gd` (13 tests) pins the ordering constraints that used to be comments: construction and processor before storage, shield after the upgrades block, disease after skills and traits, storage the only per-instance component, and every vanilla key equal to its legacy string.

**This is the single biggest blocker and the reason stage 2 exists.**

[`ComponentBase`](../../../../modules/components/component_base.gd) has no save hooks at all. Instead, [`module_base.gd:426–600`](../../../../modules/templates/module_base.gd) is a hand-written chain — `get_component_by_type(ProcessorComponent)` → `data["processor"] = …` — roughly twenty times, mirrored in `load_save_data` at `:529`. `PawnComponentBase` has the same hole, filled the same way by `SaveManager._load_pawns` (needs / health / skills / traits / disease / breathing / robot_power / robot_integrity / visitor).

A modded component is therefore *structurally incapable* of persisting. Not "awkward to persist" — there is no seam.

**Fix.** Virtual `get_save_data() -> Dictionary` / `load_save_data(data: Dictionary)` on both `ComponentBase` and `PawnComponentBase`, defaulting to `{}` / no-op. `ModuleBase` walks `components` and keys each block the way storage already keys its own — by `get_path_to(component)`, which is stable across a save/load because it's the scene path.

Two things this must not break:

- **Order is load-bearing and currently encoded in comments.** "Construction before storage: the deconstructed path reconfigures the material storage." "Processor before storage: restoring the recipe reconfigures the input/output slots." WI-45 added more of these (residue before recipe; A3's `powered` alongside `force_off`). A naïve `for component in components` loop silently reorders all of it. Add an exported `save_order: int = 0` on the component bases, sort by it, and port each existing ordering constraint to an explicit number with the comment moved onto the field. **Getting this wrong produces a bug class that only appears in modded saves**, which is the worst possible place for it.
- **The on-disk shape must not change.** Keep the existing key names (`"construction"`, `"processor"`, `"storage"`, …) by giving each vanilla component a `save_key` that defaults to its node path but is overridden to the legacy string. Pre-WI-47 saves then load untouched, and no `SAVE_VERSION` bump is needed. Modded components get path keys, which is fine because no old save contains them.

This stage is a pure refactor with a large blast radius and total test coverage available (`tests/unit/test_component_persistence.gd` from WI-45 exists precisely for this). Do it before anything additive.

### M3 — Save sections are a literal

> **DONE 2026-08-02 (stage 3).** `SaveSection` (`scripts/managers/save_section.gd`) + a registry on `SaveManager`; the 17-entry dictionary literal and the 17-call load sequence are both walks now. Each of the 16 participants registers one line in its own `_ready()`, next to its `Global` registration, carrying its order number and the reason for it. `difficulty` stays written directly — it's an id chosen before the run starts, so there is no system holding state to ask.
>
> - **The registry is static.** `SaveManager` is deliberately last under `Managers/`, so it doesn't exist yet when the systems that feed it are readying — there is no instance to register into. Registration replaces by id, so the scene reload a load performs refreshes every vanilla entry, and `SaveSection.is_live()` prunes anything left pointing at a freed node.
> - **`empty` per section**, because the two list-shaped sections (`piles`, `pawns`) can't be handed `{}` when absent — the receiving methods are typed.
> - **Unclaimed passthrough** works and is verified across a full save → load → save. One caveat now documented in the code: "untouched" means *semantically*, not byte-for-byte. The block goes through `JSON.parse_string`, and JSON has a single number type, so an int returns as a float. Every vanilla loader already coerces with `int()`/`float()` for exactly that reason; a mod reading its own section is under the same obligation whether or not it sat out a session.

### M3 — original finding

[`save_manager.gd:283–305`](../../../../scripts/managers/save_manager.gd) hardcodes 17 sections; `_apply_pending_load` hardcodes their load order at `:661–695`, with ordering comments as load-bearing as M2's ("phantom settlement fires" — economy after time; pawns before crew; contracts after traders).

A mod that adds a manager — a new threat system, a faction, a research track — has nowhere to put state.

**Fix.** A `SaveParticipant` interface (`section_id() -> StringName`, `save_order() -> int`, `get_save_data()`, `load_save_data()`), registered on `SaveManager` the way managers already register into `Global` in `_ready()`. Vanilla managers register with their current section ids and explicit order numbers derived from today's sequence. Unknown sections in a save (mod present when saved, absent when loaded) are **preserved and written back out untouched** rather than dropped — so disabling a mod for one session doesn't destroy its state.

### M4 — `ItemInstanceData` subtypes are a hardcoded match

> **DONE 2026-08-02 (stage 3), by a different route than either option below.** `ResourceData` gained `@export var instance_data_script: Script`, and `instance_from_dict(resource, data)` resolves the class from the resource that owns the stack instead of from any table. `ItemInstanceData` gained `type_id()` and `from_dict()`, so reading a block is the subclass's own job — the `match` in `SaveManager` naming `OreInstanceData` and `FoodInstanceData` is gone.
>
> Chosen over the `type_id` + global registry the finding recommends because a global registry needs a *registration step*, and a mod has no code entry point to run one from (there is no mod-init hook, and M9 means a mod class can't even be named). A `Script` on the resource is pure data, is the shape M9 proved works from inside a `.pck`, and has no shared namespace — two mods can both call their variance "purity" without colliding. The `"type"` tag stays in the save for readability and is checked on the way back, warning when a resource's script has been swapped under an existing save.
>
> Wired into the six vanilla variance resources (five ores → `OreInstanceData`, biomass → `FoodInstanceData`). A resource that declares no script drops the variance and keeps the stack — losing a richness value is survivable, losing the ore would not be.

### M4 — original finding

[`save_manager.gd:153`](../../../../scripts/managers/save_manager.gd):

```gdscript
match String(data.get("type", "")):
    "ore": …OreInstanceData…
    "food": …FoodInstanceData…
```

Any modded resource with `has_variance = true` silently loses its instance data on save — which is the *entire point* of variance. Given WI-09 built ore richness and WI-29 built food quality on this, a mod adding e.g. component purity or fuel grade is a natural thing to want.

**Fix.** Make the subclass self-describing: an exported `type_id: StringName` on `ItemInstanceData` plus a registry that maps it back to a script, or simply store the script's `uid://` in the dict and instantiate from that. The `uid` route is less code but pins M9's "never re-uid a script" rule harder. Prefer the explicit `type_id` + registry; it keeps saves human-readable, which has been worth a lot during every previous audit.

### M5 — `ModuleData.UICategory` is an enum

> **DONE 2026-08-03 (stage 4).** New `BuildCategoryData` (`data/build_categories/`), scanned as a `ContentPaths` kind, with twelve vanilla `.tres` at sort_order 0/10/…/100 and `other` at 1000. `ModuleData.ui_category` became `category_id: StringName`; all 39 module `.tres` that declared one were rewritten; `BuildMenuModel` groups and orders on it.
>
> - **`cat_icon` moved out of the scene.** It was an inspector dict on the BuildMenu node keyed by the enum — unreachable to a mod, and display data for scanned content living in a scene. It's now a field on each category resource; the two authored icons (Core's truss glyph, Power's solar atlas region) moved into `core.tres` and `power.tres`, and `build_menu.tscn` is down to a script reference.
> - **An undeclared category still renders**, under its own id, sorted at `UNKNOWN_SORT_ORDER` (past even `other`) so a module from an uninstalled mod can never displace vanilla rail order. Tested.
> - Verified in-game: 45 modules, every one in a declared category, rail order identical to the old enum sequence — Core, Power, Life Support, Industry, Food, Mining, Storage, Crew, Commerce, Defense, Logistics. `Other` correctly doesn't appear: everything that would fall in it is `hidden`.

### M5 — original finding

[`module_data.gd`](../../../../data/modules/module_data.gd) declares a fixed 12-value enum, and [`build_menu_model.gd:17–30`](../../../../ui/buttons/build_menu_model.gd) maps each to a label. Enums cannot be extended from data, so a mod cannot add a build-menu rail category — its modules all land in `OTHER`.

**Fix.** `StringName category_id` plus a scanned `BuildCategoryData.tres` carrying `id`, `display_name`, `sort_order`, `cat_icon`. `BuildMenuModel.group_modules` / `category_order` / `category_name` all key on the resource instead of the enum.

Cheap **now** — WI-43 shipped days ago and the call sites are small and fresh — and it gets steadily more expensive. Worth doing even if the rest of this WI slips.

### M6 — Content-ish scene preloads

> **DONE 2026-08-03 (stage 4)**, but **the finding below is wrong about the truss fix** and the correction matters.
>
> **`ModuleBase.replacement_on_delete` is dead code.** It is declared, set by no scene, and read by nothing. The four truss preloads are also not about replacement-on-delete at all: they auto-place truss *underneath* a corridor/stairs/turbolift/airlock when it lands on an empty MODULE cell. The actual replace-on-delete path is `WorldManager.replacement_module`, which has always been a proper `@export`.
>
> So the four sites now resolve through `ModuleBase.structural_backfill()` → `WorldManager.replacement_module` — the same authored resource `remove_module` backfills with, giving one answer to "what is the structural placeholder" instead of five. `replacement_on_delete` was left in place rather than deleted (removing an export is beyond "make preloads reachable"), but it should go.
>
> The rest: `MiningComponent.mining_drone_scene` and `LogisticsBayComponent.hauler_robot_scene` became `@export`s **keeping their current scene as the default**, so no module scene needed editing and a mod's own module can point elsewhere. `InspectionRunner`'s two preloads became plain fields injected by `UnlockManager` from new exports — the runner is created in code and has no scene, so the manager is the only authored surface, matching `RaidManager.pirate_ship_scene` / `CrewManager.crew_pawn_scene`.
>
> Verified in-game, including the one change with live consequences: placing a corridor on an empty MODULE cell still auto-places truss beneath it.

### M6 — original finding

Not many, but each one is a thing a mod can't reach:

- `truss` — preloaded at four sites: [`hallway.gd:5`](../../../../modules/core/hallway.gd), [`stairs.gd:5`](../../../../modules/core/stairs.gd), [`module_airlock.gd:5`](../../../../modules/transport/module_airlock.gd), [`module_turbolift.gd:5`](../../../../modules/transport/module_turbolift.gd). (`ModuleBase.replacement_on_delete` is already an `@export` — these four bypass it.)
- [`mining_component.gd:6`](../../../../modules/components/mining_component.gd) mining drone, [`logistics_bay_component.gd:17`](../../../../modules/components/logistics_bay_component.gd) hauler robot (a path string, not even a preload), [`inspection_runner.gd:18–19`](../../../../scripts/managers/inspection_runner.gd) arrival shuttle + inspector pawn.

**Fix.** `@export` where the owner is a scene (the four truss sites should just use `replacement_on_delete`), or a `GameContentData` settings resource for the manager-level ones. `RaidManager.pirate_ship_scene`, `CrewManager.crew_pawn_scene` and `VisitorManager.visitor_pawn_scene` are already exports — that's the pattern to match.

### M7 — New dangers means one new manager per danger

> **SHIP VARIANTS DONE 2026-08-03 (stage 4). The deferred `ThreatData`/`ThreatDriver` half is untouched, as intended.**
>
> `ShipData` (`data/ships/`), scanned as a `ContentPaths` kind, with one vanilla `pirate_raider.tres`. `RaidManager` rolls each ship in a wave from `ShipData.eligible(strength)` via a weighted `pick()`, so one wave can mix variants.
>
> - **Per-ship stats deliberately stayed on the scene.** The finding lists "scene, HP, weapon loadout, speed, orbit behaviour script, salvage table" as ShipData's contents, but hull/speed/damage/interval/range/tint are *already* exports on the PirateShip scene. Mirroring them onto the resource would only create two places to disagree. `ShipData` carries scene + selection (`min_strength`, `weight`) + salvage; a modder making a heavier raider inherits the scene, retunes its exports, and points a `ShipData` at it — exactly how `ModuleData` relates to its module scene.
> - **Salvage overrides per half.** `salvage_resource` null and `salvage_amount.x < 0` fall back to RaidManager's, so a variant only declares what differs.
> - **`min_strength`** gates heavier raiders behind station value, so they appear as the station grows rather than ambushing a starting base. The pool is fixed at spawn: a wave shouldn't gain heavier ships because the player's credits moved mid-fight.
> - **The wave is reproducible.** `eligible()` sorts by id at the point the pool is built rather than at scan time — it is the list that feeds the roll, and sorting there holds however entries reached the registry. A unit test caught this: the test seam bypassed a scan-time sort.
> - **Saves record the variant per ship** (`"ship"` key), and both a missing key (pre-M7 save) and an unknown id (uninstalled mod) fall back to `pirate_ship_scene` with a warning — the fight restores rather than losing a ship the player is mid-battle with.
>
> Verified live: a 5-ship raid spawns tagged variants, saves mid-fight with all five recorded, restores all five as the right variant; and a save hand-edited to name `absentmod.dreadnought` still restores all five, on the fallback, warning once per ship.

### M7 — original finding

`RaidManager` is hardcoded to pirates end to end: one `pirate_ship_scene`, one `PirateShip` class, one strength formula, one save section, one banner. A mod adding a *different kind* of threat — a derelict drifting in, a rival station's blockade, a solar flare — has to write a manager, and M3 is what lets it do that at all.

**Fix, scoped deliberately.** Two tiers:

- **Now:** make ship *variants* data-driven. A `ShipData.tres` (scene, HP, weapon loadout, speed, orbit behaviour script, salvage table) with `RaidManager` selecting from a scanned pool weighted by station value. That covers "mods can add pirate ships and wave compositions", which is the common ask, and it's a normal `.tres` + scan.
- **Deferred:** generalised `ThreatData` + `ThreatDriver` in the `JobData`/`JobDriver` mould, so a threat type is a resource plus a script. Genuinely new design work, and there's no evidence yet anyone wants it. M3 keeps the door open — a mod manager with its own save section can implement a threat without this.

### M8 — There is no way to patch existing content

> **RECIPE INVERSION DONE 2026-08-03 (stage 4). The patch-op format below is still deferred.**
>
> `RecipeData` gained `processor_tags: Array[String]` + `sort_order`, and a static reverse index (`RecipeData.for_tags`) scanned through a new `ContentPaths.RECIPES` root. `ProcessorComponent.get_available_recipes()` assembles the eligible set from the owning module's tags instead of reading a scene array.
>
> - **The existing tags were far too coarse to use as-is.** Every processor module carried exactly one gameplay tag, `"Industrial"` — keying on it would have offered every refining recipe in the forge, the ice processor and the algae tank. Each processor gained a specific second tag (`Refinery`, `Forge`, `IceProcessing`, `Electrolysis`, `AlgaeCulture` on both algae modules, `Hydroponics`), and the ten vanilla recipes each declare one. Tags rather than module ids, as the finding prefers: one declaration reaches the vanilla refinery *and* any modded refinery claiming the same tag.
> - **`sort_order` with gaps of 10** preserves the refinery's authored selector order (Iron, Carbon, Silicon, Gold, Iridium) exactly, and lets a mod slot a recipe *between* two vanilla ones rather than only at the end.
> - **Resolved lazily and cached**, not in `_ready()`: `module_data` isn't reliably assigned by the time a component readies, and this is the only thing here that needs it.
> - **Both asserts retired.** `assert(available_recipes.has(recipe))` is gone entirely; `select_recipe` now warns and refuses. The eligible set is assembled from scanned data, so a stale UI entry or a mod recipe whose tag stopped matching is a content problem, not a programming error, and must not take the game down.
> - **The legacy array is deleted, with evidence.** The migration ran the two-step the finding asks for: a transitional union that warned whenever a scene array contributed anything the index didn't, then a probe comparing both across all seven processors. The index alone reproduced every authored list and every scene default, so `ore_processor.tscn`'s `available_recipes` (the only one ever set) was removed. `ProcessorComponent.available_recipes` remains as an export purely so an unmigrated third-party scene still works, and still warns if it contributes.
>
> Verified live: a placed refinery resolves five recipes in the authored order with a working selector, its default is among them, and an ineligible recipe is refused without crashing.

### M8 — original finding

Godot has no XPath-patch equivalent. A mod that wants to change a vanilla number must ship a replacing `.tres`, and two mods doing that conflict silently and order-dependently.

The specific trap for the stated "new resources" use case: `ProcessorComponent.available_recipes` is an `@export Array[RecipeData]` on the component **in the module scene**. So a mod can add a new ore and a new `RecipeData` for smelting it, and there is no way to make the existing refinery accept the recipe short of shipping a replacement refinery scene — at which point it conflicts with every other mod that did the same.

That single fact is the difference between "mods can add ores" and "mods can add ore *chains*", so it matters more than the general patching question.

**Fix, in two independent pieces:**

- **Invert recipe eligibility** (do this one regardless). `RecipeData` declares which processors it's valid for — by module id or, better, by module tag (`&"smelter"`), reusing the tag vocabulary that upgrades and adjacency already key on. `ProcessorComponent` builds `available_recipes` at ready from a reverse index instead of reading a scene array. Vanilla keeps its current recipe sets, expressed as data; mods add recipes to vanilla processors by declaring a tag. This also retires the `assert(available_recipes.has(recipe))` at [`processor_component.gd:96`](../../../../modules/components/processor_component.gd), which a mod could otherwise trip into a crash.
- **A patch-op format** (defer until asked for). `ModPatch.tres`: target id, property path, op (`set` / `add` / `mul` / `append` / `remove`), value; applied after all scans, in mod load order, with a log line per applied op. Enough for balance mods, and it makes conflicts *visible* instead of silent, which is the actual win. Not enough to restructure a scene, and shouldn't try.

### M9 — Exported builds will not register mod `class_name`s

> **SPIKED 2026-08-02. Confirmed, with one correction and one reprieve.** 29 checks, run in all four of {editor build, exported build} × {text-script pack, binary-token pack} — 29/29 green in every one. Method and full findings below.

`global_script_class_cache.cfg` is baked at export. Scripts inside a mod `.pck` do load and run, but their `class_name` is not registered, so:

- **A mod script cannot reference *any* mod `class_name` — including its own.** This is stricter than the original "A cannot reference B". `class_name X` may be *declared* freely (harmless, and the mod's own project needs it for editor support), but every *reference* to `X` is a hard failure: `Compile Error: Identifier not found: SpikeShimmerData` on a script's own `X.new()`, `Parse Error: Could not find type "X" in the current scope` on another script's use of it. The practical bite is that the vanilla subclass idiom is uncopyable — `OreInstanceData.merged_with()` opens with `other as OreInstanceData` and builds an `OreInstanceData.new()`, and a mod writing the same subclass can do neither.
- Mod `.tres` files must reference scripts by `uid://` or path, never by class name.
- Mod scripts *can* reference vanilla class names freely — those are baked. Confirmed both by `extends ItemInstanceData` and by a static call through `ResourceScanner`.
- **This is not export-only.** The editor build behaves identically, because a pack-mounted script is missing from the class cache either way. Good news for the rest of this WI: stages 1–5 can be developed and verified without exporting.

**The reprieve: `preload()` and `load()` by path substitute completely.** All four routes work, in both build types:

| Mod script needs | Works? |
| --- | --- |
| `const Helper := preload("res://mods/<id>/scripts/helper.gd")`, then `Helper.static_fn()` / `Helper.new()` | yes |
| `load("res://mods/<id>/scripts/helper.gd")` at call time (optional cross-mod deps) | yes |
| `preload()` of a **vanilla** script by path | yes — identical result to the class_name route |
| another of itself: `(get_script() as GDScript).new()`; identity: `other.get_script() == get_script()` | yes |

So M9 costs mods static typing across their own files, and nothing else. It is an authoring rule, not a capability gap, and it belongs in the mod-author docs rather than in the engine-facing design.

WI-44's `@export var driver: Script` already does the right thing here (a `Script` reference, not a `class_name` string), and the reasoning in its comment — "so that renaming the driver is caught when the resource is loaded" — turns out to be the modding-correct choice too. The spike loaded a **vanilla** `JobData.tres` living inside a mod pack whose `driver` pointed at a **mod** script, instantiated it, and called through it. That combination is the most load-bearing one in the whole design and it works untouched.

#### Other spike findings

1. **uid beats a stale path.** A mod `.tres` referencing `resource_data.gd` by its correct uid and a deliberately wrong path loaded fine. So "**never re-uid**" is the real rule — moving or renaming a vanilla script is safe as long as its `.uid` sidecar travels with it. Add to the standing rules.
2. **Mount with `replace_files = false`.** Not optional. An exported pack carries `res://.godot/global_script_class_cache.cfg`, `res://.godot/uid_cache.bin` **and** `res://project.binary` alongside the mod's own files, and the default `replace_files = true` lets any mod shadow all three plus any vanilla resource. With `false`: a deliberate shadow of a vanilla `.tres` lost to the vanilla copy, the global class list stayed at exactly its pre-mount size, and vanilla resources kept loading. This makes M1's "a mod can never shadow a vanilla file by accident" true *by mechanism* rather than by naming convention — worth keeping both.
3. **A `script_class="..."` header hint naming an unregistered mod class is harmless.** The editor writes one into every `.tres` whose script has a `class_name`; the loader treats it as a hint and falls through to the script reference. Mod authors don't have to hand-strip it.
4. **Both script export modes work, and they behave differently on disk.** Text mode ships `res://….gd` verbatim. Binary-token mode (which is what *this* project's own preset uses, `script_export_mode=2`) ships `res://….gdc` plus a `res://….gd.remap`; `load("….gd")` follows the remap transparently, but `FileAccess` on the `.gd` path returns `ERR_FILE_NOT_FOUND`. **Consequence for M1: `ModManager` must read `mod.json` through `FileAccess` (plain files are never remapped) and everything else through `ResourceLoader` — it must never `FileAccess` a mod script.** `ResourceScanner` already strips `.remap`, which is exactly why.
5. **Discovery needs no new code.** `ResourceLoader.list_directory` and `DirAccess.open` both see a pack-mounted root, and `ResourceScanner.scan_paths` recursed one correctly (4 `.tres` across two nested dirs) in all four environments. `ContentPaths` only has to supply the roots; the 13 scan sites need no other change.
6. **Mod scenes work end to end** — a `.tscn` in the pack with a mod script on its root, a *vanilla* `ComponentBase` script on a child, and an `ExtResource` pointing at a mod `.tres`, all resolved on `instantiate()`.
7. **Late mounting is fine.** The probe mounted from an autoload *after* the main scene was already up and everything resolved. That doesn't settle the "`ModManager` before `Global`" open question — content *scanning* still has to happen after the mount — but it does rule out needing to mount before engine startup.
8. **A mod project does not need the game's source to build a pack.** Hand-written `.tres` carrying the right uid and path resolve at runtime against the game's `res://`, and a mod script that can't compile in its own project still exports (text mode doesn't parse; binary mode only tokenizes). The pack does have to be authored at the *mount* path — files must live at `res://mods/<id>/…` in the mod project. In practice authors will still want an SDK copy of the project for editor support; that's a stage-1 deliverable, not a blocker.

#### What the spike did NOT cover

Autoload ordering (`ModManager` before `Global`); a modded module actually placed, built and saved; two mods with colliding ids; the cost of N packs at startup. All of those are stage-1/stage-3 work with real code behind them.

#### Reproducing it

Throwaway mod project (bare, ~10 files, so anything it resolves provably came from the game and not from a vanilla script the pack carried along): `mods/spikemod/{mod.json, scripts/*.gd, data/{resources,jobs}/*.tres, scenes/spike_scene.tscn}` plus one `data/resources/test_resource.tres` that exists only to attempt a shadow. Two presets differing solely in `script_export_mode` (0 and 2).

```
godot --headless --path <modproj> --export-pack "Mod Pack" spikemod.pck
copy spikemod.pck  ->  %APPDATA%/Godot/app_userdata/Spaceport Iridium/mods/
godot --headless --path . -- --mod-spike                       # editor build
godot --headless --path . --export-release "Windows Desktop" <out.exe>
"<out.exe>" --headless -- --mod-spike                          # exported build
```

The probe was a temporary `ModSpike` autoload gated on `OS.get_cmdline_user_args().has("--mod-spike")`, writing to `user://mod_spike_result.txt` (the exported build has no console wrapper, so stdout isn't reachable). Deleted after, along with its autoload entry — see the WI-30..WI-33 probe pattern.

### M10 — Pawn variations have no data resource

> **DONE 2026-08-03 (stage 4).** `PawnData` (`data/pawns/`), scanned as a `ContentPaths` kind, with vanilla `crew.tres` and `visitor.tres`. `CrewManager.spawn_crew` and `VisitorManager._deliver_visitor` roll a kind for their role instead of instantiating one hardcoded scene; both keep their existing export as the fallback, so an empty `data/pawns/` still plays.
>
> - **`HireCandidate` gained `pawn_id`**, rolled when the candidate is generated and saved with it, so a hire queued on a shuttle arrives as the kind the player picked from the list. Omitted from the dict when unset, so pre-M10 saves and default-kind candidates are byte-identical.
> - **`hire_price_mult` folds into the existing trait multiplier chain** rather than adding a parallel rule.
> - **No `name_style` field**, contrary to the finding's list: `NameGenerator` has no notion of styles, and an export nothing reads is worse than none. It belongs with the name-word-list audit this WI already defers.
> - **The weighted roll moved into `WeightedPick`** (`scripts/utility/`), shared with M7's ship variants. The subtle part is the boundaries — `randf()` returns exactly 0.0, and float accumulation can push a roll of 1.0 past the last bucket — so it is worth having once.
> - An uninstalled kind (mod removed between queueing a hire and its shuttle landing) warns and spawns the fallback rather than losing the hire.
>
> Verified live: starting crew and a visitor both spawn through the kind roll, all four hire candidates carry their kind, the kind survives a candidate save round trip, and a candidate rewritten to name `absentmod.synthetic` still hires onto the fallback scene.

### M10 — original finding

Crew / visitor / robot differ by scene plus code (`RobotPawnBase` builds its energy and integrity components in `_ready`). There's no `PawnData`. Restore is already fine — the save stores `scene_file_path` — but *spawning* isn't: `CrewManager` has one `crew_pawn_scene`, `VisitorManager` one `visitor_pawn_scene`, and the hire-candidate generator has no notion of alternate kinds.

**Fix.** A scanned `PawnData.tres` (scene, display name, which manager sources it, hire-price band, name-generator style, spawn weight) that `CrewManager` / `VisitorManager` / hire candidates select from. Smaller than it looks once M2 lands, because the per-component restore chain is the bulk of what makes pawn kinds special-cased today.

### M11 — The save must record its mod list

> **DONE 2026-08-02 (stage 3).** `meta.mods` is `[{id, version}, …]` from `ModManager.mod_records()`. `SaveManager.mod_drift(saved_records)` is one pure rule shared by the slot browser and the load path: a mod that isn't installed, or is installed at a different version, is drift; extra mods are not. Absent on pre-WI-47 saves reads as "no mods", not "mods missing".
>
> - **Slot browser** renders an amber `⚠` line naming each drifted mod, before the player commits.
> - **On load**: `push_warning` plus a `station_alert`, naming mod and version, and the game proceeds. Verified end to end — saved with the sample mod installed, uninstalled it, loaded: *"This save used mods that aren't loaded: spikemod (0.1.0) is not installed. Modules and items from them are gone, and the station may be unplayable."*

### M11 — original finding

A save written with mods and loaded without them is not a small degradation. Decision 4 says fail soft, and `world_manager.gd:203` does exactly that per module — but "fail soft" applied to a station whose reactor, refinery and half its corridors came from an absent mod produces a *running game that is no longer playable*, silently. The player deserves to be told which it is, and the game cannot tell them without recording what was loaded.

**Fix.** The `meta` block gains `mods: [{id, version}, …]` — `meta` already exists to let the slot browser render a row without parsing sections, and this is the same kind of cheap header data.

Three behaviours, all decided:

- **Slot browser:** a save whose mod set doesn't match the currently-loaded set is marked in the list, before the player commits to loading it. Cheap because it's `meta`.
- **On load with mods missing:** a **warning, not a refusal** — name the missing mods, state plainly that the station may be missing modules and the game may be unplayable, and let the player proceed. Refusing outright would strand saves whose mod simply changed version, and there's no way to know in advance how load-bearing the missing content was. Proceeding is the player's call; making it silently is not.
- **On load with *extra* mods** (installed since the save): no warning. Additive content that wasn't there before is the normal, working case.

Version mismatch on a mod that *is* present is a warning too, with the same wording — a mod that renamed its ids between versions is indistinguishable from a missing one at load time.

This pairs with M3's unknown-section passthrough: the warning covers content the player can see is gone, and the passthrough makes sure the state behind it survives a round trip so re-installing the mod restores the run rather than half of it.

## ~~Not yet audited~~ — SWEPT 2026-08-03

All eight checked. Two were real gaps and are fixed; two more were downstream of one of those and fixed with it; four were false alarms. Verified by a 10-check in-game run with the sample mod installed, confirming both halves at once: every vanilla entry still present (16 market resources → 17, 6 ores → 7) and the mod's ore joined.

| Area | Verdict |
| --- | --- |
| **`MarketManager` listing seeds** | **GAP, FIXED.** `market_resources` is an `@export` on a node in main.tscn, so a mod's resource could never be quoted, sold or bought. `ResourceData.tradable` now opts in, and the manager unions its authored list with everything declaring it. |
| **`TraderManager` stock generation** | **No gap of its own** — it reads `market_manager.get_tradeable_resources()`. Fixed by the above. |
| **`ContractManager` demand generation** | **No gap of its own** — same list. Fixed by the above. |
| **`AsteroidManager` ore tables** | **GAP, FIXED.** `ore_types_available` is likewise an `@export`, so a modded ore could never appear in the belt — where a mining-chain mod has to start. `ResourceData.asteroid_spawn_weight` now opts in; the manager's `ore_spawn_weights` dictionary still wins where it has an entry, so vanilla weights are untouched. |
| **minimap tag→colour table** | **Minor gap, FIXED.** The table is an `@export` keyed by tag; a modded module with a new tag drew in fallback hull grey with no way to say otherwise. `ModuleData.minimap_color` (alpha 0 = keep the tag lookup) is checked first. |
| **tier export goals (`data/tiers/`)** | **No gap.** `export_goals` is `Dictionary[StringName, int]` keyed by resource *id*, and `data/tiers/` is already a scanned `ContentPaths` root — a mod ships its own tier resources naming its own ores. Adding a goal to a *vanilla* tier is the general patching problem (stage 5), not hardcoding. |
| **`OverlayPalette`** | **No gap.** The suspicion doesn't hold: it is pure value→colour arithmetic (O2 partial, hp fraction, field level, priority). Nothing enumerates resources or modules, so there is nothing for mod content to fall out of. |
| **`NameGenerator` word lists** | **Real but deferred.** Pools come from the vendored m12 addon with a hardcoded syllable fallback; a mod can't add name words. Cosmetic, addon-bound, and it is the reason M10 ships no `name_style` field. Worth a small item if anyone asks; not worth inventing an extension point nothing has requested. |

The two fixes follow the same shape as M8's recipe inversion: the *content* declares its participation and the manager unions that with its authored list, so vanilla behaviour is byte-identical with no `.tres` edits and a mod only has to say so. `tools/sample_mod/`'s glimmerite now sets both flags, so the sample covers the sweep too.

## Files to touch

**Stage 1 (loader) — DONE**
- `scripts/managers/mod_manager.gd`, `scripts/mods/{mod_manifest,mod_registry}.gd`, `scripts/utility/content_paths.gd` — new
- `project.godot` — `ModManager` autoload, ordered before `Global`
- The 13 scan sites: `ui/buttons/build_menu.gd`, `scripts/managers/save_manager.gd` (×2), `scripts/managers/unlock_manager.gd` (×3), `scripts/managers/event_manager.gd`, `scripts/jobs/job_data_registry.gd`, `data/{difficulty,diseases,shops,skills,traits}/*_data.gd`
- `ui/menus/main_menu.gd` — the one place outside a scan site that named a path constant
- `tools/sample_mod/` + `tools/.gdignore` — the fixture, kept out of the game's filesystem scan and out of its export

**Stage 2 (component persistence)**
- `modules/components/component_base.gd`, `pawns/pawn_component_base.gd` — virtual hooks + `save_order` + `save_key`
- `modules/templates/module_base.gd` — `:426–600` collapses to a loop
- `scripts/managers/save_manager.gd` — `_load_pawns` component chain collapses likewise
- Every component with existing save data — override the hooks, port the ordering comment onto `save_order`

**Stage 3 (save sections + instance data + mod list)**
- `scripts/managers/save_manager.gd` — `SaveParticipant` registry, `instance_from_dict` registry, unknown-section passthrough, `meta.mods`
- `data/resources/item_instance_data.gd` + the two subclasses — `type_id`
- Every manager contributing a section — register instead of being listed
- `ui/menus/` slot browser + load path — M11's mismatch marker and the missing-mods warning

**Stage 4 (extension points)**
- `data/modules/module_data.gd`, `ui/buttons/build_menu_model.gd`, `ui/buttons/build_menu.gd` + new `BuildCategoryData` — M5
- The four truss preloads, `mining_component.gd`, `logistics_bay_component.gd`, `inspection_runner.gd` — M6
- `data/recipes/recipe_data.gd`, `modules/components/processor_component.gd` — M8 recipe inversion
- New `ShipData`, `scripts/managers/raid_manager.gd` — M7
- New `PawnData`, `scripts/managers/crew_manager.gd`, `scripts/managers/visitor_manager.gd` — M10

**Throughout**
- `tests/unit/test_mod_registry.gd`, `tests/unit/test_content_paths.gd` — new
- `tests/unit/test_component_persistence.gd` — extend; it's the safety net for stage 2
- A sample mod under `tests/fixtures/` or similar, shipped as the living example. The M9 spike's throwaway mod project is its seed — it already covers a variance resource, a mod `ItemInstanceData` subclass, a mod `JobDriver` behind a vanilla `JobData`, a mod scene with a vanilla component, and both script export modes; what it lacks is a module, a tech node, a build category and anything that saves state.

## Implementation order

1. ~~**M9 spike first.**~~ **DONE 2026-08-02** — 29/29 in all four environments, no redesign needed. See M9.
2. ~~**Stage 1 — M1.** Loader + `ContentPaths` + namespacing.~~ **DONE 2026-08-02** — see M1.
3. ~~**Stage 2 — M2.** Component save hooks, both bases.~~ **DONE 2026-08-02** — see M2.
4. ~~**Stage 3 — M3, M4, M11.** Save participants, instance-data registry, and the `meta.mods` list.~~ **DONE 2026-08-02** — see M3, M4, M11.
5. **Stage 4 — M5, M6, M8-recipes, M7-ships, M10.** Additive and independent of each other; each can ship or slip alone. Sweep the "not yet audited" list here. **ALL FIVE DONE 2026-08-03. Only the "not yet audited" sweep remains.**
6. **Stage 5 — M8 patch ops.** Only if a real mod wants it.

Stages 2 and 3 change no save bytes and add no features. They will feel like no progress and they are the entire item.

## Edge cases

- **Ordering:** a modded component with default `save_order` on a module that also carries construction and storage must land *after* construction. Confirm the default is a value that keeps vanilla's constraints intact rather than one that happens to work today.
- **Path keys:** `get_path_to(component)` must be stable across save/load for a mod module whose scene the mod later edits. A moved component node silently orphans its save block — same failure the storage dict already has, so it's not new, but document it as a mod-author rule.
- **Missing mod on load:** a save whose modules came from a now-absent mod. `world_manager.gd:203` skips them; confirm the *station* survives that — a load that drops half the modules must not leave dangling turboshaft groups, orphaned pawns mid-job, or a `PathManager` graph referencing freed modules.
- **Missing mod, unknown sections:** M3's passthrough must survive a full save→load→save round trip with the mod disabled, and the re-enabled mod must find its state intact.
- **Two mods, same id:** hard error surfaced in the UI, not a `push_warning` into the log.
- **Mod content referenced by an unlock:** a `GrantModuleEffect` pointing at a module from a *different* mod that isn't installed. Must degrade to a dead tech node, not a crash on `UnlockManager` scan.
- **A mod's `.tres` referencing a vanilla script whose uid changed.** This is M9's rule failing in practice. Detect and log clearly rather than surfacing as a generic load error. (Spike: uid takes precedence over path, so a *moved* vanilla script is fine as long as its `.uid` moved with it. Only a *changed* uid breaks a mod — hence "never re-uid", not "never move".)
- ~~**Recipe inversion (M8):** a vanilla processor whose scene array and the new tag index disagree during the transition. Assert-free migration — build from the index, log the diff once, delete the array in a follow-up.~~ **DONE 2026-08-03** exactly this way: a transitional union that warns on any scene-only entry, a probe diffing index against scene across all seven processors (the index was a superset everywhere, defaults included), then the one authored array deleted.
- **Save with mods, load in vanilla:** already works for modules; confirm for jobs (`JobDataRegistry` returns null → job dropped), resources, and pawn scenes.
- **M11 on a pre-WI-47 save:** absent `meta.mods` must read as "no mods", not as "mods missing", or every legacy save warns.
- **M11 with a mod present at a different version:** warns, and the player can still proceed. Confirm the warning names the mod and version rather than just counting.

## Verification

1. ~~**Spike:** exported build loads a `.pck` containing one script and one `.tres`; the `.tres`'s script reference resolves.~~ **PASSED 2026-08-02**, plus mod↔mod `preload`, mod scenes, the `driver: Script` round trip, both script export modes, and the shadowing/`replace_files` behaviour.
2. ~~**Stage 2 regression:** save a mature station, apply stage 2, load the *pre-refactor* save → byte-identical world state.~~ **PASSED 2026-08-02**, with the criterion corrected from byte-identical to structurally identical: the walk deliberately writes blocks in restore order, so key order moves. 21 modules × 11 component block types + 3 pawns, every value identical, only the documented `traits` shape change differing.
3. **Ordering:** a processor mid-batch with a queued recipe, a deconstructing module with reconfigured storage, and a fuel generator mid-burn (WI-45 A3) all survive save/load after stage 2. These are the three constraints most likely to break.
4. ~~**Stage 3:** disable a mod that owns a save section, load, save, re-enable, load → state intact.~~ **PASSED 2026-08-02** — a section from an absent mod was injected on disk, survived load → re-save unchanged, and every other section round-tripped value-for-value (0 differences). All 16 vanilla sections registered in the documented order. The re-enable half is covered by the passthrough being value-preserving.
5. **M11:** save a station built largely from a mod's modules, disable the mod, open the slot browser → the row is marked before loading. Load anyway → warning names the mod, the game runs, the modded modules are gone. Re-enable, load the *same* save → the station is whole again and the mod's section survived the round trip.
6. ~~**The sample mod is the real test.** Ship one that exercises every path: a new resource with variance, a processor recipe attached to a *vanilla* refinery by tag, a new module with a new component that saves state, a new job type with a driver, a tech node granting the module, a new build category, a ship variant, a pawn kind. If the sample mod needs a single core edit, this WI isn't done.~~ **PASSED 2026-08-03.** `tools/sample_mod/` now covers all eight, verified by a 22-check probe across a build and a restore run: every piece registers, the mod recipe appears in the vanilla refinery's selector beside the five vanilla ones, the module unlocks by research and places, and its mod component's state survives a save/load. **`git status` after the run showed no file changed outside `tools/sample_mod/`** — the "zero core edits" bar met literally.
>
> Two things the exercise taught, both now in the mod's README: a modded module scene is tiny because module scenes *inherit* `modules/templates/module_base.tscn`, which already carries sprite/footprint/path/structure/construction; and a mod's `.tres` should carry uid **and** path for vanilla references, since a wrong uid silently degrades to the path with only a warning.
7. **Fail-soft:** a mod with a malformed manifest, a mod with a `.tres` referencing a missing script, and two mods with colliding ids each produce a clear message and a running game.
8. **GUT:** full suite green (505 baseline at WI-45) plus the new registry suites.
9. **Regression:** build → deconstruct → collect pile; a trade caravan; a turbolift ride; a full raid. Stage 2 touches the persistence of nearly every component these depend on.

## Open questions

- **Autoload ordering.** `ModManager` must run before `Global`, but `Global` is where every manager registers. Confirm a plain autoload ordered first is sufficient, or whether the packs need mounting even earlier (a `--main-pack` style bootstrap, or from the main menu before the scene swap). The M9 spike narrowed this: mounting from an autoload *after* the main scene was already running still resolved everything, so nothing has to happen before engine startup — the constraint is only "mount before the first scan", not "mount before boot".
- **Mod list UI.** WI-36 built the main menu and settings shell. A mods page belongs there, but it's unscoped — this WI assumes at minimum a read-only list with load status and errors.
- **`ResourceScanner` cost.** 12 roots × N mods, each `ResourceLoader.load`ed at startup. Fine at vanilla scale; unmeasured at 30 mods. Worth a number before stage 4.

## Related

- [[WI-44_Job_System_Refactor]] — the extension-point pattern this WI generalises; `JobDataRegistry` is the model for M1 and M3.
- [[WI-45_Save_System_Audit]] — the component-by-component field sweep M2 refactors, and the source of the ordering constraints it must preserve. Its `test_component_persistence.gd` is stage 2's safety net.
- [[WI-43_Build_Menu]] — introduced the `UICategory` enum M5 converts.
- [[WI-39_Power_Registry]] — precedent for replacing implicit discovery with explicit registration, which is M3's shape.
- [[01_Technical_Specification]] — needs a modding section once stage 3 lands.
