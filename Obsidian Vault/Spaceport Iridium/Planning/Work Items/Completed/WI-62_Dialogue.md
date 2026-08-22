# WI-62 — Dialogue

> **STATUS: COMPLETE (2026-08-22).** Shipped as designed apart from the nine deviations below. **Ninety-nine files: 54 new, 32 changed, 13 deleted** (excluding `.uid`/`.import` sidecars). The deletions are the whole of `EventChoice`, `EventEffect`, its nine subclasses and the event card. **1316 GUT tests, all green** (from 1217 — six new suites, +99 tests), an **89-check headless probe** green on repeated runs, and **seven screenshots** each driven into the state under test. Save is backward-compatible and `SAVE_VERSION` did not move: a pre-WI-62 save has no `story` section, and every field in it defaults to "nothing has happened yet".
>
> **Deviations from the design below:**
> 1. **Standing is a Comms *tab*, not a block beside the ARC block.** §5 said "a block on the Comms panel, beside the ARC block that is already there". The ARC block sits above the tab strip and is permanent, and a second permanent block would push the transmission feed down on every station — including the many that have never met anybody. It is the fourth tab, `INCOMING / STANDING / QUOTA / FINANCE`.
> 2. **`grant_cargo` deposits into the docking bay, not through `StorageQuery.find_sink()`.** §3's table said `find_sink`, which takes a **pawn** — and a ship offloading at the dock has none. The bay is where the cargo physically lands, and whatever will not fit becomes a pile at the dock. The no-silent-loss half of that line is unchanged and is the part that mattered.
> 3. **`EventData` gained a tenth field, `mood_ids`, that the design did not anticipate.** [MoodCatalog] recovers "which event does this mood modifier belong to" by scanning authored `EventEffectHappinessModifier` resources — and those are exactly what this item deleted. Without a replacement the Needs tab prints a modifier the player cannot account for, which is the defect WI-51 added the breakdown to fix. Events now **declare** the ids their dialogue applies. §2's table is otherwise accurate.
> 4. **`ResponseRules` was extracted mid-implementation and is not in the design.** The blocker-label rule and the all-blocked check were written inline in the balloon, which needs a live scene, a compiled `DialogueResource` and the addon's own menu widget before it renders anything — three reasons a defect there is screenshot-only. They are a pure class with their own suite now, which is the standing "pure logic must be extracted to be testable" invariant applied after the fact.
> 5. **`UIPalette` gained `PANEL_SHADOW` and `READOUT_SHADOW`.** `ConsolePanel` and `ReadoutPanel` were naming raw `Color(0, 0, 0, …)` in code — the last two colours in `ui/` not coming from the palette. The scene sweep never saw them because they live in code, which is the half-a-drift-guard problem WI-58 fixed in the other direction. Three lines, and the balloon needed the token anyway.
> 6. **The reachability sweep had to widen to `.gd` files.** `test_event_content.gd` first checked that a scheduled-only event (`weight = 0`) is queued by some `.dialogue` file, and promptly declared the **shipped** `insolvency_warning` unreachable — it is fired by `EconomyManager` in code. Two kinds of caller count.
> 7. **`DialogueResponsesMenu.auto_configure_focus` is off and the balloon wires focus itself.** The addon indexes `get_menu_items()[0]` unguarded, and that list excludes every disallowed row — so an all-blocked line made it throw `Out of bounds get index '0'` one frame *before* the escape hatch existed. Only the probe found this.
> 8. **The escape hatch carries a real `DialogueResponse` pointing at END**, not a sentinel. `set_meta(name, null)` looked like the obvious sentinel and is a trap: in Godot 4 a null value **deletes** the entry, so `get_meta("response")` then errors on the very item meant to carry it. A real response also means every path downstream works unmodified.
> 9. **The addon registered the new `.dialogue` files into `locale/translations_pot_files` by itself.** §8 flagged this as a manual step to remember; it turns out not to be one.
> 10. **The civilian portrait pool excludes one prefix, not seven.** `portrait` is a prefix of `portrait_pirate`, so the pool needs an exclusion — and the first draft listed the seven faction prefixes by name. `portrait_SAI.png` landed in the directory the same day and immediately leaked a robot into the civilian pool. One exclusion, `portrait_`, covers every faction prefix there is and every one there will ever be. A deny-list of names is a maintenance burden disguised as precision, and this one lasted a few hours.
>
> **What the screenshots caught that the probe could not:** the Standing tab printed each faction's name **twice** — once as the row's entity name and again as the `StatBar`'s label — and the honest "this is a record, not a lever" caveat sat as a row at the bottom of the panel body, which is the thing `ConsolePanel.footer_text` exists to prevent. Both fixed; the bar's label is the scale (`HOSTILE TO ALLIED`) now, which is information the row did not previously carry.
>
> **What the probe caught that a screenshot could not:** deviations 7 and 8, and the load-order fix below.
>
> **A pre-existing bug fixed on the way past.** [[03_Bugs_and_Improvements]] records that `EventManager._on_cycle_changed` can fire a random event on load, *before* `load_save_data` restores its own cooldown table. That was a stray card before; with chaining it can drop a chapter-two event into a save that never saw chapter one. The natural roll and the scheduled drain now both gate on `SaveManager.is_loading()`.
>
> **Balance left deliberately untouched.** Every converted event keeps its original weight, `min_cycle`, cooldown and numbers. The only new content with numbers of its own is the chain (§7), and those are first guesses.
>
> The roadmap and [[01_Technical_Specification]] are **not** updated yet — the spec wants a new §1.x for the dialogue runtime and a correction to §1.13 (events), which no longer describes what an event is.

## Goal

Today an event is a grey box with a title, a paragraph and two buttons. Nobody is talking to you. The brief's goal is that the player interacts with **characters** — a pirate captain who wants your credits has a face and a name, a trader who owes you a favour remembers that they owe you — and that the machinery which makes that possible is general enough that the tutorial can hand it a station AI called **SAI** and get an onboarding flow for free.

Five deliverables:

1. **One conversational modal.** The dialogue balloon replaces the event card outright. There is exactly one surface in the game that shows somebody saying something.
2. **Events are written in `.dialogue` files.** `EventData` keeps the things that decide *whether* an event happens; the script decides what is said and what it does.
3. **A speaker has a face and a name**, resolved once per conversation and stable across every line of it — including when the face is drawn at random from a pool.
4. **Conversations remember.** A saved flag store plus a scheduled-event queue, so a choice made in one event can gate the choices and outcomes of a later one.
5. **The worked chain from the brief** — *Damaged Ship Needs Help* — authored end to end as the acceptance test for all four of the above.

The single most load-bearing decision in this item is §2: **what an event is after this**. Everything else follows from it.

## Design

### 1 — The balloon is the only conversational modal, and the event card is deleted

`ui/windows/event_card.gd` + `.tscn` go. Not reskinned, not kept as a fallback for events that have no dialogue — deleted, with every event converted in this item. There are eleven of them; that is a morning's work, and the alternative is the thing this codebase has repeatedly regretted (WI-44's note that the two job systems "coexist" was true for one commit and misleading for a month).

The balloon (`ui/dialogue/balloon.tscn`) already wears the console frame — PANEL at panel alpha, EDGE border, inner highlight, drop shadow — and already takes every colour and size from `UIPalette`/`UIMetrics`/`UIType`. It is a **modal overlay**, the third kind of surface alongside the pause menu and the game-over screen: not a `ConsolePanel`, not a `ReadoutPanel`, not a `ModeManager` mode. That classification is already written on the file and does not change.

What changes about it:

**It takes a named pause hold, and it takes it late.** `DialogueBalloon.PAUSE_HOLD = &"dialogue"`, taken in `apply_dialogue_line()` when the first real line renders and released when the conversation ends. Never `TimeManager.paused`. Taking it on the *first line* rather than in `_ready()` is not a detail — it is what makes §2's silent events work, because a conversation that never shows a line never stops the sim. One rule, both cases.

Two consequential follow-ons, each with a test that fails if it is forgotten:

- `UITimeScaleSelect.HOLD_REASONS` and `HOLD_LABELS` each gain a `&"dialogue"` row and lose the `&"event_card"` row. `test_pause_holds.gd::_declared_holders()` names `EventCard.PAUSE_HOLD` today and must name `DialogueBalloon.PAUSE_HOLD` instead. Suggested text: reason *"Someone is waiting for an answer"*, label *"In conversation"* (15 chars, comfortably under `HOLD_LABEL_MAX`).
- `test_ui_theme.gd::OVERRIDE_EXEMPT` lists `res://ui/windows/event_card.tscn`. Deleting the scene without deleting the exemption leaves a dead entry that quietly exempts nothing. **`balloon.tscn` is not exempt and must not become exempt** — it is inside the design system and passes the sweep today (the raw `Color(...)` WI-60's status block flagged was fixed in `59b8d869`).

**It does not swallow `ui_cancel`.** `will_block_other_input` currently marks *every* unhandled event handled, which would take Esc away from the pause menu — something the event card never did, so a player who can open the pause menu over an open event today must still be able to over an open conversation. The block gets one exception for `ui_cancel`.

**It is not on the Esc ladder.** Same reasoning, and the same considered exception, as an outstanding critical alert (`ui_main.gd::_topmost_esc_claim`): a conversation is a thing you answer, and an Esc that dismisses it is an answer given without being read. The conversation ends when it ends.

**It is mounted by us, not by `DialogueManager`.** `show_dialogue_balloon()` adds the balloon to `get_current_scene()`, which puts its draw order *and* its `_unhandled_input` order at the mercy of tree position. The runner (§6) instantiates the balloon and adds it under `UIMain`, above the modes and below the pause menu — the slot the event card occupied. `runtime/balloon_path` in `project.godot` stays as it is; after this it is only what the editor's *Test Scene* button uses.

**A blocked response names its blocker on itself.** `DialogueResponsesMenu` renders an `is_allowed == false` response as a disabled item (and appends `Disallowed` to its node name) — but only while `hide_failed_responses` stays **false**, which is its default and which we keep deliberately. The response's own `condition_as_text` is the blocker sentence, and the balloon appends it to the label in `TEXT_DISABLED`. This is the console UI's standing invariant applied to a new surface, not a new rule; `ActionButton` already has the states for it.

**All-blocked is a soft-lock and must be caught.** The event card's guard was `EventData.has_free_choice()`, validated at load. Its analogue cannot be static — a response's condition is only known when the line is reached — so the guard moves to the balloon: if `dialogue_line.responses` is non-empty and every one of them is disallowed, `push_error` naming the cue and render a single `[ No option available — end transmission ]` item that ends the conversation. A player never sees a dead modal, and the error names the file.

### 2 — What an event is after this item

**`EventData` keeps eligibility and pacing. A `.dialogue` file owns the script and the consequences.**

| Field | After this item |
|---|---|
| `id`, `weight`, `min_cycle`, `cooldown_cycles` | unchanged — the picker's inputs |
| `conditions: Array[EventCondition]` | **unchanged, and deliberately not moved into dialogue** (below) |
| `title` | unchanged — the alert headline and the transmission subject |
| `body` | kept, **redocumented**: this is the Comms row, not card text. Nothing renders it as prose to answer any more |
| `icon` | **deleted** — never authored in any of the eleven `.tres`, never read by anything |
| `choices: Array[EventChoice]` | **deleted** |
| `auto_effects: Array[EventEffect]` | **deleted** |
| `dialogue: DialogueResource` | **new** — the script |
| `cue: String` | **new** — where in it to start (v4 renamed "titles" to "cues") |

`EventChoice`, `EventEffect` and the nine `data/events/effects/*.gd` subclasses are **deleted**. Their behaviour does not vanish — it moves into the bridge's verb list (§3), which is where their balance numbers keep living in data. A `.dialogue` file is data, so the "balance numbers belong in `.tres` or exported vars, not code constants" invariant is satisfied by the same argument that lets a recipe live in a `.tres`.

**Why `EventCondition` survives and `EventEffect` does not.** They look symmetric and are not. A condition answers *"may this event fire at all"*, and `try_fire_random_event()` needs that answer for every candidate **before** any conversation exists, in order to weight the roll. Expressing it as an `if` inside the dialogue would mean opening a conversation to discover it should not have happened — burning the roll and showing nothing. An effect has no such caller: nothing ever asks what an event *would* do. It has exactly one consumer and belongs where it is written.

**A notification event is a cue with no dialogue lines.** This is the mechanism that lets the two shapes of event share one path with no branch anywhere:

```
~ market_glut_iron_ore
$> station.market_shock("iron_ore", 0.6, 24)
=> END
```

`get_next_dialogue_line()` runs the mutations and returns `null`, so the balloon never shows a line, never takes the pause hold (§1), and frees itself. The player sees the alert and the Comms row exactly as they do today. `EventData` needs no `is_silent` flag and `EventManager` needs no `if`. "Does this event interrupt the player" becomes a property of what the author wrote, which is the correct place for it.

**What is deliberately *not* used: `DialogueManager.create_resource_from_text()`.** Compiling a synthesized script at runtime from the old `title`/`body`/`choices` fields would let the eleven existing events survive untouched. It also puts author-controlled strings through a compiler, where a label containing `=>` or `[` becomes a parse error in a file nobody can open. Convert the eleven by hand.

**`EventManager` changes, minimally:**

- `_load_events()` keeps `ContentPaths.scan(ContentPaths.EVENTS)` and `accept_id()`. Its `has_free_choice()` warning is replaced by a **cue-existence check**: `event.dialogue.get_cues().has(event.cue)`. A typo'd cue is otherwise an event that fires and does nothing, forever, silently — the worst failure mode this item introduces.
- `fire_event()` stops branching on `choices.is_empty()`. It logs (unchanged: `station_alert` + `post_transmission` under `EVENT_SENDER`), then hands the event to the runner. `pending_events` stays and stays saved — two events firing in one tick still queue and show in order.
- `resolve_choice()` is deleted. A conversation ending is what dequeues the event.

**A pre-existing bug this makes worse, and which should be fixed here.** [[03_Bugs_and_Improvements]] records that `EventManager._on_cycle_changed` can fire a random event on load, *before* `load_save_data` restores the manager's own cooldowns (events are section 130 of 17). Today that is a stray card. With chaining it can drop a chapter-two event into a save that never saw chapter one. Gate the natural roll on the same "not while loading" condition `AlertManager._pause_allowed()` already consults.

### 3 — The bridge: two aliases, one vocabulary each

Dialogue reaches the game through `DialogueManager.register_state_context(alias, node)`. Registered contexts land in `_registered_contexts`, which is a `Dictionary` inside `_get_game_states()`, so `station.credits(-300)` resolves `station` to the node and calls the method on it. Two aliases, because they are two different jobs.

**`station` — `DialogueBridge` (`scripts/dialogue/dialogue_bridge.gd`).** The sanctioned verb list: everything a conversation may *do* to the simulation. This is the one seam between authored text and the sim, which makes it the one place the sim's own invariants get enforced — notably that `EconomyManager.record_income` returns the **net** after the ARC levy and the caller must credit *that* value, a bug the game has already shipped once.

Starting vocabulary — the nine deleted effects, plus what the brief's chain needs:

| Verb | Replaces / for |
|---|---|
| `credits(n)` | `EventEffectCreditDelta`, including its `record_event_delta` ledger entry |
| `loan(principal)` | `EventEffectTakeLoan` |
| `mood(id, value, hours)` | `EventEffectHappinessModifier` → `EventManager.apply_station_happiness` |
| `market_shock(resource_id, mult, hours)` | `EventEffectMarketSupplyShock` |
| `salvage(resource_id, min, max, piles)` | `EventEffectSpawnSalvage` — the station-bounds math comes with it |
| `raid(strength)` | `EventEffectPirateRaid` (`-1` auto-scales from station value) |
| `breach(count)` | `EventEffectHullBreach` |
| `outbreak(disease_id)` | `EventEffectDiseaseOutbreak` |
| `offer_contract()` | `EventEffectOfferContract` |
| `grant_cargo(resource_id, min, max)` | new — the trader's thanks. Deposits through `StorageQuery.find_sink()` and **piles the remainder rather than voiding it** |
| `damage_station(severity)` | new — the exploding freighter |
| `transmit(sender, subject, body)` | new — an outcome worth re-reading later |
| `alert(title, detail)` | new — an outcome worth looking at now |
| `dock_is_free()` | new, and a *query* — reads `TraderManager.find_trade_bay()`, `visit_active`, `is_inbound()` |

Ids pass as plain strings and are coerced on the call, for the same reason the Panku cheats take plain strings: Godot's `Expression` rejects `&"…"` literals but coerces `String` → `StringName`. An unknown id is a `push_error` naming the verb and the id, never a silent no-op.

**`story` — `StoryState` (`scripts/dialogue/story_state.gd`).** Everything a conversation may *remember*: `flag(id)`, `set_flag(id, value)`, `bump(id, n)`, `standing(faction_id)`, `shift_standing(faction_id, delta)`, `queue_event(event_id, delay_hours)`.

**Flags are declared, not free-form.** Same argument as `Groups` (WI-41) and `UIType` (WI-49): a flag is a bare string on both sides of a contract, and the typo is silent in the direction that matters — `flag("kestrel_dockd")` reads false forever. Declared ids live in a const table on `StoryFlags` with a one-line comment each; an undeclared id pushes an error. There is a related trap worth knowing even though we are not using it: passing a raw `Dictionary` as a game state *does* let authors write bare identifiers, but `_set_state_value` only writes keys the dictionary **already has**, so an undeclared flag silently fails to persist rather than erroring. A method surface avoids that entirely.

**Every autoload is already in scope, and `include_singletons` does not gate it.** `_load_autoloads()` walks the scene-tree root and adds every autoload to `game_states` unconditionally, so a `.dialogue` file can write `Global.anything` or `SignalBus.anything` whether or not we want it to. The only lever is `DialogueManager.validate_member_access`, a `Callable` consulted for property reads, property writes, method calls and string-index access. Set it: allow the two aliases and the addon's own built-ins, deny the rest with a message naming the file. It is cheap, it is the difference between "the bridge is the vocabulary" being a rule and being a suggestion, and it is what makes a mod's `.dialogue` file safe to run (WI-47).

### 4 — Speakers: `SpeakerData`, portrait pools, and a cast

The brief: *"An image can be required but random — if so, the image should be stable over several lines of conversation."* The balloon's current placeholder does the exact opposite — `randi_range(12, 49)` runs inside `apply_dialogue_line()`, so the pirate's face changes every time he opens his mouth.

**`SpeakerData`** (`data/speakers/*.tres`, new `ContentPaths.SPEAKERS` kind):

- `id: StringName` — what the dialogue names
- `display_name: String` — a fixed name, **or** empty to draw one from `NameGenerator.random_name()`
- `portrait: Texture2D` — a fixed face (SAI, a recurring character), **or**
- `portrait_pool: PortraitPool` — a face drawn from a pool
- `faction: StringName` — optional; ties a speaker to a standing (§5)

**`PortraitPool`** (`data/portraits/*.tres`): an `id`, a `directory`, and a `prefix`. The pool's contents are *scanned*, not enumerated. `ResourceScanner` already resolves `.remap`/`.import` suffixes so an exported build behaves like the editor; it needs one small extension — `scan_paths(path, extension := "tres")` — to list `.png` as well. Results are sorted for determinism and cached per pool.

Scanning rather than authoring an `Array[Texture2D]` is worth that extension for two reasons. First, WI-47: a mod drops portraits in its own directory and gets a pool with zero core edits. Second, and more immediately — **the vanilla art has a hole in it.** `assets/external/thirstsector_portraits/` runs `portrait12`…`portrait18`, then `portrait20`…`portrait49`. There is no `portrait19`. Any code that builds a path from a numeric range will, one time in thirty-seven, ask for a file that does not exist. A directory listing cannot have that bug. The eight pools the art supports:

| Pool | Prefix | Count |
|---|---|---|
| `civilian` | `portrait` (bare) | 37 |
| `pirate` | `portrait_pirate` | 22 |
| `authority` | `portrait_hegemony` | 17 |
| `fringe` | `portrait_luddic` | 17 |
| `enforcer` | `portrait_diktat` | 16 |
| `trader` | `portrait_league` | 15 |
| `corporate` | `portrait_corporate` | 11 |
| `mercenary` | `portrait_mercenary` | 8 |

The art is 128×128, which is exactly `UIMetrics.DIALOGUE_PORTRAIT`. No metric changes.

**The cast is resolved once per conversation.** `SpeakerCast` (a pure `RefCounted`, `scripts/dialogue/speaker_cast.gd`) is built when a conversation opens and thrown away when it closes. `resolve(speaker_id) -> ResolvedSpeaker` picks a name and a face on first sight of that id and returns the same one every time after; two speakers in one conversation drawn from the same pool never get the same face. That one sentence — *a speaker is resolved once per conversation, not once per line* — is the whole of the brief's stability requirement, and the placeholder in `balloon.gd` is deleted with it.

**Naming a speaker in dialogue.** The character at the head of a line is the speaker id, resolved through the cast:

```
distress_captain: Station, this is the Kestrel. We are holed and running hot.
```

renders as *Ari Vance* over a `trader`-pool face. A character string that is not a known `SpeakerData` id falls back to showing that string verbatim with no portrait — which is what lets narration (`Station sensors flag a debris cluster.`) and quick authoring both work without ceremony.

**The event's own picture.** A conversation with no speaker at all can still want an image — a debris field, a hull breach. `SpeakerData` already covers it: a speaker with an empty `display_name` and a fixed `portrait` *is* an image with no name, and the balloon already hides `CharacterLabel` when the character is empty. No second concept.

**Save behaviour, stated rather than promised:** the cast is runtime-only. A save taken with a conversation pending re-rolls faces on load, because `pending_events` restores the *event*, not the conversation. That is acceptable for a one-shot. A **chain** that must remember a face across sessions stores the resolved portrait path in a story flag — which is a thing §5 already does for everything else it remembers.

### 5 — Chaining: flags, standing, and scheduled events

Three mechanisms, one save section (`&"story"`, registered after `&"events"`).

**Flags** (`StoryFlags`, pure). A declared-id → `Variant` store. `flag("kestrel_docked")`, `set_flag(...)`, `bump(...)` for counters. Read from dialogue conditions and from response conditions — note v4's self-closing form:

```
- Ask about the bounty [if story.flag("kestrel_bounty_known") /]
```

**Faction standing** (`FactionStanding`, pure). The brief's chain trades in *"reputation with the local faction"*, and the game has no such number. `ContractManager.reputation` is a contract-completion counter; `VisitorManager.reputation` is a 0–1 visitor-satisfaction float. Both are about something else, and overloading either would make one number answer two questions.

So: `FactionData` (`data/factions/*.tres`, new `ContentPaths.FACTIONS` kind) with an id, a display name, a description and a default `PortraitPool`. Three **scored** factions in v1 — **`authority`** (the system patrol the brief calls the local authorities), **`pirates`**, **`traders`** — plus ARC listed but **not scored**, because ARC standing already exists as the tier ladder and the inspection gate, and two competing numbers for one relationship is exactly the "one place per vocabulary" failure this codebase keeps deleting.

Standing is a float in `[-1, +1]` with five named bands (`HOSTILE / COLD / NEUTRAL / WARM / ALLIED`), so it becomes a sentence rather than a decimal on screen. It renders as a block on the **Comms panel**, beside the ARC block already there.

**Be honest about what it does:** in v1, standing gates dialogue and renders in Comms, and nothing else. A number with no consequence is a promise the game has not kept, so it is written down here rather than discovered later. The three places it should hook in, in the order they are worth doing: `VisitorManager`'s arrival pacing (traders), `RaidManager`'s frequency and strength (pirates), and `MarketManager`'s prices (traders). None of them are in this item.

**Scheduled events** (`EventSchedule`, pure). `story.queue_event("kestrel_pursuit", 4)` puts an event id and a due time (cycle + hour) on a saved queue; `EventManager` drains what is due on `hour_changed`, **bypassing the weighted roll, the cooldown and the `min_cycle` gate** — a scheduled event was already decided by a choice the player made, so re-litigating its eligibility would drop chapter two on the floor. Its `conditions` are still checked; if they fail, the event is dropped and a transmission says the moment passed. A queued id that no longer resolves (a mod was removed) is dropped with a `push_warning`, never a crash.

### 6 — The runner

`DialogueRunner` (`scripts/managers/dialogue_runner.gd`, `Global.dialogue_runner`), a node in `main.tscn` under `Managers/`. Tree order is ready order and is load-bearing as always: **after `AlertManager`** (it posts transmissions) and **after `EventManager`**, before `SaveManager`. It owns:

- `run(resource, cue, extra_states) -> void` — the one public entry point. `EventManager` calls it; so, later, will the tutorial.
- A queue, so two conversations never overlap. Same shape as `pending_events`, same reason.
- The balloon's lifecycle: instantiate, mount under `UIMain`, `start()`, free on `dialogue_ended`.
- The cast for the current conversation.
- Registration of the `station` and `story` contexts, and the `validate_member_access` filter.

**Nothing else in the game may instantiate a balloon.** Same rule, same reasoning, as `InspectorPanel.select()` being the only way to raise a selection surface.

### 7 — The worked example: *Damaged Ship Needs Help*

`data/dialogue/events/damaged_ship.dialogue`, driven by `data/events/damaged_ship.tres` (conditions: `EventConditionDockFree` — new, wrapping the `dock_is_free()` query — plus `min_crew`). This is the acceptance test: it exercises weighted random branches, a choice gated on a flag, a scheduled follow-up, cargo, credits, a raid, station damage, and both directions of standing.

```
~ hail

distress_captain: Station, this is the Kestrel. We are holed and running hot out of the outer system.
distress_captain: Requesting emergency dock. There is no time to explain — yes or no.

- Grant docking permission => granted
- Deny the request => denied

~ granted

$> story.set_flag("kestrel_docked", true)

%2 => granted_trader
%2 => granted_chased
%1 => granted_bounty

~ granted_trader
distress_captain: You just bought four people another year. Take what is in the hold — we cannot carry it anywhere now.
$> station.grant_cargo("steel", 20, 40)
$> station.grant_cargo("silicon_ore", 10, 25)
$> story.shift_standing("traders", 0.1)
=> END

~ granted_chased
distress_captain: Payment, and an apology. We were not running from the weather.
$> station.credits(600)
$> station.transmit("Kestrel", "Docked under fire", "The Kestrel paid for its berth and admitted it was being followed.")
$> story.queue_event("kestrel_pursuit", 4)
=> END

~ granted_bounty

patrol_officer: Station, the ship in your bay is carrying a wanted man. Hand him over and the bounty is yours.
distress_captain: Whatever they are paying you, I will double it to have never seen me.

- Hand him over
	$> story.shift_standing("authority", 0.15)
	$> story.shift_standing("pirates", -0.05)
	$> station.credits(250)
	patrol_officer: Sensible. The Confederation remembers this.
	=> END
- Feign ignorance
	$> story.set_flag("kestrel_captain_hidden", true)
	$> story.shift_standing("authority", -0.2)
	$> station.credits(900)
	distress_captain: You never saw us. We were never here.
	=> END

~ denied

%2
	Station sensors track the Kestrel bending onto a long, slow burn toward the inner planets.
	$> story.shift_standing("authority", -0.05)
%2
	The Kestrel's drive flares white and comes apart. Debris rings the station for an hour.
	$> station.damage_station(0.2)
	$> station.salvage("steel", 10, 20, 3)
%2
	Two unlit hulls close on the Kestrel, kill its engines, and match locks. The channel goes quiet.
	$> story.shift_standing("authority", -0.15)
	$> story.shift_standing("pirates", 0.05)
%1
	A patrol cutter disables the Kestrel and boards. A commendation arrives an hour later, addressed to nobody.
	$> station.transmit("System Patrol", "Fugitive detained", "Your refusal to harbour the Kestrel is noted with approval.")

=> END
```

The follow-up, `data/dialogue/events/kestrel_pursuit.dialogue`, is a second event fired by `queue_event` four hours later, whose opening line differs on `story.flag("kestrel_captain_hidden")` and which ends in `station.raid(-1)`.

Three things to notice, because they are the point of the design:

- **The brief's "possible results" list is a weighted random block, not code.** `%2` / `%1` siblings, with each weight visible next to the text it weights. The compiler's rule is `^%(weight)?( [if cond /])? ` — **the trailing space is required** — and a `%N` branch may itself carry a condition, which is how a later chapter offers an outcome only to a station that has defenses.
- **The prerequisite is an `EventCondition`, not a response condition.** "Docking bay exists and is free" decides whether the hail happens at all; putting it on the responses would mean hailing a station that cannot answer.
- **Nothing in the file names a manager.** Every line goes through `station` or `story`.

### 8 — Modding

Two new `ContentPaths` kinds (`SPEAKERS`, `FACTIONS`) plus a `PORTRAITS` kind, appended to `KINDS`. A `.dialogue` file needs no scan root of its own — it is referenced from the event `.tres` that uses it, and `import "res://…" as x` covers sharing between files. A mod therefore adds a talking event with zero core edits, which is WI-47's bar, provided the bridge's verb list covers what it wants to do. That list growing on demand is fine and expected; content growing *around* the bridge is not, which is what §3's access filter enforces.

One caveat to record now: `.dialogue` files that should be translatable must be listed in `locale/translations_pot_files`, which today names only `res://tests/test_dialogue_script.dialogue`. Add the real directory when the first real file lands.

### 9 — What this item deliberately does not build

- **The tutorial.** SAI ships here as a `SpeakerData` with a fixed portrait and nothing to say. The onboarding flow, the "Skip Onboarding" option on the New Game screen, and whatever step-gating a tutorial needs are the next item. SAI shipped against a `corporate`-pool placeholder and now points at real art (`portrait_SAI.png`, added in `a9199129` while this item was in flight).
- **Standing consequences.** §5 names the three hooks and leaves them.
- **Pawns talking in balloons.** WI-48's chats are a mood system with a signal, not conversation; giving them balloons would put a modal in front of the player every few minutes.
- **Voice.** The balloon already honours a `#voice` tag; nothing authors one.
- **Concurrent lines** (`|`), the addon's simultaneous-speaker feature. No use for it, and the balloon has one portrait slot.

## Stages

1. **The runner and the bridge.** `DialogueRunner`, `DialogueBridge`, `StoryState`, `StoryFlags`, `FactionStanding`, `EventSchedule`, the `validate_member_access` filter, the `&"story"` save section. No events converted yet; drive it from a cheat.
2. **The balloon.** Pause hold, the `ui_cancel` exception, `UIMain` mounting, blocked-response labels, the all-blocked guard, the placeholder portrait roll deleted.
3. **Speakers and portraits.** `SpeakerData`, `PortraitPool`, `SpeakerCast`, the `ResourceScanner` extension, the eight pools, SAI.
4. **The conversion.** All eleven events to `.dialogue`; `EventChoice`, `EventEffect`, the nine effect scripts, `event_card.gd`/`.tscn` and `EventData.icon` deleted; `EventManager` simplified; the load-order roll fixed; the two test tables updated.
5. **The chain.** Factions, the Comms standing block, `EventConditionDockFree`, *Damaged Ship Needs Help* and `kestrel_pursuit`.
6. **Verification.** Probe, screenshots, docs.

Stages 1–3 are independently landable and leave the game working with the event card still in place. **Stage 4 is the cutover and should be one commit** — it is the only point at which the game is briefly inconsistent.

## New cheats

The console is how stages 1–3 get driven before any event is converted, and how a chain gets tested without waiting four game-hours. Pass ids as plain strings.

- `start_dialogue(path, cue)` — run any `.dialogue` file from anywhere.
- `set_flag(id, value)` / `dump_flags()`.
- `set_standing(faction, value)` / `dump_standing()`.
- `queue_event(id, delay_hours)` / `dump_schedule()`.

Every one emits the standing `station_alert` "CHEAT: …" so a save that used them stays self-documenting.

## Testing

New GUT suites, pure classes only, constructed directly — never touching `Global` or `SignalBus`:

- `test_story_flags.gd` — declared-id enforcement, defaults, `bump`, round-trip serialization.
- `test_faction_standing.gd` — clamping at both ends, band boundaries, every band having a name and no two bands sharing one.
- `test_event_schedule.gd` — due/not-due across an hour boundary and a cycle boundary, ordering when two are due at once, dropping an unresolvable id.
- `test_speaker_cast.gd` — the stability property (one id resolves identically N times), distinctness (two ids from one pool differ), determinism under a seeded RNG, and **a pool with a hole in its numbering resolving every entry** — the `portrait19` case, pinned so nobody reintroduces range arithmetic.
- `test_dialogue_bridge.gd` — as far as purity allows: id coercion, unknown-id error paths, and the verb table being complete with respect to the nine effects it replaces.

Extended:

- `test_event_eligibility.gd` — conditions unchanged; the `has_free_choice` assertions removed.
- **A content sweep**, and the most valuable test in this item: for every `EventData` under `ContentPaths.scan(EVENTS)`, assert `dialogue != null`, `cue` non-empty, and `dialogue.get_cues().has(cue)`. A typo'd cue is a silent dead event and this is the only thing that will ever catch it.
- `test_pause_holds.gd` — `EventCard.PAUSE_HOLD` → `DialogueBalloon.PAUSE_HOLD`.
- `test_ui_theme.gd` — the `event_card.tscn` exemption removed; `balloon.tscn` stays swept.

## Verification

Per the standing rule — **a screenshot is part of the verification, and it has to be driven into the state under test.** MCP has been unreliable since the back half of Phase 3, so assume the fallback: a temporary autoload probe running a numbered checklist headlessly, printing pass/fail per check, then deleted.

Probe checks worth naming in advance:

1. A mutation-only cue runs, changes state, shows nothing, and **never takes the pause hold** — assert `TimeManager.pause_holders()` stays empty across it.
2. A conversation with lines takes `&"dialogue"` on the first line and releases it on end, with the holder set empty afterwards.
3. The same speaker id resolves to the same face and the same name across five lines.
4. A flag set in one conversation is readable by a second, and survives save → load.
5. `queue_event` fires at the right hour, exactly once, and does not re-fire after a save/load taken between queueing and firing.
6. Every branch of a `%` block is reachable — fixed seed, N runs, assert each branch at least once.
7. `validate_member_access` denies `Global.credits` from a probe `.dialogue`, and the denial names the file.
8. Every `SpeakerData` resolves a texture, and every `PortraitPool` is non-empty.

Screenshots, driven into state: a two-speaker conversation with a portrait; a response list with one blocked entry showing its blocker; the all-blocked escape hatch; the Comms standing block; the balloon over an open mode panel (draw order); the pause menu over the balloon (Esc still reaches it).

## Edge cases

- **A conversation opens while a critical alert is holding the sim.** Two holds, refcounted, independent — exactly what WI-53 made `hold_pause` reference-counted for. Neither releases the other.
- **A raid starts mid-conversation.** Nothing special: the sim is stopped and the raid resumes when the conversation ends.
- **Saving mid-conversation.** The pause menu is reachable (§1), so it is possible. The event is in `pending_events` and re-fires from its cue on load; the cast re-rolls. Any state a choice already committed stays committed — mutations are not transactional and must not pretend to be.
- **Game over during a conversation.** `GameOverScreen` takes its own hold and draws above; the runner drops its queue on `game_over`.
- **A pool directory is empty or missing** (a mod was removed): the speaker falls back to no portrait plus a `push_warning`, never a broken texture rect.
- **An event fires whose dialogue resource failed to load.** Logged, dequeued, no modal. An unopenable conversation must never become an unclosable one.
- **Two events fire in the same tick.** Already handled by `pending_events`; the runner's queue is the second half of the same guarantee.
- **A conversation is running when the player quits to menu.** The runner unregisters both state contexts in `_exit_tree`; a stale context surviving the scene swap would have the next run talking to a freed node.

## Open questions

1. **Does a conversation stop the sim, always?** The event card did, so this preserves today's behaviour. But a chatty tutorial that pauses on every line will feel worse than one that does not — and the tutorial is the next item. A per-conversation `holds_pause` argument on `run()` is the obvious answer and is cheap to add later; not adding it now avoids designing for a caller that does not exist yet.
2. **How many portrait pools should map to how many factions?** Eight pools, three scored factions. The mapping in §4 is a guess made from filenames; it wants looking at with the art actually on screen.
3. **Should `EventData.body` survive at all?** It is the Comms row now, and a good author would rather write that line at the *end* of the conversation via `station.transmit()` than up front in a `.tres`. Keeping it is the low-risk call for this item; deleting it is a plausible follow-up once eleven converted events show whether anyone uses it.
