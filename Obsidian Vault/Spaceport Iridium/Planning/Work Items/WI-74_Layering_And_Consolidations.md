# WI-74 — Layering and Consolidations

> **Status: DRAFT (2026-09-19), not started. Follows [[WI-70_Job_Ownership_Contract]]**, because §1 reshapes the job-picking path that WI-70's restored-job resume runs through. Scoped from [[05_Architecture_Review]] §A9–A11 and the second-pass audit's small findings in [[03_Bugs_and_Improvements]]: **F33**, **F34**, **F36** and **F37**. Six independent pieces, each its own commit. §0's two decisions are the author's to settle; the recommended default is marked on each.

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
