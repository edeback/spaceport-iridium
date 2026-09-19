# WI-67 — Move Heat and O2 to Tier 2 (Spacesuits)

> **STATUS: IMPLEMENTED 2026-09-15, STATICALLY VERIFIED ONLY.** Nine files new, twenty-two changed. **1672 GUT tests green** (1624 before this item, so +48 and nothing regressed), across three new suites: `test_suit_rules.gd`, `test_suit_content.gd` and `test_crew_frames.gd`. `SAVE_VERSION` did not move.
>
> **What is NOT verified, and it is the important half:**
> - **No live-world run.** The headless probe in §Verification was written and *hung before its first line of output* — the WI-40 `-s script.gd` autoload gotcha, not a defect in the item. Its resource-and-logic checks were moved into GUT (where they pass); everything that genuinely needs a loaded station is **untested**: a crew pawn actually spawning with the component, Tier 1 posting no trips, `tier_up` sending helmets to the airlock, the walk itself, the suit-up alert firing, the mood applying, the Heater warming anything. **Assume none of that works until it has been run.**
> - **No screenshots.** The tint-on-faces question (§10) is completely open, and it is the one the design flags as needing a look rather than a test.
> - **No balance measurement.** The Heater's 150/hour, 15 power, its thermostat band and `harm_hold_hours = 2.0` are all first guesses. WI-60's first guesses were out by ~4× in both directions.
>
> **Deviations from the design below:**
> 1. **`SuitRules.Environment` is `SuitRules.RoomState`.** Godot has a native `Environment` class, and an enum of that name at script scope makes every *external* reference resolve to a different type — `Parse Error: Could not resolve external class member "Environment"`, then `Invalid operands "Environment" and "SuitRules.Environment"`. Worth knowing before naming any enum after a Godot type.
> 2. **Inner classes must spell the enum `SuitRules.RoomState` in full.** An inner class does not inherit the outer script's type scope, so `Situation.environment: RoomState` is a *different* type from the one every caller passes. Reads as redundant; is not. The WI-64 `class_name`-cycle trap in a new costume.
> 3. **The change duration is `JobDriver_ChangeSuit.CHANGE_SECONDS`, not an export on the component.** `make_actions()` runs on unclaimed board jobs with no pawn attached, so there is no component to read it from — and `PawnComponentBase` is a `Node2D`, so instantiating one for a default would allocate a node per call and leak it.
> 4. **`sleep_restored_per_hour()` gained an optional `sleeper` parameter** rather than becoming a second function; `environment_rest_multiplier(sleeper)` does the same. Null still asks the module-level question the Environment tab prints.
> 5. **`pawn_base.tscn` still contains the old embedded `SpriteFrames` sub-resource and its 38 texture references**, now unused — the `Crew` node points at `crew_suited_frames.tres`. Hand-deleting ~190 lines of a scene file risked corrupting it; the editor drops them on the next save.
> 6. **`PawnSuitComponent.hold_remaining()`** was added as a public accessor for `dump_suits` and the Needs tab.
> 7. **`project.godot` changed by itself**: the Dialogue Manager addon appends every new `.dialogue` to `locale/translations_pot_files`. Expected, and the same thing WI-62 and WI-63 did.
>
> The questions the brief left open were settled with the author in two rounds — §0 carries the answers, and they are decisions rather than suggestions. **Round two changed the shape of the item:** a suit is put on and taken off **at an airlock**, not where the pawn stands, which is what makes a breach or a cold room genuinely dangerous and makes airlock placement a layout decision.

## Goal

A new station asks the player to keep six things alive at once: food, sleep, recreation, power, air and heat. Air and heat are the two that fail *quietly* — the station starts pressurised and warm, the player expands fast, the starter module's scrubber and heater are spread thin across twenty rooms, and the crew suffer in a way that reads as nothing until somebody is hurt. Food and sleep at least announce themselves.

After this item, air and heat stop being Tier 1's problem without stopping being simulated:

1. **At Tier 1 the crew live in their suits.** Suited crew feel ideal air and temperature everywhere, inside or out. No cost, no upkeep, no behaviour. Low-oxygen and temperature *warnings* are muted; the gas and the heat keep moving exactly as they do today.
2. **From Tier 2 the crew want their helmets off.** They walk to an airlock to take a suit off, walk to an airlock to put one back on, and a suit worn indoors costs **−10 mood**.
3. **SAI says so** when the station reaches Tier 2.
4. **The crew look different** with the suit off — the new helmetless sprites.
5. **A Heater module**, with a thermostat, so a Tier 2 player has a fix for a cold station that is not "build a forge".

## 0 — Decisions settled with the author

**Round one (2026-09-15).**

1. ~~Suits come off in place.~~ **Superseded by round two.**
2. **Visitors never wear suits.** They feel the station exactly as they do today, and never take the −10.
3. **Tier 1 mutes warnings, not readouts.** The low-O2 alert and the OXYGEN chip's amber go quiet. The O2 and heat overlays, the Status tab's Air and Environment sections and the Environment temperature line all stay — a player who goes looking can still see the systems.
4. **SAI's Tier 2 notice is a tutorial hint.** Skipping the tutorial skips it; AIDE replays it. §8 covers what a skipping player gets instead.
5. **A Heater module is in scope.** WI-60 measured an expanded station heated only by the starting module settling at **−7 °F**; without a heater, reaching Tier 2 would suit most of the crew permanently.

**Round two (2026-09-15).**

6. **A suit goes on and comes off at an airlock, as a job.** This is the item's central rule, and it reverses decision 1. The cost is a new job type; what it buys is the whole point of the feature — a breach or a heat failure is now a real danger, because the crew have to *cross the station* to get into a suit, and a station whose airlocks are far from its workshops is a station that kills people. Layout matters.
7. **Hull breaches do not happen at Tier 1.** They start at Tier 2 (§12).
8. **The Heater has a thermostat** the player sets (§9).
9. **No roster filtering** for who is suited. The sprite is the signal.
10. **Disease is out of scope.** Suits do not affect transmission in this item; noted for future disease/health work.
11. **ARC's Tier 2 promotion transmission gains a line**: *"…and your crew will expect habitable interior conditions."*
12. **The Tier 1 ARC inspector arrives and stays suited**, so an inspection can never fail on air or heat the player was never asked to provide (§11).

## Design

### 1 — What changed in round two, and why it is the whole item

Round one had a suit come off wherever a pawn stood. That made the suit a status effect: conditions turn bad, the suit appears, nobody is ever hurt, and the entire cost of a failing station is mood. The airlock rule turns it into a **race**:

- A room turns harmful. The crew in it are **not** protected — they are unsuited, and the clock is running.
- They drop what they are doing and walk to the nearest airlock, **taking damage the whole way** — suffocation from `PawnBreathingComponent`, temperature harm from `PawnTemperatureComponent`, both already built and both currently near-unreachable in practice.
- Whether they make it is a function of **how far the nearest airlock is**, which is a thing the player built.

So the existing health-drain paths stop being decorative, and the answer to "why would I put an airlock here?" stops being "to go outside". A breach in a far corner of a sprawling station is now a genuine emergency, which is what the brief's "actual danger" asks for.

Two consequences to hold on to while reading the rest:

- **Crew can now die of air and heat.** Health reaching zero does nothing today — there is no death, and *Pawn Death* is a separate brief item — so in practice a crew member bottoms out at 0 HP and stays there. This item does not add death, but it is the first system that will routinely drive health to the floor, and it is worth knowing that is the state the player will see until that item lands.
- **The response to *harmful* preempts work** (§4), which is a deliberate departure from WI-17's "flee only preempts idle jobs, working crew finish what they're doing, that's the player's problem to notice". That stance was written when the consequence was a slow health tick. When the consequence is dying at your post, self-preservation wins.

### 2 — The rule: three environments, and hysteresis between them

**`SuitRules`** (`scripts/utility/suit_rules.gd`), pure and static — no `Global`, no `SignalBus`, the standing rule. The component owns the state and the tunables and passes them in, exactly as `HeatMath` is used.

A room sorts into one of four answers:

| Environment | When | What it means |
|---|---|---|
| `HARMFUL` | O2 partial < `damage_o2_partial` (25) **or** temperature outside the dangerous band (< 20 °F / > 110 °F) | go and suit up **now** |
| `HABITABLE` | O2 partial ≥ `AtmosphereManager.alert_o2_partial` (40) **and** temperature inside 40–90 °F | a suit may come off here |
| `TOLERABLE` | anything between | keep what you are wearing |
| `UNKNOWN` | no `AtmosphereComponent`, or no thermal body yet | keep what you are wearing |

**`TOLERABLE` is the load-bearing row.** With only two answers, a room sitting at 40 °F would send a pawn back and forth to the airlock forever. The gap between "fit to live in" and "actively harmful" is the hysteresis, and it is also what the brief describes: an unsuited crew member in a chilly 30 °F room is cold and unhappy about it, and does not go and suit up.

**Every threshold is borrowed, never re-declared.**

- `HARMFUL` uses the numbers that already mean "this is hurting you": `PawnBreathingComponent.damage_o2_partial`, and the pawn's `PawnTemperatureComponent.tuning()` dangerous band. A GUT sweep pins `HARMFUL` to hold **exactly** where `HeatMath.harm_per_hour() > 0` or O2 is below the damage partial, to the degree — the WI-60 deviation 7 lesson, where two functions answering the same question disagreed at the boundary.
- `HABITABLE`'s O2 floor is `AtmosphereManager.alert_o2_partial`, the number the low-O2 alert and the OXYGEN chip already share. So "the crew will take their helmets off in here" and "the game is not warning you about this room" agree by construction.
- `UNKNOWN` is not a real room. Only truss, armour plate and the radiator carry `has_atmosphere = false`, and crew never stand in any of them; it exists for the registration window just after a module finishes building. It must never read as harmful, or every completed build would send its construction crew sprinting for an airlock.

The state machine over those answers:

```
outside (current_module == null, and not CONVEYED)   -> suited, no job
TierData.suits_mandatory (Tier 1)                    -> suited, no job
unsuited and environment == HARMFUL                  -> SUIT UP: interrupt, go to any reachable airlock
suited and hold > 0                                  -> stay suited
suited and hold == 0 and current room HABITABLE      -> TAKE IT OFF: queue a trip to a HABITABLE airlock
otherwise                                            -> unchanged
```

**The hold** is `harm_hold_hours = 2.0` sim-hours, reset to full on every tick spent in a `HARMFUL` room and decremented otherwise — so it measures *"two hours past the last time they met a hostile interior"*, the brief's wording, rather than two hours from first contact. Being outside does not refresh it: space is not a hostile interior. It runs at Tier 1 as well, so a promotion that lands mid-crisis still respects it.

**Taking the suit off needs the pawn's *current* room to be habitable, not just the airlock.** Otherwise a crew member working in a 25 °F workshop walks to the airlock, strips, walks back, and immediately walks out again to re-suit — an oscillation the player watches all day. Requiring the room they are actually in to be fit means the −10 persists precisely while the place they work is not, which is the signal the player needs. A `TOLERABLE` room keeps its suit on and its −10, and that is the hysteresis doing its job.

**The airlock clause from the brief survives as the entry case.** A pawn coming in from outside is *standing in* the airlock, so if that airlock is `HABITABLE` and the hold has expired, the suit comes off there with no trip: they are already at the place. This is also the one thing that ends a hold early — a crew member who suits up in a freezing lab, goes out to build something, and comes back through a warm airlock twenty minutes later takes it off there instead of waiting out the two hours.

**"Outside" means exterior, not "no module".** `current_module == null` also covers a turbolift ride, and the moment before `spawn_crew` assigns a module. So the rule reads `current_module == null` **and** the movement component is not `CONVEYED`; a conveyed pawn decides nothing and keeps what it is wearing. Otherwise every lift ride would flip a helmet on and off.

When the rule runs: on `slow_tick` (which also decrements the hold), on `PawnBase.module_changed` (so the airlock entry case sees the exact transition and a pawn reacts the step they enter a harmful room), and on `SignalBus.station_tier_changed`.

### 3 — `PawnSuitComponent`: the state, on crew only

`pawns/pawn_suit_component.gd` (`class_name PawnSuitComponent`, extends `PawnComponentBase`), on **`crew_pawn.tscn`** — and, in its static form only, on the inspector (§11). That is the whole robot/visitor exclusion: WI-48's *carries the component = participates*, one rule, no `is_visitor` test anywhere in this item.

State: `suited: bool = true`, `_hold_remaining: float`, `_was_outside: bool`, `_active_mood: bool`, and `_trip_cooldown: float` (§4). Exports: `harm_hold_hours = 2.0`, `indoor_mood_offset = -0.10`, `suit_change_seconds`, `trip_retry_hours`, `suited_frames`, `unsuited_frames`.

`_was_outside` is a bool rather than a reference to the previous module, deliberately: a module can be freed between two ticks, and this is the non-`Dictionary` form of WI-63's dangling-node lesson.

**Suit supply becomes one question in one place.** Today it is answered twice — `PawnBreathingComponent` says a null module or a module with no atmosphere, `PawnTemperatureComponent` says a null module. Add

```gdscript
static func on_suit_supply(pawn: PawnBase) -> bool   # null module, OR carries this component and is suited
```

and have `PawnBreathingComponent._current_atmosphere()` return null and `PawnTemperatureComponent.ambient_temperature()` return `NAN` when it is true. **Their existing suit-supply branches then do all the work** — no O2 drawn, no suffocation, no flee, no temperature mood, no harm — and the NaN branch's `_clear()` is already what lifts a stale `too_cold` the moment a suit goes on. Neither consumer gains a new branch. Breathing keeps its own "a module with no atmosphere is suit supply" clause for pawns that carry no suit component.

The suit component reads the **raw** room, never the felt one, or it could never decide to take a suit off: `Global.atmosphere_manager.get_component(module)` and `Global.heat_manager.temperature_at(module)` directly. A pawn kind missing a breathing or temperature component simply has no opinion on that axis, and the axis counts as fine.

**Suited crew do not breathe station air**, which is the existing suit-supply rule and matters twice. At Tier 1 nobody draws the station's O2 down, so "oxygen still moves through the station" holds while nothing consumes it; new modules still register at vacuum and fill from their neighbours, so an over-expanded Tier 1 station arrives at Tier 2 thin on air, and that is Tier 2's first lesson. At Tier 2 it also closes a loop worth having: crew who suit up in a failing room stop drawing its O2, so it recovers while they are gone.

**Sleep.** "Act as if in ideal heat" reaches rest too. `SleepComponent`'s rest-rate path (`sleep_component.gd:103`) takes the sleeper and drops `temperature_comfort_multiplier()` from the product when that sleeper is on suit supply. Vibration and greenery stay — a suit does not quiet a noisy dormitory. The Environment tab keeps printing the module-level number, and `desirability()` is untouched: a suited sleeper still preferring the warm bunk is harmless.

### 4 — The trip: one job type, two ways in

A new job type, `change_suit`, following WI-44 exactly — a `JobData` `.tres` plus a `JobDriver`, with no registration step.

**`data/jobs/change_suit.tres`**: `category = NEEDS`, `skill = &""`, `xp_reward = 0`, `saveable = true`, `player_cancelable = false` (this is self-preservation, and a player cancelling a suit-up is cancelling somebody's life support).

**`JobDriver_ChangeSuit`**, three actions:

```gdscript
[Action_FindBestTarget.new(Finder_Airlock.new(need_habitable), JobTarget.Slot.A),
 Action_GotoTarget.new(JobTarget.Slot.A),
 Action_ChangeSuit.new(JobTarget.Slot.A)]
```

**`Finder_Airlock`** extends `TargetFinder`, modelled on `Finder_DockingBay` (a group scan, not a slot finder — an airlock has no occupancy to book): nearest reachable module in `Groups.AIRLOCK`, filtered by `Global.path_manager.is_reachable`. Suiting **up** accepts any airlock, habitable or not — you can always put a suit on. Taking one **off** accepts only a `HABITABLE` airlock, per the brief.

**`Action_ChangeSuit`** is `CompleteMode.DURATION` (a few sim-seconds, with the `interact` pose) and flips the component's `suited` on completion. Two contracts it must honour:

- **`on_resume` must not re-flip.** The action contract's most important rule is that an `on_start` which changes the world needs a resume that verifies rather than repeats. The flip therefore happens in `on_finish` on the success path — or, equivalently, the action records that it has flipped in `save_state()`. A save taken mid-change must not toggle a suit twice.
- **It re-checks at the moment of the flip.** Taking a suit off verifies the airlock is still `HABITABLE` and the hold is still clear; conditions can change during the walk. A failed check ends the job without flipping, and the cooldown below stops it thrashing.

**Two ways in, and the difference is the point:**

- **Suiting up is an interrupt.** `interrupt_with_job` — the same call `PawnBreathingComponent._try_flee` and `InspectionRunner` already use. It preempts whatever the pawn was doing, at any job, which is §1's deliberate departure from WI-17.
- **Taking a suit off is queued.** `queue_job` puts it on the pawn's **personal queue**, so it runs when the current job ends. Work is not interrupted to go and change; the −10 rides along until then. Both go through the personal queue or an interrupt and **never** the board — the standing rule for followups and queued needs.

**When no airlock is reachable**, no job is posted. The suit-up alert (§7) still fires and says why (*"no reachable airlock"*), which is exactly the layout feedback this design exists to give. The milder existing behaviour still helps here: `PawnBreathingComponent`'s flee already moves **idle** crew out of a room below `flee_o2_partial` (35) *before* it reaches the damage partial (25), so the suit trip is the second line of defence rather than the first. Temperature has no equivalent flee, which is noted as an open question rather than built.

**`_trip_cooldown`** (`trip_retry_hours`) is set whenever a trip fails or a change is refused at the airlock, so a station in a state where the rule wants a change it cannot complete retries on a slow clock instead of every tick.

**At the moment of promotion** every suited crew member in a habitable room queues a trip, so the station files past its airlocks over the following minutes as SAI is still talking. That is a good moment and it costs nothing to get; it also means a station with one airlock and twenty crew has a visible queue, which is feedback about the layout.

**No claims, no slots, no suit inventory.** An airlock takes any number of simultaneous users, and a suit is not an item. The brief is explicit that suits have no resource or energy cost, and slot contention here would turn a safety mechanism into a traffic jam. `ClaimSpec` is not involved, so `required_claims` stays empty.

### 5 — Where Tier 1 is decided: `TierData.suits_mandatory`

A bool on `TierData`, **true on `tier_1.tres` only**, read through one accessor — `UnlockManager.suits_mandatory() -> bool` (the current tier's flag; `false` plus a `push_warning` if the tier has no data). Four readers, one answer: the suit component, `AtmosphereManager`'s alert gate, `VitalsStrip`'s OXYGEN chip, and the new min-tier event condition (§12).

Data rather than `current_tier < 2` for the WI-26 reason: what a tier *is* lives in its `.tres`, and a mod reshaping the ladder decides where the suits come off.

### 6 — The −10: `&"suit_indoors"`

A `MoodCatalog` entry: label **"Spacesuit on inside"**, a new `CAUSE_SUITED := "while suited indoors"`, and a blurb that doubles as the rule's explanation — *"Wearing a pressure suit inside the station. Crew want rooms they can breathe and stay warm in without one."*

The brief's "−10" is **−0.10**: mood is 0–1 and the Needs tab prints it ×100 (`pawn_needs_tab.gd:142`), so it reads `−10` beside `too_cold`'s `−12` at worst.

Applied when **suited, inside, and not `suits_mandatory`** — never at Tier 1, never outside. It *does* apply while a hold keeps the suit on, because that crew member is wearing a suit indoors and the brief's rule is about the suit. INF duration and **derived**: never saved, re-derived on the first tick after a load from the saved `suited`, exactly like `too_cold`, `company` and the WI-30 field maluses.

That row is where a player who skipped the tutorial learns the rule (§8), which is why the blurb carries it.

### 7 — Warnings

**Muted at Tier 1** (`suits_mandatory`):

- **The low-O2 alert.** `AtmosphereManager._check_alerts()` returns early. On `station_tier_changed` to a non-mandatory tier, `_low_o2_alerted` is **cleared**, so the first Tier 2 pass raises for every room that is already thin, and the existing plural line (`"%d modules are low on oxygen"`) coalesces them into one row. Promotion is exactly when that list is worth having; the alternative leaves rooms latched silently from Tier 1 until they recover and drop again. The load path emits the same signal, costing one duplicate warning — WI-45 A7's accepted price for an unsaved latch.
- **The OXYGEN chip's amber.** The station average still prints; it never goes amber while mandatory. It refreshes every 0.5 s of real time, so promotion lights it with no wiring.
- **The temperature harm alert needs no gate**: suited crew feel `NAN`, so it cannot fire. Say so in a comment, or the next reader adds a redundant check.

**Not muted** (§0.3): the O2 and heat overlays, the Status tab's Air and Environment sections, the Environment temperature line and its band word. Hull breaches are handled by not happening at all at Tier 1 (§12).

**Added at Tier 2: the suit-up alert.** When a crew member starts a suit-up trip — that is, when the room turned `HARMFUL`, not when they walk outside and not at promotion — `PawnSuitComponent` raises:

```
AlertRules.make_id(&"suit_up", pawn), HIGH
"Suiting up — no air" / "— too cold" / "— too hot"
"<name> · <module> · <reading>"      # or "· no reachable airlock"
plural: "%d crew are suiting up"
```

**HIGH, not LOW**, and that is a change from what round one's design would have wanted: under the airlock rule this pawn is *being harmed right now* and is walking across the station to stop it. That is "look at this now" by the WI-53 definition, and it is the same class as the low-O2 alert it will usually accompany. It is not CRITICAL — it must not stop the sim, because the player's only useful response is to watch or to plan an airlock, and a modal in the middle of an emergency helps nobody. Its id is per pawn, so a crew member who trips this repeatedly refreshes one row.

For crew this replaces WI-60's `pawn_temperature` HIGH alert, which can no longer fire for them (they either make it to a suit or they are already being alerted about by this). That alert stays for visitors, and its plural `"%d crew are in dangerous temperatures"` becomes `"%d people are …"`, since visitors are now the only pawns it reaches.

### 8 — SAI at Tier 2

A normal WI-63 hint: two files, one trigger, spent once, transmitted, replayable from AIDE.

- **`TutorialTriggers.DECLARED`** gains `&"station_tier_reached": true`, filtered by the tier number as a string (`"2"`), so a later Tier 3 hint is a `.tres` drop with no watcher edit.
- **The watcher** subscribes to `SignalBus.station_tier_changed` and calls `_fire_for(&"station_tier_reached", str(t))` for **every tier from 2 up to the new one**, so two `tier_up` cheats in a row, or a load at Tier 3, cannot skip the Tier 2 hint.
- **The arming trap.** `UnlockManager.load_save_data` emits `station_tier_changed` *during* the load, before `game_bootstrapped` arms the watchers — so on a load the signal is already gone. Arming therefore also checks `current_tier` once, which is the watcher form of WI-63's "an already-true condition returns immediately". A post-WI-63 save that reached Tier 2 before this item has no ledger entry for the new hint and gets it on load; a pre-WI-63 save has no tutorial section, counts as complete, and gets nothing.
- **`data/tutorial/habitable_interior.tres`**: id `habitable_interior`, trigger `station_tier_reached`, filter `"2"`, `has_subject = false`, a title like "Crew want their helmets off", and a body that is the durable copy of the rule.
- **`data/dialogue/tutorial/hint_habitable_interior.dialogue`**, cue `tier_two`. SAI covers the four things the player now has to know: crew will not live in suits indoors any more; **they change at airlocks, so an airlock near where people work is a safety measure**; a suit worn inside makes them unhappy; and a room that turns harmful will hurt them while they walk. It points at **`console:overlay`** (the O2 and heat overlays show which rooms are fit) and **`console:rnd`** (the Heater and life support are researched there). It must **not** point at `category:life_support` — the Build rail hides a category until something in it is buildable, so at promotion the coach would ring empty space. WI-62's authoring traps apply: no `": "` inside a line, and no inline `[do …]` gates.
- It queues behind whatever is already talking (the inspection wrap-up, ARC's promotion), because `DialogueRunner` owns that ordering. The tutorial still adds no pause hold, so `test_pause_holds.gd` is untouched.

**ARC's promotion transmission** gains the author's sentence — *"…and your crew will expect habitable interior conditions."* — appended in `UnlockManager.advance_tier` **only when the new tier is 2**, since that body is shared by every promotion. That is the one line a player who skipped the tutorial still sees; the rest of their explanation is the `suit_indoors` Needs row (§6), the suit-up alerts (§7), and twenty helmets coming off.

`CLAUDE.md`'s "Six triggers, eight hints" becomes seven and nine.

### 9 — The Heater, with a thermostat

`modules/life_support/heater.tscn`, `data/modules/life_support/heater_mdata.tres`, `data/unlocks/industrial_tree/heater_unlock.tres`.

**The emitter learns two things.** `HeatEmitterComponent.idle_heat_per_hour` currently emits whenever the module stands — right for the starting module's trickle and the reactor's waste heat, wrong for a machine on the grid with a dial on it. It gains:

- `@export var power_consumption_component: PowerConsumptionComponent` — `OxygenGeneratorComponent`'s exact shape (`oxygen_generator_component.gd:50`). Null means unconditional, so the starter and the reactor are byte-for-byte unchanged; linked and unpowered means no idle heat. `heat_per_batch` needs nothing: the processor's accumulator already stops when unpowered.
- `@export var thermostat_enabled: bool` plus `target_temperature_f: float = 65.0` and a small `thermostat_hysteresis_f`. While enabled, idle heat is emitted only while the owning module's own temperature is below the target, and stops once it passes target + hysteresis. **The hysteresis is not optional** — this is a feedback loop with a heater at one end, and a bare threshold is an oscillator, which is the same argument WI-60 §5 makes for the throttle's smooth ramp. The `O2 generator`'s `target_pressure`/`hysteresis` pair is the precedent for both the shape and the naming.

**The setpoint is player state, so it saves.** `HeatEmitterComponent` takes WI-47 component hooks it does not currently have — key `&"heat_emitter"`, order 66 (beside heat's 65) — writing `{"target_f": …}` **only when `thermostat_enabled`**, so no other module's save block changes.

**Its control** is a `Stepper` row in the module's Status tab, in the Environment section beside the temperature row, shown only when `thermostat_enabled`. `Stepper.configure(current, 40, 90, 5, false)` — the habitable band, in fives, unsigned — with `value_changed` (never `value_previewed`) writing the setpoint, which is exactly the commit rule the widget exists for. The row prints the target in °F through `HeatMath.format_temperature`, so the setpoint and the reading beside it are formatted by the same function.

**The module** is a small structure-only block in the radiator's shape: no interior, `has_atmosphere = false`, conducting over the structure graph like every WI-60 thermal body, with a `PowerConsumptionComponent` and a `HeatEmitterComponent`. It carries a **low** `heat_radiation_mult` (~0.5) — a heater that radiates its own output into space is a radiator with extra steps, and this one wants to be buried inside the station. Tags `["Life Support", "Thermal"]`, category `life_support`, placeholder art (WI-60 deviation 9's precedent).

**The numbers are a starting guess to be measured**, since WI-60's first guesses were out by ~4× in both directions: 150 heat/hour, 15 power, 4 steel, 3 upkeep. The pass criterion is a probe, not a feeling: **WI-60's 34-body station, with the starting module and two thermostatted heaters, settles inside 40–90 °F and the heaters cycle rather than run flat out.**

**The unlock**: industrial tree beside the radiator, **`min_tier = 2`, no prerequisite**, ~150 credits. Not folded into `life_support_unlock.tres`, which sits behind the electrolyzer: the day the player reaches Tier 2 is the day cold starts costing mood, so the fix has to be one purchase away. Not Tier 1, because heat has no consequence there and a Tier 1 heater would be a button that visibly does nothing.

### 10 — Sprites

**The art fits exactly.** Every crew member is `crewBlueA` recoloured by WI-22's `tint`; `pawn_base.tscn` references no other set. The 38 `NoHelmet` PNGs are that set's seven animations frame for frame: `idle` 6, `idle_sit` 6, `interact` 4, `interact_back` 4, `interact_sit` 4, `lay_down` 6, `walk` 8.

- **Extract** the crew `SpriteFrames` sub-resource out of `pawn_base.tscn` into `pawns/frames/crew_suited_frames.tres` — a pure move with an identical game afterwards, and its own before/after screenshot. **Author** `pawns/frames/crew_unsuited_frames.tres` with the same animation names, frame counts, speeds and loop flags. `assets/external/` stays unmodified (the WI-66 rule).
- **`PawnBase.set_sprite_frames(frames)`** is the only place `sprite_frames` is assigned, preserving animation name, frame, `frame_progress`, `flip_h` and rotation — although under the airlock rule a change only ever happens standing still in an airlock, so the mid-stride case is now rare rather than routine.
- Null `unsuited_frames` swaps nothing: a modded crew kind with the component and no helmetless art keeps its sprite and still gets the rule.
- **Visitors** carry no suit component and are never suited, so `visitor_pawn.tscn`'s `Crew` node takes the helmetless frames statically. A guest in a helmet reads as a guest in a suit.
- The pawn icon (`ui_in_game.gd:71`) and the inspector's identity strip read the current frame texture, so both follow the suit for free.

**The tint trap.** On the helmeted sprite WI-22's tint colours a suit; on the helmetless one it also colours face and hair. Whether the palette survives that is a screenshot question, answered in step 6 of the order below before anything builds on it. If it does not, the fix is a shader masking skin pixels out of the tint — do not pre-build it.

### 11 — The ARC inspector

`InspectionRunner._check_fail_conditions()` fails a run when the inspector drops below `_health_fail_threshold` (70 HP), and `InspectorPawn` carries `PawnHealthComponent` and `PawnBreathingComponent` — so today a vented station fails an inspection by suffocating the inspector. `Action_Wait`'s comment records that as deliberate: a dwelling inspector is kept non-idle precisely so it takes the damage instead of fleeing.

Per §0.12, that must not happen at Tier 1, when habitable air was never asked of the player. The inspector gets a **static** `PawnSuitComponent`: an `@export var static_suit: bool` that makes the component answer `suits_mandatory()` and nothing else — suited at Tier 1, unsuited from Tier 2, no trips, no job, no mood, no hold.

That single rule gives both halves. At Tier 1 the inspector arrives and stays suited, cannot be harmed by air or heat, and the promotion turns purely on the tour (which is what the checklist is for). From Tier 2 the inspector is unsuited and WI-26's fail path works exactly as it does today — by which point a habitable interior *is* the standard the station is being held to. `Action_Wait`'s comment gains a sentence saying the damage path it protects only bites from Tier 2.

The inspector also keeps the helmeted sprite at Tier 1 for free, since the static component drives the same frame swap.

### 12 — Hull breaches start at Tier 2

Per §0.7. There is exactly one source of breaches in play: the `micrometeorite_strike` event, whose dialogue calls `$> station.breach(1, 2.0)` — it is the only `station.breach` call in `data/dialogue/`. (`Cheats.breach_module` stays unrestricted, which is the point of a cheat.)

`EventData` has no tier field, and the right shape already exists: a new **`EventConditionMinTier`** (`data/events/conditions/condition_min_tier.gd`, `@export var min_tier: int = 2`, reading `Global.unlock_manager.current_tier`), attached to `micrometeorite_strike.tres` as a sub-resource exactly as `outbreak.tres` composes its two. `EventConditionDiseaseUnlocked` is the precedent in both form and intent — it exists so the outbreak event can never fire on a Tier 1 station with no disease to give.

The condition is generic and will be wanted again by the next tier-gated event, which is why it takes a number rather than hard-coding 2.

### 13 — Save

`PawnSuitComponent` uses the WI-47 component hooks, so there is **no `SaveManager` edit**. Key `&"suit"`, `save_order()` **65**, after breathing's 60; nothing orders against it. The block is `{"suited": bool, "hold_hours": float}` — the hold is a clock, which is real state.

The **trip itself** needs no special handling: WI-44 saves an in-flight job as its `JobData` id plus targets plus action index, and `JobDataRegistry` resolves `change_suit` by scanning `data/jobs/`. A save taken mid-walk reloads a pawn still walking to the airlock. `Action_ChangeSuit` is the one part that must get its `save_state`/`on_resume` right (§4), or a save landing inside the change flips a suit twice.

**A missing block** (a pre-WI-67 save) loads as `suited = true`, hold 0, and the first tick decides. At Tier 1, nothing changes. At Tier 2+, crew in habitable rooms queue a trip to an airlock and everyone else keeps the suit and the −10. An old Tier 3 station with cold corridors loads with unhappy crew: the rule is new to it, and §8's arm-time check is what tells that player why.

Not saved: the mood modifier and the sprite, both derived from `suited`. `TierData.suits_mandatory` is content. The thermostat setpoint saves (§9). `SAVE_VERSION` does not move.

### 14 — Cheats

Each emits its `station_alert` "CHEAT: …", ids as plain strings:

- `suit_up(name)` — as though the pawn had just met a harmful room: suited, full hold. `"all"` for the whole crew.
- `unsuit(name)` — clears the hold and takes the suit off in place. The rule may send them straight back to an airlock, which is the fastest way to see *why*.
- `set_o2(cell, partial)` — WI-60's `set_temperature` for gas, and the only practical way to drive a room across each boundary on demand.
- `dump_suits()` — per crew member: suited, hold, current module, environment class with its O2 and °F, nearest reachable airlock and its distance, any live trip, and whether `suit_indoors` is applied. The distance column is what makes this the debugging tool for the whole item.

## Files to touch

**New**
- `pawns/pawn_suit_component.gd` (`class_name PawnSuitComponent`)
- `scripts/utility/suit_rules.gd` (`class_name SuitRules`)
- `scripts/jobs/drivers/job_driver_change_suit.gd`, `scripts/jobs/finders/finder_airlock.gd`, `scripts/jobs/actions/action_change_suit.gd`, `data/jobs/change_suit.tres`
- `pawns/frames/crew_suited_frames.tres` (extracted), `pawns/frames/crew_unsuited_frames.tres`
- `data/tutorial/habitable_interior.tres`, `data/dialogue/tutorial/hint_habitable_interior.dialogue`
- `modules/life_support/heater.tscn`, `data/modules/life_support/heater_mdata.tres`, `data/unlocks/industrial_tree/heater_unlock.tres`
- `data/events/conditions/condition_min_tier.gd`
- `tests/unit/test_suit_rules.gd`, `tests/unit/test_crew_frames.gd`

**Changed**
- `pawns/pawn_base.gd` — `set_sprite_frames()`
- `pawns/pawn_base.tscn` — the crew `SpriteFrames` becomes an ext_resource
- `pawns/crew_pawn.tscn` — the component, with both frame sets
- `pawns/visitor_pawn.tscn` — helmetless frames; `pawns/inspector_pawn.tscn` — the static component (§11)
- `pawns/pawn_breathing_component.gd`, `pawns/pawn_temperature_component.gd` — suit supply via `on_suit_supply()`, and the temperature alert's plural line
- `modules/components/sleep_component.gd` — a suited sleeper drops the temperature term
- `modules/components/heat_emitter_component.gd` — power link, thermostat, save hooks
- `data/tiers/tier_data.gd`, `data/tiers/tier_1.tres` — `suits_mandatory`
- `scripts/managers/unlock_manager.gd` — `suits_mandatory()`, and the Tier 2 sentence on the promotion transmission
- `scripts/managers/atmosphere_manager.gd` — the Tier 1 gate and the promotion latch clear
- `ui/console/vitals_strip.gd` — the OXYGEN chip's amber gate
- `ui/inspector/tabs/module_environment_tab.gd` — the thermostat row
- `scripts/utility/mood_catalog.gd` — `suit_indoors`, `CAUSE_SUITED`
- `scripts/tutorial/tutorial_triggers.gd`, `scripts/managers/tutorial_manager.gd` — the trigger, the watcher, the arm-time check
- `data/events/micrometeorite_strike.tres` — the min-tier condition
- `scripts/jobs/actions/action_wait.gd` — the inspector comment (§11)
- `scripts/utility/cheats.gd` — the four cheats
- Tests, extended not rewritten: `test_tutorial_triggers.gd`, `test_tutorial_content.gd`, the build-menu listing suite, the mood catalog's coverage, and the event-content sweep

Run `filesystem_manage(op="scan")` after the new `class_name` files, or none of `SuitRules`, `PawnSuitComponent`, `Finder_Airlock`, `Action_ChangeSuit` or `JobDriver_ChangeSuit` will resolve.

**Docs after landing:** `CLAUDE.md` (trigger/hint counts, a sentence under *Pawns* on suit supply and the airlock rule) and [[01_Technical_Specification]] (the pawn section, the WI-60 thermal section, the jobs list).

## Implementation order

1. **`SuitRules` + `test_suit_rules.gd`.** The item is one classification and one decision table; pin both before anything reads them.
2. **`TierData.suits_mandatory` + `UnlockManager.suits_mandatory()`.**
3. **`PawnSuitComponent`**: state, decision, hold, the airlock entry case, save — plus **suit supply** into breathing and temperature. No trips, no sprites, no mood yet: at this step Tier 1 is already finished and verifiable with `dump_suits`, `set_o2` and `set_temperature`.
4. **The job**: finder, driver, action, `.tres`, and both entry points. This is the risky step and the one the probe exists for.
5. **Mood and warnings**: `suit_indoors`, the suit-up alert, the Tier 1 gates, the promotion latch clear.
6. **Sprites.** Extract first as a pure refactor with a before/after shot, then the helmetless set, `set_sprite_frames()`, the visitor scene. **Settle the tint question (§10) here.**
7. **The sleep term, the inspector (§11), and the breach condition (§12)** — three small independent changes.
8. **The Heater**: power link, thermostat, save, the stepper row, scene, data, unlock, then the balance measurement.
9. **The hint**, including the promotion sentence.
10. **Cheats, screenshots, docs.**

## Edge cases

- **The airlock-distance balance is now the item's central risk.** Too far and a breach is a massacre; too close and nothing is at stake. `harm_hold_hours`, the walk speed and the harm rates are the levers, and none of them can be judged except by playing a station that was not built with this rule in mind — which is exactly what an existing save is.
- **Cold corridors** (WI-60 flagged them: maximally exposed, thermally light) now suit crew up *and* hurt them on the way. This compounds with the point above; the heat overlay is what shows it, and the Heater is what fixes it.
- **A pawn already suited walks through anything safely**, which is what stops the suit-up trip from being a death sentence in a cascading failure: the first trip is dangerous, everything after it is not, until the hold expires.
- **Oscillation** is prevented in three places, and all three are needed: `TOLERABLE` keeps the current state, taking a suit off needs the pawn's *own* room habitable (§2), and `_trip_cooldown` throttles a refused change.
- **Turbolift rides**: a `CONVEYED` pawn decides nothing. Verify in the probe that a ride never reads as outside; if it did, the symptom would be a helmet flicker, since outside sets no hold.
- **Construction sites**: stepping into an adjacent blueprint nulls `current_module`, so the pawn is outside and suited; stepping back in needs no airlock, because no hold was set. The airlock clause only matters when there is a hold to cut short.
- **Going out** through an airlock never triggers the entry case; only coming in does.
- **Hires at Tier 2+** are placed straight into the docking bay by `spawn_crew`, never outside. They arrive suited with no hold and queue a trip if the bay is habitable — no docking-bay special case.
- **A crew member who cannot reach any airlock** keeps the suit (safe) or cannot get one (dangerous). Both states are reported by the alert and by `dump_suits`, and both are layout problems the player can see.
- **An airlock demolished mid-trip** fails the job through the standard target-aliveness path; the cooldown then re-runs the decision, which finds another airlock or none.
- **Pause**: everything rides `slow_tick`, signals and the job runner, so holds and trips freeze. Nothing here touches `TimeManager.paused`.
- **The Spacer trait** keys on `current_module == null`, unchanged: a Spacer outside is suited and happy; inside in a suit, they take the −10 like anyone.
- **Void Sickness** accrual keys on being outside, unchanged. Suits do not affect disease indoors (§0.10).
- **Visitors** keep today's behaviour exactly and are now the only pawns the health-drain paths and the `pawn_temperature` alert reach.
- **Robots** carry no suit component; **the inspector** carries the static form only (§11).
- **A module finishing construction underfoot** reads `UNKNOWN` and changes nothing — the reason `UNKNOWN` is not `HARMFUL`.

## Verification

1. **GUT**, pure (construct directly, never touch `Global`):
   - `test_suit_rules.gd`: classification boundaries at O2 24.9/25/39.9/40 and 19/20/39/40/90/91/110/111 °F; the agreement sweep pinning `HARMFUL` to `HeatMath.harm_per_hour > 0` or O2 below the damage partial across −100…400 °F; every row of §2's table; hysteresis in both directions in `TOLERABLE`; the hold set, refreshed, decayed, not refreshed outside, and cleared by a `HABITABLE` airlock only; taking a suit off requiring the pawn's own room habitable; `suits_mandatory` winning over everything; the mood never applying at Tier 1 or outside; `UNKNOWN` changing nothing.
   - `test_crew_frames.gd`: both `.tres` agree on animation names, frame counts, speeds and loop flags, and every helmetless frame path contains `noHelmet`.
   - The tier ladder: `tier_1.tres` mandatory, `tier_2.tres` not.
   - Tutorial suites: the trigger declared *and* watched, the cue resolving, `console:overlay` and `console:rnd` parsing to real modes.
   - The build-menu suite: the heater listed at Tier 2, absent at Tier 1.
   - The event sweep: `micrometeorite_strike` carries the min-tier condition and reports not-met at Tier 1.
2. **Headless probe** (a temporary autoload running a numbered checklist, deleted after):
   - New game: both crew suited, no `suit_indoors`, suited frames, **and no `change_suit` job ever posted** — Tier 1 adds no behaviour at all.
   - Tier 1: breach one module and freeze another. No low-O2 alert, no temperature alert, no amber chip, no health lost, no trips. Fire `micrometeorite_strike` by id: it is refused.
   - `tier_up`: crew in habitable rooms queue trips and are unsuited **after reaching an airlock, not before**; crew in a `TOLERABLE` room stay suited at −0.10; already-thin rooms raise one coalesced row; `habitable_interior` is spent and transmitted; the promotion transmission carries the extra sentence and the Tier 3 promotion does not.
   - Vent the room an unsuited crew member is working in: the current job is interrupted, a `change_suit` job starts, one HIGH alert is raised, **health actually falls during the walk**, and the suit goes on at the airlock. Then: hold 2 h, no second trip, and the suit comes off only after the hold expires *and* their room is habitable again.
   - The same with **every airlock demolished**: no job, the alert says so, and the pawn keeps taking damage — the layout failure is observable rather than silent.
   - Walk a suited pawn out through an airlock and back in through a habitable one: the suit comes off **in the airlock**, inside the hold. Back in through a `TOLERABLE` one: it stays on.
   - Save mid-walk **and** mid-change, reload: the trip resumes, the suit is not flipped twice, `suited`/hold round-trip, and `suit_indoors` is **absent from the JSON** and back within a tick. A save with every `"suit"` block stripped loads and re-decides.
   - A Tier 2 hire delivered to a habitable bay ends up unsuited via a trip. A visitor in a freezing room takes harm as before and never suits.
   - Tier 1 inspection with a vented station: **passes** (§11). Tier 2 inspection with a vented station: still fails, as WI-26 intends.
   - Heater: unpowered emits nothing; powered emits; the thermostat **cycles** around its setpoint rather than running flat out; the setpoint round-trips through a save. The 34-body station with two heaters settles in band.
   - A Tier 2 save with a tutorial section lacking the hint fires it once on load; a save with no tutorial section does not.
3. **Screenshots, driven into the state under test:**
   - helmeted and helmetless crew side by side **across a spread of tints** (§10's open question);
   - every animation both ways, `lay_down` in a bunk and `interact_back` at a workstation included;
   - a crew member mid-emergency: the alert row, the job report in the inspector, the walk;
   - the Needs tab with `suit_indoors` and its cause;
   - the hint with the coach ringing Overlays then R&D;
   - the Heater's thermostat row in the Status tab at two setpoints, and the heat overlay across a station with two heaters.
4. **By hand, and this is the one that matters:** load a station built **before** this rule existed, promote it, and breach something far from an airlock. If nobody is in danger, the thresholds are too kind; if the crew die faster than the player can understand what happened, the alert or the hold is wrong. Then play Tier 1 through to promotion without thinking about air or heat once, and check that the transition reads as a new expectation rather than as a bug.

## Open questions

- **A temperature flee.** O2 has one (idle crew leave a room below 35 before it reaches the damage partial at 25); heat has no equivalent, so the first response to cold is the suit trip. A mild temperature flee would make the two symmetrical.
- **Airlock throughput.** No claims and no slots (§4). If twenty crew filing through one airlock at promotion reads badly, the fix is a queue anchor rather than a slot limit.
- **A suit-up trip while already carrying cargo.** The interrupt cancels the current job; the standing invariant keeps the goods on the pawn for the `store_inventory` sweep. Worth watching that an emergency does not scatter a haul chain.
- **Should a suit come off automatically on going outside?** It must, and does. The inverse — a pawn who *needs* to go outside for an EVA job while unsuited — already works, because going outside means `current_module == null`, which the rule answers with "suited" before the trip begins. Whether that should instead be a visible airlock stop on the way out is a fidelity question, not a correctness one.
- **Suits and airborne disease** (§0.10), deferred to future disease/health work.

## Related

- [[WI-17_Life_Support_Oxygen]] — suit supply as a null module, the flee rule this item's interrupt deliberately departs from, the low-O2 alert and its latch.
- [[WI-60_Heat_System]] — the thermal network, `HeatMath`'s bands, the harm rate `HARMFUL` must agree with, the pawn-side alert, `HeatEmitterComponent`, and the cold-station question the Heater answers.
- [[WI-44_Job_System_Refactor]] — `JobData` + driver + actions, the personal queue vs the board, and the `on_resume` contract `Action_ChangeSuit` has to honour.
- [[WI-63_Tutorial]] — hints as two files, declared triggers, spent-once watchers, the coach's target grammar, "an already-true condition returns immediately".
- [[WI-26_Station_Tiers]] — `TierData`, `station_tier_changed` (including its emit on load), and `InspectionRunner`'s harm-fails-the-run rule that §11 narrows.
- [[WI-13_Events_v1]] — `EventCondition`, which §12's min-tier gate joins.
- [[WI-22_Pawn_Identity]] — the tint that now falls on faces.
- [[WI-47_Modding_Support]] — component save hooks instead of a `SaveManager` edit, pawn kinds, and scan-don't-register for the new job type.
- [[WI-48_Pawn_Interactions]] — *carries the component = participates*, and derived INF mood modifiers.
- [[WI-45_Save_System_Audit]] — an unsaved alert latch costs one duplicate warning.
- [[WI-49_UI_Design_System]] / [[WI-55_Panels_Trade_And_RD]] — the `Stepper` and its commit rule, which the thermostat uses.
- [[WI-52_Vitals_And_Ledger]] / [[WI-53_Alerts]] — the OXYGEN chip, alert tiers, the amber budget, coalescing.
- [[WI-54_Panels_Build_And_Overlays]] — the listing rule that hides the Heater at Tier 1 and why the hint cannot point at the Life Support category.
- [[New Work for Phase 4]] — the source brief.
