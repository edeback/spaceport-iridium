# WI-34 — Minimap

## Goal
A square panel in the upper-right giving a simplified, symbolic overview of the world — modules as squares, asteroids as dots, ships as triangles — with click-to-jump camera navigation. Becomes necessary as stations outgrow a few screens.

## Design
- **Symbolic, not a render.** A custom `Control` (`ui/minimap.gd/.tscn`) using `_draw()` — no SubViewport (cost, and the design explicitly wants silhouette/shapes). World→map transform: fit a padded bounding box of all content (modules + asteroids) into the panel, recomputed when bounds change (station growth re-scales gracefully; clamp minimum scale so a young station isn't three giant pixels — use a sensible minimum world-span).
- **Layers drawn, back to front:**
  - Modules: one filled rect per occupied cell from `WorldManager.layer_data` (MODULE layer primary; corridor/turbolift cells in a dimmer shade). Color by category: default hull grey, distinct tints for power/industry/crew/defense (a small `tag → Color` map; tags exist on ModuleData), blueprints outlined, damaged modules (WI-24) tinted warning-red at low HP.
  - Asteroids: dots from `AsteroidManager`'s live set.
  - Ships: triangles — trader shuttle, arrival shuttles, pirate ships (WI-32; red), inspector ship. Source: a lightweight `minimap_tracked` group that ship-like nodes join on spawn, so the minimap never hard-codes managers.
  - Viewport rectangle: the camera's current world rect outlined, so you know where you're looking.
- **Redraw policy:** `queue_redraw()` on `module_added/removed`, on `slow_tick` (moving ships/asteroids/camera rect), and on camera move — it's a few hundred rects of `draw_rect`, trivial per frame, but slow_tick + camera-change is plenty.
- **Click-to-jump:** `_gui_input` left-click (and drag) → inverse transform → `Camera` target position (`scripts/managers/camera.gd` — add a `jump_to(world_pos)` if it lacks one; respect existing camera limits/zoom). Drag pans continuously.
- **Chrome:** collapsible (the collapsible_container addon is available), semi-transparent background, fixed panel size with the world fit inside; real-time UI (no sim scaling anywhere here).

## Files to touch
- **New:** `ui/minimap.gd/.tscn`
- `ui/ui_in_game.tscn`/`ui_main.gd` — mount the panel upper-right
- `scripts/managers/camera.gd` — `jump_to(world_pos)`
- `objects/arrival_shuttle.gd`, `objects/asteroid_base.gd`, (WI-32) `pirate_ship.gd` — join `minimap_tracked` / `asteroid` groups as needed
- `data/modules/module_data.gd` — nothing new (tags suffice); the tag→color map lives in minimap code as exported Dictionary

## Implementation order
1. Static module rendering + fit transform.
2. Asteroids + ships via groups; slow_tick refresh.
3. Click/drag-to-jump + viewport rect.
4. Category colors, damage tint, blueprint outline, collapse chrome.

## Edge cases
- Module placed far from the station (detached build, if possible) stretches the bounds: bounding-box fit handles it; extreme aspect ratios letterbox inside the square panel.
- Click while a build preview is active: minimap click must not place a module — consume the event (`accept_event`), and jumping mid-preview is allowed (preview follows mouse anyway).
- Panel under other windows (trade screen etc.): normal z-order; collapsed state persists in session (not saved).
- Hundreds of asteroids: dots are cheap; if the field is huge, decimate to one dot per N world units (guard, likely unneeded).
- Paused game: minimap still redraws (UI is real-time) — ships frozen is correct.

## Verification
1. Grown station: minimap silhouette matches the real layout (spot-check corridors vs modules shading); build/demolish updates immediately.
2. Click a far module cluster → camera jumps there; drag pans smoothly; viewport rect tracks manual camera movement and zoom.
3. Trader arrival, pirate raid (WI-32), and mining field all render as their symbols and move on slow_tick.
4. Damage a module to low HP → red tint appears (WI-24 landed).
5. No interaction leaks: clicking the minimap never places/selects world objects; collapse/expand works.
6. Perf: no measurable frame cost at 4× on a large station (monitors_get).
