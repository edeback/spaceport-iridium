# 04 — UI Rework Program (WI-49 … WI-57)

> **STATUS: COMPLETE — WI-49 … WI-54 shipped 2026-08-10, WI-55 … WI-57 shipped 2026-08-11.** All nine items are done and every one of the six invariants is true in the shipped build. This is the umbrella doc for the Phase-4 UI rework. It holds the things all nine work items share — the design-system tables, the invariants, the port inventory, the sequencing, and the decisions taken up front — so each WI can cite one authority instead of re-deriving the palette nine times.
>
> The source design is **`assets/external/spaceport-iridium-ui-layout/project/Iridium Console UI Spec.dc.html`**, a Claude Design handoff bundle: ten reference screens at 1920×1080 plus the rules that produce them. Read it before implementing any child WI. Numbers in this doc are transcribed from it and are authoritative for implementation; where this doc and the mockup disagree, **this doc wins** (it carries the gameplay corrections from [[New Work for Phase 4]] that the mockup predates).
>
> **The mockup is a style guide, not a content spec.** It shows four tabs on a crew member; the game has six. Port everything the game has — the mockup shows how it should *look*, not what should exist.

## Goal

Merge the accreted per-feature windows into **one console UI** with a unified look. Today there are roughly twenty independent surfaces — a top-left resource strip, a left-hand build column, four code-built full-rect "management screens" that each invented their own frame, two floating info panels that follow their subject around, two trade screens, a minimap, an overlay toolbar, and a raid banner — with an **empty `Theme`** (`ui/themes/base_theme.tres` is three lines and sets nothing), so every one of them looks like whatever Godot's defaults plus a hand-authored `StyleBoxFlat` happened to produce.

The end state: navigation in a console welded to the bottom edge, **one** panel open at a time on the left, **one** inspector on the bottom right, and persistent readouts (map, alerts, vitals, clock) that never move.

## The six invariants

These are the load-bearing rules. Every child WI is judged against them.

1. **One panel.** Build, Crew, Stores, Trade, R&D, Comms and Overlays are *modes*, not windows. Opening one closes the last. Two panels can never coexist — so there is no z-order to manage and no "close everything" problem. Two **readout flyouts** are chartered exceptions: the resource ledger (WI-52) and the alert log (WI-53). Both are raised from a permanent readout rather than from the console, both are things you glance at rather than work in, and closing Build to check stock or to read what just happened is exactly the interruption this rule exists to prevent. Nothing else gets the exemption without a line here.
2. **One inspector.** Crew, module, asteroid, pile, turboshaft and corridor selections render into the *same* bottom-right surface with a swapped tab set. ~~Nothing selected shrinks it to a single line of text rather than hiding it.~~ *(2026-09-13)* Nothing selected hides it — the line was a permanent box that said nothing. *(2026-09-13, later)* It reads **bottom-up**: an identity strip on its floor, a rail of tabs on that, and a detail box that rises only while a tab is open — see §"What inverting the inspector changed".
3. **Left is doing, right is watching.** Panels only ever open on the left. Map, alerts and inspector own the right edge permanently and never move, so opening a panel shifts nothing the player was reading.
4. **Vitals are pinned; everything else is the ledger.** Six resources sit in the console strip; the rest live behind the ledger chip, grouped. Pinning promotes any resource into the strip, so the layout is indifferent to 20 resources or 100.
5. **Amber is a budget, not a colour.** Cyan means live / selected / affordable. Amber is reserved for breaches, falling vitals and ARC. Nothing decorative is amber, which is why one amber pixel reads instantly.
6. **One panel frame.** A 56px panel header, a 34px readout header, a 1px `#1d2c40` edge, a 1px inner top highlight, and the hotkey right-aligned in the header. *Most of the polish gap in the current build is frame inconsistency, not placement.* *(2026-09-13)* The inspector is the one right-column tenant with **no** readout header: the inversion traded `SELECTED · CREW` for the portrait and name, which say the same thing in none of the height. It keeps the edge, the inner highlight and the palette.

## Geometry

The project already runs a **1920×1080 viewport** with `window/stretch/mode="viewport"` and `aspect="expand"` (`project.godot:52-56`), so the spec's absolute pixel values map **1:1** to viewport coordinates. No scaling maths is required.

`aspect="expand"` means a wider display hands the game extra *width*, not a letterbox. Therefore: **the console anchors bottom-wide, the right column anchors to the right edge, panels anchor to the left edge and take their width from the table below.** Extra width becomes more visible station, which is the correct outcome. Panel widths are fixed pixels, not fractions — a 1180px Trade table reflowed to 60% of an ultrawide would be unreadable.

| Element | Size |
| --- | --- |
| Console | 112px, full width, bottom-anchored |
| Mode button | 70×74px, 5px gaps |
| Console zones | modes 715 / vitals flex / time 247 |
| Panel — Overlays | 360px |
| Panel — Build | 356px + 340px flyout (696 total) |
| Panel — Comms | 620px |
| Panel — Crew | 660px |
| Panel — Stores | 1080px |
| Panel — Trade | 1180px |
| Panel — R&D | 1400px |
| Right column | 344px, 20px gutter |
| Inspector | 420px, bottom-anchored above the console |
| Panel header | 56px |
| Readout header | 34px |

Panels run from the top of the screen to the top of the console (`bottom: 112px`). The right column starts at `top: 20px, right: 20px`; the inspector sits at `right: 20px, bottom: 132px` (20px above the console). *(2026-09-13: `bottom: 112px` — it sits on the console now, like the left panels.)*

## Palette

| Name | Hex | Use |
| --- | --- | --- |
| VOID | `#05080e` | Play-area base. Nebula is a radial gradient over it, never a texture. |
| PANEL | `#0b111b` | Every surface. 0.94–0.98 alpha when it floats over the station. |
| CONSOLE | `#0d1420` | Console gradient top; `#080d15` bottom. The only surface with a cyan top border. |
| EDGE | `#1d2c40` | The only border on inert panels. `#16222f` for internal dividers. |
| LIVE | `#4fbfd9` | Active mode, selection, affordable, positive rate. Glows only on badges and the map viewport. |
| ATTENTION | `#e5a34a` | Breach, falling vital, unread transmission, ARC. Budgeted. |
| GROWTH | `#4fbf7a` | Built modules, biomass, researched tech. Never a UI state. |
| DESTRUCTIVE | `#d4614f` | Demolish and fire. **Outline only, never a filled button.** |
| TEXT | `#9db9c9` | Primary body. `#eaf6fb` emphasis, `#5f7d94` secondary, `#4a6d85` meta. |

Supporting values that recur in the mockup and should become named constants: header gradient `#152436 → #0e1826` (readout) and `#17303d → #0e1c26` (panel), active-panel border `#2f6b80`, control fill `#111b27`, control border `#24384f`, inner highlight `rgba(120,190,225,.07)`, amber text `#f2c377` on amber-tinted rows, amber meta `#a68242`, amber border `#8a6524`.

## Type

Fonts are **already imported** (commits `9e895c39`, `2ace616a`): `assets/fonts/Chakra_Petch/`, `assets/fonts/IBM_Plex_Mono/`, `assets/fonts/IBM_Plex_Sans/`.

| Role | Face |
| --- | --- |
| Display / labels | Chakra Petch 600–700 |
| Numbers / hotkeys | IBM Plex Mono 500–700 |
| Body prose | IBM Plex Sans 400–600 |
| Panel title | 15px, .18em tracking, caps |
| Readout label | 11px, .20em tracking, caps |
| Entity name | 14–18px Chakra Petch 600 |
| Metric | 13–16px Mono 700 |
| Meta line | 10–11px Mono 500, caps |
| Mode button label | 9px, .10em tracking, caps |
| Minimum on-screen | 9px labels, 11px everything else |
| Never | italics; no icon fonts in the HUD |

Godot's `Font` has no letter-spacing property. Tracking is done with `FontVariation.spacing_glyph`, which is what the theme's caps-label variations must use — this is why the type scale needs to live in *theme type variations* rather than per-label overrides.

## Mode inventory

Nine console buttons: seven modes, then a divider, then two utilities.

| Mode | Width | Hotkey | Built from | WI |
| --- | --- | --- | --- | --- |
| BUILD | 356 + 340 | B | `ui/buttons/build_menu.gd` (rail + flyout already exist, WI-43) | WI-54 |
| CREW | 660 | C | ✅ `crew_panel.gd`; `SHOW ALL JOBS` swaps `jobs_screen` in as a second view | WI-56 |
| STORES | 1080 | E | ✅ `stores_panel.gd`; every bin's priority and contents in one list | WI-56 |
| TRADE | 1180 | T | `trade_screen` + `trader_screen` merged; Contracts becomes a tab | WI-55 |
| R&D | 1400 | R | `unlocks/unlock_panel.gd`, reflowed to tiers left-to-right | WI-55 |
| COMMS | 620 | G | ✅ **New.** Transmissions + ARC; `economy_screen` becomes the FINANCE tab and the tier block the QUOTA tab | WI-57 |
| OVERLAY | 360 | V | `overlay_controller.gd`'s toolbar strip becomes a panel | WI-54 |
| AIDE | 620 | F1 | ✅ **New.** `aide_panel.gd`; SAI's introduction and every advisory she has given, replayable. Was the deferred stub decision 7 describes | WI-50, filled in by WI-63 |
| SYS | — | Esc-at-rest | `menus/pause_menu.gd` (WI-36) | WI-50 |

Plus two non-mode surfaces: the **ledger flyout** (console chip, allowed to coexist with a mode — it is a readout, not a workspace) and the **alert history log**.

## Port inventory

Every existing UI file and where it goes. Nothing in this table may be silently dropped.

**Becomes part of the frame or console (WI-49, WI-50, WI-52):**

| Current | Fate |
| --- | --- |
| `ui/themes/base_theme.tres` (empty) | ✅ Filled in — the real theme (WI-49) |
| `ui/themes/spinbox_theme.tres` | ✅ Deleted; folded into `LineEdit/constants/minimum_character_width` (WI-49) |
| `ui/resource_display_ui.tscn`, `energy_display_ui.gd`, `ui_main.tscn`'s `ResourceDisplayPanel` | ✅ Deleted; replaced by the pinned vitals strip (WI-52) |
| `ui/ui_time_scale_select.tscn` | Console time zone |
| `ui_main.gd` `_add_side_button()` + the `VBoxContainer` side column | **Deleted.** Modes replace it |
| `ui_main.gd` `_setup_alerts_strip()` / `_spawn_alert()` | ✅ Deleted; the alert feed replaces it (WI-53) |
| `ui_main.gd` `_refresh_crew_count()` label | ✅ Deleted; it is the CREW derived chip (WI-52) |
| `ui_main.gd` `_topmost_esc_claim()` / `_close_esc_claim()` | Rewritten against the mode stack (WI-50) |
| `ui/minimap.tscn` | ✅ Station Map readout, top of the right column (WI-49 pilot); WI-53 made the column a measured stack |
| `_setup_raid_ui()` raid banner | ✅ Split (WI-53): raid start is a critical alert, the payoff moved to a right-column `RaidReadout`. WI-57 gives ARC its own surface |

**Becomes an inspector tab set (WI-51):**

`pawns/pawn_info_panel.tscn` and its six tabs (`pawn_needs_tab`, `pawn_job_tab`, `pawn_skills_tab`, `pawn_inventory_tab`, `pawn_schedule_tab`, `pawn_social_tab`); `windows/module_info_ingame_panel.tscn` and the **17 component UIs** that feed its `TabContainer` via `ComponentBase.has_ui()`/`get_ui()`; `component_ui_panels/local_upgrades_tab.gd`, `workspace_tab.gd`, `asteroid_info_panel`, `resource_pile_inventory_tab`; `windows/turboshaft_panel.tscn`.

**Becomes a mode panel (WI-54 … WI-57):**

✅ `buttons/build_menu.tscn` and ✅ `overlay_controller.gd`'s toolbar + legend (WI-54; `buttons/module_resource_cost_ui.*` deleted with them, `module_button_tooltip` demoted to the recent strip's hover card). ✅ `trade/trade_screen.tscn`, ✅ `trade/trader_screen.tscn` and ✅ `windows/contracts_screen.tscn` — all three **deleted**, merged into `trade/trade_panel.gd` + `trade/contracts_tab.gd` (WI-55); ✅ `unlocks/unlock_panel.gd` + `unlock_node_card.gd` reframed (WI-55). ✅ `windows/jobs_screen.gd` — no longer a panel; it is the Crew panel's second view and reports its shape through a signal (WI-56). ✅ `windows/ui_crew_recruitment.tscn` — reachable from the Crew footer as well as from the docking bay (WI-56), then **deleted** and rebuilt as `windows/hire_tab.gd`, the Crew panel's `HIRE` tab (see §"What moving HIRE changed"). ✅ `windows/economy_screen.gd` — **deleted**, reborn as `comms/finance_tab.gd` (WI-57). **The table is empty.**

**Untouched by this program:** `menus/main_menu.tscn`, `settings_menu.gd`, `save_load_menu.gd`, `keybind_row.gd`, `pause_menu.gd`, `game_over_screen.tscn` (WI-36's out-of-game flow — it has its own consistent look and no console). `event_card.tscn` is untouched here because the Phase-4 **Dialogue** item is going to rewrite it against Dialogue Manager; it should adopt the new theme for free and otherwise be left alone. `preview_module`, `selection_brackets`, `overlay_flow_layer`, `click_cycler` are world-space, not chrome.

## Decisions taken up front

Recorded here so the child WIs don't each re-litigate them.

1. **Contracts becomes a Trade tab; Economy becomes a Comms tab.** The mockup's Trade panel already shows `ORDERS / CONTRACTS / PRICE HISTORY / ROUTES`, and its Comms panel is captioned "PARENT CORPORATION · QUOTA, LOANS, PERSONNEL" — loans, the ARC levy, the ledger and tier progress are all ARC business. Neither screen gets a console slot of its own.
2. **PRICE HISTORY and ROUTES are stubs.** `MarketManager` keeps only current supply (`market_data`) and derives price from it — there is no history buffer, and routes are an undesigned system. Both tabs are **omitted** in WI-55 rather than faked; the tab strip is built to take them later. Adding price history is a ring buffer on `MarketManager` and a graph, and it should be its own item when someone wants it.
3. **Trade merges into one panel and keeps the sim pause while docked.** `trader_screen` today pauses the sim so the trader can't depart mid-trade (UI is real-time by design, so the screen keeps working while paused). That guarantee survives the merge: opening Trade *while a trader is docked* pauses; opening it otherwise does not. `trader_screen.tscn` is retired.
4. **Stores is presentation-only. WI-12 is already done** (2026-07-19; the roadmap, tech spec and bugs-doc D7 were corrected 2026-08-09). The Stores panel must therefore surface and edit **everything WI-12 shipped**: per-module haul priority, the per-resource desired amount, current contents, the accepted-resource checklist for `player_configurable` storages, manual dump (with amount), and the auto-dump toggle. Its two dropped tasks — the `draining` flag and mass-sell — stay dropped; see [[01_Technical_Specification]] §2.1. No new storage *mechanics* in this program.
5. **R&D spends credits, not research points.** The mockup's `48 RP · +2.1/CYC` header and per-node `120 RP` costs are for an undesigned system. `UnlockData.cost` is a `Dictionary[ResourceData, int]` and stays that way — the header carries the credit balance, node costs render as their real resource costs, and affordability is the existing `can_unlock()`.
6. **ARC inspections become player-initiated.** The `CONTACT ARC` button replaces `UnlockManager`'s per-cycle random offer roll. See WI-57.
7. **SYS opens the existing pause menu. AIDE is a deferred stub** — it renders and is disabled with a "not yet" tooltip. It is the natural mount point for the Phase-4 **Tutorial/Onboarding** item, and reserving the console slot now is free; inventing a help system inside a UI rework is not. ✅ **Closed by [[WI-63_Tutorial]]** — AIDE is a live mode now. It is the one mode outside `ModeManager.ORDER`: it sits in a second list, `TRAILING`, because it belongs *past* the group divider beside SYS rather than inside the seven, and `test_mode_manager.gd` still accounts for every member of the enum exactly once across both. Its action was renamed `ui_aide` → `mode_aide` on the way, because the hotkey conflict scan skips every `ui_`-prefixed action as a Godot built-in and would have hidden a rebind collision on F1.
8. **Panels are code-built; the frame and the repeated widgets are scenes.** The codebase is already split this way — `unlock_panel`, `economy_screen`, `jobs_screen` and `overlay_controller` are pure code, while `pawn_info_panel` and `build_menu` are `.tscn`. Code-built panels won because they compose the shared widgets without a scene author having to keep nine `.tscn` files in sync, and because the layouts are data-driven lists rather than fixed forms. The *frame* and the small repeated parts (readout panel, stat bar, chip, stepper, tab strip, list row) are `.tscn` + script so they can be authored and previewed once.
9. **New input actions go in the input map, not hardcoded.** WI-36 shipped a keybind remapper reading `user://settings.cfg`; every mode hotkey must be a real action so it appears there. Hotkeys render in the panel header (right-aligned, Mono 11px, `#4a6d85`) and on the console buttons, so the UI teaches them.

## Sequencing

The mockup's own suggested build order, split finer so no work item touches more than two panels. **Every step leaves the game playable and shippable**, which is the property that makes this safe to do across nine items.

| WI | Title | Why here |
| --- | --- | --- |
| [[WI-49_UI_Design_System]] ✅ | Theme, palette, type, shared panel frame, widget library | "Every later step gets cheaper, and this alone closes most of the polish gap." Nothing else can start without the frame |
| [[WI-50_Console_And_Modes]] ✅ | Console strip, mode buttons, exclusive mounting, Esc rewrite, time zone | Existing screens get **ported in behind it unchanged**. They look inconsistent for a while and still behave better than they do now |
| [[WI-51_Inspector]] ✅ | One bottom-right surface, swapped tab sets, nothing-selected line | The largest single reduction in surface count; also where the mood-modifier breakdown lands |
| [[WI-52_Vitals_And_Ledger]] ✅ | Pinned strip + ledger flyout + per-cycle rates + pin persistence | "Do this before adding more resources, not after" |
| [[WI-53_Alerts]] ✅ | Severity model, sticky/critical alerts, jump-to-subject, history log | The one item with real gameplay consequence (critical alerts pause the sim) |
| [[WI-54_Panels_Build_And_Overlays]] ✅ | The two narrow panels that already exist | Cheapest panel conversions; proves the frame at two widths |
| [[WI-55_Panels_Trade_And_RD]] ✅ | The two widest panels, reflowed in place | Existing content, new layout, plus the Contracts tab merge |
| [[WI-56_Panels_Crew_And_Stores]] ✅ | Two genuinely new panels | Crew roster and the station-wide storage view have no predecessor |
| [[WI-57_Panel_Comms_And_Retirement]] ✅ | Comms panel, ARC contact, and deleting the last legacy windows | The closer: nothing may be left mounted outside the console |

## What WI-49 landed (the API everything else builds on)

Shipped 2026-08-10. Cite this rather than re-deriving it; details and the traps found are in [[WI-49_UI_Design_System]].

| File | What it is |
| --- | --- |
| `ui/theme/ui_palette.gd` (`UIPalette`) | Every chrome colour as a `const`, the three list-row `StyleBoxFlat` treatments (`Row.INERT/LIVE/AMBER` + `row_style/row_accent/row_text/row_meta`), the header and section-rule gradients, `tinted()`, and `sign_color()`. Nothing in `ui/` may name a hex literal. |
| `ui/theme/ui_metrics.gd` (`UIMetrics`) | The geometry table as `const`, the tracking values, and the derived helpers (`panel_bottom`, `panel_content_height`, `inspector_top`, `inspector_bottom_offset`, `mode_zone_width`). |
| `ui/theme/ui_type.gd` (`UIType`) | The theme's type-variation names as `StringName` constants — 11 label variations, 5 button variations. Never write the string. |
| `ui/theme/console_panel.tscn` + `.gd` | The left mode panel. `title` / `subtitle` / `hotkey` / `panel_width` / `content_padding` / `active`, plus `content()` and `add_header_control()`. Anchors itself; provides no scrolling. |
| `ui/theme/readout_panel.tscn` + `.gd` | The right-column surface. `label` / `accent_color` / `panel_width` / `content_height` / `collapsible` / `collapsed` / `drop_shadow`, plus `content()`, `add_action()` and `collapse_toggled`. Takes its own height when anchored to a point. |
| `ui/theme/widgets/` | `StatBar`, `HatchBar`, `Chip`, `Stepper`, `TabStrip`, `ListRow`, `SectionLabel`, `ActionButton`. Each has a `static create()`. |

Two rules that came out of building it and bind the later items: **the scene authors structure, the script applies every number from `UIMetrics`** (so no `.tscn` can hold a header height that disagrees with the design system), and **frame node lookups are lazy**, because exported setters fire before children exist and callers configure a frame before mounting it.

`Stepper` already implements the commit rule the Stores panel needs: the displayed value moves per step, but `value_changed` fires once on release or after a quiet period. `value_previewed` is for live readouts only.

## What WI-50 landed (the mounting contract everything else uses)

Shipped 2026-08-10. Details and the six traps found are in [[WI-50_Console_And_Modes]].

| File | What it is |
| --- | --- |
| `ui/console/mode_manager.gd` (`ModeManager`) | The **only** mutable "what is open" state in the HUD. `Mode` enum, `ORDER`/`LABELS`/`HOTKEY_ACTIONS`, `register(mode, factory)` / `register_unavailable(mode, reason)`, `open`/`close`/`toggle`/`current`, and the mode hotkeys with the text-focus guard. Session-only, tree-independent, 28 GUT tests. |
| `ui/console/console_bar.tscn` + `.gd` (`ConsoleBar`) | The 112px strip. Builds its buttons from `ModeManager.ORDER`, `bind(manager)` wires both directions, `vitals_zone()` / `time_zone()` are where WI-52 and the clock live. |
| `ui/console/mode_button.tscn` + `.gd` (`ModeButton`) | 70×74. `active` / `bar` / `dot` / `badge` are **four distinct signals** and the widget is where that distinction is enforced. `set_disabled_with_reason()` for a declared-but-unbuilt slot. |
| `ui/icons/console/*.svg` | Nine glyphs. Authored, not `_draw()`, because `_draw()` is the one thing headless verification cannot see. |
| `ConsolePanel.create()` / `SCENE_PATH` | Added to WI-49's frame so panels are one call, like the widgets. |
| `UIPalette.console_gradient()`, `UIType.CLOCK` | The console's own gradient and the 28px clock variation. |

**The contract for every later panel:**

1. Register a **factory**, not an instance. It is called at most once, on first open, and the panel is cached from then on. `register_unavailable(mode, reason)` for a slot that has a button before it has a panel; the console tracks the registry through `registry_changed`, so registration order does not matter.
2. A factory may parent its own panel or leave it orphaned; orphans land on `UIMain`'s `PanelLayer`.
3. Implement `on_opened()` / `on_closed()` if — and only if — the panel holds work it must not do while closed.
4. **Never set `visible` on yourself.** Declare `signal close_requested` and emit it from your own close control; `ModeManager` connects it duck-typed, the same way it finds the two hooks. Hiding yourself leaves `ModeManager.current()` stale and the next hotkey press closes nothing.
5. Take the panel width from `UIMetrics`, and the printed hotkey from `ModeManager.hotkey_label(mode)` so a rebind follows.
6. **Every HUD hotkey is a real input action** in `Global.REMAPPABLE_ACTIONS` — including the overlay keys, which WI-50 converted (Shift+digit since 2026-09-15; the bare digits are the time speeds and Space is pause). `ModeManager.text_entry_has_focus(viewport)` is the one place that decides whether the player is typing; call it, do not re-write it. **Match with `ModeManager.hotkey_pressed(event, action)`, never a bare `is_action_pressed`** — Godot's default ignores extra modifiers, so Shift+1 would also be 1.

Esc is now four levels in `ui_main.gd`: game-over latch → held preview → console flyout *(build flyout, then the resource ledger, then the alert log)* → the open mode → the selection → an active overlay. WI-51 collapsed the selection chain to one check; WI-52 added the ledger beside the build flyout and WI-53 the alert log; **WI-55 removed the trader-modal level** — folded into the Trade panel it *is* a mode, and its docked pause is a named hold the panel releases on close. **An outstanding critical alert is deliberately not on the ladder** (WI-53): the player hammers Esc, and an acknowledgement Esc can satisfy is one that gets satisfied without being read.

## What WI-51 landed (the selection API everything else consumes)

Shipped 2026-08-10. Details and the five traps found are in [[WI-51_Inspector]].

| File | What it is |
| --- | --- |
| `ui/inspector/inspector_panel.tscn` + `.gd` (`InspectorPanel`) | The one selection surface: a bottom-right ~~`ReadoutPanel`~~ plain `Control` since the 2026-09-13 inversion (§"What inverting the inspector changed"), 420px, ~~one gutter above the console~~ sitting on the console since 2026-09-13, **growing upward** to a hard top limit. `SelectionKind`, `select()` / `clear()` / `kind()` / `selected_subject()` / `camera_target()`, the static `kind_of()`, `signal selection_changed`, and ~~the nothing-selected line with its caret~~ — removed 2026-09-13: nothing selected hides the panel through `UIMain._sync_inspector_visibility()`. |
| `ui/inspector/tab_sets/*.gd` | One `InspectorTabSet` per kind — `CrewTabSet`, `ModuleTabSet`, `AsteroidTabSet`, `PileTabSet`, `TurboshaftTabSet`. A set answers *what the thing is called, what its meta line says, which tabs it has, what each page holds*; the panel owns the surface. Nodes, not RefCounteds, so their connections die with them. |
| `ui/inspector/inspector_tab_plan.gd` (`InspectorTabPlan`) | Pure: module tab ordering (production → status → power → storage → crew → structure → *unknown* → upgrades), the short labels, duplicate numbering, and the component-derived crew tab set. 25 tests. **Amended by WI-64 (2026-08-23):** Power, Air and the synthetic Environment page fold into one `Status` tab (`STATUS_MEMBERS`, sections stacked Power → Air → Environment by `ModuleStatusTab`), every tab carries a `sources` list, and a component's key resolves up its inheritance chain so a subclass inherits its base's tab. 44 tests. |
| `scripts/utility/mood_catalog.gd` (`MoodCatalog`) | Pure: modifier id → `{label, blurb, cause}` across the fixed table and the three dynamic families (disease/trait/event), the duration-or-cause column, breakdown sorting, and **the happiness formula itself** (`combine`) — which `PawnNeedsComponent` now calls, so the breakdown and the sim cannot diverge. 30 tests. |
| `PawnNeedsComponent.get_modifier_breakdown()` / `needs_average()` | The two accessors the Needs tab needs. Nothing else may read `_modifiers`. |

**The contract for WI-53 and WI-56:** `InspectorPanel.select(subject)` is the *only* way to raise a selection surface, and `camera_target()` is what to hand `GameCamera.jump_to()`. Both have callers now — WI-53's alert rows and WI-56's crew roster and Stores cards — and all three guard the same way: `select()` **toggles** when handed the already-selected subject, which is right for a click on the station and wrong for a list row, so a row click checks `selected_subject()` first.

**Two rules that bind the later panels:** a page that scrolls must drive its own `custom_minimum_size.y` from its content, and a panel that sizes itself to its content must re-fit on `minimum_size_changed` rather than measuring once. Both are the WI-48 zero-height lesson, and WI-51 hit each of them twice.

## What WI-52 landed (the rate and the pin list everything else can read)

Shipped 2026-08-10. Details, the nine deviations and the four traps found are in [[WI-52_Vitals_And_Ledger]].

| File | What it is |
| --- | --- |
| `scripts/utility/resource_rate_tracker.gd` (`ResourceRateTracker`) | Pure: a per-resource ring buffer of `(sim_hours, total)` and a least-squares slope over the window, in units per cycle. Sim-time stamps, self-decimating, `NO_RATE` rather than a fabricated `0.0`, never saved. 18 tests. |
| `scripts/utility/ledger_model.gd` (`LedgerModel`) | Pure: `category_of` / `in_category`, the `derived:` id namespace, `DEFAULT_PINS`, `PIN_CAP`, `resolve_pins` (drop / dedupe / cap / refill-to-the-saved-length), and the three formatters — `format_per_cycle`, `rate_color`, `format_compact`. 25 tests. |
| `ResourceManager.rates` / `rate_per_cycle()` / `ledger_resources()` | The manager owns the tracker (never the shared `.tres` — WI-38 A8) and now *discovers* resources rather than only reading its authored array, so a modded one is tracked and listed with no core edit. |
| `ui/console/vitals_strip.gd` (`VitalsStrip`) | The console's flex zone. `pinned_ids` / `is_pinned` / `toggle_pin` / `pin_count` / `has_room_to_pin`, `signal pins_changed`, `signal ledger_toggled`, and the `vitals` save section. Resource chips repaint on `total_changed`; derived chips and the falling-vital test ride a real-time timer. |
| `ui/console/vitals_chip.tscn` + `.gd` (`VitalsChip`) | The 108×52 tile. Fixed width by construction, so a number gaining a digit never re-lays out the strip. |
| `ui/console/resource_ledger.tscn` + `.gd` (`ResourceLedger`) | The flyout. `open` / `close` / `toggle` / `is_open`, `strip` for the pin toggles. Bottom-right, grows upward, stops one right-column-plus-two-gutters short of the edge. |
| `ListRow.set_action_color()`, `ResourceData.average_instance_value()` | The two additive helpers, both of which the later panels want. |
| `Cheats.dump_rates()` | Total, per-cycle rate and sample count per resource — how you tell a flat line from "no data yet". |

**The contract for the later panels:**

1. **`ledger_category` is presentation only**, exactly as `ui_category` is (WI-43). Nothing may branch on it, and nothing may group a list on `tradable` or `has_variance` because they happen to correlate today.
2. A rate is `ResourceRateTracker.NO_RATE` until there is history. Test with `has_rate()`, print with `LedgerModel.format_per_cycle()`; never compare against `0.0`.
3. **The ledger is the only surface allowed to coexist with a mode** (invariant 1's one exception) and it sits at Esc level 2, beside the build flyout. Nothing else gets that exemption without a line in this doc.
4. **Console flyouts never open over the map, alerts or inspector** — `UIMetrics.LEDGER_RIGHT_INSET` is the encoded form of that rule.
5. `SaveManager.register_section` is called by the **UI node that owns the state**, not added to `SaveManager`. WI-53's alert history should do the same.

## What WI-53 landed (the alert API, and the pause every later panel must respect)

Shipped 2026-08-10. Details, the nine deviations and the four traps found are in [[WI-53_Alerts]].

| File | What it is |
| --- | --- |
| `scripts/utility/alert_data.gd` (`AlertData`) | The record — `Priority` (LOW/HIGH/CRITICAL), id, title/detail, subject, route, cycle/hour, `sequence`, `count`, `acknowledged`, `suppress_pause`, `group_title`. `subject_node()` is the only sanctioned way to read a subject. |
| `scripts/utility/alert_rules.gd` (`AlertRules`) | Pure: the tier table, `make_id` / `family_of`, ordering, ageing, `survives_clear`, the `Group` coalescer, the feed cap. 35 tests. |
| `scripts/managers/alert_manager.gd` (`AlertManager`) | A node under `Managers/` after `TimeManager`. Owns the live queue, the log, the pause latch and the `alerts` save section. `AlertManager.raise_alert(id, priority, title, detail, subject, route, group_title)` is the static every emit site calls; `resolve_alert(id)` is the "the condition ended" path. |
| `TimeManager.hold_pause` / `release_pause` / `is_paused` / `pause_holders` | Reference-counted pause, replacing four independent "was it paused before I opened?" flags that could not compose. |
| `ui/alerts/` | `alert_feed`, `alert_row`, `alert_history`, `raid_readout`, plus three authored glyphs. |
| `InspectorPanel.top_limit`, `UIMain._layout_right_column()` | The right column is now a measured stack — map, raid readout, feed — that hands the inspector its live ceiling. |

**The contract for WI-54 … WI-57:**

1. **`SignalBus.station_alert(message)` is not deprecated.** It is the correct interface for "something happened, mention it", and the shim gives every one of its fifty-odd sites a LOW alert for free. Reach for `AlertManager.raise_alert` only when the alert genuinely deserves a tier, a subject or a route.
2. **CRITICAL is a closed set.** Six members, listed in [[WI-53_Alerts]] §4, and the membership test is "the player will lose something irreversible if they are looking away". A new panel does not get to add one; if more than one or two fire in twenty minutes at 4x, the classification is wrong.
3. **Never write `TimeManager.paused` from a panel.** That field is the player's own pause and it is what saves. A panel that must stop the sim takes a named hold — the docked-trader pause WI-55 inherits is `trader_screen`'s hold, and merging it into the Trade panel means moving the hold, not reinventing the flag.
4. **A panel that wants to be reachable from an alert declares a route id**, and `AlertFeed.ROUTES` maps it to a `ModeManager.Mode`. `build` / `crew` / `stores` / `trade` / `research` / `comms` are already wired, including for the modes whose panels do not exist yet.
5. **The alert log is the second (and last chartered) exception to invariant 1**, at Esc level 2 beside the resource ledger.
6. `ListRow`'s name and meta labels are ellipsed, and that is load-bearing rather than cosmetic — see the trap in [[WI-53_Alerts]]. Any new list built on `ListRow` inherits the fix; any list that hand-rolls its own row will rediscover the bug.

## What WI-54 landed (the frame additions and the two shipped panels)

Shipped 2026-08-10. Details, the ten deviations and the five traps found are in [[WI-54_Panels_Build_And_Overlays]].

| File | What it is |
| --- | --- |
| `ConsolePanel.panel_offset_left` / `footer_text` / `footer_variation` | Two additive frame properties. The first exists for Build's flyout — the one frame that does not weld to the left edge. The second is the full-bleed instruction strip at a panel's foot, which the design draws as part of the frame rather than as the last row of the content. |
| `SectionLabel.hint`, `ListRow.set_icon(texture, size)` | A trailing hotkey hint on a section rule (`CATEGORIES ——— [/]`), and an icon size override for a row that is a *heading* rather than a line item. |
| `ui/buttons/build_menu.gd` (`BuildMenu`) | The 356px body: full-bleed search, the recent strip, `CATEGORIES`, and a `ListRow` rail whose entries carry name / count / caret. `open_category()`, `close_flyout()`, `flyout_open()`, `flyout_panel()`, `facts_for()`. Owns the flyout. |
| `ui/buttons/module_button.gd` (`ModuleButton`) | The flyout row in three states — buildable, selected-and-expanded (description + facts line), locked-and-dimmed (gating tech + lock glyph) — plus the `compact` icon-only tile the recent strip uses. |
| `ui/buttons/module_facts.gd` (`ModuleFacts`) | Reads the numbers a module scene **declares** — power draw, power output, storage capacity, crew seats, footprint — once per `PackedScene`, cached on the menu. Nothing here simulates; see deviation 2. |
| `BuildMenuModel.sort_bucket` / `gating_unlock` / `gating_label` / `format_cost` / `format_footprint` / `format_facts` / `fact_is_a_cost` | The new pure rules, all tested. Locked-after-unlocked ordering, gate resolution by walking `UnlockData.effects` (no `required_unlock` back-reference), and the row/hint text. |
| `ui/buttons/build_cursor_hint.gd` (`BuildCursorHint`) | The held module's attached label, mounted on the HUD by `UIMain` so it outlives the Build panel. A real `Control`, not `_draw()` output — deliberately, so a probe can read it. |
| `OverlayPalette.MODE_*` / `LegendStop` / `legend_stops()` / `legend_note()` | The legend table, keyed by `StringName`. Every stop is produced by that mode's own colour function, so the swatch beside a phrase **is** the tint the station is painted with. |
| `build_category_prev` / `build_category_next` | Two real, remappable actions on `[` / `]`. See deviation 1 for why not `Q`/`E`. |

**The contract for WI-55 … WI-57:**

1. **A panel's standing instruction is `ConsolePanel.footer_text`, not a row at the bottom of the content.** It is full-bleed and welded to the frame; a list that scrolls must not be able to push it off.
2. **Locked is a state, not an absence.** Build renders un-researched modules dimmed with the tech that grants them, and the rail no longer hides a category because everything in it is locked. R&D (WI-55) is the other half of that story and should assume the player arrives already knowing what they are missing.
   **Narrowed 2026-09-15:** the menu now lists what the player can build *or can do something about*. A category holding nothing buildable is off the rail until its first module is granted (Defense and Logistics on a new station), and a locked module is listed only while research the station can reach grants it — one needing a promotion first (its granting node, or any prerequisite of it, above the station's tier), or that nothing grants, is not listed, and search follows the same rule. `BuildMenuModel.is_listed` / `category_shown` are the rule; the rail re-derives on a grant, a promotion and `global_unlock_changed`. A category the onboarding opens has to stay on a new station's rail — `test_tutorial_content.gd` pins it.
3. **Never invent a rate.** `ModuleFacts` reports only what a scene declares. A panel that wants a produced-per-cycle figure needs a real source for it, the way `ResourceRateTracker` is one — not a formula in the view.
4. **`ui_category` groups the rail and nothing else.** The rail is built from discovered category ids, so a modded category appears with no core edit; nothing in the panel gates gameplay on it, and nothing groups on `tags`.
5. **A screenshot is part of the verification, and it has to be driven into the state under test.** Two defects in this item passed every probe check and were visible only in a capture — and the first capture proved the frame while proving nothing about the item's one behaviour change.

## What WI-55 landed (the frame bridge and the two widest panels)

Shipped 2026-08-11. Details, the ten deviations and the four traps found are in [[WI-55_Panels_Trade_And_RD]].

| File | What it is |
| --- | --- |
| `ConsolePanel.hides_inspector` / `close_requested` / the content bridge | Three additive frame properties. The first is the design's flag, set by Trade and R&D. The other two are the **body bridge**: the frame forwards `on_opened`/`on_closed` down to whatever is mounted in `content()` and re-emits that body's `close_requested` as its own. |
| `scripts/utility/trade_offer.gd` (`TradeOffer`) | Pure: `sell_limit` / `buy_limit` / `clamp_amount`, `is_sell` / `is_buy`, `unit_price`, the `Line` record and the totals, plus `sell_orders` / `buy_orders` in the shape `commit_trades` takes. 30 tests. |
| `ResourceData.available_unreserved()`, `StorageComponent.available_to_withdraw()`, `StorageData.available_to_withdraw()` | The station-wide `AVAIL` figure and the two accessors under it. Re-derived per call, never cached — reservations move on every claim and release and none of them touch `needs_recalc`. |
| `ui/windows/trade/trade_panel.gd` (`TradePanel`) | The 1180px merged panel: `ORDERS` + `CONTRACTS`, one signed stepper per commodity, the summary bar, and the docked `PAUSE_HOLD`. |
| `ui/windows/trade/trade_resource_row.gd` (`TradeResourceRow`) | `COMMODITY · BUY @ · SELL @ · HELD · AVAIL · TRADE`, plus `make_header()` so the captions come from the same constants as the columns. |
| `ui/windows/trade/contracts_tab.gd` (`ContractsTab`) | Offers, active contracts and capped history, with `accept_block_reason()` shown inline as well as on the button. |
| `ui/windows/unlocks/unlock_panel.gd` (`UnlockPanel`) | The 1400px tech tree: one tab per tree, depth columns with hairline connectors, the credit chip in the header, `select_tree()`. |
| `UnlockNodeCard.State` / `state_of()` | The four treatments as a state rather than four call sites, and the cost-in-place-of-the-state-label rule. |
| `UnlockManager.has_affordable_unlock()` / `tree_progress()` | The R&D readiness-dot predicate and the per-tab progress headline, both on the manager rather than recomputed in a view. |
| `Stepper.editable` / `is_editing()` | A read-only stepper for a control the player can see but may not use yet, and the guard a tick-driven refresh needs so it cannot snatch a number mid-drag. |

**The contract for WI-56 and WI-57:**

1. **A code-built panel's body gets the mode hooks and can ask to be closed** — implement `on_opened()` / `on_closed()` / `signal close_requested` on the *body*, mount it in `content()`, and the frame does the rest. Do not reach for `ModeManager` from inside a panel, and never set your own `visible`.
2. **`hides_inspector` is a declaration, not a list.** Only a panel that genuinely owns the whole screen sets it; the narrow modes leave the inspector alone.
3. **`AVAIL` ≠ `HELD`, and Stores wants the same distinction.** `ResourceData.available_unreserved()` is the station-wide figure and `StorageComponent.available_to_withdraw()` the per-bin one. Anything that lets the player commit stock must show what is unreserved, not what is stored.
4. **A cap that a control's own value *causes* has to add that value back.** The sell limit is `AVAIL + this line`; without it a standing order ratchets itself to zero one haul at a time. Any Stores control that drives hauling will hit the same shape.
5. **Two things called "tier" is a real hazard.** R&D's columns are prerequisite depth and its node gates say `NEEDS STATION TIER n`. Comms owns the station tier outright from WI-57, at which point R&D's promotion block moves there and this stops being ambiguous.
6. **A screenshot is part of the verification, still.** Three of this item's four defects were invisible to a 92-check probe — a hairline too dim to see, a tab strip painted on the wrong tab, and a probe stocking a bin that silently stocked nothing.

## What WI-56 landed (the pawn-status vocabulary and the two new panels)

Shipped 2026-08-11. Details, the twelve deviations and the four traps found are in [[WI-56_Panels_Crew_And_Stores]].

| File | What it is |
| --- | --- |
| `scripts/utility/pawn_status.gd` (`PawnStatus`) | Pure: **the one place in the game that turns a pawn into a sentence**. A `Facts` record and its `facts_for(pawn)` adapter, the sentence table, `describe` / `tone_of` / `is_idle` / `tone_color` / `tone_row`, the roster's `Filter` / `Sort` / `passes` / `compares_before`, and `summarize` / `summary_text` / `summary_color` behind the problem line. 44 tests. |
| `scripts/utility/stores_model.gd` (`StoresModel`) | Pure: `Entry`, the three sorts and their total comparator, `LEGEND`, the priority range/bands/`priority_label`/`priority_color`, `lists` (which bins are real storage), `modules_holding_stock`, `subtitle_text`. 24 tests. |
| `ui/windows/crew_panel.gd` + `crew_roster_row.gd` | The 660px roster: filter pills, sort, the problem-line bar with `SHIFT ROTA` and `HIRE`, and the two-view state machine (`show_roster` / `show_board` / `board_visible`). `HIRE` has since become a tab and the state machine has grown a strip — see §"What moving HIRE changed". |
| `ui/windows/stores_panel.gd` + `stores_module_card.gd` | The 1080px bin list: the legend line, sort, one card per bin with a priority `Stepper`, a fill gauge and contents chips. |
| `ui/windows/storage_overlays.gd` (`StorageOverlays`) | WI-12's two dialogs, extracted: the accepted-resource checklist and the per-resource desired/dump/auto-dump dialog, plus the shared `dump_to_pile`. Both the Stores card and the inspector's storage tab call in. |
| `Chip.chip_style(kind)`, `StorageComponent.resource_consumers()` / `autodump_warning()`, `PawnNeedsComponent.has_critical_need()` | The four additive helpers. |
| `JobsScreen` | Reframed again: a body rather than a panel, reporting its shape through `signal subtitle_changed`. |

**The contract for WI-57:**

1. **`PawnStatus` is the only place a pawn becomes a sentence.** The roster, the job board, the inspector's Job tab and `RobotVitalsTab.state_text` all read it; a fifth surface adds a caller, never a fifth set of rules. The tone set is closed and **only three states spend amber** (resigning, a critical need, a drone out of power) — invariant 5, enforced by a test.
2. **Off duty is not idle.** `PawnStatus.is_idle` requires `on_shift`, and the console's CREW readiness dot now asks the same question the panel's problem line answers. Any future "is somebody free?" check goes through it.
3. **A two-view panel swaps in place through public methods.** Crew's `show_roster()` / `show_board()` are public precisely because WI-55's tab-strip defect was a view driven around its own entry point; a probe or a screenshot driver must use the same door the player does. Crew is now a *tabbed* panel with a drill-down; `show_tab()` / `show_hire()` / `open_tab()` joined them under the same rule.
4. **Storage priority has one vocabulary now** (`StoresModel.priority_label` / `priority_color`, delegating to `UIPalette.sign_color`) and one range. Nothing may print its own words for a haul priority, and **priority writes go through `update_priority()`** — the WI-45 A5 rule, now asserted by a probe that watches an already-posted job's priority move.
5. **A construction bin on a finished module is not storage.** `StoresModel.lists` is the membership rule; anything else enumerating bins should use it rather than `Groups.RESOURCE_STORAGE`, whose membership tracks `accepts_exports` rather than "has a StorageComponent".
6. **A screenshot is part of the verification, still.** Three of this item's defects were invisible to an 81-check probe — six dead bins the model and the panel agreed about, priority captions ellipsed to nonsense in a fixed column, and a colour that said the opposite of the text beside it.

## What WI-57 landed (the closer)

Shipped 2026-08-11. Details, the eight deviations and the five traps found are in [[WI-57_Panel_Comms_And_Retirement]].

| File | What it is |
| --- | --- |
| `scripts/utility/transmission_data.gd` (`TransmissionData`) | The record — `family`, a unique `id`, sender/subject/body, cycle/hour, `unread`, `route`, an unsaved live `subject_ref`, `sequence`. Deliberately the *sibling* of [AlertData] rather than a flavour of it; its class docs carry the five-row table of how the two differ. |
| `scripts/utility/transmission_log.gd` (`TransmissionLog`) | Pure: the bounded (60) newest-first ring buffer, `post` (which **always appends**), the unread accounting, `mark_read` / `mark_all_read`, and the save round-trip with its re-derived sequence counter. 27 tests. |
| `AlertManager.transmit()` / `post_transmission()` / `transmissions` / the `transmissions` section | One owner for "things that arrived". The static `transmit(id, priority, title, detail, family, sender, body, route, subject, group_title)` raises the alert **and** posts the transmission; the transmission's subject line *is* the alert's title, so the two lists cannot drift into different words. |
| `ui/windows/comms/comms_panel.gd` (`CommsPanel`) | The 620px panel: the permanent amber ARC block above the tab strip, the live raid-payoff row, and `INCOMING` / `QUOTA` / `FINANCE`. `show_tab()` is public and routes through the strip. |
| `ui/windows/comms/transmission_row.gd` (`TransmissionRow`) | A `ListRow` header over a fold-out body. 34px avatar slot, cyan while unread, expands in place. |
| `ui/windows/comms/quota_tab.gd` (`QuotaTab`) | WI-26's promotion block, moved out of Research. Export gauges, the facility checklist, and a closing line that says what the *button* will do next. |
| `ui/windows/comms/finance_tab.gd` (`FinanceTab`) | `economy_screen` with its window, title bar, close button and Esc handler deleted. Content unchanged. |
| `UnlockManager.InspectionBlock` / `inspection_block()` / `can_request_inspection()` / `export_goal_progress()` / `missing_inspection_tag()` / `inspection_cooldown_remaining()` | The readiness checks the deleted per-cycle roll used to make, now producing a sentence for a button instead of gating a random number. |
| `ListRow.set_swatch(color, size)`, `UnlockPanel.FOOTER`, `SignalBus.transmissions_changed` | The three additive bits: an avatar-sized swatch, the footer R&D was missing (Build was also missing one - see WI-58), and the signal both the feed and the console badge re-derive from. |
| **Deleted** | `ui/windows/economy_screen.gd`, `data/events/arc_inspection_offer.tres`, `data/events/effects/effect_inspection_response.gd`, `ui/windows/module_info_panel.tscn`, `ui/windows/popup_panel.tscn`, the empty `ui/data/` and `ui/windows/storage/`. |

**What the retirement sweep actually found:** almost nothing, which is the point — eight prior items had each cleaned up after themselves. `UIMain` is 481 lines and its runtime child list is exactly the allowed set. There were no stray `PRESET_TOP_WIDE` / `PRESET_CENTER_TOP` anchors, no hardcoded left offsets, and no `_add_side_button` remnant. The re-run of WI-49 §7's override sweep found **zero** `add_theme_font_size_override` calls anywhere in the console UI; the nine that remain are all in `ui/menus/` and `event_card.gd`, both explicitly untouched by this program. **That sweep was code-only** and therefore structurally blind to the 28 *scene-authored* `theme_override_font_sizes` sitting in `.tscn` files at the same moment - see WI-58, which fixed them and added the scene half of the drift guard.

**The rules this leaves behind** (they are in CLAUDE.md's UI section too):

1. **An alert is "look at this now"; a transmission is "this arrived and you can read it later."** `AlertManager` owns both lists and `transmit()` raises them together. A hull breach is never a transmission; a contract offer is both.
2. **Alert repeats refresh one row; transmission repeats are separate rows.** Two lists, two rules, and the id shapes make it obvious: an alert id is a dedupe key, a transmission id is `family#sequence`.
3. **A blocked action names its blocker on its own control.** Six of the seven `InspectionBlock` states print a sentence on the button. This is WI-54's "locked is a state, not an absence" applied to an action rather than to content.
4. **A row that repaints on a signal it can itself emit must not rebuild.** Expanding a transmission marks it read, which fires `transmissions_changed`, which lands back in the feed — an unconditional rebuild frees the row mid-signal. WI-53 learned this as a nuisance; here it is a crash.
5. **`register_unavailable` now has no users.** Every console mode has a real panel. It stays for a future slot declared ahead of its panel, and a mode that was never registered at all is still a loud error.

## What WI-58 corrected

Shipped 2026-08-14. The program is complete, so this is an **appendix rather than a tenth item**: an audit of the nine against their own invariants, and the fixes it produced. Details, the ten deviations and the six traps are in [[WI-58_UI_Rework_Fix_Pass]].

The audit's verdict on the program itself was good — the port inventory is genuinely empty, all eleven deleted files are gone, there are no dangling `res://ui/…` references, and four of the six invariants were airtight. What it found clustered in one place and one theme.

**The place: the seam WI-51 deviations 7-8 left.** Sixteen component UIs and five pawn tab scenes stayed pre-rework `.tscn`, so the design system stopped at the surface the player touches most. They are converted now — both `SpinBox`es are `Stepper`s (there were no `SpinBox/*` entries in the theme at all, so Godot resolved their arrows from its default *light* theme inside a dark console), the Kenney placeholder art and the 12×12 destructive `TextureButton` are `ActionButton`s, and the two dead sub-panels WI-56 deviation 9 deferred are deleted.

**The theme: the verification sweeps were code-only.** WI-57 §8's "zero `add_theme_font_size_override` calls" was true and could not see 28 scene-authored ones, six of them at 10px. `test_ui_theme.gd` now sweeps `ui/**.tscn` as text for authored sizes, authored colours and undeclared type variations.

| Area | What changed |
| --- | --- |
| **The right column's budget** | `ALERT_FEED_MAX_HEIGHT` (a fixed 400, chosen before the raid readout existed) → `UIMetrics.alert_feed_max_height(raid_visible, screen_height)`, derived from the screen minus the console, the readouts and a new `INSPECTOR_MIN_CONTENT_HEIGHT`. **The feed is the tenant that yields**: it has an overflow row and a history flyout, the inspector has nowhere. A raid over a full feed used to give the inspector a **zero-height** content region with its chrome rendering outside its own rect. |
| **Contrast** | `TEXT_META` 3.44:1 → 4.99:1 and `TEXT_SECONDARY` 4.37:1 → 5.59:1 on `PANEL`; a new `TEXT_DISABLED` token for every `font_disabled_color`, because a disabled control is exactly where WI-57's "a blocked action names its blocker" rule puts a sentence — and on the `ActionPrimary` disabled fill that sentence was at **3.01:1**. `test_ui_palette.gd` computes WCAG ratios and pins the whole ladder. |
| **`ReadoutPanel` geometry** | `panel_width` was **cosmetic** for a right-anchored readout: the real offsets were a hand-typed `-364` in six scenes, all correct and all silently stale the moment `RIGHT_COLUMN_WIDTH` moved. `_apply_layout` writes them now, from `panel_width` and a new `right_inset`, the way `ConsolePanel` always has. |
| **One answer per question** | `StoresModel.contents_editable()` / `priority_editable()` / `locked_reason()` — the Stores card, the inspector's storage tab and the dump dialog gave three answers to "what may I change on this bin?", and the third let the player rewrite a live blueprint's build requirements and vent its delivered materials. The split matters: `player_configurable` says whether the **contents** are the player's (a Storage module's are, a Forge's are not), while **priority** is the player's on every bin because it is how the whole hauling system is steered. `UIPalette.shift_cell()` — the Crew rota and the schedule editor painted the same on/off-shift fact in two colour languages, one keypress apart. |
| **The amber budget** | Locked R&D nodes and locked module tooltips go inert (a tree of fifteen tier-gated nodes was fifteen amber pixels at rest); a pile, a designated asteroid and any gauge merely under full go cyan; the alert feed's accent goes by state and the log's is cyan. `UIPalette.gauge_tint()` / `GAUGE_LOW` is the rule for a gauge with no real predicate; a drone uses `wants_repair()`, which is better. |
| **The pause** | `TimeManager.pause_holders()` existed since WI-53 with exactly one consumer — a cheat. Pressing resume under a hold snapped the button back and said nothing. The console's cycle line now names the holder in amber, with the sentence on its tooltip. |
| **Coverage** | Build's footer (the ninth panel, not the eighth); HIRE and SHIFT ROTA naming their blockers on the button rather than in a tooltip; `M`, `L` and `show_details` printed from the live `InputMap`; rebind conflict detection widened past the remap screen's display list, with a test that parses `project.godot` to keep the classification complete; `ui/buttons/structure_button.*` deleted. |

**The rules this leaves behind** (they are in CLAUDE.md's UI section too):

1. **A `.tscn` form of a font size, a colour or a type variation is the same violation as its code form.** A sweep that greps `.gd` is half a drift guard.
2. **A page wider than its panel widens the panel.** An anchored `Control` clamps its size *up* to its combined minimum, so an over-wide inspector tab does not clip or scroll — the whole 420px selection surface grows. The probe sweeps the seam for it.
3. **An overrun behaviour without a reserved width collapses a label rather than capping it.** A `Label` with overrun reports a minimum width of ~1, and a `BoxContainer` with no expanding child hands every child exactly its minimum.
4. **When the sim will not resume, the console says who is holding it.** The pause/speed controls are the one place a player meets a blocked action with no panel to explain it.
5. **The feed yields; the inspector does not.** Any future tenant of the right column has to say which of those it is. *(2026-09-13)* While the inspector holds a selection the feed collapses to `AlertRules.COMPACT_CAP` rows — its most severe row plus `+ n more` — because the 220px floor stopped the inspector collapsing but left a selected module's Status tab scrolling inside a strip whenever a few alerts were up.

## What WI-63 added (a fourth kind of surface)

The program's three surfaces are the **mode panel** (`ConsolePanel`), the **readout**
(`ReadoutPanel`) and the **modal overlay** (pause menu, game-over screen, dialogue balloon).
[[WI-63_Tutorial]] needed something none of them can be: a thing that **points at chrome that
already exists**. `TutorialCoach` is that, and it is written down here as a fourth kind rather
than dressed up as a readout it is not.

What it must obey, since it lives under `ui/` like everything else:

- **It spends no amber.** The ring is `LIVE` — invariant 5 is intact, and the budget is still
  breach / falling vital / unread transmission / ARC. What makes a tutorial pointer
  unmistakable without a new colour is the **pulse**, which nothing else in the HUD does.
- **The pulse is real time.** `TimeManager.animation_speed()` returns 0 while the sim is held,
  and the tutorial runs entirely while it is. The coach must never join `sim_animation`.
- **One mark at a time**, the same way there is one open mode and one selection.
- **It re-resolves its target every frame** and keeps the caption plate when the target goes,
  so a panel closing under it leaves an instruction rather than a paused game with nothing on
  screen explaining why. It also takes itself down whenever no conversation is running.
- **It never covers the thing it points at.** It *may* cover another panel — a mark on a
  console vitals chip has the right column beside it and nowhere else to go at 1080p — and
  that is the accepted trade.
- **It names no colour, size or type variation**, and `tutorial_coach.tscn` is on
  `test_ui_theme.gd`'s sweep like every other scene under `ui/`. It must never be exempted.

Two defects here were **screenshot-only** and are worth remembering as a pair: a bare `Panel`
reports a zero minimum height (so a frame authored that way never draws at all — use a
`PanelContainer` when the surface has to size to its content), and the dialogue balloon is a
`CanvasLayer`, so it draws over *every* ordinary child of `UIMain` — any overlay that shares
the balloon's screen slot is invisible whenever anybody is talking.

## What moving HIRE changed (2026-08-24)

Hiring was a **component UI on the docking bay**: the recruitment window was a page in that
module's inspector, so the only way to learn the game *had* hiring was to find the right module
and click it. WI-56 mitigated it with a footer `HIRE` button that opened the same component UI
inside an `AcceptDialog` — two addresses for one window, and neither of them where the player
looks for crew. It is now the Crew panel's **`HIRE` tab**.

- **The gate did not move, only the window.** A hire arrives by shuttle and needs a bay to dock
  at, so `CrewManager.request_hire()` still takes the bay, `HireTab` still finds it through
  `Groups.CREW_RECRUITMENT`, and `CrewRecruitmentComponent` is still what marks a constructed
  docking bay as the station's crew gateway. What the component lost is `has_ui()` / `get_ui()`
  and its `ui_info_panel_element` — it is pure gameplay now, and `InspectorTabPlan`'s `"Hire"`
  row went with it.
- **`ROSTER` and `HIRE` are peers; the job board is not.** Who is aboard and who could be are
  alternatives and sit on a `TabStrip`. `SHOW ALL JOBS` stays a drill-down *through* the roster
  tab and now covers the strip as well as the page, because leaving `ROSTER` lit over the job
  board would claim it was a third alternative.
- **A blocker every card shares is the page's, not the card's.** This is the one new rule and it
  is extracted, per the risk below: `scripts/utility/hire_board.gd` (`HireBoard`), 20 tests. Four
  cards each printing `NO FREE SLEEPING PODS` under a page that also printed it was **only**
  visible in a screenshot. `HireBoard` never decides *whether* a hire is blocked — every sentence
  it sorts came from `CrewManager.hire_block_reason()`, which owns that. The single sentence it
  owns is `NO_BAY_REASON`, because the manager has no objection to hiring into a station with
  nowhere to dock.
- **The card's reason sits on the card, not in the button's label.** WI-58's rule is that a
  blocked action names its blocker *on its own control*; the 132px action column is exactly the
  width that made WI-58 move the roster's problem line off its button in the first place, so the
  sentence goes on the row beside the button rather than inside it.
- **The frame's subtitle serves both tabs** (`n aboard · n bunks` — bunks are what gates a hire),
  which is why the page prints only what the header cannot: `n ARRIVING BY SHUTTLE`, hidden at
  zero. The first draft repeated the crew and bunk counts four pixels below the header. Also
  screenshot-only.

Verified by a 40-check windowed probe plus five 1920×1080 screenshots; 1482 GUT green.

## What inverting the inspector changed (2026-09-13)

Source: the Claude Design handoff `Iridium Inspector.dc.html` (project `d4fdab39-dde5-4ff9-9aba-4ae13578fe3e`). It is a **layout** document, not a content spec — its tab names (`LOG`, `STAFF`) are illustrative — so everything the inspector already showed was kept and re-homed rather than dropped.

The inspector used to read top-down: a 34px `SELECTED · CREW` header, the subject block with its bars, a tab strip whose first tab was always open, the page, and a footer of actions. Every click paid for a whole page. It now reads **bottom-up**, and at rest it shows the vital information and nothing else.

| Part | What it is |
| --- | --- |
| **Identity strip** | On the panel's floor, sitting on the console's top edge, where the eye already is. Framed icon, name, meta line (the amber status line under it when there is one), and exactly two buttons: **◎ centre camera** (`camera_target()` → `GameCamera.jump_to`) and **✕ deselect**. Never anything destructive. It never moves: switching or closing tabs changes only what is above it. |
| **Tab rail** | `InspectorTabRail` (`ui/inspector/inspector_tab_rail.gd`): folder tabs standing on the strip. A **toggle, not a selector** — nothing open is the resting state, and pressing the open tab closes the box. The open tab gets `ACTIVE_BORDER` sides, a 2px `LIVE` cap and the `UIPalette.open_tab_gradient()` wash and stands 2px taller; while one is open the whole rail fills, side borders included. It is not a `TabStrip` because a strip always has something selected. |
| **Detail box** | Rises out of the open tab and grows upward as far as its page needs, stopped only by `UIMetrics.inspector_detail_max_height()` — what the column leaves under the map and alerts once the resting chrome has its share — past which the page scrolls. A page may carry a **footer row** under a divider (`InspectorTabSet.page_footer(id)`), rebuilt with the strip. |

Where things moved:

- **No header.** `InspectorPanel` extends `Control` and is no longer a `ReadoutPanel`; `inspector_panel.tscn` is a bare root and the whole surface is built in code from `UIMetrics`. `kind_label()` went with the header. `UIMetrics.inspector_max_content_height()` is deleted (all it did was subtract the header), and `alert_feed_max_height()` no longer reserves 34px for one.
- **No subject bars, no subject footer.** `subject_bars()` and `footer_actions()` are gone from the tab-set contract; `page_footer(id)` replaces the second. **FIRE sits beside the wage** on the Job tab's footer — the number you would check before firing sits next to the button — and the wage is now `EconomyManager.wage_for_pawn()`, the scaled figure actually charged (the meta line used to print the unscaled one). **DECONSTRUCT / DEMOLISH** hang under a new synthetic **Upkeep** tab (`ModuleUpkeepTab`: the integrity bar, a breakdown row, the module's upkeep line with a word on whether ARC has switched upkeep on yet), `BAND_STRUCTURE`, present once a module is complete. **DESIGNATE** moved under an asteroid's Contents, with the remaining-chunks bar.
- **The meta lines carry what the bars used to.** Crew: `PawnStatus`'s sentence · `Off shift` when the sentence has not said so · happiness. Module: cell · crew · haul · **`INT 88%`**. Integrity is still visible without opening anything, and the amber status line still says "Damaged" the moment it matters.
- **The open tab persists per kind, "none" included.** `InspectorTabPlan.tab_to_open()` / `tab_after_click()` are the rule, with tests. A remembered tab the next subject lacks opens nothing rather than some other page, and the memory survives it, so the next refinery still opens on Output.
- **Esc is unchanged** — still the selection rung, still a deselect.

Two deviations from the design, both because the game has more than the mockup drew:

1. **Tab padding is 8px, not 14, and the label is 11px through a new `UIType.INSPECTOR_TAB`.** The design drew four tabs; a crew member and a refinery have six. At 14px the sixth wrapped onto a second row, which only a screenshot showed. The 11px is the design's own size — the theme's strip tabs are 12. The rail still wraps rather than clipping when something carries more.
2. **The meta line wraps rather than ellipsing.** The design's meta fits on one line; `PawnStatus` sentences often do not, and the sentence *is* the vital information. A crew strip with a wrapped sentence rests at ~124px against the design's 108.

Three more after the first screenshots, at the user's direction — each walks back a piece of the design that did not survive being played with:

3. **The rail is solid while a tab is open.** The design filled only its lower half, leaving a see-through notch beside the tabs between the box and the strip. Now the whole rail fills and carries the box's side borders down to the strip, so the three parts are one column. At rest it stays clear.
4. **Flush on the console, not floating a gutter above it.** `UIMetrics.inspector_bottom_offset()` is `CONSOLE_HEIGHT`; the strip wears no bottom border, because the console's cyan top edge is that edge (the left panels' rule). `alert_feed_max_height()` stopped reserving the gutter that used to sit under the inspector.
5. **No 420px cap.** The detail box grows as far as its page needs, limited only by the map and alerts above it, which is what the inspector always had. `INSPECTOR_DETAIL_MAX_HEIGHT` is deleted.

One defect the inversion introduced and a screenshot caught: **a page opened from the resting strip is built while the box is still hidden**, so its autowrap labels measure at zero width and ask for several lines too many — a blank band under Status. The column's `minimum_size_changed` cannot see the correction, because the page sits in a `ScrollContainer`, which reports a fixed minimum whatever its child asks for. `_adopt_page` now connects each page's own `minimum_size_changed` to the fit. This is WI-51's "re-fit, never measure once" rule, with one more place the signal has to come from.

Verified by a 50-check windowed probe (every state the design names, the toggle, per-kind memory, the anchor, the three moved actions, ✕ and Esc) plus 1920×1080 screenshots of each state, and a second probe for the three changes above; GUT green.

## Cross-cutting risks

- **`ui_main.gd` was the choke point.** All nine items touch it, and it was 491 lines of hand-wired `_setup_*` calls. WI-50 reduced it to a mount table plus the mode registry; the check was "if it is still growing by WI-55, stop and refactor", and it never did — **481 lines at the end of WI-57**, ten fewer than it started with while absorbing nine items' worth of new surfaces. No refactor was ever needed. ✅ Closed.
- **MCP has been unreliable since the back half of Phase 3, and this is a UI program.** Headless probes cannot verify `_draw()`, shaders, or layout. Every panel WI needs a **windowed screenshot** in its verification, and the WI-48 lesson applies hard: *a probe must replicate the caller's exact call order*, because building a control in-tree hides layout bugs that the real mount path exposes. "Did the data arrive?" checks pass while a panel renders at zero height.
- **Pure logic must be extracted to be testable.** GUT covers pure classes only. Anything with a rule in it — alert severity classification, resource rate smoothing, ledger grouping, tab-set selection, panel geometry — belongs in a static/pure class with its own suite, exactly as `BuildMenuModel`, `MinimapTransform` and `OverlayPalette` already are.
- **Save compatibility.** Three items added save state in the end: WI-52 (`vitals`, the pinned resources), WI-53 (`alerts`, the history log) and WI-57 (`transmissions`, the Comms log). All three are absent-key-means-default sections registered by the node that owns the state, and **`SAVE_VERSION` never moved** — it is still 2, where WI-44 left it. ✅ Closed.
- **Do not gate gameplay on UI categories.** `ModuleData.ui_category` buckets the build menu; `tags` is gameplay (WI-43). The Stores and Crew panels will be tempted to group on one and filter on the other.

## Related

- [[New Work for Phase 4]] — the source brief, including the alert, crew, R&D and Comms corrections folded into this doc.
- [[WI-58_UI_Rework_Fix_Pass]] — the correction pass over all nine; see §"What WI-58 corrected".
- [[01_Technical_Specification]] — §1.18 is the HUD's architectural description. ✅ The flag this line carried from WI-50 ("needs a UI section; there is currently no architectural description of the HUD at all") was **stale**: WI-50 through WI-57 each wrote their own paragraph into §1.18 as they landed, and WI-58 confirmed it is current and added its own.
- [[02_Roadmap]] — Phase 4 ordering.
- [[03_Bugs_and_Improvements]] — **C13** (`force_withdraw` doesn't emit `total_changed`, so the credit HUD lags a slow tick) ✅ fixed in WI-52.
- [[WI-48_Pawn_Interactions]] — its §9 Social tab is superseded by WI-51's inspector tab set.
- [[WI-43_Build_Menu]] — the rail/flyout the Build panel is built from, and the `ui_category` vs `tags` rule.
- [[WI-36_Main_UI_Flow]] — Esc arbitration, the keybind remapper, and the out-of-game menus this program leaves alone.
