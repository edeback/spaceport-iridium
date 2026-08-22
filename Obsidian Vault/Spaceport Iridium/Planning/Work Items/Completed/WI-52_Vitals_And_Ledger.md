# WI-52 — Vitals Strip & Resource Ledger

> **STATUS: COMPLETE, 2026-08-10.** Fourth item of the [[Spaceport Iridium/Planning/04_UI_Rework_Program]]. Depends on [[WI-49_UI_Design_System]] and [[WI-50_Console_And_Modes]] (this item fills the console's middle zone).
>
> **866 GUT tests green** (was 823; +18 in `test_resource_rate_tracker`, +25 in `test_ledger_grouping`). **52-check headless probe green** against the real `main.tscn`. Windowed 1920×1080 screenshots captured of the console strip with a falling amber vital, the open ledger, pin mode, the ledger coexisting with Build, and the HUD at rest. **Save adds one new section (`vitals`); absent key = the designed default six, so `SAVE_VERSION` did not move and pre-WI-52 saves load unchanged.** Closes **C13**.
>
> **Superseded (2026-08-22): the first column is `Category.BASIC`, labelled `BASIC`, not `RAW_ORE`/`RAW ORE`.** When `carbon_ore` was deleted and carbon became a directly mined resource, it moved out of REFINED into that column and the old name stopped describing it. Ordinals are unchanged, so no `.tres` was re-authored; the column now holds carbon plus the four remaining ores. §5 and the §4 column list below still print the old name.
>
> **Deviations from the design below, and why:**
>
> 1. **Pins save as one ordered list, not the design's `{"pinned": […], "derived": […]}` pair.** Order is part of what the player curated, and two lists cannot express a derived chip sitting between two resource chips — while the verification the item asks for is literally "restores the same ids in the same order". Derived entries carry a `derived:` prefix, which no resource id can collide with: base-game ids are hand-authored and a mod's must begin with its own `modid.` prefix ([[WI-47_Modding_Support]] M1).
> 2. **The refill target is the saved list's length, not the pin cap.** The design says an under-full strip "refills from the default order rather than leaving a gap". Applied literally that makes unpinning impossible — unpin `credits`, which is one of the defaults, and it comes straight back. So a shortfall refills only up to *what the save asked for*: six saved with one lost to a removed mod restores six; four saved deliberately restores four; an empty or absent list is the one case with no expressed intent and means the designed six. `toggle_pin` does not refill at all. Both failures were caught by the probe, not by inspection.
> 3. **`show_in_ledger` is a plain opt-out `bool`, not a derived default.** The design floated `has_global_store or tradable or is stored anywhere`. A derived default is unpredictable (a resource silently leaves the ledger when the last bin holding it is demolished) and still needs an explicit override for `stored_energy`, which is `has_global_store`-adjacent. Defaulting to `true` gets the modding requirement for free and puts the two exclusions in the two `.tres` files that want them.
> 4. **`LedgerModel.in_category()` returns one column per call rather than a grouped dictionary.** GDScript rejects nested typed collections outright — `Dictionary[Category, Array[ResourceData]]` is a parse error, not a style choice. Four calls over eighteen resources is not a cost worth an untyped return for.
> 5. **The rate tracker decimates inside `sample()`.** `slow_tick` is 4 Hz sim-time, so a cycle is 960 ticks; retaining all of them would be a 960-entry buffer per resource for no extra fidelity. `sample_spacing_hours` (0.25) drops anything that arrives too soon, so `ResourceManager` just calls it on every tick and the cadence stays one testable rule rather than a counter on the manager.
> 6. **`ResourceManager` now discovers resources rather than only reading its authored `storable_resources`.** A modded resource was in no manager's list, so it would never have recalculated, never accrued a rate, and never reached the ledger. It unions the authored array with a `ContentPaths.scan` of every registered root, mirroring what `SaveManager._build_lookups` already does.
> 7. **PIN MODE promotes its own button to the primary weight while on, and swaps every row's icon for a pin swatch.** The theme's secondary button has no distinct pressed state, so the toggle read as inert in both states — visible only in the screenshot, which is exactly what the program doc warns headless cannot catch. The swatch swap is the design's own wording ("PIN MODE turns each row's swatch into a pin toggle") and doubles as the affordance: outside pin mode eighteen rows must not look like eighteen controls.
> 8. **The CREW chip goes amber when heads exceed bunks, and the starting station has no bunks** — so a fresh game boots with one amber chip. Kept deliberately: it is a real, actionable warning (unrested crew resign) and it is the first thing a new station should be told to fix. Worth revisiting if [[WI-53_Alerts]] finds amber over-subscribed.
> 9. **Two small additions to WI-49's library, both additive.** `ListRow.set_action_color()`, because a sign-coloured right-hand metric is a recurring need the program doc already anticipated in `UIPalette.sign_color`'s own comment; and `ResourceData.average_instance_value()`, the station-wide counterpart of the per-bin richness figure the storage tab shows.
>
> **Traps found, for the WIs that follow:**
>
> - **Headless reports a 1920×1920 viewport, not the project's 1920×1080.** Any probe asserting an anchored control's absolute position must measure against `get_viewport().get_visible_rect()`, never `UIMetrics.SCREEN_SIZE`. A right-edge check passed and a bottom-edge check failed for this reason alone.
> - **`Callable.bind()` must be symmetric across connect and disconnect.** Connecting `handler.bind(x)` and disconnecting the bare `handler` silently no-ops — `is_connected` returns false and nothing errors. `VitalsStrip` rebuilds the same bound callable to disconnect with.
> - **Nested typed collections do not parse.** See deviation 4. The error (`Nested typed collections are not supported`) surfaces as a cascade of "Could not resolve class X" in every *consumer* of the file, which points at the wrong script entirely; `--headless --check-only --script <file>` on the suspect file is what finds it.
> - **A pre-existing `ConsoleBar` warning fires on every boot**: it counts its 1px group divider as a 70px button, so ten children "need 745px" in a 715px zone. Harmless, but it is noise that will mask a real overflow warning from a later panel.

## Goal

Split the resource readout in two: a **pinned vitals strip** in the console holding six resources the player curates, and a **ledger flyout** holding everything, grouped, with a per-cycle rate on every line (invariant 4).

The mockup's build-order note is a warning about sequencing: *"Do this before adding more resources, not after."* There are 20 `ResourceData` files today (18 real, plus `test_resource` and `stored_energy`) and the current strip hardcodes **five** of them as an `Array[ResourceData]` exported on `ui_main.tscn`, with credits and energy as separate bespoke widgets and a crew count `Label` appended in code. Every new resource is currently a scene edit or a nothing — it doesn't appear at all.

## Design

### 1 — Why pinning, and not "show all"

Invariant 4's real claim is that the layout must be *indifferent to the resource count*. A strip that grows is a strip that eventually wraps or shrinks its numbers below the 11px floor. Pinning moves the curation decision to the player and makes the strip's size a constant. The ledger is where completeness lives.

### 2 — The vitals strip

`ui/console/vitals_strip.tscn` + `.gd` (`class_name VitalsStrip`) — the console's flex zone. Each chip is 52px tall: an 12px colour swatch (or the resource's icon), the value in `Metric` 16px Mono with an optional `/max` in `TEXT_META` 13px, and the resource name in `ReadoutLabel` 9px.

Three chip kinds, because three things in the strip aren't plain resources:

- **Resource chip** — a `ResourceData` and its `get_total()`. Pinned; any resource can be one.
- **Derived chip** — `ENERGY 160/295` (`PowerManager` production vs. capacity, today's `energy_display_ui.gd`), `OXYGEN 98%` (station-average atmosphere), `CREW 2/4` (`CrewManager.crew_count()` over bunk capacity). These are computed, not stored, so they are **always available and separately pinnable** — they can't be entries in the ledger's resource list because they aren't resources.
- **Ledger chip** — the fixed right-hand `LEDGER · 30 ▸` control that opens the flyout. Always present, never pinned away, and it carries the tracked-resource count.

**Falling-vital treatment:** a chip whose value is dropping and below a threshold takes the amber row treatment — amber fill, amber border, `#f2c377` value, and a `▼` glyph. This is one of the four sanctioned uses of amber (invariant 5) and it is the reason the strip is worth having at all: `FOOD 12 ▼` in amber is the whole early-warning system. The threshold and the "falling" window are exported tuning on the strip, not constants.

**Fix C13 here.** `ResourceData.change_global_total` recalcs and emits `total_changed`; `force_withdraw` only sets `needs_recalc`, so hiring crew, paying off a raid, buying a module or purchasing an upgrade doesn't move the credit display until `ResourceManager`'s next slow tick. It self-heals within 0.25 sim-seconds and reads as UI lag. With credits as a first-class vital chip that lag is now on the most-watched number on screen, so the two paths get made symmetric.

### 3 — Rates: the piece that doesn't exist

Every ledger line and the falling-vital detection need a **per-cycle rate**, and nothing in the game tracks one. `ResourceManager` is 16 lines: it walks `storable_resources` on `slow_tick` and calls `_recalc_resource()`. There is no history, so there is no derivative.

`scripts/utility/resource_rate_tracker.gd` (`class_name ResourceRateTracker`) — pure, no `Global`, GUT-testable. A per-resource ring buffer of `(sim_hours, total)` samples with a fixed capacity, and `rate_per_cycle(id)` returning the least-squares slope over the window, scaled to a cycle.

Design constraints, each of which is a way this goes wrong if ignored:

- **Sim time, not wall time.** Samples are stamped with `TimeManager` hours. At 4× the same rate must read the same, and a paused game must not decay the rate toward zero.
- **A window long enough to be stable, short enough to be useful.** One cycle of samples at `slow_tick` cadence is the starting point; exported.
- **Least squares, not last-minus-first.** A single haul depositing 40 ore must not read as `+40/cyc`. The slope over a window is the honest answer and it is also cheap.
- **Insufficient samples read as `—`, not `0.0`.** A newly-tracked resource has no rate, and displaying `0.0` claims something false. This matters on load, where every buffer starts empty.
- **Not saved.** It is derived state and re-derives within a window (the standing rule: derived state is re-derived, never saved). The ledger shows `—` for the first window after a load, which is correct and honest.

The tracker is owned by `ResourceManager` (it already has the slow-tick subscription and the resource list) and read by the strip, the ledger, and — later — anything that wants a trend.

### 4 — The ledger flyout

`ui/console/resource_ledger.tscn` + `.gd` (`class_name ResourceLedger`). Anchored **directly above the LEDGER chip**, stopping short of the right column: *"Console flyouts never open over the map, alerts or inspector."*

- 34px `ReadoutPanel` header: `RESOURCE LEDGER`, subtitle `n TRACKED · 6 PINNED`, then `PIN MODE` and `ESC`.
- **Four columns, one per category:** `RAW ORE`, `REFINED`, `LIFE SUPPORT`, `GOODS`. Each row is name / amount / per-cycle rate, the rate sign-coloured.
- Footer legend: `PIN ANY RESOURCE TO PROMOTE IT INTO THE CONSOLE STRIP · RATES ARE PER CYCLE`.
- `PIN MODE` turns each row's swatch into a pin toggle. A separate mode rather than an always-live pin control, because the ledger is read far more often than it is curated and a mis-click shouldn't reshuffle the strip.

**It is not a mode** (invariant 1's one exception): *"Checking stock mid-build should not close Build."* It is a readout, and it coexists with whatever mode is open. `ModeManager` does not know about it; Esc closes it at level 2, above the open mode.

### 5 — Categories need a field

Grouping into four columns needs a category per resource, and `ResourceData` has no such field. Add one:

```
enum Category { RAW_ORE, REFINED, LIFE_SUPPORT, GOODS }
@export var ledger_category: Category = Category.GOODS
```

This is **presentation only** and must not be gated on by gameplay — the same rule `ui_category` follows for modules (WI-43): `tags` is gameplay, `ui_category` buckets the build menu. Nothing may branch on `ledger_category`, and nothing may group the ledger on `tradable` or `has_variance` because those happen to correlate today.

Authoring across the 18 real resources: ores → RAW_ORE; iron/carbon/silicon/gold/iridium/steel → REFINED; oxygen/water/hydrogen/ice/biomass/biowaste → LIFE_SUPPORT; credits → GOODS. `stored_energy` and `test_resource` are excluded from the ledger entirely — a resource opts *in* via a `show_in_ledger` flag defaulting to `has_global_store or tradable or is stored anywhere`, or by an explicit exclude. Whichever shape it takes, `test_resource.tres` must not appear in a player-facing list, and a modded resource must appear without a core edit (WI-47).

### 6 — Pin state persists per save

The player's curated strip is a player setting, not derived, so it saves. A new `SaveManager` section:

```
"vitals": { "pinned": ["credits", "iron_ore", ...], "derived": ["energy", "oxygen", "crew"] }
```

Ids, never indices or paths. **Absent key = the default six**, so pre-WI-52 saves load with the designed default and `SAVE_VERSION` stays put. A pinned id that no longer resolves (a mod removed, a resource renamed) is **dropped with a warning**, not an error — and the resulting under-full strip refills from the default order rather than leaving a gap.

The default six, from the mockup: Energy, Credits, Oxygen, Food, Steel, Crew. "Food" maps to biomass or rations depending on where the food chain has got to; pick whichever the current recipes actually produce and say so in the code.

Two open questions to settle during implementation, both defaulting to "no": should pins be a *game* setting (per save, as specced) or a *player* setting (per install, in `user://settings.cfg` alongside WI-36's settings)? Per-save is specced and is the right default because a station's vitals depend on what that station does. And should the strip cap at six? The zone is flex, so more would fit at some widths and then not fit at others — cap it at six and say so in the pin UI, rather than allowing a strip that overflows at 1920 but not at 2560.

## Files to touch

*As shipped. `VitalsStrip` is a code-built `HBoxContainer` (no `.tscn`) because it authors nothing a scene could hold, and the `vitals` save section is registered by the strip itself rather than added to `SaveManager` — the WI-47 M3 pattern, so the section dies with the HUD instead of being a hardcoded entry that fails when there is none.*

- **New:** `ui/console/vitals_strip.gd` (`VitalsStrip`), `ui/console/vitals_chip.tscn` + `.gd` (`VitalsChip`), `ui/console/resource_ledger.tscn` + `.gd` (`ResourceLedger`), `scripts/utility/resource_rate_tracker.gd` (`ResourceRateTracker`), `scripts/utility/ledger_model.gd` (`LedgerModel`), `tests/unit/test_resource_rate_tracker.gd`, `tests/unit/test_ledger_grouping.gd`
- `data/resources/resource_data.gd` — `Category` enum + `ledger_category`, `show_in_ledger`, `average_instance_value()`, and the C13 fix in `force_withdraw`
- `data/resources/*.tres` — 17 category assignments (credits takes the GOODS default) + 2 exclusions
- `scripts/managers/resource_manager.gd` — owns the rate tracker; discovers resources; feeds the tracker on `slow_tick`
- `scripts/managers/atmosphere_manager.gd` — `station_average_o2_partial()`, volume-weighted, for the OXYGEN chip
- `ui/theme/ui_metrics.gd` — chip/ledger geometry and the two zone-fit helpers
- `ui/theme/widgets/list_row.gd` — `set_action_color()`
- `ui/console/console_bar.gd` — builds the strip in the flex zone; `vitals()` accessor
- `ui/ui_main.gd` — `create_resource_display()`, `_setup_crew_ui()`, `_refresh_crew_count()` and `_mount_vitals_strip()` deleted; mounts the ledger; Esc level 2b; `toggle_ledger` in `_shortcut_input`
- `scripts/managers/global.gd` — `toggle_ledger` joins `REMAPPABLE_ACTIONS` and `ACTION_LABELS`
- **Deleted:** `ui/resource_display_ui.tscn` + `.gd`, `ui/energy_display_ui.gd`, and `ui_main.tscn`'s whole `VitalsStrip` subtree with its four exports
- `scripts/utility/cheats.gd` — `dump_rates()`

## Implementation order

1. `ResourceRateTracker` + tests. Pure, and the rest of the item is unreadable without a rate.
2. Wire the tracker into `ResourceManager`; verify with a cheat dump against a known production loop before anything renders it.
3. `ledger_category` + the `.tres` pass + `test_ledger_grouping`.
4. `VitalsStrip` with a **hardcoded** default six. The console's middle zone now holds the real thing and the old strip is gone. Playable.
5. The C13 symmetry fix.
6. `ResourceLedger` with the four columns and rates, read-only.
7. Pin mode, then the save section.

## Edge cases

- **Rate on load.** Every buffer is empty, so every line reads `—` for one window. Do not seed the buffer from the loaded totals — a single sample is not a rate, and a fabricated `0.0` on a station that is actually mining is a worse lie than a dash.
- **Rate across a scene swap.** `ResourceData` is a shared resource whose runtime fields survive a Quit-to-Menu because Godot's resource cache holds it (the WI-38 A8 lesson). The tracker must therefore be **owned by the manager node**, not stashed on `ResourceData`, or a new game inherits the previous run's samples. This is exactly the bug A8 was.
- **Paused game.** Sim-time stamps mean no samples accrue while paused and the rate holds its last value rather than decaying. Verify at pause, and at 1×/2×/4× that the same production reads the same rate.
- **A resource with no global store and no storage anywhere** reads 0 with no rate. It still belongs in the ledger if it is tracked; the ledger is a complete list, not a list of what you happen to have.
- **`has_variance` resources** (ore richness, food quality) have a meaningful average as well as a count. The strip shows the count; the ledger row may show the average in the meta position, as `ui_storage_component._format_slot_value` already does (`14 (72%)`).
- **Credits are special and shouldn't be.** They are `has_global_store`, they have a bespoke widget today, and half the codebase reaches for `ResourceManager.credit_resource`. In the strip they are one resource chip like any other. Resist adding a credits special case back for the rate line (income/expense breakdown lives in the Economy tab, WI-57).
- **The strip must not reflow on every tick.** Chips are rebuilt on pin changes only; values update in place. A `HBoxContainer` re-laying out 60 times a second because a number changed width is a real cost and a visible jitter — fixed-width numeric slots.
- **Six pins and a narrow window.** At 1920 the flex zone fits six chips plus the ledger chip. Verify; if it doesn't, the chip width or the pin cap is wrong, and the pin cap is the safer knob.
- **The mockup shows 30 resources.** There are 18. The four columns will be short. That is fine — the layout's whole claim is that it is indifferent to the count.

## Verification

1. **GUT:** `test_resource_rate_tracker` — a constant production slope reads back exactly; a single spike deposit does not read as its full magnitude; a paused stretch (no new samples) holds the rate; fewer than the minimum samples returns the "no data" sentinel and not 0.0; the ring buffer overwrites oldest-first and never grows; identical rates at 1× and 4× given the same sim-hour stamps. `test_ledger_grouping` — every real resource lands in exactly one category, `test_resource` and `stored_energy` are excluded, a resource with an unset category defaults to GOODS rather than vanishing.
2. **Headless probe:** pin/unpin across the cap, save, load, and assert the strip restores the same ids in the same order; assert an unresolvable pinned id is dropped with a warning and the strip refills to six; assert a pre-WI-52 save (no `vitals` key) loads the default six.
3. **Windowed screenshot** of the console strip with a falling amber vital, and of the open ledger against mockup screen 10 — four columns, header counts, footer legend, and the flyout stopping short of the right column.
4. **Manual:** spend credits via a cheat (`add_credits`, then hire a crew member, which goes through `force_withdraw`) and confirm the chip moves **immediately**, which is the C13 fix.
5. **Ledger coexists with a mode:** open Build, open the ledger, confirm Build stays open, confirm Esc closes the ledger first and Build second.
6. **Regression:** the energy readout still shows production/capacity correctly under a brownout; the crew count still tracks hire/fire/departure; nothing else read the deleted `ResourceDisplayUI`.

## Related

- [[Spaceport Iridium/Planning/04_UI_Rework_Program]] — invariant 4, and decision 9 on hotkeys (`L` for the ledger).
- [[WI-50_Console_And_Modes]] — the flex zone this fills, and Esc level 2.
- [[03_Bugs_and_Improvements]] — **C13**, fixed here.
- [[WI-38_Bug_Fix_Pass_2]] — A8, the shared-`ResourceData`-survives-a-scene-swap trap the rate tracker must not walk into.
- [[WI-43_Build_Menu]] — the `ui_category` vs `tags` precedent that `ledger_category` follows.
- [[WI-47_Modding_Support]] — a modded resource must reach the ledger without a core edit.
- [[WI-45_Save_System_Audit]] — the "player settings are not derived state" rule that makes pins savable.
