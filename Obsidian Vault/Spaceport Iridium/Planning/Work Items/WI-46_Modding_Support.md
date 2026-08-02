# WI-46 — Modding Support

> **Status: PLANNED (2026-08-01).** Design only, nothing implemented. Sized as a multi-stage item in the WI-44 mould — stages 1–3 are pure refactors of existing behaviour and are the whole load-bearing part; stages 4–5 are additive and can be dropped or deferred without stranding anything.

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

Every scan root is a `const String` baked to `res://`: 11 named constants (`MODULE_PATH`, `UNLOCK_PATH`, `TIER_PATH`, `LOCAL_UPGRADE_PATH`, `JOB_PATH`, `EVENT_PATH`, `DISEASES_PATH`, `SKILLS_PATH`, `TRAITS_PATH`, `SHOPS_PATH`, `DIFFICULTY_PATH`) plus two inline strings in [`save_manager.gd:101,105`](../../../../scripts/managers/save_manager.gd). Nothing calls `load_resource_pack`.

**Fix.** Two new pieces:

- **`ModManager`** — autoload, ordered *before* `Global`. Scans `user://mods/*/mod.json`, validates the manifest (`id`, `name`, `version`, `game_version`, optional `deps` and `load_after`), topo-sorts, `ProjectSettings.load_resource_pack()`s each `.pck` in order, and records what loaded plus what failed and why.
- **`ContentPaths`** — the roots registry. `ContentPaths.roots_for(&"modules")` returns `["res://data/modules/", "res://mods/coolmod/data/modules/", …]`; the 13 call sites loop it instead of taking a const. Base game roots register themselves so vanilla is just "mod zero" and the code path is never untested.

Mod `.pck`s mount into `res://mods/<id>/` by convention rather than overwriting `res://data/`, so a mod can never shadow a vanilla file by accident — shadowing becomes an explicit stage-5 operation.

**Id namespacing.** Mod content ids must be `modid.thing`. [`SaveManager._register_id`](../../../../scripts/managers/save_manager.gd) currently warns and *keeps the first* on a duplicate, which is load-order-dependent and easy to miss. Make a collision between two *different* mods a hard, surfaced error (mod list screen, not just `push_warning`), and validate the prefix at load. Vanilla ids stay unprefixed — they're the reserved namespace.

### M2 — Components cannot save state

**This is the single biggest blocker and the reason stage 2 exists.**

[`ComponentBase`](../../../../modules/components/component_base.gd) has no save hooks at all. Instead, [`module_base.gd:426–600`](../../../../modules/templates/module_base.gd) is a hand-written chain — `get_component_by_type(ProcessorComponent)` → `data["processor"] = …` — roughly twenty times, mirrored in `load_save_data` at `:529`. `PawnComponentBase` has the same hole, filled the same way by `SaveManager._load_pawns` (needs / health / skills / traits / disease / breathing / robot_power / robot_integrity / visitor).

A modded component is therefore *structurally incapable* of persisting. Not "awkward to persist" — there is no seam.

**Fix.** Virtual `get_save_data() -> Dictionary` / `load_save_data(data: Dictionary)` on both `ComponentBase` and `PawnComponentBase`, defaulting to `{}` / no-op. `ModuleBase` walks `components` and keys each block the way storage already keys its own — by `get_path_to(component)`, which is stable across a save/load because it's the scene path.

Two things this must not break:

- **Order is load-bearing and currently encoded in comments.** "Construction before storage: the deconstructed path reconfigures the material storage." "Processor before storage: restoring the recipe reconfigures the input/output slots." WI-45 added more of these (residue before recipe; A3's `powered` alongside `force_off`). A naïve `for component in components` loop silently reorders all of it. Add an exported `save_order: int = 0` on the component bases, sort by it, and port each existing ordering constraint to an explicit number with the comment moved onto the field. **Getting this wrong produces a bug class that only appears in modded saves**, which is the worst possible place for it.
- **The on-disk shape must not change.** Keep the existing key names (`"construction"`, `"processor"`, `"storage"`, …) by giving each vanilla component a `save_key` that defaults to its node path but is overridden to the legacy string. Pre-WI-46 saves then load untouched, and no `SAVE_VERSION` bump is needed. Modded components get path keys, which is fine because no old save contains them.

This stage is a pure refactor with a large blast radius and total test coverage available (`tests/unit/test_component_persistence.gd` from WI-45 exists precisely for this). Do it before anything additive.

### M3 — Save sections are a literal

[`save_manager.gd:283–305`](../../../../scripts/managers/save_manager.gd) hardcodes 17 sections; `_apply_pending_load` hardcodes their load order at `:661–695`, with ordering comments as load-bearing as M2's ("phantom settlement fires" — economy after time; pawns before crew; contracts after traders).

A mod that adds a manager — a new threat system, a faction, a research track — has nowhere to put state.

**Fix.** A `SaveParticipant` interface (`section_id() -> StringName`, `save_order() -> int`, `get_save_data()`, `load_save_data()`), registered on `SaveManager` the way managers already register into `Global` in `_ready()`. Vanilla managers register with their current section ids and explicit order numbers derived from today's sequence. Unknown sections in a save (mod present when saved, absent when loaded) are **preserved and written back out untouched** rather than dropped — so disabling a mod for one session doesn't destroy its state.

### M4 — `ItemInstanceData` subtypes are a hardcoded match

[`save_manager.gd:153`](../../../../scripts/managers/save_manager.gd):

```gdscript
match String(data.get("type", "")):
    "ore": …OreInstanceData…
    "food": …FoodInstanceData…
```

Any modded resource with `has_variance = true` silently loses its instance data on save — which is the *entire point* of variance. Given WI-09 built ore richness and WI-29 built food quality on this, a mod adding e.g. component purity or fuel grade is a natural thing to want.

**Fix.** Make the subclass self-describing: an exported `type_id: StringName` on `ItemInstanceData` plus a registry that maps it back to a script, or simply store the script's `uid://` in the dict and instantiate from that. The `uid` route is less code but pins M9's "never re-uid a script" rule harder. Prefer the explicit `type_id` + registry; it keeps saves human-readable, which has been worth a lot during every previous audit.

### M5 — `ModuleData.UICategory` is an enum

[`module_data.gd`](../../../../data/modules/module_data.gd) declares a fixed 12-value enum, and [`build_menu_model.gd:17–30`](../../../../ui/buttons/build_menu_model.gd) maps each to a label. Enums cannot be extended from data, so a mod cannot add a build-menu rail category — its modules all land in `OTHER`.

**Fix.** `StringName category_id` plus a scanned `BuildCategoryData.tres` carrying `id`, `display_name`, `sort_order`, `cat_icon`. `BuildMenuModel.group_modules` / `category_order` / `category_name` all key on the resource instead of the enum.

Cheap **now** — WI-43 shipped days ago and the call sites are small and fresh — and it gets steadily more expensive. Worth doing even if the rest of this WI slips.

### M6 — Content-ish scene preloads

Not many, but each one is a thing a mod can't reach:

- `truss` — preloaded at four sites: [`hallway.gd:5`](../../../../modules/core/hallway.gd), [`stairs.gd:5`](../../../../modules/core/stairs.gd), [`module_airlock.gd:5`](../../../../modules/transport/module_airlock.gd), [`module_turbolift.gd:5`](../../../../modules/transport/module_turbolift.gd). (`ModuleBase.replacement_on_delete` is already an `@export` — these four bypass it.)
- [`mining_component.gd:6`](../../../../modules/components/mining_component.gd) mining drone, [`logistics_bay_component.gd:17`](../../../../modules/components/logistics_bay_component.gd) hauler robot (a path string, not even a preload), [`inspection_runner.gd:18–19`](../../../../scripts/managers/inspection_runner.gd) arrival shuttle + inspector pawn.

**Fix.** `@export` where the owner is a scene (the four truss sites should just use `replacement_on_delete`), or a `GameContentData` settings resource for the manager-level ones. `RaidManager.pirate_ship_scene`, `CrewManager.crew_pawn_scene` and `VisitorManager.visitor_pawn_scene` are already exports — that's the pattern to match.

### M7 — New dangers means one new manager per danger

`RaidManager` is hardcoded to pirates end to end: one `pirate_ship_scene`, one `PirateShip` class, one strength formula, one save section, one banner. A mod adding a *different kind* of threat — a derelict drifting in, a rival station's blockade, a solar flare — has to write a manager, and M3 is what lets it do that at all.

**Fix, scoped deliberately.** Two tiers:

- **Now:** make ship *variants* data-driven. A `ShipData.tres` (scene, HP, weapon loadout, speed, orbit behaviour script, salvage table) with `RaidManager` selecting from a scanned pool weighted by station value. That covers "mods can add pirate ships and wave compositions", which is the common ask, and it's a normal `.tres` + scan.
- **Deferred:** generalised `ThreatData` + `ThreatDriver` in the `JobData`/`JobDriver` mould, so a threat type is a resource plus a script. Genuinely new design work, and there's no evidence yet anyone wants it. M3 keeps the door open — a mod manager with its own save section can implement a threat without this.

### M8 — There is no way to patch existing content

Godot has no XPath-patch equivalent. A mod that wants to change a vanilla number must ship a replacing `.tres`, and two mods doing that conflict silently and order-dependently.

The specific trap for the stated "new resources" use case: `ProcessorComponent.available_recipes` is an `@export Array[RecipeData]` on the component **in the module scene**. So a mod can add a new ore and a new `RecipeData` for smelting it, and there is no way to make the existing refinery accept the recipe short of shipping a replacement refinery scene — at which point it conflicts with every other mod that did the same.

That single fact is the difference between "mods can add ores" and "mods can add ore *chains*", so it matters more than the general patching question.

**Fix, in two independent pieces:**

- **Invert recipe eligibility** (do this one regardless). `RecipeData` declares which processors it's valid for — by module id or, better, by module tag (`&"smelter"`), reusing the tag vocabulary that upgrades and adjacency already key on. `ProcessorComponent` builds `available_recipes` at ready from a reverse index instead of reading a scene array. Vanilla keeps its current recipe sets, expressed as data; mods add recipes to vanilla processors by declaring a tag. This also retires the `assert(available_recipes.has(recipe))` at [`processor_component.gd:96`](../../../../modules/components/processor_component.gd), which a mod could otherwise trip into a crash.
- **A patch-op format** (defer until asked for). `ModPatch.tres`: target id, property path, op (`set` / `add` / `mul` / `append` / `remove`), value; applied after all scans, in mod load order, with a log line per applied op. Enough for balance mods, and it makes conflicts *visible* instead of silent, which is the actual win. Not enough to restructure a scene, and shouldn't try.

### M9 — Exported builds will not register mod `class_name`s

`global_script_class_cache.cfg` is baked at export. Scripts inside a mod `.pck` do load and run, but their `class_name` is not registered, so:

- Mod script A cannot reference mod script B by class name, or type against it.
- Mod `.tres` files must reference scripts by `uid://` or path, never by class name.
- Mod scripts *can* reference vanilla class names freely — those are baked.

WI-44's `@export var driver: Script` already does the right thing here (a `Script` reference, not a `class_name` string), and the reasoning in its comment — "so that renaming the driver is caught when the resource is loaded" — turns out to be the modding-correct choice too.

**Two consequences to commit to now:**

1. **Never re-uid an existing script or resource.** Mod `.tres` files will reference vanilla scripts by uid. Add this to the standing rules.
2. **Spike this before designing around it.** Build a throwaway `.pck` with one script and one `.tres` referencing a vanilla class, export the game, and confirm it loads. Everything downstream assumes it does. This is stage 1's first task, not its last.

### M10 — Pawn variations have no data resource

Crew / visitor / robot differ by scene plus code (`RobotPawnBase` builds its energy and integrity components in `_ready`). There's no `PawnData`. Restore is already fine — the save stores `scene_file_path` — but *spawning* isn't: `CrewManager` has one `crew_pawn_scene`, `VisitorManager` one `visitor_pawn_scene`, and the hire-candidate generator has no notion of alternate kinds.

**Fix.** A scanned `PawnData.tres` (scene, display name, which manager sources it, hire-price band, name-generator style, spawn weight) that `CrewManager` / `VisitorManager` / hire candidates select from. Smaller than it looks once M2 lands, because the per-component restore chain is the bulk of what makes pawn kinds special-cased today.

### M11 — The save must record its mod list

A save written with mods and loaded without them is not a small degradation. Decision 4 says fail soft, and `world_manager.gd:203` does exactly that per module — but "fail soft" applied to a station whose reactor, refinery and half its corridors came from an absent mod produces a *running game that is no longer playable*, silently. The player deserves to be told which it is, and the game cannot tell them without recording what was loaded.

**Fix.** The `meta` block gains `mods: [{id, version}, …]` — `meta` already exists to let the slot browser render a row without parsing sections, and this is the same kind of cheap header data.

Three behaviours, all decided:

- **Slot browser:** a save whose mod set doesn't match the currently-loaded set is marked in the list, before the player commits to loading it. Cheap because it's `meta`.
- **On load with mods missing:** a **warning, not a refusal** — name the missing mods, state plainly that the station may be missing modules and the game may be unplayable, and let the player proceed. Refusing outright would strand saves whose mod simply changed version, and there's no way to know in advance how load-bearing the missing content was. Proceeding is the player's call; making it silently is not.
- **On load with *extra* mods** (installed since the save): no warning. Additive content that wasn't there before is the normal, working case.

Version mismatch on a mod that *is* present is a warning too, with the same wording — a mod that renamed its ids between versions is indistinguishable from a missing one at load time.

This pairs with M3's unknown-section passthrough: the warning covers content the player can see is gone, and the passthrough makes sure the state behind it survives a round trip so re-installing the mod restores the run rather than half of it.

## Not yet audited

Stated explicitly so the implementer doesn't assume this WI swept the whole codebase. The following enumerate or assume specific resources and were **not** checked for hardcoding:

`AsteroidManager` ore composition and spawn tables; `MarketManager` listing seeds; `TraderManager` stock generation; `ContractManager` demand generation; the tier export goals in `data/tiers/`; `NameGenerator`'s word lists; `OverlayPalette`'s per-mode value mapping; the minimap's tag→colour table. Each is a plausible place for a hand-written resource list that a mod's new ore would fall out of. Sweep them during stage 4 (M7/M10), which is when new resources first actually need to flow through them.

## Files to touch

**Stage 1 (loader)**
- `scripts/managers/mod_manager.gd`, `scripts/utility/content_paths.gd` — new
- `project.godot` — `ModManager` autoload, ordered before `Global`
- The 13 scan sites: `ui/buttons/build_menu.gd`, `scripts/managers/save_manager.gd` (×2), `scripts/managers/unlock_manager.gd` (×3), `scripts/managers/event_manager.gd`, `scripts/jobs/job_data_registry.gd`, `data/{difficulty,diseases,shops,skills,traits}/*_data.gd`

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
- A sample mod under `tests/fixtures/` or similar, shipped as the living example

## Implementation order

1. **M9 spike first.** One `.pck`, one script, one `.tres`, exported build. Half a day. If mod scripts don't load the way this WI assumes, most of stages 4–5 need redesigning and it's better to know on day one.
2. **Stage 1 — M1.** Loader + `ContentPaths` + namespacing. Nothing else is testable until content can come from somewhere else.
3. **Stage 2 — M2.** Component save hooks, both bases. Pure refactor, biggest blast radius, fully covered by existing tests. Do it while stage 1 is the only new thing in flight.
4. **Stage 3 — M3, M4, M11.** Save participants, instance-data registry, and the `meta.mods` list. M11 goes here rather than later because it freezes part of the meta shape and every save written after this stage should carry it.
5. **Stage 4 — M5, M6, M8-recipes, M7-ships, M10.** Additive and independent of each other; each can ship or slip alone. Sweep the "not yet audited" list here.
6. **Stage 5 — M8 patch ops.** Only if a real mod wants it.

Stages 2 and 3 change no save bytes and add no features. They will feel like no progress and they are the entire item.

## Edge cases

- **Ordering:** a modded component with default `save_order` on a module that also carries construction and storage must land *after* construction. Confirm the default is a value that keeps vanilla's constraints intact rather than one that happens to work today.
- **Path keys:** `get_path_to(component)` must be stable across save/load for a mod module whose scene the mod later edits. A moved component node silently orphans its save block — same failure the storage dict already has, so it's not new, but document it as a mod-author rule.
- **Missing mod on load:** a save whose modules came from a now-absent mod. `world_manager.gd:203` skips them; confirm the *station* survives that — a load that drops half the modules must not leave dangling turboshaft groups, orphaned pawns mid-job, or a `PathManager` graph referencing freed modules.
- **Missing mod, unknown sections:** M3's passthrough must survive a full save→load→save round trip with the mod disabled, and the re-enabled mod must find its state intact.
- **Two mods, same id:** hard error surfaced in the UI, not a `push_warning` into the log.
- **Mod content referenced by an unlock:** a `GrantModuleEffect` pointing at a module from a *different* mod that isn't installed. Must degrade to a dead tech node, not a crash on `UnlockManager` scan.
- **A mod's `.tres` referencing a vanilla script whose uid changed.** This is M9's rule failing in practice. Detect and log clearly rather than surfacing as a generic load error.
- **Recipe inversion (M8):** a vanilla processor whose scene array and the new tag index disagree during the transition. Assert-free migration — build from the index, log the diff once, delete the array in a follow-up.
- **Save with mods, load in vanilla:** already works for modules; confirm for jobs (`JobDataRegistry` returns null → job dropped), resources, and pawn scenes.
- **M11 on a pre-WI-46 save:** absent `meta.mods` must read as "no mods", not as "mods missing", or every legacy save warns.
- **M11 with a mod present at a different version:** warns, and the player can still proceed. Confirm the warning names the mod and version rather than just counting.

## Verification

1. **Spike:** exported build loads a `.pck` containing one script and one `.tres`; the `.tres`'s script reference resolves.
2. **Stage 2 regression:** save a mature station, apply stage 2, load the *pre-refactor* save → byte-identical world state. This is the acceptance test for the whole stage; a diff of the two save files should be empty.
3. **Ordering:** a processor mid-batch with a queued recipe, a deconstructing module with reconfigured storage, and a fuel generator mid-burn (WI-45 A3) all survive save/load after stage 2. These are the three constraints most likely to break.
4. **Stage 3:** disable a mod that owns a save section, load, save, re-enable, load → state intact.
5. **M11:** save a station built largely from a mod's modules, disable the mod, open the slot browser → the row is marked before loading. Load anyway → warning names the mod, the game runs, the modded modules are gone. Re-enable, load the *same* save → the station is whole again and the mod's section survived the round trip.
6. **The sample mod is the real test.** Ship one that exercises every path: a new resource with variance, a processor recipe attached to a *vanilla* refinery by tag, a new module with a new component that saves state, a new job type with a driver, a tech node granting the module, a new build category, a ship variant, a pawn kind. If the sample mod needs a single core edit, this WI isn't done.
7. **Fail-soft:** a mod with a malformed manifest, a mod with a `.tres` referencing a missing script, and two mods with colliding ids each produce a clear message and a running game.
8. **GUT:** full suite green (505 baseline at WI-45) plus the new registry suites.
9. **Regression:** build → deconstruct → collect pile; a trade caravan; a turbolift ride; a full raid. Stage 2 touches the persistence of nearly every component these depend on.

## Open questions

- **Autoload ordering.** `ModManager` must run before `Global`, but `Global` is where every manager registers. Confirm a plain autoload ordered first is sufficient, or whether the packs need mounting even earlier (a `--main-pack` style bootstrap, or from the main menu before the scene swap).
- **Mod list UI.** WI-36 built the main menu and settings shell. A mods page belongs there, but it's unscoped — this WI assumes at minimum a read-only list with load status and errors.
- **`ResourceScanner` cost.** 12 roots × N mods, each `ResourceLoader.load`ed at startup. Fine at vanilla scale; unmeasured at 30 mods. Worth a number before stage 4.

## Related

- [[WI-44_Job_System_Refactor]] — the extension-point pattern this WI generalises; `JobDataRegistry` is the model for M1 and M3.
- [[WI-45_Save_System_Audit]] — the component-by-component field sweep M2 refactors, and the source of the ordering constraints it must preserve. Its `test_component_persistence.gd` is stage 2's safety net.
- [[WI-43_Build_Menu]] — introduced the `UICategory` enum M5 converts.
- [[WI-39_Power_Registry]] — precedent for replacing implicit discovery with explicit registration, which is M3's shape.
- [[01_Technical_Specification]] — needs a modding section once stage 3 lands.
