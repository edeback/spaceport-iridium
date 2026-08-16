# WI-59 — Starting Flow

## Goal

Give the beginning of a run some personalization. Today New Game is one click on a difficulty card and the station that appears is entirely rolled: two anonymous crew whose names, traits and skills the player meets for the first time in the inspector, on a station with no name. After this item, New Game is a **setup screen** where the player names the station and picks their two starting crew out of a pool of candidates whose names, traits and skills are on the card — with difficulty still chosen there, exactly as it is now.

Three deliverables, in descending order of how much they change:

1. **Crew picking.** A pool of rolled candidates, each card showing name / traits / standout skills; the player selects two; any card can be re-rolled individually, any number of times.
2. **Station name.** Typed at setup, stored for the run, saved, shown as the **minimap's header** and pre-filled as the **default save slot name**.
3. **Difficulty**, unchanged in behaviour — it just moves onto the new screen instead of being its own step (WI-37).

Nothing about the *simulation* changes. Every piece of this already exists in the codebase in some form; the item is about putting the choice in the player's hands before the scene swap.

## Design

### 1 — One setup screen, not a wizard

New Game opens a **`NewGameSetup`** control (`ui/menus/new_game_setup.gd`), built the way `SettingsMenu` and `SaveLoadMenu` already are: constructed with `.new()` as a child of `MainMenu` in `_build_submenus()`, hidden by default, hides `_panel` while open, and reports back through a `closed` signal. Esc closes it by the same path those two use — do not invent a new one, and note that `UIMain`'s Esc ladder is an in-game thing that does not reach the menus.

The screen carries three regions and a footer:

```
  STATION NAME   [ LineEdit, max 24 chars ]

  SELECT YOUR CREW                             picked 1 / 2
  ┌────────────┐ ┌────────────┐ ┌────────────┐
  │ card  ⟳    │ │ card  ⟳    │ │ card  ⟳    │      3 x 2 grid
  └────────────┘ └────────────┘ └────────────┘
  ┌────────────┐ ┌────────────┐ ┌────────────┐
  └────────────┘ └────────────┘ └────────────┘

  DIFFICULTY     [ four selectable cards ]

  [ Back ]                        [ Begin ]
```

A wizard was the alternative and is rejected: these are three small independent decisions with no ordering between them, and a wizard would add back/forward state plus a "can I still change the difficulty?" question for nothing.

**This screen is deliberately outside the console design system.** `test_ui_theme.gd`'s `OVERRIDE_EXEMPT` list starts with `res://ui/menus/`, because the whole menu layer predates WI-49 — so hand-typed sizes and geometry are legal *here specifically*, and this is the one place in a UI work item where that is true. Follow the existing menus' idiom (`main_menu.gd` builds Controls in code and pulls its few colours from `UIPalette.TEXT_META` / `TEXT_SECONDARY` / `LIVE_BRIGHT`); keep doing exactly that. Do **not** import `ConsolePanel`/`ReadoutPanel` here, and leave a comment saying why, so a later reader doesn't "fix" the inconsistency and drag the exemption list along with it.

Two rules from the console are worth borrowing on their merits, not because they're enforced: **a disabled Begin names its blocker on the button itself** ("Pick 2 crew"), and the geometry numbers this screen types by hand are the only ones it may type.

### 2 — The difficulty cards move, and stop being buttons

`_build_difficulty_cards()` / `_difficulty_card()` / `_start_button()` / `_show_difficulty_picker()` / `_show_main_buttons()` and `_difficulty_container` all **move out of `main_menu.gd`** into the setup screen. `MainMenu` is left with its four buttons, and New Game just opens the setup screen.

The one behavioural change: each card today *is* a Start button (`_start_button` calls `start_new_game(id)` directly). It becomes a **selection** — click to select, one selected at a time, Normal preselected — with the single `Begin` in the footer doing what the per-card Start used to.

Everything else about the cards survives verbatim, including the two things WI-37 was careful about: the description and the `effect_summary()` line are still **derived from the `.tres`** so a balance tweak can't leave the card describing old numbers, and the **empty-`data/difficulty/` fallback** still has to work (today it drops in a bare "Start"; here it hides the difficulty region entirely and lets Begin proceed at the default, keeping the same `push_warning` naming `ContentPaths.roots_for(ContentPaths.DIFFICULTY)`).

### 3 — Candidates: reuse `HireCandidate` wholesale

The recruitment system (WI-22) already produces exactly the object this screen needs. `HireCandidate` carries name, tint, skills, trait ids, price and `pawn_id` (the WI-47 M10 pawn kind); it has `standout_skills()` and `total_skill_levels()`; it round-trips through `to_dict`/`from_dict`; and **`CrewManager.spawn_crew(at_module, candidate)` already takes one and applies it**. There is no new pawn-construction path in this item — the seam already exists, and starting crew currently goes through it with a candidate it rolled itself (`spawn_crew`'s `else` branch calls `_generate_candidate()` and applies it).

The problem is only *where* the roll can run. The setup screen lives in `main_menu.tscn`, which has **no managers at all** — `Global.crew_manager` is null there — and `_generate_candidate()` is an instance method reading six `@export`s off the `CrewManager` node.

**Extract the roll into a pure class:** `CandidateRoller` (`scripts/utility/candidate_roller.gd`, `RefCounted`) holding the roll knobs as plain typed fields with the current defaults, and owning `roll() -> HireCandidate`, `roll_skills()`, `roll_tint()` and the price computation. `CrewManager` keeps its `@export`s and copies them onto a roller, so scene-level tuning still wins in game; the setup screen constructs a bare `CandidateRoller` and gets the same distribution.

That duplicates the defaults in two places, which is normally the thing this project refuses. Two reasons it's the right call here, and one guard that makes it safe:

- **main.tscn overrides none of them.** The `CrewManager` node in `main.tscn` sets only `crew_pawn_scene` and `shuttle_scene`; every roll knob sits at its script default, so the two agree today by construction.
- The alternative — moving six exports into a `CrewRollData` resource both sides load — is a bigger, more invasive refactor of a manager this item otherwise barely touches, and it buys correctness that the guard below already buys.
- **The guard:** a GUT test asserts that a default `CandidateRoller`'s fields equal `CrewManager`'s exported defaults, field by field. If anyone ever tunes one side, the suite says so. Same spirit as `test_ui_theme`'s drift sweep.

`CandidateRoller` is pure and constructible without `Global`, which makes the roll bands, the "mostly low with 1–2 standouts" shape and the monotonic pricing directly testable for the first time — `CrewManager.compute_price` is already static and already tested, and this brings the rest of the roll with it.

Two static call chains the roller depends on all work fine from the menu scene, because they are statics over scanned content: `PawnData.roll_for_role(Role.CREW)`, `TraitData.roll_set()`, `SkillData.all()`, `NameGenerator.random_name()`. **Mod content is included for free** — `ModManager` is an autoload and mounts before the main menu precisely so the menu's static scans see modded content, so a modded pawn kind or trait can turn up in the starting pool with no extra wiring.

### 4 — Pool, selection, and re-rolling

- **Pool size 6**, laid out 3 × 2. Big enough that two picks is a real choice, small enough to read at a glance without scrolling.
- **Select exactly two.** Selected cards take a highlight border and a `1` / `2` pick badge; clicking a selected card deselects it; clicking a third while two are picked does nothing (rather than silently evicting a pick — the count readout and the disabled Begin already say what's wanted).
- **Every card has its own ⟳**, which replaces that one card with a fresh `roller.roll()`. Re-rolling a *selected* card keeps the slot selected and swaps its occupant — "roll this pick until I like it" is the whole point of the button, and dropping the selection on each press would make that miserable.
- **Unlimited and free.** The player can sit there rolling forever; that's what the goal asks for, and §5 explains why it doesn't hand out free elites.
- The card shows **name**, **traits** (`TraitData.display_name`, joined) and **standout skills** ("Construction 7, Mining 5", or "No standout skills"). That text already exists as `_skills_text` / `_traits_text` — private helpers on `ui_crew_recruitment.gd`, which this screen can't reach and must not copy. **Move them onto `HireCandidate`** as `skills_line()` / `traits_line()` and have the recruitment window call those instead. Same rule as `PawnStatus` and `StoresModel`: a candidate becomes a sentence in exactly one place, and now two surfaces render that sentence.

The rejected alternative was two fixed slots with a reroll each and no pool — fewer moving parts, but "select from a pool" is the ask, and with six visible cards the reroll button reads as *refine my options* instead of *the only way to see anything else*.

### 5 — Better crew cost more, forever, and the card says so

`HireCandidate.apply_to()` sets `pawn.hire_price = price`, and `EconomyManager` computes the per-cycle wage as `wage_for(pawn.hire_price, wage_fraction)`. So the rolled price of a starting crew member is **already** their salary for the rest of the game — this is live today, it's just invisible because the roll is invisible.

Keep that coupling, and **surface it**: each card shows the derived per-cycle wage. It is the only thing standing between "unlimited free re-rolls" and "everyone starts with two specialists at no cost", and it turns the pool from a slot machine into a trade-off — a high-skill start is a permanently higher payroll on a station that has not earned a credit yet.

No credits are charged at setup (there is no station and no treasury yet), and `hire_cost` stays out of the setup screen's vocabulary entirely — the word "hire" doesn't belong on a screen where the player is assembling a founding crew.

To compute the wage without an `EconomyManager` node: give it `const DEFAULT_WAGE_FRACTION: float = 0.05` and change the export to `@export var wage_fraction: float = DEFAULT_WAGE_FRACTION`. The menu reads the const and calls the existing `static func wage_for`. `main.tscn` doesn't override `wage_fraction` either, so the const is the truth; the comment on it should say that out loud. Apply the same one-line treatment to `CrewManager.starting_crew` (`const STARTING_CREW: int = 2`) so the picker requires however many the manager will spawn, rather than a hardcoded 2 of its own.

### 6 — Staging, and the shape WI-37 already established

Both new values ride into the game the way difficulty does — staged on `Global` before `change_scene_to_file`, because managers read them from `_ready` onward and there is no manager to hang them on before the scene exists:

```gdscript
var station_name: String = ""
var staged_crew: Array[HireCandidate] = []
```

with `set_station_name()` / `station_display_name()` (falling back to `DEFAULT_STATION_NAME`), and **`take_staged_crew()` which returns the array and clears it**. Consume-once matters: `CrewManager` must not be able to re-apply a stale founding roster if anything ever calls the spawn path twice.

`CrewManager._spawn_starting_crew(home)` becomes: spawn one pawn per staged candidate, then **top up with fresh rolls until `starting_crew` is reached**. That top-up is not defensive padding — it is the path that keeps *playing `main.tscn` directly from the editor* working, which CLAUDE.md requires and which stages nothing at all. An empty staged array reproduces today's behaviour exactly.

Everything else in `_on_module_added_for_start` is untouched, including its `SaveManager.is_loading() or has_pending_load()` bail — a loaded game restores crew from the save's pawn section and must never see the staged list.

**Clearing.** Staged crew is cleared in the same two places `clear_difficulty()` already is, for the same reasons: `MainMenu._ready()` (returning to the menu from a run must not leave a founding roster behind for the next New Game) and `SaveManager.stage_load()` (loading a save after abandoning a half-configured New Game must not inherit the menu's leftovers — WI-37's exact edge case, one line lower).

### 7 — Persisting the station name

The station name is a single value chosen before the run and never mutated by any system — which is precisely the shape `difficulty` has, so it takes the same route rather than a new one:

- **Envelope field.** `_collect_sections()` writes `"station": Global.station_name` alongside `"difficulty"`, with the same reasoning in the comment: not a section, because there is no system holding the state to ask.
- **`_apply_sections()` must add `"station"` to its `claimed` dict.** This is the trap. That dict seeds as `{"difficulty": true}`, and anything unclaimed is filed into `_unclaimed_sections` as *a disabled mod's data* and written back out untouched on the next save. An unclaimed `"station"` would round-trip forever while the game ran nameless, and nothing would error.
- **`stage_load()` stages it** next to `Global.set_difficulty(read_difficulty(data))`, via a `read_station_name(data)` static that mirrors `read_difficulty`: authoritative sections field first, `meta` second, `""` last.
- **`_get_meta()` echoes it** so the slot browser can show it without parsing sections.
- **No `SAVE_VERSION` bump and no migration.** A pre-WI-59 save has no `"station"` key, reads as `""`, and falls back to the default header — additively backward-compatible, the same trade WI-37 made.

### 8 — Where the name shows

**The minimap header.** `ui_main._setup_right_column()` sets `_map_readout.label = Global.station_display_name()` right after instantiating the scene, next to where it already sets `content_height` and adds the hotkey hint. `ReadoutPanel.label` has a setter that re-applies immediately, so this is one line — and `minimap.tscn`'s authored `label = "Station Map"` stays as the fallback for a nameless save.

Two facts about that header, both of which shape the input field:

- **`_apply_label()` calls `to_upper()`.** "Iridium Reach" renders as `IRIDIUM REACH`. That's the console's idiom and is fine, but the player types mixed case and should not be surprised — worth a glance at the setup screen's field styling.
- **The header `Label` has no autowrap and no overrun behaviour**, and a `ReadoutPanel` is an anchored `Control` that clamps its size *up* to its combined minimum. So a long name doesn't ellipsize — it **widens the map readout out of the right column**. Hence the 24-character cap on the input, which is the fix rather than adding an overrun mode: WI-53 established that a `Label` with an overrun behaviour reports a minimum width of ~1 and *collapses* instead of capping. Verify by screenshot at the maximum length, not by reasoning about it.

**The default save slot name.** `SaveLoadMenu.open()` in `Mode.SAVE` pre-fills `_new_slot_edit.text` with `SaveManager.sanitize_slot_name(Global.station_display_name())` and selects all, so the existing `grab_focus()` means typing replaces it and Enter accepts it. The rest of the flow is already correct without changes: `sanitize_slot_name` folds anything that could escape `user://saves/`, an empty result is already rejected by `_on_new_slot_pressed`, and a name colliding with an existing slot already routes through the "Overwrite '%s'?" confirm.

**Not in scope:** a random station-name suggester. `DEFAULT_STATION_NAME = "Spaceport Iridium"` as the field's placeholder and empty-input fallback is thematic, costs nothing, and removes the empty-name case entirely — so Begin's only gate is the crew count.

## Files to touch

**New**
- `ui/menus/new_game_setup.gd` — the setup screen (`class_name NewGameSetup`)
- `scripts/utility/candidate_roller.gd` — `class_name CandidateRoller`, the extracted pure roll
- `tests/unit/test_candidate_roller.gd` — roll bands, pricing monotonicity, the defaults drift guard
- `tests/unit/test_station_name.gd` — sanitize/fallback/`read_station_name` precedence (or fold into `test_save_slots.gd`)

**Changed**
- `ui/menus/main_menu.gd` — difficulty cards move out; New Game opens the setup screen; clear staged crew in `_ready()`
- `ui/menus/save_load_menu.gd` — pre-fill the new-slot field in SAVE mode
- `pawns/hire_candidate.gd` — `skills_line()` / `traits_line()` move in from the recruitment window
- `ui/windows/ui_crew_recruitment.gd` — call those instead of its own `_skills_text` / `_traits_text`
- `scripts/managers/global.gd` — `station_name`, `staged_crew`, accessors, `take_staged_crew()`, `DEFAULT_STATION_NAME`
- `scripts/managers/crew_manager.gd` — delegate the roll to `CandidateRoller`; consume staged crew in `_spawn_starting_crew`; `const STARTING_CREW`
- `scripts/managers/economy_manager.gd` — `const DEFAULT_WAGE_FRACTION` feeding the export
- `scripts/managers/save_manager.gd` — `"station"` in `_collect_sections`, in `_apply_sections`'s `claimed`, in `_get_meta`; `read_station_name`; stage + clear staged crew in `stage_load`
- `ui/ui_main.gd` — set the map readout's label from the station name
- `tests/unit/test_ui_crew.gd` (or wherever the candidate tests sit) — the moved sentence helpers

Remember `filesystem_manage(op="scan")` after the two new `class_name` files, or `CandidateRoller` won't resolve.

## Implementation order

1. **`CandidateRoller` + the drift guard.** Pure, testable, and nothing depends on the UI yet — `CrewManager` delegates to it and behaves identically. Green GUT here means the rest of the item can't change the roll by accident.
2. **`Global` staging + `CrewManager` consumption.** Still no UI: drive it from a probe (or the cheat console) by staging two hand-built `HireCandidate`s and confirming the starting crew are those two. The top-up path is verified by staging one, and by staging none.
3. **Station name end-to-end** — `Global`, save envelope, `stage_load`, meta, the minimap label, the save-slot pre-fill. Fully verifiable before any setup screen exists, by staging a name from a probe.
4. **The setup screen**, difficulty cards moved in first (so New Game reaches the game again as early as possible), then the crew pool, then the name field.
5. **Screenshots and the probe checklist.**

## Edge cases

- **Booting `main.tscn` directly from the editor** stages nothing: two rolled crew, `DEFAULT_STATION_NAME` on the map. Today's behaviour, and it must stay that way.
- **New Game → Back → Load a save.** The staged roster and name must be gone. Cleared in `MainMenu._ready()` and again in `stage_load` — belt and braces on purpose, because these two clears cover different entries into the same failure.
- **Load a save → quit to menu → New Game.** The reverse leak: `stage_load` staged the *save's* name onto `Global`, and `MainMenu._ready()` is what drops it.
- **Pre-WI-59 save** loads with no `"station"` key and shows the default map header. Confirm the key is not silently filed into `_unclaimed_sections` (§7's trap) — check by saving that loaded game and reading the JSON.
- **Empty `data/difficulty/`** — the WI-37 fallback still has to leave a workable Begin.
- **Empty `data/pawns/`, or every kind at `weight` 0.** `roll_for_role` returns null and `spawn_crew` falls through to `crew_pawn_scene`; the *card* must still render (name/traits/skills come from generators that don't depend on a kind). A pool of cards that can't name their pawn kind is fine; a pool of blank cards is not.
- **A modded pawn kind is uninstalled between setup and the scene swap.** Effectively impossible in one click, but `spawn_crew` already handles the unknown-`pawn_id` case with a `push_warning` and the fallback scene — the same path a queued hire uses. Nothing new.
- **The maximum-length station name** in the map header (§8) — the one failure a screenshot has to rule out.
- **A station name of only spaces/underscores** sanitizes to `""` for the slot field; `_on_new_slot_pressed` already rejects empty, so the player types their own. The *header* still shows what they typed, which is correct — the sanitizer exists for filenames, not for display.
- **Re-rolling the same card many times** must not leak: each roll replaces the card's `HireCandidate` and the old one is refcounted away. Watch the selection bookkeeping — the pick badge indexes the *slot*, not the candidate object.

## Verification

1. **GUT.** `CandidateRoller` roll bands (every skill within 0..`base_skill_max` except 1–2 standouts in the standout band), price monotonic in total skill levels, trait and pawn-kind price multipliers folded in; the defaults drift guard against `CrewManager`'s exports; `read_station_name` precedence (section → meta → `""`); `sanitize_slot_name` over a station name with punctuation; `skills_line`/`traits_line` including the "No standout skills" case. All pure — construct directly, never touch `Global`.
2. **Headless probe** (the pattern WI-30 onward has relied on, and the fallback whenever MCP is down): stage two known candidates + a known station name → boot `main.tscn` → assert the two starting pawns carry exactly those names, traits, skills and `hire_price`; assert `Global.station_name`; save; assert `"station"` in the envelope and **not** in `_unclaimed_sections`; reload; assert the name and the crew survive. Then the three degenerate stagings: none, one, and (a loaded save) — each landing on the right path.
3. **Screenshots, driven into the state under test** — this is a UI item, and every panel item in the UI rework program found defects a headless probe could not see:
   - the setup screen with 0 / 1 / 2 crew selected (Begin's disabled label naming its blocker),
   - a card mid-re-roll and a *selected* card after a re-roll (selection survived),
   - the map header at a 24-character station name, at the default, and on a pre-WI-59 save,
   - the save browser opening with the slot name pre-filled.
4. **A full round trip by hand:** name a station, pick two crew whose traits and skills you noted, Begin, find both of them in the crew roster with those exact traits and skills, check the payroll line matches the wages the cards quoted, save (accepting the pre-filled slot name), quit to menu, load, and confirm the map still says the right thing.
