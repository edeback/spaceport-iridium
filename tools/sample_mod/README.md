# Sample mod (WI-47)

A **separate Godot project** that builds a mod `.pck` for Spaceport Iridium. It
started life as the WI-47 M9 spike fixture and is kept as the living example the
WI asks for — if this mod ever needs a core edit to work, WI-47 isn't done.

`tools/` carries a `.gdignore`, so the game's editor never scans this project and
none of it ships in the game's export. Open it on its own (`--path
tools/sample_mod`) or not at all.

## Why it is deliberately bare

It contains only the mod's own files — no copy of the game's scripts. That is the
whole point: anything it resolves at runtime provably came from the *game's*
`res://`, not from a vanilla script the pack happened to carry along. Hand-written
`.tres` files reference vanilla scripts by uid and path; they don't resolve inside
this project, and they don't need to.

A real mod author would rather work against an SDK copy of the game project for
editor support. That's a stage-1 deliverable, not something this fixture needs.

## What it exercises

| File | Covers |
| --- | --- |
| `mods/spikemod/mod.json` | manifest; a plain file survives the pack and is readable with `FileAccess` |
| `data/resources/glimmerite.tres` | vanilla `ResourceData` script referenced by uid + path |
| `data/resources/glimmerite_stale_path.tres` | correct uid, deliberately wrong path — proves uid wins |
| `data/resources/shimmer_default.tres` | a resource whose own script is a mod script, `script_class` hint and all |
| `data/jobs/polish_glimmerite.tres` | vanilla `JobData` whose `driver: Script` is a mod script — the WI-44 shape |
| `scripts/shimmer_instance_data.gd` | mod script extending a vanilla `class_name`; `get_script().new()` instead of a self-reference |
| `scripts/job_driver_polish.gd` | mod `JobDriver`, no `class_name` |
| `scripts/mod_helper.gd` + `mod_consumer.gd` | `preload()` between mod scripts, and into vanilla — the substitute for class names |
| `scripts/class_name_user.gd` | **negative control**: naming a mod `class_name` must fail to compile |
| `scenes/spike_scene.tscn` | mod root script + vanilla component script + `ExtResource` to a mod `.tres` |
| `/data/resources/test_resource.tres` | **negative control**: an attempt to shadow a vanilla file, which `replace_files = false` must defeat |

Stage 4's extension points, added once all five landed:

| File | Covers |
| --- | --- |
| `data/modules/shimmer_collector_mdata.tres` + `scenes/shimmer_collector.tscn` | a modded **module**: an inherited scene off `module_base.tscn` plus one added component. Inheritance is why this file is six lines — the base carries sprite, footprint, path, structure and construction |
| `scripts/shimmer_collector_component.gd` | **M2**: a mod component that owns save state, via `save_key()` + `get_save_data()`/`load_save_data()` |
| `data/build_categories/glimmer.tres` | **M5**: a mod **build-menu category**, slotted at `sort_order = 55` between vanilla Mining (50) and Storage (60) |
| `data/recipes/polish_glimmerite_recipe.tres` | **M8**: a recipe that attaches itself to the **vanilla ore processor** by declaring `processor_tags = ["Refinery"]` — no replacement refinery scene, so it can't conflict with another mod doing the same |
| `data/ships/glimmer_corsair.tres` | **M7**: a raider variant in the wave pool |
| `data/pawns/glimmer_hand.tres` | **M10**: a crew kind in the hire pool, at a 1.4× price band |
| `data/unlocks/glimmer_tech.tres` | a **tech node** on the vanilla `industry` tree granting the mod's module |
| `data/resources/glimmerite.tres` | **M4**: `instance_data_script` pointing at the mod's own `ItemInstanceData` subclass, so its variance rebuilds on load |

## The acceptance test

WI-47's bar is not "these features exist" — it is that a mod exercising all of them
needs **zero core edits**. Verified 2026-08-03 by a temporary probe, 22 checks
across two halves:

- **Build**: the mod loads with no problems; its resource, module, job type, ship
  variant, pawn kind, build category and tech node all register; its recipe shows
  up in the vanilla refinery's selector next to the five vanilla ones; the module
  starts locked, unlocks by research, places, and its mod component writes its own
  save block.
- **Restore**: the save loads, the module comes back, and the mod component's
  state (`collected = 41.5`) survives the round trip.

`git status` after the run showed **no file changed outside this directory**.

The mod id is still `spikemod`, from its origin as the M9 spike fixture. Renaming
it would mean rewriting every `spikemod.*` content id and the mount path, so it is
left alone unless there is a reason to churn them.

## Building it

```
godot --headless --path tools/sample_mod --export-pack "Mod Pack" spikemod.pck
```

`Mod Pack` exports GDScript as text; `Mod Pack Binary` exports it as binary
tokens (`.gdc` + a `.gd.remap`). Both are supported and the M9 spike verified
both — keep both presets so a regression in either is visible.

## Installing it

```
user://mods/spikemod/mod.json     <- copy of mods/spikemod/mod.json
user://mods/spikemod/spikemod.pck
```

The manifest sits **outside** the pack on purpose. `ProjectSettings.load_resource_pack()`
has no counterpart — a pack cannot be unmounted — so every decision about whether
to load a mod at all (id collisions, missing dependencies, load order) has to be
made before mounting, from a file that is readable without mounting.

On Windows `user://` is `%APPDATA%/Godot/app_userdata/Spaceport Iridium/`.
