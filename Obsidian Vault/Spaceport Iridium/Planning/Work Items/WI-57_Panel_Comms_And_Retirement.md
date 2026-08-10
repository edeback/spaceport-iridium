# WI-57 — Comms Panel & Legacy Retirement

> **STATUS: planned, not started.** Ninth and closing item of the [[04_UI_Rework_Program]]. Depends on every prior item.

## Goal

Two things, and the second is why this is the last item:

1. **Comms** (620px) — the station's relationship with the outside world: incoming transmissions, and ARC as a standing action. Mockup screen 8. It absorbs the Economy screen as a tab (program decision 1) and the tier/promotion section, and it makes **ARC inspections player-initiated** (decision 6).
2. **Retirement** — nothing may be left mounted outside the console. This is the sweep that makes the invariants true rather than mostly true, and it can only happen once every panel has a home.

## Design — Comms

### 1 — ARC is a fixture, not a message

The panel's top block is permanent and amber: `CONTACT ARC`, `PARENT CORPORATION · QUOTA, LOANS, PERSONNEL`, and a `HAIL` action. *"The parent corporation gets a permanent amber block above the feed because it is always available to hail — it is an action, not something that arrived."*

Amber here is one of the four sanctioned uses (invariant 5: breach, falling vital, unread transmission, ARC).

### 2 — Contact ARC replaces the random inspection roll

Per the brief: *"Instead of the Inspection event firing randomly, the 'Contact ARC' button allows the player to pick when they are ready for an inspection."*

Today (`unlock_manager.gd`, WI-26), on every `cycle_changed`: tick the re-offer cooldown; bail if an offer is pending or a tour is running, if the station is at max tier, or if the cooldown is live; bail unless `tier_goals_met()`; bail unless a docking bay exists; then roll `inspection_offer_chance_per_cycle` (0.5) and fire an event card the player accepts or declines.

So the player meets promotion as a coin flip that may or may not happen on a cycle where they happen to be ready. Under the new design the *readiness* checks stay and the *dice* go away:

- `_on_cycle_changed`'s offer roll is **deleted**, along with `inspection_offer_chance_per_cycle`, `_inspection_offer_pending` and `_offer_inspection()`.
- `inspection_reoffer_cooldown_cycles` is **kept** — a failed inspection should still cost you a few cycles before you can try again, and that is a consequence, not a dice roll. `decline_inspection()` goes away with the offer it declined.
- `begin_inspection()` becomes the button's action, called directly. Its existing guards (a bay must exist; abort harmlessly if the bay vanished) are already written for being called at an arbitrary moment.
- `arc_inspection_offer` (the `EventData`) is retired from the natural event pool, or deleted.

The button therefore has four states, and each names its own blocker rather than being greyed:

| State | Reads |
| --- | --- |
| Ready | `REQUEST INSPECTION` |
| Goals unmet | `n OF m EXPORT GOALS MET` (disabled) |
| No docking bay | `NO DOCKING BAY TO RECEIVE THEM` (disabled) |
| Cooling down after a fail | `ARC WILL RETURN IN n CYCLES` (disabled) |
| Tour running | `INSPECTOR ABOARD` (disabled) |
| Max tier | `NO FURTHER PROMOTIONS` (disabled) |

This is a **gameplay change, not a UI change**, and it is a good one: it converts a "wait and hope" into a "prepare, then commit", which is the shape the rest of the tier system already has. It also makes the first-inspection moment — which flips `EconomyManager`'s wage/upkeep/levy cost streams on — a deliberate player decision rather than something that happens to them. That consequence must be spelled out on the button's tooltip for the *first* inspection, because a player who doesn't know that walks into recurring costs they didn't choose.

### 3 — The transmission feed

Below the ARC block: `INCOMING` with `MARK ALL READ`, and a list of `ListRow`s — 34px avatar slot (*"sized to take a faction portrait later without re-laying the list out"*), sender, subject line, and a timestamp or a `NEW` badge. **Unread is a panel treatment**: cyan edge and brighter type, *"matching the alert feed's unread convention exactly, so the two lists teach each other. The console badge is the same count."*

There is no message system in the game. Rather than invent a mail client, this is a **small persisted log that existing systems post to** — the same shape as WI-53's alert history, deliberately, so the two are one pattern:

`scripts/utility/transmission_data.gd` — `{ id, sender, subject, body, cycle, hour, unread, action }`, where `action` is an optional route (`open_mode(TRADE)`, `select(module)`, `accept_contract(id)`).

Posted by: `ContractManager` on offer (`"%s offers a contract: …"` is already a `station_alert`), `TraderManager` on arrival and on a standing offer, `UnlockManager`/`InspectionRunner` for ARC messages, `EconomyManager` for settlements and loan events, `EventManager` for events with a narrative sender. Each of these already emits an alert; a transmission is the *durable* half of the same notification, and the two should be raised together by one helper rather than at 20 separate call sites.

**Keep the distinction sharp:** an alert is "look at this now" (transient or acknowledgeable); a transmission is "this arrived and you can read it later". A hull breach is never a transmission. A contract offer is both.

Saved as a new `SaveManager` section (`"transmissions"`), bounded ring buffer, absent key = empty, so pre-WI-57 saves load and `SAVE_VERSION` stays put.

The Comms console button's **amber count badge** is the unread count (WI-50 §3).

### 4 — Economy becomes a tab

`economy_screen.gd` moves in whole as the `FINANCE` tab: balance, this-cycle and last-cycle ledger breakdowns by category, the expandable wages/upkeep per-payer detail, the visitor count and reputation, the ARC levy summary, loan take/repay, and the read-only recurring-cost toggle state.

It belongs here because it is ARC's business — the levy is ARC's skim, the loans are ARC's loans, and the cost streams switch on when ARC promotes you. Its content is unchanged; it loses its bespoke frame and its own Esc handler.

### 5 — Tier progress moves in too

WI-26's tier/promotion section (export goals and their progress, the inspection checklist tags, current tier and what the next one unlocks) currently sits in the Research panel's header area. It moves to Comms as part of the ARC block or a `QUOTA` tab, next to the `REQUEST INSPECTION` button that acts on it. Goals and the button that submits them being in two different panels is the current arrangement and it is the thing worth fixing.

`SignalBus.station_tier_progress_changed` already exists and already drives that section; it follows.

### 6 — The raid payoff

WI-53 deleted `ui_main`'s bespoke top-centre raid banner and made raid-start a critical alert. The **shrinking payoff** still needs a home while a fight is on: `RaidManager.current_payoff()` falls over time and `can_pay_off()` gates it. Put it in the ARC block as a live row while `RaidManager.active` — hailing for terms is the same category of action as hailing ARC, and Comms is already the "talk to someone" panel. The console's COMMS badge should reflect it.

If playtesting says a payoff buried one keypress deep is too slow during a fight, the fallback is a compact live strip above the console — but not a return to a bespoke floating panel.

## Design — Retirement

### 7 — The sweep

Delete, verify, and make the invariants true. By the end of this item:

- **Nothing is mounted in `ui_main.tscn`'s root except** the console, the right column (map, alerts, inspector), the mode panel container, the ledger flyout, and the three legitimate modals (event card, pause menu, game-over screen).
- **`_add_side_button` and the left `VBoxContainer` are gone** (WI-50), and so is anything that positioned itself relative to them — grep for hardcoded left offsets, `TOOLBAR_LEFT`-style constants, and `PRESET_TOP_WIDE`/`PRESET_CENTER_TOP` anchors on HUD children.
- **Every deleted file is actually deleted**, not left orphaned: `resource_display_ui`, `energy_display_ui`, `pawn_info_panel`, `module_info_ingame_panel`, `module_info_panel.tscn`, `popup_panel.tscn`, `trader_screen`, `turboshaft_panel`'s standalone scene, `resource_pile_inventory_tab.tscn.agent_backup`, and `ui/themes/spinbox_theme.tres` if `Stepper` obsoleted it. Check `.uid` files go with them and that no `.tscn` still references them.
- **`ui/data/` is empty** and either gets used or gets removed.
- **`ui_main.gd` is the mode registry, four Esc levels, the inspector hand-off and the game-over latch** — and nothing else. It started this program at 491 lines.
- **Every `add_theme_*_override` that the theme now covers is gone** (WI-49 §7's sweep, re-run at the end because six items will have added some).
- **One `Esc` chain, four levels**, and no panel closes itself behind `ModeManager`'s back.
- **The tech spec gets a UI section.** [[01_Technical_Specification]] currently describes no part of the HUD. The console, the mode registry, the inspector, the alert tiers, the ledger and the widget library are architecture now, and the next person needs the same summary the managers and components get.
- **CLAUDE.md gains a UI paragraph.** There isn't one today, and by this point the console, the mode registry, the inspector and the alert tiers are the first thing anyone touching `ui/` needs to know. (The stale WI-12 / WI-46-vs-47 lines in CLAUDE.md, the roadmap, the tech spec and bugs-doc D7 were already corrected on 2026-08-09, so this is additive.)

### 8 — The final consistency pass

With every panel in the new frame, look at all nine side by side and fix what only shows up in comparison: header subtitle phrasing, whether hotkey hints are present everywhere, footer action ordering, empty-state wording, whether any panel invented a control the widget library should own. This is the pass that makes the set feel designed rather than nine separately-converted screens, and it can only happen last.

## Files to touch

- **New:** `ui/windows/comms_panel.gd`, `scripts/utility/transmission_data.gd`, `scripts/managers/transmission_log.gd` (or fold into `AlertManager` — one owner for "things that arrived"), `tests/unit/test_transmission_log.gd`
- `ui/windows/economy_screen.gd` — becomes the `FINANCE` tab; frame and Esc handler deleted
- `ui/windows/unlocks/unlock_panel.gd` — tier section removed (moves to Comms)
- `scripts/managers/unlock_manager.gd` — the offer roll, `inspection_offer_chance_per_cycle`, `_inspection_offer_pending`, `_offer_inspection()` and `decline_inspection()` deleted; `begin_inspection()` becomes the player action; a `can_request_inspection()` returning the blocker for the button's label
- `data/events/**/arc_inspection_offer*` — retired from the pool
- `scripts/managers/{contract_manager,trader_manager,economy_manager,event_manager}.gd`, `inspection_runner.gd` — post transmissions alongside their alerts, via one helper
- `scripts/managers/save_manager.gd` — the `transmissions` section
- `ui/ui_main.gd` / `.tscn` — the retirement sweep
- `main.tscn` — the transmission log's manager node, if separate
- **Deleted:** everything in §7's list
- `Obsidian Vault/.../01_Technical_Specification.md`, `02_Roadmap.md`, `CLAUDE.md` — the documentation debt

## Implementation order

1. `TransmissionData` + the log + tests. Bounded, saved, and independently verifiable.
2. Comms panel frame with the ARC block and the feed, fed by the four posting systems.
3. `FINANCE` tab (a straight move).
4. Tier/quota section moved in from Research.
5. **The inspection change.** Last of the Comms work, because it is the one thing here that alters gameplay and it wants the surrounding UI to already exist.
6. The raid payoff row.
7. The retirement sweep.
8. The consistency pass, then the documentation.

## Edge cases

- **A save mid-inspection.** `_inspection_in_progress` is deliberately runtime-only and never saved, so a load resolves to "no inspection" — an inspector pawn is the one pawn excluded from saves. That stays true, and the button must read `READY` (not `INSPECTOR ABOARD`) after loading a save taken during a tour. Say so at the code, because it looks like a bug.
- **Cooldown persistence.** `_inspection_cooldown_cycles` gates the button now, so whether it survives a save matters in a way it didn't when it only gated a dice roll. If it isn't saved today, save it — otherwise a failed inspection is undone by a reload, which is exactly the kind of quiet exploit a save audit exists to catch.
- **`tier_up` cheat** calls `advance_tier()` directly and resets the cooldown. Unchanged, and it should keep working with no offer machinery behind it.
- **Max tier.** `is_max_tier()` disables the button with its own label rather than hiding it — a hidden button reads as a bug at the moment the player has actually won the ladder.
- **The first inspection flips the cost streams on.** WI-26 wires the first pass to switch `EconomyManager`'s wages/upkeep/levy from off to on. Now that the player chooses the moment, the tooltip must say so before they commit. Not a modal — a tooltip and a distinct button label for the first one.
- **Transmission dedupe.** A trader arriving five times is five transmissions with five timestamps, not one refreshed row — unlike alerts, where the same breach refreshes. Two different rules for two different lists, and the id shapes should make that obvious.
- **Unread count vs. history.** `MARK ALL READ` zeroes the badge without deleting anything, matching `CLEAR ALL`'s non-destructiveness in the alert feed.
- **A transmission whose action is stale** (a contract that expired, a module that was destroyed) — the row keeps its text and loses its action, exactly like an alert whose subject died.
- **Panel width vs. the feed.** 620px with a 34px avatar slot fits a sender and a subject line, not a body. Reading a transmission expands the row in place; do not open a sub-window, which is the thing this program exists to stop.
- **The event card is not a transmission** and must not be routed through the log, though an event may post one.
- **Don't let the retirement sweep delete something still referenced.** A `.tscn` holding a stale `ext_resource` to a deleted script fails to load at runtime, not at edit time, and the failure can be a silently missing panel. Grep every deleted path across `.tscn`, `.tres` and `.gd` before deleting, and run the full game after each removal.

## Verification

1. **GUT:** `test_transmission_log` — the ring buffer bounds and overwrites oldest-first; unread count matches unread entries; `MARK ALL READ` preserves entries; dedupe does **not** collapse repeated arrivals from one sender; a round-trip through save data preserves order, unread state and timestamps; an absent save key yields an empty log.
2. **Headless probe:** assert `can_request_inspection()` returns the right blocker in each of the six states (goals unmet, no bay, cooling down, in progress, max tier, ready), driven with cheats (`grant_export`, `tier_up`, removing the bay); request an inspection and assert the tour begins exactly as the old accept path did; fail one and assert the cooldown gates the button; save/load mid-tour and assert the button reads ready and nothing is left half-running.
3. **Windowed screenshot** of Comms against mockup screen 8 (amber ARC block, unread cyan treatment, avatar slots) and of the FINANCE and QUOTA tabs.
4. **The retirement audit, and it is the real deliverable of this item:** with the game running, dump `ui_main`'s child list and assert it matches §7's allowed set. Open every mode in turn and screenshot; assert exactly one panel visible at all times. Grep for every deleted filename across the repo and assert zero hits. Confirm `ui_main.gd`'s line count and content match §7.
5. **A full playthrough to tier 2.** Build, hire, mine, refine, trade, take a contract, get raided, request an inspection, get promoted — using **only** the console. Anything that cannot be reached from it is a miss, and this walk is how they get found.
6. **Regression:** the whole economy page still works (loans, ledger, per-payer detail, toggle states); tier goals still track exports; the levy still switches on at first promotion; `record_income` still returns the **net** after the skim and callers still credit that returned value (a real money-loop bug once, and this item touches the economy UI).

## Related

- [[04_UI_Rework_Program]] — decisions 1 and 6; the port inventory this item empties.
- [[New Work for Phase 4]] — the Contact-ARC requirement.
- [[WI-26_Station_Tiers]] — the inspection lifecycle being changed, and the tier section being moved.
- [[WI-25_Economic_Sinks]] — the economy page becoming a tab, and the `record_income` net rule.
- [[WI-53_Alerts]] — the alert/transmission split, and the shared "things that arrived" ownership.
- [[WI-55_Panels_Trade_And_RD]] — Research hands the tier section over.
- [[WI-32_Combat_v1]] — the raid payoff finding a home.
- [[01_Technical_Specification]] — gains a UI section here.
