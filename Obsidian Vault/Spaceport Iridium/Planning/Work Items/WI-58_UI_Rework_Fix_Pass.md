# WI-58 — UI Rework Fix Pass & Component-UI Conversion

## Context

The nine-item UI rework (WI-49…WI-57, `Planning/04_UI_Rework_Program.md`) shipped 2026-08-10/11. I audited the shipped code against the program's design, its six invariants, and general readability/usability.

**The program's own design coverage is high and the doc is honest.** The port inventory is genuinely empty — every deleted surface's functionality has a home (I diffed `economy_screen` → `finance_tab`, the three trade screens → `trade_panel`+`contracts_tab`, `jobs_screen` → the Crew second view, `turboshaft_panel` → `TurboshaftTabSet`, and found nothing dropped). All 11 files the doc says were deleted are gone. There are zero dangling `res://ui/...` references in source. Four invariants are airtight: no panel hides itself, `TimeManager.paused` has exactly one sanctioned writer with every `hold_pause` released on every exit path, all 73 code sites use `UIType` constants, and all four list-row callers guard `selected_subject()` before `select()`.

**The gaps cluster in one place and one theme.**

The place is **the inspector's component UIs**. WI-51 deviations 7–8 deliberately kept 16 component UIs and 5 pawn tab scenes as pre-rework `.tscn`, flattening only their outer `PanelContainer` in `InspectorPanel._adopt_page()`. The design system stops at that seam — and it is the surface the player touches most. `ui/windows/storage_resource_line.tscn` is the worst case in one file: Kenney placeholder textures, two 16px font overrides, a raw crimson `self_modulate`, a 12×12 destructive `TextureButton`, and a bare `SpinBox` with **no `SpinBox/*` entries in `base_theme.tres` at all** — so Godot resolves its arrows from the engine's default *light* theme inside a dark console.

The theme is that **the verification sweeps were code-only**. WI-57 §8's claim of "zero `add_theme_font_size_override` calls in the console UI" is literally true — and structurally incapable of seeing the 28 scene-authored `theme_override_font_sizes` (six at 10px, under the design's own 11px floor) or the 7 scene-authored `Color(...)` literals that WI-49's "nothing in `ui/` may name a hex literal" forbids. `tests/unit/test_ui_theme.gd` is a good drift guard but only reads the theme resource, so nothing pins the scenes.

Separately there is one **layout bug that is not polish**: during a raid with a full alert feed, the inspector's tab content region computes to exactly zero height.

Scope confirmed with the user: one work item covering the defect fixes *and* the seam conversion.

---

## Stage 1 — Layout and readability defects

### 1.1 The inspector collapses to zero content during a raid — `ui/ui_main.gd`, `ui/theme/ui_metrics.gd`, `ui/inspector/inspector_panel.gd`

`UIMain._layout_right_column()` ([ui_main.gd:343](ui/ui_main.gd:343)) stacks map + raid readout + alert feed and hands the bottom to `InspectorPanel.top_limit`. Worst realistic case:

```
20 gutter + 240 map + 20 + 96 raid + 20 + 400 feed + 20  =  816 = top_limit
UIMetrics.inspector_max_height(1080, 816)          = 1080-112-20-816 = 132
UIMetrics.inspector_max_content_height(...)        = 132-34          =  98
InspectorPanel._chrome_height() for a crew subject ≈ 152
_refit(): page_height = min(page_min, max(0, 98-152)) =                 0
```

The tab content region vanishes entirely, and `content_height` is clamped to 98 while the column needs 152 — so the subject block, tab strip and footer overflow the frame's own rect. This is exactly what `ALERT_FEED_MAX_HEIGHT`'s comment ([ui_metrics.gd:186-192](ui/theme/ui_metrics.gd:186)) says must not happen; the 400px cap was chosen before WI-53 added the 96px raid readout above it, and never revisited. Non-raid worst case is 62px of page, which is under one `StatBar` row.

Fix, in `UIMetrics`:
- Add `INSPECTOR_MIN_CONTENT_HEIGHT` — the floor the selection surface may never go under (size it to subject block + strip + footer + ~2 rows).
- Replace the `ALERT_FEED_MAX_HEIGHT` constant with `alert_feed_max_height(raid_visible: bool, screen_height := SCREEN_SIZE.y) -> int`, derived by subtracting the map, the raid readout when present, the gutters, the console and the inspector floor from the screen height. `AlertRules.FEED_CAP` and this must still agree — keep the assertion relationship documented in both files.
- `_layout_right_column()` passes `_raid_readout.visible` in; the feed yields to the inspector rather than the other way round, which is the correct priority (the feed already has a `+ n more` overflow row and a history flyout; the inspector has nowhere to go).

In `InspectorPanel._refit()` ([inspector_panel.gd:386](ui/inspector/inspector_panel.gd:386)): `content_height` must never be clamped below `chrome`. Take `maxf(chrome, ...)` so the frame always contains its own chrome even if the budget is hostile, and let the page scroll.

Pure arithmetic → extend `tests/unit/test_ui_metrics.gd` with the raid-plus-full-feed case asserting a non-zero page.

### 1.2 Contrast: meta text 3.4:1, and blocked-reason sentences at 3.0:1 — `ui/theme/ui_palette.gd`, `ui/themes/base_theme.tres`

Computed sRGB/WCAG ratios against `PANEL #0b111b`:

| Token | Ratio | Verdict |
|---|---|---|
| `TEXT #9db9c9` | 9.20:1 | pass |
| `TEXT_EMPHASIS #eaf6fb` | 17.2:1 | pass |
| `TEXT_SECONDARY #5f7d94` | **4.37:1** | under 4.5 |
| `TEXT_META #4a6d85` | **3.44:1** | under 4.5, at 11px |
| `ATTENTION_TEXT` on amber row | 9.94:1 | pass |
| `DESTRUCTIVE` outline + text | 5.06:1 | pass |

The amber pairing and the destructive outline are right — the palette got the hard parts correct. Two problems:

- `TEXT_META` at **3.44:1 / 11px** is the most-used style in the HUD: every `ListRow` meta line, every timestamp, every panel `footer_text` ([console_panel.gd:373](ui/theme/console_panel.gd:373)), every hotkey hint. Lift it until it clears 4.5:1 on both `PANEL` and `CONSOLE`. `TEXT_SECONDARY` (readout labels, inactive tabs) needs a smaller lift.
- **`font_disabled_color` for all four button variations is `TEXT_META`** (`base_theme.tres:735, 745, 755, 768`). On the `ActionPrimary` disabled fill that computes to **3.01:1** — and that is precisely where WI-57's rule "a blocked action names its blocker on its own control" lands: `CommsPanel._inspection_button` renders its `InspectionBlock` sentence disabled in 6 of 7 states ([comms_panel.gd:363](ui/windows/comms/comms_panel.gd:363)), as do Crew's HIRE and Contracts' ACCEPT. The one place the design deliberately puts a sentence the player must read is the least readable text in the build. Give the button variations their own `font_disabled_color`.

Changing `TEXT_META` repaints most of the HUD — this needs a screenshot, not just a test.

### 1.3 `modulate` used to colour text — `ui/pawns/pawn_social_tab.gd:115,125,165`

`modulate` *multiplies* the theme's font colour. `_muted_label(…, UNMET_COLOUR)` renders `TEXT_META × TEXT` = `#2e4f69` → **2.22:1**; a feud renders `DESTRUCTIVE × TEXT` = `#83463e` → **2.62:1**. Three of the four opinion colours fail. This is WI-49's documented `self_modulate` trap in its `modulate` form. Use `add_theme_color_override("font_color", …)` with a `UIPalette` value.

### 1.4 The resource ledger's text column is ~72px — `ui/console/resource_ledger.gd:234`

`LEDGER_WIDTH 760` − 2 border − 20 pad = 738, ÷4 columns with 3× `LEDGER_COLUMN_GAP 8` → 178.5px/column. `ListRow` content margins ([ui_palette.gd:243-244](ui/theme/ui_palette.gd:243)) take 25, the icon 24, two 10px separators, and the action label ~37. **The name/meta block gets ≈72px** for a 15px entity name over an 11px meta line — "Iridium Ore" alone is ~78px. Compounding it, the Action label has no `text_overrun_behavior` ([list_row.tscn:68-73](ui/theme/widgets/list_row.tscn:68)) so it reports its full width as minimum and takes it out of the expanding text block first.

Fix: give `ListRow`'s action label an overrun behaviour and a max width, and widen the ledger — either drop to 3 columns with the fourth wrapping, or raise `LEDGER_WIDTH` (there is room; `LEDGER_RIGHT_INSET` is the only hard constraint).

### 1.5 The job board truncates the one thing it exists for — `ui/windows/jobs_screen.gd:190`

`JobDriver.explain_block()` is described at [jobs_screen.gd:11](ui/windows/jobs_screen.gd:11) as "the whole value of this view". Realistic strings run ~78 chars (`WAITING 3H · ASSIGNED WORKSPACE · NO BATCH READY AND NO MATERIALS TO START ONE`) ≈ 593px into a ~513px meta column, ellipsed. Let the block reason wrap onto its own line under the row, or move it to the row's tooltip *and* a second visible line — do not leave it as the ellipsed tail of a meta line.

### 1.6 The energy and crew vitals chips can re-lay the strip — `ui/console/vitals_strip.gd:308,325`

Resource chips go through `LedgerModel.format_compact` ([vitals_strip.gd:295](ui/console/vitals_strip.gd:295)); the two derived chips build raw `"%d"` / `"/%d"` strings instead. `VitalsChip` is a `PanelContainer`, so its minimum size is `max(custom_minimum_size, children)`. Two fusion reactors (`power_output = 2000.0` each) → `"3200"` + `"/4000"` ≈ 76px into a 68px budget: the chip grows past `VITALS_CHIP_WIDTH` and re-lays the whole strip out — the exact jitter [ui_metrics.gd:41-44](ui/theme/ui_metrics.gd:41) and `vitals_chip.gd:6-11` both assert cannot happen. Route both through `format_compact` and give the value/suffix labels an overrun behaviour.

### 1.7 `UIMetrics.tracking_center_nudge()` has zero callers

Written ([ui_metrics.gd:249-254](ui/theme/ui_metrics.gd:249)) because `spacing_glyph` adds space after *every* glyph including the last, so every centred tracked label sits half a tracking unit left of centre. Apply it at the three centred tracked labels: the mode-button caption, `TabStrip`'s buttons, and the Stores priority caption.

---

## Stage 2 — Convert the component-UI seam

The 16 component UIs (`ui/windows/*_component_ui.tscn`, `ui_storage_component`, `ui_sustenance_component`, …), the 5 remaining pawn tab scenes (`ui/pawns/pawn_{schedule,inventory,skills,job,social}_tab.tscn`, `simple_inventory_row.tscn`) and `ui/windows/component_ui_panels/`. Content and logic stay as they are — this is presentation only, exactly as WI-51 scoped the *rest* of the inspector.

Reuse, don't invent: `UIType.*` variations instead of `theme_override_font_sizes`; `UIPalette.*` instead of authored `Color`; `StatBar` / `Chip` / `ListRow` / `SectionLabel` / `ActionButton` from `ui/theme/widgets/`; `InspectorPanel._adopt_page()` already flattens the outer panel, so nothing needs its own surface.

**2.1 The two `SpinBox`es → `Stepper`.** `PriorityValue` ([ui_storage_component.tscn:137](ui/windows/ui_storage_component.tscn:137)) and `DesiredResourcesSpinbox` ([storage_resource_line.tscn:58](ui/windows/storage_resource_line.tscn:58)). `base_theme.tres` has no `SpinBox/*` entries and `SpinBox extends Range`, not `LineEdit`, so its arrows come from Godot's default light theme — these are the only un-skinned controls in the HUD. Swapping in `Stepper` also fixes a real bug for free: [ui_storage_component.gd:96](ui/windows/ui_storage_component.gd:96) calls `update_priority()` on *every* `value_changed`, so dragging priority across its 201-value range fires ~200 re-sorts of the job board. `Stepper`'s commit rule (`value_changed` on release/quiet period, `is_editing()` guard against tick-driven refresh) is what `stores_module_card.gd` already uses.

**2.2 Placeholder art and the 12×12 destructive button.** `storage_resource_line.tscn` pulls four Kenney placeholder textures. `RemoveResourceButton` is a **12×12** `TextureButton` that removes a resource and dumps its stock to a pile ([ui_storage_component.gd:114](ui/windows/ui_storage_component.gd:114)) — the smallest interactive control in the HUD and destructive. `DumpButton` is 20×20. Both become `ActionButton` (destructive weight = outline only, per the invariant the theme test already pins). Same for the schedule tab's 11×22 paint cells ([pawn_schedule_tab.gd:31](ui/pawns/pawn_schedule_tab.gd:31)) — widen toward a ~24px minimum.

**2.3 The six sub-floor font sizes.** `pawn_schedule_tab.tscn:43,49,55,61,66,71` set `font_size = 10` on the hour ticks and legend, under the design's 11px floor, on a live inspector tab.

**2.4 The two forked colour languages.** `pawn_schedule_tab.gd:9-10` names `WORK_COLOR`/`REST_COLOR` as raw floats; the Crew panel's SHIFT ROTA paints the identical on/off-shift fact with `UIPalette.tinted(LIVE, 0.55)` / `tinted(EDGE, 0.9)` ([crew_panel.gd:610](ui/windows/crew_panel.gd:610)). Same information, two colour languages, one keypress apart. Put the shift colours in `UIPalette` and have both read them.

**2.5 Delete the dead subtrees.** `DumpResourcePanel` ([ui_storage_component.tscn:144-208](ui/windows/ui_storage_component.tscn:144)) and `EditResourcesPanel` (`:210+`) — ~30 nodes, 9 `unique_name_in_owner`, zero script references since `StorageOverlays` took over. WI-56 deviation 9 deferred them to WI-57; WI-57 did not take them. One of them holds a `font_color = Color(0.297, 0, 0.120, 1)` at ~1.3:1 — a live counterexample sitting in a scene.

**2.6 Reconcile "can I edit this bin?"** Three surfaces currently give three answers. The Stores card disables the stepper for non-configurable bins; the inspector's storage tab leaves its priority control live and comments "Desired amounts are always configurable" ([ui_storage_component.gd:59](ui/windows/ui_storage_component.gd:59)); and the chip dialog (Stage 3.1) is a third. Pick the Stores card's rule, put it in `StoresModel` beside `lists` so it is testable, and have both surfaces read it.

**2.7 The guard that would have caught all of this.** Extend `tests/unit/test_ui_theme.gd` with a scene sweep over `ui/**.tscn` asserting: no `theme_override_font_sizes` outside the exempt set (`ui/menus/`, `event_card`, `game_over_screen`, `preview_module`); no authored `Color(...)` outside the same set plus the world-space files; every `theme_type_variation` string matches a declared `UIType` constant (all 33 do today — pin it); and `base_theme.tres` carries `SpinBox/*` entries if any `SpinBox` survives. This is the missing half of the drift guard — the existing suite reads the theme resource and is structurally blind to the scenes.

---

## Stage 3 — Behaviour fixes

**3.1 Make the read-only Stores card actually read-only.** `stores_module_card.gd` gates the stepper (`:209`) and prints *"Set by the module — readable here, edited where it is produced"* (`:242-247`), but wires its content chips unconditionally at `:302` into `StorageOverlays.open_resource`, which writes `desired` (`storage_overlays.gd:265`) and destroys stock (`:275`) on any bin. `player_configurable` defaults false, so this reaches processor input/output bays, sustenance bins, and — because `StoresModel.lists` deliberately keeps live construction sites — **a blueprint's construction import bin**, where it lets the player rewrite the build's requirements and vent its delivered materials. The card says one thing and does another. Open the dialog read-only when `not entry.configurable` (contents and averages visible, write controls disabled and named), using the same rule from 2.6.

**3.2 Say why the sim will not resume.** `ui_time_scale_select.gd:59-66`: pressing un-pause while a hold is outstanding snaps the button straight back, and selecting a speed pill lights the pill while the clock stays still. Holders come from a critical alert, a docked trader, an event card, the pause menu and game over. `TimeManager.pause_holders()` already exists ([time_manager.gd:160](scripts/managers/time_manager.gd:160)) and its only consumer in the project is `cheats.gd:496`. Map holder ids to a short sentence and show it on the control — the same `InspectionBlock` shape Comms uses. This is the clearest remaining violation of "a blocked action names its blocker".

---

## Stage 4 — Amber re-tone

Invariant 5 charters amber for breach, falling vital, unread transmission and ARC. Per your call:

- **Locked R&D nodes → inert/dim.** [unlock_node_card.gd:155-156](ui/windows/unlocks/unlock_node_card.gd:155) wears `ATTENTION_BORDER` + `ATTENTION_META` on every tier-gated node — a tree with 15 locked nodes is 15 amber pixels at rest. Same treatment for the locked module row and its tooltip (`module_button.gd:162`, `module_button_tooltip.gd:50`). WI-54's rule is "locked is a state, not an absence", which is about *rendering* it, not about alarming on it.
- **Progress / pile / designated asteroid → `LIVE`.** `module_tab_set.gd:147` (any bar under 1.0), `pile_tab_set.gd:44` (every pile, unconditionally), `asteroid_tab_set.gd:46` (designated for mining — the definition of "selected"), `robot_vitals_tab.gd:60` (charge < 1.0; note `:54`'s `wants_recharge` is the correct predicate and stays amber).
- **Unchanged, per your call:** auto-dump chips (`stores_module_card.gd:285`) keep their amber — a silently destroying setting earns a standing warning. Unaffordable costs keep theirs.
- Also worth a look while in here: `alert_feed.gd:68` / `alert_history.gd:78` set `accent_color = ATTENTION` once at build, so the accent bar is amber on an empty feed. Compare `inspector_panel.gd:229`, which swaps `TEXT_META` ↔ `LIVE` by state.

Add the amber-budget assertion to a test the way `PawnStatus`'s tone set already is (WI-56 contract 1).

---

## Stage 5 — Coverage and hygiene

- **The Build rail has no footer.** [ui_main.gd:114-123](ui/ui_main.gd:114) never sets `footer_text`; only the flyout has one (`build_menu.gd:232`), and Build opens with the flyout closed. WI-54 §1 and deviation 5 both say it should; WI-57 deviation 6 believed R&D was the only panel missing one. It is the ninth panel.
- **HIRE names its blocker in a tooltip, not on the button.** [crew_panel.gd:449-454](ui/windows/crew_panel.gd:449) keeps the label as `"Hire"` and puts `hire_block_reason()` in `tooltip_text`; Comms writes the sentence into the label. Crew is the outlier and it is the panel whose blocked state the player meets first. `_rota_button` (`:455`) is disabled with no reason at all.
- **Three bound hotkeys are printed nowhere:** `toggle_map` (M) — despite WI-49 naming it as a readout-header action, `ui/minimap.gd` never calls `add_action()`; `toggle_ledger` (L) — the ledger prints `ESC` but never `L`; `show_details` (Tab) — hold-to-show module labels is undiscoverable. Print them via the existing `ReadoutPanel.add_action()` / footer paths.
- **Rebind conflict detection has a hole.** `ui_aide`, `debug_fire_event` and `debug_offer_contract` are real actions absent from `Global.REMAPPABLE_ACTIONS`, and `Global.find_binding_conflicts()` ([global.gd:232](scripts/managers/global.gd:232)) only iterates that array — rebinding a mode onto F6 silently double-fires with no swap offer.
- **`ui/buttons/structure_button.{gd,tscn}` is fully orphaned** and its handler writes `Global.current_module`, which does not exist — it would error if it ever ran. Predates the program; delete.
- **Right-column horizontal geometry is scene-authored.** `ReadoutPanel._apply_layout()` ([readout_panel.gd:165](ui/theme/readout_panel.gd:165)) never writes `offset_left`/`offset_right`, so for a right-anchored control `panel_width = UIMetrics.RIGHT_COLUMN_WIDTH` is cosmetic and the real 344 lives as a hand-typed literal in six scenes (`minimap`, `alert_feed`, `raid_readout`, `alert_history`, `resource_ledger`, `inspector_panel`). All correct today; all silently stale if `RIGHT_COLUMN_WIDTH` moves. Have `_apply_layout` re-apply the offsets the way `ConsolePanel` does (`:285-288`). Same class of thing: `minimap.tscn:16`'s `content_height = 206` restates `STATION_MAP_HEIGHT − READOUT_HEADER_HEIGHT`, leaving that constant with no runtime consumer, and `stepper.tscn:27,41` hardcodes `EDGE` as floats in the WI-49 widget library itself.
- **Missing empty states:** the Build flyout on a search with no matches (opens titled `RESULTS`, subtitle `0`, blank body), Trade ORDERS with no tradable resources, an empty ledger category column, and a corridor selection (empty tab strip over a blank region).
- **`TradePanel._show_tab` (`:487`) lacks the re-route guard** `CommsPanel.show_tab` uses — the exact shape of WI-55's own tab-strip defect. Harmless today (one caller), cheap to close.

**Explicitly out of scope, per your call:** the `DebugAddButton` on `storage_resource_line.tscn` (a live, ungated free-resource deposit on every storage tab) stays — I will keep it wired through the Stage 2 conversion rather than dropping it. The AIDE button keeps printing F1 with no handler and no `REMAPPABLE_ACTIONS` entry.

---

## Verification

1. **GUT** — `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`. Baseline is 1060 green. New: the `UIMetrics` raid-plus-full-feed case (1.1), the scene-override sweep in `test_ui_theme.gd` (2.7), the bin-editability rule in `test_stores_panel_model.gd` (2.6/3.1), and the amber-budget assertion (Stage 4). Run `godot --headless --import` first if any new `class_name` lands.
2. **Headless probe** — the WI-30…WI-57 pattern: a temporary autoload running a numbered checklist, deleted afterward. Cover the pause-hold sentence for each holder id, the read-only chip dialog on a construction bin, the Stores/inspector editability agreement, and Build's footer.
3. **Windowed screenshots, driven into the state under test** — this is the program's own hardest-won rule and every panel item found defects a probe could not see. Required captures: the inspector during a raid with a full alert feed (1.1 — the whole point); a module's storage tab and a pawn's schedule tab before/after the Stage 2 conversion; the R&D tree with several locked nodes (Stage 4); `CONTACT ARC`, `HIRE` and a contract `ACCEPT` in their disabled states (1.2 — the sentences must be readable); the resource ledger with long resource names (1.4); the vitals strip with two fusion reactors online (1.6).
4. **MCP first, probe as fallback** — `project_run` → `logs_read` → `game_manage` → `project_manage(op="stop")`. MCP has been unreliable through the back half of Phase 3; if it dies, the autoload probe covers everything except `_draw()` and shader output.

## Documentation

- New `Planning/Work Items/WI-58_UI_Fix_Pass.md`, following the house format: status block with recorded deviations at the top, then design, then traps found.
- `Planning/04_UI_Rework_Program.md` — the program is complete, so this appends a "what WI-58 corrected" section rather than reopening the nine. Correct WI-57 deviation 6's "the one panel of nine with no standing instruction" (Build was the other), and note that WI-57 §8's override sweep was code-only.
- `CLAUDE.md`'s UI section — add the scene-authored rule (the `.tscn` forms of a font size, a colour and a type variation are the same violations as their code forms) and the corrected pause-feedback rule.
- `Planning/01_Technical_Specification.md` — still has no architectural description of the HUD; the program doc's Related section has flagged this since WI-50.