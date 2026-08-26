# WI-66 — Star and Planet Variations

> **STATUS: COMPLETE (2026-08-24).** Shipped as designed apart from the seven deviations below. Six files changed, eighteen new (ten of them `.tres`). **1522 GUT tests, all green** (+40, `test_star_systems.gd`) — the suite was green at 1482 before this item, so nothing regressed. Verified further by a **24-check headless probe** green on repeated runs, and **21 screenshots** driven into each state. Save is backward-compatible and `SAVE_VERSION` did not move.
>
> **Deviations from the design below:**
> 1. **`planet_cutoff` shipped as `planet_coverage`, and both it and `planet_cloudiness` are inverted on the way to the shader.** All four uniforms the design names — `cloud_cover`, `land_cutoff`, `river_cutoff`, `lake_cutoff` — are consumed as `step(uniform, noise)`, so a *higher* value means *less* of the thing. Every one of them runs backwards from its name. `StellarBackground._map_threshold()` is the single place that inverts; §Verification's screenshot is what caught it.
> 2. **The three normalised planet factors are normalised, which the design left implicit.** §4 listed `planet_cloud_cover` / `planet_cutoff` / `planet_noise_size` as though they were absolute. They ship as 0–1 factors mapped into each layer's own band, because the vendored per-layer values are tuned *against each other* (`Rivers` draws land noise at `size` 4.6 and clouds at 7.3) and an absolute number would have to be per-layer — which would put variant-shaped data in the save file. The cost is that retuning a band shifts an existing save's cloudiness slightly; the palette, which is most of the look, is stored absolutely.
> 3. **The generator insets every hue band by 2°** (`HUE_BAND_MARGIN`). Quantising to 8 bits moves a hue by up to ~1.4°, so generating right up to a band edge produces a colour that leaves the band on its way to the shader. The realism sweep caught it immediately — a water stop at hue 184.7 against a floor of 185. Generation keeps its distance rather than the rule being widened.
> 4. **`LEGACY_SEED` is 19660929, and it was chosen by search, not picked.** The design says the legacy sky should land somewhere recognisable; an arbitrary constant does not. The shipped seed produces a yellow star (`ecbd38` against the vendored `ffd832`) over a green-and-blue Rivers planet with river blue `5193a6` (vendored: `4fa4b8`) — a close match for the sky the game had before this item. **It is pinned in a test**, because the constant is chosen against a specific *sequence* of rng calls: inserting a roll anywhere upstream lands it somewhere else entirely.
> 5. **`StellarBackground.star_layer`/`planet_layer` are typed `Node2D`, not `Parallax2D`**, and there is an `is_preview` flag. Both exist so the contact-sheet cheat drives the real applier — a sheet that used a second code path would be verifying something other than the game.
> 6. **The star always renders larger than the planet, and that is now an invariant with a test.** The design treated apparent size as a free variation axis; it is not. **The station sits out at the asteroid belt, far from both bodies** — the planet is the nearer of the two, but a star is larger by orders of magnitude, so at that distance the star is what dominates the sky, and a large planet reads as *orbit*, which is the wrong place. Every `PlanetVariant` therefore authors `scale_range = (1, 1)` (60–100px) against a smallest-possible star of 120px, and `test_star_systems.gd` asserts over the **bands** that the smallest star any class can roll still out-sizes the largest planet any variant can. One consequence: at scale 1, `pixels` is both the apparent-size axis and the resolution axis, so a smaller planet is necessarily a chunkier one — which reads correctly as less detail at greater distance, but the two can no longer be varied independently.
> 7. **`STAR_PLANET_CLEARANCE` — the planet's offset band is pushed right of the star's disc.** The two authored bands overlap on their own: a hot class reaches a 300px disc, and starting from the right of the star band that runs into the left of the planet band. See the screenshot note below. A small star leaves the authored band untouched; only a large one moves it, and only by as much as it takes. Measured against the **disc**, not the corona — the flare layer is sparse arcs over transparency, and a planet catching one of those reads as weather rather than as a mistake.
>
> **What the screenshots caught that the probe could not:**
> - **The first contact sheet was a field of featureless overcast white balls**, and that is deviation 1: the "clear world" roll was producing *total* whiteout because `cloud_cover` is a threshold. Every headless check passed the whole time. This is the defect the item exists to have found.
> - The star-tint claim (§3) is visibly true and worth the lerp: a red dwarf's ocean world reads warm across the clouds and land, a blue giant's reads cold. Side-by-side it is obvious; in a data dump it would be four hex codes.
> - **A fully lit planet drawn on top of the star's face.** Found by forcing the worst corner of the two offset bands — and it turned out to be reachable by the generator, not just by the forcing. It reads as a rendering error rather than as a transit. Deviation 7 is the fix; the re-check searched **40,000 real rolls** for the tightest pairing and found the gap pinned at exactly the 40px floor, so the rule binds and nothing gets closer.
> - **The first pass had the planet out-sizing the star, and that was wrong** — see deviation 6. It looked fine in isolation, which is exactly why it survived the first screenshot pass: the shot answers "is this attractive", and the actual question was "does this say we are out at the belt". A composition can be pleasant and still describe the wrong place.
>
> **What a pixel comparison settled that neither could:** the save/reload pair differs in 1497 pixels of 2,073,600 (0.07%), confined to a bounding box of x=289–1027, y=178–579 — exactly the two bodies and no UI. That is the shaders' animation clock advancing between two shots taken seconds apart, not the sky changing. Deliverable 2 holds.
>
> **Two vendored bugs are documented but NOT fixed**, because `assets/external/` stays unmodified: `Star.randomize_colors()`'s array-length mismatch, and `Star._set_colors()` reading a `colorramp` uniform that does not exist. Nothing in the project calls either.
>
> **Left open on purpose:** the New Game preview (§Open questions) is not built; `dry_terran`'s weight has not been played against the other three; and the offset bands in `StarSystemGenerator` are composition constants tuned from one contact sheet, not from play.
>
> [[01_Technical_Specification]] gains §1.17a for this item and a `system` entry in §1.17's section list. **This doc has NOT been moved to `Completed/`** — that is the author's call once the work is verified.

## Goal

Every run currently opens on the **same sky**: the unmodified `Star.tscn` and `Rivers.tscn` from Deep-Fold's Pixel Planet generator, at their authored defaults, instanced straight into `main.tscn`. Nothing in the project calls a single one of the generator's setters — `set_pixels`, `set_seed`, `set_light`, `randomize_colors` have **zero call sites** outside `assets/external/pixel_planets/`.

Four deliverables:

1. **A generated star and planet per run**, rolled when a new game starts.
2. **The same sky on reload** — a saved game comes back looking exactly as it did.
3. **Realistic colour** — no green stars, no purple stars, water in some shade of blue.
4. **Four planet types**, not one: `Rivers`, `LandMasses`, `IceWorld`, `DryTerran`, each with varied parameters rather than its shipped defaults.

There is **no gameplay impact**. This is a visual item, and it is deliberately also the seam that **Stars, Planets and Other Stations** ([[New Work for Phase 4]]) needs — see §11.

## Design

### 1 — What the vendored generator gives you, and the three parts of it you must not use

`assets/external/pixel_planets/` is **vendored third-party code and stays byte-for-byte unmodified.** Everything this item adds lives in the project's own tree and drives those scenes from outside. That is not fussiness: the vendored scripts are untyped GDScript against a project that runs `untyped_declaration` / `unsafe_property_access` / `unsafe_method_access` as warnings, and the moment we start editing them we own that whole file's warning surface and lose the ability to re-pull the upstream asset.

Each planet type is a `Control` running a script extending `StellarObjectVisual`, with one `ColorRect` child per rendering layer, each carrying its own `ShaderMaterial`. The base class offers `set_pixels` / `set_light` / `set_rotates` / `set_dither` / `set_seed` / `set_colors` / `randomize_colors`. **Three of those are traps:**

- **`randomize_colors()` is the wrong tool for this item and, on the star, is outright broken.** It builds a palette from `_generate_new_colorscheme`, an arbitrary cosine-hue generator, which produces exactly the green and purple stars deliverable 3 forbids. Worse: `Star.randomize_colors()` assembles a **7-element** array and `Star.set_colors()` slices it `(0,1) / (1,6) / (6,10)` — that hands **5** colours to a `uniform vec4 colors[4]` and **1** colour to a `uniform vec4[2] colors`. Both are silently wrong at runtime. Nothing in the project has ever called it, so nobody has noticed.
- **`set_seed()` has a hidden global-RNG side effect.** `Rivers.set_seed()` and `LandMasses.set_seed()` both call `randf_range(0.35, 0.6)` and write it to `cloud_cover`. Calling it makes generation non-reproducible and silently overwrites an authored cloud cover, which breaks deliverable 2 in a way that only shows up on a reload.
- **`Star._set_colors()` is dead code that reads a uniform that does not exist.** It does `$Star.material.get_shader_parameter("colorramp").gradient` — `Star.gdshader` has no `colorramp`, only `colors[4]`. The four `Gradient`s `Star._ready()` builds exist solely to feed it. Ignore all of it; and note that `Star.gd` overrides `_ready()` **without calling `super()`**, so a star never records `original_colors` and you cannot hang anything off the base `_ready`.

**The rule this item follows:** the applier writes `colors` and `seed` **directly onto each layer's material**, and calls the vendored setters only for the ones that are pure pass-throughs with geometry side effects we want — `set_pixels`, `set_light`, `set_rotates`, `set_dither`.

`set_pixels` is the one that genuinely must go through the vendored path. It sets the shader's `pixels` uniform **and** resizes the `ColorRect`, and on the star it additionally re-sizes and re-offsets `$Blobs` and `$StarFlares` by `relative_scale`. Writing `pixels` on the material alone leaves the rects stale and the flares mis-centred.

### 2 — Realism is authored data, not a constrained random hue

Deliverable 3 cannot be met by clamping a random hue, because "realistic" is not one band. Stars follow the blackbody locus — red → orange → yellow → white → blue-white — and *skip green entirely*, which is why a green star is impossible rather than merely rare. Water is blue. Clouds are white to grey. Land is the only genuinely free axis.

So the palettes are **authored `.tres`, scanned like every other content kind**, and the generator's job is to pick one and jitter it — not to invent one.

`data/star_classes/star_class.gd` (`class_name StarClass`, extends `Resource`):

| field | what |
|---|---|
| `id: StringName` | `&"yellow"`, `&"red_dwarf"`, … |
| `display_name: String` | "G-class yellow" — what the debug dump prints |
| `spectral_class: StringName` | `&"G"` |
| `temperature_k: int` | the physical anchor the ramp is authored against, and the second half of the dump line |
| `ramp: Gradient` | core → rim, sampled to 4 stops for `Star.gdshader`'s `colors[4]` |
| `weight: float` | pick weight |
| `size_range: Vector2`, `flare_range: Vector2`, … | the per-class knob bands (§5) |

Six ship, and the weighting is a **deliberate departure from astrophysical frequency**: real space is ~76% M-dwarfs, which would make three runs in four open on a red sky. Weighted for variety instead, with O/B rare because a blue giant should feel like a find.

| id | class | K | ramp (core → rim) | weight |
|---|---|---|---|---|
| `blue_giant` | B | 15000 | `f2f6ff` `a8c8ff` `5b8fe0` `1b3a7a` | 1 |
| `white` | A | 8500 | `ffffff` `dfe8ff` `9fb4d8` `3c4a72` | 2 |
| `yellow_white` | F | 6800 | `fdffe8` `ffeeae` `e0b95e` `7a5a1e` | 3 |
| `yellow` | G | 5800 | `f5ffe8` `ffd832` `ff823b` `7c191a` | 4 |
| `orange` | K | 4500 | `fff0d8` `ffb44a` `e0662a` `6b1e12` | 4 |
| `red_dwarf` | M | 3200 | `ffd9c0` `ff8a5c` `c93c28` `4d1010` | 3 |

**The `yellow` ramp is the vendored `Star.gd` `starcolor1` verbatim.** That is on purpose: it is the pin that says our applier reproduces a look the asset's author already signed off on.

The star's other two layers derive from the ramp rather than being authored twice — matching exactly what the shipped `Star.tscn` does: `Blobs.colors = [ramp[0]]`, `StarFlares.colors = [ramp[1], ramp[0]]`.

**The vendored "blue star" ramp is why this section exists.** `Star.gd`'s `starcolor2` is `f5ffe8 / 77d6c1 / 1c92a7 / 033e5e`. Those middle two measure at **hue 167° and 189°** — green-cyan and cyan. It is a teal star, and teal stars are not a thing. Shipping the asset's own second palette would have failed deliverable 3 on its own.

### 3 — Palette *roles*, which is what lets one model cover four differently-shaped variants

The four planet scenes have different layer counts, different node names, and different `colors[]` array lengths per layer — and one of them packs **two** conceptual ramps into a single uniform:

| variant | scene | layer node | shader | colours |
|---|---|---|---|---|
| `rivers` | `Rivers.tscn` | `Land` | `LandRivers` | **6** = 4 land + 2 river |
| | | `Cloud` | `Clouds` | 4 |
| `land_masses` | `LandMasses.tscn` | `Water` | `PlanetUnder` | 3 (the ocean — this layer is the whole sphere) |
| | | `Land` | `PlanetLandmass` | 4 |
| | | `Cloud` | `Clouds` | 4 |
| `ice_world` | `IceWorld.tscn` | `Land` | `PlanetUnder` | 3 (the ice sheet) |
| | | `Lakes` | *inline* | 3 |
| | | `Clouds` | `Clouds` | 4 |
| `dry_terran` | `DryTerran.tscn` | `Land` | *inline* | 5 |

A four-way `match` on the variant id would work and is exactly the kind of dispatch table WI-47 deleted three of. Instead, four **roles** — `SURFACE`, `LAND`, `LIQUID`, `CLOUD` — and a layer is an ordered list of `(role, count)` **segments**:

```
rivers      Land   → [LAND×4, LIQUID×2]      Cloud  → [CLOUD×4]
land_masses Water  → [LIQUID×3]   Land → [LAND×4]    Cloud  → [CLOUD×4]
ice_world   Land   → [SURFACE×3]  Lakes → [LIQUID×3] Clouds → [CLOUD×4]
dry_terran  Land   → [SURFACE×5]
```

`data/planet_variants/planet_variant.gd` (`class_name PlanetVariant`) carries `id`, `display_name`, `scene: PackedScene`, `layers: Array[PlanetLayerSpec]`, and the per-variant knob bands; `planet_layer_spec.gd` (`class_name PlanetLayerSpec`) is `node_name: StringName` plus `segments: Array[PlanetPaletteSegment]`, and a segment is `role` + `count`.

Three things fall out of this that are worth the extra resource type:

- **"Water is blue" becomes one assertion over one role**, testable across every variant and every future one, instead of four hand-written per-variant checks.
- **`dry_terran` has no `LIQUID` role at all**, which is exactly why the realism test has to be per-role rather than per-planet.
- **A mod adds a fifth planet type as a `.tres` drop with no core edit** — the WI-47 bar, and the same bargain `SpaceBodyProfile` made in WI-61.

Roles are generated, not authored, and each has its own rule:

- **`LIQUID`** — hue **190–240°**, saturation 0.35–0.75, darkening down the ramp. This *is* deliverable 3's water clause. `ice_world` lakes narrow to 185–215° and lift value.
- **`LAND`** — the free axis, but rolled from a small set of **biome hue bands** rather than the whole wheel, so it reads as deliberate: temperate green (75–140°), arid ochre (30–55°), rust (10–25°), tundra grey-blue (200–220°, low saturation).
- **`SURFACE`** — the whole-sphere ramp: ice (near-white with a blue cast) for `ice_world`, ochre/rust for `dry_terran`.
- **`CLOUD`** — near-white → grey-blue, always, because real clouds are.

**The star tints the planet.** `CLOUD`'s highlight and the top of `LAND`/`SURFACE` shift a few percent toward the star ramp's core colour. It costs one lerp and it is the difference between "a star and a planet" and "a star **and its** planet" — a red-dwarf system should read warm all the way across.

**`light_origin` is derived from the two bodies' actual screen positions**, not left at the authored `(0.39, 0.39)`: `0.5 + (star_pos - planet_pos).normalized() * 0.35`, computed **once at build time**. Not per frame — the two bodies sit on `Parallax2D` layers with different `scroll_scale` (0.1 vs 0.15), so their relative offset drifts as the camera pans, and a per-frame recompute would make the terminator swim across the planet while you scroll the station.

### 4 — `StarSystemData` is the rolled *result*, and the result is what gets saved

Two options, and the choice matters:

- **Save the seed**, re-derive everything. One integer, and deliverable 2 is free — until the first patch that retunes the generator, which silently repaints the sky of every existing save.
- **Save the resolved parameters.** Larger block, immune to generator changes.

**Save the resolved parameters**, and carry the seed alongside as provenance. This is also what the codebase already does everywhere it rolls something: an asteroid saves its rolled contents and richness, not its seed; a `HireCandidate` saves its rolled name, skills and traits, not its seed. The standing "derived state is re-derived, never saved" rule is about state derivable from *live* state — a one-time roll is not derivable from anything.

`scripts/utility/star_system_data.gd` (`class_name StarSystemData`, extends `RefCounted`, `to_dict()` / `from_dict()`) — the `HireCandidate` shape exactly:

```
seed: int                       # provenance only; nothing re-derives from it
star_class_id: StringName
star_ramp: PackedColorArray     # 4, post-jitter
star_pixels: int                # shader resolution
star_scale: int                 # integer magnification (§6)
star_offset: Vector2
star_noise_size / star_time_speed / star_circle_amount / star_storm_width: float
planet_variant_id: StringName   # &"" is tolerated and means no planet (§Edge cases)
planet_palette: Dictionary[StringName, PackedColorArray]   # role -> ramp
planet_seed / planet_rotation / planet_cloud_cover / planet_cutoff / planet_noise_size: float
planet_pixels: int, planet_scale: int, planet_offset: Vector2
```

Colours round-trip as `Color.to_html(true)` strings — lossless, and readable in the save file, which matters when the only way to debug this feature is to look at it.

### 5 — `StarSystemGenerator`: pure, seeded, and the axes it varies

`scripts/utility/star_system_generator.gd` — all static, no `Global`, no `SignalBus`, no nodes, so GUT can hammer it. `generate(seed: int) -> StarSystemData`.

**Every roll goes through one `RandomNumberGenerator` instance seeded from `seed`. The global RNG is never touched** — which is the other half of why §1 forbids `set_seed()`.

What varies, beyond class and variant:

| axis | band | why |
|---|---|---|
| star ramp jitter | hue ±6°, value ±8% | two G-class systems are not the same yellow |
| star `size`, `circle_amount`, `circle_size`, `storm_width` | per-class | surface churn and flare character |
| planet `rotation` | 0 – 0.6 rad | axial tilt |
| planet `cloud_cover` | 0.30 – 0.62, with a ~15% "clear world" roll to ~0.15 | some planets should be nearly cloudless |
| `land_cutoff` / `river_cutoff` / `lake_cutoff` | per-variant | land-to-water ratio |
| noise `size` | per-variant | continent scale |
| `time_speed` | ±20% of authored | so two worlds don't drift in lockstep |
| `pixels` + integer `scale` | see §6 | apparent size |
| screen offset | within an authored band per layer | so the planet isn't always bottom-right |

`OCTAVES` stays authored. It is a cost knob as much as a look knob and the authored values are tuned.

### 6 — Apparent size: vary `pixels`, and keep `scale` an integer

`set_pixels(n)` sets the shader's `pixels = n` **and** sizes the `ColorRect` to `n × n` — one shader pixel per screen pixel at scale 1. On-screen size is then `n × node.scale`.

- `pixels` is the art's chunkiness. `Star.gdshader` hints `hint_range(10,100)`; the planet shaders the same. Stay inside 60–100.
- `scale` **must be an integer**. A pixel-art shader at scale 2.4 renders uneven pixel sizes — some 2px wide, some 3 — and it reads as a rendering bug, not as variety. The star already sits at `scale = 2` in `main.tscn`.

`pixels ∈ [60,100] × scale ∈ {2,3}` gives 120–300px of apparent diameter, which is plenty of range against a 1080p viewport, and both parallax layers already carry `texture_filter = 1` (nearest) so it stays crisp.

### 7 — `StellarBackground`: the node that mounts and applies

`objects/stellar_background.gd` (`class_name StellarBackground`, extends `Node`), mounted under `BackgroundLayers` with two `@export` `NodePath`s to the existing `LocalStar` and `LocalPlanet` `Parallax2D` nodes — the way `AsteroidManager` already takes `start_point` / `end_point` / `asteroid_layer`.

On `_ready`: read `Global.get_star_system()`, instantiate `Star.tscn` and the chosen planet variant's scene, `add_child` them, then apply.

Registers itself as `Global.stellar_background`. It is **not** a manager — no tick, no signals, no save section of its own — but the cheats need a handle on it, and `Global` already carries four non-managers (`ui_in_game`, `ui_main`, `tilemap`, `cheats`) for exactly that reason. A `Groups` entry for a single always-present node would be worse.

**Every `ShaderMaterial` is `duplicate()`d before a single parameter is written.** A `SubResource` inside a `PackedScene` is **shared across every instantiation of that scene** unless `resource_local_to_scene` is set — and `Star.tscn`'s three materials and every planet variant's are plain sub-resources. Two consequences, both real:

- Godot caches the `PackedScene`, so `SaveManager.load_slot`'s `reload_current_scene()` hands the *same* material objects to the new tree. Any parameter we do not overwrite on every apply leaks from the previous run into the next one — and we deliberately do not write every parameter on every variant.
- The moment anything else instantiates one of these scenes (a New Game preview — §Open questions), it would fight the live game's sky.

Duplicating closes the whole class of bug for one line. The same applies to any `Gradient` read out of a `StarClass` `.tres`: duplicate before jittering, or the jitter accumulates into the shipped resource for the rest of the session.

Apply order is **instantiate → `add_child` → apply**, so the vendored `_ready` has run before we write anything.

### 8 — `main.tscn`, and the save

**`main.tscn`:** delete the `Star` and `Planet` instances under `LocalStar` / `LocalPlanet`, add the `StellarBackground` node. The two `Parallax2D` nodes keep their `scroll_scale`, `texture_filter` and `follow_viewport` exactly as they are; only their children become runtime-built. The planet's scene cannot be authored in the file any more because it is one of four.

**Save: an envelope-level `"system"` block, beside `"difficulty"` and `"station"` — not a registered section.** Same shape of thing: chosen before the run starts, never mutated by any system, so there is no live owner to ask for it. And it must be **staged on `Global` before the scene swap**, exactly as difficulty and the station name are, because `StellarBackground._ready` reads it and `_apply_pending_load` is deferred until the whole tree is up — without staging, a load renders one frame of the wrong sky and then swaps.

Four touch points, and the third is the one that bites:

1. `_collect_sections()` writes `"system": Global.get_star_system().to_dict()`.
2. `SaveManager.read_star_system(data)`, static, mirroring `read_difficulty` / `read_station_name`; called from `stage_load`.
3. **`_apply_sections()` must add `"system": true` to its `claimed` dict.** Anything unclaimed is filed as a disabled mod's data and handed straight back out on the next save. An unclaimed `"system"` would round-trip forever while the game rendered a default sky, and **nothing would error** — the exact failure mode the comment on that dict already warns about for `"station"`.
4. `Global`: `star_system`, `stage_star_system()`, `get_star_system()` (generating on first read if never staged), and a line in `clear_staged_start()`.

**`SAVE_VERSION` does not move.** A save with no `"system"` key generates from a fixed `LEGACY_SEED` constant — so a pre-WI-66 save gets one specific sky, permanently and consistently, rather than a fresh one every load. It is not the sky it had; that is a deliberate one-time change, and it is the same bargain WI-61 struck when pre-WI-61 bodies all restored as belt asteroids.

Booting `main.tscn` directly from the editor takes the same path, which means **dev boots always get the same sky** — the counterpart to difficulty falling back to Normal, and useful: a background that changed every time you hit play would make screenshot comparison impossible.

`MainMenu`'s New Game path stages a freshly rolled system alongside the difficulty, name and crew it already stages. `NewGameSetup` is not involved — it reports choices, and the system is not a choice (§Open questions).

### 9 — Time, pause, and why the sky keeps moving

`StellarObjectVisual._process` accumulates **real-time** delta. Leave it.

The project's rule is that gameplay animations follow sim speed via `animation_speed()` and the `sim_animation` group, while UI stays real-time. A background body ten canvas layers behind everything, with no collision, no click target and no gameplay effect, is on the UI side of that line. Concretely: **do not join `sim_animation`, and do not take a pause hold.** The onboarding conversation holds the sim stopped for its whole run (WI-63) and a slowly churning star behind it is the thing that keeps a paused game from looking crashed.

The rate is imperceptible anyway — `time_speed` 0.05–0.1, multiplied down by a further 0.005–0.02 in `update_time` — so nobody will read the planet as "still spinning while paused". Say it in a comment on the node, because the next reader will reach for `sim_animation` on reflex.

### 10 — Cheats

Per the standing rule, each emits a `station_alert` "CHEAT: …":

- `reroll_system(seed := 0)` — regenerate and re-apply live (0 = random). The one that makes this item testable at all.
- `set_star_class("red_dwarf")` / `set_planet_variant("ice_world")` — pin one axis, re-roll the rest.
- `dump_system()` — the full `StarSystemData` as text: class, `display_name`, `temperature_k`, variant, every rolled number and every palette ramp.
- `system_contact_sheet(count := 24)` — arrange `count` generated systems in a grid for one screenshot (§Verification).

Ids pass as plain `String`s, never `&"…"` — Panku's `Expression` rejects StringName literals.

### 11 — What this is a prerequisite for

[[New Work for Phase 4]]'s **Stars, Planets and Other Stations** wants a system to carry ore-type richness feeding the spawned asteroids, and a space temperature that makes hotter systems demand different station layouts. `StarSystemData` is where both land, and `StarClass.temperature_k` is already the physical quantity the second one wants.

**Nothing speculative ships here.** No empty `ore_richness` field, no inert `space_temperature`. `temperature_k` earns its place today as the anchor the ramps are authored against and the second half of what `dump_system()` prints; everything else is added by the item that uses it.

## Files to touch

**New**
- `data/star_classes/star_class.gd` (`class_name StarClass`) + six `.tres`
- `data/planet_variants/planet_variant.gd` (`class_name PlanetVariant`), `planet_layer_spec.gd` (`class_name PlanetLayerSpec`), `planet_palette_segment.gd` (`class_name PlanetPaletteSegment`) + four `.tres`
- `scripts/utility/star_system_data.gd` (`class_name StarSystemData`)
- `scripts/utility/star_system_generator.gd` (`class_name StarSystemGenerator`)
- `objects/stellar_background.gd` (`class_name StellarBackground`)
- `tests/unit/test_star_systems.gd`

**Changed**
- `scripts/utility/content_paths.gd` — two kinds (`STAR_CLASSES`, `PLANET_VARIANTS`) and their `KINDS` entries
- `scripts/managers/global.gd` — `star_system`, `stellar_background`, `stage_star_system` / `get_star_system`, `clear_staged_start()`
- `scripts/managers/save_manager.gd` — `_collect_sections`, the `claimed` dict, `read_star_system`, `stage_load`
- `ui/menus/main_menu.gd` — stage a rolled system on New Game
- `main.tscn` — drop the two authored instances, add `StellarBackground`
- `scripts/utility/cheats.gd` — the four cheats

**Untouched, deliberately:** everything under `assets/external/pixel_planets/`.

Run `filesystem_manage(op="scan")` after the new `class_name` files or none of them will resolve.

## Implementation order

1. **`StarSystemData` + `StarSystemGenerator` + `test_star_systems.gd`**, with the two resource types and all ten `.tres`. Pure, fully tested, nothing rendered yet. The realism sweep (§Verification) is written **here**, before anything can look at it and call it fine.
2. **`StellarBackground` + the `main.tscn` change**, applying a hardcoded `LEGACY_SEED`. **The sky must look substantially like it does today at this step** — the `yellow` ramp is the vendored `starcolor1` and `rivers` is the current planet, so this is the step that proves the applier drives the vendored shaders correctly rather than that the generator has taste. Screenshot before and after.
3. **Generation on New Game**: `Global` staging, `MainMenu`, and the `reroll_system` cheat. Now every run differs.
4. **Save** — write, read, stage, and the `claimed` entry. Save/reload must be pixel-identical, and a pre-WI-66 save must load.
5. **The other three variants**, the star tint on the planet, and the derived `light_origin`.
6. **The remaining cheats, the contact sheet, and the look pass.** Colour bands are a hypothesis until 24 of them are on screen at once.

## Edge cases

- **The unclaimed-section trap (§8.3).** The single most likely way to ship this half-working with no error anywhere.
- **No planet.** `planet_variant_id == &""` must leave the slot empty rather than crash. Nothing rolls it today; the follow-on item's "planet (optional)" does, and tolerating it now costs one guard.
- **A `.tres` naming a node that isn't in its scene**, or segment counts that don't sum to the shader's array length. Silent at runtime — Godot pads or truncates the uniform. This is precisely the bug already sitting in `Star.randomize_colors()`, which is the argument for the sweep in §Verification.
- **A missing or empty `data/star_classes/`** (a mod mounting badly, an export filter mistake) must degrade to the legacy sky, not to a black screen or a crash on a weighted pick over an empty array.
- **Material sharing across a scene reload** (§7). Benign only as long as we overwrite every parameter we vary on every apply — and we do not, by variant. Duplicate.
- **`Star._ready()` does not call `super()`**, so `original_colors` is never populated on a star. Harmless today; do not build on it.
- **Fractional `scale`** (§6) — reads as a rendering defect, not as variety.
- **A very large `pixels` on a very large `scale`.** Three full-screen shader `ColorRect`s per planet plus three per star, redrawn every frame. Keep `pixels ≤ 100` (the shaders' own hint ceiling) and check the frame cost on the biggest combination before settling the bands.
- **Jitter accumulating into a shipped `Gradient`** if it is mutated in place rather than duplicated — invisible for one roll, obvious after `reroll_system` a dozen times.
- **A star ramp jittered across a hue boundary.** ±6° on an `orange` core at 30° is safe; the same jitter on a band edge is not. The realism sweep must run over the **post-jitter** colours, not the authored ones.

## Verification

1. **GUT** (`test_star_systems.gd`, pure — construct directly, never touch `Global`/`SignalBus`):
   - **Determinism:** `generate(n)` twice is field-for-field identical; `generate(n)` and `generate(n+1)` are not; and generating between them does not perturb the result (i.e. nothing reads the global RNG).
   - **Round-trip:** `to_dict()` → `from_dict()` is lossless, colours included, over a few hundred seeds.
   - **The realism sweep, over a few thousand seeds — this is deliverable 3 as an executable assertion:**
     - no star colour has hue in **(75°, 195°)** — green through cyan — or **(260°, 330°)** — violet through magenta, *unless* its saturation is below 0.15 (which is what exempts near-white cores like `f5ffe8`, whose hue reads as 86° at saturation 0.09).
     - **pin the vendored teal:** `77d6c1` and `1c92a7` (from `Star.gd`'s unused `starcolor2`) must **fail** that predicate. A realism test that would pass the palette we rejected is testing nothing.
     - every `LIQUID` colour has hue in **[185°, 245°]** and saturation above a floor.
     - every colour clears a value floor and a saturation ceiling — nothing black, nothing neon.
   - **Content sweep over every shipped `.tres`:** unique ids, positive weights, a non-null `scene`, a 4-stop ramp on every `StarClass`, and — via `PackedScene.get_state()`, the way `test_ui_theme.gd` already sweeps `.tscn` files without instantiating them — **every `PlanetLayerSpec.node_name` exists in its scene, and its segment counts sum to the length of that layer's authored `colors` array.** The one test that catches the `Star.randomize_colors()` class of bug.
   - **Bands:** `scale` is always an integer; `pixels` always within the shaders' `hint_range(10,100)`; every rolled float inside its authored band for the class/variant that was picked.
   - **`LEGACY_SEED` produces `star_class_id == &"yellow"` and `planet_variant_id == &"rivers"`** — the pin that a pre-WI-66 save lands somewhere close to where it started, and an early warning that a generator change moved it.
2. **Headless probe** (the standing fallback — a temporary autoload running a numbered checklist, deleted after). Headless **cannot verify anything this item renders**, so the probe's job is strictly the plumbing:
   - a new game stages a system; two new games in a row stage different ones.
   - save → reload → `Global.star_system.to_dict()` is **identical field for field**, which is deliverable 2.
   - a save file with the `"system"` key **removed** loads, produces the `LEGACY_SEED` system, and **writes the block back on the next save**.
   - a save carrying a genuinely unknown extra section still round-trips it, proving the `claimed` change didn't break the mod path.
   - `StellarBackground` mounts both bodies, and every layer's material is a **distinct object** from its scene's sub-resource (the §7 duplication, asserted rather than assumed).
   - `reroll_system` twice leaves the same number of children — no leaked instances.
3. **Screenshots — the whole item lives here.** This is a purely visual feature and headless renders no shaders at all, so a green suite proves only that the plumbing is sound:
   - **A 24-system contact sheet** from `system_contact_sheet()`. One picture answers "does this look like a real sky?", "is anything green or purple?", "is every ocean blue?" and "do 24 of these actually look different from each other?" — and it is the only artefact that can settle the colour bands.
   - **Step 2's before/after pair** — today's sky against the applier driving the same values. Any difference is the applier being wrong, and it will never be this easy to see again.
   - **All four variants at once**, each at two different `pixels`/`scale` combinations, checking that a bigger planet is chunkier rather than blurrier.
   - **A save/reload pair**, same frame of the same station, compared pixel-for-pixel.
   - **A red-dwarf system and a blue-giant system side by side**, for the §3 tint: the planet in each should visibly belong to its star.
   - **The terminator while panning** — two shots at opposite ends of a camera sweep, proving `light_origin` is fixed and the shadow does not swim (§3).
4. **By hand:** start four new games in a row. If two of them are hard to tell apart, or if any one of them looks *wrong* rather than merely different, the bands in §5 are wrong with every test green.

## Open questions

- **Should the New Game screen preview the system and let the player re-roll it?** Not in scope — the brief asks for generation, not for a choice. But it is cheap given this design (the generator is pure and `StellarBackground`'s apply is a function of `StarSystemData`), WI-59 already establishes per-card re-roll as the screen's idiom, and it is the only place the player could ever influence their sky. If it is added: the preview instantiates the same vendored scenes, which is the second half of why §7 duplicates materials.
- **Is the system worth surfacing anywhere the player can read it** — the minimap header beside the station name, or a Comms line? It becomes worth it the moment the follow-on item gives a system gameplay properties; today it would be a label with nothing behind it.
- **Weighting.** §2 weights for variety over frequency. If **Stars, Planets and Other Stations** later makes class a gameplay input, that trade needs revisiting, because "how often do I get a hard system" stops being a taste question.
- **Should `dry_terran` be rarer?** It is the only variant with no water and no clouds, so it is the most visually distinct and also the flattest. Roll it against the other three once the contact sheet exists.

## Related

- [[WI-61_Comets]] — `SpaceBodyProfile` is the direct precedent: per-kind knobs as scanned `.tres` rather than exports on a node, discovered through `ContentPaths`, with the rolled result saved rather than the seed. The files/order/verification shape here is deliberately the same.
- [[WI-59_Starting_Flow]] — `Global`'s staging pattern (`station_name`, `staged_crew`, `clear_staged_start`) and `CandidateRoller` as the precedent for extracting a roll into a pure, separately testable class.
- [[WI-37_Difficulty_Levels]] — the original "chosen before the run, staged on `Global`, written as an envelope field, never mutated" shape that `"system"` copies.
- [[WI-47_Modding_Support]] — `ContentPaths` and the scan-don't-register rule both new content kinds follow; a fifth planet type must be a `.tres` drop with zero core edits.
- [[WI-63_Tutorial]] — the onboarding holds the sim stopped for its whole run, which is the case §9's real-time decision is actually about.
- [[WI-49_UI_Design_System]] — not applicable, and worth saying so: `test_ui_theme.gd`'s override sweep is scoped to `res://ui/`, and every file this item adds sits under `data/`, `scripts/` or `objects/`. The palette rules here are about physical realism, not the console's amber budget.
- [[New Work for Phase 4]] — the source brief, and **Stars, Planets and Other Stations** is the item this one is the prerequisite for (§11).
- [[01_Technical_Specification]] — wants a short section on the background layers, which it does not currently document at all, plus a line in §1.17's save-section list for the `"system"` envelope field.
