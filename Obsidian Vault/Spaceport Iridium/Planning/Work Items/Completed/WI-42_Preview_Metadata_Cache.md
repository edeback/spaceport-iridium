# WI-42 — Preview Metadata Cache

> **STATUS: COMPLETE (2026-07-22).** Shipped as designed. `PreviewModule.ModulePreviewData` (inner class, as the doc preferred) holds the twelve values; `_preview_cache: Dictionary[PackedScene, ModulePreviewData]` is an instance member on the node, so it dies with the scene. One instantiate per distinct scene per session instead of one per preview change — 47 distinct scenes across the 45 buildable `ModuleData` resources (45 base + 2 flipped variants: airlock, docking bay). Single file touched: `ui/preview_module.gd`. 377 GUT tests green (unchanged — no extractable rule, as the doc predicted). Verified by an old-vs-new differential probe: 1605 checks over every ModuleData × flip state × two sweeps, zero divergence.
>
> **Edge cases, all resolved as the doc guessed:**
> - **Material is not shared.** The preview copies only texture/offset/region/transform/flip off the module's sprite, never its material; `PreviewModule._ready` duplicates its own. Asserted per-check in the probe.
> - **Nothing assigns `ModuleData.scene` at runtime** (`grep '\.scene\s*='` → zero hits outside reads), so cached entries can't go stale. Confirmed, not inherited.
> - **Missing `StructureComponent` / `offset` / `sprite`** are now `assert`s in `ModulePreviewData.from_scene` — the assumption made loud, matching how `StorageData` states its invariants. All 45 modules satisfy all three.
> - **Point arrays are shared** between every preview of a scene rather than copied. Verified by grep that nothing anywhere mutates `connection_points`/`internal_points`/`must_be_clear_points`; noted in a comment at the assignment.
>
> **One pre-existing bug fixed in passing** (found by the probe, not caused by this WI): `update_from_module_data` had no null guard on `module_data`, while the `module_data` setter did. Pressing `flip_module` with no module selected reached it through the `flipped` setter and threw "Invalid access to property 'scene' on a base object of type 'Nil'" — a live crash on `main`, one keypress away. Guarded at the top of the function, which covers both setters.

## Goal
Stop `PreviewModule` from instantiating an entire module scene every time the build preview changes. Closes **C12**.

Smallest of the four Phase 3.5 refactors and fully independent of the others — schedule it whenever.

## Design

`PreviewModule.update_from_module_data` instantiates `module_data.scene`, reads twelve values off it, and frees it. It runs from the `module_data` and `flipped` setters, so it fires on every build-menu selection and every flip. What it actually needs is static per-scene metadata that never varies at runtime:

- from the module: `size`, `offset.position`
- from `StructureComponent`: `connection_points`, `internal_points`, `must_be_clear_points`
- from the sprite: `texture`, `offset`, `region_enabled`, `region_rect`, `transform`, `flip_h`, `flip_v`

**Cache it, keyed by `PackedScene`.** Not by `ModuleData` — a flippable module's `flipped_scene` is a separate `PackedScene` with genuinely different geometry, and keying on the scene gets that right for free while keying on `ModuleData` would need a second dimension.

Shape: a small `ModulePreviewData extends RefCounted` holding those fields, plus a lazily-populated `Dictionary[PackedScene, ModulePreviewData]`. One instantiate per scene per session instead of one per preview change.

`PackedScene` alone is a sufficient key. (Scoping this WI originally flagged the `is_horizontal` assignment in `update_from_module_data` as a possible second key dimension — `is_horizontal` has since been removed from the codebase entirely, so the question is moot and the key stays one-dimensional.)

### Cache lifetime — don't repeat A8

A process-wide `static var` dictionary would hold every previewed `PackedScene` alive across scene swaps. That's a small leak, and structurally it is *exactly* the pattern behind WI-38's A8 (mutable state on a cached resource surviving a Quit-to-Menu → New Game boundary). The data here is immutable so it can't corrupt a run the way credits did — but the lesson is cheap to apply.

**Own the cache on the `PreviewModule` node** (an instance member), so it dies with the scene. `PreviewModule` is long-lived within a session and the cache only needs to outlive individual preview changes, which an instance member does fine. If profiling later shows the per-session repopulation matters (it won't — it's one instantiate per module type the player actually previews), a static with an explicit clear-on-scene-entry is the escalation, not the starting point.

## Files to touch
- `ui/preview_module.gd` — cache + lookup, replacing the instantiate
- **New (optional):** `ui/module_preview_data.gd` if `ModulePreviewData` warrants its own file rather than an inner class. Inner class is fine and probably better — nothing outside `PreviewModule` needs it.
- Remember: `filesystem_manage(op="scan")` if a new `class_name` lands

## Implementation order
1. Extract the current read block verbatim into `ModulePreviewData.from_scene(scene) -> ModulePreviewData`, still called every time. No behavior change yet.
2. Add the dictionary and the lookup in front of it.

## Edge cases
- **Sprite `transform` is a `Transform2D` (value type)** — copies cleanly. But `texture` and `region_rect` come off a shared resource; the preview assigns them onto its own sprite, so confirm nothing mutates them afterward (`_update_shader` touches the *material*, which the preview owns separately — check whether that material is shared with the real module's, since `ModuleBase._ready` explicitly duplicates its own).
- **A module whose scene lacks a `StructureComponent`**: `update_from_module_data` currently calls `get_structure_component()` unguarded and would already be crashing today, so this isn't a regression — but the cache builder is a natural place to guard, and every buildable module having one is an assumption worth making explicit rather than incidental.
- **`offset` node**: `temp_module.offset.position` is read off an `@export`ed node reference. Null if a scene forgets to wire it — same "already broken" category, same reasoning.
- **Unlocks changing a module's scene at runtime**: they don't (`GrantModuleEffect` flips `unlocked_by_default`, it doesn't swap `scene`), so cached entries can't go stale. Confirm that's still true rather than inheriting the assumption.

## Verification
1. Cycle the whole build menu, rotating and flipping each entry → previews render identically to before: right sprite, right size, right blocked-cell tinting, right must-be-clear overlay.
2. Flippable modules specifically (the ones with a distinct `flipped_scene`) → flipping shows the flipped geometry, not a cached copy of the unflipped one. This is the test the cache key exists to pass.
3. Place from a preview → the placed module matches what the preview showed, at the same cell and orientation.
4. Multiplacement drag (`Multiplacement.HORIZONTAL`/`VERTICAL`/`BOTH`) → per-cell validity still updates correctly during the drag.
5. Quit to menu → New Game → build menu previews still work (the cache was rebuilt, not left dangling).
6. Full GUT suite green. No new unit tests warranted — this is a UI-side cache with no extractable rule.
