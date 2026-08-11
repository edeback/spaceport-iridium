# WI-56 — Mode Panels: Crew & Stores

> **STATUS: DONE, shipped 2026-08-11.** Eighth item of the [[04_UI_Rework_Program]]. Depended on [[WI-49_UI_Design_System]], [[WI-50_Console_And_Modes]] and [[WI-51_Inspector]] (row clicks route to `select()`), plus [[WI-55_Panels_Trade_And_RD]]'s content bridge and `Stepper.is_editing()`.
>
> **1033 GUT tests green** (was 965; +44 in `test_pawn_status`, +24 in `test_stores_panel_model`). **81-check headless probe green** against the real `main.tscn`. Windowed 1920×1080 screenshots captured of the Crew roster, the job-board view and the Stores panel. **Save-neutral** — this item adds no save state and reads none that moved.
>
> STORES is no longer a disabled console slot: `ui_main`'s `STORES_REASON` and its `register_unavailable` call are gone, and six of the seven modes now have a panel (Comms is WI-57's).
>
> **Deviations from the design below, and why:**
>
> 1. **The crew row is its own control, not a `ListRow`.** The design makes status *the primary column*, and a `ListRow` has a name over a meta line plus one right-hand slot — which would push the status sentence into either the meta position (where it reads as a subtitle of the name) or the action slot (where it ellipses to nothing). `CrewRosterRow` carries three stacked lines and a morale gauge, on the same `Button` skeleton and the same `UIPalette.Row` treatments. Code-built rather than a `.tscn`, like `UnlockNodeCard`.
> 2. **The filter pills are `Button`s wearing the tab type variations, not `Chip`s.** A `Chip` is a `PanelContainer`; making one clickable means hand-rolling hover, press and focus, which is exactly what WI-49's widget library exists to prevent. `Chip` did gain a static `chip_style(kind)` so the two controls share one definition of what a chip looks like — Stores' content chips are `Button`s too, for the same reason and with more at stake (they open the dialog that destroys resources).
> 3. **`PawnStatus` owns the roster's filter, sort and summary as well as the sentence.** The WI scopes it to the status text and files the roster counters under `test_stores_panel_model` (a slip — they are not storage). Everything derived from "what is this pawn doing" lives in one pure class with one suite; `StoresModel` keeps the storage half.
> 4. **`PawnStatus` takes a `Facts` record, not a pawn.** A live `PawnBase` cannot be constructed in GUT (its `_ready` reaches for `Global.path_manager`), so the rules take a plain record and `facts_for(pawn)` is the single adapter. That is what makes 44 tests possible.
> 5. **Off duty is not idle.** An off-shift crew member with nothing to do is the schedule working, not a staffing problem, so `PawnStatus.is_idle` requires `on_shift` — otherwise the footer would read `4 IDLE` every night forever. `console_bar._crew_wants_attention` was repointed at the same predicate, which strictly narrows a dot that used to light every night; a dot that lit for a roster the panel then reported as `0 IDLE` would be worse than no dot.
> 6. **An idle-type job never prints its own report.** `idle_wander` has a perfectly good sentence ("Wandering to Corridor"), and printing it would dress the absence the player is scanning for up as activity. "Idle — no work available" and "Idle — between jobs" are two different states and both are said out loud (the WI's edge case, with the two meanings the other way round from how it phrases them: `current_job == null` is the gap between jobs, `idle_wander` is the board having had nothing).
> 7. **`RobotVitalsTab.state_text` and the inspector's Job tab now delegate to `PawnStatus`.** The Job tab used to print the literal word "Nothing" for a null job — a third spelling of "Idle", which is precisely the drift the shared helper exists to stop.
> 8. **Both footer actions open dialogs, not panels.** Invariant 1 says there is one panel and neither `HIRE` nor `SHIFT ROTA` is a mode. Both parent to the HUD rather than to the panel body, so closing Crew cannot free a question the player is halfway through answering (the rule `CrewTabSet`'s fire confirmation already follows).
> 9. **The Stores overlays are shared by extraction, not by reuse.** `ui_storage_component.tscn`'s two hidden sub-panels became `StorageOverlays` statics and both surfaces call in. The `.tscn` still *authors* those subtrees — they are simply never shown. Removing `%`-unique-named nodes from a scene nothing here can visually verify is a worse trade than a few unreachable nodes; the WI-57 sweep can take them.
> 10. **The manual dump now respects reservations, which it did not before.** WI-12's *auto*-dump vents `stored − reserved_withdraw` (hardened by WI-38 A4), but its *manual* dump capped at `stored` and withdrew with `use_reserve = true` — so a hauler already walking to the bin arrived to find the stock it had claimed deleted, and the confirmation quoted a number the vent could not honestly reach. The dialog caps at `available_to_withdraw()` and withdraws without touching reservations. This is the one behaviour change in an otherwise presentation-only item, and it is the WI's own "the panel must show the same number it will actually dump, or the confirmation lies".
> 11. **The per-chip dialog carries the desired amount too.** The WI puts desired "on the resource chip, expanded or on hover-focus"; a chip that is already a click target for dumping should not also grow an inline editor, so desired, the one-off vent and the auto-dump toggle are the three controls of one per-resource dialog. The inspector's storage tab keeps its inline spinbox.
> 12. **A construction bin on a *finished* module is not listed.** `ready_constructed` drops it out of `Groups.RESOURCE_STORAGE`, stops its posting scan and hides its own UI — it is dead and permanently empty, and there is one on every corridor and airlock. Listing them put six inert `+100` cards at the top of the first station's list and pushed the two bins that actually held something below the fold. A construction bin on a *blueprint* is still listed: that one is a live construction site, which is the case the WI keeps.
>
> **Traps worth carrying forward:**
>
> - **A screenshot is part of the verification, and it caught three things an 81-check probe did not.** (a) The six dead construction bins above — every count check agreed with itself because the model and the panel shared the same wrong membership rule. (b) `URGENT — PULLS STO…`: the priority captions ellipsed in their fixed column on *every* card, so the caption that makes the routing language legible explained nothing. The captions are short now and the long form lives in the legend line, with a test on the length. (c) Five cyan `IN PROGRESS` rows on the job board all reading "Idle — no work available" — the data was right and the colour said the opposite.
> - **"The first configurable bin" is not a stockable bin.** The docking bay's export hold is `player_configurable` with an empty `storage_data`, and it has `accepts_exports = false` (its goods leave with the trader). A probe that wants a posted job to watch has to pick the bin by what it can actually do, and try the deficit direction as well as the surplus one — WI-55's "a probe that stocks a bin has to check it worked", one layer further in.
> - **`ConsolePanel.title` and `subtitle` are not what is on screen.** The frame upper-cases them at render time and leaves the properties as set, so a probe comparing against `"JOBS"` fails on a header that reads `JOBS`. Compare the property, or upper-case both sides.
> - **The starting station has zero bunks.** The roster's problem line says `5 BUNKS SHORT` from the first frame, and `HIRE` is disabled with "No free sleeping pods" on it. That is the panel working — it is the failure the WI says "the game currently only surfaces as a needs decay nobody connects to a cause" — but it does mean the very first thing a new player sees in this panel is a complaint. Worth a look during Phase-4 balance; not a bug here.

## Goal

The two panels with **no predecessor**. Mockup screens 4 and 5.

- **Crew** (660px) — every crew member with location, live job status and morale, filterable and sortable, answering "is my crew fine?" in one glance.
- **Stores** (1080px) — every module holding stock, its haul priority, and its contents, answering "where is my stuff and where is it going?"

Both are station-wide views of information that today exists only per-entity: to compare two crew members' morale you click each of them in turn, and to compare two storerooms' priorities you click each module. That per-entity-only access is why the routing language (storage priority) is hard to learn and why an unhappy crew member goes unnoticed until they resign.

## Design — Crew

### 1 — The roster

`ui/windows/crew_panel.gd` — a 660px `ConsolePanel`. Header: `CREW`, subtitle `n ABOARD · n BUNKS` (`CrewManager.crew_count()` and `sleep_capacity()`), `ESC`.

Filter row: `ALL` · `ON SHIFT` · `IDLE` · `UNHAPPY` as `Chip` pills, then a right-aligned **`SHOW ALL JOBS`** button (§3).

One `ListRow` per crew member: portrait swatch tinted with the pawn's `crew_tint_palette` colour, name in `EntityName`, current module in the meta position, then the **status sentence**, then a morale bar and number.

**Status is the primary column**, and the design is specific about why: *"'Working at Mining Bay', 'Moving to Refinery', 'Idle' — a full sentence, colour-coded: cyan working, grey transitional, dim idle, amber emergency. Idle is what the player is scanning for."* A sentence beats a state enum because the player is looking for the *absence* of purpose, and "Idle" reads as absence in a way that a blank cell does not.

The sentence comes from the pawn's `current_job`. `JobsScreen._detail_for(job)` and `PawnInfoPanel._robot_state_text()` both already build something like it; the shared version belongs in a pure helper (`scripts/utility/pawn_status.gd`, `class_name PawnStatus`, static, tested) so the roster, the inspector and the job board all say the same thing about the same pawn. Three places inventing three sentences for one state is how "Idle" and "No job" end up meaning the same thing on two screens.

**Morale is a bar, not a number** — *"bars are comparable at a glance down a column; numbers are not. The number stays for players who want it, and turns amber below 50."* Morale is `PawnNeedsComponent.happiness` × 100.

Sort: by status (idle first), morale ascending, or name. Idle-first-by-default is the right default because it puts the actionable rows at the top.

### 2 — The footer states the problem

*"A one-line summary — idle count, unhappy count, bunks short — so the panel answers 'is my crew fine?' without reading six rows."* `1 IDLE · 1 UNHAPPY · 2 BUNKS SHORT`, amber when any term is nonzero.

"Bunks short" is `crew_count() - sleep_capacity()` clamped at zero — a real failure the game currently only surfaces as a needs decay nobody connects to a cause.

Footer actions: `SHIFT ROTA` and `HIRE`.

- **`HIRE`** opens the existing recruitment content (`windows/ui_crew_recruitment.tscn`), which is today a *module component UI* on the crew quarters — meaning hiring is only reachable by finding and clicking the right module. As a Crew panel action it becomes discoverable. `CrewManager.hire_block_reason()` already produces the "why can't I hire" sentence; show it on the disabled button rather than making the player guess.
- **`SHIFT ROTA`** is a station-wide view of what `pawn_schedule_tab` shows per pawn. Scope it as a **read-only grid** in v1 (crew × shift, who is on when) with per-pawn editing still living in the inspector's Schedule tab. A station-wide schedule *editor* is a feature, not a reframing, and it doesn't belong in a UI rework.

### 3 — `SHOW ALL JOBS` is the job board

Per the brief: *"The 'Show All Jobs' button is what displays the same content as the current 'Jobs' screen, both the jobs taken by the crew as well as the ones not yet picked up."*

`jobs_screen.gd` (already converted to `ConsolePanel` by WI-49's pilot, and mounted as the CREW mode by WI-50) becomes the panel's **second view**, swapped in place — same mode, same width, a back control in the header. Not a tab strip, because it is a drill-down rather than a peer: the roster is who, the board is what.

Its content is unchanged and its value is intact — in-progress work swept from pawns, unclaimed work from `JobManager`'s board, and the `JobDriver.explain_block()` sentence saying **why a chosen pawn won't take a given job**. That explanation is the answer to "why is nobody hauling?" and it is the single most useful diagnostic in the game; it must not get lost in the reframing.

### 4 — Selecting a row

*"Clicking a name fills the same right-hand inspector as clicking the person on the station. One detail view, two ways in."* → `InspectorPanel.select(pawn)` plus `GameCamera.jump_to()`, the same two calls WI-53's jump-to uses. The panel does not open its own detail view. Ever.

### 5 — Who is in the list

Crew, from `CrewManager.get_crew()`. **Not** robots (no needs, no morale, no shift — they have their own state and belong in the inspector or a later robots view) and **not** visitors (guests aren't staff). Both exclusions fall out of asking for the crew list rather than scanning `Groups.PAWN`, which is also why they need no `is_robot` check.

A resigning crew member (`include_leaving`) stays listed, amber, with their grace window in the meta line — that is precisely a row the player must not miss.

## Design — Stores

### 6 — The routing language, finally visible

`ui/windows/stores_panel.gd` — a 1080px `ConsolePanel`. Header: `STORES`, subtitle `n MODULES HOLDING STOCK`, `ESC`.

Below the header, the design's legend line, and it is load-bearing: **`PRIORITY DECIDES WHERE HAULERS DELIVER FIRST · −100 REFUSE … +100 URGENT`**. *"A range that abstract needs its legend on screen, not in a tooltip."* Storage priority *is* the routing language of the whole hauling system — construction imports sit at +99, deconstruction exports at −99, and sinks must out-priority sources — and right now the player meets it as an unlabelled spinbox on one module at a time.

Then a sort control (`SORT: PRIORITY ▾` / name / fill).

One card per storage-holding module: name, sector/location meta, a **`Stepper` for priority (−100…+100)** as the widest hit target in the panel — *"the stepper is the only editable control in the panel and gets the widest hit target. Sign is carried by colour as well as by the number: cyan pulls stock in, amber pushes it away"* — and the contents as `Chip`s.

*"Contents are chips, not a table. Modules hold two or three resource types, not thirty, so chips read faster than columns and wrap cleanly as storage tech grows."*

### 7 — Everything WI-12 shipped must be reachable here

WI-12 (Storage QoL) is **done** (2026-07-19). Program decision 4: the Stores panel is presentation-only, and it must surface and edit **all** of it. Note that two of WI-12's designed tasks were dropped and stay dropped — the `draining` flag (unchecking a stocked resource dumps to the overflow pile rather than draining in place) and the trade-panel mass-sell button, both recorded in [[01_Technical_Specification]] §2.1 — so don't build UI for either:

| Feature | Where it lives now | In Stores |
| --- | --- | --- |
| Haul priority | `SpinBox`, per module | The card's `Stepper` |
| Per-resource desired amount | `SpinBox` per resource line | On the resource chip, expanded or on hover-focus |
| Current contents (+ average variance, `14 (72%)`) | Resource lines | The chips |
| Accepted-resource checklist (`player_configurable` only) | `EditResourcesPanel` overlay | A per-card `EDIT` action opening the same checklist |
| Manual dump with amount | `DumpResourcePanel` overlay | A per-chip dump action |
| Auto-dump toggle | Inside the dump overlay | A visible per-chip indicator that can be toggled directly |
| Free space / capacity | Two labels | The card's meta line |
| Fill-meter display toggle | Checkbox | Per-card, in the `EDIT` overlay |

Two things to get right rather than port literally:

- **Priority writes go through `update_priority()`, never a field assignment.** Assigning `priority` alone leaves already-posted import/export jobs at their old priority and `JobManager`'s re-sort cannot repair an ordering nothing told it changed. This was a real WI-45 finding (A5) and a station-wide panel makes it eight times easier to hit. `Stepper` must also debounce — dragging from −100 to +100 must not fire 200 re-sorts.
- **Auto-dump is currently buried in the dump dialog**, so a player who wants a surplus vented has to open a modal about something else. It surfaces as a per-chip state, because a *silently destroying* setting must be visible from the overview. The confirmation on enabling it for a resource a `SustenanceComponent` or `PowerComponent` consumes — noted in WI-12 as a kindness and skipped — is worth adding now that the setting is one click from the roster of every store.

Dump destroys resources. The standing rule is that **the player never loses resources without an explicit action that loses them, with no "too small to matter" threshold** — so the dump action keeps its confirmation, and the confirmation states the amount.

### 8 — Which modules appear

Any module with a `StorageComponent`. That includes processor input/output bays and construction sites, which are not `player_configurable` — they appear with their priority stepper **disabled** and their contents readable, because "why is the refinery hoarding ore" is a question this panel should answer even where it can't be edited. A card that is read-only says so; it is not hidden.

Row click → `InspectorPanel.select(module)` + `jump_to`, same as Crew.

## Files to touch

*As built.*

**New:**

| File | What it is |
| --- | --- |
| `scripts/utility/pawn_status.gd` (`PawnStatus`) | Pure. `Facts` / `Line` / `Summary` records, the sentence table, `describe` / `tone_of` / `is_idle` / `tone_color` / `tone_row`, the roster's `Filter` / `Sort` / `passes` / `sort_bucket` / `compares_before`, `summarize` / `summary_text` / `summary_color`, and the two adapters `facts_for(pawn)` / `of(pawn)` plus `location_of`. 44 tests. |
| `scripts/utility/stores_model.gd` (`StoresModel`) | Pure. `Entry`, the `Sort` orders and their total comparator, `LEGEND`, the priority range and bands, `priority_label` / `priority_color`, `lists`, `modules_holding_stock`, `subtitle_text`. 24 tests. |
| `ui/windows/crew_panel.gd` (`CrewPanel`) | The 660px body: filter pills, sort picker, `SHOW ALL JOBS`, the roster list, the problem-line bar with `SHIFT ROTA` and `HIRE`, and the two-view state machine (`show_roster` / `show_board` / `board_visible`). |
| `ui/windows/crew_roster_row.gd` (`CrewRosterRow`) | `swatch · name / status / location · morale`. Code-built, on `ListRow`'s `Button` skeleton and row treatments. |
| `ui/windows/stores_panel.gd` (`StoresPanel`) | The 1080px body: the legend line, the sort picker, the card list, and the repaint-in-place-unless-the-order-changed refresh. |
| `ui/windows/stores_module_card.gd` (`StoresModuleCard`) | One bin: name/location, fill gauge, the priority `Stepper` with its caption, contents chips, `EDIT`. |
| `ui/windows/storage_overlays.gd` (`StorageOverlays`) | The accepted-resource checklist, the per-resource desired/dump/auto-dump dialog, and the shared `dump_to_pile`. |

**Changed:**

- `ui/windows/jobs_screen.gd` — a self-framing `ConsolePanel` no longer; it is the Crew panel's second view, reports its shape through `signal subtitle_changed`, and takes its in-progress sentences from `PawnStatus`.
- `ui/ui_main.gd` — CREW builds `CrewPanel.create()`; STORES is registered rather than declared unavailable; `STORES_REASON` deleted.
- `ui/windows/ui_storage_component.gd` — both overlays now open through `StorageOverlays`; its own two handlers and the `edit_checkboxes` map are gone, and its priority range comes from `StoresModel`.
- `ui/theme/widgets/chip.gd` — `set_kind` now delegates to a new static `chip_style(kind)`, so a clickable chip can be a `Button` wearing the same surface.
- `ui/inspector/tabs/robot_vitals_tab.gd` — `state_text` is a wrapper over `PawnStatus.of()`; its six branches moved there.
- `ui/pawns/pawn_job_tab.gd` — the headline is `PawnStatus`, tone-coloured; the category stays.
- `ui/console/console_bar.gd` — the CREW readiness dot uses `PawnStatus.is_idle`.
- `pawns/pawn_needs_component.gd` — `has_critical_need()`, reading the same `was_critical` latch `_process` maintains.
- `modules/components/storage_component.gd` — `resource_consumers()` / `autodump_warning()`. **No mechanics changes.**

Not touched: `JobManager`, `StorageQuery`, job drivers, the hauling rules, `CrewManager`, `pawn_base.gd`, `robot_pawn_base.gd`, `pawn_schedule_tab.gd`, `ui_crew_recruitment.*`. This item shows the routing language; it does not change it.

## Implementation order

1. `PawnStatus` + tests, and repoint `jobs_screen` and the inspector at it. Pure, and it makes all three surfaces agree before any of them is rebuilt.
2. Crew roster: rows, filters, sort, footer summary. Row click → inspector.
3. `SHOW ALL JOBS` view swap; `HIRE`; read-only `SHIFT ROTA`.
4. Stores cards: priority stepper, contents chips, legend line. Read/write priority only.
5. Desired amounts, edit checklist, dump, auto-dump — shared overlays with the inspector tab.
6. Read-only cards for non-configurable storages.

## Edge cases

- **Priority re-sort storms.** §7. Debounce the stepper and commit on release.
- **A crew member dies or is fired while the panel is open.** The list rebuilds on `crew_departed`/`crew_resigned` **deferred** — the pawn is still in the tree until end of frame, which `ui_main._setup_crew_ui` already handles this way.
- **Zero crew.** The panel renders the footer's problem statement, not an empty box. Zero crew is also the `game_over` condition, so this state is brief but must not error.
- **A pawn with no job** vs **a pawn whose job is an idle-type job**. `Job.is_idle_type()` exists and the two are different: no job at all means the board had nothing it could take, an idle job means it chose to loiter. The status sentence should distinguish them, because the first is a station problem and the second isn't.
- **A pawn in a turbolift** has `current_module == null` and is in `CONVEYED` movement state. Location reads as the shaft, not blank.
- **A pawn outside on EVA** — location reads as exterior, and Void Sickness accrual makes this a row worth noticing.
- **Storage with `allow_any_resource`** (mining bay output) has no fixed accepted-resource list; the edit checklist shows read-only, as WI-12 specified.
- **A module whose storage is empty** — still listed if it is configurable (its priority still matters), because a store you've set to +80 and that is empty is exactly the interesting case.
- **Contents chips wrapping.** A `allow_any` bin mid-cargo-sweep can hold many types. Cap the chips shown and summarise `+n more`; the card must not grow unbounded.
- **Dump while a withdraw is reserved.** WI-12 already vents only `stored − reserved_withdraw`; the panel must show the same number it will actually dump, or the confirmation lies.
- **A module removed while its card is open** — cards rebuild on `module_removed`.
- **Robots hauling** show up in the job board view but not the roster. Someone will read that as a bug; the panel subtitle saying `n ABOARD` (crew) rather than `n PAWNS` is the mitigation.

## Verification

*As run. 1033 GUT green, 81/81 probe checks green, three windowed screenshots.*

1. **GUT, 68 new tests.** `test_pawn_status` (44) — a working pawn, a moving one, a pawn between jobs, a loitering one, an off-duty one, a needs job, a critical need, a resignation pending and final, a robot recharging / out of power / seeking a charger / being repaired / idle / working, and a visitor each produce the expected sentence and tone; a null `Facts` never crashes; **only the three alert states spend amber**, asserted over every job category; the roster summary counts idle / unhappy / leaving / bunks-short from a hand-built roster, counts a resigning pawn once rather than twice, clamps bunks-short at zero, tolerates a short happiness array and renders all four terms at zero; the four filters and the three sort orders, with the comparator asserted **antisymmetric over every pair in every order** (a non-total comparator is licence for `sort_custom` to do anything, including crash). `test_stores_panel_model` (24) — the three sorts are total and stable and never mutate their input, a null entry cannot crash the comparator, membership excludes previews and dead construction bins while keeping live construction sites, `modules_holding_stock` counts modules rather than bins, empty bins are listed but not counted, the priority vocabulary matches the legend at both extremes and delegates its colour to the shared `sign_color`, the captions are short enough for their column, and the player's range contains the system's reserved ±99.
2. **Headless probe, 81 checks**, mounted as an autoload against the real `main.tscn` and driving both panels through the entry points the player uses. Crew: the frame at 660px with real height, the inspector left alone behind it, one row per crew member with none for a spawned visitor, a hire appearing, the problem line matching a hand-computed summary and following a dropped morale, the filters narrowing and restoring, a name sort ordering the rows, a row click filling the inspector as CREW with a camera target and **not** deselecting on a second click, the view swap renaming the header / changing the footer / keeping the width and coming back, and the roster row printing the same sentence `PawnStatus.of()` produces. Stores: the frame at 1080px, one card per listed bin, the legend line on screen rather than in a tooltip, a card click selecting the module without toggling it off, contents chips rendering, a read-only card listed rather than hidden, `AVAIL` diverging from `HELD` on a claim and recovering on release, and the consumer warning present exactly when something eats the resource. **The WI-45 A5 check**: a bin provoked into posting a haul job, then the stepper driven through its own commit signal — the component's priority moves *and the already-posted job's priority moves with it*, while a `value_previewed` writes neither. Finally: exactly one panel visible in every available mode, Esc claiming the mode, and neither panel leaving a pause hold or touching the player's own `paused` flag.
3. **Windowed 1920×1080 screenshots** of the Crew roster (status sentences colour-coded, morale bars and amber numbers, the amber problem line, `HIRE` disabled with its reason), the job-board view (the back control in the header, `EXPLAIN FOR`, both sections) and Stores (the legend line, sign-coloured steppers with their captions, contents chips with icons, an amber auto-dump chip on a −100 `REFUSES` bin). Three defects were visible only here — see the traps above.
4. **Still owed by a human at the keyboard:** hiring through to a shuttle arrival from the Crew footer; watching haulers actually stop delivering to a bin set to −100 over several slow ticks; and confirming a dump of a partially-reserved stack matches the number the dialog quoted. The probe covers the state around each of these, not the multi-cycle behaviour.
5. **Regression:** the inspector's storage tab still does everything it did (it now shares the overlays and its per-line remove goes through the same overflow-pile path); the recruitment window still works from the crew-quarters module, and the Crew footer opens the same component UI; per-pawn schedule editing still works in the inspector, and the rota grid is read-only as scoped.

## Related

- [[04_UI_Rework_Program]] — decision 4.
- [[WI-12_Storage_QoL]] — the storage features this panel must surface in full.
- [[WI-44_Job_System_Refactor]] — the job board and `JobDriver.explain_block()` behind `SHOW ALL JOBS`.
- [[WI-45_Save_System_Audit]] — A5, the `update_priority()` rule this panel must not break.
- [[WI-40_Storage_Query_Helper]] — the priority-as-routing semantics the legend line explains.
- [[WI-22_Pawn_Identity]] — names, tints and the hire flow.
- [[WI-06_Shifts_and_Schedules]] — the rota this shows read-only.
- [[WI-51_Inspector]] — `select()`, and the shared storage overlays.
- [[New Work for Phase 4]] — the `SHOW ALL JOBS` requirement.
