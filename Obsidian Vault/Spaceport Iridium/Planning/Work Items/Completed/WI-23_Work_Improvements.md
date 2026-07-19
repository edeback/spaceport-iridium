# WI-23 — Work Improvements: Workspaces, Manned Processing, Workstation Anchors

## Goal
Pawns feel like they have roles: modules can have assigned workers whose jobs only they take (and which they prioritize), processors require a pawn actually working at them instead of ticking down on their own, and modules with jobs get authored WORKSTATION anchors with per-anchor animations (interact, interact_sit, lay_down, …).

## Design
- **Workspace assignment.** Assignment lives on the module: `WorkspaceComponent` (`modules/components/workspace_component.gd`) with `max_workers` and an assigned-pawn list (saved as pawn references — pawns need a stable save id; WI-22's pawn section gives them one, add `pawn_id` if it didn't). UI: a module-panel tab listing crew with assign/unassign toggles.
  - **Claim gating:** jobs posted "by" a module with a non-empty assignment are only claimable by assignees. Mechanism: `JobBase` gains `workspace: WorkspaceComponent` (null = open to all); `can_do_job` base check consults it. The posting components (processor work jobs below, mining, repair later) set it from their owner module.
  - **Prioritization:** assignees prefer their workspace's jobs. Mechanism: `JobManager.find_job` already walks by effective priority; add a per-pawn bonus — `effective_priority_for(pawn)` = `effective_priority()` + `WORKSPACE_AFFINITY_BONUS` when `workspace` lists the pawn. Bonus sized to win ties and modest bands, not to cross the ±99 routing bands (constant in `JobPriorities`).
- **Manned processors.** `ProcessorComponent` gains `requires_worker: bool` (exported; existing scenes default false = zero behavior change until scenes opt in). When true: `_stepwise_processing` still withdraws inputs and *readies* a batch, but progress only advances while a pawn works it. New `Job_WorkProcessor` (`scripts/jobs/job_work_processor.gd`, Category WORK, `get_skill()` = crafting by default, overridable per module/recipe): posted when a batch is ready and no worker is engaged; pawn paths to the module's WORKSTATION anchor, plays the anchor's animation, and drives `current_process_time` forward each `process_job` tick — scaled by `skill_mult` (WI-22) × `work_speed()`. Job completes with the batch; followup: if another batch is ready and the pawn is still on shift, chain via `get_followup_job` (stay at the machine) instead of re-posting to the board.
  - Shift end mid-batch: the pawn finishes the current batch (jobs are never interrupted by shift end — existing rule), then walks; progress persists if they leave for other reasons (batch holds at partial progress until someone resumes).
- **Workstation anchors + animations.** `AnchorDef` gains `@export var animation: StringName = &""` (interact, interact_back, interact_sit, lay_down — whatever the pawn sprite frames support; missing animation falls back to idle). Author WORKSTATION anchors in the processor/mining/crew module scenes (module_editor addon already edits scenes). Pawn side: on arriving at a claimed anchor with an animation, `PawnBase` plays it and restores idle/walk on leaving — hook where STAND-anchor claims already resolve (WI-16 plumbing).

## Files to touch
- **New:** `modules/components/workspace_component.gd`, `scripts/jobs/job_work_processor.gd`, `ui/windows/component_ui_panels/workspace_tab.gd/.tscn`
- `modules/components/processor_component.gd` — `requires_worker`, batch-ready state, progress-by-worker, save partial progress (mid-batch progress becomes worth saving once a pawn invested time — add to processor save data)
- `scripts/jobs/job_base.gd` — `workspace` field + `can_do_job` gate; `scripts/jobs/job_priorities.gd` — affinity bonus constant
- `scripts/managers/job_manager.gd` — `effective_priority_for(pawn)` in `find_job` comparisons (and keep board sort on the pawn-agnostic key)
- `scripts/pathing/anchor_def.gd` — `animation`; `pawns/pawn_base.gd` / `pawn_movement_component.gd` — play/restore anchor animation on arrival/departure
- Processor module scenes (`modules/**`) — WORKSTATION anchors + `requires_worker` opt-in per design (refinery/forge yes; fully-automated modules like solar stay unmanned)
- `scripts/managers/save_manager.gd` — workspace assignments (module section), pawn ids if missing
- WI-21 followup: `Job_WorkProcessor` save/restore entry
- Remember: `filesystem_manage(op="scan")` after new `class_name` files

## Implementation order
1. Anchor `animation` field + pawn playback (visible win, no logic risk).
2. `WorkspaceComponent` + assignment UI + claim gating on one job type (mining bay is the simplest existing poster).
3. Affinity bonus in `find_job`.
4. Manned processors: batch-ready state → `Job_WorkProcessor` → skill-scaled progress → followup chaining; opt in the refinery/forge scenes.
5. Save: assignments + mid-batch progress; WI-21 job entry.

## Edge cases
- All assignees resigned/died: `WorkspaceComponent` prunes invalid refs on slow_tick; empty assignment reopens jobs to everyone (and alert once: "no workers assigned to X" only if the module sat idle with a ready batch > N hours).
- Assignee off-shift with a ready batch: job waits (strict gating per design) — the alert above is the pressure valve; verify no alternate pawn steals it.
- Assigned pawn is also the only one who can eat/sleep: needs jobs ride the personal queue and outrank board work — no starvation lock (existing WI-05 behavior preserved).
- Two assignees, one batch: first claim wins; the other falls through to other jobs — affinity bonus must not make them ping-pong (bonus applies to claim choice only, no reservation of workers).
- `requires_worker` toggled on a scene whose module has stock mid-batch (save from before the toggle): partial progress loads, job posts, pawn resumes — verify no double-withdrawal of inputs.
- Anchor claimed but pawn dies/leaves mid-work: anchor releases (existing release-on-movement path), job cancels per lifecycle, batch progress holds.
- Processor UI progress bar must reflect stalled-waiting-for-worker distinctly from unpowered (`last_error` string).

## Verification
1. Assign pawn A to the refinery: only A takes its work jobs; A preferentially returns to the refinery over equal-priority hauling; unassign → anyone takes them.
2. Manned refinery with stocked inputs: batch waits for a worker, pawn walks to the workstation anchor, plays the interact animation at the right spot, progress advances only while present; skill-0 vs skill-10 crafters differ in batch time.
3. Pawn pulled away mid-batch (interrupt via cheat): progress holds, job re-posts, another/same pawn resumes to completion; inputs consumed exactly once.
4. Shift end mid-batch: batch finishes, then the pawn goes off-shift.
5. Save/load mid-batch with worker engaged (WI-21 landed): worker resumes at the machine, progress preserved.
6. Regression: unmanned processors (solar, scrubber, unmodified scenes) behave exactly as before; construction priority bands unaffected by the affinity bonus (build a module while the refinery begs for workers).
