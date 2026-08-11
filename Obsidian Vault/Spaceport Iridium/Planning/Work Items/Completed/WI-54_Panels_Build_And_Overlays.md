# WI-54 — Mode Panels: Build & Overlays

> **STATUS: COMPLETE, 2026-08-10.** Sixth item of the [[04_UI_Rework_Program]]. Depends on [[WI-49_UI_Design_System]] and [[WI-50_Console_And_Modes]].
>
> **935 GUT tests green** (was 901; +34 across `test_build_menu_model` and `test_overlay_palette`). **64-check headless probe green** against the real `main.tscn`. Windowed 1920×1080 screenshots captured of Build with a category open (buildable rows, a selected row explaining itself inline, three dimmed locked rows with their gating tech, the cursor ghost hint) and of Overlays with the O₂ ramp live. **Save-neutral** — this item adds no save state.
>
> **Deviations from the design below, and why:**
>
> 1. **Category cycling is `[` / `]`, not the design's `Q/E`.** `E` is `mode_stores` ([[WI-50_Console_And_Modes]] deviation 1), and a key that both opens Stores and steps the rail is precisely the collision that WI's hotkey scan exists to catch. Both are real, remappable actions in `Global.REMAPPABLE_ACTIONS`, and the hint the panel prints is read from the live `InputMap` — so a player who wants Q/E is one rebind away and the panel prints whatever they chose. The edge case's rule is honoured either way: an unbound pair prints **no** hint rather than a hint for a key that does nothing.
> 2. **The facts line reports what a module scene *declares*, not a simulated rate.** The design's `+2.4 ORE/CYC` is not derivable before placement — a mining bay's ore rate depends on its drones, which asteroid they reach, and the operator's skill, so any figure the panel invented would be wrong on every station but the one it was calibrated on. `ModuleFacts` reads the four things a scene states outright and that are true before the module is placed: **power draw, power output, storage capacity, crew seats.** A module declaring none of them gets no line at all. This is the same "never fabricate a zero" rule `ResourceRateTracker.NO_RATE` already follows (WI-52).
> 3. **The flyout is a second `ConsolePanel`, not a floating popup.** It carries the same 56px header and the same foot as the rail beside it, which is what makes 356 + 340 read as one two-stage surface. The frame gained `panel_offset_left` for it; `top_level` is what lets a control inside the rail's content region resolve its anchors against the viewport. It stays a **child** of `BuildMenu` on purpose — `top_level` detaches the transform and *not* the visibility, so closing Build takes the flyout with it for free.
> 4. **The active border moves to the flyout while it is open** and the rail goes inert. This is the mockup's own detail (it overrides the rail panel's right border to `#1d2c40` and gives the flyout `#2f6b80`): the cyan belongs to the outermost edge on screen.
> 5. **`ConsolePanel` gained a footer strip and `SectionLabel` gained a `hint`.** Both panels in this item carry a standing instruction at the foot, and the design draws it as part of the frame — full-bleed, its own top rule, a darker fill — so it belongs to the frame rather than being the last row of two different panels' content. The `CATEGORIES ——— [/]` hint is the same slot and the same weight as a panel header's hotkey because it means the same thing.
> 6. **The selected row expands on focus as well as on being held.** The design's whole argument for inline explanation is that it "survives keyboard and controller navigation", which a hold-only trigger would not. The **live treatment** still marks only the held module — that is the selection.
> 7. **`module_button_tooltip` is kept, restyled and demoted; `module_resource_cost_ui` is deleted.** The inline block makes the tooltip redundant *in the flyout*, but the recent strip's 40px tiles are icon-only with no text at all, and without a hover card a recent tile is an unlabelled picture. Its per-resource cost widgets are `Chip`s now, which is what `module_resource_cost_ui` existed to be.
> 8. **The rail no longer hides a category whose modules are all locked.** With locked entries rendering there is something to show, and a rail that changes length as the tech tree opens up is a rail the player cannot build muscle memory on. Each entry's count counts what is *shown*, so the rail and the flyout header agree.
> 9. **`OverlayPalette` owns the legend table, not the controller.** Every stop is produced by that mode's own colour function at a representative value rather than by naming a colour — the swatch beside "breathable" *is* the tint a breathable module gets, so retuning a gradient cannot leave the legend explaining a colour the station no longer paints. It is keyed by `StringName` rather than by `OverlayController.Mode` so the pure side never reaches into a `Control`; `OverlayController.LEGEND_KEYS` maps the two, and a GUT test pins that the map is total.
> 10. **"Clear overlay" is a row in the same list** (as the mockup draws it) and never takes the live treatment — "no overlay" is the absence of a state, not a state.
>
> **Traps found, for the WIs that follow:**
>
> - **`OS.get_keycode_string(91)` returns `"BraceLeft"`, not `"BracketLeft"`** — despite Godot's own constant being `KEY_BRACKETLEFT = 91`. `ModeManager.HOTKEY_ABBREVIATIONS` missed, and the panel printed `BRACELEFT/BRACERIGHT`. Every probe check passed, because `action_hotkey_label` returned a perfectly valid non-empty string; **only the screenshot showed it.** Both spellings are now in the map.
> - **`ListRow` pins its icon to the 24px list-item square.** The rail's 34px design tile rendered small and nothing failed. `set_icon` takes an optional size now — a rail entry is a *heading*, a list row is a line item.
> - **Containers skip `top_level` children in both `_resort` and `get_minimum_size`.** That is what lets the flyout be a child of the rail's `VBoxContainer` without being laid out by it. Anyone "fixing" it into a sibling loses the visibility coupling in deviation 3 and has to reimplement it.
> - **A screenshot has to be driven into the state under test, not just into the panel.** The first Build capture opened the biggest category, which is `Core` — and `Core` has no locked modules, so the frame was proved and the item's one behaviour change was not. The shot helper now picks the fullest category *that contains an ungranted module*.
> - **`ModuleData.components` is empty on an un-tree'd instance**, because components append themselves from their own `_ready`. `ModuleFacts` walks the node tree instead; `PreviewModule.ModulePreviewData` sidesteps the same problem by looking components up at known paths.

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

*As shipped. `ModuleFacts` is a plain `RefCounted` with no scene — it authors nothing a scene could hold — and its cache lives on the `BuildMenu` that asked, not in a static, so it dies with the HUD instead of holding every inspected `PackedScene` alive across a Quit-to-Menu (the `PreviewModule` rule, WI-42). `preview_module.gd` was **not** touched: the cursor label needs the held `ModuleData`, which `UIInGame` already exposes.*

- **New:** `ui/buttons/module_facts.gd` (`ModuleFacts`), `ui/buttons/build_cursor_hint.gd` + `.tscn` (`BuildCursorHint`)
- **Deleted:** `ui/buttons/module_resource_cost_ui.gd` + `.tscn` — `Chip` is what it was trying to be
- `ui/buttons/build_menu.gd` — rewritten: full-bleed search block, recent strip, `SectionLabel` + cycle hint, `ListRow` rail, the flyout as a second `ConsolePanel`, locked entries, category cycling
- `ui/buttons/module_button.gd` / `.tscn` — rewritten as the flyout row: three states (buildable / selected-and-expanded / locked-and-dimmed) plus the `compact` icon-only tile the recent strip uses
- `ui/buttons/module_button_tooltip.gd` / `.tscn` — rewritten, restyled, demoted to the recent strip's hover card; costs are `Chip`s
- `ui/buttons/build_menu_model.gd` — `sort_bucket`, `gating_unlock` / `gating_label`, `format_footprint` / `format_cost` / `format_facts` / `fact_is_a_cost`
- `ui/overlay_controller.gd` — `ListRow` rows with printed keys, the clear row, the live-mode legend, the footer line
- `ui/overlay_palette.gd` — `MODE_*` keys, `LegendStop`, `legend_stops()`, `legend_note()`
- `ui/theme/console_panel.gd` / `.tscn` — `panel_offset_left`, `footer_text` / `footer_variation`
- `ui/theme/widgets/section_label.gd` / `.tscn` — `hint`
- `ui/theme/widgets/list_row.gd` — `set_icon` takes an optional size
- `ui/theme/ui_metrics.gd` — flyout x, the four Build icon sizes, footer padding
- `ui/console/mode_manager.gd` — bracket-key abbreviations
- `ui/ui_main.gd` — Build panel takes no content padding; the cursor hint is mounted here
- `scripts/managers/global.gd`, `project.godot` — the two category-cycle actions
- `tests/unit/test_build_menu_model.gd`, `tests/unit/test_overlay_palette.gd` — +34 tests

Not touched: `OverlayFlowLayer`, module shaders, `ModuleData` (the `required_unlock` fallback was not needed — the effects walk is cheap and stays the single source of truth), `ClickCycler`, `preview_module.gd`.

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

*As run. 935 GUT green, 64/64 probe checks green, two windowed screenshots.*

1. **GUT (+34).** `test_build_menu_model`: locked entries sort after unlocked within a category, are ordered by name inside each half, and are never dropped (an all-locked category still renders both entries); the input array is never mutated; gating-unlock resolution finds the node whose `GrantModuleEffect` names the module, skips stat-modifier effects, tolerates nulls in authored data, falls back to the unlock's id when it has no display name, and reports `NO_GATE_LABEL` for a module nothing grants; `format_cost` leads with the largest amount and breaks ties by name (a dictionary's iteration order must never decide what the player reads); `format_facts` orders output before draw, omits what a module does not declare, trims whole numbers, and its cost sign is a real U+2212 minus. `test_overlay_palette`: every mode has a multi-stop legend, every stop is labelled and **opaque** (the mode functions return tint *strength* in alpha), the "breathable" swatch equals `o2_color(O2_GREEN_AT)` to three decimals, wreckage never reads as a low-HP module, an unknown key has no legend, only O₂ and Logistics carry a note, and `OverlayController.LEGEND_KEYS` is total over the enum.
2. **Windowed screenshots** at 1920×1080 against mockup screens 3 and 9. Build: 356 + 340, both 56px headers, the flyout header carrying the category name / count / `◀`, a selected row with its inline description and `−5 ENERGY` line, three dimmed locked rows (`NEEDS: GARDEN`, `NEEDS: HOLODECK`, `NEEDS: MEDICAL BAY`) with lock glyphs sorted below the buildable ones, the `CLICK TO HOLD · ESC CANCEL` foot, and the cursor ghost hint reading `CORRIDOR · 10 CREDITS`. Overlays: 360px, six numbered rows with Oxygen live, the O₂ ramp with its breach note, the corridor toggle, and the footer sentence. **Two defects were visible only here** — see the traps in the status block.
3. **Headless probe, 64 checks**, driving the HUD through the same entry points the player uses. Both panels' widths and real heights (the WI-48 zero-height lesson) including the flyout's 356 origin and the pair's 696 total; the rail surviving a category pick, a search, and a step to another category; the flyout header's count agreeing with the rows under it; a locked module rendering, dimmed, with a gating label, sorted after every buildable one, and doing nothing when pressed; the held module's row marked selected and expanded; the cursor hint appearing, naming the module, surviving its panel being closed, and going away when the module is dropped; Esc taking the flyout before the mode; exactly one panel visible at every step across all seven modes; and leaving Build taking its flyout with it.
4. **Regression, in the probe:** affordability — the cost line is not amber while the station can pay, and repaints amber when the stock is drained *without the row being rebuilt*; `module_lock_changed` — force-unlocking a tech with the flyout open un-dims its module in place. Search, the recent strip and the corridor toggle are covered by checks 29–30 and 14. `OverlayFlowLayer` is untouched.
5. **Still owed by a human at the keyboard:** placing a module end to end including flip and multiplacement, and cancelling with Esc at each stage. The probe covers the state machine around it, not the feel of it.

## Related

- [[04_UI_Rework_Program]] — the mode inventory and panel widths.
- [[WI-43_Build_Menu]] — the rail/flyout/search/recent this reframes, and `BuildMenuModel`.
- [[WI-35_UI_Overlays]] — the controller, palette and flow layer being reframed.
- [[WI-42_Preview_Metadata_Cache]] — `PreviewModule`, and the flip-with-nothing-selected crash it fixed.
- [[WI-50_Console_And_Modes]] — the console bar adornments (fill vs. bar vs. dot) and the corridor toggle's new home.
- [[WI-47_Modding_Support]] — modded categories and modules must appear with no core edit.
