# WI-57 — Comms Panel & Legacy Retirement

> **STATUS: DONE 2026-08-11.** Ninth and closing item of the [[04_UI_Rework_Program]], which is now **complete**.
>
> **1060 GUT tests green** (was 1033; +27 in `test_transmission_log`). **108-check headless probe green** against the real `main.tscn`, plus a separate **16-check two-phase save probe** that writes a slot, reloads it through the real `SaveManager` path, and then strips the new section out to prove a pre-WI-57 save still loads. Four windowed 1920×1080 screenshots. **Save-additive and backward-compatible**: one new absent-key-means-default `transmissions` section; `SAVE_VERSION` stays at 2.
>
> ### Deviations from the design above
>
> 1. **The transmission log folded into `AlertManager` rather than becoming its own manager node.** §"Files to touch" offered both; this one wins on the WI's own argument — "one owner for things that arrived" — and it is what makes `AlertManager.transmit()` possible as *one helper raising both halves*, which §3 asks for. It also costs no `main.tscn` edit and no new ready-order question. The two lists stay sharply distinct because they are different records with different rules, not because they live in different nodes.
> 2. **`InspectionBlock` has seven members, not six.** The WI's table folds "goals unmet" and "no facility" together, but they are different problems with different fixes (ship more ore vs. build a hydroponics bay), and the whole point of the button is that it names what is in the way. `FACILITY_MISSING` prints `NEEDS A <tag> FACILITY`.
> 3. **The `no docking bay` path no longer sets a cooldown.** That made sense when `begin_inspection` was an offer's Accept branch — the offer had been consumed — but the button now reads `NO DOCKING BAY TO RECEIVE THEM` when there is none, so the only way to reach the guard is a bay lost between the paint and the press. Charging two cycles for that would be a penalty for something the player did not do.
> 4. **The raid payoff is in the ARC block *and* stays in WI-53's right-column `RaidReadout`.** §6 says to move it and then flags its own risk ("if playtesting says a payoff buried one keypress deep is too slow during a fight, the fallback is a compact live strip"). The readout already *is* that strip, it is a legitimate right-column readout under invariant 3, and deleting it to re-add it after the first playtest is churn. Two entry points to one action is the program's own pattern (`One detail view, two ways in`).
> 5. **A card event posts a transmission too.** §"Edge cases" says the event card is not a transmission and must not be routed through the log — true, and it isn't: the card is still the modal, and the log gets the title and body only, with the choices left where they make sense. A player who answered a card two cycles ago should still be able to read what it said.
> 6. **The R&D panel gained a footer.** Not in scope, found by §8's side-by-side pass: it was the one panel of nine with no standing instruction, which read as an unfinished frame rather than as a panel with nothing to say.
> 7. **`ListRow.set_swatch` gained a `size` parameter**, mirroring `set_icon`'s from WI-54, so the 34px avatar slot is the widget's business rather than the row's.
> 8. **`TransmissionRow` hides its action when the route points at Comms.** Every ARC message carries `route = &"comms"` so that clicking it *in the alert feed* lands here — which is right there and absurd here. The route stays on the record; the row declines to draw the button.
>
> ### Traps worth remembering
>
> - **An autoload survives `reload_current_scene`, so a `CONNECT_ONE_SHOT` handler is spent after the first scene.** The save probe's phase 2 silently never ran and the whole run looked like it had passed. Connect normally and count phases.
> - **A row that repaints on a signal it can itself emit must not rebuild.** Expanding a transmission marks it read → `transmissions_changed` → the feed rebuilt → the row was freed while its own `toggled` signal was still propagating out of it. `_refresh_feed` now repaints when the entry set is unchanged and only rebuilds when it moved. WI-53 hit this shape as a nuisance (a freed row handed to a click in flight); here it was a hard error.
> - **The save envelope nests sections under `sections`.** A probe reaching for `data["transmissions"]` finds nothing and reports a missing save section that is present.
> - **A save slot is `.json`, not `.save`.** Two probe checks failed on a null `FileAccess` before that was obvious.
> - **A screenshot is part of the verification, still — and it caught three things a 108-check probe did not.** (a) An expanded ARC message offering `OPEN COMMS` while sitting inside the Comms panel. (b) `ARC Central` wearing *two different avatar colours* two rows apart, because `arc` and `finance` were separate families — one sender reading as two correspondents, which is exactly what the shared `ARC_SENDER` constant existed to prevent. (c) The QUOTA facility chips: a LIVE wash and an INERT one are six per cent apart on a 90px chip, so a missing required facility and a built one were **indistinguishable**. They now say `NEEDED` in amber or `×n` in cyan. That is the WI-56 lesson ("a colour that said the opposite of the text beside it") in its weaker form — a colour saying nothing at all.

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

*As run. 1060 GUT green, 108/108 probe checks green, 16/16 save-probe checks green, four windowed screenshots.*

1. **GUT, 27 new tests.** `test_transmission_log` — a post lands at the front, carries its sim stamp, starts unread, and `entries()` is a copy so a post cannot appear under a caller mid-render; **five arrivals from one sender are five rows**, each with its own id, and the id shape is `family#sequence`; the buffer is bounded and drops the oldest first; the unread count tracks `mark_read` and a second read of one entry reports no change (so no signal fires for a no-op); `MARK ALL READ` preserves every entry; a round trip preserves order, unread state, stamps, bodies and routes; an absent key yields an empty log; **a restored log cannot re-mint an id it already holds**, even from a save whose counter was stripped; a save written by a build with a larger cap does not grow this one; and on the record itself, a freed subject costs the row its action and nothing else, while a Variant holding an int never goes through a cast.
2. **Headless probe, 108 checks**, mounted as an autoload against the real `main.tscn`. *The log:* `transmit()` raises both halves with the transmission's subject equal to the alert's title; a repeat is a second transmission but still one alert row with a bumped count; the console badge counts unread and zeroes on `MARK ALL READ`; contract offers, loans and fired events each post; the finance transmission is from `ARC Central`. *The panel:* 620px at real height, the inspector left up behind it, the ARC block a permanent child at index 0 above the tab strip, one row per transmission newest-first, the subtitle reporting the unread count, a row expanding in place and marking itself read with the count and subtitle following, `MARK ALL READ` clearing the badge without dropping a row, all three tabs swapping with **the strip and the page agreeing** (WI-55's defect), the footer changing per tab, the width holding across tabs, Research no longer carrying a tier section and gaining its footer, and the raid row appearing, paying the ransom and going when the raid ends. *The inspection:* the offer roll, the decline path and the event are all gone and `EventManager` no longer knows the id; each of the seven blocker states asserted in turn and each printing its own sentence on the button; the request starting a real `InspectionRunner`; a fail starting the cooldown; the cooldown surviving a `get_save_data` round trip; a mid-tour save not persisting the tour and the button not being stuck on `INSPECTOR ABOARD` afterwards; max tier disabling the button rather than hiding it; the first promotion still flipping the cost streams on, clearing the cooldown, and posting an ARC transmission. *The retirement audit:* `ui_main`'s live child list matches §7's allowed set exactly, **exactly one panel is visible after opening every mode**, every mode has a real panel, every panel is a `ConsolePanel` at its geometry-table width printing its hotkey, Esc claims an open Comms, and Comms neither touches the player's `paused` flag nor leaves a hold.
3. **Save probe, 16 checks, two phases across a real scene swap.** Writes a slot holding three transmissions (one read, two unread, two of them identical arrivals) and an outstanding cooldown, stages it, reloads, and asserts the log came back in order with its bodies, routes and unread state, that the two identical arrivals are still two rows, that **the cooldown survived** (a reload cannot undo a failed inspection), and that no inspection is in progress. Then strips the `transmissions` section out of the file and reloads again: a pre-WI-57 save loads, yields an empty log rather than the pre-load one, and `SAVE_VERSION` never moved.
4. **Four windowed 1920×1080 screenshots**, driven into state (a mixed-sender log with both row treatments and one row expanded, a partial quota, a live raid, an outstanding loan): Comms `INCOMING`, `QUOTA` and `FINANCE`, plus Research to prove the tier block left. **Three defects were visible only here** — see the traps in the status block.
5. **Still owed by a human at the keyboard:** the full playthrough to tier 2 using only the console — build, hire, mine, refine, trade, take a contract, get raided, request an inspection, get promoted. The probe covers each state around that walk, not the multi-cycle behaviour, and the walk is how a surface that cannot be reached from the console gets found.
6. **Regression:** the economy page still does everything it did (loans, the ledger, the per-payer wage and upkeep detail, the toggle states) as the FINANCE tab; tier goals still track exports; the levy still switches on at first promotion; `record_income` still returns the **net** after the skim and every caller still credits that returned value.

## Related

- [[04_UI_Rework_Program]] — decisions 1 and 6; the port inventory this item empties.
- [[New Work for Phase 4]] — the Contact-ARC requirement.
- [[WI-26_Station_Tiers]] — the inspection lifecycle being changed, and the tier section being moved.
- [[WI-25_Economic_Sinks]] — the economy page becoming a tab, and the `record_income` net rule.
- [[WI-53_Alerts]] — the alert/transmission split, and the shared "things that arrived" ownership.
- [[WI-55_Panels_Trade_And_RD]] — Research hands the tier section over.
- [[WI-32_Combat_v1]] — the raid payoff finding a home.
- [[01_Technical_Specification]] — gains a UI section here.
