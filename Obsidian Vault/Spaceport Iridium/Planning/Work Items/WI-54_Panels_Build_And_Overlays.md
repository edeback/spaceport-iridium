# WI-54 — Mode Panels: Build & Overlays

> **STATUS: planned, not started.** Sixth item of the [[04_UI_Rework_Program]]. Depends on [[WI-49_UI_Design_System]] and [[WI-50_Console_And_Modes]].

## Goal

Convert the two narrowest mode panels — the ones whose content already exists and mostly works — into proper `ConsolePanel`s matching mockup screens 3 and 9.

These two are grouped because they are the cheap ones, and doing them first proves the frame at 360px and at the awkward 356+340 two-stage width before the 1400px R&D tree depends on it. Neither has new gameplay.

## Design

### 1 — Build: two stage, not a drilldown

WI-43 already replaced the overflowing tag accordion with a category rail plus a floating flyout grid, search, and a recent row. The structure is right; the frame and the numbers are not.

`ui/buttons/build_menu.gd` becomes the body of a 356px `ConsolePanel` with a **340px flyout beside it** (696px total, and only while browsing). Deltas from what exists:

| Now | Target |
| --- | --- |
| `FLYOUT_WIDTH = 300.0` | 340 |
| Rail is a `VBoxContainer` of 64px-icon buttons in the left column | Rail inside the panel: search at top, `CATEGORIES` section label with the `Q/E` hint, then the rail |
| Flyout is a floating `PanelContainer` positioned relative to the rail | Flyout is a sibling panel that slides out from the panel's right edge, top-aligned, its own 56px header carrying the category name, its module count, and a `◀` collapse control |
| Category rows are icon buttons | Rows are `ListRow`: name, count, `▸` |
| Recent row of 40px icon-only buttons | Kept as-is, above `CATEGORIES` |

**Module rows in the flyout gain the design's inline explanation.** Today `module_button_tooltip.tscn` shows cost and description on hover. The design puts the selected module's description and its rate/draw line **inline, in the list**, because *"it survives keyboard and controller navigation, and is readable while the ghost is already on the station."* So: every row shows name, cost chips and footprint (`2×2`); the **selected** row expands to add the description and a `+2.4 ORE/CYC` / `−14 ENERGY` line. The hover tooltip can stay for the mouse, but it stops being the only way to read a module.

**Locked modules stay in the list, dimmed, showing their gating tech** — `NEEDS: DRILLING II` with a lock glyph. *"That list is half of what makes R&D legible."* Today an ungranted module's button is hidden (`module_lock_changed` reveals it), so this is a behaviour change: the build menu must render locked entries. `UnlockManager.is_module_granted()` gives the state; the gating unlock's display name comes from walking `UnlockData.effects` for the `GrantModuleEffect` that names this module. If that walk turns out to be awkward, the cheaper fix is a `required_unlock` back-reference on `ModuleData` — but try the walk first, because a back-reference is a second source of truth about the same edge.

**The holding state moves onto the station.** Once picked up, the module is a ghost under the cursor with its cost and `R ROTATE` hint attached, and a `CLICK TO HOLD · ESC CANCEL` line at the panel foot. `PreviewModule` (WI-42) already draws the ghost; this adds the attached label. Keep it as a UI-layer `Control` following the cursor rather than something drawn in the preview's `_draw()` — `_draw()` output cannot be verified headlessly, and there is no reason to make this the exception.

The panel's 56px header: `BUILD`, and `ESC` in the hotkey slot.

`BuildMenuModel` (pure, 16 tests) is **not touched**. It already owns grouping, search and recency, and it should keep owning them; anything new that is a rule (locked-entry ordering, "which unlock gates this module") goes in there with a test rather than into the view.

### 2 — Overlays: a mode, not a flyout

`overlay_controller.gd` today mounts its own toolbar strip at a hardcoded `TOOLBAR_LEFT = 184.0` — a number chosen to clear the left column that WI-50 deletes. The toolbar becomes the body of a 360px `ConsolePanel`, the narrowest in the game.

Body: six rows, each `ListRow` with the overlay name and **its number key printed beside it** — Power 1, Oxygen 2, Integrity 3, Vibration 4, Logistics 5, Clear overlay 0. The active row takes the live treatment. Below them, the corridor-display toggle inherited from WI-50 §8. At the foot, the design's explanatory line: *"The chosen overlay keeps painting the station after this panel closes."*

Then the existing legend, which is the part with real content: each mode's value→colour ramp from `OverlayPalette`, rendered under the row list for the active mode only. A legend for all five at once in 360px is unreadable.

Three properties of the current controller that must survive the move, because each is a considered decision:

- **The panel closes, the overlay stays.** Selecting an overlay and pressing Esc leaves the station painted. The console button keeps a **cyan bar** underneath — distinct from the active-mode fill and from R&D's readiness dot (WI-50 §3), and this is exactly why those are three different adornments.
- **Number keys work with the panel shut.** 1–5 and 0 stay owned by `OverlayController`. The panel exists for discoverability and for the mouse, and *"it makes itself redundant over time rather than replacing the keys."*
- **Session-only, never saved.** A load starts with no overlay. Unchanged.

`OverlayFlowLayer` (the logistics arrows and priority labels drawn over the world) is untouched — it is world-space, not chrome.

### 3 — Why Overlays is a mode at all

*"Overlays obeys the one-panel rule like everything else, so it can never sit on top of Build. That is the whole reason it is a mode rather than a popover."* Today the toolbar coexists with everything and overlaps the left column at some widths. Making it a mode costs one console slot and removes a whole class of overlap bug.

## Files to touch

- `ui/buttons/build_menu.gd` / `.tscn` — panel + flyout geometry, `ListRow` rows, inline selected-module explanation, locked entries, the hold-state hint
- `ui/buttons/module_button.gd` / `.tscn` — row treatment; the expanded selected state
- `ui/buttons/module_button_tooltip.gd` / `.tscn` — demoted to a mouse convenience, or deleted if the inline block makes it redundant
- `ui/buttons/module_resource_cost_ui.gd` / `.tscn` — cost chips via `Chip`
- `ui/buttons/build_menu_model.gd` — only if a new *rule* is needed (locked ordering, gating-unlock resolution); with tests
- `ui/preview_module.gd` — expose what the attached cursor label needs; do not draw the label here
- `ui/overlay_controller.gd` — toolbar → panel body; `TOOLBAR_LEFT`/`TOOLBAR_TOP` deleted; legend reflowed; corridor toggle adopted
- `ui/overlay_palette.gd` — read-only; may gain a `legend_stops()` accessor if the legend currently hardcodes them
- `ui/ui_main.gd` — the corridor checkbox handler moves; `%BuildMenu` unique-name references updated
- `tests/unit/test_build_menu_model.gd` — extended if §1's rules land there

Not touched: `OverlayFlowLayer`, module shaders, `ModuleData` (unless the `required_unlock` fallback is needed), `ClickCycler`.

## Implementation order

1. Overlays first. It is smaller, it has no data-driven list, and it validates `ConsolePanel` at the narrowest width with almost no risk.
2. Build's frame and geometry, content unchanged.
3. `ListRow` category rows and the flyout header.
4. The inline selected-module explanation.
5. Locked entries (the only behaviour change in the item).
6. The hold-state cursor hint.

## Edge cases

- **Flyout + Esc ordering.** Esc level 2 closes the flyout, level 3 closes Build. `UIMain._topmost_esc_claim` already had a `flyout` claim above the panels for exactly this reason and the ordering must survive the WI-50 rewrite.
- **A held preview + an open flyout + Esc.** Level 1 (preview) wins. One press cancels the ghost and leaves the menu open, which is what a player mid-build wants.
- **Closing Build while holding a module** keeps the ghost (WI-50 edge case). The attached cursor label must then survive its panel being hidden — it is parented to the UI layer, not to the panel.
- **`Q/E` category cycling** is printed in the design's header. If it isn't implemented, either implement it or don't print it; a printed hint for a key that does nothing is worse than no hint.
- **Search results and the rail.** Searching should surface matches across categories without closing the rail — *"the category list never scrolls away, so the player keeps their place."* Verify the existing WI-43 behaviour still holds inside the narrower panel.
- **A category with zero visible modules** (everything in it locked, before locked entries render) currently shows an empty flyout. With locked entries rendering, it shows them dimmed, which is better; make sure the count in the header counts what is *shown*.
- **Modded modules and categories** (WI-47 M5/M6) must appear without a core edit. The rail is built from discovered `ui_category` values, and it must not assume the vanilla set.
- **`ui_category` vs `tags`.** The rail groups on `ui_category` only. Nothing in this panel may gate on `ui_category`, and nothing may group on `tags`.
- **Overlay legend at 360px.** Five ramps won't fit; one will. If a mode's ramp still overflows, it scrolls inside the legend region, not the panel.
- **The 1080px+ panels will overlap where the toolbar used to be.** Nothing should be positioned relative to the old left column any more; grep for other hardcoded left offsets while `TOOLBAR_LEFT` is being deleted.

## Verification

1. **GUT:** any new `BuildMenuModel` rule — locked entries sort after unlocked within a category and are never dropped; gating-unlock resolution returns the right display name for a module gated by an unlock, and a sensible fallback for one gated by nothing.
2. **Windowed screenshot** of Build with the Mining category open, against mockup screen 3: 356 + 340 widths, both 56px headers, the selected row's inline description and rate line, a dimmed locked row with its gating tech, and the cursor ghost with its attached cost/rotate hint. And of Overlays against screen 9: 360px, six numbered rows, the footer line.
3. **Headless probe:** open Build, assert the panel and flyout occupy the specified widths and real height (the WI-48 zero-height lesson); assert a locked module appears in its category's row list; assert selecting a category doesn't collapse the rail.
4. **Manual:** place a module from the new flow end to end, including rotate and multiplacement; cancel with Esc at each stage. Activate each of the five overlays from the panel and from its number key, close the panel, confirm the station stays painted and the console bar stays lit, then clear with 0.
5. **Regression:** search, recent list, affordability greying, `module_lock_changed` revealing a newly granted module while the panel is open, the corridor-display toggle in its new home, and the logistics overlay's flow arrows.

## Related

- [[04_UI_Rework_Program]] — the mode inventory and panel widths.
- [[WI-43_Build_Menu]] — the rail/flyout/search/recent this reframes, and `BuildMenuModel`.
- [[WI-35_UI_Overlays]] — the controller, palette and flow layer being reframed.
- [[WI-42_Preview_Metadata_Cache]] — `PreviewModule`, and the flip-with-nothing-selected crash it fixed.
- [[WI-50_Console_And_Modes]] — the console bar adornments (fill vs. bar vs. dot) and the corridor toggle's new home.
- [[WI-47_Modding_Support]] — modded categories and modules must appear with no core edit.
