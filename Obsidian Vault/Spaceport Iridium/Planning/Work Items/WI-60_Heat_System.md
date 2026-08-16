# WI-60 — Heat System

## Goal

Give station **layout** a second meaning. Today the only spatial pressures are pathing distance and WI-30's adjacency fields; a forge is as happy buried in the middle of the station as bolted to the edge. After this item every module has a **temperature**, heat flows between physically-attached modules and bleeds to space through exposed faces, and three systems care about the result: hot machines throttle themselves, cold and hot rooms rest crew badly, and crew who live outside 40–90 °F get miserable and then get hurt.

Four deliverables:

1. **A thermal body per module**, exchanging heat over the structure graph and radiating to space through its open faces.
2. **Heat sources**, either constant (the starting module's trickle) or proportional to work actually done (the forge, the ore processor).
3. **Heat consequences** — a throttle on hot machinery, a comfort term on sleep, a mood modifier and a health drain on crew.
4. **A Radiator module** and a **heat overlay**, so the player can both fix the problem and see it.

The brief calls heat "a new station-wide adjacency system", and it is adjacency-*shaped* — but §1 explains why it cannot live in `AdjacencyManager`, and that distinction is the single most load-bearing decision in this item.

## Design

### 1 — Heat is a stored quantity that flows, not a field that is derived

`AdjacencyManager` (WI-30) is the wrong home for heat and cannot be made into the right one. Its fields are **pure derived state**: recomputed from scratch on every topology change, never saved, with a receiver's level a closed-form sum of `intensity × falloff^hops`. That model has no memory. Heat has nothing *but* memory — a forge shut off an hour ago leaves a warm room, and a module's temperature right now is the integral of everything that has happened to it. Retrofitting that into a system whose whole correctness argument is "throw it away and rebuild it" would destroy the property WI-30 depends on.

The right precedent is **`AtmosphereManager`** (WI-17), which is the same kind of thing: a conserved quantity, held per module in a runtime-attached component, relaxed pairwise toward equilibrium on a tick, saved because it is real state. Heat copies its shape almost exactly, with three deliberate differences:

| | Atmosphere (WI-17) | Heat (this item) |
|---|---|---|
| Graph | **Path** graph — gas moves through doors | **Structure** graph — heat conducts through plating |
| Who has one | Interior modules only (`has_atmosphere` + a `PathComponent`) | **Every placed module**, truss and exterior hardware included |
| Sink | Only a hull breach | Every exposed face, continuously |

The structure graph is what makes a **Radiator** possible at all: it hangs on the outside of the station, has no atmosphere and no interior, and still has to be plumbed into the thermal network. It is also what makes **truss conduct** — the same call WI-30 made, for the same reason (they are physically attached), and it has a real gameplay consequence worth designing for rather than around: a truss spine is a superb heat path *and* a huge radiator, so truss-heavy stations run cold.

### 2 — `HeatManager` and `HeatComponent`

**`HeatManager`** (`scripts/managers/heat_manager.gd`, `Global.heat_manager`), a node in `main.tscn` under `Managers/` placed **after `StructureManager`** (it reads that graph) and, as always, before `SaveManager`. It mirrors `AtmosphereManager`: attaches a component to every eligible module on `module_added`, subscribes to `slow_tick`, and runs the exchange pass.

Eligibility is one rule in one place, as WI-17 established: **any module that is on the structure graph gets a thermal body.** No `has_heat` flag, no per-scene wiring — a modded module joins the thermal network for free, which is the WI-47 bar.

**`HeatComponent`** (`modules/components/heat_component.gd`), runtime-attached exactly like `AtmosphereComponent` (the manager sets `owner_module` before `add_child`, and the component re-registers itself into `owner_module.components` because runtime nodes have no scene `owner`). It holds:

- `temperature_f: float` — the state, in **degrees Fahrenheit**. One unit, everywhere. Every threshold the brief specifies is in °F, the readout is in °F, and a second internal unit is two places to get a conversion wrong for zero gameplay gain.
- `thermal_mass()` — `cells × ModuleData.heat_thermal_mass_per_cell`, the direct analogue of `AtmosphereComponent.volume()`. Bigger and denser modules change temperature more slowly.

Registration follows the atmosphere lifecycle precisely: `ready_constructed` registers, `ready_preview` / `ready_blueprint` / `_exit_tree` unregister. **A blueprint is not a thermal body** — a construction site is a frame, not a room.

### 3 — The exchange pass

On `slow_tick`, accumulate sim-hours and run a pass every `pass_interval_hours` (default **0.25 game-hours**). This is the one place heat deliberately diverges from atmosphere's tick shape: `slow_tick` fires at 4 Hz *sim-time*, which at `SECONDS_PER_HOUR = 10` is **40 ticks per game-hour**, and heat covers every module rather than only the pressurised ones. A process the brief measures in hours does not need 4 Hz resolution, and the accumulator buys a ~40× reduction in pass count for no observable difference. The relaxation math is step-size independent, so the interval is a pure performance knob.

Each pass does three things, in order:

**Conduction.** For every structural edge between two registered components, move energy toward the pair's shared equilibrium — the reduced-mass form `AtmosphereManager._exchange_pair` already uses:

```
flow = (T_a − T_b) × (m_a·m_b / (m_a + m_b)) × step
```

with `step = min(conduction_rate_per_hour × hours, 1.0)`. Energy is conserved exactly, and a full step lands exactly on equal temperatures, so clamping at 1 can never overshoot. Edges are symmetric, so each unordered pair is processed once via the `module_id` comparison atmosphere already uses. `conduction_rate_per_hour` defaults around **1.5** — a pair equilibrates over a few game-hours, which is the brief's "hours, not cycles". (Atmosphere's 25 is an order of magnitude faster on purpose; air moves, steel does not.)

**Production.** Each `HeatEmitterComponent` (§4) adds its energy for the elapsed hours.

**Radiation to space.** Every module loses

```
loss = exposure × ModuleData.heat_radiation_mult × radiation_coefficient × (T − SPACE_TEMP_F) × hours
```

clamped so a pass can never carry a module *below* `SPACE_TEMP_F`. Linear in `(T − T_space)`, not Stefan-Boltzmann `T⁴`: the brief asks for "based on the amount of heat they have", linear is trivially tunable, and a fourth-power law would make the difference between 200 °F and 400 °F unbalanceable without also making the difference between 60 °F and 70 °F invisible.

`space_temperature_f` is a **balance knob, not physics** — around **−60 °F**, far enough below the habitable band that an unheated station freezes, close enough that the overlay ramp and the numbers on the Environment tab stay legible. Lowering it makes heating harder; that is its whole job.

**Exposure** is the fraction of a module's faces that touch nothing, and that number already exists — `SolarPowerComponent` computes it as `(connection_points.size() + 1 − non_cross_layer_connections) / (connection_points.size() + 1)`. Extract it to `StructureComponent.open_face_fraction()` (delegating to a pure `HeatMath.exposure_fraction`) and have `SolarPowerComponent` call that instead, so two systems cannot drift on what "surrounded" means. A pinning test asserts today's solar scaling numbers before the extraction and after it.

**The `+ 1` is the module's implicit back face, and it is load-bearing for both consumers.** It is what makes a solar panel boxed in on all four sides still generate *something*, and — the reason it matters here — what makes a fully enclosed module still radiate *something*. It puts a hard floor of `1 / (connection_points.size() + 1)` under exposure, which for a typical four-face module is 20%.

That floor is what structurally satisfies the brief's "come to equilibrium instead of heating up forever": a forge sealed in the middle of the station does not climb without bound, it settles — just five times hotter than the same forge on the hull. Document this on the extracted function; it is not an off-by-one to be tidied away later, and deleting it would reintroduce an unbounded temperature for exactly the layout a player is most likely to build by accident. If a boxed-in forge reads as *too* survivable in play, the lever is `radiation_coefficient` (which scales the whole curve), never the floor.

### 4 — Producing heat: `HeatEmitterComponent`

Authored in the scene, like `AdjacencyEmitterComponent` and for the same reason (balance lives in data). Two knobs, and a module may use either or both:

- `idle_heat_per_hour: float` — constant output while the module is Built. The starting module's small heater, a reactor's standing waste heat.
- `heat_per_batch: float` — energy released per completed batch of work, when `processor: ProcessorComponent` is linked.

Both route through `owner_module.get_effective_stat(&"heat_output", …)` so an upgrade can tune them.

**`heat_per_batch` is measured in batch-fractions, not seconds, and that is the whole trick.** `ProcessorComponent` gains one accumulator, incremented in exactly the two places that already advance a batch (`_stepwise_processing` and `advance_work`):

```gdscript
_work_accumulated += delta / get_process_time()   # fraction of a batch
```

The emitter reads and **drains** it each pass. This satisfies both halves of the brief's forge requirement *by construction rather than by a second formula that can disagree with the first*:

- "only produce heat while working" — the accumulator does not move when the processor is unpowered, out of inputs, out of output space, or waiting for a worker.
- "produce heat proportional to how much it produces" — a heat throttle (§5) multiplies `process_time` **up**, so the same wall-clock second buys a smaller fraction of a batch, so it emits proportionally less heat. The negative feedback loop closes itself, with no code anywhere that knows it is a loop.

Wiring a mining rate or a power output to the same accumulator shape later is a scene edit; v1 wires only the processor.

Authored emitters in v1: **forge** (large `heat_per_batch`), **ore processor** (moderate), **fusion reactor** (idle), **starting module** (a small idle trickle — the brief's requirement that the founding crew do not freeze in hour one).

### 5 — Being affected by heat

**Throttle (machines).** `HeatComponent` writes a reserved `&"heat"` `StatModifiers` source on its owner — joining `DAMAGE_SOURCE`, `BREAKDOWN_SOURCE` and `ADJACENCY_SOURCE` on `ModuleBase`, and stacking with them independently, which is exactly why those are separate named sources. It sets `process_time` MULT ≥ 1, ramping smoothly from `heat_throttle_start_f` to `heat_throttle_full_f`, and **removes the source entirely** below the start temperature so an ordinary module's effective stats are byte-for-byte its base values.

The ramp is a lerp, never a step, and `heat_throttle_max_mult` is finite (default ~4×, never ∞). A binary cutoff plus §4's feedback loop is an oscillator: cut production at the threshold, cool below it, resume, overshoot, repeat, with the player watching a machine stutter once a second.

Which modules throttle is authored on `ModuleData` — `throttles_when_hot: bool` gating `heat_throttle_start_f` / `heat_throttle_full_f` — following `maintenance_breakdown_k`'s precedent, because `HeatComponent` is runtime-attached and therefore has nowhere to carry per-module tuning. The bool means the ninety-odd modules that do not care carry one unchecked checkbox rather than two meaningless numbers.

**Comfort (sleep).** `SleepComponent.environment_rest_multiplier()` already owns "what my surroundings do to rest"; it gains a temperature term rather than a second function. Knobs (`comfort_low_f`, `comfort_high_f`, `temperature_penalty_k`) go on the component, which *is* authored per scene. `desirability()` gains the same term, so a pawn choosing between two free bunks prefers the comfortable one — which is what makes the player's insulation decisions legible without a tutorial.

The comfort curve itself lives in `HeatMath` (§7) so the recreation providers can adopt it in one line later. **They do not in v1** — sleep is the module the brief names, and one consumer is enough to prove the shape.

**Crew.** New `PawnTemperatureComponent` (`pawns/pawn_temperature_component.gd`), on `crew_pawn.tscn` and `visitor_pawn.tscn`. On `slow_tick` it reads `owner_pawn.current_module`'s `HeatComponent` and bands the result:

| Band | Range | Effect |
|---|---|---|
| Comfortable | 40–90 °F | nothing |
| Uncomfortable | 20–39 / 91–110 °F | mood modifier |
| Dangerous | < 20 / > 110 °F | mood modifier **and** health drain, ramping with distance past the threshold |

Three exclusions, and **all three fall out of existing rules rather than adding a check**:

- **Robots are immune** because `RobotPawnBase` does not carry the component. This is WI-48's "carries this component = participates" rule, and it stays exactly one rule — no `is_robot` anywhere.
- **Pawns in space are immune** because `current_module == null` means suit supply, which is precisely how `PawnBreathingComponent` already reads EVA.
- **Visitors are included** deliberately: they carry needs, and a guest freezing in your lobby is feedback the player should get.

Mood is **one INF-duration modifier at a time**, `&"too_cold"` or `&"too_hot"`, and setting either clears the other so they can never both be live. Derived state — **not saved**, re-derived on the first tick after load, the `&"company"` precedent. It also has to clear when the pawn steps outside; a pawn who walks into the void must stop being cold, and the null-module branch is the one that has to remember to say so.

Health drain is exposed as a rate the way suffocation is exposed as a flag: `PawnHealthComponent` gains it as a fourth decay source alongside starvation, suffocation and disease, under the same exclusivity rule (any active source suppresses passive regen; multiple sources stack).

`MoodCatalog` gains `&"too_cold"` / `&"too_hot"` entries with two new cause constants (`CAUSE_COLD` = "while cold", `CAUSE_HOT` = "while hot"). Without them the Needs tab would fall back to a capitalised id — which is the *correct* failure mode and by design never hides the row, but "Too cold" with a blurb and a cause is what the player deserves.

**Alerts.** One HIGH alert, raised **from the pawn side**, not the module side: a forge at 400 °F is working as intended and must never light the strip, while a crew member being harmed is exactly "look at this now". Latched with a re-arm margin like `AtmosphereManager._low_o2_alerted`, coalescing plural `"%d crew are dangerously cold"`, and **not saved** (WI-45 A7: the latch only suppresses a repeat, so a load costs one duplicate warning about a crew member who is genuinely still freezing). Never CRITICAL — this does not pause the sim.

**No vitals chip.** A station-average temperature is a number that lies: one forge at 400 °F and forty rooms at 65 °F averages to something reassuring. The overlay answers "where", the Environment tab answers "how much", and the alert answers "now". Adding a seventh pinnable chip that can be simultaneously accurate and wrong is worse than adding nothing.

### 6 — The Radiator, and the overlay

**Radiator** — `modules/life_support/radiator.tscn` + `data/modules/life_support/radiator_mdata.tres` + an `industrial_tree` unlock entry (you unlock the forge; you need its counterweight). It needs **no new component**: it is a module with a large `ModuleData.heat_radiation_mult` (~12), and §3's radiation term already scales by exposure. "Eliminates heat based on the number of free spaces around it, like a Solar Panel" is therefore the *same formula every module already runs*, with one number turned up — which is the "new features = new `.tres` data, not new class hierarchies" rule paying out.

Passive (no power draw) with a per-cycle upkeep, on the grounds that a radiator is a fin. Making it a powered pump is a one-line scene change if it plays as too cheap.

**Overlay** — a sixth `OverlayController.Mode`, `HEAT`:

- `OverlayPalette.heat_color(temp_f)`, a **diverging** ramp: `_COOL` (already in the palette) → `_GOOD` at the habitable band → `_BAD`, via the existing `gradient3` with temperature mapped across `[cold_ref, hot_ref]` so the comfortable band lands mid. `MODE_HEAT` legend key, stops produced by calling `heat_color` at representative temperatures (WI-54's rule: the swatch beside "habitable" is the tint a habitable module gets), and a note naming the 40–90 °F band.
- A sixth `ListRow` in the panel. `PANEL_OVERLAYS_WIDTH` is unchanged at 360 — one more row is vertical.
- A new `overlay_heat` input action on **`6`** (physical keycode 54, currently unbound; the existing five sit on 1–5 and clear on 0). It must be added to **both** `Global.REMAPPABLE_ACTIONS` and `Global.ACTION_LABELS` — `test_keybinds.gd` fails on an action declared in `project.godot` and classified in neither list, which is exactly the guard WI-58 built it to be.
- No new signal wiring in `_setup_signals`: temperature changes continuously, so the existing `slow_tick` full-pass refresh already covers it.

**Environment tab** — `ModuleEnvironmentTab` gains a temperature line **above** the adjacency rows, and unlike those rows it prints the real number. The tab's own comment explains why the field levels are rendered as severity words ("a propagation strength with no units the player could interpret"); temperature is the opposite case — °F is a unit the player has had since childhood, so it prints `72°F`, the band word, and the throttle percentage when the module is throttled, following the tab's existing "a severity word is a hint, `+8%` is an answer" rule.

### 7 — Pure math in one place

`scripts/utility/heat_math.gd` (`class_name HeatMath`), all static, no `Global` / `SignalBus`, per the standing rule:

- `exchange_flow(t_a, mass_a, t_b, mass_b, step) -> float`
- `space_loss(temp_f, space_temp_f, exposure, coefficient, hours) -> float`
- `exposure_fraction(connection_points_count, connected_count) -> float`
- `throttle_multiplier(temp_f, start_f, full_f, max_mult) -> float`
- `comfort_multiplier(temp_f, low_f, high_f, k) -> float`
- `band(temp_f, tuning) -> Band` (enum: `FREEZING, COLD, COMFORTABLE, WARM, SCORCHING`)
- `mood_offset(temp_f, tuning) -> float`, `harm_per_hour(temp_f, tuning) -> float`
- `band_label(band) -> String` and `format_temperature(temp_f) -> String` — **the one place a temperature becomes a word, and the one place it becomes a string.** Three surfaces render temperature (the tab, the overlay legend, the alert), and `PawnStatus` / `StoresModel` are the precedent for what happens when they each answer separately.

Balance numbers stay as exports on the manager, the components and `ModuleData`, and are *passed into* these functions, never read from inside them.

### 8 — Save

`HeatComponent` implements the WI-47 component hooks — **no `SaveManager` edit**, which is the point of that refactor. Key `&"heat"`, `save_order()` **65** (free between atmosphere's 60 and the O2 generator's 70; nothing orders against it, because a temperature depends on no other component's restored state). One float. `PawnTemperatureComponent` saves **nothing** — every value it holds is derived from the module it is standing in.

`SAVE_VERSION` does not move. Additive and backward-compatible — with one trap that has to be handled deliberately:

**A pre-WI-60 save has no `heat` block per module, and the obvious reading of a missing block ("start at space temperature") would load every existing save into a station whose entire crew immediately begins freezing to death.** A missing block therefore seeds at the **comfortable midpoint** (~65 °F), and the station drifts to its real equilibrium over the following hours. The player gets a station that behaves plausibly and then gets interesting, rather than a death spiral they did nothing to cause.

The same question applies to a **newly built** module in a live game, and the answer there is different: it seeds at the **mean temperature of its already-built structural neighbours**, falling back to `space_temperature_f` when it has none. Not conserving energy at that instant is correct — placement adds mass to the station, it is not a leak — and the alternative (every new corridor briefly chilling the block it was added to) is a nuisance with no gameplay in it. New-game seeding gets the same treatment `AtmosphereManager.seed_starting_atmosphere()` gets: the starting station begins habitable.

### 9 — Cheats

Per the standing rule, each emits its `station_alert` "CHEAT: …":

- `set_temperature(cell, degrees_f)` — force one module's temperature.
- `heat_station(degrees_f)` — set every registered module, for reaching an extreme without waiting.
- `dump_heat()` — one line per module: temperature, thermal mass, exposure, net flux, and its throttle multiplier if any. The debugging tool this item will actually live on.

## Files to touch

**New**
- `scripts/managers/heat_manager.gd` (`class_name HeatManager`) + a `Global.heat_manager` slot + a node in `main.tscn` after `StructureManager`
- `modules/components/heat_component.gd`
- `modules/components/heat_emitter_component.gd` + `.tscn`
- `pawns/pawn_temperature_component.gd`
- `scripts/utility/heat_math.gd` (`class_name HeatMath`)
- `modules/life_support/radiator.tscn` + `data/modules/life_support/radiator_mdata.tres` + an `data/unlocks/industrial_tree/` entry
- `tests/unit/test_heat.gd`

**Changed**
- `data/modules/module_data.gd` — `heat_thermal_mass_per_cell`, `heat_radiation_mult`, `throttles_when_hot`, `heat_throttle_start_f`, `heat_throttle_full_f`
- `modules/templates/module_base.gd` — one line: the reserved `HEAT_SOURCE := &"heat"` stat-source id, beside the other three
- `modules/components/processor_component.gd` — the `_work_accumulated` batch-fraction accumulator and its drain accessor (two increments, one getter)
- `modules/components/structure_component.gd` — `open_face_fraction()`
- `modules/components/solar_power_component.gd` — call it instead of computing its own
- `modules/components/sleep_component.gd` — the temperature term in `environment_rest_multiplier()` and `desirability()`, plus its three comfort exports
- `pawns/pawn_health_component.gd` — temperature as a fourth decay source
- `pawns/crew_pawn.tscn`, `pawns/visitor_pawn.tscn` — the new pawn component
- `scripts/utility/mood_catalog.gd` — `too_cold` / `too_hot` entries + two cause constants
- `ui/overlay_palette.gd` — `heat_color`, `MODE_HEAT`, legend stops and note
- `ui/overlay_controller.gd` — `Mode.HEAT`, the row, the hotkey entry, the legend key
- `ui/inspector/tabs/module_environment_tab.gd` — the temperature line
- `project.godot` — the `overlay_heat` action on `6`
- `scripts/managers/global.gd` — `overlay_heat` in `REMAPPABLE_ACTIONS` **and** `ACTION_LABELS`
- `scripts/utility/cheats.gd` — the three cheats
- Module scenes gaining emitters: forge, ore processor, fusion reactor, starting module
- `tests/unit/test_overlay_palette.gd`, `tests/unit/test_keybinds.gd` — extended, not rewritten

Remember `filesystem_manage(op="scan")` after the new `class_name` files, or `HeatMath` won't resolve.

## Implementation order

1. **`HeatMath` + `test_heat.gd` first.** The whole item is eight formulas and they are worth pinning before anything reads them. Green here means nothing later can move the physics by accident.
2. **`StructureComponent.open_face_fraction()` + the `SolarPowerComponent` extraction**, with the pinning test written *before* the move. A pure refactor with no heat in it; the game is identical at this step.
3. **`HeatManager` + `HeatComponent`: conduction, radiation, save, seeding.** No sources and no consequences — every module sits at whatever it was seeded at and cools toward space. Verifiable end to end from the cheat console with `dump_heat`, and this is where the conservation and equilibrium claims get proven.
4. **`HeatEmitterComponent`** + the processor accumulator + the four authored scenes. Now the station has hot and cold places.
5. **Consequences**, cheapest first: the module throttle, then the sleep comfort term, then the pawn component (mood, then harm, then the alert).
6. **The Radiator**, which is a `.tres` plus a scene once step 3 exists.
7. **Overlay, Environment tab, cheats, screenshots.**

## Edge cases

- **A pre-WI-60 save** seeds at the comfortable midpoint, not at space temperature (§8). Verify by loading a save made before this item and confirming nobody starts freezing.
- **Corridors and truss are cold.** They are maximally exposed and thermally light, and a pawn's temperature is read from `current_module` — so a long exterior corridor may harm crew walking down it. This is intended pressure but it is the **balance risk of the item**; the 40–90 °F band's leeway exists partly to absorb it. Tune `heat_thermal_mass_per_cell` on corridors before tuning the band.
- **Stacked layers.** A corridor and a MODULE-layer module can occupy one cell; both are structural vertices, so both get thermal bodies and exchange across the cross-layer edge. Two bodies in one cell is correct and cheap — note it so nobody later "fixes" it.
- **Throttle oscillation.** Prevented by the smooth ramp and the finite `max_mult` (§5). Watch for it anyway with a forge sealed in an unradiated box; a stuttering progress bar is the symptom.
- **A module both throttled and damaged and broken down.** Three separate named `StatModifiers` sources, compounding by design. `process_time` is the stat all three write, which is exactly why they are three sources and not one.
- **Deconstruction sites.** `ready_deconstructing()` should drop the module off the thermal network the way WI-39 drops it off the power grid; a teardown site is not a live part of the station.
- **A module removed mid-pass.** The pass iterates registered components; `_exit_tree` unregisters. Its stored energy is simply gone — heat is not a resource and the no-silent-resource-loss invariant does not reach it.
- **The station splits in two.** Two disconnected structural components equilibrate independently, which is correct and needs no code.
- **Fully enclosed modules still radiate**, at the `1 / (n + 1)` back-face floor (§3). A sealed forge equilibrates hot rather than climbing forever, which is the brief's requirement met by the geometry rather than by a clamp. The extraction is the one moment this could be lost, so it is pinned by a test.
- **Zero `connection_points`** (some exterior hardware): the same `+ 1` makes exposure 1.0 rather than dividing by zero.
- **Pause.** Everything rides `slow_tick`, so a paused station's temperature is frozen. Nothing here may ever touch `TimeManager.paused`.
- **Load ordering.** Temperatures restore per module with no cross-module resolution needed, and no pass can run mid-load because `slow_tick` has not fired. The pawn mood modifier re-derives on the first tick.
- **Difficulty (WI-37).** No hook in v1. If it wants one later, `space_temperature_f` is the single knob.
- **Modded modules** join the thermal network with no wiring (§2) at the `ModuleData` defaults — which means a mod that authors nothing gets a plausible thermal body rather than an inert one. Confirm against the sample mod.

## Verification

1. **GUT** (`test_heat.gd`, pure — construct directly, never touch `Global`): `exchange_flow` conserves energy exactly and lands on equal temperatures at `step = 1` with no overshoot at any mass ratio; `space_loss` never carries a module below `space_temperature_f` even at absurd hours; `exposure_fraction` at no faces connected, some connected, and **all** connected — the last asserting the `1 / (n + 1)` back-face floor explicitly rather than just "greater than zero" — plus the zero-`connection_points` case; `throttle_multiplier` is 1.0 below the start, continuous at both ends, and capped; `comfort_multiplier` is exactly 1.0 across the whole comfortable band and continuous at its edges; `band` boundaries at 19/20/39/40/90/91/110/111 °F; `mood_offset` and `harm_per_hour` zero inside the band and monotone outside; `band_label` and `format_temperature` output. Plus the **solar pinning test** from step 2, and the extended overlay-palette and keybind suites.
2. **Headless probe** (the standing fallback whenever MCP is down, and the pattern every item since WI-30 has used — a temporary autoload running a numbered checklist against `main.tscn`, deleted after):
   - A two-module station, one seeded hot and one cold, with production and radiation disabled: assert total energy is **identical** before and after fifty passes, and that the two temperatures converge.
   - A forge in a sealed box **climbs and stalls at a finite equilibrium** rather than rising without bound — the back-face floor (§3), and the check that would catch someone "simplifying" the `+ 1` away. The same forge with a Radiator attached equilibrates lower; the Radiator walled in on every face drops to roughly its floor share of that effect rather than to zero.
   - The forge's own throttle: assert `process_time`'s effective value rises with temperature, that batches slow, and that **emitted heat per game-hour falls proportionally** — the §4 feedback claim is the one this design most needs proven.
   - Save mid-heat-up with a throttled forge and a freezing pawn; reload; assert every temperature round-trips, the throttle modifier re-derives, and the pawn's mood modifier is **absent from the JSON** and back within one tick.
   - Load a **pre-WI-60 save** and assert the station is habitable, not frozen.
   - A pawn walked from a 70 °F room into a 10 °F one and then outside: mood modifier appears, swaps, and **clears** on the null-module step; health drains only in the dangerous band; a hauler robot in the same room is untouched.
3. **Screenshots, driven into the state under test** — a standing requirement since WI-49, and every panel item in that program found defects a headless probe could not see:
   - the heat overlay across a station with a hot forge, a habitable core and a cold truss spine (the diverging ramp has to read as three distinct things at a glance, not as one muddy gradient),
   - the overlay legend and the six-row panel at 360px,
   - the Environment tab on a throttled forge, on a comfortable bunk room, and on a module with no adjacency fields at all (the temperature line must not look stranded),
   - the Needs tab of a crew member carrying `too_cold`, with its cause column reading "while cold".
4. **A full round trip by hand:** start a new game, confirm the founding crew are comfortable in the starting module, build a forge somewhere stupid, watch the room heat until the crew complain and the alert fires, bolt on a Radiator, and watch it come back. If that loop is not legible without opening the overlay, the balance is wrong even if every test is green.

## Related

- [[WI-17_Life_Support_Oxygen]] — the diffusion/relaxation model this copies, including the exact reduced-volume exchange and the runtime-attach-a-component-per-eligible-module shape.
- [[WI-30_Module_Adjacency]] — the system heat is *not* built on, and why (§1); also the source of `SleepComponent.environment_rest_multiplier()`, the Environment tab, and the truss-conducts rule.
- [[WI-24_Combat_Setup]] — the named `StatModifiers` source pattern the throttle joins, and `ModuleData`'s precedent for per-module balance fields.
- [[WI-35_UI_Overlays]] / [[WI-54_Panels_Build_And_Overlays]] — the overlay mode, the palette's legend-from-the-real-colour-function rule, and the panel row.
- [[WI-48_Pawn_Interactions]] — "carries this component = participates" as the only robot-exclusion rule, and the derived INF-duration mood modifier that is never saved.
- [[WI-45_Save_System_Audit]] / [[WI-47_Modding_Support]] — the component save hooks this uses instead of editing `SaveManager`, and the alert-latch-is-not-saved call.
- [[WI-58_UI_Rework_Fix_Pass]] — `test_keybinds.gd`, which fails on an unclassified input action.
- [[New Work for Phase 4]] — the source brief. **Star and Planet Variations** is the natural follow-on: a system's star is the obvious second heat *source*, and `space_temperature_f` is already the knob it would turn.
- [[01_Technical_Specification]] — needs a new §1.x for the thermal network, and §1.12's adjacency paragraph should gain a sentence saying heat deliberately is not one of its fields.
