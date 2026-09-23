# WI-74 — Layering and Consolidations

> **Status: DONE (2026-09-22).** §0.1 was settled by the author, and more generously than the recommendation: a blueprint cancelled before it is finished refunds its **whole** credit cost however much work was done on it; a **finished deconstruction** refunds it too; only a built module that is **demolished** loses its credits, along with its materials. §0.2 was taken as recommended (a generation counter). Verified by **1860 unit tests (104 suites)** and **65 integration tests (13 suites)**, both green; by seven seeded faults against the new integration suite, each failing the test meant to catch it and every file restored after (the restored job resumed ahead of the drained-robot gate, no blueprint refund, the receipt not saved, no deconstruction refund, a guest allowed the board, an inspector allowed to sweep, the stay clock counted in seconds rather than hours), plus a cache that doesn't clear on rescan and StructureManager's HUD binding put back, each failing its unit sweep; by `--import` at its baseline (the three addon parse errors it always prints, no `Busy`); and by screenshots of the running game: the Build panel's footer carries the refund rule and wraps inside its 356px, and a click on a module, and on a corridor sharing a cell with it, opens the inspector through the new signal.
>
> **What shipped that the plan did not say:**
> - **§4 refunds a receipt, not a price.** `purchase_and_add_module` records what it charged as `ModuleBase.credits_paid`, which is saved and is what both refund paths pay back through the one payer, `ModuleBase.refund_credits()` (credits the station, books `refunds` on the ledger, zeroes the receipt). The plan's version - refund `module_data`'s cost - would have printed money: the game places modules for free all the time (the starting station, the truss backfilled under every removed room, the corridor a door lays down), and truss costs 5 cr, so "place a room, deconstruct it, deconstruct the truss it leaves" would have paid out for the truss each time. Receipt-zeroing also makes a save on either side of a refund pay it exactly once. **A save from before WI-74 carries no receipt**, so modules standing in it refund nothing; guessing would refund the free ones too.
> - **The deconstruction refund lands at Deconstructing → Deconstructed**, beside the materials, not when the bin is hauled empty. A save mid-teardown restores with the receipt intact (F38's path) and refunds when it finishes.
> - **DEMOLISH never cancelled a blueprint.** The plan said a blueprint could be cancelled by right-click "and the inspector's DEMOLISH"; `page_footer` only offers DEMOLISH on a built module. The blueprint paths are a right-click and placing a module over an unbuilt truss (which removes itself), and both refund. A right-click on a *built* module is a demolition and refunds nothing, exactly as DEMOLISH.
> - **The rule is stated in three places:** the Build panel's footer (a second line, `UIMain.BUILD_REFUND_RULE`), and the DECONSTRUCT and DEMOLISH tooltips, which name the amount (`…and the 350 cr it cost`) and say nothing about credits on a module nobody paid for.
> - **§1 changed one behaviour, on purpose.** Guests and the inspector gated their queue on `is_valid() and can_do_job()`; crew and robots on `can_begin()`. For a fresh job those are the same (`can_do_job` asks `is_valid`), and for a restored job left in the queue behind something newer the old gate refused it - F40's shape, on the two kinds WI-70 never touched. Every kind asks `can_begin()` now. The inspector also runs the restored-job step, which is a no-op because it is never saved. `_idle_pose()` is the shared "nothing to do" branch the four copies each spelled out.
> - **§2's sweep is "a static function that scans `ContentPaths` compares the generation"**, not "a `static var _scanned` reads it": that catches a cache latched on anything, including an emptiness check, and leaves the managers that scan in `_ready` alone. It also fails on the old boolean latch, and on a static cache that `test_content_caches.gd` does not drive through read → plant → invalidate → gone. Each cache now clears its registry before rescanning, which a first scan never needed. The five test files each called one cache's seam, not several; four now tear down with `ContentPaths.invalidate()`, and `test_content_paths.gd` pins the generation's moves.
> - **§3 also deleted the per-instance `resource_pile_clicked` / `asteroid_clicked` signals** (emitted, never connected) and UIMain's three one-line `*_clicked` methods; `module_clicked` is now the private `_module_clicked`. A click on anything the inspector has no page for is ignored rather than passed on, because `select()` of it would clear the selection. `PathManager`'s redraw cue is a local `debug_path_changed` signal rather than a SignalBus one: it has exactly one listener, and it is not cross-system. A unit sweep (`test_sim_ui_layering.gd`) keeps world objects from naming the HUD and managers from binding it, allowing `DialogueRunner` and `TutorialManager`, whose job is mounting under `UIMain`.
> - **§6 moved the mining bay's whole per-frame body**, not just the respawn countdown: the power mirror onto its drones and the "No power!" line were the same `_process`, and PowerManager balances on the same tick. Its `set_process` calls went with it. Lose check before hire clock, and trader fulfilment before its clocks, keep the order they ran in within a frame.
> - **§6's verification times each clock** instead of comparing a 24-hour soak: soak totals are not seed-stable (WI-72), and a timing assertion says which clock drifted. Each of the five fires within one slow tick plus two frames of its configured duration.
> - **Not verifiable with synthetic input: stacked-cell cycling.** In the running game, a second injected click on a cell holding a corridor and the Command Center cleared the selection instead of cycling - and the tree *before* this item, stashed and run the same way, did exactly the same. `ClickCycler` derives the cell from `get_global_mouse_position()`, which injected button events may not move, so this is either an artifact of the injection or a pre-existing fault; either way WI-74 did not change it. Left for the author's by-hand check (§Verification 3).
>
> The doc is left in `Work Items/` for the author to file.
>
> *Original status: DRAFT (2026-09-19), not started. Follows [[WI-70_Job_Ownership_Contract]], because §1 reshapes the job-picking path that WI-70's restored-job resume runs through. Scoped from [[05_Architecture_Review]] §A9–A11 and the second-pass audit's small findings in [[03_Bugs_and_Improvements]]: **F33**, **F34**, **F36** and **F37**. Six independent pieces, each its own commit. §0's two decisions are the author's to settle; the recommended default is marked on each.*

## Goal

None of these is a defect with a player-visible symptom today, apart from F34, which is a missing rule rather than a bug. Each is a place where the same thing is written more than once, or where the simulation reaches up into the interface, and each has already cost an edit in several places:
- **Job picking is written three times** (§1). WI-68 F21 had to patch its restored-job resume into `PawnBase`, `RobotPawnBase` and `VisitorPawn` separately, and `InspectorPawn` has a fourth, narrower copy.
- **Thirteen content caches can't be invalidated** (§2). Each is a static that scans `ContentPaths` once and never again. That blocks WI-47's deferred stage 5 (patch ops) and any runtime mod toggle, and it is why five test files each have to clear registries by hand.
- **The simulation calls the HUD** (§3, F33). Four world objects call `Global.ui_main.*_clicked` directly, and two simulation managers bind a UI node by relative tree path.
- **Small leftovers:** F34 (blueprint cancellation and credits), F36 (a warning that floods), F37 (five per-frame countdowns the tick rule would put on `slow_tick`).

## 0 — Decisions for the author (not yet settled)

1. **F34: cancelling a blueprint refunds its credits only if no work has been done on it.** *Recommended.* Today placing a module withdraws its credit cost, and cancelling the blueprint returns the delivered materials as a pile but never the credits. Deconstructing a built module doesn't refund credits either, so "credits are a fee" is at least consistent. What's missing is the misclick case: a blueprint cancelled a second after placement costs its full fee. Refund in full while `work_seconds_done == 0`, booked through `EconomyManager.record_refund` (WI-68 F4), and state the rule in the Build panel's footer. *Alternatives:* never refund, and say so in the footer; or refund for any unfinished blueprint.
2. **§2 uses a generation counter, not a registry base class.** *Recommended.* The thirteen caches have different shapes (`_registry` plus `_ordered`, `_by_tag`, `_event_by_modifier`), so a shared base would force them into one mold. A static `ContentPaths.generation` bumped by one `invalidate()`, which each cache compares against its own `_scanned_generation`, is one line per cache. *Alternative:* a `ContentRegistry` base class; neater, and a larger diff for the same behaviour.

## Scope

**In:** the job-picking template (§1), cache invalidation (§2), world clicks and F33 (§3), F34 (§4), F36 (§5), F37 (§6).

**Out:**
- WI-47 stage 5 itself; §2 only removes the thing blocking it;
- turbolift boarding's awaits (see WI-71's scope).

## Design

### 1 — One `start_job` (A9)

Today's four copies, reduced to their steps:

| Step | Crew (`PawnBase`) | Robot (`RobotPawnBase`) | Visitor | Inspector |
|---|---|---|---|---|
| gate | none | zero energy: recharge only, stop | none | none |
| restored job (F21) | yes | yes, after the gate | yes | no (never saved) |
| cargo sweep | yes | yes | yes | no |
| personal queue | yes | yes | yes | yes |
| gate | none | below threshold: idle, stop | none | none |
| work | board, by shift | its bay's own job (`_claim_work_job`, per robot kind) | none | none |
| fallback | wander, else idle pose | idle pose | wander, else idle pose | idle pose |

One template in `PawnBase` runs the steps in that order, with five overridable hooks: `_gate_before_resume() -> bool`, `_sweeps_cargo() -> bool`, `_gate_before_work() -> bool`, `_claim_work_job() -> bool` (which `MiningDronePawn` and `HaulerRobotPawn` already override), and `_fallback_job()`. The three `start_job` overrides are deleted, leaving each class's hooks as the only statement of how it differs, which is what CLAUDE.md already says the specialisations are ("which components they carry and where they source jobs").

This is behaviour-preserving, and the risk is in the orderings, so each row of the table above becomes an assertion in a WI-69 integration test: one per pawn kind, driven into each gate.

### 2 — Content caches that can be invalidated (A10)

The thirteen static caches that read `ContentPaths`: `BuildCategoryData`, `DifficultyData`, `DiseaseData`, `PawnData`, `PlanetVariant`, `RecipeData`, `ShipData`, `ShopTypeData`, `SkillData`, `StarClass`, `TraitData`, `JobDataRegistry` and `MoodCatalog`. `NameGenerator` reads the name-generator addon, not `ContentPaths`, so it stays as it is.

Per §0.2, add `ContentPaths.generation` and `ContentPaths.invalidate()`. `register_mod_root` and `clear_mod_roots` call `invalidate()`, and each cache's `_ensure_scanned` rescans when its `_scanned_generation` is stale. The per-class `clear_for_test` seams keep working, and the five test files that call several of them (`test_content_paths`, `test_job_persistence`, `test_pawn_kinds`, `test_recipe_index`, `test_ship_variants`) can call `ContentPaths.invalidate()` instead.

A source sweep asserts that every script with a `static var _scanned` also reads `ContentPaths.generation`, so a fourteenth cache can't be added the old way.

Managers that scan in `_ready` (`UnlockManager`, `EventManager`, `SaveManager`'s id lookups) already rescan on every scene, so they need nothing.

### 3 — The simulation stops calling the HUD (A11, F33)

- **Clicks:** add `SignalBus.world_object_clicked(object: Node2D)`. `ModuleBase._on_footprint_input_event`, `PawnBase._on_collision_clicked`, `ResourcePile`'s and `AsteroidBase`'s click handlers emit it instead of calling `Global.ui_main.*_clicked`. `UIMain` subscribes and dispatches by type to its existing handlers. `module_clicked` keeps `ClickCycler`'s stacked-cell arbitration exactly as it is; only the route in changes.
- **F33:** delete `StructureManager.ui_in_game`, which is bound and never read. `PathManager` keeps its `debug_path` (the multi-select path preview) and stops writing into `UIInGame`; `UIInGame` reads `Global.path_manager.debug_path` when it redraws. Neither simulation manager binds a UI node afterwards, which is what lets WI-69's fixture, or any later headless tool, run the station without the HUD.

### 4 — F34, per §0.1

In `WorldManager.remove_module`, when the module is an unbuilt blueprint whose `ConstructionComponent.work_seconds_done == 0`, credit back its credit cost with `change_global_total` and book it with `record_refund`. That covers both ways a player cancels one: right-click, and the inspector's DEMOLISH (`module_tab_set.gd`). Destruction never reaches this path for a blueprint, since `apply_damage` ignores anything that isn't built, and a finished deconstruction removes a built module, not a blueprint. The Build panel's `footer_text` gains the rule in one sentence, and CLAUDE.md's "placement pays only on success" invariant gains its mirror.

### 5 — F36: warn once

`UnlockManager.suits_mandatory()` `push_warning`s on every call when the current tier has no `TierData`. It runs per crew member per slow tick and per atmosphere tick, so a missing `.tres` writes about 40 lines a second. Latch it: warn the first time for a given tier, then answer quietly.

### 6 — F37: five countdowns onto the tick

Move each onto `slow_tick`, integrating over `interval`, so they pause and scale like every other periodic system:
- `CrewManager._process`: the pending-hire clock;
- `TraderManager._process`: the visit and arrival clocks;
- `EventManager._process`: the station-wide happiness countdown;
- `MiningComponent._process`: the drone respawn timer;
- `VisitorPawn._process`: the stay and stranded-retry timers. Only the countdowns move: `super(delta)` still runs the pawn's jobs per frame.

A slow tick is 0.25 sim-seconds, finer than any of these clocks needs. `TraderManager`'s departure warning at "an hour left" and `CrewManager`'s arrival fire at most one tick later than today.

## Files to touch

| | Files |
|---|---|
| §1 | `pawns/pawn_base.gd`, `robot_pawn_base.gd`, `visitor_pawn.gd`, `inspector_pawn.gd`, and the two robot kinds' existing hooks |
| §2 | `scripts/utility/content_paths.gd`, the thirteen cache scripts, the five test files, and a new sweep in `tests/unit/` |
| §3 | `scripts/managers/signal_bus.gd`, `modules/templates/module_base.gd`, `pawns/pawn_base.gd`, `data/resources/resource_pile.gd`, `objects/asteroid_base.gd`, `ui/ui_main.gd`, `scripts/managers/path_manager.gd`, `structure_manager.gd`, `ui/ui_in_game.gd` |
| §4 | `scripts/managers/world_manager.gd`, the Build panel's footer in `ui/ui_main.gd` |
| §5 | `scripts/managers/unlock_manager.gd` |
| §6 | the five files in §6 |
| Docs | `CLAUDE.md` (the invariant in §4; the job-picking hooks under *Pawns*), [[01_Technical_Specification]] |

## Implementation order

§5 and §3 first (small, and §3 helps WI-69), then §6, §4 once decided, §2, and §1 last, since it has the most orderings to preserve and benefits most from the fixture being mature.

## Edge cases

- **§1 and a pawn kind a mod adds** inherit the template and override only the hooks they need. That's an improvement: today a mod pawn has to copy a whole `start_job`.
- **§3's click on a freed object:** the signal is emitted by the clicked object itself, so it is live at emission, and `InspectorPanel.select()` already handles a subject that dies later.
- **§4 and a blueprint that received materials but no work:** credits come back and the materials come back as a pile, which is both halves of what was paid.
- **§6 and a load:** `_apply_pending_load` restores every section in one call, so no tick fires while it runs and no countdown advances mid-restore, exactly as with `_process` today.

## Verification

1. **GUT unit:** the cache sweep, and one test per cache that a `ContentPaths.invalidate()` makes it rescan. One is enough if they share a helper.
2. **GUT integration (WI-69):**
   - one test per pawn kind for §1's orderings: a robot at zero energy recharges before its restored job, a visitor never takes board work, the inspector runs only its queue;
   - F34: cancel a fresh blueprint and the balance is back where it was, with a `refunds` line in the ledger;
   - F37: hires, visits, happiness effects, respawns and stays all complete within a tick of their old times over a 24-hour soak.
3. **By hand, with screenshots:** click a module on a stacked cell, a pawn, a pile and an asteroid; each opens the inspector as before, and a second click on the stacked cell still cycles.

## Related

- [[WI-47_Modding_Support]]: stage 5 (patch ops), which §2 unblocks.
- [[WI-68_Audit_Fix_Pass]]: F21, which §1's template makes a one-place change; F4's `record_refund`, which §4 uses.
- [[WI-10_Placement_UX]]: `ClickCycler`, which §3 must not disturb.
