# WI-56 — Mode Panels: Crew & Stores

> **STATUS: planned, not started.** Eighth item of the [[04_UI_Rework_Program]]. Depends on [[WI-49_UI_Design_System]], [[WI-50_Console_And_Modes]] and [[WI-51_Inspector]] (row clicks route to `select()`).

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

- **New:** `ui/windows/crew_panel.gd`, `ui/windows/stores_panel.gd`, `ui/windows/stores_module_card.tscn` + `.gd`, `scripts/utility/pawn_status.gd`, `tests/unit/test_pawn_status.gd`, `tests/unit/test_stores_panel_model.gd`
- `ui/windows/jobs_screen.gd` — becomes the Crew panel's second view; header gains a back control
- `ui/windows/ui_crew_recruitment.tscn` + `.gd` — reachable from the Crew footer as well as from the module
- `ui/pawns/pawn_schedule_tab.gd` — the read-only rota grid reuses its shift model
- `ui/windows/ui_storage_component.gd` + `.tscn`, `storage_resource_line.gd` + `.tscn` — the edit/dump overlays are shared with the inspector's storage tab rather than duplicated
- `modules/components/storage_component.gd` — an accessor for "does this module hold stock / is it configurable", plus the auto-dump-on-a-consumed-resource confirmation hook. **No mechanics changes.**
- `pawns/pawn_base.gd` / `robot_pawn_base.gd` — read-only; `PawnStatus` takes the pawn and asks
- `scripts/managers/crew_manager.gd` — read-only unless a "bunks short" helper is cleaner there

Not touched: `JobManager`, `StorageQuery`, job drivers, the hauling rules. This item shows the routing language; it does not change it.

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

1. **GUT:** `test_pawn_status` — a working pawn, a moving pawn, an idle pawn (no job), a loitering pawn (idle-type job), a sleeping pawn, a pawn in an emergency job, a robot recharging, a robot out of power, and a visitor each produce the expected sentence and colour class; a null job never crashes. `test_stores_panel_model` — sorting by priority/name/fill is stable and total; the "modules holding stock" count matches the card list; the bunks-short and idle/unhappy counts are computed from a hand-built roster.
2. **Headless probe, mounted as `ui_main` mounts it:** open Crew, assert one row per crew member and none for robots or visitors; assert the footer counts match a state set up by cheats (`spawn_pawn`, force an idle, drop a morale); click a row and assert the inspector selected that pawn. Open Stores, change a priority, and assert `update_priority()` was the path taken (an already-posted job's priority moved) — this is the WI-45 A5 regression and it is the one check this item most needs.
3. **Windowed screenshot** of Crew against mockup screen 4 (status sentence colour coding, morale bars, footer problem line) and Stores against screen 5 (legend line, sign-coloured steppers, contents chips).
4. **Manual:** hire from the Crew footer; open the job board view and confirm the block explanation still appears for a chosen pawn; set a storeroom to −100 from Stores and watch haulers stop delivering to it; dump a stack and confirm the amount matches the confirmation; enable auto-dump on a resource the galley consumes and confirm the warning.
5. **Regression:** the inspector's storage tab still does everything it did (it now shares the overlays); the recruitment window still works from the crew-quarters module; per-pawn schedule editing still works in the inspector.

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
