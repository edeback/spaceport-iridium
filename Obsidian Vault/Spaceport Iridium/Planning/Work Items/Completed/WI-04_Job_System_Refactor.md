# WI-04 — Job System Cleanup & Categories

## Goal
Prepare the job system for the many job types coming (sleep, recreation, hauling variants, repair) without redesigning it: unify the cancel/end lifecycle, introduce job categories with per-category queues, add the "finish what's started" priority boost and job aging, and formalize the personal-queue/followup mechanics that already exist. Explicitly **not** in scope: utility-function scoring (design later; the category structure built here is its prerequisite).

## Design
- **Lifecycle contract** (resolves the two open questions in the dev notes):
  - `cancel(as_failed)` is the single termination entry point; it sets terminal state, releases reservations, and calls `end_job()` itself (idempotent — guard against double-emit).
  - `JobManager` never calls `end_job()` directly; it calls `cancel(true)` on invalid jobs.
  - Pawns call `cancel(false)` for graceful interrupt, then simply drop the reference; `_end_current_job()` no longer calls `end_job()` (the job did).
- **Categories:** `enum JobBase.Category { HAUL, BUILD, WORK, NEEDS, MOVE, MISC }` — each subclass declares one. `JobManager` keeps `Dictionary[Category, Array[JobBase]]`, each array priority-sorted as today.
- **Selection:** `find_job(pawn, allowed_categories)` — pawns pass all categories v1 (shift/assignment filtering comes in WI-06). Scan order: category-major by pawn preference order, priority within category.
- **Finish-first boost:** `Job_ConstructModule` gets `priority = COMPLETION_BOOST` (constant, e.g. 50) when the site is resourced; hauling to construction already carries priority 99 via storage priority — document the priority bands in one place (see below).
- **Aging:** each `slow_tick`, JobManager bumps an `age` counter; effective priority = `priority + age_bonus` (cap it). Cheap: applied at comparison time, not by re-sorting — keep arrays sorted by base priority and add age only as a tiebreaker v1 (avoids constant re-sorting).
- **Priority bands doc:** create `scripts/jobs/job_priorities.gd` (constants + comment table): construction import 99, deconstruction export −99, default storage 1, completion boost, needs job implicit (personal queue, never on board).

## Files to touch
- `scripts/jobs/job_base.gd` — category field, lifecycle contract (`cancel` base implementation calling `end_job`, `_ended` guard)
- `scripts/managers/job_manager.gd` — category queues, `find_job` signature, invalid-job handling via cancel, aging on slow_tick
- Every job subclass (`scripts/jobs/job_*.gd`) — declare category; delete now-redundant `end_job` calls; ensure every `cancel()` override calls `super()` or follows the contract (most currently just set state — they must release reservations first, then super)
- `pawns/pawn_base.gd`, `pawns/mining_drone_pawn.gd` — `_end_current_job` simplification; queue-job invalid path uses `cancel(true)` only (it currently calls both cancel and end_job — A-grade example of why this WI exists)
- `modules/components/storage_data.gd` — `end_all_jobs` uses the new contract (cancel only)
- `modules/components/construction_component.gd` — completion boost; its `job_end` listeners keep working (job_end still fires exactly once, from cancel/finish)
- **New:** `scripts/jobs/job_priorities.gd`
- `ui/pawns/pawn_job_tab.gd` — display category (cosmetic, cheap while here)

## Implementation order
1. Write the contract into `JobBase` (base `cancel` sets a `_terminal` flag, emits `job_end` once). Add `Category`.
2. Sweep subclasses: declare categories; refactor each `cancel()` to: release-reservations → set state → `super.cancel(as_failed)`. Grep for every `end_job()` call site (`job_manager.gd`, `pawn_base.gd`, `mining_drone_pawn.gd`, jobs themselves) and remove/replace per contract.
3. Rework JobManager storage into category dict; keep `add_job/remove_job/find_job/re_sort_jobs` API shape.
4. Completion boost + priorities constants file.
5. Aging tiebreaker on slow_tick.
6. Pawn job tab shows "Category: Haul" etc.

## Edge cases
- `CONNECT_ONE_SHOT` listeners on `job_end` (`ConstructionComponent._on_construction_job_end`, deconstruction variant): must fire exactly once under the new single-emit guarantee — test construct-fail-retry loop (block path to a construction site, watch the job re-post).
- Double-cancel: pawn cancels a job the manager is simultaneously invalidating → `_terminal` guard prevents double reservation-release (StorageData cancel_* are already idempotent via `has(job)` checks — verify).
- `Job_GetResource.cancel` is called by `StorageData.end_all_jobs` *from within* storage teardown — re-entrancy: cancel → cancel_withdraw_job → storage which is mid-clear. Current code survives because erase-before-cancel; preserve that ordering.
- Followup jobs (`queue_job(followup, true)`) bypass the board — they must still respect the lifecycle (they do; they're started directly).
- Empty category arrays in find_job — skip cleanly.
- A job added while a pawn iterates the board (shouldn't happen — single-threaded — but find_job mutates arrays while scanning; keep the reverse-index iteration pattern per category).

## Verification
1. Full gameplay regression: construction chain, mining chain, eating, deconstruction, storage rebalancing — all function.
2. Kill a construction site's access (delete connecting hallway) with a build job claimed → job fails, site re-posts, pawn moves on; reconnect → construction completes. No duplicate `construction_finished` handling errors.
3. Fill a storeroom beyond desired while another has deficit → haul happens; delete the destination mid-haul → cargo stays on pawn, swept to another storage; **no reservation leaks**: after the dust settles, check `reserved_withdraw/reserved_deposit` are 0 on all storages (add a debug assertion or console print).
4. Two construction sites, one already resourced, one waiting on materials, one free pawn → pawn prefers finishing the resourced one (completion boost).
5. Let a low-priority export job sit while spamming higher-priority jobs → aging tiebreaker eventually surfaces it (observable with debug board print).
6. Job tab shows category; drones still only take mining jobs from their bay.
