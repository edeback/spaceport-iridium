# WI-50 — Console Bar & One-Panel Mode System

> **STATUS: COMPLETE, 2026-08-10.** Second item of the [[04_UI_Rework_Program]]. Built on [[WI-49_UI_Design_System]]'s `ConsolePanel` and theme.
>
> **768 GUT tests green** (was 739; +29 in `test_mode_manager`). **104-check headless probe green** against the real `main.tscn`, a 23-check re-verification after the cleanup pass, and windowed 1920×1080 screenshots captured for the console at rest, Build (with and without its flyout), Crew, R&D, Overlays, and all four button states together. Save-neutral — this item adds no save state.
>
> **Deviations from the design below, and why:**
>
> 1. **STORES is bound to `E`, not `S`.** `S` is `camera_down` in the WASD pan cluster, and a hotkey that both opens a panel and pans the camera is worse than a weak mnemonic. The design's other collision (M for the map vs Comms) landed as the doc proposed: **M = map collapse, G = Comms.** A GUT test now scans every mode hotkey against every other bound action, so the next one of these is a test failure rather than a play-test discovery.
> 2. **`ModeManager` distinguishes "unregistered" from "declared unavailable".** §7 wants STORES rendered as a disabled button, and §Verification wants an unregistered mode to *error* rather than silently no-op. Those are in tension: pressing `E` would push an error every time. So `register_unavailable(mode, reason)` is a third state — the console renders it disabled with the reason as its tooltip, `open()` on it is a quiet no-op that cannot close the panel the player is using, and only a genuinely unknown mode errors.
> 3. **`_setup_alerts_strip` and `_setup_raid_ui` stay.** §8 lists both among the things that go, but their replacements are WI-53's and do not exist yet. The raid banner is the **only** route to `RaidManager.pay_off()`, so deleting it now would remove a real player action for the length of three work items. Both are marked in code as WI-53's to take.
> 4. **`create_resource_display` stays too**, retargeted rather than deleted. §2 says to mount the existing resource strip into the vitals zone as-is, which is the opposite of §8's "it goes". §2 wins: the strip is authored in `ui_main.tscn` (it carries the energy readout's exported label path) and is reparented into the console on ready. It is wrapped in a `ScrollContainer` because **seventeen** resource tiles are wider than the flex zone — without it the strip's minimum width shoves the time zone off the right edge. WI-52 replaces the whole thing with six pinned vitals and a ledger chip, and the wrapper goes with it.
> 5. **Esc has five levels, not four.** The doc's four assume WI-51 has already collapsed the info panels into one inspector. Until it does, level 4 is still the five-way selection chain. Two other ranks are worth recording: the **trader screen** sits above the mode (it is a sim-pausing modal, which is what it was before), and an **active overlay ranks last**, below everything. That is deliberate — "the panel closes, the overlay stays" means Esc must never take the tint away while the player still has something else open, and `0` clears it directly anyway.
> 6. **The trader auto-open is gone, as §Edge-cases directs** — §7's table row saying otherwise is the summary line, and the reasoned paragraph wins. Arrival raises an alert and lights TRADE's readiness dot. Nothing is stranded: `trade_component_ui` already opens the trader screen from the docking bay's own panel.
> 7. **A `ClockMetric` type variation was added to the theme** (Mono 700, 28px) and `UIType.CLOCK` with it. The design's 28px clock is the largest type in the HUD and had no variation; a per-label `font_size` override would have been exactly the drift WI-49 exists to prevent. `test_ui_theme` covers it like the other sixteen.
> 8. **`toggle_ledger` (L) is authored in the input map but deliberately kept out of `REMAPPABLE_ACTIONS`.** Settling the id now means WI-52 never has to rename an action players may already have remapped; listing it in the remapper before it does anything would ship a rebindable key that silently does nothing, and the settings screen is the one place an unhandled action is visible to the player. `ui_aide` (F1) is in the same state by design (decision 7).
> 9. **The overlay digit keys became real input actions after all** (`overlay_power` … `overlay_logistics`, `overlay_clear`). The first cut kept them as raw keycodes on the grounds that they were a like-for-like port, but the handler was being *rewritten* anyway (see the `Shortcut` trap below), decision 9 says hotkeys go in the input map, and the raw version consumed **every** bare digit press before the action system saw it — so anything later bound to a digit would have silently never fired. They are now in the remapper alongside the mode keys and inside the collision test.
>
> **Traps found, for the WIs that follow:**
>
> - **A `Shortcut` on a `Button` stops firing when the button is hidden.** The overlay hotkeys were `Button.shortcut`s, which worked only because the toolbar was always on screen. The moment the toolbar became a closable panel they died — and the design explicitly requires 1–5 to keep working with the panel shut. They moved into `OverlayController._unhandled_input`. **Any hotkey that must outlive its panel cannot live on a control inside it.**
> - **`top_level` detaches transform, not visibility.** The Build flyout is `top_level`, so hiding the Build panel hides the flyout *while leaving its own `visible` true*. `flyout_open()` had to become `is_visible_in_tree()`, or Esc's flyout level claims the key for a flyout nobody can see. Closing the mode also has to `close_flyout()` explicitly, or reopening Build reopens a category the player already dismissed.
> - **`move_to_front()` needs a layer to be safe in.** An opened panel has to draw over the ambient strips but must never draw over the modals or the pause menu. Mode panels are mounted on a dedicated full-rect `PanelLayer` added before them, so raising a panel is scoped.
> - **A panel that hides itself makes the manager lie.** Three ported screens had their own X button setting `visible = false`; under a mode registry that leaves `current()` stale and the next hotkey press closes nothing. They declare a `close_requested` signal, which `ModeManager.panel_for()` connects duck-typed exactly as it does `on_opened`/`on_closed`. That way the contract is enforced by the framework rather than by every panel remembering to reach through `Global.ui_main` — which matters because WI-51 through WI-57 add six more panels.
> - **A pawn with nothing to do still has a job.** `PawnBase._pick_next_job` hands an idle pawn an `idle_wander` job, so `current_job == null` lasts a frame or two; the CREW readiness dot keyed on it would essentially never light. `Job.is_idle_type()` is the test that already exists for this, and `PawnBreathingComponent` uses it. Found by review, not by play-testing, which is the argument for the readiness sources getting a pure classifier of their own in WI-53.
> - **`describe_event` output does not fit a 70px button.** "ESCAPE" overflowed the SYS face. `ModeManager.HOTKEY_ABBREVIATIONS` shortens per token for console use only; the remap screen keeps the full word.
> - **Godot's SVG importer needs one import pass before a `preload` of the file parses.** The first `--headless --import` after adding the glyphs fails every preload in `console_bar.gd` with "no resource loaders"; the second pass is clean.
>
> **Known follow-ups, not this item's:**
>
> - `ui_debug.tscn` (the pre-existing tilemap/mouse-cell readout mounted on the HUD in `main.tscn`) draws underneath the Station Map readout in the top-right corner. It predates this item and belongs to whoever decides the debug overlay's fate.
> - **The readiness sources live in `ConsoleBar` and are the one part of this item GUT cannot reach.** `_trader_is_docked` / `_an_unlock_is_affordable` / `_crew_wants_attention` are gameplay predicates inside a chrome widget, and the `is_idle_type` bug above is exactly what that costs. The program doc's own risk list says a rule belongs in a pure class with its own suite; WI-53 owns the alert severity model and is the natural place to land a shared classifier — at which point the mode→adornment mapping should become a provider registered alongside the panel factory, so a panel WI stops having to edit `console_bar.gd` as well as its own panel.
> - `ReadoutPanel` could take a `collapse_action` and self-wire its collapse hotkey; today `UIMain` hand-wires `toggle_map` for the one readout that has one. Worth doing when WI-53 adds the second.

## Goal

Build the console — the 112px bar welded to the bottom edge — and make **mode mounting exclusive**: opening one panel closes the last, so two panels can never coexist (invariant 1). Then port the existing screens in behind it *unchanged*.

That last clause is the point of doing this as its own item. The mockup's build order says it plainly: *"Port existing screens in behind it unchanged; they will look inconsistent for a while and still behave better than they do now."* Exclusive mounting plus a real hotkey per mode is a usability win that lands before any panel is redesigned, and it means the seven panel items that follow are each independently shippable.

## Design

### 1 — What the console replaces

Today, navigation is scattered across three places that grew independently:

- A left-hand `VBoxContainer` in `ui_main.tscn` holding a corridor-display checkbox, the build menu, a "Module Info" button, and four buttons appended at runtime by `ui_main.gd`'s `_add_side_button()` — which finds the Module Info button, *steals its stylebox*, and inserts a sibling above it. Research, Contracts, Economy and Jobs all arrive this way.
- A top-left resource strip (`ResourceDisplayPanel`).
- `overlay_controller.gd`'s own toolbar strip, positioned at a hardcoded `TOOLBAR_LEFT = 184.0` chosen to clear the left column.

All three go away. `_add_side_button` in particular is a mechanism whose only reason to exist is that there was nowhere else to put a button; the console is that place.

### 2 — The console

`ui/console/console_bar.tscn` + `console_bar.gd` (`class_name ConsoleBar`) — bottom-anchored, full width, 112px, `CONSOLE`→`#080d15` gradient, **a cyan top border** (the only surface in the game with one) and a 1px inner top highlight. Three zones separated by 1px `EDGE` dividers:

- **Modes, 715px, left.** Seven 70×74 mode buttons at 5px gaps, then a 1px×52 divider, then AIDE and SYS.
- **Vitals, flex.** Owned by [[WI-52_Vitals_And_Ledger]]. This item mounts the *existing* `ResourceDisplayPanel` content into the zone as-is and leaves the pinning/ledger work alone.
- **Time, 247px, right.** `HH:MM` at 28px Mono over `CYCLE n · DAY n` in `ReadoutLabel`, and below it the pause / 1× / 2× / 4× row — which is `ui/ui_time_scale_select.tscn` reparented and restyled, not rewritten.

The console is **opaque and consumes input** (`MOUSE_FILTER_STOP`) across its full height. The scanline overlay the mockup draws over the play area stops at the console's top edge; if that effect is wanted it belongs to the world layer, not here, and it is not part of this item.

### 3 — `ModeButton`

`ui/console/mode_button.tscn` + `.gd`: a 70×74 button with a 22px glyph over a 9px caps label, and three optional adornments the design distinguishes carefully:

- **Active state** — LIVE-tinted fill and LIVE border. The active *mode*.
- **A cyan bar under the button** — "an overlay is live even though the Overlays panel is closed." Distinct from active, because the overlay outlives its panel.
- **A readiness dot** (7px LIVE, glowing, top-right) — "there is something here you can do now." The mockup puts it on R&D, meaning affordable unresearched tech.
- **A count badge** (amber, 16px, top-right) — unread items. Comms.

Bar, dot and badge are three different signals and must not collapse into one "notification" concept. Each mode declares which it uses:

| Mode | Adornment | Source |
| --- | --- | --- |
| BUILD | — | |
| CREW | dot | idle crew, or an unhappy/resigning crew member |
| STORES | — | |
| TRADE | dot | a trader is docked |
| R&D | dot | an affordable, prerequisite-met, tier-met unlock exists |
| COMMS | badge | unread transmissions |
| OVERLAY | bar | an overlay mode is active |

Glyphs are the design's simple geometric shapes. Author them as SVGs in `ui/icons/console/` rather than drawing them in `_draw()` — `_draw()` content cannot be verified headlessly, and there is no reason to make these the exception.

### 4 — The mode registry

`ui/console/mode_manager.gd` (`class_name ModeManager`), a node under `UIMain`. It owns the *only* mutable "what is open" state in the HUD.

```
enum Mode { NONE, BUILD, CREW, STORES, TRADE, RND, COMMS, OVERLAY }
signal mode_changed(new_mode: Mode, previous: Mode)
func open(mode: Mode) -> void   # closes the previous one first
func close() -> void
func toggle(mode: Mode) -> void # pressing the active mode's button closes it
func current() -> Mode
```

Registration is `register(mode, factory: Callable)` returning a lazily-instantiated panel, cached after first use. Lazy because R&D and Trade are expensive to build and most sessions won't open all seven; cached because rebuilding a panel loses its scroll position and its filter state, and re-scanning `data/` on every open is wasteful.

**Panels are hidden, not freed, on close.** The exception is any panel that holds a live subscription it must not service while closed — those implement `on_opened()` / `on_closed()` and connect/disconnect there. `jobs_screen` and `economy_screen` already refresh only `if visible`, which is the same idea; make it a contract instead of a habit.

`ModeManager` is **session-only**. Nothing about which panel was open is saved; a load lands in the no-panel state, which is the state invariant 3 says the player returns to after every Esc.

### 5 — Esc, rewritten

`ui_main.gd`'s `_topmost_esc_claim()` is a 30-line ordered `if` chain over eleven named claims (`preview`, `flyout`, `trader`, `unlocks`, `contracts`, `economy`, `jobs`, `overlay`, `pawn_info`, `asteroid_info`, `pile_info`, `turboshaft`, `module_info`), paired with a matching `_close_esc_claim()` match statement. It works, and WI-36's comment correctly explains why the ordering has to be consulted from both sides. It also has to grow a case per surface, and this program is about removing surfaces.

After this item the chain collapses to four levels, because the layout guarantees the ordering:

1. **A held module preview** — the most transient thing on screen (`UIInGame.cur_input_mode != None`).
2. **A console flyout** — the Build category flyout, or the ledger. These are children of something else and close first.
3. **The open mode**, from `ModeManager.current()`. One check, not seven.
4. **The inspector selection** ([[WI-51_Inspector]]) — one check, not five.

Below that, nothing is open and the press belongs to the pause menu, exactly as now. The game-over latch stays at the top and keeps absorbing the key.

`esc_claimed()` keeps its signature so `PauseMenu` needs no change. The per-panel `_unhandled_input` Esc handlers in `contracts_screen`, `economy_screen`, `unlock_panel` and `trader_screen` are **deleted** — WI-36 tolerated the duplication because both paths did the same thing; with a mode manager, a panel closing itself behind the manager's back is a real bug.

### 6 — Hotkeys

New input actions, added to `project.godot`'s input map so WI-36's remapper picks them up automatically: `mode_build` (B), `mode_crew` (C), `mode_stores` (S), `mode_trade` (T), `mode_research` (R), `mode_comms` (M), `mode_overlays` (V), `ui_aide` (F1), `toggle_ledger` (L), `toggle_map` (`M`… see below).

**Collision to resolve:** the mockup prints `M` on the Station Map readout (for collapse) *and* wants a letter for Comms. Proposal: `M` = map collapse (it is printed in the design and the map is the more frequent action), Comms takes `G` for "signal". Whichever way it lands, it must be settled before the actions are authored, because renaming an action after players have remapped it invalidates their `settings.cfg` entry.

Pressing a mode's own hotkey or button while it is open **closes it** (`toggle`). Overlay number keys 1–5 and 0 stay owned by `OverlayController` and keep working with the Overlays panel shut — that is the stated design ("the panel closes, the overlay stays").

### 7 — Porting the existing screens behind it

Each of the four side-button screens and the two info panels gets mounted through `ModeManager` with **no internal changes**:

| Screen | Mounted as | Note |
| --- | --- | --- |
| `unlock_panel` | R&D | Still full-rect internally; it will be reflowed in WI-55 |
| `contracts_screen` | TRADE | Temporarily *is* the Trade mode; WI-55 makes it a tab of the real panel |
| `economy_screen` | COMMS | Same arrangement; WI-57 makes it a tab |
| `jobs_screen` | CREW | Already converted to `ConsolePanel` by WI-49; WI-56 puts the roster in front of it |
| `build_menu` | BUILD | Reparented out of the left column into a `ConsolePanel` |
| `overlay_controller`'s toolbar | OVERLAY | Toolbar strip becomes the panel body; `TOOLBAR_LEFT` goes away |
| `trade_screen` | — | Stays reachable from the docking-bay module inspector until WI-55 |
| `trader_screen` | — | Unchanged; still auto-opens on trader arrival and still pauses |

STORES has no predecessor and its button is **disabled with a tooltip** until WI-56. A disabled button that says why is better than a hidden one; it also proves the console layout at full width from day one.

### 8 — What shrinks in `ui_main.gd`

It is 491 lines of hand-wired setup and it is the choke point for all nine items. After this one it should be: the mode registry table, the four Esc levels, the inspector hand-off, and the game-over latch. `_add_side_button`, `_setup_alerts_strip` (moves to WI-53), `_setup_raid_ui`, `_setup_crew_ui`'s label, `create_resource_display`, the empty `_process`, and `_on_check_button_toggled`/`_on_info_button_pressed` all go.

The corridor-display checkbox (`_on_check_button_toggled` → `WorldManager.show_module_layer`) is a real feature with no home in the design. Park it in the **Overlays panel** as a toggle row below the five overlay modes — it is the same category of thing (a way of looking at the station) and the panel is the narrowest, so there is room.

## Files to touch

- **New:** `ui/console/console_bar.tscn` + `.gd`, `ui/console/mode_button.tscn` + `.gd`, `ui/console/mode_manager.gd`, `ui/icons/console/*.svg`, `tests/unit/test_mode_manager.gd`
- `ui/ui_main.gd` — mode registry, Esc rewrite, deletions per §8
- `ui/ui_main.tscn` — console mounted; left column, resource strip and Module Info button removed
- `ui/ui_time_scale_select.tscn` / `.gd` — reparented into the time zone
- `ui/overlay_controller.gd` — toolbar becomes the panel body; `TOOLBAR_LEFT`/`TOOLBAR_TOP` deleted
- `ui/buttons/build_menu.gd` / `.tscn` — reparented into a `ConsolePanel`
- `ui/windows/{contracts_screen,economy_screen,jobs_screen}.gd`, `ui/windows/unlocks/unlock_panel.gd`, `ui/windows/trade/trader_screen.gd` — delete their own Esc handlers; add `on_opened`/`on_closed` where they hold subscriptions
- `project.godot` — the new input actions
- `ui/menus/pause_menu.gd` — verify only; `esc_claimed()` is unchanged

## Implementation order

1. `ModeManager` + `test_mode_manager` first. It is pure state machine logic and everything else depends on its semantics.
2. `ConsoleBar` shell with the three zones, the existing resource strip dropped into the vitals zone, and the time zone. **Playable here** — no modes wired, but the clock and resources have moved and the layout is real.
3. `ModeButton` + the seven buttons + the adornment sources.
4. Wire the six existing screens through `ModeManager`, one at a time, deleting each one's side button as it lands.
5. The Esc rewrite. Do it *after* the wiring, when every surface is reachable through the manager and the four levels are actually true.
6. Hotkeys and the input map.
7. `ui_main.gd` cleanup.

## Edge cases

- **The trader auto-open path.** `trader_arrived` currently calls `_trader_screen.open()` from a signal handler. Under exclusive mounting, an incoming trader force-closing the player's open Build panel mid-placement is hostile. Resolution: the arrival raises an **alert** (WI-53) and lights TRADE's readiness dot; it does not steal the mode. The auto-open behaviour is deliberately dropped, and this is a design change worth stating rather than a bug.
- **The event card and the game-over screen are not modes.** They are modals that sit above everything including the console, and they keep working as they do. Do not route them through `ModeManager`.
- **The build preview survives its panel.** Closing Build while holding a module currently leaves the preview in hand. Keep that — Esc level 1 cancels the preview, level 3 closes the panel, and the ordering means one press does one thing.
- **A panel whose subject vanishes.** `turboshaft_panel` already watches `module_removed`; the trader screen already closes on departure. Under the manager these must call `ModeManager.close()` rather than setting `visible = false`, or the manager's idea of the current mode goes stale.
- **Mode hotkey during text entry.** The build menu has a search `LineEdit`; typing "steel" must not fire mode_stores and mode_trade. Guard on `get_viewport().gui_get_focus_owner()` being a text control, in `ModeManager`'s input handler, once.
- **Panku's REPL** is opened with backtick and is a `Control` in the tree; check it still receives input above the console.
- **Cheat-driven state.** `Global.cheats` fires `station_alert` and mutates managers directly; nothing in it should need to know about modes.
- **A second monitor / window resize.** The console anchors bottom-wide and the right column right-anchored, so `aspect="expand"` extra width lands in the vitals flex zone and the play area. Verify at 2560×1080 that the mode zone doesn't stretch its buttons (it is a fixed 715px, left-aligned).

## Verification

1. **GUT:** `test_mode_manager` — `open` closes the previous mode and emits `mode_changed` once with the right previous value; `toggle` on the active mode closes it; `close` on NONE is a no-op; a registered factory is called at most once; unregistered modes error rather than silently no-op (the WI-41 `build_module` silent-no-op probe trap is the precedent — a no-op that looks like success wastes a verification cycle).
2. **Headless probe:** open all seven modes in sequence and assert exactly one panel is visible at every step; assert Esc walks the four levels in order from a state with a held preview, an open flyout, an open mode and a selection all live at once; assert every mode hotkey opens its own panel and closes it on a second press.
3. **Windowed screenshot** of the console at 1920×1080 with each mode open, checked against mockup screens 1–9 for the 715/flex/247 zone split, the 70×74 buttons, the cyan top border, and each adornment type rendering distinctly.
4. **Manual:** trader arrives while Build is open → the panel does not close, TRADE's dot lights, an alert appears. Overlay stays painted with the Overlays panel closed and its console bar remains lit.
5. **Regression:** every ported screen still does what it did — research purchases, contract accept/decline, loan take/repay, the job board's block explanations, the build menu's search and recent list, all five overlay modes, and the corridor-display toggle in its new home.

## Related

- [[04_UI_Rework_Program]] — the mode inventory table and the console geometry.
- [[WI-49_UI_Design_System]] — `ConsolePanel`, `UIMetrics`, and the two pilot conversions this builds on.
- [[WI-36_Main_UI_Flow]] — the Esc arbitration this replaces, and the keybind remapper the new actions must appear in.
- [[WI-51_Inspector]] — Esc level 4; this item leaves the existing info panels alone.
- [[WI-52_Vitals_And_Ledger]] — owns the middle console zone this item only stubs.
- [[WI-53_Alerts]] — the trader-arrival alert that replaces the auto-open, and the badge/dot data sources.
- [[WI-43_Build_Menu]] — the rail/flyout being reparented.
