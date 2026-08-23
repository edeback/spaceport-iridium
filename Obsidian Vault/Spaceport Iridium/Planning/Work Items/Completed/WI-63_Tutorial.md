# WI-63 — Tutorial & Onboarding

> **STATUS: COMPLETE (2026-08-22).** Shipped as designed apart from the eight deviations below. **Forty-eight files: 30 new, 18 changed** (excluding `.uid`/`.import` sidecars), nothing deleted. **1381 GUT tests, all green** (from 1329 — four new suites, +52 tests), a **72-check headless probe** green on repeated runs, and **eight screenshots** each driven into the state under test. Save is backward-compatible and `SAVE_VERSION` did not move: a pre-WI-63 save has no `tutorial` section, and the absence means the tutorial is complete.
>
> **Deviations from the design below:**
> 1. **`ui_aide` was renamed to `mode_aide`.** §8 kept the WI-50 name and said F1 would start working for free. It would have — but `test_mode_manager.gd`'s conflict scan skips every `ui_`-prefixed action as a Godot built-in, so once AIDE became rebindable, a player moving another mode onto F1 would have collided with it and been told nothing. The action also moved from `NON_REMAPPABLE_ACTIONS` into `REMAPPABLE_ACTIONS`, which is why `test_keybinds.gd`'s "three invisible bindings" test is now about two. Still F1.
> 2. **`TutorialHintData` gained an eighth field, `has_subject`, that the design did not anticipate.** Without it there is no way to tell a dialogue asking for a subject its trigger never provides — an authoring mistake, which must be loud — from a subject that was alive when the hint fired and has since been freed, which is ordinary. It also earns its keep in `fire()`: **a subject-carrying hint with no subject does not fire and stays armed**, rather than spending itself to say "that has not eaten".
> 3. **`bind_sources()` had to become re-callable, and runs on every mode change.** §2 has the bridge binding its four signal sources once, when the HUD is up. [BuildMenu] is a **lazy factory** (WI-50) and does not exist at that point, so `flyout_changed` was never connected and the onboarding's "choose the Crew category" gate could never resolve — the player clicks Crew, the conversation does not move, and the simulation stays held with no way forward but the skip control. This is the worst defect in the item and **only a screenshot found it**.
> 4. **The coach mark takes itself down when nothing is talking** ([TutorialCoach]'s fifth rule, not in the design). The manager clears the mark on the two finish callbacks it owns, but a game over, a quit to menu, or any other caller of `DialogueRunner.abandon()` bypasses both and would leave a pulsing ring on screen with nothing behind it. Asking the runner every frame makes that impossible rather than merely unlikely — the same argument rule 3 already makes about the target.
> 5. **The plate is a `PanelContainer`, not a `Panel`.** A bare `Panel` reports a zero minimum height, so the frame drew nothing and the text spilled over the console strip. The mark was otherwise entirely correct, which is why nothing headless noticed.
> 6. **The unresolved / `screen` plate position moved from "above the console" to "the top of the play area".** The obvious slot is exactly where the balloon lives, and the balloon is a `CanvasLayer` — it draws over every ordinary child of [UIMain], including this. A plate there is invisible whenever anybody is talking, which for a `screen` mark is always. The comet advisory uses that target.
> 7. **`ModeManager` gained `console_order()`** beside `ORDER` and `TRAILING`, so the console and the test ask one question rather than two that can disagree. §8 described the two lists and left the join implicit.
> 8. **`UIMetrics.PANEL_AIDE_WIDTH` aliases `PANEL_COMMS_WIDTH`** rather than repeating 620. Both are lists of things somebody said; two reading surfaces of different widths in one console would read as an accident.
>
> **Two input defects found in play, after the item was called done (2026-08-23).** Both are in WI-62 rule 2 — "the balloon does not swallow `ui_cancel`" — which turned out to be half-kept in two different ways, and the tutorial is what made both matter.
> 1. **The balloon swallowed everything while it was hidden.** `DialogueBalloon` is a `CanvasLayer`; `balloon.hide()` hides the `Control` inside it, not the node running `_unhandled_input`. So an invisible balloon went on marking every unhandled event handled — from `_ready` until the first line renders, for 0.1s after every non-inline mutation, and for the **whole duration of a tutorial gate**. The placement step therefore could not be completed: SAI asked the player to click a cell, and the click was consumed before it reached [UIInGame]. Fixed by guarding the handler on `balloon.visible`, which is the honest rule — a modal blocks input because it is *in front of the player*, and when it is not, it is not a modal. This was reported from play; the 72-check probe and all nine screenshots missed it, because nothing before this item ever asked the player to click the world during a conversation.
> 2. **The balloon ate Esc on the GUI path.** Found while verifying the first fix. `_unhandled_input` correctly exempts `ui_cancel`, but the balloon holds focus while waiting, so Esc arrives as **GUI** input first — and `_on_balloon_gui_input` called `set_input_as_handled()` unconditionally before deciding what the event was. The pause menu was therefore unreachable over *any* conversation, which predates this item but which WI-63 made far worse by holding the simulation for the whole tutorial. §"Edge cases" below asserts this guarantee holds; it now does. Skipping the typewriter with Esc is the addon's own `skip_action` and deliberately stays.
>
> Verified by a **10-check input probe** (a click reaches the game while the balloon is hidden and is still swallowed while it is visible; Esc reaches the pause menu through a visible balloon, with a baseline proving the probe can press Esc at all) and a **10-check windowed placement probe** that walks the onboarding to the placement gate, warps the real cursor to a real cell, pushes a real click, and asserts the Mess Hall lands and the gate closes. A third thing fell out of that pass: a probe run made Godot rewrite `project.godot` and **resurrect the renamed `ui_aide` action** beside `mode_aide`, putting two actions on F1 — `test_keybinds.gd`'s classification sweep caught it, which is exactly what WI-58 added it for.
>
> **A third defect found in play (2026-08-23), and a design bug behind it.** Demolishing a module the unreachable advisory had just fired on wedged `TutorialManager._prune` with *"Trying to assign invalid previously freed instance"*, once per `slow_tick`, forever.
> - **Cause:** the grace clocks were `Dictionary[ModuleBase, float]`. A typed dictionary keyed on a node **cannot be iterated at all** once one of its keys has been freed — `keys()` hands each entry to a typed loop variable, and the assignment errors *before* the `is_instance_valid` guard inside the loop can run. That guard was unreachable code. Clocks are now keyed by `get_instance_id()`, and pruning is by membership in the set of modules the tick actually walked: exact (a module deconstructed out of the group is as gone as a freed one), and it never looks at a dangling reference.
> - **And the advisory was blaming the wrong module.** Chasing the crash surfaced it: placing anything puts a **corridor segment on the same cell**, and removing anything backfills **truss**. Both are in `Groups.MODULE`, both read as cut off exactly when the module they serve does, and the scan takes the first match — so a player who built a detached Mess Hall was told their *Corridor* was unreachable and then advised to build a corridor. `_is_worth_naming()` now restricts the advisory to MODULE-layer modules that are not the truss backfill (compared against `WorldManager.replacement_module`, so a mod that swaps it is covered). The cost is that a lone detached corridor says nothing, which is the right trade: this advisory is for "you built a room and forgot to connect it".
>
> Verified by an **11-check demolish probe** that fires the advisory on a detached module, demolishes it mid-conversation, keeps ticking, and asserts zero freed-instance errors, that the clock was pruned, that a later module still trips the advisory, and that a freed subject degrades rather than crashing. Two new GUT tests pin the data the filter depends on — corridors staying off the MODULE layer, and truss staying on it — because both are numbers in a `.tres` that nothing else would complain about. **1383 GUT green.**
>
> **A tooling note worth keeping.** Godot's `ProjectSettings` rewrites the whole of `project.godot` from its in-memory cache on save, so text edits made while a run has the project open get clobbered — twice during this work it **resurrected a temporary probe autoload and the renamed `ui_aide` action**, the latter putting two actions on F1. `test_keybinds.gd`'s classification sweep caught it both times. Re-check `project.godot` after any run that registered a temporary autoload.
>
> **What the screenshots caught that the probe could not:** deviations 3, 5 and 6 — a gate that could never close, a frame that never drew, and a plate hidden behind the balloon. Every one of them left the headless checks green.
>
> **What the probe caught that a screenshot could not:** deviation 4, and the abandon latch — a second gate re-suspending behind an abandoned first one, which would have made "Skip the tutorial" stall on the next step with the sim held.
>
> **`UIPalette` is untouched.** No new colour, and the amber budget is unspent: the ring is `LIVE` with a real-time pulse, and AIDE carries no console badge. `test_pause_holds.gd` is also unchanged, as §4 promised — the tutorial rides the balloon's existing `&"dialogue"` hold and adds no holder.
>
> **Known rough edge, accepted.** A mark on a console vitals chip puts its plate over the right column, because on a 1080p screen there is nowhere else within reach of the target. The plate never covers the *thing it points at*, which is the rule that matters; moving it far enough to clear every panel would move it away from what it is explaining.
>
> [[01_Technical_Specification]], [[02_Roadmap]] and [[04_UI_Rework_Program]] are updated. The program doc's decision 7 (AIDE as a deferred stub) is now closed.

## Goal

The game has thirty-odd interlocking systems and tells the player about none of them. There is a short list of things you *must* do in the first two cycles — build somewhere to eat, connect it, power it, keep the beds ahead of the crew count — and the current game teaches all of them by killing you. By the time the trial-and-error has taught you the rule, the run that taught it is unrecoverable.

[[WI-62_Dialogue]] built the machinery this needs and deliberately stopped one step short: SAI ships as a `SpeakerData` with a real portrait and nothing to say, and `StoryFlags.DECLARED` already carries a `sai_introduced` flag that nothing sets. This item gives SAI a script.

Five deliverables:

1. **An onboarding conversation** that runs on the first frame of a new game, holds the sim while it runs, and walks the player through placing their first module — with the interface itself highlighted, step by step, waiting on the player rather than on a click-through.
2. **A "Skip Onboarding" option** on the New Game screen, and a way out of the tutorial from inside it.
3. **Eight one-shot contextual hints**, each armed against a real failure the station can walk into, each fired at most once per run.
4. **A surface that can point at a piece of the interface** — the thing the console UI has never had, and the reason the AIDE button has been a disabled stub since WI-50.
5. **AIDE goes live**, so every advisory SAI has given is re-readable and the introduction is replayable. Shipping a tutorial while the console's help button stays greyed out with *"Assistance is not available yet"* is not an option.

The load-bearing decision is §2: **the tutorial talks to the interface through a third dialogue alias**, and everything else follows from that.

## Design

### 1 — A tutorial beat is two files, exactly as an event is

WI-62's shape is reused wholesale and for the same reasons. A **hint** is:

- a `.tres` under `data/tutorial/` that decides *when* it happens — its trigger, its filter, its Comms subject;
- a `.dialogue` file under `data/dialogue/tutorial/` that decides what is said and what is pointed at.

The **onboarding** is a single `.dialogue` file with no `.tres` at all, because there is exactly one of it and its trigger ("a new game started") is not a thing anyone will ever author a second instance of.

**Why a `TutorialHintData` rather than reusing `EventData`.** They are close: both are "a condition plus a conversation", and `insolvency_warning` is already a `weight = 0` event fired from code by `EconomyManager`, so the precedent for a non-random event exists. But four of `EventData`'s nine fields — `weight`, `min_cycle`, `cooldown_cycles`, `conditions` — are meaningless for a hint, and a resource where half the fields must be left at zero is a resource that will eventually be filled in wrong. Worse, a hint living under `ContentPaths.EVENTS` would join the weighted roll's candidate list and `test_event_content.gd`'s reachability sweep, both of which would then need a special case. A separate kind costs one `ContentPaths` entry and keeps two scans honest.

```
TutorialHintData:
    id: StringName             # &"module_unpowered"
    trigger: StringName        # a declared TutorialTriggers id
    trigger_filter: StringName # the one discriminator that trigger takes, or &""
    dialogue: DialogueResource
    cue: String
    title: String              # the Comms subject
    body: String               # the Comms row
```

**A hint always posts a transmission.** This is not a flag. A hint fires once per run and then never again; a player who was mid-placement when it appeared and clicked through it has permanently lost the advice unless it is written down somewhere. That is the exact case [[WI-57_Panel_Comms_And_Retirement]] built the transmission log for — *"an alert is 'look at this now'; a transmission is 'this arrived, read it later'"* — and a hint is both. `TutorialManager` posts it from `title`/`body` the same way `EventManager.fire_event` does, so the row looks like every other row in the feed.

Note the asymmetry with WI-62, which argued the opposite about `is_silent` ("whether an event interrupts the player is a property of what its author wrote"). It still is: a hint interrupts because its author wrote lines. What is *not* left to the author is whether the advice survives being dismissed, because there is no hint for which the answer is no.

### 2 — The third alias: `guide`

WI-62 §3: *"A `.dialogue` file may reach exactly two things: `station` for what a conversation does to the sim, `story` for what it remembers."* This item adds a third, `guide` ([TutorialBridge], `scripts/tutorial/tutorial_bridge.gd`), and the reason it is a third rather than more verbs on `station` is that it does a categorically different thing: **it is the only alias that touches the interface, and the only one that can block a conversation.**

`station.credits(-300)` returns immediately and changes the sim. `guide.await_mode("build")` changes nothing and does not return until the player opens the Build panel. Folding a verb that suspends the conversation into the alias whose whole contract is "what this does to the simulation" would make the bridge's one honest sentence stop being true.

| Verb | Kind | What it does |
|---|---|---|
| `point(target, caption)` | act | Raises the coach mark (§3) on `target`, captioned `caption`. Replaces any mark already up |
| `point_at_subject(caption)` | act | The same, on the hint's subject — selects it through `InspectorPanel.select()` and marks its world position |
| `clear_point()` | act | Takes the mark down |
| `subject_name()` | query | The pawn or module this hint is about, for `{{ }}` interpolation |
| `await_mode(mode_id)` | **wait** | Until that console mode's panel is open |
| `await_category(category_id)` | **wait** | Until the Build rail has that category showing in its flyout |
| `await_module_picked(module_id)` | **wait** | Until that module is the one on the cursor |
| `await_module_placed(module_id)` | **wait** | Until a module of that `ModuleData` exists on the grid |
| `abandon()` | act | Ends the tutorial now. What the skip control calls |

**Blocking works because the addon awaits mutations.** `dialogue_manager.gd:1928` is `return await thing.callv(method, args)`, and `_mutate` awaits `_resolve` for any mutation not marked non-blocking. A bridge verb that is a GDScript coroutine therefore suspends the conversation until it returns. This is load-bearing and non-obvious, and it is why the design does not need a step-machine of its own: **the onboarding script *is* the state machine**, written in the order the player experiences it, in a file an author can read.

**Every wait must be satisfiable and abandonable.** Two rules, both of which are the difference between a tutorial and a soft-lock:

- A wait whose condition is **already true** returns immediately without arming anything. A player who opened Build before SAI asked must not be stuck waiting for them to open it again.
- After `abandon()`, **every subsequent wait returns immediately**. Ending the conversation is what actually happens (§6), but the flag has to exist regardless, because a gate that is already suspended when abandon lands has to come back, and the gate after it must not re-suspend.

**The access filter gains one line.** `DialogueRunner._validate_access` allows `DialogueBridge`, `StoryState` and `DialogueBalloon`; it gains `TutorialBridge`. Nothing else about WI-62 §3 changes — a `.dialogue` file still cannot reach `Global`.

### 3 — The coach mark: a fourth kind of surface, declared as one

The console UI has three kinds of surface: `ConsolePanel` (a mode), `ReadoutPanel` (the right column), and the modal overlay (pause menu, game-over, balloon). A coach mark is none of them. It is an **overlay that points at existing chrome**, it owns no content of its own, and there is at most one in existence at a time. [[04_UI_Rework_Program]] requires a new surface to say which of the existing kinds it is; the honest answer here is "a fourth", and the program doc gains a paragraph saying so rather than the surface pretending to be a readout.

`TutorialCoach` (`ui/tutorial/tutorial_coach.tscn`), mounted under `UIMain` above the panel layer and below the modals — the slot where it can draw over an open Build panel but never over the balloon or the pause menu. It is three things:

- **A ring** around the target's rect, drawn as a 2px border with a **real-time alpha pulse**.
- **A plate** beside the ring carrying SAI's portrait at readout scale, the speaker name, and the caption. It is the reason the sim's "In conversation" hold sentence stays true while the balloon is hidden (§4).
- **A skip control**, `Skip the tutorial`, wearing the outline-only destructive treatment `ActionButton` already has. Present on every mark, always, including the hints'.

Four rules it carries:

1. **The ring is `LIVE`, never `ATTENTION`.** Invariant 5 is that amber is a budget spent on breach, falling vital, unread transmission and ARC. A tutorial pointer is not an emergency; it is *"this one, right now"*, which is what cyan already means everywhere in the console. The pulse — which nothing else in the HUD does — is what makes it unmistakable without spending the budget.
2. **The pulse is real-time.** `Global.time_manager.animation_speed()` returns 0 while paused, and the tutorial runs entirely while the sim is held. A pulse driven off sim time would sit frozen for the whole onboarding. The mark must not join the `sim_animation` group.
3. **It re-resolves its target every frame.** A panel can close under it — the player presses Esc, an alert steals focus. When the target cannot be found the ring hides and *the plate stays*, so the instruction survives and the player can act on it. A mark that vanished with its target would leave a paused game with nothing on screen explaining why.
4. **It names no colour, size or type variation.** `UIPalette` / `UIMetrics` / `UIType` as everywhere else. `tutorial_coach.tscn` is swept by `test_ui_theme.gd` and **must not** be added to `OVERRIDE_EXEMPT`.

**Targets are a parsed grammar, not a node path.** `TutorialTarget` (pure, `scripts/tutorial/tutorial_target.gd`) parses `"<kind>:<id>"`:

| Target | Resolves to |
|---|---|
| `console:<mode>` | `ConsoleBar.mode_button(mode)` |
| `category:<id>` | the Build rail's row for that category |
| `module:<module_data_id>` | the Build flyout's row for that module |
| `vital:<id>` | a pinned chip on the vitals strip |
| `subject` | the world position of the pawn or module this hint is about |
| `screen` | no ring; the plate alone, centred above the console |

Parsing is pure and tested; resolution is live and screenshot-verified. `BuildMenu` gains `rail_row(category)` and `list_row(module_id)`, and `VitalsStrip` gains `chip(id)` — three accessors, no behaviour. The `vital:` kind is not speculative: the sleep hint's whole advice is *"the number of crew against available beds is in the bottom console"*, and pointing at the chip is the difference between that sentence being instruction and being trivia.

### 4 — The onboarding script

`data/dialogue/tutorial/onboarding.dialogue`, one file, run by `TutorialManager` on `game_bootstrapped` when `not SaveManager.has_pending_load()` and the player did not skip. Its shape:

```
~ intro

sai: Station Administrator. I am SAI — Subprocess Artificial Intelligence, assigned to
     this posting by the Astral Resource Corporation.
sai: ARC has towed you a station core and a debt. What you do with the first determines
     how you handle the second.
sai: Your remit is a profitable station. Mine is making sure you still have a crew when
     you get there.
sai: Four things keep a human alive and working out here — air, food, a bed, and
     something to do that is not work. None of them are here yet. All of them are yours
     to build. And every module you build draws power.
sai: You are authorised for a limited catalogue. Prove the station is established — build
     it out, ship ARC its ore — and they will licence you more.
$> story.set_flag("sai_introduced", true)
=> first_task

~ first_task

sai: Start with somewhere to eat. Follow along.
$> guide.point("console:build", "Open the Build panel")
$> guide.await_mode("build")

sai: Modules are filed by what they are for.
$> guide.point("category:crew", "Choose the Crew category")
$> guide.await_category("crew")

$> guide.point("module:mess_hall_mdata", "Take the Mess Hall")
$> guide.await_module_picked("mess_hall_mdata")

sai: Put it against one side of the existing station. It does not have to be pretty.
$> guide.point("screen", "Click a cell alongside the station to place it")
$> guide.await_module_placed("mess_hall_mdata")
$> guide.clear_point()

sai: What you placed is a blueprint, not a building. Most modules are assembled on site
     out of materials, and your crew will start on it without being told.
sai: The Core catalogue is the exception — corridors, stairs, turbolifts arrive
     prefabricated and land finished. You will want them: a crew member who cannot walk
     to that door will never eat at that table.
sai: The rest is yours. Air, food, beds, somewhere to unwind — build them before you
     need them, because by the time you need one it is already too late to build it.
=> END
```

**Why the gates are standalone `$>` mutations and not inline `[do …]`.** The inline form is tempting: an inline mutation is awaited by `dialogue_label._mutate_inline_mutations`, does **not** trigger the balloon's hide-on-mutation path, and would leave the instruction on screen in the balloon while the player acts. It is also a trap. `DialogueLabel.skip_typing()` sets `_is_skipping_mutations` and then runs every remaining inline mutation **without awaiting it** — and clicking the balloon is exactly how a player skips typing. One impatient click and every gate in the file fires and returns instantly, running the whole tutorial to its end in a frame. The standalone form has no such path.

The consequence of the standalone form is that `DialogueBalloon._on_mutated` hides the balloon 0.1s into each gate. That is why the coach mark carries SAI's face and the caption: **the balloon steps aside and the instruction moves next to the thing the player has to click**, which is where it belonged anyway.

**The "cannot be unpaused until the tutorial completes" requirement is already built.** The balloon takes `&"dialogue"` on its first rendered line and releases it in `finish()` only — not when it hides. So the sim stays held across every gate, `UITimeScaleSelect` renders *"In conversation"* / *"Someone is waiting for an answer"*, and the resume button bounces with a sentence. **No new pause hold, and no new row in the two hold tables.** `test_pause_holds.gd` is untouched by this item, which is the correct outcome and worth asserting so nobody adds one.

**Placement works while the sim is held.** Placing a module is a UI action; `purchase_and_add_module` withdraws immediately and `ModuleBase._ready` emits `module_added`, which is the gate's condition. Construction is a job and does not start until the hold lifts — which is precisely the sequence SAI describes, and means the player watches their crew walk over to it the instant the tutorial ends.

**One thing to notice:** the balloon blocks `_unhandled_input`, so while it is up the `mode_build` hotkey is swallowed and the player must click the console button. During a gate the balloon is hidden and the hotkey works again. Both routes satisfy `await_mode`, so the gate does not care — but the caption should say "open" rather than "click", because either is fine.

### 5 — The eight hints and six triggers

**A trigger is declared or it does not exist.** `TutorialTriggers.DECLARED`, a const table with a one-line comment each — the same argument as `Groups` (WI-41), `UIType` (WI-49) and `StoryFlags` (WI-62). A `.tres` naming an undeclared trigger errors at load rather than becoming a hint that never fires.

| Trigger | Filter | Source | Grace |
|---|---|---|---|
| `module_unreachable` | — | `slow_tick` scan, `PathManager.is_reachable` from the station core | 2 sim-hours |
| `module_unpowered` | — | `PowerConsumptionComponent.powered_changed(false)` | 2 sim-hours |
| `trader_arrived` | — | `SignalBus.trader_arrived` | none |
| `space_body_arrived` | body profile id | **new** `SignalBus.space_body_arrived(profile)` | none |
| `crew_resigning` | — | `SignalBus.crew_resigning` | none |
| `need_critical` | need name | `SignalBus.pawn_critical_need` | none |

Six triggers, eight hints — `need_critical` carries three (`hunger`, `sleep`, `recreation`) and `space_body_arrived` filters for `comet`. That is what `trigger_filter` is for and why it is one field rather than three near-identical watchers. It means whatever its trigger says it means, and the content sweep checks that a filter is only present where its trigger takes one.

**The one new signal.** `AsteroidManager._announce_arrival` currently raises a LOW alert and nothing else — there is no signal for a body arriving. It gains `SignalBus.space_body_arrived(profile: SpaceBodyProfile)`, emitted beside the alert. The hint filters on the profile id, so a mod's own body kind can have its own hint with no core edit.

**Two triggers need a grace window, and it is the whole of their correctness.**

- **Unpowered.** `powered_changed(false)` fires on every brownout — a passing solar dip, a reactor mid-repair. Firing *"your module has no power"* at a station that browns out for four seconds a cycle is noise, and firing it at a player who just pressed Force Shutdown is worse than noise, it is wrong. The watcher requires the module to be continuously unpowered for two sim-hours **and** `force_off` to be false.
- **Unreachable.** A blueprint placed a second before the corridor that connects it is not a mistake, it is a build order. Two sim-hours of continuous unreachability is a forgotten corridor.

The reachability anchor is the starting module — the one module the station is guaranteed to have and the one crew actually live in. If it has been destroyed, the check is skipped rather than guessed at; a station that has lost its core has larger problems than a tutorial hint.

**A fired hint costs nothing.** The watcher for a hint that has fired is **disconnected**, not merely skipped, and the `slow_tick` scanners return immediately once their hint is spent. By the time a run is a few cycles old the whole subsystem is inert. This is a rule, not an optimisation: a tutorial that keeps scanning the station forever to teach a lesson it already taught is a tax on every save that ever ran it.

**A hint highlights its subject by selecting it.** `InspectorPanel.select()` is the only sanctioned way to raise a selection surface and it already draws brackets plus the shader tint, so `guide.point_at_subject()` routes through it — checking `selected_subject()` first, because `select()` toggles. It does take the player's inspector away from whatever they had open; that is the same trade the alert feed's JUMP already makes, and a hint fires at most once.

The eight, with what each points at:

| Hint | Points at | Says |
|---|---|---|
| `module_unreachable` | the module | Crew cannot reach it until a corridor or stairs connect it. Build → Core |
| `module_unpowered` | the module | It will not run without power. Solar panels are Build → Power, and they want open sky — do not wall them in, including with each other |
| `trader_arrived` | `console:trade` | Buy and sell before your chains exist; ship iron ore to keep ARC content; place orders early — a standing order fills the moment a trader docks |
| `comet_arrived` | `screen` | Ice and carbon, and not for long |
| `crew_resigning` | the pawn | Unhappy crew leave. Lose everyone with no money to hire, and ARC takes the station |
| `need_recreation` | the pawn | Crew have to unwind. The mess hall counts if they can get to it; dedicated modules count for more |
| `need_sleep` | `vital:beds` **and** the pawn | A bed they can walk to. The crew-against-beds count is in the console |
| `need_hunger` | the pawn | Starving crew take damage and eventually die. A reachable mess hall, with food actually in it — buy it or grow it |

### 6 — `TutorialManager`

`scripts/managers/tutorial_manager.gd`, `Global.tutorial_manager`, a node in `main.tscn` under `Managers/`. Tree order is ready order and load-bearing as always: **after `DialogueRunner`** (it calls `run()`), after `AsteroidManager` and `CrewManager` (it subscribes to their signals), **before `SaveManager`**. It owns:

- **The ledger** — which hints have fired, whether the onboarding ran, whether the player skipped. `TutorialLedger`, pure, its own GUT suite.
- **The watchers** — armed on `game_bootstrapped`, disconnected as each hint spends itself.
- **The hint table**, scanned from `ContentPaths.TUTORIAL`.
- **The save section** `&"tutorial"`, order **170** — above every vanilla section, because it restores against a finished station and its watchers must arm against real modules.
- **The coach**, which it mounts and hands to the bridge.

**An absent save section means the tutorial is complete.** This is the one migration decision and it goes the conservative way: a pre-WI-63 save gets `onboarding_done = true` and every hint marked spent. The alternative — defaulting to "nothing has happened yet" — would have a veteran's two-hundred-module station stop dead to explain what a corridor is. A save that predates the feature belongs to somebody who already knows.

**The onboarding runs on new games only.** `game_bootstrapped` fires from two places: `main.gd` for a new game, `SaveManager._apply_pending_load` for a load. The guard is the same `not SaveManager.has_pending_load()` that `main.gd` already uses to decide whether to spawn the starting station. A save taken *during* the onboarding therefore comes back with the tutorial not finished and not running — which is correct: the conversation is gone, the hold is released, and the ledger says the onboarding did not complete, so AIDE offers to replay it.

**`DialogueRunner` gains one narrow public method, `abandon()`** — end the conversation on screen now. It is not new behaviour: `_on_game_over` already does exactly this internally. Naming it is what lets the skip control reach it without anything else learning how to touch a balloon.

**Skip disarms everything.** Whether from the New Game checkbox or the skip control mid-run, the result is the same: onboarding marked done, every hint marked spent, watchers disconnected. A player who skipped the tutorial has said they know how to play, and a game that keeps interrupting them anyway did not listen. AIDE is where they go if they change their mind, and that is the strongest reason §8 is in scope rather than deferred.

### 7 — Skip Onboarding on the New Game screen

`NewGameSetup` gains a checkbox in its footer row, beside Begin. `start_requested` gains a fourth argument; `MainMenu` stages it with `Global.set_skip_onboarding()` alongside the difficulty, the station name and the crew, and `Global.clear_staged_start()` resets it — the same four-line pattern WI-59 established, in the same place.

Default **off**. A first-time player who does not read the checkbox gets the tutorial, which is the failure mode that costs them nothing.

`NewGameSetup` is on `test_ui_theme.gd`'s `OVERRIDE_EXEMPT` list (`res://ui/menus/` predates WI-49), so the checkbox is authored in the local idiom of that file and does not start pulling `ConsolePanel` into the menu layer.

### 8 — AIDE goes live

WI-50 reserved the console slot and its `ui_aide` (F1) binding, disabled with *"Assistance is not available yet"*, and [[04_UI_Rework_Program]] decision 7 names this item as its mount point. It becomes a real mode opening a 620px `ConsolePanel`, **SAI ADVISORY**, with two blocks:

- **Replay the introduction** — one row, always present.
- **Advisories** — every hint SAI has given this run, newest first, each replayable. A footer line counts how many remain unseen without naming them.

**`Mode.AIDE` is a mode that is not in `ORDER`.** The console builds seven buttons from `ModeManager.ORDER`, then a divider, then AIDE and SYS — AIDE sits past the divider deliberately and must stay there. But `test_mode_manager.gd:263` asserts `ORDER.size() == Mode.size() - 1`, so adding an eighth mode breaks it. The fix is not to weaken the assertion: `ModeManager` gains `TRAILING: Array[Mode] = [Mode.AIDE]` — modes that live past the divider — the console builds `ORDER`, divider, `TRAILING`, divider, SYS, and the test becomes `ORDER.size() + TRAILING.size() == Mode.size() - 1`. The table still has to account for every mode; it just knows there are two zones now. `LABELS` and `HOTKEY_ACTIONS` gain their `AIDE` rows and F1 starts working for free.

SYS stays what it is — not a mode, it opens the pause menu.

### 9 — Modding

One new `ContentPaths` kind, `TUTORIAL`, appended to `KINDS`. A mod drops a `.tres` plus a `.dialogue` into its own `data/tutorial/` and gets a hint, provided it names a declared trigger. `TutorialTriggers` gains a `declare()` the way `StoryFlags` has one, so a mod that ships its own watcher can ship its own trigger; re-declaring a vanilla id is refused rather than overwritten, for the same load-order reason.

The `guide` verb list growing on demand is expected. Content growing *around* it is not, which is what the access filter enforces — unchanged from WI-62 §3.

### 10 — What this item deliberately does not build

- **A tutorial beyond the first module.** The brief's scope is the introduction, one guided placement, and eight reactive hints. A second guided sequence ("now connect it", "now power it") is a plausible follow-up and is exactly what the hints already cover reactively — which is better teaching, because it arrives when the player has the problem.
- **Difficulty-aware or skill-aware hints.** Every hint fires for every player once. No adaptive pacing.
- **A hint for anything not in the brief's list.** Heat, raids, disease, contracts, tiers — all real, none taught here. Adding one later is two files.
- **Voice.** The balloon honours a `#voice` tag; nothing authors one.
- **Rewording the hold sentence.** During a gate the console reads *"In conversation"* while the balloon is hidden and the coach mark is up. The mark carries SAI's face and name, so the claim is true, and this is the reason it does. If playtesting says it reads wrong, the fix is a priority order over `TimeManager`'s holders — **not** a second pause hold, which would put two rows in the tables for one situation.

## Stages

1. **The manager and the ledger.** `TutorialManager`, `TutorialLedger`, `TutorialTriggers`, `TutorialHintData`, the `ContentPaths.TUTORIAL` kind, the `&"tutorial"` save section. No content, no UI — drive it from a cheat.
2. **The bridge and the coach.** `TutorialBridge`, the `guide` alias, the filter line, `TutorialTarget`, `TutorialCoach`, the three new UI accessors, `DialogueRunner.abandon()`. Drivable end to end from a hand-written probe `.dialogue`.
3. **The onboarding.** `onboarding.dialogue`, the `game_bootstrapped` trigger, the Skip Onboarding checkbox and its staging.
4. **The hints.** The six watchers, the two grace windows, `SignalBus.space_body_arrived`, the eight `.tres` + `.dialogue` pairs.
5. **AIDE.** `Mode.AIDE`, `ModeManager.TRAILING`, the panel, the replay path, the test-table change.
6. **Verification.** Probe, screenshots, docs.

Stages 1–2 land independently and change nothing the player sees. Stage 3 is the first stage a new game behaves differently in.

## New cheats

The console is how stages 1–2 get driven before any content exists, and how a hint gets tested without walling in a solar panel and waiting two hours. Plain strings, as always.

- `start_onboarding()` — run the onboarding conversation now, from any state.
- `fire_hint(id)` — fire one hint regardless of its trigger or its ledger entry.
- `reset_tutorial()` — clear the ledger; everything is unseen again.
- `dump_tutorial()` — what has fired, what is armed, what is waiting.
- `skip_tutorial()` — the abandon path, from outside.

Each emits the standing `station_alert` "CHEAT: …", so a save that used them stays self-documenting.

## Testing

New GUT suites, pure classes only, constructed directly — never touching `Global` or `SignalBus`:

- `test_tutorial_ledger.gd` — once-ever semantics, the skip-disarms-everything path, save round-trip, and **the absent-section default being "complete"** rather than "fresh", which is the one migration decision and the one that is silent if it regresses.
- `test_tutorial_triggers.gd` — declared-id enforcement, `declare()` refusing a redefinition, which triggers take a filter.
- `test_tutorial_target.gd` — the target grammar: every kind parses, an unknown kind errors rather than resolving to nothing, a malformed string does not crash.

Extended:

- **A content sweep**, the most valuable test in this item, mirroring WI-62's cue sweep: for every `TutorialHintData`, assert `dialogue != null`, `cue` non-empty, `dialogue.get_cues().has(cue)`, `trigger` declared, and `trigger_filter` present only where its trigger takes one. Assert every declared trigger has **exactly one** vanilla hint — a trigger with no hint is a watcher burning `slow_tick` for nothing.
- **A verb sweep.** Scan every `.dialogue` file under `data/dialogue/` for `guide\.(\w+)` and assert each name is a method on `TutorialBridge`. The access filter allows the bridge wholesale, so a typo'd verb is a runtime error in the middle of the tutorial with the sim held — the worst place in the game for one. This is the analogue of WI-62's cue check and the only thing that will ever catch it statically.
- **An affordability pin.** Assert the module the onboarding asks for costs no more than a new game starts with. The mess hall is 6 steel and the starting module ships 50, so it passes today — and the day someone retunes either number, the gated step becomes unsatisfiable with the sim held and no way forward except the skip control. One assertion, permanent.
- `test_mode_manager.gd` — `ORDER.size() + TRAILING.size() == Mode.size() - 1`, and `AIDE` present in `LABELS` and `HOTKEY_ACTIONS`.
- `test_ui_theme.gd` — `tutorial_coach.tscn` swept, not exempted.
- `test_pause_holds.gd` — **unchanged, deliberately.** Assert no new holder appears; the tutorial rides the balloon's `&"dialogue"` hold.

## Verification

Per the standing rule — a screenshot is part of the verification and has to be driven into the state under test. Assume the headless-probe fallback: a temporary autoload running a numbered checklist and printing pass/fail per check, then deleted.

Probe checks worth naming in advance:

1. A gate whose condition is **already true** returns in the same frame and arms nothing.
2. A gate suspends the conversation, and the sim stays held across the whole suspension — `pause_holders()` contains `&"dialogue"` and nothing else, before, during and after.
3. `abandon()` mid-gate resolves it, ends the conversation, releases the hold, and **the next gate in the same file returns immediately** rather than re-suspending.
4. Each hint fires exactly once: fire its trigger three times, assert one conversation, one transmission, and the watcher disconnected afterwards.
5. The unpowered watcher does **not** fire for a `force_off` module, and does not fire for a module that browns out for less than the grace window.
6. The unreachable watcher fires for a module placed with no corridor, and does not fire for one connected within the grace window.
7. A save taken mid-onboarding loads with no conversation, no hold, and the ledger reporting the onboarding incomplete.
8. A save with no `tutorial` section loads with everything marked complete and no watcher armed.
9. Skip Onboarding at New Game produces a run where `game_bootstrapped` raises nothing and no watcher is armed.
10. Every hint's subject survives to the conversation — a pawn that resigned and departed between the trigger and the balloon does not produce a null-name line.

Screenshots, each driven into state: the intro balloon with SAI's portrait; the coach mark on the console's Build button with the balloon hidden; the mark on a Build flyout row (a target inside an open panel); the mark on a vitals chip; a hint firing with its pawn selected and bracketed; the mark after its target disappeared, ring gone and plate still up; the AIDE panel with a partly-filled archive; the New Game footer with the checkbox.

## Edge cases

- **The player places the wrong module during the placement gate.** The gate does not fire; the mark stays up; SAI says nothing. Acceptable, and better than an interruption — the caption already names what to place. The skip control is the way out for a player who has decided to build something else.
- **The player cannot afford the module.** The click no-ops and the gate hangs with the sim held. Guarded by the affordability pin above, with the skip control as the runtime backstop.
- **A hint's trigger fires while the onboarding is still running.** The runner queues conversations, so it plays after. But the *subject* may be stale by then — see probe check 10; the hint resolves its subject at fire time and drops itself if the subject is gone before its first line.
- **Two hints trigger in the same tick.** Already handled: `DialogueRunner`'s queue, same guarantee as `pending_events`.
- **A hint fires during a critical alert's hold.** Two holds, refcounted, independent (WI-53). Neither releases the other.
- **The player opens the pause menu mid-gate.** `ui_cancel` is never swallowed (WI-62 rule 2), so Esc reaches it and save/quit stay available with the tutorial suspended. This is the reason that exception exists and it should not be narrowed.
- **A game over during the onboarding.** `DialogueRunner._on_game_over` clears its queue and finishes the balloon; the coach mark takes itself down with the conversation. Hard to reach — the sim is held — but not impossible.
- **A hint's dialogue resource fails to load.** Logged, ledger entry spent anyway, no modal. A hint that cannot open must not become one that fires every slow tick forever.
- **A mod removes a hint whose ledger entry is saved.** The entry is dropped with a warning on load, exactly as `StoryFlags.from_save` drops an unknown flag and for the same reason.
- **The player quits to the menu mid-tutorial.** `TutorialBridge` unregisters its alias in `_exit_tree` alongside the other two; a stale context surviving the scene swap would have the next run's dialogue pointing at a freed coach.

## Open questions

1. **Should the hints respect difficulty?** A player on Hard has arguably opted out of being taught, and a player on Peaceful might want more. The current answer is that they are orthogonal — difficulty tunes the simulation, not the documentation — but the New Game screen now has both controls side by side, which invites the question.
2. **Should a hint be re-armable?** Once-ever is the brief, and the AIDE archive covers re-reading. But *"a module has no power"* is advice a player can need twice, six cycles apart, about a different module. A cooldown rather than a latch is a small change and a real behaviour change; not making it now avoids designing for a complaint nobody has made.
3. **Does the coach mark want to dim the rest of the screen?** A scrim would make the ring unmissable and would also cover the station the player is being asked to look at. Starting without one; the pulse may be enough.
