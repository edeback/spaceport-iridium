# Writing Events

How to add an event to Spaceport Iridium. Current as of [[WI-62_Dialogue]] (2026-08-22).

An event is **two files**:

| File | Decides |
|---|---|
| `data/events/<id>.tres` | *Whether* it happens — conditions, weight, cycle gate, cooldown |
| `data/dialogue/events/<id>.dialogue` | *What is said and what it does* |

That split is the whole design. The `.tres` is read by the weighted picker before any conversation exists; the `.dialogue` file is the event's behaviour. There is no `EventChoice` and no `EventEffect` — if you find a comment mentioning them, it is stale.

---

## 1 — The quickest possible event

**`data/dialogue/events/coolant_leak.dialogue`**

```
~ leak

A coolant line lets go somewhere in the spine. Nobody is hurt, but the smell will linger.
$> station.mood("coolant_leak_stink", -0.05, 8.0)
=> END
```

**`data/events/coolant_leak.tres`**

```
[gd_resource type="Resource" script_class="EventData" format=3]

[ext_resource type="Script" path="res://data/events/event_data.gd" id="1_evdata"]
[ext_resource type="Resource" path="res://data/dialogue/events/coolant_leak.dialogue" id="3_script"]

[resource]
script = ExtResource("1_evdata")
id = &"coolant_leak"
title = "Coolant Leak"
body = "A coolant line let go in the spine. Nobody was hurt; the smell will take a shift to clear."
dialogue = ExtResource("3_script")
cue = "leak"
weight = 1.0
min_cycle = 3
cooldown_cycles = 6
mood_ids = PackedStringArray("coolant_leak_stink")
```

Then **`godot --headless --import`** once, or the `.dialogue` file will not resolve.

That is a complete event. It is discovered by a directory scan — there is no registration step anywhere.

---

## 2 — The `.tres`: every field

| Field | Meaning |
|---|---|
| `id` | Stable, unique, non-empty. Used by saves, `story.queue_event()` and the `fire_event` cheat. |
| `title` | The alert headline and the Comms subject line. |
| `body` | **The Comms row, not card text.** Logged the moment the event fires, so a player who was mid-placement can read what happened. Nothing renders it as prose to answer. |
| `dialogue` | The `.dialogue` resource. An event without one never fires. |
| `cue` | Which `~ cue` in that file to start from. Validated at load — a typo is caught on startup, not never. |
| `weight` | Relative chance among eligible events. `0.0` = never rolls naturally (see §8). |
| `min_cycle` | Earliest cycle a natural roll may pick it. |
| `cooldown_cycles` | Cycles before it is eligible again after firing. |
| `conditions` | All must hold. See below. |
| `mood_ids` | **Required if your dialogue calls `station.mood()`** with an id of its own. See §6. |

### Pacing, in practice

Two rolls per cycle (cycle start plus one random mid-cycle hour), each with a chance derived from `EventManager.expected_cycles_between_events` (default 1.5). Weight is relative *among the currently eligible set*, so a weight of `0.5` is not "half as often" in absolute terms — it is half as often as a `1.0` event that is eligible at the same moment.

### Conditions

Composed as sub-resources. Each is a script under `data/events/conditions/`:

| Condition | Field | Gate |
|---|---|---|
| `condition_min_crew` | `min_crew: int` (default 1) | At least this many crew |
| `condition_min_credits` | `min_credits: int` | At least this many credits |
| `condition_has_module_tag` | `tag: String` | A **constructed** module carries that gameplay tag |
| `condition_dock_free` | — | A finished docking bay exists and nothing is using it |
| `condition_disease_unlocked` | — | The disease system is available at this tier |
| `condition_difficulty_allows_raids` | — | The run's difficulty permits raids |

Authored module tags: `AlgaeCulture`, `Commerce`, `Core`, `Crew`, `Defense`, `Dock`, `Electrolysis`, `Forge`, `Hydroponics`, `IceProcessing`, `Industrial`, `Life Support`, `Lodging`, `Logistics`, `Power`, `Refinery`, `Storage`, `Thermal`, `Transport`. (These are `tags` — gameplay. Never gate on `ui_category`, which is presentation only.)

The `.tres` shape for one condition:

```
[ext_resource type="Script" path="res://data/events/event_condition.gd" id="2_cond"]
[ext_resource type="Script" path="res://data/events/conditions/condition_min_crew.gd" id="4_c0"]

[sub_resource type="Resource" id="Resource_c0"]
script = ExtResource("4_c0")
min_crew = 2

[resource]
...
conditions = Array[ExtResource("2_cond")]([SubResource("Resource_c0")])
```

**Put the prerequisite here, not on a response.** "A docking bay exists and is free" decides whether the hail happens at all; gating the *responses* instead means hailing a station that cannot answer and then telling the player so.

---

## 3 — The `.dialogue`: syntax

Indent with **tabs**. Dialogue Manager 4 syntax — v3 examples on the internet are wrong in three places noted below.

```
~ cue_name              # a cue (v3 called these "titles")
=> cue_name             # jump
=>< cue_name            # jump and return
=> END                  # end the conversation
=> END!                 # end, ignoring pending returns

speaker_id: Some text.  # a line with a speaker
Some text.              # narration — no speaker, no portrait

- A response
	speaker_id: What happens if you pick it.
	=> END
- A response that jumps => some_cue

$> station.credits(-300)      # a mutation (v3 used `do` / `set`, still parse)
$>> station.alert("Hi")       # non-blocking mutation

if story.flag("x")            # conditions
	speaker_id: One thing.
elif station.tier() >= 2
	speaker_id: Another.
else
	speaker_id: A third.

%2 => outcome_a               # weighted random siblings
%1 => outcome_b

%                             # a random block
	Some text.
	$> station.credits(50)
%
	Some other text.

import "res://data/dialogue/shared.dialogue" as shared
=>< shared/some_cue
```

Inline: `[[a|b|c]]` picks one at random per evaluation, `[wait=1.5]` pauses typing, `[next=auto]` auto-advances, `[speed=1.5]` changes typing speed.

### Three authoring traps

1. **`": "` anywhere in a line splits it into speaker and text.** A narration line containing a colon silently acquires a "speaker" made of its own first clause. Escape it as `\:`, or rewrite the sentence. `test_event_content.gd` catches the obvious cases by flagging any character name over 32 characters.
2. **A `%` weighted-random marker needs its trailing space.** `%2 => outcome` works; `%2=> outcome` does not.
3. **A `[#blocked=…]` tag value must not contain a comma** — the tag parser splits on commas.

---

## 4 — Speakers and portraits

The name at the head of a line is a `SpeakerData` id. Anything that isn't one prints verbatim with no portrait, which is the narration behaviour.

**A speaker is resolved once per conversation, not once per line.** A pool-drawn face and a rolled name are picked the first time the speaker talks and held for every line after — that is what makes a random portrait usable. Two speakers drawn from the same pool never get the same face.

### Existing speakers

| id | Name | Face | Faction |
|---|---|---|---|
| `sai` | SAI (fixed) | `portrait_SAI.png` (fixed) | `arc` |
| `arc_auditor` | rolled | `corporate` pool | `arc` |
| `arc_officer` | rolled | `corporate` pool | `arc` |
| `pirate_captain` | rolled | `pirate` pool | `pirates` |
| `patrol_officer` | rolled | `authority` pool | `authority` |
| `freight_broker` | rolled | `trader` pool | `traders` |
| `distress_captain` | rolled | `trader` pool | `traders` |

### Portrait pools

Eight, all over `assets/external/thirstsector_portraits/`, all **scanned directories** rather than lists:

| Pool | Filename prefix | Faces |
|---|---|---|
| `civilian` | `portrait`, excluding `portrait_` | 37 |
| `pirate` | `portrait_pirate` | 22 |
| `authority` | `portrait_hegemony` | 17 |
| `fringe` | `portrait_luddic` | 17 |
| `enforcer` | `portrait_diktat` | 16 |
| `trader` | `portrait_league` | 15 |
| `corporate` | `portrait_corporate` | 11 |
| `mercenary` | `portrait_mercenary` | 8 |

> Pools are scanned, never numbered. The vanilla art runs `portrait12`…`portrait18` then `portrait20`…`portrait49` — **there is no `portrait19`** — so any code that builds a path from a numeric range asks for a missing file one time in thirty-seven.
>
> **Naming rule for new art:** anything belonging to a faction or a character is `portrait_<something>`. The `civilian` pool is everything under `portrait` *except* `portrait_`, so a file named that way stays out of the anonymous crowd automatically. A face that should be drawn at random by civilians is `portrait<number>`.

### Adding a speaker

`data/speakers/<id>.tres`:

```
[gd_resource type="Resource" script_class="SpeakerData" format=3]

[ext_resource type="Script" path="res://data/speakers/speaker_data.gd" id="1_speaker"]
[ext_resource type="Resource" path="res://data/portraits/mercenary.tres" id="2_pool"]

[resource]
script = ExtResource("1_speaker")
id = &"salvage_boss"
display_name = ""
portrait_pool = ExtResource("2_pool")
faction = &"traders"
```

- `display_name` **empty** rolls a name per conversation. Fill it in for a recurring character.
- `portrait` (a `Texture2D`) instead of `portrait_pool` pins one face.
- `faction` is presentational — it does **not** move standing on its own. A conversation that means to move a standing says so.

### An image with no name

A `SpeakerData` with an empty `display_name` and a fixed `portrait` is exactly that: the balloon hides the name label when there is nothing to show. There is no separate "event image" concept.

---

## 5 — `station`: what a conversation can *do*

The only vocabulary that reaches the simulation. Ids are plain strings — Godot's `Expression` rejects `&"…"`, and an unknown id is a logged error rather than a silent no-op.

### Actions

| Call | Effect |
|---|---|
| `station.credits(n)` | Positive pays the station, negative charges it. Books the swing on the economy ledger. Going below zero is allowed. |
| `station.loan(principal)` | An ARC loan at standard terms. No-op if one is already running. |
| `station.mood(id, value, hours)` | Station-wide happiness modifier. Re-using an `id` refreshes rather than stacks; late hires get it too. **Declare the id in `mood_ids`.** |
| `station.outbreak(disease_id = "", min = 1, max = 3)` | Seeds a disease. Empty id rolls from the tier's pool. Always leaves one crew member well. Ids: `station_flu`, `fervent_fever`, `void_sickness`. |
| `station.market_shock(resource_id, multiplier, hours)` | Below 1 = scarcity (prices spike), above 1 = glut. |
| `station.offer_contract(premium_bonus = 0.15)` | A delivery-contract offer on the board. |
| `station.raid(strength = -1.0)` | A real pirate wave. `-1` auto-scales from station value. |
| `station.breach(count = 1, hours = 2.0)` | Hull breaches in random pressurised modules. |
| `station.damage_station(severity)` | Every built module loses that **fraction of its max HP**. `0.15` is a scare; `0.4` hurts. |
| `station.salvage(resource_id, min, max, piles = 2)` | Free-floating piles near the station; crew sweep them in through the airlocks. |
| `station.grant_cargo(resource_id, min, max)` | A docked ship offloads. Into the bay if it fits, piled at the dock if not — never lost. |
| `station.transmit(sender, subject, body)` | Something worth re-reading later. Lands in Comms with a LOW alert. |
| `station.alert(title, detail)` | Something worth looking at now. HIGH — stays until clicked. |

### Queries — for `if` and `[if … /]`

| Call | Returns |
|---|---|
| `station.dock_is_free()` | A finished bay exists and nothing is using it |
| `station.credits_held()` | Current credits |
| `station.stock(resource_id)` | Station-wide total of a resource |
| `station.crew_count()` | Living crew |
| `station.tier()` | Station tier, 1–5 |
| `station.under_attack()` | A raid is running |
| `station.has_module(tag)` | A constructed module carries that gameplay tag |

Resource ids: `biomass`, `biowaste`, `carbon`, `credits`, `gold`, `gold_ore`, `hydrogen`, `ice`, `iridium`, `iridium_ore`, `iron`, `iron_ore`, `oxygen`, `silicon`, `silicon_ore`, `steel`, `stored_energy`, `water`.

> **Nothing else is reachable.** A `.dialogue` file cannot touch `Global`, `SignalBus` or any manager — the runtime refuses it and logs why. If your event needs a verb that isn't here, add it to `DialogueBridge`, don't reach around it.

---

## 6 — `story`: what a conversation *remembers*

| Call | Effect |
|---|---|
| `story.flag(id)` | Truthy read — a set bool, a positive count, a non-empty string |
| `story.value(id)` | The raw value, for comparing a counter against a number |
| `story.set_flag(id, value)` | Write |
| `story.bump(id, amount = 1)` | Add to a counter, returns the new value |
| `story.standing_of(id)` | Faction standing, −1 … +1 |
| `story.shift_standing(id, delta)` | Move it, clamped |
| `story.standing_band(id)` | The band as a word |
| `story.queue_event(event_id, delay_hours)` | Promise a follow-up |
| `story.cancel_event(event_id)` | Un-promise it |

### Flags are declared

A flag is a bare string on both sides of a contract, and the typo is silent in the direction that matters — `story.flag("kestrel_dockd")` reads false forever and your chain simply never continues. **Add your flag to `StoryFlags.DECLARED`** in `scripts/dialogue/story_flags.gd`, with the default (which is also its type) and a one-line comment:

```gdscript
## Whether the player let the salvage crew aboard. Read by `salvage_fallout`.
&"salvage_crew_admitted": false,
```

An undeclared id is refused and logged. `test_event_content.gd` sweeps every `.dialogue` file for flags that aren't declared, so a typo fails the suite rather than shipping.

Currently declared: `kestrel_docked`, `kestrel_captain_hidden`, `kestrel_pursuit_seen`, `sai_introduced`, `distress_hails_answered` (a counter).

### Faction standing

| id | Name | Scored |
|---|---|---|
| `authority` | System Patrol | yes |
| `traders` | Free Merchant League | yes |
| `pirates` | The Wreckyards | yes |
| `arc` | Astral Resource Corporation | **no** — ARC's relationship is the tier ladder |

Five bands over −1 … +1: **Hostile** (≤ −0.6), **Cold** (≤ −0.2), **Neutral**, **Warm** (≥ +0.2), **Allied** (≥ +0.6). Shifts clamp, so you never have to check the floor.

Sensible magnitudes: a small courtesy `0.05`, a real favour `0.1–0.15`, a betrayal `0.2`. It takes several events to cross a band, which is the intent.

> **Standing has no gameplay consequence yet.** It gates dialogue and renders on the Comms `STANDING` tab, and the panel footer tells the player so. Write to it freely; just don't imply on screen that it does more than it does.

### Mood ids

If your dialogue calls `station.mood("something", …)`, that id must appear in the event's `mood_ids`, or the crew Needs tab will print a modifier the player cannot account for. An id of the exact form `event_<your event id>` is recovered automatically and needs no entry.

---

## 7 — Chaining

Three mechanisms; use the lightest that works.

**Within one conversation** — cues and responses. The Kestrel's three "permission granted" outcomes are a weighted random block jumping to three cues.

**Across conversations, same session or later** — a flag:

```
# in the first event
- Feign ignorance
	$> story.set_flag("kestrel_captain_hidden", true)
	=> END

# in a later event
if story.flag("kestrel_captain_hidden")
	pirate_captain: You are the station that hid a man from the Patrol.
else
	pirate_captain: The Kestrel went quiet somewhere near you.
```

**A timed follow-up** — `story.queue_event(id, hours)`:

```
$> station.transmit("Kestrel", "Docked under fire", "Whatever was behind them knows where you are.")
$> story.queue_event("kestrel_pursuit", 4)
```

A scheduled event **bypasses the roll, the cooldown and `min_cycle`** — the player already chose it. Its `conditions` are still checked; if they fail, the player is told the moment passed rather than being left waiting.

Give the follow-up `weight = 0.0` and `min_cycle = 999` so it can *only* arrive that way. The content sweep then checks that something actually queues it, so a dead-end chapter fails the suite.

Everything above is **saved** and survives a save taken between chapters.

---

## 8 — Blocked responses

A response can carry a condition. It still **renders**, disabled, with its reason — a blocked action names its blocker on its own control:

```
- Pay the ransom [if station.credits_held() >= 600 /] [#blocked=You cannot raise 600 credits]
	$> station.credits(-600)
	=> END
- Refuse them
	$> station.raid(-1.0)
	=> END
```

- The condition is **self-closing** in v4: `[if x /]`, not `[if x]`.
- `[#blocked=…]` is the sentence the player reads. Without it they get the raw expression, which is deliberately ugly so you notice.
- **Always leave one response the player can take.** If every option is gated the balloon offers `[ No option available — end transmission ]` and logs an error — an escape hatch, not a design.

---

## 9 — Notification events

An event that shouldn't interrupt anyone is a cue with **no dialogue lines**:

```
~ glut
$> station.market_shock("iron_ore", 2.5, 24.0)
=> END
```

The mutations run, no balloon opens, the simulation is never paused, and the player sees the alert and the Comms row. There is no flag for this — whether an event interrupts is a property of what you wrote.

---

## 10 — Testing what you wrote

**In game**, from the Panku console (backtick). Pass ids as plain strings:

```
Global.cheats.fire_event("coolant_leak")
Global.cheats.start_dialogue("res://data/dialogue/events/coolant_leak.dialogue", "leak")
Global.cheats.set_flag("kestrel_docked", true)
Global.cheats.dump_flags()
Global.cheats.set_standing("authority", -0.7)
Global.cheats.dump_standing()
Global.cheats.queue_event("kestrel_pursuit", 1)
Global.cheats.dump_schedule()
Global.cheats.advance_hours(4)
```

**Headless**, before committing:

```
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

`test_event_content.gd` sweeps every authored event and `.dialogue` file and will fail on: a missing or typo'd cue; a duplicate or empty id; an empty `body`; a null condition slot; a character with no `SpeakerData`; an undeclared flag; a resource id that doesn't exist; an unscored faction being shifted; a mood id missing from `mood_ids`; a scheduled-only event nothing reaches; and a colon accidentally turning prose into a speaker.

---

## 11 — Checklist for a good event

- [ ] The `title` reads as a headline and the `body` reads as a log entry a player would want to re-read.
- [ ] Conditions describe a world the event makes sense in — not just "the player can afford it".
- [ ] Every response leads somewhere, and at least one is always takeable.
- [ ] Anything a choice costs is visible before it is chosen, either in the label or in the line above it.
- [ ] Outcomes vary. A `%` block with three branches is more interesting than one certain result, and costs no code.
- [ ] Anything the event should be remembered for is a flag, and the flag is declared.
- [ ] If it moves a standing, the amount is proportionate to what the player actually did.
- [ ] It does not interrupt for something that isn't worth stopping the game over — that is what a notification event is for.
- [ ] `godot --headless --import`, then GUT green.

---

## Reference

- Design and rationale: [[WI-62_Dialogue]]
- Runtime: `scripts/dialogue/` (`DialogueBridge`, `StoryState`, `StoryFlags`, `FactionStanding`, `EventSchedule`, `SpeakerCast`, `ResponseRules`), `scripts/managers/dialogue_runner.gd`, `ui/dialogue/balloon.gd`
- Data: `data/events/`, `data/dialogue/events/`, `data/speakers/`, `data/portraits/`, `data/factions/`
- Worked example of a chain: `data/dialogue/events/damaged_ship.dialogue` and `kestrel_pursuit.dialogue`
- Addon docs: [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) — read the **v3 → v4 upgrade notes**, as most examples online predate it.
