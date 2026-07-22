# WI-35 — UI Overlays

## Goal
Toggleable station overlays that give a clear read of one system at a time: **O2** (green→red by pressure), **Power** (green powered / red unpowered-but-needs), **Structural Integrity** (green full HP → red low), **Vibration** (red high, clear none — WI-30 fields), **Logistics** (storage priorities + current flows). One overlay active at a time, selected from a small toolbar strip.

## Design
- **Rendering: shader tint, not rect soup.** The module shader already carries per-instance params (PREVIEW/SELECTED/DAMAGE…): add `OVERLAY_COLOR: vec4` (alpha 0 = off). An `OverlayManager` UI-side controller (`ui/overlay_controller.gd`, owned by UIMain — not a game manager; it's pure view) sets each visible module's overlay color when a mode is active and clears on deactivate. Refresh on `slow_tick` + mode-relevant signals (cheap: one iteration over placed modules, values already cached by their systems).
- **Mode data sources:**
  - **O2:** `AtmosphereComponent` O2 partial vs breathable threshold → green→yellow→red gradient; modules without atmosphere untinted; breached modules pulse.
  - **Power:** modules with a `PowerConsumptionComponent`: green if `powered`, red if not; generators tinted by output>0; passives untinted.
  - **Integrity:** `hp/max_hp` gradient (WI-24); truss-damaged distinct.
  - **Vibration:** `Global.adjacency_manager.get_field(module, &"vibration")` normalized against a "high" reference (WI-30); zero = untinted.
  - **Logistics:** tint by `StorageComponent` priority sign/magnitude (sinks warm, sources cool) **plus** an overlay drawing layer (a `Node2D` above the module canvas) with flow arrows: active haul jobs (board + claimed, from→to endpoints) and conveyor links (WI-27) as arrows; storage priority numbers as small labels on each storage module. This is the one mode needing more than tint.
- **Toolbar:** icon strip (top bar near time controls): five toggle buttons + hotkeys; selecting one deselects others; Esc/again = off. Active mode shows a legend chip (what the gradient means).
- **Lifecycle:** overlay state is session-only (not saved). New modules appearing while a mode is active get tinted on the next refresh tick; removed modules need no cleanup (param dies with the instance).

## Files to touch
- **New:** `ui/overlay_controller.gd`, `ui/overlay_flow_layer.gd` (logistics arrows), toolbar scene bits
- Module shader — `OVERLAY_COLOR` param; `modules/templates/module_base.gd` — `set_overlay_color()` helper beside `_update_shader`
- `ui/ui_main.gd` / `ui_in_game` — toolbar mount, hotkeys, legend
- Data accessors (read-only) on: `atmosphere_component.gd`, `power_consumption_component.gd`, `storage_component.gd` — only if current fields aren't publicly readable already
- `scripts/managers/job_manager.gd` — expose an iterator over waiting+claimed haul jobs with endpoints for the flow layer (claimed jobs: via pawns' `current_job`)

## Implementation order
1. Shader param + controller skeleton + **Power** mode (simplest data) end-to-end.
2. O2 + Integrity (pure gradients).
3. Vibration (after WI-30).
4. Logistics: tint + priority labels, then flow arrows.
5. Legend/hotkeys polish.

## Edge cases
- Overlay + selection/damage shader params simultaneously: overlay **replaces** selection/damage while active, to prevent confusion by combining tints. (Station overlays are for data gathering and are not expected to be on all the time.)
- Stacked layers (corridor + turbolift + module on one cell): each layer's sprite tints from its own module's data — O2 on the corridor, power on the module is correct and informative.
- Logistics arrows for jobs whose endpoint died this frame: guard with `is_instance_valid`; arrows are redrawn per refresh, never retained.
- Paused game: overlays keep refreshing (UI real-time) — values static while paused is correct.
- Mode active during save/load (scene reload): controller re-initializes off; no dangling params (fresh instances default alpha 0).
- Colorblind note: green/red gradients get distinct luminance ends; legend chips carry text.

## Verification
1. Power mode: unpower a wing (kill a generator) → instant red spread exactly matching unpowered consumers; restore → green.
2. O2 mode: fire a breach → module reds and pulses, neighbors drift orange as diffusion drags them down; seal + refill → green wave.
3. Integrity mode: cheat-damage assorted modules → gradient matches HP percentages; damaged truss distinct.
4. Vibration mode: forge cluster glows, falls off with hops per WI-30, rest of station clear.
5. Logistics mode: priorities legible on every storage module; a construction site shows +99 and inbound arrows; conveyor links render; arrows update as jobs complete.
6. Mode switching rapid-fire leaves no stuck tints; `logs_read` clean; frame cost negligible on a large station at 4×.
