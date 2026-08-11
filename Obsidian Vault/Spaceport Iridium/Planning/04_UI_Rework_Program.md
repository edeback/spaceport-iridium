# 04 — UI Rework Program (WI-49 … WI-57)

> **STATUS: in progress — WI-49 … WI-54 shipped 2026-08-10, WI-55 and WI-56 shipped 2026-08-11, WI-57 not started.** This is the umbrella doc for the Phase-4 UI rework. It holds the things all nine work items share — the design-system tables, the invariants, the port inventory, the sequencing, and the decisions taken up front — so each WI can cite one authority instead of re-deriving the palette nine times.
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
2. **One inspector.** Crew, module, asteroid, pile, turboshaft and corridor selections render into the *same* bottom-right surface with a swapped tab set. Nothing selected shrinks it to a single line of text rather than hiding it.
3. **Left is doing, right is watching.** Panels only ever open on the left. Map, alerts and inspector own the right edge permanently and never move, so opening a panel shifts nothing the player was reading.
4. **Vitals are pinned; everything else is the ledger.** Six resources sit in the console strip; the rest live behind the ledger chip, grouped. Pinning promotes any resource into the strip, so the layout is indifferent to 20 resources or 100.
5. **Amber is a budget, not a colour.** Cyan means live / selected / affordable. Amber is reserved for breaches, falling vitals and ARC. Nothing decorative is amber, which is why one amber pixel reads instantly.
6. **One panel frame.** A 56px panel header, a 34px readout header, a 1px `#1d2c40` edge, a 1px inner top highlight, and the hotkey right-aligned in the header. *Most of the polish gap in the current build is frame inconsistency, not placement.*

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

Panels run from the top of the screen to the top of the console (`bottom: 112px`). The right column starts at `top: 20px, right: 20px`; the inspector sits at `right: 20px, bottom: 132px` (20px above the console).

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
| COMMS | 620 | M? | **New.** Transmissions + ARC; `economy_screen` becomes a tab | WI-57 |
| OVERLAY | 360 | V | `overlay_controller.gd`'s toolbar strip becomes a panel | WI-54 |
| AIDE | — | F1 | **Deferred stub.** See *Decisions* below | WI-50 |
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

✅ `buttons/build_menu.tscn` and ✅ `overlay_controller.gd`'s toolbar + legend (WI-54; `buttons/module_resource_cost_ui.*` deleted with them, `module_button_tooltip` demoted to the recent strip's hover card). ✅ `trade/trade_screen.tscn`, ✅ `trade/trader_screen.tscn` and ✅ `windows/contracts_screen.tscn` — all three **deleted**, merged into `trade/trade_panel.gd` + `trade/contracts_tab.gd` (WI-55); ✅ `unlocks/unlock_panel.gd` + `unlock_node_card.gd` reframed (WI-55). ✅ `windows/jobs_screen.gd` — no longer a panel; it is the Crew panel's second view and reports its shape through a signal (WI-56). ✅ `windows/ui_crew_recruitment.tscn` — unchanged, and now reachable from the Crew footer as well as from the crew-quarters module (WI-56). Still to go: `windows/economy_screen.gd` (WI-57).

**Untouched by this program:** `menus/main_menu.tscn`, `settings_menu.gd`, `save_load_menu.gd`, `keybind_row.gd`, `pause_menu.gd`, `game_over_screen.tscn` (WI-36's out-of-game flow — it has its own consistent look and no console). `event_card.tscn` is untouched here because the Phase-4 **Dialogue** item is going to rewrite it against Dialogue Manager; it should adopt the new theme for free and otherwise be left alone. `preview_module`, `selection_brackets`, `overlay_flow_layer`, `click_cycler` are world-space, not chrome.

## Decisions taken up front

Recorded here so the child WIs don't each re-litigate them.

1. **Contracts becomes a Trade tab; Economy becomes a Comms tab.** The mockup's Trade panel already shows `ORDERS / CONTRACTS / PRICE HISTORY / ROUTES`, and its Comms panel is captioned "PARENT CORPORATION · QUOTA, LOANS, PERSONNEL" — loans, the ARC levy, the ledger and tier progress are all ARC business. Neither screen gets a console slot of its own.
2. **PRICE HISTORY and ROUTES are stubs.** `MarketManager` keeps only current supply (`market_data`) and derives price from it — there is no history buffer, and routes are an undesigned system. Both tabs are **omitted** in WI-55 rather than faked; the tab strip is built to take them later. Adding price history is a ring buffer on `MarketManager` and a graph, and it should be its own item when someone wants it.
3. **Trade merges into one panel and keeps the sim pause while docked.** `trader_screen` today pauses the sim so the trader can't depart mid-trade (UI is real-time by design, so the screen keeps working while paused). That guarantee survives the merge: opening Trade *while a trader is docked* pauses; opening it otherwise does not. `trader_screen.tscn` is retired.
4. **Stores is presentation-only. WI-12 is already done** (2026-07-19; the roadmap, tech spec and bugs-doc D7 were corrected 2026-08-09). The Stores panel must therefore surface and edit **everything WI-12 shipped**: per-module haul priority, the per-resource desired amount, current contents, the accepted-resource checklist for `player_configurable` storages, manual dump (with amount), and the auto-dump toggle. Its two dropped tasks — the `draining` flag and mass-sell — stay dropped; see [[01_Technical_Specification]] §2.1. No new storage *mechanics* in this program.
5. **R&D spends credits, not research points.** The mockup's `48 RP · +2.1/CYC` header and per-node `120 RP` costs are for an undesigned system. `UnlockData.cost` is a `Dictionary[ResourceData, int]` and stays that way — the header carries the credit balance, node costs render as their real resource costs, and affordability is the existing `can_unlock()`.
6. **ARC inspections become player-initiated.** The `CONTACT ARC` button replaces `UnlockManager`'s per-cycle random offer roll. See WI-57.
7. **SYS opens the existing pause menu. AIDE is a deferred stub** — it renders and is disabled with a "not yet" tooltip. It is the natural mount point for the Phase-4 **Tutorial/Onboarding** item, and reserving the console slot now is free; inventing a help system inside a UI rework is not.
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
| [[WI-57_Panel_Comms_And_Retirement]] | Comms panel, ARC contact, and deleting the last legacy windows | The closer: nothing may be left mounted outside the console |

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
6. **Every HUD hotkey is a real input action** in `Global.REMAPPABLE_ACTIONS` — including the overlay digits, which WI-50 converted. `ModeManager.text_entry_has_focus(viewport)` is the one place that decides whether the player is typing; call it, do not re-write it.

Esc is now four levels in `ui_main.gd`: game-over latch → held preview → console flyout *(build flyout, then the resource ledger, then the alert log)* → the open mode → the selection → an active overlay. WI-51 collapsed the selection chain to one check; WI-52 added the ledger beside the build flyout and WI-53 the alert log; **WI-55 removed the trader-modal level** — folded into the Trade panel it *is* a mode, and its docked pause is a named hold the panel releases on close. **An outstanding critical alert is deliberately not on the ladder** (WI-53): the player hammers Esc, and an acknowledgement Esc can satisfy is one that gets satisfied without being read.

## What WI-51 landed (the selection API everything else consumes)

Shipped 2026-08-10. Details and the five traps found are in [[WI-51_Inspector]].

| File | What it is |
| --- | --- |
| `ui/inspector/inspector_panel.tscn` + `.gd` (`InspectorPanel`) | The one selection surface: a bottom-right `ReadoutPanel`, 420px, one gutter above the console, **growing upward** to a hard top limit. `SelectionKind`, `select()` / `clear()` / `kind()` / `selected_subject()` / `camera_target()`, the static `kind_of()`, `signal selection_changed`, and the nothing-selected line with its caret. |
| `ui/inspector/tab_sets/*.gd` | One `InspectorTabSet` per kind — `CrewTabSet`, `ModuleTabSet`, `AsteroidTabSet`, `PileTabSet`, `TurboshaftTabSet`. A set answers *what the thing is called, what its meta line says, which tabs it has, what each page holds*; the panel owns the surface. Nodes, not RefCounteds, so their connections die with them. |
| `ui/inspector/inspector_tab_plan.gd` (`InspectorTabPlan`) | Pure: module tab ordering (production → power → storage → crew → structure → *unknown* → upgrades), the short labels, duplicate numbering, and the component-derived crew tab set. 25 tests. |
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
| `ui/windows/crew_panel.gd` + `crew_roster_row.gd` | The 660px roster: filter pills, sort, the problem-line bar with `SHIFT ROTA` and `HIRE`, and the two-view state machine (`show_roster` / `show_board` / `board_visible`). |
| `ui/windows/stores_panel.gd` + `stores_module_card.gd` | The 1080px bin list: the legend line, sort, one card per bin with a priority `Stepper`, a fill gauge and contents chips. |
| `ui/windows/storage_overlays.gd` (`StorageOverlays`) | WI-12's two dialogs, extracted: the accepted-resource checklist and the per-resource desired/dump/auto-dump dialog, plus the shared `dump_to_pile`. Both the Stores card and the inspector's storage tab call in. |
| `Chip.chip_style(kind)`, `StorageComponent.resource_consumers()` / `autodump_warning()`, `PawnNeedsComponent.has_critical_need()` | The four additive helpers. |
| `JobsScreen` | Reframed again: a body rather than a panel, reporting its shape through `signal subtitle_changed`. |

**The contract for WI-57:**

1. **`PawnStatus` is the only place a pawn becomes a sentence.** The roster, the job board, the inspector's Job tab and `RobotVitalsTab.state_text` all read it; a fifth surface adds a caller, never a fifth set of rules. The tone set is closed and **only three states spend amber** (resigning, a critical need, a drone out of power) — invariant 5, enforced by a test.
2. **Off duty is not idle.** `PawnStatus.is_idle` requires `on_shift`, and the console's CREW readiness dot now asks the same question the panel's problem line answers. Any future "is somebody free?" check goes through it.
3. **A two-view panel swaps in place through public methods.** Crew's `show_roster()` / `show_board()` are public precisely because WI-55's tab-strip defect was a view driven around its own entry point; a probe or a screenshot driver must use the same door the player does.
4. **Storage priority has one vocabulary now** (`StoresModel.priority_label` / `priority_color`, delegating to `UIPalette.sign_color`) and one range. Nothing may print its own words for a haul priority, and **priority writes go through `update_priority()`** — the WI-45 A5 rule, now asserted by a probe that watches an already-posted job's priority move.
5. **A construction bin on a finished module is not storage.** `StoresModel.lists` is the membership rule; anything else enumerating bins should use it rather than `Groups.RESOURCE_STORAGE`, whose membership tracks `accepts_exports` rather than "has a StorageComponent".
6. **A screenshot is part of the verification, still.** Three of this item's defects were invisible to an 81-check probe — six dead bins the model and the panel agreed about, priority captions ellipsed to nonsense in a fixed column, and a colour that said the opposite of the text beside it.

## Cross-cutting risks

- **`ui_main.gd` is the choke point.** All nine items touch it, and it was 491 lines of hand-wired `_setup_*` calls. WI-50 reduced it to a mount table plus the mode registry; the check was "if it is still growing by WI-55, stop and refactor", and it is not — **480 lines after WI-56**, which added a one-line STORES factory and deleted the `register_unavailable` call and its reason constant. No refactor needed; WI-57 is the last item that touches it.
- **MCP has been unreliable since the back half of Phase 3, and this is a UI program.** Headless probes cannot verify `_draw()`, shaders, or layout. Every panel WI needs a **windowed screenshot** in its verification, and the WI-48 lesson applies hard: *a probe must replicate the caller's exact call order*, because building a control in-tree hides layout bugs that the real mount path exposes. "Did the data arrive?" checks pass while a panel renders at zero height.
- **Pure logic must be extracted to be testable.** GUT covers pure classes only. Anything with a rule in it — alert severity classification, resource rate smoothing, ledger grouping, tab-set selection, panel geometry — belongs in a static/pure class with its own suite, exactly as `BuildMenuModel`, `MinimapTransform` and `OverlayPalette` already are.
- **Save compatibility.** Only two items add save state: WI-52 (pinned resources) and WI-53 (alert history). Both are new absent-key-means-default sections; `SAVE_VERSION` should not need to move. WI-52's `vitals` section shipped this way and `SAVE_VERSION` did not move.
- **Do not gate gameplay on UI categories.** `ModuleData.ui_category` buckets the build menu; `tags` is gameplay (WI-43). The Stores and Crew panels will be tempted to group on one and filter on the other.

## Related

- [[New Work for Phase 4]] — the source brief, including the alert, crew, R&D and Comms corrections folded into this doc.
- [[01_Technical_Specification]] — needs a UI section once WI-50 lands; there is currently no architectural description of the HUD at all.
- [[02_Roadmap]] — Phase 4 ordering.
- [[03_Bugs_and_Improvements]] — **C13** (`force_withdraw` doesn't emit `total_changed`, so the credit HUD lags a slow tick) ✅ fixed in WI-52.
- [[WI-48_Pawn_Interactions]] — its §9 Social tab is superseded by WI-51's inspector tab set.
- [[WI-43_Build_Menu]] — the rail/flyout the Build panel is built from, and the `ui_category` vs `tags` rule.
- [[WI-36_Main_UI_Flow]] — Esc arbitration, the keybind remapper, and the out-of-game menus this program leaves alone.
