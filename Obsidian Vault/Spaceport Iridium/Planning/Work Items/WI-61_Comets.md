# WI-61 — Comets

> **STATUS: COMPLETE (2026-08-20).** Shipped as designed apart from the eight deviations below. Twenty-seven files touched, seven new. **1214 GUT tests, all green** (+37: `test_comets.gd` at 34, plus three in `test_minimap.gd`) — the whole suite was green at 1177 before this item, so nothing regressed. Verified further by a **66-check headless probe** green on repeated runs, and **thirteen screenshots** driven into each state. Save is backward-compatible and `SAVE_VERSION` did not move: a body with no `profile` key restores as a belt asteroid with the old 2000px-from-the-marker despawn rule.
>
> **The probe proves the whole chain end to end**, not just the parts: a drone leaves a mining bay, flies out to a designated comet, mines it, returns, and deposits ice and carbon into the bay's own storage — which is the §6a soft-lock, live.
>
> **Deviations from the design below:**
> 1. **The comet sprite needed a `Sprite2D.offset`, which the design did not anticipate, and it is load-bearing.** `blue_comet.png`'s head sits at texture (18, 43) of 64×64 and `Sprite2D.rotation` pivots on the sprite's own origin — so with the texture centred, the head would *orbit* the node's position every time the heading changed. Worse, the node's position is what `Action_Mine` glues the mining drone to and what `should_despawn()` measures, so it would have been a point in the middle of the tail. `offset = Vector2(14, -11)` puts the head on the origin. Measured by decoding the PNG, not by eye.
> 2. **The art's measured forward axis is 137°, and 135° ships anyway.** The brief's "bottom-left" reading is right to within two degrees, which is invisible in play; a measured-to-the-decimal number in the data would imply a precision the sprite does not have.
> 3. **`MinimapTransform` got two statics, not one dictionary.** §8 specified `clamp_to_map(point, rect) -> {position, on_edge}`. Shipped as `clamp_to_map()` plus `is_outside()`: an untyped `Dictionary` access is exactly what this project's `unsafe_property_access` warning exists to catch, and two typed functions are individually testable.
> 4. **`spawn_gap_hours` is re-rolled after every spawn *attempt*, not every spawn.** A CROSSING profile declines when nothing is built yet (§3); without the re-roll it would retry every single frame for the whole opening of a run.
> 5. **The comet's entry/exit margins were widened after measurement**, from (600–1200)/600 to (800–1600)/800. The first probe run showed a two-module station producing crossings *shorter* than the belt's own 2000px despawn radius, which made the comet's arrival read as barely outside the play area.
> 6. **`AsteroidDispersal.GRID` became a parameter that nothing uses.** The design flagged the 3×3 shatter of a mostly-transparent tail as a cosmetic risk and named `grid` as the lever. The screenshots say it reads fine — the shards are recognisable pieces of comet, not empty squares — so the lever ships unused at its default, and the dust colour is the only thing the comet profile actually overrides.
> 7. **`_process` skips the rotation write entirely when `rotation_speed_deg_per_sec` is 0.** Not in the design and behaviourally a no-op (`+= 0`), but it makes it explicit that a non-tumbling body's rotation belongs to `_apply_orientation()` alone.
> 8. **One profile resource covers both trajectories, so each shipped `.tres` carries the other's inert knobs** (`belt_jitter` on the comet, `entry_margin` on the belt). Left that way deliberately: an enum plus a few unused fields is cheaper to read than the two-resource-type hierarchy the standing rule tells us not to build.
>
> **What the screenshots caught that the probe could not:**
> - **The first "comet behind the station" shot was blank**, and that was the *feature working* — a comet posed at the station centre is covered completely by the hull, which is pixel-identical to not rendering at all. The shot had to be re-posed against a hull **corner**, where the tail is visibly sliced off at the hull line, plus a fully-occluded/open-space pair so "hidden" cannot be misread as "broken". A screenshot that cannot distinguish success from total failure is not verification.
> - The belt still draws exactly where it always did after its layer moved to −1.
> - The inspector's grey subject-icon swatch is identical on a comet and an asteroid, i.e. pre-existing and not a regression from `body_name`.
>
> **Three probe checks were wrong, not the code**, and all three the same way: they asserted a comet's route is longer than the belt's 2000px. On a two-module station a crossing is legitimately ~1700–2500px. Replaced with "the route carries it past the far side" and "the restored route equals the saved route" — a threshold that happens to hold on the station you tested is not the property you meant.
>
> **What the probe found that has nothing to do with comets:** a bare starting station **cannot mine anything at all**, comet or asteroid, because it has no airlock — so `PathManager.is_space_reachable()` is false and `JobDriver_Mine.can_do()` refuses every trip. Pre-existing and correct; noted because it cost an hour of chasing a comet bug that was not one, and because any future mining probe has to build an airlock first.
>
> **Balance left open on purpose:** an 18–60 game-hour gap against a crossing of roughly ten game-hours puts a comet in the sky about 20% of the time — measured on the *starting* station, and both the crossing length and therefore that fraction scale with the station's bounds. Re-measure on a large station before tuning. The yield split (ice 6 / carbon 3 / silicon 1 at 0.35, 28 chunks) has not been played against the economy at all.
>
> The roadmap and [[01_Technical_Specification]] are updated for this item; note the spec still has no section for [[WI-60_Heat_System]], which that item deferred.

## Goal

Add **comets**: a second kind of mineable body that arrives from anywhere, crosses the whole play area on a straight line, and leaves. Where the asteroid belt is a standing supply of metals off to one side of the station, a comet is a **transient volatiles delivery** — mostly ice, some carbon, occasionally a little silicon — that the player has one crossing to exploit before it is gone.

Four deliverables:

1. **A crossing trajectory** — spawn well outside the station in a random direction, fly across (passing *behind* the station), despawn well outside on the far side.
2. **A different yield** — ice always and a lot of it, carbon always and a moderate amount, silicon ore sometimes and a little.
3. **Everything else identical to an asteroid** — clickable, inspectable, designatable, minable by drones, disintegrating when worked out.
4. **A scarcity** — 0–2 alive at any moment, with real gaps at zero.

Deliverable 3 is the one that decides the shape of this item, and §1 is about why it makes almost all of it free.

## Design

### 1 — A comet is an `AsteroidBase`, not a subclass of one

Every consumer of a mineable body in this codebase keys on the **class**, not on a scene or an id:

| Consumer | How it finds bodies |
|---|---|
| `Finder_Asteroid` | `get_nodes_in_group(Groups.ASTEROID)` → `node as AsteroidBase` |
| `JobDriver_Mine._any_ore_left` | the same group scan |
| `Action_Mine` | `JobTarget.asteroid()` |
| `JobTarget` / `SaveManager.asteroid_ref` | `Kind.ASTEROID`, resolved through `AsteroidManager.get_asteroid_by_id` |
| `InspectorPanel.kind_of` | `subject is AsteroidBase` → `AsteroidTabSet` |
| `Minimap` | iterates `Global.asteroid_manager.asteroids` |
| `UIMain.asteroid_clicked` | `inspector.select(asteroid)` |

If a comet **is** an `AsteroidBase`, none of those files needs a comet case, and deliverable 3 is satisfied by construction rather than by seven parallel code paths that can drift. That is worth far more than the naming tidiness of a `CometBase`, and it is also the composition rule the project already runs on: the differences between a comet and an asteroid are **a scene, a spawn rule, and a row of numbers** — none of them behaviour to override.

So: **no new class for the body.** `objects/comet.tscn` is a second scene rooted in the same `objects/asteroid_base.gd`, and `AsteroidBase` gains five fields, all inert at their defaults so an asteroid behaves exactly as it does today:

- `body_name: String = "Asteroid"` — the player-facing noun (§8).
- `profile_id: StringName = &"asteroid"` — which `SpaceBodyProfile` spawned it; saved, and the only thing a load needs in order to rebuild the right scene.
- `faces_travel_direction: bool = false` and `sprite_forward_offset_deg: float = 0.0` (§4).
- `despawn_anchor: Vector2` + `despawn_distance: float` (§3).

`rotation_speed_deg_per_sec` is promoted from a bare `var` to an `@export` so the comet scene can author it as `0`.

**`AsteroidBase` keeps its name.** Renaming it to `MineableBody` would churn `Groups.ASTEROID`, `JobTarget.Kind.ASTEROID`, `SaveManager.asteroid_ref`, the `&"mine_asteroid"` job id and the `"asteroids"` save section — three of which are **save-format identifiers** — for a rename that improves nothing the player can see. The player-facing noun moves into data instead (§8); the code-facing one stays wrong-but-stable. Say so in a comment on the class, so the next reader doesn't start the rename.

### 2 — `SpaceBodyProfile`: the per-track knobs, as data

Comets differ from asteroids in **every** number `AsteroidManager` currently holds as an `@export`. Adding a second parallel set of exports to the manager would double it and put two spawn tracks' balance in a scene file, against the standing rule that balance lives in `.tres`. So the per-track knobs become a resource.

`data/space_bodies/space_body_profile.gd` (`class_name SpaceBodyProfile`, extends `Resource`):

```
id: StringName                    # &"asteroid" / &"comet"; saved per body
display_name: String              # "Asteroid" / "Comet"
scene: PackedScene
max_population: int               # 15 / 2
spawn_gap_hours: Vector2          # min/max game-hours between spawn attempts
speed_range: Vector2              # px per sim-second
trajectory: Trajectory            # BELT | CROSSING
mix_mode: MixMode                 # WEIGHTED_PICK | FIXED_LIST
fixed_ores: Array[BodyOreEntry]   # FIXED_LIST only
richness_band: Vector2
richness_spread: float
richness_skew: float
dispersal_dust: Color             # §9
# CROSSING only:
entry_margin: Vector2             # px beyond the station bounds to appear
exit_margin: float                # px beyond the far side before despawning
lateral_spread: float             # 0 = dead through the centre, 1 = graze the edge
```

`data/space_bodies/body_ore_entry.gd` (`class_name BodyOreEntry`) is three fields: `resource: ResourceData`, `weight: float`, `chance: float`.

Two profiles ship: `asteroid_belt_profile.tres` and `comet_profile.tres`. **The asteroid profile must reproduce today's belt exactly** — same cap (15), same 5-sim-second cadence (0.5 game-hours, flat), same 10–30 px/s, same richness band/spread/skew, same weighted 1–3 ore pick. WI-60's `open_face_fraction` extraction is the precedent: write the pinning test *before* the move, and the game is identical at that step.

Profiles are **discovered by scan**, not authored on the manager node: a new `ContentPaths.SPACE_BODIES` kind (two lines in `ContentPaths`) plus a scan mirroring `AsteroidManager._spawnable_ores` — cached, and **sorted by id** so a weighted roll is reproducible however the directory enumerated. That makes "a mod adds its own kind of body" a `.tres` drop with zero core edits, which is the WI-47 bar. The belt's ore pool stays where it is (`ore_types_available` / `ore_spawn_weights` on the manager node, plus `ResourceData.asteroid_spawn_weight`) — `WEIGHTED_PICK` reads it unchanged, so nothing about belt composition moves in this item.

`AsteroidManager` keeps **one** `asteroids: Array[AsteroidBase]` and counts population per profile with a filter. Two arrays would be two places every future reader has to remember, and `get_asteroid_by_id`, the save section and the minimap all iterate that one array today.

### 3 — The crossing trajectory, and the despawn rule that would have killed it

**The existing despawn rule is a trap.** `AsteroidManager._process` frees any body more than 2000px from `start_point.position` — the *belt marker*. A comet spawning on the opposite side of the station is already further than that from the belt marker, so with no change it would be freed on its first frame, silently, with no error.

Fix by making the rule per-body rather than per-manager: `AsteroidBase` carries `despawn_anchor` and `despawn_distance`, and the manager despawns when `position.distance_squared_to(despawn_anchor) > despawn_distance²`. Asteroids get `anchor = start_point.position, distance = 2000` at spawn, which is **identical to today's behaviour** — deliberately the belt marker rather than the body's own jittered spawn point, so the pinning test has nothing to forgive. Both fields are saved.

**Entry, aim and exit** are pure geometry and belong in a pure file. `data/events/effects/effect_spawn_salvage.gd` already contains the station-bounds-plus-outward-offset math this needs — extract it to `scripts/utility/space_geometry.gd` (`class_name SpaceGeometry`, all static, no `Global`) and have the salvage effect call it, so the two cannot disagree about where "outside the station" is:

- `station_bounds(module_positions: Array[Vector2]) -> Rect2`
- `half_extent(bounds: Rect2, direction: Vector2) -> float` — the existing `|dir.x|·w/2 + |dir.y|·h/2` box-radius.
- `outward_point(bounds, direction, distance) -> Vector2` — the salvage effect's rule, now shared.
- `crossing(bounds, angle, lateral, entry_margin, exit_margin) -> Crossing` — the new one, returning `{entry, direction, distance}`.

`crossing` rolls out to `entry = centre + dir(angle) · (half_extent(dir) + entry_margin)`, aims at `centre + perp(dir) · lateral · half_extent(perp)`, and reports `distance` as entry→exit, where exit is `exit_margin` past the bounds on the far side. `lateral` is drawn per comet from `[-lateral_spread, +lateral_spread]`, so comets sometimes cut straight through the station and sometimes graze it — a comet that always bisected the station would read as scripted within two arrivals.

**Speed stays in the asteroid band (15–28 px/s), and that is a constraint, not a preference.** Drones move at `PawnBase.speed = 80` px/sim-second and chase a moving target; a body outrunning a meaningful fraction of that turns every mining trip into a stern chase. Asteroids already drift at 10–30 and the whole mining chain is proven at that speed, so comets stay inside the proven envelope. At ~20 px/s a comet crosses a 5000px span in roughly one game-cycle, which is the window the player gets.

Zero placed modules means no bounds and no sensible centre: skip the spawn that tick rather than spawning at the origin.

### 4 — Orientation: no spin, nose forward

`assets/external/blue_comet.png` is 64×64 with the head at the **bottom-left** and the tail streaming to the upper-right, i.e. its authored forward axis points toward `(-1, +1)`, which is **135°** in Godot's screen-space angle convention. So:

```gdscript
if faces_travel_direction and sprite != null:
	sprite.rotation = direction.angle() - deg_to_rad(sprite_forward_offset_deg)
```

with `sprite_forward_offset_deg = 135.0` authored on `comet.tscn`, `rotation_speed_deg_per_sec = 0`, and the whole thing applied **once** — in `_ready` and wherever `direction` is assigned — not per frame, because a comet's direction never changes after spawn. Put the offset in data rather than baking 135° into code: it is a property of the art, and a mod's body sprite will point somewhere else.

A note for whoever reads this later and reaches for physics: a real comet's tail points away from the sun, not backwards along its path. The brief asks for nose-along-motion and that is what ships; it is a deliberate call, not an oversight.

### 5 — One line in `main.tscn`: `AsteroidLayer` moves to `layer = -1`

"It can go behind the station" cannot be done with `z_index`. `BackgroundLayers/AsteroidLayer` is a `CanvasLayer` with **no `layer` set, so it is Godot's default `1`** — *above* `ForegroundLayers/ModuleLayer`, which is explicitly `0`. Asteroids draw in front of the station today; nobody noticed because the belt sits off to the left at x ≈ −200 and never overlaps it. `CanvasLayer` ordering dominates `z_index`, so no per-node value can push a body on `AsteroidLayer` behind a module.

**Set `AsteroidLayer.layer = -1`.** That is the whole change: it lands between the parallax background (`-10`) and the modules (`0`), keeps `follow_viewport_enabled = true` so its contents stay in world space (which is what lets drones fly to them), and needs no second layer, no second `@export` on the manager, and no per-profile depth field. Comets spawn into the same layer asteroids already use.

Two knock-on effects, both accepted deliberately:

- **Asteroids move behind the station too.** Invisible today, since the belt never overlaps the modules. It becomes visible only if the player builds out over the belt, and a rock passing behind the hull is the correct reading of that picture anyway.
- **Click-picking flips for the same overlap.** The viewport picks per canvas layer, highest first, so a module in front of a body now takes the click and the body behind it does not. That is the behaviour you want for a comet crossing the station, and it is a property of the layer rather than of `set_input_as_handled()` ordering. For an asteroid under a module built over the belt it is a change from today — the same acceptable one.

The alternative considered and rejected was a separate `CometLayer` at `-1` alongside `AsteroidLayer` at `1`, which buys the ability to keep asteroids in front at the cost of a second layer, a `renders_behind_station` flag on every profile, and a second manager export. Nothing wants asteroids in front, so none of that carries its weight.

### 6 — The yield, and the two ways it does not currently fit the station

The mix is a `FIXED_LIST` of three `BodyOreEntry` rows, rolled per comet:

| Resource | Weight | Chance | Effect |
|---|---|---|---|
| `ice` | 6.0 | 1.0 | always, ~60–67% of the body |
| `carbon` | 3.0 | 1.0 | always, ~30–33% |
| `silicon_ore` | 1.0 | 0.35 | roughly a third of comets, ~10% |

`max_resources = 28` on `comet.tscn` against the asteroid's 10, so a comet is a genuinely large prize whose whole value is gated on noticing it in time. **These five numbers are a first guess and should be measured, not trusted** — WI-60's two balance guesses were both wrong by ~4×, in opposite directions, and only the probe found it.

Two things in the existing station do not accept this yield, and the first one is a soft-lock:

**(a) The mining bay cannot store refined carbon, and the failure is silent and permanent.** `modules/resource_gathering/mining_bay.tscn`'s output `StorageComponent` has `allow_any_resource = false` and authors slots for exactly six ores — `iridium_ore, carbon_ore, ice, gold_ore, silicon_ore, iron_ore`. `carbon` is not among them. `Action_DumpInventory` skips every resource the bin refuses and returns `FAILED` if nothing landed, and it **never destroys anything** — so the carbon stays on the drone, trip after trip, until `space_available() <= 0` makes `JobDriver_Mine.can_do` refuse every future mining job. That bay's drones stop mining, permanently, with no alert and no error. Fix: add a `carbon` `StorageData` slot to the bay. More importantly, add the **guard** — a test asserting that every resource every shipped profile can yield is storable by the vanilla mining bay, so the next body kind cannot reintroduce this.

**(b) Carbon cannot be picked as a priority ore.** `MiningComponentUI` builds its dropdown from `Global.asteroid_manager.ore_types_available`, which is the six belt ores. The brief asks that comets "can be prioritized"; the `designated` flag covers the per-body half of that (§8, free), but the per-bay ore preference would silently omit anything only comets carry. Replace the dropdown's source with a new `AsteroidManager.spawnable_yields()` — the union of `ore_types_available`, every `ResourceData` declaring an `asteroid_spawn_weight`, and every profile's `fixed_ores`, sorted by id. That also closes a **latent WI-47 gap**: a mod's ore already joins the belt through `asteroid_spawn_weight` but has never been selectable in this dropdown.

**Carbon vs Carbon Ore is the one judgement call in this item.** The brief lists "Ice / Carbon / Silicon Ore" and distinguishes the third with the word "Ore", so it is read literally: comets yield **refined `carbon`**, not `carbon_ore`. That is a real economic shortcut — every other mined material goes through a refining recipe, and `carbon_refining_recipe.tres` exists — and it is what makes comets meaningfully special rather than "an asteroid with a different weight table". If it plays as too strong, the change is one field in `comet_profile.tres` **plus** reverting (a) above, since `carbon_ore` already has a bay slot. Flagged here rather than decided silently.

**Richness is nearly meaningless on a comet, and the inspector must not pretend otherwise.** `Action_Mine` only attaches an `OreInstanceData` when `resource.has_variance`, and of the three, only `silicon_ore` has it. So a comet with no silicon has a richness band that describes nothing, while `AsteroidTabSet.meta_text()` prints `get_richness_descriptor()` unconditionally. Add `AsteroidBase.has_variable_yield()` (true when any resource in the mix has `has_variance`) and drop the richness clause from the meta line when it is false. Asteroid mixes always contain a variance ore, so asteroids are unaffected.

### 7 — Population and cadence

`max_population = 2` gives the brief's ceiling. The floor of zero has to be built deliberately: today's `_process` spawns whenever the population is under the cap and the timer elapses, which converges on "always at the cap". Instead, roll the next gap from `spawn_gap_hours` **after each spawn**, so a comet profile with `Vector2(18, 60)` game-hours (0.75–2.5 cycles) sits empty most of the time and occasionally has two. Keep the accumulator in the manager's existing `_process` sim-delta idiom rather than moving to `slow_tick` — the belt already works that way, and one clock for both tracks is easier to reason about than two.

`last_spawn` in the save becomes a per-profile dictionary; a pre-WI-61 save's scalar restores onto the asteroid profile.

### 8 — UI: the noun, and the minimap

**The inspector caption is a live bug this item has to fix anyway.** `InspectorTabSet.kind_label()` is documented as *"the header caption, after `SELECTED · `"* and is overridden by all six tab sets — and **nothing calls it**. `InspectorPanel._apply_selection` reads a static `KIND_CAPTIONS` dictionary keyed on `SelectionKind` instead. Since a comet resolves to `SelectionKind.ASTEROID`, that dictionary would caption it "Asteroid" with no way to say otherwise. Fix the contract rather than special-casing: have the panel call `_set.kind_label()` when a set is mounted, keep `KIND_CAPTIONS` only for `NONE`, and retitle the six `kind_label()` returns from `"ASTEROID"` to `"Asteroid"` etc. so the rendered casing does not change. `AsteroidTabSet.kind_label()` and `subject_name()` then both return `_asteroid.body_name`, which comes from the profile — **one place a body becomes a noun**, the same rule `PawnStatus` and `StoresModel` follow.

The rest of the tab set needs nothing: the Contents tab, the remaining-chunks bar and the "Designate for mining" footer button all work on a comet as-is, which is deliverable 3's clicking, viewing and prioritizing.

**The minimap will blow its own scale open unless comets are excluded from the fit.** `Minimap._recompute_bounds` deliberately expands the world AABB over *every live asteroid* so that nothing it draws lands outside the box. A comet spawns thousands of pixels out, so including it would zoom the whole station down to a smudge for the comet's entire crossing and back again — the hysteresis in `settle_bounds` damps the thrash but not the zoom.

Exclude bodies whose profile is `CROSSING` from `_recompute_bounds`, and instead draw them **clamped to the map's edge**: a comet outside the box renders as a marker on the rim in the direction it lies, and slides inward naturally once it enters. That is the radar-contact idiom, it keeps an approaching comet discoverable, and it costs one pure function — `MinimapTransform.clamp_to_map(point, rect) -> {position, on_edge}` — in the file that is already pure and unit-tested. Add a `comet_color` export (a pale blue against the belt's grey-brown) and draw an on-edge contact slightly larger than an in-box dot.

**One `LOW` alert on arrival**, via `AlertManager` — "A comet has entered the mining envelope". Not a transmission (it is "look now", and it is worthless an hour later), never `HIGH` (it does not stop what you are doing), and no alert on departure. Include it, and **cut it if it reads as noise in play** — a rim contact on the minimap may already be enough, and an alert the player learns to ignore is worse than no alert.

### 9 — Disintegrating

Mined dry, a comet takes the same `_disperse` path as an asteroid: `AsteroidDispersal` shatters the body's *own* sprite into a 3×3 grid, which already works for any texture and is precisely why it is built in code rather than authored. One change: `DUST_COLOR` becomes a settable field defaulting to today's grey-brown, so `comet_profile.tres` can pass a pale blue-white through `setup()`. A grey-brown rock puff coming off a blue comet is exactly the kind of thing only a screenshot catches.

Watch the shatter itself on a 64×64 sprite that is mostly transparent tail: the corner shards will be nearly empty. If it reads badly, the lever is `GRID` (also worth making a parameter) — not a bespoke comet effect.

A comet that reaches its despawn distance is **freed with no dispersal**, exactly as a drifted-out asteroid is. It left; it did not break up.

### 10 — Save

Additive, backward-compatible, and **`SAVE_VERSION` does not move**. Three new keys on each asteroid entry:

- `profile` — the `SpaceBodyProfile.id`. This is the load-bearing one: `_spawn_asteroid_from_save` currently instantiates `asteroid_scene` unconditionally, so without it every restored comet comes back as a rock. **A missing key reads as `&"asteroid"`**, which is exactly right for a pre-WI-61 save.
- `despawn_anchor` and `despawn_distance` (§3). Missing reads as the belt marker and 2000.

The manager's own block: `last_spawn` becomes `spawn_gaps` (profile id → hours remaining) with the old scalar migrating onto the asteroid profile; `next_id` is unchanged and stays one shared id space across both kinds, so `get_asteroid_by_id` and `SaveManager.asteroid_ref` need no edit at all.

`_spawn_asteroid_from_save`'s two ordering constraints carry over unchanged and are still load-bearing: `resource_weighted_values` must be set **before** `add_child` (`_ready` sums the weights), and `cur_resources` restored **after** (`_ready` resets it to `max_resources`). Comets add a third: `direction` must be set before the orientation is applied, or a restored comet points at 135° instead of along its path.

### 11 — Cheats

Each emits its `station_alert` "CHEAT: …", per the standing rule:

- `spawn_comet()` — force one now, ignoring the gap and the cap. The one this item will actually live on.
- `spawn_body(profile_id)` — the general form.
- `dump_bodies()` — one line per live body: profile, id, position, distance travelled out of its despawn distance, contents, designation.

## Files to touch

**New**
- `data/space_bodies/space_body_profile.gd` (`class_name SpaceBodyProfile`)
- `data/space_bodies/body_ore_entry.gd` (`class_name BodyOreEntry`)
- `data/space_bodies/asteroid_belt_profile.tres`, `data/space_bodies/comet_profile.tres`
- `objects/comet.tscn` (root script `asteroid_base.gd`, `blue_comet.png`, `ClickArea` circle sized to the head rather than the tail)
- `scripts/utility/space_geometry.gd` (`class_name SpaceGeometry`)
- `tests/unit/test_comets.gd`

**Changed**
- `objects/asteroid_base.gd` — the five new fields, `has_variable_yield()`, the orientation apply, three new save keys
- `objects/asteroid_dispersal.gd` — dust colour (and `GRID`) as parameters
- `scripts/managers/asteroid_manager.gd` — profile scan + per-profile population/cadence/trajectory/despawn, `spawnable_yields()`, the migrated save block
- `scripts/mods/content_paths.gd` — the `SPACE_BODIES` kind
- `main.tscn` — one line: `BackgroundLayers/AsteroidLayer` gains `layer = -1` (§5)
- `modules/resource_gathering/mining_bay.tscn` — a `carbon` storage slot (§6a)
- `ui/windows/mining_component_ui.gd` — the dropdown reads `spawnable_yields()`
- `ui/inspector/inspector_panel.gd` — caption from `kind_label()`
- `ui/inspector/tab_sets/*.gd` — six `kind_label()` returns retitled; `asteroid_tab_set.gd` also reads `body_name` and drops the richness clause when there is no variable yield
- `ui/minimap.gd` — exclude CROSSING bodies from bounds, rim-clamped contacts, `comet_color`
- `ui/minimap_transform.gd` — `clamp_to_map`
- `data/events/effects/effect_spawn_salvage.gd` — calls `SpaceGeometry`
- `scripts/utility/cheats.gd` — the three cheats
- `tests/unit/test_minimap.gd` — extended, not rewritten

Run `filesystem_manage(op="scan")` after the new `class_name` files, or `SpaceBodyProfile` / `SpaceGeometry` won't resolve.

## Implementation order

1. **`SpaceGeometry` + `test_comets.gd` first**, including the extraction from `effect_spawn_salvage.gd` with its pinning test written *before* the move. Pure, no comets in it yet, game identical.
2. **`SpaceBodyProfile` + the asteroid profile**, and `AsteroidManager` refactored to run the belt *through* it. **The game must be indistinguishable at this step** — same cap, same cadence, same speeds, same mixes, same despawns. This is the step that can regress something that works, so it is done alone and verified alone.
3. **`despawn_anchor` / `despawn_distance`**, still asteroid-only and still identical (§3).
4. **The comet: scene, profile, the `AsteroidLayer` depth change, crossing trajectory, orientation.** It flies and it disintegrates; nothing mines it yet.
5. **The yield and its two misfits** — the fixed mix, the mining bay's carbon slot, `spawnable_yields()`. Now a drone completes a full trip, and this is the step to prove the §6a soft-lock cannot happen.
6. **Save**, including a pre-WI-61 load.
7. **UI** — the caption fix, `body_name`, the minimap contacts, the arrival alert.
8. **Cheats, screenshots, balance measurement.**

## Edge cases

- **The belt's 2000px despawn would free every comet on its first frame** (§3). This is the single most likely way to implement this item and see nothing happen at all, with no error. Step 3 exists to close it before step 4 can trip on it.
- **A comet despawning under a working drone** is handled and free: `Finder_Asteroid._target` sets `fail_on_lost = false`, `Action_GotoTarget` reads a lost-but-survivable target as `DONE`, and `Action_Mine` returns `DONE` on a null asteroid so `JobDriver_Mine.next_index_after` sends the drone to another body or home with a partial load. **Verify it rather than assume it** — it is the only place a comet's transience touches the job system.
- **A drone still glued to a comet at despawn.** `Action_Mine` writes `job.pawn.position = asteroid.position` every tick, so a drone can be sitting several thousand pixels out when its rock vanishes. Its route home is a fresh `pathfind_to_node_in_space` from wherever it is — the same call it already makes, but a much longer walk than the belt ever produced. Watch for a drone running its energy down on the trip back; WI-28's zero-energy crawl at 0.25× speed would make it much worse.
- **A comet crossing the station's cells** overlaps modules visually and is behind them (§5). It has no collision — nothing in the belt does — so it passes through with no physical interaction, which is intended.
- **A station built out over the asteroid belt** now draws its rocks behind the hull and lets the module take the click, because `AsteroidLayer` moved with the comets (§5). Accepted, not a regression to fix — but it is the one existing behaviour this item changes, so it belongs in the item's own notes rather than being discovered later as a mystery.
- **Two comets at once, both designated.** `Finder_Asteroid` returns the first designated body its shuffled scan finds, so drones split across them arbitrarily. Same as two designated asteroids today; no change needed.
- **A comet spawning inside the asteroid belt's corridor** is possible and harmless — they are the same kind of object on different layers.
- **Zero placed modules** — no bounds, no centre; skip the spawn (§3).
- **The station grows during a crossing.** `despawn_distance` is fixed at spawn, so a comet that entered when the station was small still exits where it always would have. Correct, and cheaper than re-deriving it every frame.
- **`asteroid_id = -1`.** `EventEffectSpawnSalvage` deliberately spawns `ResourcePile`s rather than asteroids to bypass the population cap, so nothing today creates an unregistered body — but `AsteroidBase` still documents the case, and the new profile field must default sanely for a bare instance (`tests/unit/test_goto_lost_target.gd` constructs `AsteroidBase.new()` directly).
- **Pause.** The manager and the body both early-return on `Global.time_manager.scale(delta) <= 0`, so comets freeze with the sim. Nothing here may write `TimeManager.paused`.
- **Speed vs drone speed** (§3): a profile authored above ~40 px/s turns mining into a chase the drone barely wins. Worth an assert, or at least a comment on `speed_range`.
- **Modded profiles** join by scan at their `.tres` defaults and share the one body layer. A mod cannot pick its own render depth without a `main.tscn` edit; note it rather than building for it.

## Verification

1. **GUT** (`test_comets.gd`, pure — construct directly, never touch `Global`/`SignalBus`):
   - `SpaceGeometry.station_bounds` over zero / one / many module positions; `half_extent` along the axes and the diagonals; `outward_point` **pinned against the values `effect_spawn_salvage.gd` produced before the extraction**.
   - `crossing()`: the entry point is always outside `bounds` by at least `entry_margin`; the ray from entry along `direction` intersects the bounds for `lateral = 0`; `distance` always carries the body past the far edge; `lateral = ±1` still produces a finite crossing; a degenerate zero-size `bounds` does not divide by zero.
   - The fixed-list mix roll: ice and carbon present in **every** sample, silicon present in roughly `chance` of a large sample, weights landing in `resource_weighted_values` unmodified, and an entry with a null `resource` skipped rather than crashing.
   - Orientation: `direction.angle() - deg_to_rad(offset)` for the four axis directions, asserting the 135° authored offset puts the head along travel.
   - The despawn predicate at just-inside, exactly-at and just-outside `despawn_distance`.
   - `MinimapTransform.clamp_to_map` for a point inside (unchanged, `on_edge = false`), outside in each quadrant, and exactly on the boundary.
   - **The §6a guard:** every resource every shipped profile can yield is accepted by the vanilla mining bay's output storage. This is a data test, and it is the one that stops a future body kind bricking every drone.
   - **The step-2 pinning suite:** the asteroid profile's cap, cadence, speed band, richness parameters and ore-pick behaviour equal the manager's pre-refactor exports.
2. **Headless probe** (the standing fallback since WI-30 — a temporary autoload running a numbered checklist against `main.tscn`, deleted after):
   - Spawn a comet with the cheat: it appears outside the station bounds, its sprite rotation matches its heading, it does **not** despawn on frame one, it crosses, and it frees itself past the far margin.
   - Population: with the cap at 2 and a short gap, the count never exceeds 2; with a long gap, a run spends most of its time at 0.
   - A full mining trip end to end: a drone claims a comet, flies out, fills its hold with ice/carbon(/silicon), returns, and **deposits everything** — assert the drone's inventory is empty afterwards, which is the §6a soft-lock check.
   - Despawn a comet mid-mine (free the body while a drone is on it) and assert the drone recovers: no failed job left on the board, no orphaned claims (`reserved_withdraw`/`reserved_deposit` reconcile to zero), and it either finds another body or comes home with a partial load.
   - Mine one dry and assert it disperses and leaves both `asteroids` and the save.
   - Save with one comet mid-crossing and one asteroid, reload, and assert both come back as the **right scene**, at the same position, heading, contents, designation and remaining despawn distance. Then load a **pre-WI-61 save** and assert every body restores as an asteroid with the belt's anchor and 2000px.
   - The belt itself, before and after step 2, over a long run: same population ceiling, same ore-type distribution, same despawn behaviour.
3. **Screenshots, driven into the state under test** — every panel item since WI-49 found defects a headless probe could not see, and this item has four things only a picture can settle:
   - a comet **passing behind the station** (the `CanvasLayer` claim in §5 is either true or embarrassingly false, and nothing headless can tell you which) — and, in the same pass, the belt still drawn where it always was, since §5 moved its layer too,
   - the comet's nose pointing along travel for at least two very different headings — the 135° offset is the single most likely thing to be wrong by a quarter turn,
   - the inspector on a selected comet: the caption reading `Selected · Comet`, the Contents tab's three rows, the meta line with **and** without the richness clause, and the designate button,
   - the minimap with a comet far out (a rim contact, station still at full scale) and the same comet close in (an ordinary dot), plus the dispersal puff on a comet mined dry.
4. **A full round trip by hand:** start a new game, wait for a comet, notice it on the minimap, designate it, watch drones fill the bay with ice and carbon, and see the comet break up or leave. If the player cannot tell a comet from an asteroid at a glance, or cannot work out that it is temporary, the numbers in §6 and §7 are wrong even with every test green.

## Related

- [[WI-21_Job_Serialization]] — `asteroid_id`, `SaveManager.asteroid_ref` and the asteroid save section this extends; the id space stays shared on purpose.
- [[WI-44_Job_System_Refactor]] — `Finder_Asteroid`, `Action_Mine` and `JobDriver_Mine`, none of which change: the survivable-target contract (`fail_on_lost = false`) is what makes a vanishing comet a non-event.
- [[WI-34_Minimap]] — `_recompute_bounds`'s "nothing it draws lands outside the box" rule, which is exactly what a crossing body breaks, and `MinimapTransform` as the pure home for the clamp.
- [[WI-51_Inspector]] — `AsteroidTabSet`, `InspectorPanel.kind_of`, and the unused `kind_label()` contract this item repairs.
- [[WI-47_Modding_Support]] — `ContentPaths` and the scan-don't-register rule the profile kind follows; also the latent dropdown gap §6b closes.
- [[WI-60_Heat_System]] — the immediately preceding item, and the source of two habits used here: extract-then-pin before refactoring something that works, and treat the first balance numbers as a hypothesis the probe tests.
- [[WI-13_Events_v1]] — `EventEffectSpawnSalvage`, whose station-bounds math becomes `SpaceGeometry`.
- [[New Work for Phase 4]] — the source brief. **Stars, Planets and Other Stations** is the natural follow-on: "ore type richness that feeds into the spawned asteroids" is a per-system override of exactly the `SpaceBodyProfile` set this item introduces.
- [[01_Technical_Specification]] — §1.2's `AsteroidManager` row and §1.17's `asteroids` save section both want a sentence on profiles; §1.18 wants the minimap's contact markers.
