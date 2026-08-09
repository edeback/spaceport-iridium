# WI-48 — Pawn Interactions

> **Phase 4, first item. Planned, not started.** The roadmap, tech spec and Phase-4 notes are deliberately *not* updated yet — the rest of Phase 4 is still being planned, and the ordering around this item isn't settled. Update [[02_Roadmap]] and [[01_Technical_Specification]] when the phase is laid out, not when this doc lands.

## Goal

Pawns should have meaningful interactions with each other — flavor and story, not just a shared occupancy bonus. Crew who share a module **chat**, chats land positive or negative, and the outcome is *remembered*: every crew member accumulates an opinion of every other crew member, and those opinions feed back into future chats and into mood.

This replaces the passive "someone else is in the room" recreation drip (WI-05 step 8) with a discrete, legible event. Recreation still comes out of company; it now arrives in visible chunks with a cause and a name attached.

## Design

### 1 — One component, grown, not a second one

The chat driver **and** the opinion ledger both live in the existing `SocializeComponent` (`pawns/socialize_component.gd`), rewritten. Three reasons to keep it as one component rather than splitting behavior from state:

- The chat driver is the ledger's only writer. Splitting them buys nothing and costs a cross-component lookup on every resolution.
- One save block (`&"social"`) instead of two.
- **"Carries this component = participates" is already the robot-exclusion rule** and stays exactly one rule. Robots and drones don't have the component and therefore neither chat nor hold opinions — no new `is_robot` check anywhere.

The class name stays `SocializeComponent` so `crew_pawn.tscn` and `socialize_component.tscn` need no re-pathing (and any modded pawn kind referencing it keeps working — WI-47 M10 ships pawn kinds).

**Visitors don't chat in v1**, and that falls out of the same rule: `visitor_pawn.tscn` has no `SocializeComponent`. Enabling guest chatter later is a scene edit plus a UI filter decision, not a code change — noted, not done.

### 2 — What gets removed

`_on_slow_tick`'s **company branch** — the `passive_fun_per_hour` drip scaled by `_count_company()` — is deleted. Chats are what company is worth now.

The **solitude branch is kept unchanged**: Introvert recharging while *alone* in a module is a different mechanic (it doesn't involve another pawn) and nothing in this WI replaces it.

The WI-05 balance guard is **kept and now applies to chats**: a chat's recreation payout never lifts recreation above `social_cap_percent` (the renamed `passive_cap_percent`, default 50). Active recreation must stay the only way to fill the bar and the only lever above half happiness from that need. A chat that would overshoot the cap grants the remainder and no more — it still counts as a chat and still moves opinions.

### 3 — The chat loop

On `slow_tick` (never `_process`), each pawn's component:

1. Accumulates `_hours_since_chat += interval / SECONDS_PER_HOUR`.
2. Bails unless: `current_module != null`, not asleep (`current_job` is a sleep-type job), and `_hours_since_chat >= chat_interval()`.
3. Scans the `Groups.PAWN` group for others in the same module that also carry a `SocializeComponent`, are awake, and are **also off cooldown**. (Same scan shape the old passive tick did — see *Edge cases* for why an occupant index isn't worth it yet.)
4. Picks one partner, weighted **against recency**: partners not spoken to in a while are likelier than the one from the last conversation. Uses the ledger's `last_hour` stamp; unmet crew get the top weight, so new hires get talked to.
5. **Resolves the chat once for the pair** and resets *both* cooldowns.

Resetting both cooldowns inside the resolution is what makes double-resolution impossible: whichever component ticks first initiates, and the partner's own tick that same interval finds itself on cooldown. This holds regardless of node order, so it doesn't depend on `slow_tick` subscriber ordering.

`chat_interval()` = `base_chat_interval_hours` (default **1.0**) × the product of the pawn's traits' `chat_interval_multiplier`. **Extrovert 0.5** (wants to chat twice as often), **Introvert 2.0**. Pair readiness needs *both* pawns ready, so an Extrovert paired only with an Introvert converses at the Introvert's pace — intended.

### 4 — Outcome: positive or negative

One roll per chat, one shared verdict (a conversation goes well or badly for both people in it), then **per-direction opinion deltas** so asymmetric opinions can persist.

`P(positive) = clamp(base_positive_chance + opinion_weight × (opinion̄ / OPINION_MAX) + affinity_weight × trait_affinity + skill_weight × social_skill_term, min_chance, max_chance)`

- `base_positive_chance` default **0.75** — the "people who work together usually like each other" trend. Repeated exposure drifts a pair positive on its own; it takes trait conflict or a bad streak to go the other way.
- `opinion̄` is the mean of the two directional opinions, so a pair that already dislikes each other is likelier to have another bad one — the spiral the brief asks for, bounded by `min_chance`.
- `trait_affinity` comes from trait axes (below).
- `social_skill_term` — see §6.
- `min_chance` / `max_chance` (default 0.05 / 0.97) keep both spirals from latching.

**Opinion deltas** are asymptotic so nobody pins at the extremes from sheer repetition:

`delta = ±magnitude × (1 - |opinion| / OPINION_MAX)`

with `magnitude` rolled in a band (positive chats slightly larger than negative ones by default, tunable). Opinion range is **−100…+100**, 0 = neutral. Each direction uses its *own* current opinion in that falloff, so a one-sided friendship stays one-sided.

**Payout:**
- Positive → recreation to both (`chat_recreation` × the pawn's trait `chat_recreation_multiplier`), clamped by the cap in §2.
- Negative → no recreation, plus a small **finite** happiness modifier `&"bad_chat"` (e.g. −0.05 for 4h). Finite modifiers already persist and tick down (the WI-29 `good_meal`/`bad_meal` precedent) — no new persistence machinery.

Both pawns record the interaction (§5) and `SignalBus.pawns_chatted(a, b, positive, delta)` fires for UI and for the future relationships/death work.

### 5 — The ledger

Per-partner record, keyed by `pawn_id`:

```
{ opinion: float, chats: int, last_cycle: int, last_hour: int, last_positive: bool }
```

Plus a bounded `recent` array (last ~10 chats: partner id, partner name at the time, positive, delta, cycle/hour) — this is the "record what sort of effect it had" list the panel reads, and it's what makes a fired crew member's history still legible.

Names are snapshotted into `recent` because the partner may be gone by the time it's read; the per-partner records resolve `pawn_id` → live pawn lazily instead.

### 6 — Trait axes and the social skill

**Trait axes.** `TraitData` gains two fields:

- `social_polarity: float` (default **0.0** = socially neutral, opts the trait out entirely)
- `social_axis: StringName` (default empty → **falls back to `exclusive_group`**)

`trait_affinity` = for each axis both pawns have an opinion on, `polarity_a × polarity_b`, summed and normalised. Same sign = aligned = friendlier; opposite = conflict = likelier to go badly. Optimist/Pessimist and Introvert/Extrovert already share `exclusive_group`s (`mood`, `sociability`), so each needs exactly one new line. Hardy/Weak share `constitution` but stay at polarity 0 — a tough constitution is not a personality. Spacer has no group and no polarity.

The `exclusive_group` fallback is why this is two data lines rather than a new taxonomy; the explicit `social_axis` exists so a modder can define an axis whose traits *aren't* mutually exclusive at roll time.

**The social skill.** `data/skills/social.tres` exists and currently has no gameplay effect — only the disease maluses reference it. This is the natural place to give it one, so it's included deliberately: the pair's social skill nudges `P(positive)` (`skill_weight`, small), and both participants earn a little social xp per chat. Diseases that dull the social skill therefore make the sick worse company, for free. **Setting `skill_weight` to 0 in the exported tuning disables the whole hook** if it plays badly — it's one number, not a structural dependency.

### 7 — Mood from sharing a room

Separate from chats, and continuous: a pawn co-located with crew it likes or dislikes gets a small mood shift, with a **wide neutral band** so ordinary acquaintances don't move mood at all.

`SocialMath.mood_offset(mean_opinion, neutral_band, max_offset)` → 0 inside ±`neutral_band` (default **±25**), then ramping linearly to ±`max_offset` (default **±0.06**) at ±100.

Applied as a single INF-duration modifier under one id (`&"company"`), recomputed on `module_changed` and on `slow_tick`, over this pawn's opinions of the co-located crew. **Not saved** — it's derived state, re-derived on the first tick after load, exactly like the adjacency-driven maluses and the trait exterior modifier.

One id, recomputed, means it can never stack or leak when a pawn walks out of the room.

### 8 — Pure math, in one place

`scripts/utility/social_math.gd` (`class_name SocialMath`), all static, no `Global`/`SignalBus` — so it's GUT-testable per the standing rule:

- `positive_chance(opinion_mean, affinity, skill_term, tuning) -> float`
- `opinion_delta(current, positive, magnitude) -> float`
- `mood_offset(mean_opinion, neutral_band, max_offset) -> float`
- `chat_interval(base, trait_multiplier) -> float`
- `trait_affinity(axes_a, axes_b) -> float`
- `partner_weight(hours_since_last, chats) -> float`
- `opinion_label(opinion) -> String` (Hostile / Cold / Neutral / Friendly / Close — the UI banding)

Balance numbers stay exported on `socialize_component.tscn` (one authored instance, one place to tune) and are *passed into* the pure functions, never read from inside them.

### 9 — UI: the Social tab

New `ui/pawns/pawn_social_tab.gd` + `.tscn`, added to `DataTabs` in `pawn_info_panel.tscn` (the panel already calls `set_pawn` on every tab child). Hidden — `visible = false` in `set_pawn`, the `PawnSkillsTab` pattern — for pawns with no `SocializeComponent`, so robots are excluded without a type check.

- One row per **other live crew member** (`Global.crew_manager.get_crew()`, minus self; robots and visitors are already excluded by that call): name, opinion band label, and a bar tinted by sign. Crew never met read "Haven't spoken" rather than "Neutral 0" — not knowing someone and being indifferent to them are different things and the panel should say so.
- Row tooltip: chat count and "last spoke: Cycle 4, 09:00".
- Below a separator, the `recent` log, newest first: "Chatted with Ada — went well (+6), Cycle 4 09:00".

### 10 — Save

`SocializeComponent` implements the WI-47 pawn-component hooks (`save_order` / `save_key` / `get_save_data` / `load_save_data`) — no `SaveManager` edit needed, which is the point of that refactor. Key `&"social"`, order **50** (after traits at 40; nothing in the block depends on another component being restored).

Saved: the per-partner ledger (`pawn_id` → record), `_hours_since_chat`, the `recent` array. **Not saved:** the `&"company"` mood modifier (derived, §7). `pawn_id` is a monotonic counter that load bumps past every restored id, so ledger keys can never be re-pointed at a different pawn.

Backward-compatible: a pre-WI-48 save has no `social` block, and a missing block means "no opinions yet" — which is the correct reading of a station whose crew has never chatted.

### 11 — Cheats

Per the standing rule, each emits its `station_alert` "CHEAT: …":

- `dump_opinions(cell)` — the ledger of the crew at/near `cell`.
- `set_opinion(cell_a, cell_b, value)` — force a directional opinion (both directions if called twice).
- `force_chat(cell_a, cell_b)` — resolve a chat immediately, ignoring cooldowns.

## Files to touch

- **New:** `scripts/utility/social_math.gd`; `ui/pawns/pawn_social_tab.gd` + `.tscn`; `tests/unit/test_social.gd`
- `pawns/socialize_component.gd` — rewritten: chat loop, ledger, mood modifier, save hooks. `socialize_component.tscn` — the exported tuning block (company drip exports removed, chat/opinion/mood exports added)
- `data/traits/trait_data.gd` — `social_polarity`, `social_axis`; **remove** `passive_social_multiplier`, `passive_social_cap_bonus`; add `chat_interval_multiplier`, `chat_recreation_multiplier` (keep `solitude_recreation`)
- `data/traits/optimist.tres`, `pessimist.tres`, `introvert.tres`, `extrovert.tres` — polarities + chat multipliers (hardy/weak/spacer unchanged)
- `pawns/pawn_traits_component.gd` — aggregate hooks: `chat_interval_multiplier()`, `chat_recreation_multiplier()`, `social_axes()`; drop the two passive-social hooks
- `scripts/managers/signal_bus.gd` — `pawns_chatted(a, b, positive, delta)`
- `ui/pawns/pawn_info_panel.tscn` — the new tab child
- `scripts/utility/cheats.gd` — the three cheats above
- Remember: `filesystem_manage(op="scan")` after the new `class_name` files

Not touched: `scripts/managers/save_manager.gd` (component hooks carry it), `pawn_needs_component.gd` (modifiers go through the existing `add_modifier`), and the recreation *job* path (chats are ambient, never a job).

## Implementation order

1. `SocialMath` + `test_social.gd` first — the whole design is five formulas, and they're worth pinning down before anything reads them.
2. Trait data fields + the four `.tres` + the traits-component hooks. Nothing consumes them yet.
3. `SocializeComponent` rewrite: ledger, cooldown, partner pick, resolution, recreation payout under the cap, save hooks. Delete the company drip here. **The game is playable and fully verifiable at this step** — chats work, opinions move — with no UI beyond the cheat dumps.
4. Mood-from-company modifier.
5. Social tab; cheats; `pawns_chatted` consumers.

## Edge cases

- **Double resolution.** Both cooldowns reset inside the resolution, so a pair can't chat twice in one tick from either end; correctness doesn't depend on `slow_tick` subscriber order.
- **Three or more in a room.** One chat per pawn per tick — pairs form, the room doesn't blanket-boost. This is a real behavior change from the old drip: a busy mess hall is now better because you find a ready partner *sooner*, not because the rate multiplies with headcount. Balance accordingly (the old `fun_per_extra_pawn_per_hour` knob has no successor).
- **Asleep / EVA / in a turbolift.** Sleepers are skipped (a bunk-mate isn't company); `current_module == null` already excludes anyone outside; `CONVEYED` pawns have no module and are excluded for free.
- **A pawn leaves** (fired, resigned, walked out). Ledger entries dangle; they resolve lazily and the panel skips ids with no live pawn. Entries are deliberately **not** pruned — they're a few bytes, and the Phase-4 death/memorial work will want "who knew them."
- **Robots and visitors** don't participate — they have no component, which is the only rule.
- **Trait axes with polarity 0** (Hardy/Weak/Spacer, and every mod trait that doesn't opt in) contribute nothing; a modded trait with a new axis works with no code change.
- **Cap collision.** A pawn already above `social_cap_percent` still chats and still moves opinions; only the recreation payout is clipped. Otherwise a well-entertained crew would stop having a social life.
- **Negative spiral.** Reachable by design (bad opinions bias toward more bad chats) but floored by `min_chance` and by the delta falloff, so two people who hate each other stay at a stable, unpleasant equilibrium instead of racing to −100.
- **Load.** Cooldowns and ledgers restore per-pawn with no cross-pawn resolution needed; the `&"company"` modifier re-derives on the first tick. No chat can resolve mid-load because `slow_tick` won't have fired.
- **Cost.** The partner scan is O(crew) per ready pawn per `slow_tick` — the same group scan the passive tick already did, and now it only runs for pawns that are actually off cooldown, so it's *cheaper* than what it replaces. A module-side occupant index would be the fix if crew counts ever make this show up in a profile; there isn't one today and this WI shouldn't invent one.
- **Difficulty (WI-37).** No hook in v1. If it wants one later, `base_positive_chance` is the single knob.

## Verification

1. **GUT:** `test_social.gd` over `SocialMath` — positive-chance monotonicity in opinion/affinity/skill and clamping at both ends; delta falloff approaching but never exceeding ±100; mood offset exactly 0 across the whole neutral band and continuous at its edges; trait affinity for aligned / conflicting / unrelated / neutral-polarity pairs; interval multipliers (Extrovert 0.5, Introvert 2.0, both traits absent 1.0); partner weighting favouring the unmet and the long-unspoken; label banding boundaries.
2. **Headless probe** (temporary autoload, the standard fallback): two crew in one module — assert a chat resolves within the expected window, both cooldowns reset together, both ledgers gained a symmetric-sign entry with independent deltas, and recreation rose on a positive outcome but not past the cap. Then force ~50 chats via the cheat and assert the pair's opinions trend positive with `base_positive_chance` at 0.75, and trend negative with it at 0.1 — the trend claim is the one this design most needs proven.
3. **Trait conflict:** an Optimist/Pessimist pair vs. an Optimist/Optimist pair over the same forced chat count — the conflicting pair ends materially lower. Same probe.
4. **Cooldowns:** an Extrovert chats roughly twice as often as a baseline pawn in a room with several ready partners; an Extrovert alone with an Introvert paces to the Introvert.
5. **Mood:** `set_opinion` a pair to +80, put them in one module, confirm the `&"company"` modifier appears and clears when one leaves; set to +10 and confirm **no** modifier at all (neutral band); confirm it never stacks after several room changes.
6. **Save/load:** mid-cooldown, with a populated ledger and a live `bad_chat` modifier — ledger, cooldown and recent log round-trip; the company modifier is absent from the file and back within one tick of loading. A pre-WI-48 save loads with empty ledgers and chats normally afterward.
7. **In-game:** the Social tab lists every other crew member, unmet ones read "Haven't spoken," the log fills as chats happen, and the tab is absent for a hauler robot. Robots never appear in anyone's list.
8. **Regression:** the recreation job is still the only way past the cap; Introvert solitude recharge still works; a lone pawn gains nothing from an empty room.

## Related

- [[WI-05_Needs_Completion]] — source of the passive drip this replaces, and of the `social_cap_percent` balance guard that carries over.
- [[WI-22_Pawn_Identity]] — traits, the social skill, and the stable `pawn_id` the ledger is keyed on.
- [[WI-29_Food_Quality]] — precedent for the finite `bad_chat` happiness modifier (finite modifiers persist, INF ones re-derive).
- [[WI-47_Modding_Support]] — the pawn-component save hooks this uses instead of editing `SaveManager`, plus trait scanning and pawn kinds, which is why mod traits and mod pawn kinds join the system for free.
- [[New Work for Phase 4]] — **Pawn Relationships** builds directly on this ledger; **Pawn Death** wants "pawns with relationships get a heavy mood penalty" and the `recent` log; the **UI Rework**'s Pawn Inspect "Relationships" pane supersedes §9's tab.
- [[01_Technical_Specification]] — §Pawns component list and the WI-22 identity paragraph will need the rewritten `SocializeComponent` once Phase 4 ordering is settled.
