# WI-58 — UI Rework Fix Pass & Component-UI Conversion

> **STATUS: DONE 2026-08-14.** The correction pass over the nine-item UI rework ([[Spaceport Iridium/Planning/04_UI_Rework_Program]]), which stays complete — this appends to it rather than reopening it.
>
> **1111 GUT tests green** (was 1060; +51 across `test_ui_palette`, `test_ui_theme`, `test_stores_panel_model`, and two new suites `test_pause_holds` and `test_keybinds`). **92-check headless probe green** against the real `main.tscn`, including a sweep that instantiates every scene in the converted seam and asserts it fits the inspector. **Eleven windowed 1920×1080 screenshots**, each driven into the state under test. **Save-neutral**: nothing added, removed or renamed in any save section.
>
> ### Deviations from the design above
>
> 1. **`UIMetrics.tracking_center_nudge()` is applied through a style box, not a position write.** §1.7 says "apply it at the three centred tracked labels" and does not say how; Godot gives a [Label] and a [Button] no text-offset property at all, so the content margins are the only lever. Two helpers landed beside the existing function: `nudge_content_box()` (for a control whose box already carries a fill, i.e. a tab) and `tracking_center_box()` (for a bare label). Both put the **whole** tracking on the left margin, because a centred text moves by half of what you add to one side — the same "one trailing gap, split two ways" arithmetic the nudge itself is. A negative right margin would be the obvious alternative and silently does nothing: [StyleBox] reads a negative content margin as "unset".
> 2. **The schedule tab's paint cells got taller, not wider.** §2.2 asks for "a ~24px minimum". Twenty-four hours at 24px is 599px of cells inside a 420px inspector, and a page wider than the panel does not clip — **it widens the panel**. The first pass at 24 square pushed the whole selection surface out to ~515px. The cells are 14×24 with `SIZE_EXPAND_FILL`, so they share the tab's width (~15px each) and the hit target grew in the axis that had room. The probe now asserts this for every scene in the seam.
> 3. **`player_configurable` gates a bin's *contents* and nothing else — priority is always the player's.** §2.6 says "pick the Stores card's rule", and the card disabled *both* its stepper and its contents on that flag. Taken literally that made haul priority read-only on every processor bay, sustenance bin and construction site, which is wrong: the flag exists so that a multipurpose bin (Storage, Docking Bay) holds what the player says while a Forge always takes iron and carbon and always emits steel — it is about **what is in the bin**, not about where haulers take it. Priority *is* the routing language of the whole hauling system and is the player's main lever, so it stays live on every bin. `StoresModel` therefore answers two questions rather than one: `contents_editable()` (the accepted list, each desired amount, dumping) and `priority_editable()` (any bin that still exists). The asymmetry is stated in the model so no surface has to re-derive it.
> 4. **The pause-hold sentence lives in the console's cycle line, in two forms.** §3.2 says "show it on the control". A fourth row in the time zone overflowed the console's fixed 112px and clipped its own descenders off the bottom of the screen; and the zone is 247px, so "A critical alert is waiting — click it to resume" arrived as `A CRITICAL …`. The cycle number is what gives way (it returns the moment the hold releases, and stays on the tooltip meanwhile), and there are now two tables: `HOLD_LABELS` for the line and `HOLD_REASONS` for the tooltip. A test pins both against the five real holders and pins the line's length.
> 5. **`AlertFeed` caps its rows geometrically as well as by `FEED_CAP`.** Not in the design; found by the stage-1.1 screenshot. Once the feed yields room to the raid readout its budget is below four rows, and it rendered four into two-and-a-half — the last sliced across the bottom edge with a `+ 3 more` line underneath that no longer described what was on screen. That is precisely the failure `FEED_CAP`'s own comment warns about. The feed now shows whole rows only and hides the rest into the overflow count.
> 6. **`ReadoutPanel` gained a `right_inset` property.** §5 asks it to re-apply its own offsets; it needed a second number to do it, because the right column sits one gutter in and the two flyouts stop short of the column entirely.
> 7. **`Global.NON_REMAPPABLE_ACTIONS` is a second list, not a runtime scan.** §5's fix is "make `find_binding_conflicts` see every real action". There is no runtime way to tell the project's own actions from Godot's built-ins: `ProjectSettings.has_setting("input/ui_cancel")` is **true** for a built-in the project never touched, because the engine registers every one of them with a default. So the classification is explicit, and `test_keybinds.gd` parses `project.godot`'s `[input]` section to prove it stays complete — an action added to neither list fails there.
> 8. **The Crew panel's summary line moved above its actions.** A knock-on from putting HIRE's blocker on the button: `NO FREE SLEEPING PODS` is three times the width of `HIRE`, and it ellipsed the summary to `2 BUNKS…` on the panel whose whole job is that count.
> 9. **The alert log's accent is cyan, and the feed's is by state.** §4 only asks for a look at these. The log is a record of things already dealt with, so a permanently amber accent spends the budget on nothing; the feed goes dim / cyan / amber on `AlertRules.is_sticky`, the same predicate `AlertRow.treatment_of` paints its rows with, so the bar and the rows cannot disagree.
> 10. **The module integrity bar uses a threshold, the robot integrity bar uses a predicate.** §4 says both should stop being amber "under 1.0". A drone has `wants_repair()` — the same test it acts on — which is strictly better and is what the energy bar beside it already used. A module has no such predicate, so `UIPalette.gauge_tint()` and `GAUGE_LOW` are the rule for gauges that have none.
>
> ### Corrected after the first pass
>
> Five issues found by the author at the keyboard, two of them regressions this item introduced. All fixed and re-screenshotted.
>
> 1. **The tab strip's highlight stopped moving.** A regression from §1.7: the tracking nudge writes a stylebox *override*, and [method Control.get_theme_stylebox] consults a control's own overrides whenever the type asked for is the one it is currently wearing — so the second call handed back the box the first call had written, and every tab kept the fill it was born with while its text colour (which comes from the variation, unoverridden) updated correctly. `_nudge_tracking` clears the override before reading. **This is the general trap**: a widget that both sets an override and reads the theme through the same control has to clear before it reads.
> 2. **The fill-meter checkbox was gated on the bin's editability.** Wrong on its own terms — it is a preference about the player's own screen, not a property of the bin — and the same mistake in both surfaces. It is never disabled now, and in the accepted-resources dialog it moved *above* the eighteen-row resource list so an always-available control is not the one below the fold.
> 3. **A non-editable [Stepper] now hides its buttons rather than dimming them.** WI-58's own contrast lift is what made the first version wrong: with `font_disabled_color` raised for readability, a disabled `−` and `+` no longer read as disabled, so a locked bin showed two controls that looked live and did nothing. "Locked is a state, not an absence" is about the **value**, and the value is exactly what remains.
> 4. **Both storage dialogs were rebuilt.** The dump dialog put an autowrapped note in an [HBoxContainer] beside a fixed-width stepper, which wrapped to five lines and dragged the row's height up around a control floating in the middle of it; the accepted-resources dialog ran off the bottom of the screen and took `APPLY` and `CANCEL` with it, which made it not merely ugly but **unusable**. Both now use one shared frame → scroll → column shape at a fixed size clamped to the viewport, and stack their sections vertically. A read-only dialog also drops its `CANCEL`, which was a second button doing the same nothing as `CLOSE`.
> 5. **The storage line's debug `+` moved to the end of the row.** It sat immediately left of the stored value, so `57 / 80` read as though the `+` belonged to the 57.
> 6. **`player_configurable` was re-scoped to contents only** — see deviation 3, which this replaced. The knock-on: `DUMP` is now *hidden* on a bin whose contents the module owns (a button offering to vent a resource the player may not vent is worse than no button), and the Stores card's content chips become inert readouts there for the same reason. `open_resource`'s read-only rendering is consequently unreachable through the UI and stays as a backstop — WI-58 stage 3.1's point was that the write path is guarded at the source, not only by hiding the control that reaches it.
>
> ### Traps worth remembering
>
> - **A page wider than the inspector widens the inspector.** An anchored [Control]'s size is clamped *up* to its combined minimum, so an over-wide tab does not clip or scroll — the whole 420px selection surface grows. This is now a probe sweep over the seam.
> - **A [Label] with an overrun behaviour reports a minimum width of ~1, and a [BoxContainer] with no expanding child hands every child exactly its minimum.** So "add an overrun behaviour" on its own does not cap a label, it *collapses* it. Both the vitals chip's value and the list row's action needed a reserved width alongside the overrun.
> - **`ProjectSettings.has_setting("input/…")` cannot tell a project action from a Godot built-in.** See deviation 7.
> - **`modulate` on a [ProgressBar] tints its track as well as its fill.** WI-49 documented the `self_modulate` trap for text; the same trap eats the groove a bar sits in. `HatchBar` takes a fill colour and leaves the track alone.
> - **A probe that only calls a setter reads the state before the thing it triggered.** Almost every layout path in `ui/` is `call_deferred`, so the probe's helpers have to `await get_tree().process_frame` rather than poking notifications. Check 6 failed against correct code until they did.
> - **A `Window` sizes itself once, at popup, and an autowrapped [Label] answers that question worst.** `Label.get_minimum_size()` under `AUTOWRAP_WORD_SMART` reports the height of its text *at its current width*, which is zero before layout — so it asks for roughly one line per word. `AcceptDialog` believes it. Put the body in a [ScrollContainer], whose own vertical minimum is zero, and give the frame the size.
> - **A control that writes a theme override cannot read the theme through itself afterwards.** `get_theme_stylebox(name, type)` returns the override when `type` matches the control's current variation, so the second read returns the first write. Clear, read, write.
> - **Three defects were visible only in a screenshot**, which is the program's own hardest-won rule holding for a tenth item: the sliced alert row (deviation 5), the inspector widened to 515px by its own schedule tab (deviation 2), and the energy chip silently rendering `/400` for `/4000` — a *wrong number*, not an obviously truncated one.

## Context

The nine-item UI rework shipped 2026-08-10/11. This is the audit of the shipped code against the program's design, its six invariants, and general readability.

**The program's own design coverage is high and the doc is honest.** The port inventory is genuinely empty, all eleven files it says were deleted are gone, there are zero dangling `res://ui/...` references, and four invariants are airtight: no panel hides itself, `TimeManager.paused` has exactly one sanctioned writer, all 73 code sites use `UIType` constants, and all four list-row callers guard `selected_subject()` before `select()`.

The gaps clustered in one place and one theme.

The place was **the inspector's component UIs** — WI-51 deviations 7–8 deliberately kept sixteen component UIs and five pawn tab scenes as pre-rework `.tscn`, and the design system stopped at that seam.

The theme was that **the verification sweeps were code-only**. WI-57 §8's claim of "zero `add_theme_font_size_override` calls in the console UI" was literally true and structurally incapable of seeing the 28 scene-authored `theme_override_font_sizes` or the scene-authored `Color(…)` literals.

---

## What shipped, by stage

### Stage 1 — layout and readability

**1.1 The inspector no longer collapses during a raid.** `UIMetrics.ALERT_FEED_MAX_HEIGHT` (a fixed 400) is gone, replaced by `alert_feed_max_height(raid_visible, screen_height)`, derived bottom-up from the screen: console, gutter, the inspector's floor, the readouts above the feed. `INSPECTOR_MIN_CONTENT_HEIGHT` (220) is that floor. `UIMain._layout_right_column()` hands the budget in before it measures the stack, so **the feed is the tenant that yields** — it has an overflow row and a history flyout to spill into, and the inspector has nowhere. `InspectorPanel._refit()` now takes `maxf(chrome, …)` so the frame always contains its own chrome even if the budget is hostile.

The old numbers: 20 gutter + 240 map + 20 + 96 raid + 20 + 400 feed + 20 = 816 top limit → 98px of content budget against 152px of chrome → a **zero-height** tab region with the subject block, strip and footer rendering outside the panel's rect.

**1.2 Contrast.** `TEXT_META` 3.44:1 → 4.99:1, `TEXT_SECONDARY` 4.37:1 → 5.59:1, both now clearing 4.5:1 on `PANEL`, `CONSOLE` and `CONTROL_FILL`. A new `TEXT_DISABLED` token replaces `TEXT_META` as every `font_disabled_color`, because that is where WI-57's "a blocked action names its blocker on its own control" rule lands — `CONTACT ARC`, `HIRE` and a contract's `ACCEPT` all render their reason *as the disabled label*, and on the `ActionPrimary` disabled fill that computed to **3.01:1**. `test_ui_palette.gd` computes WCAG ratios and pins all of it, including the dim/dimmer ordering so a future lift cannot invert it.

**1.3** `pawn_social_tab.gd`'s three `modulate` uses are `font_color` overrides, and its opinion bar is a `HatchBar`.

**1.4** `LEDGER_WIDTH` 760 → 1080, `LEDGER_COLUMN_WIDTH` 176 → 254, and `ListRow`'s action label got `LIST_ROW_ACTION_WIDTH` (72) plus an overrun behaviour. The name/meta block went from ~72px to ~135.

**1.5** The job board's `explain_block()` sentence is on its own wrapped line under the row, plus the row's tooltip. It was the ellipsed tail of a meta line — the one thing the view exists to say.

**1.6** Both derived vitals chips go through `LedgerModel.format_compact`; `VITALS_CHIP_WIDTH` 108 → 124 with `VITALS_VALUE_WIDTH` reserved for the value and the suffix taking the rest.

**1.7** The nudge is applied at the mode-button caption, the tab strip and the Stores priority caption.

### Stage 2 — the component-UI seam

`storage_resource_line` and `ui_storage_component` were rebuilt: both `SpinBox`es are `Stepper`s (which also buys the commit rule — the old box fired `value_changed` on every step, so dragging priority across its 201 values re-sorted the job board about two hundred times), the four Kenney placeholder textures and the 12×12 destructive `TextureButton` are `ActionButton`s, the `⌦` auto-dump glyph is shared with the Stores card, and the two dead sub-panels (~30 nodes, 9 `unique_name_in_owner`, one `font_color` at ~1.3:1) are deleted.

Every remaining scene-authored `theme_override_font_sizes` and `Color(…)` in `ui/` is gone outside the exempt set. The shift-grid colours are `UIPalette.shift_cell()`, read by both the Crew rota and the schedule editor.

`StoresModel.contents_editable()` / `priority_editable()` / `locked_reason()` are the one answer to "what may I change on this bin?", read by the Stores card, the inspector's storage tab and the dump dialog. `player_configurable` gates the **contents**; priority is the player's on every bin.

**`test_ui_theme.gd` gained the scene sweep** — no scene-authored font size, no scene-authored colour, every `theme_type_variation` a declared `UIType` constant, and `SpinBox/*` theme entries required if any `SpinBox` survives.

### Stage 3 — behaviour

**3.1** `StorageOverlays.open_resource` opens read-only on a bin the module owns, with its reason named. Because `StoresModel.lists()` deliberately keeps live construction sites, the write path reached **a blueprint's construction import bin**, where it let the player rewrite the build's requirements and vent its delivered materials. The `confirmed` handler re-checks rather than trusting the disabled widgets.

**3.2** The console names what is holding the sim. See deviation 4.

### Stage 4 — the amber budget

Locked R&D nodes and the locked module tooltip go inert; a pile, a designated asteroid, a progress bar under full and a worn drone go cyan; the alert feed's accent goes by state and the log's is cyan. Auto-dump chips and unaffordable costs keep their amber, per the call. `UIPalette.gauge_tint()` / `GAUGE_LOW` is the one rule for a gauge with no predicate to borrow, and `test_ui_palette.gd` asserts the budget.

### Stage 5 — coverage and hygiene

Build's footer; HIRE and SHIFT ROTA naming their blockers on the button; `M`, `L` and `show_details` printed from the live `InputMap`; the conflict-detection hole closed with a completeness test; `ui/buttons/structure_button.*` deleted; `ReadoutPanel._apply_layout` writing its own offsets so `RIGHT_COLUMN_WIDTH` has a runtime consumer instead of six hand-typed `-364`s; `minimap.tscn`'s restated `content_height` and `stepper.tscn`'s `EDGE`-as-floats removed; `TradePanel.show_tab` re-routing like `CommsPanel.show_tab`.

**Not done, and explicitly out of scope per the call:** the `DebugAddButton` on the storage line stays (it is now an `ActionButton`, and it reads as a control in the row — the obvious next thing to gate), and the AIDE button keeps printing F1 with no handler. The Build flyout's empty-search state, Trade ORDERS with no tradables, an empty ledger column and a corridor selection were **not** given empty states; they are the one part of §5 left undone and belong in a follow-up.

---

## Verification

*As run.*

1. **GUT — 1111 green**, up from 1060. New: the raid-plus-full-feed budget arithmetic and the feed/`FEED_CAP` agreement (`test_ui_palette`); WCAG ratios for every text token on every surface it lands on, the dimness ladder, the disabled label on the primary fill, and the amber-budget assertions (`test_ui_palette`); the scene sweep and the theme's dim-text/disabled agreement (`test_ui_theme`); the two bin-editability rules and their locked reasons (`test_stores_panel_model`); `test_pause_holds` (11) and `test_keybinds` (7).
2. **Headless probe — 92 checks green**, mounted as an autoload against the real `main.tscn`. It drives the raid-plus-full-feed column and asserts the inspector keeps its floor and its frame contains its chrome; opens the ledger and measures it; opens the inspector's storage tab on an editable and a locked bin and drives the priority stepper through its own commit signal (the WI-45 A5 check); opens the read-only chip dialog on a module-owned bin, presses its confirm and asserts nothing was written; takes and releases each of the five pause holds and reads the console's line back; and sweeps every scene in the converted seam for a page that would widen the inspector.
3. **Eleven windowed 1920×1080 screenshots**, each driven into its state: the inspector during a raid with a full feed, the storage tab with real resource lines, a pawn's schedule tab, the ledger with long resource names, the vitals strip at 3200/4000, the R&D tree with two locked nodes, Comms with `CONTACT ARC` disabled, the Crew roster with `NO FREE SLEEPING PODS` on the button, Stores, Build, and the console under an outstanding hold. Three defects were visible only here — see the traps.
4. **Still owed by a human at the keyboard:** dragging a schedule cell across the grid at the new size, and watching the alert feed's row cap change live as a raid starts and ends.

## Related

- [[Spaceport Iridium/Planning/04_UI_Rework_Program]] — the nine items this corrects; §"What WI-58 corrected".
- [[WI-51_Inspector]] — deviations 7–8 left the seam this converts.
- [[WI-53_Alerts]] — the feed cap and the pause-hold refcount this builds on.
- [[WI-56_Panels_Crew_And_Stores]] — `StoresModel`, and deviation 9's deferred dead subtrees.
- [[WI-57_Panel_Comms_And_Retirement]] — §8's code-only sweep, and the blocked-action rule.
- [[WI-45_Save_System_Audit]] — A5, the `update_priority()` rule the new stepper must not break.
