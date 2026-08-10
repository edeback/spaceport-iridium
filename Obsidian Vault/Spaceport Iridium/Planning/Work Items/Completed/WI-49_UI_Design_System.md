# WI-49 — UI Design System & Panel Frame

> **STATUS: COMPLETE, 2026-08-10.** First item of the [[04_UI_Rework_Program]]. Palette, type and geometry values come from that doc, which is the single authority — do not re-transcribe them from the mockup here.
>
> **739 GUT tests green** (was 683; +56 across `test_ui_palette` and `test_ui_theme`). Save-neutral — this item adds no save state. Verified with windowed 1920×1080 screenshots of the main menu, difficulty picker, settings, save/load, the in-game HUD, the converted minimap and jobs panel, and a full regression walk of research, contracts, economy, pause, module info and pawn info.
>
> **Deviations from the design below, and why:**
>
> 1. **A third pure file shipped: `ui/theme/ui_type.gd` (`class_name UIType`).** The design named only `UIPalette` and `UIMetrics`, but type-variation names are a contract between a `.tres` entry and a `theme_type_variation` assignment tied together by a bare string — a misspelling renders as the plain base type and nothing errors. This is the [[WI-41_Group_Constants]] argument applied to theme variations, so it got the same treatment.
> 2. **The theme was generated from `UIPalette` once, then checked in as the artifact of record.** Hand-transcribing ~40 palette colours into `.tres` float triples is exactly the drift the item exists to prevent, so a throwaway generator built the `Theme` from `UIPalette` and saved it; the generator was then deleted. `tests/unit/test_ui_theme.gd` guards the agreement from here on (and pins the uid `project.godot` points at, which the save dropped and had to be restored by hand).
> 3. **`HatchBar` is an eighth widget.** `StatBar`'s striped fill is four lines of `_draw()` and would otherwise have been a texture asset needing re-authoring every time the palette moved. Script-only, used inside `stat_bar.tscn`.
> 4. **Each widget got a `static func create()`.** Panels are code-built (decision 8), so `.tscn` widgets needed a one-call instantiation path; scene authors can still drop the `.tscn` in.
> 5. **The legacy info-panel window chrome was re-tinted, not left alone.** `pawn_info_panel`, `module_info_ingame_panel`, `turboshaft_panel` and `asteroid_info_panel` share a bright-blue Kenney `NinePatchRect` background. Against the new text ramp its labels became unreadable, which fails this item's own regression bar, so their `self_modulate` now lands on the palette's surfaces. WI-51 replaces the chrome outright; this is only enough to keep them legible until it does.
> 6. **MSDF turned out to be a non-issue.** The imported UI fonts already carry `multichannel_signed_distance_field=false`; the project setting only affects Godot's *built-in* default font, which the theme now replaces. 9px mode labels and 11px meta lines render sharp at 1×.
>
> **Traps found, for the WIs that follow:**
>
> - **`TextureRect.stretch_mode = 1` is TILE, not SCALE** (`STRETCH_SCALE` is `0`). A tiled 1×64 header gradient happens to *look* like a gradient at 56px tall, so this hid in the panel header and only showed up as a dashed section rule.
> - **`_get_minimum_size()` is ignored on `Button` subclasses.** `Button` overrides `get_minimum_size()` in C++ and never consults the script virtual, so `ListRow` had to drive `custom_minimum_size` off the inner row's `minimum_size_changed` instead. Every row rendered at 28px with the meta line spilling out until this was found.
> - **Godot resolves theme items up the *class* chain**, so `CheckBox`/`CheckButton` inherit `Button/styles/normal` and render as filled buttons with a tick unless they are given their own entries. Any new base-control entry needs the same audit.
> - **`self_modulate` multiplies the theme's font colour**, so a palette colour passed through it comes out muddy. `add_theme_color_override("font_color", …)` is the channel that actually sets text colour.
> - **Frame node lookups must be lazy.** Exported setters run during scene load before children exist, and callers configure a frame before mounting it — the [[WI-48_Pawn_Interactions]] call-order lesson, applied to the frame everything else is built on.

## Goal

Build the shared visual foundation the whole rework stands on: a real `Theme`, the type scale, the palette as code, **one panel frame**, and the handful of widgets that repeat across every screen.

This is step 01 of the mockup's own build order, and its rationale is the reason this is a separate work item: *"Extract the shared panel frame first — 56px header, 34px readout header, edge, inner highlight, hotkey slot. Every later step gets cheaper, and this alone closes most of the polish gap."* Invariant 6 says the same thing from the other end — **most of what looks unfinished today is frame inconsistency, not placement.**

Nothing in this item changes what the player can do. It changes what everything looks like.

## Design

### 1 — The theme is currently empty, and that is the actual problem

`ui/themes/base_theme.tres` is three lines with no properties. It is wired up as `gui/theme/custom` in `project.godot`, so every `Control` in the game is running on Godot's defaults, and each screen that wanted to look deliberate hand-authored a `StyleBoxFlat` inside its own `.tscn` (`ui_main.tscn` alone carries several, with 16px corner radii and 6px black borders that appear nowhere in the design).

So the first task is not "add a theme on top", it is **fill in the real theme and then delete the local overrides that fight it**. A local override that agrees with the theme is worse than no override, because the next person changing the theme won't find it.

### 2 — Palette and metrics as code, not as magic numbers

`ui/theme/ui_palette.gd` (`class_name UIPalette`) — all `const Color`, named exactly as the program doc's palette table (`VOID`, `PANEL`, `CONSOLE`, `EDGE`, `DIVIDER`, `LIVE`, `ATTENTION`, `GROWTH`, `DESTRUCTIVE`, `TEXT`, `TEXT_EMPHASIS`, `TEXT_SECONDARY`, `TEXT_META`, plus the supporting values). Static helpers for the things the mockup does repeatedly:

- `panel_header_gradient()` / `readout_header_gradient()`
- `tinted(color, alpha)` for the `rgba(79,191,217,.06)` row fills
- `amber_row()` / `live_row()` / `inert_row()` — the three list-row treatments, because every list in the design uses the same three
- `sign_color(value)` → LIVE positive, ATTENTION negative, TEXT_META zero. Used by the ledger, the trade table, the stores stepper and the economy tab, and it is exactly the sort of rule that drifts if four panels each write it.

`ui/theme/ui_metrics.gd` (`class_name UIMetrics`) — the geometry table as `const`: `CONSOLE_HEIGHT = 112`, `MODE_BUTTON = Vector2(70, 74)`, `PANEL_HEADER_HEIGHT = 56`, `READOUT_HEADER_HEIGHT = 34`, `RIGHT_COLUMN_WIDTH = 344`, `SCREEN_GUTTER = 20`, `INSPECTOR_WIDTH = 420`, and the per-panel widths.

**Why constants and not exported vars:** these are not balance numbers (which belong in `.tres` per the standing invariant) — they are a design system. A panel whose width can be edited per-instance is a panel that will end up 358px wide in one scene.

`OverlayPalette` (WI-35) stays separate and untouched: it maps *gameplay values* to colors for the station tint, which is a different job from chrome colors. It may read `UIPalette` for its endpoints if that is genuinely the same cyan.

### 3 — Type variations carry the tracking

Godot fonts have no letter-spacing. The design leans on tracking heavily (`.18em` panel titles, `.20em` readout labels, `.16em` meta lines), and the only way to get it is `FontVariation.spacing_glyph`. So the type scale must be **theme type variations**, not per-label font overrides:

| Variation name | Face | Size | Tracking | Use |
| --- | --- | --- | --- | --- |
| `PanelTitle` | Chakra Petch 700 | 15 | .18em | Panel header |
| `ReadoutLabel` | Chakra Petch 600 | 11 | .20em | Readout header, section labels |
| `EntityName` | Chakra Petch 600–700 | 14–18 | 0 | Crew/module names |
| `Metric` | IBM Plex Mono 700 | 13–16 | 0 | Every number |
| `MetaLine` | IBM Plex Mono 500 | 10–11 | .06em | Status/meta lines |
| `ModeLabel` | Chakra Petch 600 | 9 | .10em | Console button labels |
| `Hotkey` | IBM Plex Mono 500 | 11 | 0 | Header hotkey slot |
| `TabLabel` | Chakra Petch 600 | 12 | .10em | Tab strips |
| `Body` | IBM Plex Sans 400 | 13 | 0 | Prose, descriptions, tooltips |

Caps is a *content* decision, not a font one — Godot has no text-transform. Labels that read as caps in the design are authored in caps, or upper-cased at the one place that formats them. Do not scatter `.to_upper()` through panel code; put it in the widget that owns the label (`ReadoutHeader`, `ModeButton`, `SectionLabel`).

**No italics anywhere, and no icon fonts in the HUD** — both are explicit design rules. Existing icons stay as the SVG/PNG textures in `ui/icons/`.

### 4 — The frame: two headers and one panel

`ui/theme/console_panel.tscn` + `console_panel.gd` (`class_name ConsolePanel`) — the left-mounted mode panel frame. Exactly one implementation, used by all seven modes:

- Fixed `panel_width`, top-of-screen to top-of-console, left-anchored.
- Background PANEL, 1px right border in `#2f6b80` when this panel is the active mode, `EDGE` otherwise; 1px inner top highlight; a 28px outward drop shadow so it reads as floating over the station.
- **56px header:** a 3×20px LIVE accent bar, the title in `PanelTitle`, an optional divider + subtitle in `ReadoutLabel` grey (the "6 ABOARD · 4 BUNKS" / "2 UNREAD" slot — every panel has one), a flex spacer, then a right-aligned slot that holds the hotkey hint (`ESC`) and, for panels that need it, one header control (R&D's balance chip).
- A content region below the header that the panel fills. `ConsolePanel` provides no scrolling — panels that need it add their own `ScrollContainer`, because they differ on whether the header row scrolls with the content.

`ui/theme/readout_panel.tscn` + `readout_panel.gd` (`class_name ReadoutPanel`) — the right-column surface: the same body treatment with the **34px** header instead (3×14px accent bar whose color is the panel's own — LIVE for the map, ATTENTION for alerts — the label in `ReadoutLabel`, spacer, then a slot for actions like `HISTORY` / `CLEAR ALL` / the `M` hotkey). Used by the station map, the alert feed, and the inspector.

**The two headers are different heights on purpose** and that difference is what makes the hierarchy read, so `ReadoutPanel` must not be `ConsolePanel` with a parameter.

### 5 — The widget library

Small, boring, and used everywhere. Each is `.tscn` + script under `ui/theme/widgets/`:

- **`StatBar`** — label, value, and an 8px bar with a 1px EDGE border and the design's `repeating-linear-gradient` hatch fill. Tint from `UIPalette.sign_color` or an explicit color. This replaces every hand-built `ProgressBar` + `Label` pair in the codebase (`pawn_info_panel._make_stat_row`, `module_info_ingame_panel._build_hp_row`, the needs tab, the robot rows).
- **`Chip`** — icon + text + optional value, in the three row treatments. Storage contents, trade categories, filter pills.
- **`Stepper`** — `−` value `+` with a wide hit target, sign-colored value, and a configurable range/step. Used by Stores (priority −100…+100), Trade (order lines) and desired amounts. Currently three different `SpinBox` setups, one of which needed a theme (`spinbox_theme.tres`) to be usable at all.
- **`TabStrip`** — the design's tab row (active tab has a LIVE-tinted fill, a `#2f6b80` border with no bottom edge, and sits on a 1px EDGE underline). A `Control` that emits `tab_selected(id)`; it does **not** own its pages. This is deliberate: `TabContainer` couples the strip to the children and hides/reveals them by index, which is what made WI-48's deferred `set_tab_hidden` bug possible and what makes a per-component tab set awkward. Panels and the inspector own their page swapping.
- **`ListRow`** — the recurring "icon / name over meta line / right-aligned metric or action" row in the three treatments, with a `pressed` signal. Alerts, comms, crew, stores and trade rows are all this row.
- **`SectionLabel`** — accent bar + caps label + trailing gradient rule.
- **`ActionButton`** — the design's three button weights: primary (LIVE tinted fill, LIVE border), secondary (`#101a26` fill, `#24384f` border) and **destructive (outline only, never filled)**. The outline rule is a stated invariant; encode it here so no panel can get it wrong.

### 6 — Pilot conversions

Two conversions ship with this item, to prove the frame at both header sizes and to make the diff visible before nine panels depend on it:

- **`ui/minimap.tscn` → `ReadoutPanel`.** It already anchors top-right at roughly the right width and manages its own collapse, so it is the cheapest real test. Its `_draw()` content is untouched; only the frame changes.
- **`windows/jobs_screen.gd` → `ConsolePanel`.** A code-built full-rect panel today. Reparenting it into a fixed-width left panel with a real header is the exact operation WI-50 will perform seven more times, and doing one now is how the frame's API gets found wanting while it is still cheap to change. It stays reachable from its current side button until WI-50 removes that button.

Everything else keeps its current look until its own WI. **They will look inconsistent for a while**, and that is the accepted cost of an incremental rollout.

### 7 — What must be deleted, not layered over

- The `StyleBoxFlat` sub-resources in `ui_main.tscn` and any other `.tscn` whose intent the theme now covers.
- `ui/themes/spinbox_theme.tres` — folded into the theme's `SpinBox`/`LineEdit` entries, or made obsolete by `Stepper`.
- Per-label `add_theme_color_override` calls that are just "make this text grey/amber/red". There are dozens; they become type variations or `UIPalette` reads. The ones that stay are genuinely dynamic (a bar that turns amber below 50).

Grep targets for the sweep: `add_theme_color_override`, `add_theme_stylebox_override`, `add_theme_constant_override`, `add_theme_font_size_override`.

## Files to touch

- **New:** `ui/theme/ui_palette.gd`, `ui/theme/ui_metrics.gd`, `ui/theme/console_panel.tscn` + `.gd`, `ui/theme/readout_panel.tscn` + `.gd`, `ui/theme/widgets/{stat_bar,chip,stepper,tab_strip,list_row,section_label,action_button}.tscn` + `.gd`, `tests/unit/test_ui_palette.gd`
- `ui/themes/base_theme.tres` — the real theme: default font, type variations, and entries for `Button`, `Label`, `PanelContainer`, `LineEdit`, `SpinBox`, `ScrollContainer`, `HSlider`, `CheckBox`, `CheckButton`, `Tree`, `TooltipPanel`
- `ui/minimap.tscn` / `minimap.gd` — pilot conversion
- `ui/windows/jobs_screen.gd` — pilot conversion
- `ui/ui_main.tscn` — delete the obsolete style sub-resources
- Every `.gd` carrying a theme override the theme now covers (sweep, §7)
- Remember: `filesystem_manage(op="scan")` after the new `class_name` files, and `godot --headless --import` if the editor's class cache goes stale

Not touched: `menus/*` (the out-of-game flow adopts the theme for free and is otherwise left alone), `overlay_palette.gd`, anything world-space.

## Implementation order

1. `UIPalette` + `UIMetrics` + `test_ui_palette` — pure, and everything else reads them.
2. Fonts into the theme with the type variations. **Check the tracking renders** before building anything on it; if `spacing_glyph` doesn't give the look, the whole type scale needs rethinking and it is better to know now.
3. Theme entries for the base controls. The game is now uniformly re-skinned and still fully playable — this is the single largest visual delta in the program and it is reversible in one file.
4. `ConsolePanel` + `ReadoutPanel`.
5. The widget library.
6. The two pilot conversions.
7. The override-deletion sweep.

## Edge cases

- **A theme that changes control metrics changes layout everywhere.** Godot content margins and minimum sizes come from the theme, so a fatter `Button` stylebox silently reflows the main menu, the settings page and every existing panel. Step 3 needs a pass over the *out-of-game* menus too, even though they are otherwise out of scope.
- **MSDF is on.** `theme/default_font_multichannel_signed_distance_field=true` in `project.godot`. It is good for scaling but softens small text; verify 9px mode labels and 11px meta lines are legible at 1×, and be prepared to turn MSDF off for the UI fonts specifically (per-font import setting, not a project one).
- **Tracking and centring fight.** `spacing_glyph` adds space *after* every glyph, including the last, so a centred caps label with heavy tracking sits visibly left of centre. Compensate in the widget (a matching right-side offset), not per label.
- **`Stepper` must not re-post jobs on every keystroke.** Storage priority goes through `update_priority()`, never a field write (WI-45 A5), and holding `+` from −100 to +100 must not fire 200 re-sorts. Debounce or commit on release.
- **`TabStrip` with no pages** is legal and renders empty rather than erroring — the inspector's nothing-selected state and a module with no component UIs both hit it.
- **Do not theme the world.** Modules use a shader with `OVERLAY_COLOR` (WI-35); nothing in this item may touch module materials.
- **Panku's console** (backtick REPL) is an addon `Control` inside the tree. If the theme makes it unusable, exclude it rather than styling it.

## Verification

1. **GUT:** `test_ui_palette` over `UIPalette.sign_color` (positive/negative/zero, and exactly-zero floats), `tinted` alpha clamping, and `UIMetrics`' derived values (panel bottom = screen height − console height; inspector top = screen height − console − gutter − inspector height).
2. **Windowed screenshot, mandatory.** This item's entire output is visual and headless cannot see it. Capture: the main menu, the in-game HUD, the converted minimap, and the converted jobs panel. Compare the two converted frames against the mockup's screens 1 and 4 for header height, accent bar, border colour and hotkey placement.
3. **Legibility at 1×** for the 9px mode label and the 11px meta line, and again at whatever the smallest resolution the settings menu offers is.
4. **Regression:** every existing panel still opens, closes, and reads correctly after the theme lands and the overrides are deleted — walk all of them (build menu, both info panels, turboshaft, trader, trade, contracts, economy, research, jobs, recruitment, event card, minimap, overlays, pause, settings, save/load, game over). This is the boring check that catches the theme reflowing something.
5. **Probe caveat:** if a headless probe is used for anything here, it must instantiate the real scene and mount it exactly as its caller does — WI-48 showed a tab that passed every data check while rendering at zero height because the probe built it in-tree and the caller builds it out of tree.

## Related

- [[04_UI_Rework_Program]] — palette, type and geometry tables; the invariants this frame implements.
- [[WI-50_Console_And_Modes]] — the immediate consumer; every mode mounts a `ConsolePanel`.
- [[WI-35_UI_Overlays]] — `OverlayPalette` stays separate; the distinction between gameplay colour and chrome colour.
- [[WI-36_Main_UI_Flow]] — the out-of-game menus that inherit the theme without being redesigned.
- [[WI-48_Pawn_Interactions]] — the `TabContainer` deferred-`set_tab_hidden` trap and the zero-height-tab lesson, both of which motivate `TabStrip`.
