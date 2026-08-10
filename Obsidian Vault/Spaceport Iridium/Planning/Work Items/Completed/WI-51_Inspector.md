# WI-51 — The Inspector

> **STATUS: COMPLETE, 2026-08-10.** Third item of the [[04_UI_Rework_Program]]. Built on [[WI-49_UI_Design_System]]'s `ReadoutPanel`/`TabStrip`/`StatBar` and [[WI-50_Console_And_Modes]]' Esc ladder.
>
> **823 GUT tests green** (was 768; +30 in `test_mood_catalog`, +25 in `test_inspector_tab_plan`). **73-check headless probe green** against the real `main.tscn` — including a sweep that builds **all 45 modules** and opens **every one of their 135 tabs**, asserting each renders at real height. Windowed 1920×1080 screenshots captured for all five tab sets, four module tabs, and the inspector with Build open. Save-neutral — this item adds no save state.
>
> **Five panels became one and three files were deleted outright:** `pawns/pawn_info_panel.{gd,tscn}`, `windows/module_info_ingame_panel.{gd,tscn}`, `windows/turboshaft_panel.{gd,tscn}`, `component_ui_panels/asteroid_info_panel.{gd,tscn}`, `component_ui_panels/resource_pile_inventory_tab.{gd,tscn}`, plus `pawns/pawn_needs_tab.tscn`. `ui_main.gd`'s four click handlers and five Esc claims collapsed into `inspector.select()` and one `&"selection"` claim.
>
> **Deviations from the design below, and why:**
>
> 1. **`InspectorTabPlan` is a second pure class, and it keys on the *component*, not the component UI.** §3 says to fix the tab order and shorten the labels but leaves the rule in the panel; the program doc's own risk list says a rule inside a panel is a rule nobody can test, so it became `ui/inspector/inspector_tab_plan.gd` with 25 tests. Keying on the component's `class_name` rather than on the UI's node name matters twice over: the tab strip is built **before** any page exists (pages are made lazily, one per tab the player opens), so a UI-keyed table would force all seventeen component UIs to be instantiated just to learn their names — and the node names are exactly what the design is renaming.
> 2. **`ConstructionComponent.has_ui()` now returns false once a module is Built.** With DECONSTRUCT/DEMOLISH moved to the footer, the Build tab had nothing left in it — a progress bar pinned at 100%. It is a progress readout, so it exists while there is progress. The two buttons and their `.tscn` rows are gone from `construction_component_ui`.
> 3. **`subject_gone` became a per-frame validity poll in the panel, not a signal from each set.** §5 asks for one `subject_gone` path; the honest version is `is_alive()` on the tab set plus one `is_instance_valid` check per frame in `InspectorPanel._process` while something is selected. A `tree_exiting` connection would have been cheaper but is **wrong for pawns**: `PawnBase.reparent()`s across canvas layers constantly, which fires `tree_exiting` on a perfectly live pawn. Sets that know sooner (asteroid `despawning`, pile `despawning`, a merged shaft) still emit `subject_lost`; the poll is the backstop under all five.
> 4. **`TabStrip`'s row became an `HFlowContainer`.** A module with eight tabs (ore processor: Output / Power / Stores / Stores 2 / Crew / Air / Upgrades) ran straight off the right edge of a 420px panel with three tabs unreachable. The strip now wraps and reports its own height. WI-49's widget had no other consumer yet, so this is a widening rather than a break.
> 5. **`hides_inspector` shipped as a duck-typed declaration with no current users.** §Edge-cases says the Trade/R&D hiding "is a per-panel flag or it is nothing". It is the flag: `UIMain._on_mode_changed` reads `panel.get(&"hides_inspector")` the same way `ModeManager` finds `on_opened`/`on_closed`. No panel declares it today — the five narrow modes shouldn't, and WI-55's two wide ones don't exist yet.
> 6. **The mood breakdown's duration column reads a *cause* for permanent modifiers, and `MoodCatalog` owns the happiness formula.** §4 asked for the first; the second came out of writing the test. `PawnNeedsComponent._recompute_happiness` now calls `MoodCatalog.combine(needs_average(), sum)`, so the breakdown the tab renders is arithmetically the same operation the sim ran — clamp included. Without that they were two transcriptions of one formula, and the clamp case (0.98 + 0.05 reads 100%, not 103%) is exactly where they would have diverged.
> 7. **Two `.tscn`-authored pages were rewritten as code, three were kept.** `asteroid_info_panel`, `resource_pile_inventory_tab` and `turboshaft_panel` were mostly their own frame plus their own close button, both of which the inspector supplies — so they became code-built pages (`AsteroidContentsTab`, `PileContentsTab`, `TurboshaftFloorsTab`, `TurboshaftCabsTab`). `pawn_needs_tab` went the same way because the breakdown is a list of unknown length. The other five pawn tabs and all sixteen component UIs kept their scenes.
> 8. **Component UIs were flattened in one place rather than restyled in seventeen.** Every one is a `PanelContainer` that used to sit in a `TabContainer` and so draws its own surface; stacked inside the inspector's surface that reads as a box in a box. `InspectorPanel._adopt_page()` overrides the panel stylebox to empty for any `PanelContainer` page — which also covers a modded component's UI (WI-47) for free. Targeted restyles landed only where the old look actually broke: the needs and skills tabs onto `StatBar`, the social tab's hand-mixed colours onto `UIPalette`.
>
> **Traps found, for the WIs that follow:**
>
> - **Measuring a page once is not enough.** The processor tab's recipe line is an autowrapped `Label` with a 200px minimum width; measured before layout hands it the panel's 400px, it asks for roughly twice the height it will actually need. `_refit` latched that and rendered the panel at its full 668px cap around three lines of content. The fix is `minimum_size_changed` → deferred, re-entrancy-guarded re-fit — the same shape as `ListRow._refit` (WI-49) and `pawn_social_tab._fit_scroll_height` (WI-48). **Any panel that sizes itself to its content needs this, not one measurement.**
> - **`ScrollContainer` reports a minimum height of zero** — WI-48 deviation 8, and it bit twice more here: `LocalUpgradesTab` (*is* a ScrollContainer) and `WorkspaceTab` (contains one) both rendered at nothing inside a self-sizing panel while every row underneath was correct. Inside the old `TabContainer` it never showed, because the container handed every page the full panel. Both now drive `custom_minimum_size.y` from their list, capped. **The 45-module × 135-tab sweep is what found them; five hand-picked modules would not have.**
> - **`bool(null)` is not constructible in GDScript.** `Object.get()` on an undeclared property returns null, so a duck-typed boolean check has to be `declared is bool and bool(declared)`, never `bool(panel.get(...))`. The cast throws at runtime, not at parse time.
> - **Do not `queue_free` a confirmation dialog's parent out from under it.** The Fire dialog is parented to `UIMain`, not to the tab set, because the set is freed the moment the selection changes — and a dialog that vanishes mid-question is worse than one that outlives its panel.
> - **A tab set is a `Node`, deliberately.** Every set watches something (a module's components, a pawn's schedule, a shaft's floors); as a `RefCounted` its connections would outlive it in ways that repaint a panel showing a different subject. `queue_free` on selection change is what makes "one inspector" actually one.
>
> **Known follow-ups, not this item's:**
>
> - The **jump-to camera half of §6 is exposed but unwired**: `InspectorPanel.select()` and `camera_target()` both exist and are probe-covered, but nothing calls `GameCamera.jump_to()` with the result yet. WI-53's alerts are the first consumer.
> - `ui/windows/module_info_panel.tscn` is a dead stub with an inline `class_name ModuleInfoPanel` and no references. It predates this item and was left alone.
> - `ConsoleBar` warns that ten console buttons need 745px against a 715px reserve. Pre-existing from WI-50, unrelated to selection.

## Goal

Collapse every selection surface into **one** 420px bottom-right panel with a swapped tab set (invariant 2), and — per the Phase-4 brief — make the pawn view actually complete, including **breaking out every mood modifier that feeds the happiness number**.

This is the single largest reduction in surface count in the program. Five panels become one:

| Today | Behaviour |
| --- | --- |
| `pawns/pawn_info_panel.tscn` | Floats at the pawn's screen position and **follows it every frame** (`_process` sets its position from `get_global_transform_with_canvas()`) |
| `windows/module_info_ingame_panel.tscn` | Fixed panel, toggled |
| `component_ui_panels/asteroid_info_panel.tscn` | Instantiated fresh per click |
| `component_ui_panels/resource_pile_inventory_tab.tscn` | Instantiated fresh per click |
| `windows/turboshaft_panel.tscn` | Fixed panel, per-shaft |

A panel that chases its subject across the screen is the clearest single symptom of the problem this program exists to fix: it overlaps the station, it overlaps other panels, it moves while you read it, and it means selection has no fixed place to be. Invariant 2 fixes the position; invariant 3 (right edge never moves) means opening Build no longer shifts what you were reading.

## Design

### 1 — One surface, five tab sets

`ui/inspector/inspector_panel.tscn` + `inspector_panel.gd` (`class_name InspectorPanel`): a `ReadoutPanel` at `right: 20px, bottom: 132px`, width 420, bottom-anchored so it grows upward with its content. It owns:

- **Header** — `SELECTED · <KIND>`, and a `✕` in the action slot. The header caption is the tab set's name, which is how the player knows the tab strip changed.
- **Subject block** — 50px icon, entity name in `EntityName`, and a meta line. The meta line is per-kind and is where the design puts the number you shouldn't have to open a tab for: a crew member's assignment and wage; a module's sector, crew occupancy **and haul priority** (surfaced early on purpose — Stores is where it is edited in bulk, but you can *see* it here).
- **A `TabStrip`** and a content region it swaps pages into.
- **A footer action slot** — the module set's `DECONSTRUCT` / `DEMOLISH` pair, outline-only (invariant 5, and `ActionButton`'s destructive weight enforces it).

`SelectionKind { NONE, CREW, MODULE, ASTEROID, PILE, TURBOSHAFT }`. One entry point, `select(subject: Variant)`, which resolves the kind, builds the tab set, and remembers the previously chosen tab **per kind** so clicking through five crew members doesn't send you back to Needs each time.

### 2 — Nothing selected is a state, not a hidden panel

*"When nothing is selected the surface shrinks to a single line of text rather than vanishing."* The panel renders `NOTHING SELECTED — CLICK A MODULE OR CREW MEMBER` with a blinking caret. This matters more than it looks: a panel that vanishes teaches the player that the bottom-right is sometimes empty space they can click through to the station; a panel that stays teaches them where selection lives. Everything above it (map, alerts) keeps its position either way.

### 3 — Which tabs, per kind

**Port everything the game has.** The mockup shows four crew tabs; there are six, and the brief is explicit that the mockup is a style guide.

**CREW** — `Needs`, `Job`, `Skills`, `Kit`, `Schedule`, `Social`. Existing tabs from `ui/pawns/`, restyled onto `StatBar` and `TabStrip`. The three code-built readout blocks currently injected under the name row become part of the subject block or a tab:

- Crew wage + Fire button (WI-25) → subject meta line + footer action.
- Robot energy/integrity bars + state line (WI-28) → a **`Vitals`** tab replacing `Needs` (robots have no needs component). Robots also have no `Schedule`, `Skills`, `Social` or `Kit`-with-needs — the tab set is derived from *which components the pawn carries*, which is already how the game distinguishes its three pawn specialisations. Do not add `is_robot` checks; ask for the component.
- Visitor wallet + stay-remaining (WI-33) → subject meta line.

**MODULE** — the existing per-component tabs, unchanged in *content*. `ModuleBase.components` is walked, `ComponentBase.has_ui()`/`get_ui()` supplies each tab, and the 17 component UIs are restyled but keep their logic. Plus `local_upgrades_tab` when the module has upgrades, and `workspace_tab` when it has a workspace. The mockup's `OUTPUT / POWER / STORES / UPGRADES` is a *naming and ordering* guide, not a mandate to merge components: use it to fix the tab **order** (production, then power, then storage, then upgrades) and to shorten the labels, which currently default to the component's node name.

The integrity bar and the Environment section (WI-24, WI-30), currently injected between header and tabs, move into the subject block (integrity, as a `StatBar` with the damaged/broken/breached status line) and a **`Environment`** tab (the adjacency field list plus the concrete rest-quality line).

**ASTEROID**, **PILE** — single-tab sets, ported as-is.

**TURBOSHAFT** — `turboshaft_panel`'s floor list, cab purchase/removal, shutdown and cab positions become a tab set on this surface. It is per-shaft rather than per-module and its header caption says so (`SELECTED · TURBOSHAFT`), which is clearer than today's behaviour of silently opening a different panel than the one you'd expect from clicking a module.

**CORRIDOR** — the mockup names corridor as a fourth tab set. Corridors are `ModuleBase` instances on the CORRIDOR layer and will resolve as MODULE with whatever components they carry; no special case is needed unless a corridor turns out to have nothing to show, in which case it gets a one-line "structure only" set rather than an empty tab strip.

### 4 — The mood breakdown

The brief: *"'Needs' pane should also break out all the mood modifiers that go into the 'happiness' calculation."*

Happiness today (`pawn_needs_component._recompute_happiness`) is the **mean of the needs** — sleep, hunger, recreation, and health when the component exists — **plus the sum of every active modifier**, clamped to 0…1. The Needs tab shows five bars and nothing about the second half of that formula. There are **13 modifier sources** and a player has no way to learn any of them:

| id | Source | Duration |
| --- | --- | --- |
| `good_shopping` | `shop_component.gd:119` | finite |
| `good_lodging` | `sleep_component.gd:113` | finite |
| `<disease id>` | `pawn_disease_component.gd:194` | INF while sick |
| `difficulty` | `pawn_needs_component.gd:140` | INF |
| `exhausted` | `pawn_needs_component.gd:187` | INF while awake past the threshold |
| `<trait id>` | `pawn_traits_component.gd:117` | INF |
| `exterior` | `pawn_traits_component.gd:141` | INF while outside |
| `bad_chat` | `socialize_component.gd:264` | finite |
| `company` | `socialize_component.gd:320` | INF, re-derived |
| `interrupted_meal`, `good_meal`, `bad_meal` | `action_eat.gd:150,164,168` | finite |
| `<event id>` | `event_manager.gd:179` | per-effect |

They are bare `StringName` ids with no display metadata, so the tab cannot render them without something new. Two pieces:

**`scripts/utility/mood_catalog.gd` (`class_name MoodCatalog`)** — pure, static, GUT-testable. Maps a modifier id to `{ label: String, blurb: String }`, with fallbacks for the three **dynamic** id families that cannot be enumerated: a disease id resolves through `DiseaseData.by_id()`, a trait id through the trait's own `.tres`, an event id through `EventData`. Unknown ids fall back to `String(id).capitalize()` rather than being hidden — a modifier the player can't see is worse than one with an ugly name, and hiding unknowns would mean a modded event's mood effect silently disappears from the UI.

**`PawnNeedsComponent.get_modifier_breakdown()`** — returns the live `_modifiers` dictionary as a typed array of `{ id, value, hours_remaining }` (`INF` for permanent), sorted by absolute value descending. The component already owns this state; it just has no accessor, and the tab must not reach into `_modifiers` directly.

The tab then renders, under the bars:

```
HAPPINESS  62%
  needs average            71%
  Well fed                +5%   3h
  Optimist                +4%
  Cramped quarters        −6%
  Void sickness (stage 2) −9%   while sick
```

The needs-average line is not decoration — it is the only way to tell "my crew are miserable because the station is failing them" from "my crew are miserable because of a run of bad events", and those have completely different fixes. Values render as percentage points with `UIPalette.sign_color`; the remaining-duration column reads a duration for finite modifiers and a *cause* for permanent ones ("while sick", "while outside", "trait", "difficulty"), because "∞" answers the wrong question.

### 5 — Selection routing

`ui_main.gd` currently has four near-identical click handlers (`pawn_clicked`, `module_clicked`, `asteroid_clicked`, `resource_pile_clicked`), each with its own instantiate/free/toggle-on-reclick logic and its own bracket bookkeeping. They collapse into `InspectorPanel.select()` plus the existing `ClickCycler` for stacked module cells (WI-10), which stays as-is — it arbitrates *which* module a click means, which is a different problem from what the panel does with it.

**Selection brackets** (`UIInGame.module_brackets` / `pawn_brackets`) stay two instances, but the reason changes. Today it is "both info panels can be open at once"; with one inspector, only one thing is selected, so one bracket instance is live at a time. Keep both objects (module brackets are driven by `ModuleBase.selected`, pawn brackets by the panel) and have the panel clear the other kind on select — a stale bracket around a deselected pawn is exactly the bug the existing `clear_if_target` guard exists to prevent, and it gets easier to reason about, not harder.

The pawn panel's per-frame `_process` reposition **is deleted**. What survives is its liveness check: `if not is_instance_valid(pawn)` → clear the selection. That check should move to a `subject_gone` path that works for all five kinds (a module can be destroyed, a pile collected, an asteroid mined out, a shaft merged away).

### 6 — Jump-to target

[[WI-53_Alerts]] wants "clicking an alert jumps to the pawn or module it names", and the Crew and Stores panels want row clicks to select. All three need the same two operations: **select this subject in the inspector** and **move the camera to it**. Expose them here as `InspectorPanel.select(subject)` and reuse `GameCamera.jump_to()` (which the minimap already drives, WI-34). Nothing else should ever instantiate a selection surface.

## Files to touch

- **New:** `ui/inspector/inspector_panel.tscn` + `.gd`, `ui/inspector/tab_sets/` (one small script per kind that declares its tabs and subject-block content), `scripts/utility/mood_catalog.gd`, `tests/unit/test_mood_catalog.gd`
- `ui/pawns/pawn_info_panel.tscn` + `.gd` — **deleted**; its subject block and injected readouts redistributed per §3
- `ui/pawns/pawn_{needs,job,skills,inventory,schedule,social}_tab.*` — restyled, reparented; `pawn_needs_tab` gains the breakdown
- `ui/windows/module_info_ingame_panel.tscn` + `.gd` — **deleted**; its integrity row, Environment section and component-tab walk move into the module tab set
- `ui/windows/turboshaft_panel.tscn` + `.gd` — becomes a tab set
- `ui/windows/component_ui_panels/asteroid_info_panel.*`, `resource_pile_inventory_tab.*` — become tab sets
- The 17 `ModuleComponentUI` subclasses — restyled onto the widget library; no logic changes
- `pawns/pawn_needs_component.gd` — `get_modifier_breakdown()`
- `ui/ui_main.gd` — four click handlers → one `select()`; Esc level 4
- `ui/ui_in_game.gd` — bracket ownership per §5

Not touched: `ClickCycler`, `SelectionBrackets`, `GameCamera`, and every component's *behaviour*.

## Implementation order

1. `MoodCatalog` + `get_modifier_breakdown()` + tests. Pure, and independently verifiable before any UI exists.
2. `InspectorPanel` shell with the nothing-selected state and the MODULE tab set (the most complex, so the API gets exercised first). Old panels still mounted.
3. CREW tab set, including the breakdown and the three redistributed readout blocks.
4. ASTEROID, PILE, TURBOSHAFT sets.
5. Selection routing collapse; delete the old panels and the per-frame reposition.
6. Esc level 4 and the `select()` API for WI-53/56 to consume.

## Edge cases

- **`set_pawn` is called before the panel enters the tree** in today's code, and WI-48 deviation 8 is the scar: a `ScrollContainer` reports zero minimum height, so a tab sized itself to its margins and rendered empty while all its data was correct. Any tab that scrolls must drive `custom_minimum_size.y` from its content **synchronously and without touching `get_tree()`**. Preserve `_fit_scroll_height()`'s logic when the Social tab moves.
- **`TabStrip` instead of `TabContainer`** avoids WI-48 deviation 7 (a same-frame `set_tab_hidden` lands on an index that doesn't exist yet). Tabs that don't apply are simply not added.
- **A module with no component UIs** (truss, plain corridor) → the tab strip is empty and the subject block carries everything. Must not error.
- **The subject dies while selected.** A destroyed module, a mined-out asteroid, a collected pile, a fired crew member, a merged shaft. One `subject_gone` path, and it must survive the subject being freed *between* the signal and the deferred handler — the existing panels use `is_instance_valid` for exactly this and the habit has to carry over.
- **Re-clicking the selected subject** toggles the inspector closed today (all four handlers implement it). Under one inspector, the design's answer is the nothing-selected line, so re-click deselects rather than hides. Keep the behaviour, change the visual result.
- **Turbolift click** currently routes to a different panel than a module click. Now it routes to a different *tab set* on the same panel, which is strictly less surprising, but the shaft may span floors that are individually selectable — the header must make clear you are looking at the shaft, not the cab you clicked.
- **The panel grows upward** and a module with eight component tabs plus a long Environment list could reach the alerts feed. Cap the content region and scroll inside it; the panel's top edge must never cross the alerts panel's bottom edge.
- **Modded components** (WI-47) supply their own `has_ui()`/`get_ui()`. The tab walk must not assume a known set, and a mod component whose UI is unstyled should still be legible — which is an argument for the widget library being the path of least resistance rather than a convention.
- **Inspector vs. wide panels.** Trade (1180) and R&D (1400) are wide but the inspector is right-anchored, so they coexist. The mockup hides the inspector for Trade and R&D on the grounds that selection means nothing there. Do **not** implement that as a special case — it is a per-panel `hides_inspector` flag or it is nothing.

## Verification

1. **GUT:** `test_mood_catalog` — every static id in the table resolves to a label; unknown ids fall back to a capitalised form rather than empty; disease/trait/event families resolve through their data objects and degrade to the fallback when the data is missing; breakdown sorting is by absolute value; the needs-average plus the modifier sum reproduces the component's clamped happiness for a set of hand-built cases, **including the clamp** (a pawn at 0.98 with `+0.05` reads 100%, and the breakdown must not imply 103%).
2. **Headless probe, mounted exactly as `ui_main` mounts it** — the WI-48 lesson is non-negotiable here. For each of the five kinds: select, assert the tab set is the expected list, assert **the panel and the active tab occupy real height** (not merely that their rows exist), then select a different kind and assert the strip swapped and the previous pages are gone.
3. **Windowed screenshots** of all five tab sets against mockup screens 1 and 2, plus a crew member with at least four active mood modifiers.
4. **Manual:** click a pawn, walk it across the station, and confirm the panel does not move; open Build and confirm the inspector doesn't shift; select a module and deconstruct it from the footer; select a turbolift and add a cab.
5. **The breakdown is right, not just present.** Force a known set with cheats (`infect`, `add_trait`, `set_difficulty`, a forced bad chat, a good meal) and check every line appears with the correct sign, magnitude and duration, and that the listed values plus the needs average equal the displayed happiness.
6. **Regression:** all 17 component UIs still function — storage edit/dump/autodump, processor recipe switching, conveyor lane config, logistics bay purchase, weapon/shield power toggles, workspace assignment, local upgrades, recruitment hiring.

## Related

- [[04_UI_Rework_Program]] — invariant 2, and the port inventory this item drains.
- [[WI-49_UI_Design_System]] — `ReadoutPanel`, `TabStrip`, `StatBar`, and why `TabStrip` is not `TabContainer`.
- [[WI-50_Console_And_Modes]] — Esc level 4 and the panel that must not shift when a mode opens.
- [[WI-53_Alerts]] — consumes `select()` for jump-to.
- [[WI-56_Panels_Crew_And_Stores]] — consumes `select()` for row clicks.
- [[WI-48_Pawn_Interactions]] — its §9 Social tab is superseded here; its deviations 7 and 8 are the two traps this item is most likely to repeat.
- [[WI-10_Placement_UX]] — `ClickCycler`, kept as-is.
- [[WI-24_Combat_Setup]], [[WI-30_Module_Adjacency]], [[WI-28_Robotic_Needs]], [[WI-33_Visitors_and_Commerce]] — the four code-injected readout blocks being redistributed.
