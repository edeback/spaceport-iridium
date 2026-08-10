# WI-53 — Alerts: Priority, Acknowledgement & History

> **STATUS: planned, not started.** Fifth item of the [[04_UI_Rework_Program]]. Depends on [[WI-49_UI_Design_System]] (`ReadoutPanel`, `ListRow`) and [[WI-51_Inspector]] (`select()` for jump-to).
>
> **This is the one item in the program with real gameplay consequence** — critical alerts pause the sim. Everything else in the rework changes how things look; this changes what the game does to you.

## Goal

Turn the alert stream from a pile of interchangeable red text into a three-tier system where **importance is enforced, not merely styled**:

- **Low** alerts are transient. Someone is hungry; it fades.
- **High** alerts **require a click to dismiss**, so they cannot be missed.
- **Critical** alerts additionally **pause the game until acknowledged**.

Plus: alerts that name a pawn or a module can be clicked to jump to it, and high/critical alerts keep a **history log** so the player can go back and read what happened.

## Design

### 1 — What exists, and why it can't carry this

`ui_main.gd`'s `_setup_alerts_strip()` builds a top-centre `VBoxContainer` and `_spawn_alert(key, text)` adds a red `Label` to it, deduped by key, freed by a 15-second wall-clock timer. Five signals feed it: `pawn_critical_need`, `station_alert`, `crew_resigning`, `crew_resignation_cancelled`, `crew_departed`. Every alert is the same colour, the same size, in the same place, for the same 15 seconds, and then gone forever.

`station_alert(message: String)` has **51 emit sites** across events, components, pawns and eleven managers. That signal is the interface, and a `String` carries no severity, no subject, and no identity — which is why the current UI can't do better than it does.

### 2 — The alert record

`scripts/utility/alert_data.gd` (`class_name AlertData`, `RefCounted`):

```
enum Priority { LOW, HIGH, CRITICAL }

var id: StringName          # dedupe key; repeats refresh rather than stack
var priority: Priority
var title: String           # "Hull breach"
var detail: String          # "SECTOR 3 · O₂ 1.4/s"
var subject: Variant        # PawnBase, ModuleBase, or null
var cycle: int
var hour: int
var acknowledged: bool
```

`title`/`detail` split matters: the design's alert row is a name over a meta line, and today every message is one sentence that has to be truncated or wrapped. `"Hull breach in Reactor Hall! Emergency bulkheads will seal in 1.5 hours."` becomes `Hull breach` / `REACTOR HALL · SEALS IN 1.5H`, which reads in a glance instead of a sentence.

`subject` is a **live object reference**, not an id. It must be `is_instance_valid`-checked at click time and at render time — a breached module can be destroyed while its alert sits unacknowledged in the feed, and the history log can outlive its subject entirely (which is fine: a history row whose subject is gone loses its jump affordance and keeps its text).

### 3 — The signal, and not breaking 51 call sites at once

`SignalBus` gains `station_alert_raised(alert: AlertData)`. The existing `station_alert(message: String)` **stays**, and `AlertManager` subscribes to it, wrapping each message as `Priority.LOW` with no subject.

This is deliberate, and it is the difference between an item that can ship and one that can't:

- All 51 sites keep working from day one at low priority.
- Sites that deserve a higher tier are **migrated deliberately**, in the pass described in §4, and each migration is a considered decision rather than a mechanical rename.
- A modded system (WI-47) emitting the old signal still gets an alert.

The old signal is not deprecated on a timetable. It is the correct interface for "something happened, mention it" and most of the 51 sites genuinely mean that. The cheat console's `"CHEAT: …"` alerts in particular should stay exactly as they are — low, transient, self-documenting.

### 4 — The classification pass

`AlertManager` (`scripts/managers/alert_manager.gd`, a node in `main.tscn` under `Managers/` registering as `Global.alert_manager`, like every other manager) owns the live queue, the history, and the pause latch.

The migration, and the reasoning. **CRITICAL is deliberately tiny** — a tier that pauses the game is only useful if it almost never fires, and the test for membership is *"the player will lose something irreversible if they are looking away."*

**CRITICAL — pauses until acknowledged:**

| Alert | Source | Why |
| --- | --- | --- |
| Hull breach opened | `atmosphere_component.gd` | A timer is running toward suffocation and bulkhead loss |
| Raid inbound | `raid_manager.gd` | Combat starts now; the payoff price is shrinking |
| Crew resigning | `crew_resigning` | An irreversible departure with a grace window |
| Robot destroyed | `robot_integrity_component.gd` | Already irreversible, and easily missed |
| Contract failing this cycle | `contract_manager.gd` deadline warning | A credit penalty lands at end of cycle |
| Bankruptcy warning | `economy_manager.gd` | The step before `game_over` |

**HIGH — sticky, click to dismiss:**

Low oxygen; module broken down; truss wreckage; pawn critical need; disease caught / worsened / needs-treatment-but-no-medbay; robot out of power or unreachable-repair; visitor can't leave; contract offered / fulfilled / failed; no docking bay for active contracts; trader arrived / departing in an hour; import bin full; ARC inspection offered / arriving / passed / failed; tier promotion; ARC loan approved / repaid; ARC settlement; the levy switching on; `can_remove_module` refusal; recruit-had-nowhere-to-dock refund; disease outbreak event.

**LOW — transient, 15s (unchanged behaviour):**

Breach sealed (both paths); disease recovered; skill level-up; crew resignation cancelled; crew departed; trader passed by; contract offers expired; raid ended (all three outcomes); every debug/cheat message; `save_manager`'s save summary.

Two judgement calls worth naming: **skill level-ups are low**, because they are frequent and good news, and a sticky alert for good news trains dismissal reflexes that then eat the breach alert. **Raid *ended* is low even though raid *started* is critical** — the fight being over is not something you need to acknowledge.

Difficulty (WI-37) does **not** gate any of this. Tempting, but an alert tier is a UI contract; a Peaceful game having fewer breaches is the difficulty lever, not a quieter UI when one happens.

### 5 — The pause latch

A critical alert sets `TimeManager.paused = true` and records whether the sim was *already* paused. Acknowledging the last outstanding critical alert restores the prior state — the same prior-pause-restore pattern WI-36's pause menu already uses, and the reason that pattern exists: a player who paused deliberately must not be un-paused by the UI.

Rules, each one a way this becomes hated if got wrong:

- **Never pause during load.** `SaveManager` applies a pending load deferred and restores a whole in-progress raid; a critical alert fired during restoration would pause a game the player hasn't seen yet. Gate on the loading flag, and the same gate covers a restored breach that is still open — a loaded save must not open on a modal.
- **One pause, not one per alert.** Three simultaneous criticals pause once and un-pause when the last is acknowledged.
- **Acknowledgement is a click on the alert, and only that.** Not Esc — the player hammers Esc, and an acknowledgement that Esc can satisfy is an acknowledgement that gets satisfied without being read. This is a deliberate exception to the "Esc is always an exit" invariant and should be documented at the code as such.
- **`UI stays real-time`** is already the standing rule (never `Engine.time_scale`, never `get_tree().paused`), so a paused sim keeps a responsive feed.
- **The tutorial/onboarding item will want to suppress this.** Leave a single `AlertManager.pause_on_critical` switch rather than making the caller decide.

### 6 — The feed

`ui/alerts/alert_feed.tscn` + `.gd` — a `ReadoutPanel` in the right column below the station map, 344px, header `ALERTS` with an **amber** accent bar, and `HISTORY` + `CLEAR ALL` in the action slot.

Rows are `ListRow` in the three treatments the design specifies: amber-tinted with a left amber border for critical/high-attention, cyan-tinted for actionable-but-not-alarming (an awaiting-reply hail), and inert `#16222f` with a dim left border for low. Each row: 24px glyph, title, meta line, and a right-aligned action verb — `JUMP ▸` when the alert has a live subject, `OPEN ▸` when it routes to a mode (a contract offer opens Trade), nothing when it is only information.

**`CLEAR ALL` is non-destructive** because history exists: *"Clearing is therefore non-destructive, so players will actually use it instead of letting 40 rows pile up."* It dismisses everything acknowledgeable and leaves outstanding criticals alone — a "clear" that can dismiss a game-pausing alert defeats the tier.

Ordering: outstanding criticals first, then high by recency, then low by recency. Low alerts age out on a **wall-clock** timer (the current 15s), because they are a UI affordance and not a sim event; high and critical never age out.

Cap the visible feed (~8 rows) and summarise the rest as `+ n more` linking to history. A backed-up feed of 40 rows is the failure mode the design's history/clear pairing exists to prevent.

### 7 — Jump-to

`ListRow.pressed` on an alert with a live subject → `InspectorPanel.select(subject)` + `GameCamera.jump_to(subject.global_position)`. Both already exist (WI-51 exposes the first, the minimap already drives the second, WI-34).

Getting subjects populated is most of the work, and it is why §3's shim matters: a call site only gains a subject when someone migrates it, and the migration is where `_module_name()` string interpolation gets replaced by passing the module. Roughly 30 of the 51 sites name a pawn or module in their text and can pass it.

### 8 — History

`ui/alerts/alert_history.tscn` — a flyout from the feed's `HISTORY` action, listing high and critical alerts newest-first with cycle/hour stamps, filterable by priority. Low alerts are **not** logged: they are the ones that were designed to be missable, and logging them would bury the ones that weren't.

Bounded ring buffer (a few hundred entries), and **saved**, as a new `SaveManager` section:

```
"alerts": { "history": [ {id, priority, title, detail, cycle, hour}, ... ],
            "outstanding": [ ... ] }
```

Absent key = empty, so pre-WI-53 saves load fine and `SAVE_VERSION` stays put. `subject` is **not** saved — object references can't be, and a history row's jump affordance is a live-session nicety. Whether *outstanding* alerts should persist is a real question: a save taken with a hull breach open should probably reload still telling you about the breach. Save them, but **do not re-trigger the pause on load** (§5), and re-derive the subject where the emitting system will re-emit anyway (a breach is still breached; `AtmosphereComponent` will say so on its next tick). The safe implementation is: save history, save outstanding as *history entries*, and let live systems re-raise what is still true.

## Files to touch

- **New:** `scripts/utility/alert_data.gd`, `scripts/utility/alert_rules.gd` (pure classification + dedupe + ordering), `scripts/managers/alert_manager.gd`, `ui/alerts/alert_feed.tscn` + `.gd`, `ui/alerts/alert_row.tscn` + `.gd`, `ui/alerts/alert_history.tscn` + `.gd`, `tests/unit/test_alert_rules.gd`
- `scripts/managers/signal_bus.gd` — `station_alert_raised(alert: AlertData)`
- `main.tscn` — `AlertManager` under `Managers/`. **Tree order is ready order and is load-bearing**: after `TimeManager` (it needs the pause API and the clock) and before `SaveManager` (which is last and applies a pending load deferred)
- `ui/ui_main.gd` — `_setup_alerts_strip`, `_spawn_alert`, `_active_alerts`, `_alerts_box` and the five signal handlers **deleted**; feed mounted in the right column
- `ui/ui_main.gd` — `_setup_raid_ui`'s banner replaced: raid start is a critical alert, the shrinking payoff belongs in Comms/ARC (WI-57). Keep a minimal live raid readout if playtesting says the banner is load-bearing, but not as a bespoke top-centre panel
- `scripts/managers/save_manager.gd` — the `alerts` section
- The ~30 emit sites gaining a priority and a subject (see §4). Each is a one-line change from `station_alert.emit(text)` to a helper like `AlertManager.raise(id, priority, title, detail, subject)`
- `scripts/utility/cheats.gd` — a `fire_alert(priority)` cheat, since critical alerts are otherwise hard to provoke on demand

## Implementation order

1. `AlertData` + `AlertRules` + tests. Classification, dedupe and ordering are pure rules and belong pinned before anything renders.
2. `AlertManager` with **only** the legacy shim: every existing alert arrives as LOW. Behaviour is unchanged and the old strip can come out. Playable.
3. The feed panel in the right column, three row treatments, `CLEAR ALL` + sticky dismissal for HIGH. **Still no pausing** — HIGH is the tier that earns most of the value and carries none of the risk.
4. Jump-to, and the subject-passing migration for the ~30 sites.
5. History + its save section.
6. **CRITICAL and the pause latch last**, once the rest is trustworthy. This is the intrusive part and it should land on a system that has already been played with.

## Edge cases

- **A critical alert while the game is already paused** → acknowledge restores paused, not running.
- **A critical alert during a load, or during scene setup.** Gate on loading; a save must not open on a pause modal.
- **A critical alert while the trader screen has the sim paused** (Trade's docked pause, WI-55) → two independent pause holders. Reference-count the pause or route both through one owner; two systems each restoring "the prior state" will un-pause a game the other still wants paused. This is the most likely real bug in the item.
- **The subject dies before acknowledgement.** Row keeps its text, loses `JUMP ▸`. Never `queue_free` an alert because its subject went away — that is how a critical alert disappears without being read.
- **Dedupe vs. repeat.** `id` collapses repeats: a second breach in the same module refreshes the existing alert rather than stacking. But **two different modules breaching are two alerts**, so the id must include the subject. The current `_spawn_alert` key convention (`"%s|%s" % [pawn, need]`) already does this and should be kept as the id shape.
- **A flood.** A raid damaging eight modules at once, or an outbreak infecting six pawns. Coalesce by id family: `6 crew have fallen ill` as one HIGH alert with a list, not six rows. Without this, the first serious event fills the feed and the cap swallows the important row.
- **`game_over` is not an alert.** It has its own screen and must not be routed here.
- **Cheat alerts stay LOW.** A save that used cheats is self-documenting via the `"CHEAT: …"` prefix (standing rule); do not promote them, and do not log them to history.
- **Event cards already interrupt.** `event_card.tscn` is a modal for events with choices. An event that fires a card should not *also* raise a critical alert about the same thing.
- **Wall-clock vs sim-time.** Low alerts age on wall-clock (UI affordance); alert timestamps are sim cycle/hour (game facts). Both are correct; don't unify them.

## Verification

1. **GUT:** `test_alert_rules` — classification for a representative message from each of the three tiers; dedupe collapses same-id and keeps different-subject-same-kind separate; ordering puts outstanding criticals above everything regardless of recency; `CLEAR ALL` clears low+high and leaves criticals; the coalescer groups an id family above its threshold and leaves a pair ungrouped below it; low alerts age out and high/critical don't.
2. **Headless probe:** raise a critical → assert `TimeManager.paused` went true and the prior-pause state was recorded; acknowledge → assert it restored; raise two criticals → assert one pause, un-paused only after the second acknowledgement; raise a critical with the sim already paused → assert it stays paused after acknowledgement; raise a critical *during* a load → assert no pause. Then save with history and an outstanding alert, load, and assert history round-trips, no pause fires, and the feed is consistent.
3. **Windowed screenshot** of the feed with all three row treatments live, against mockup screen 1's alerts panel; plus the history flyout.
4. **Manual, and this is the one that matters:** provoke a real hull breach (`Cheats.damage`/`break_module` into a breach) while looking at the Build panel. The game must stop, the alert must be unmissable, clicking it must jump to the module, and the sim must resume on acknowledgement. Then do the same for a raid.
5. **The annoyance check.** Play twenty minutes at 4× and count criticals. If more than one or two fire, the classification is wrong — move something to HIGH. This is a tuning check with a real pass/fail and it should be done before the item is called done.
6. **Regression:** all 51 legacy emit sites still produce an alert after the shim lands; the five deleted `ui_main` handlers have equivalents; the raid readout still communicates the shrinking payoff somewhere.

## Related

- [[04_UI_Rework_Program]] — invariant 5 (amber is budgeted; alerts are its main consumer).
- [[New Work for Phase 4]] — the source brief for the three tiers, jump-to, and the history log.
- [[WI-51_Inspector]] — `select()`, consumed by jump-to.
- [[WI-50_Console_And_Modes]] — the trader auto-open this replaces with an alert plus a readiness dot.
- [[WI-57_Panel_Comms_And_Retirement]] — where the raid payoff and ARC messaging land.
- [[WI-36_Main_UI_Flow]] — the prior-pause-restore pattern, and the Esc invariant this item deliberately excepts.
- [[WI-37_Difficulty_Levels]] — considered and rejected as a gate on alert tiers.
- [[WI-31_Health_and_Disease]], [[WI-32_Combat_v1]], [[WI-24_Combat_Setup]], [[WI-17_Life_Support_Oxygen]] — the systems supplying most of the high and critical alerts.
