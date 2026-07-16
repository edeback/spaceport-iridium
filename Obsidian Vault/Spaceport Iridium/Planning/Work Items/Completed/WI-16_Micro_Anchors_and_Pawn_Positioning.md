# WI-16 — Micro Anchors & Pawn Positioning

*Outcome of the 2026-07-14 pathfinding discussion. One machinery, three payoffs: precise destinations inside modules (workstations, bunks), walk-to waiting spots (no more turbolift pop-in), and visual de-overlapping of pawns — all without per-frame avoidance, which stays explicitly out of scope.*

## Goal
1. **The missing primitive:** pathfind to a specific point *inside* a module — a micro-graph index plus optional offset — instead of only to the module's door/center. (This is the long-standing "pathfind to a specific path index inside a module" TODO from the dev notes.)
2. **Anchors:** named/typed points on a module's `PathComponent` (WORKSTATION, BUNK, QUEUE, STAND), authored in module scenes *or generated at runtime* by subdividing the interior path edges. Jobs reserve an anchor and movement targets it.
3. **Cosmetic de-overlap:** persistent per-pawn lane offset + walk-speed jitter so pawns sharing a path don't render as one sprite; arrival-time slot picking so idlers spread out.

Explicitly **not** in scope: RVO/physics avoidance or any per-frame neighbor queries (rejected on cost — the whole pathfinding architecture exists to avoid them), combat AI itself (a future firefight system consumes generated STAND anchors; the allocator built here is its foundation).

## Design
### Path-to-anchor primitive
- `PawnMovementComponent.move_to()` gains an optional `target_anchor: int = -1` (micro path-point index in the destination module). Macro pathfinding is unchanged; only the *final* module's sub-path changes: instead of ending at the exit door / connection point, `PathComponent` returns the interior path from the entry door to the anchor index (the existing `_get_path_within_module(start_index, anchor_index)` already does this — it just needs to be reachable as a final-leg case in `PawnMovementComponent.get_sub_path`/`extract_position`).
- Arbitrary offsets: anchor = (path_point index, `Vector2` offset). The pawn walks the micro path to the index, then a straight-line tail to the offset — module interiors are open boxes, so the straight tail is safe. This is the cheap 90% answer to "arbitrary points."

### Anchors as data
- `PathComponent` gains `@export var anchors: Array[AnchorDef]` (**new** small Resource: `type: AnchorType`, `path_index: int`, `offset: Vector2`) for authored spots (bunks, workstations, turbolift queue positions).
- Runtime generation: `PathComponent.generate_anchors(type, count) -> Array[AnchorDef]` subdivides `path_edges` segments at fixed spacing (e.g. every 20px) — hallways get free STAND slots without authoring. Generated lazily, cached, invalidated never (micro graphs are static per scene).
- **Reservation:** a tiny `AnchorSlots` helper on PathComponent — `claim(type, claimant) -> AnchorDef` / `release(claimant)`. Claims are runtime-only (never saved — jobs aren't saved either; on load, re-claims happen when jobs repopulate). Same claim-and-release discipline as storage reservations: release on ANY job cancel path.
- Consumers in this WI: turbolift waiting (below) and `Job_Idle`/arrival spreading. WI-05's Job_Sleep claims BUNK anchors if this lands first (see the note added there); combat claims generated STANDs later.

### Turbolift waiting spots walk-to
- Replace `ModuleTurbolift.get_waiting_slot()`/`assign_waiting_slot()` position-teleport with QUEUE anchors on its corridor cell's hallway: the ride request claims a queue anchor, and the pawn's final movement leg targets it — they *walk* to the waiting spot. When the cab arrives, the boarding walk starts from the anchor. Releases on board/cancel.

### Cosmetic de-overlap
- **Lane offset:** each pawn hashes its instance id to a persistent perpendicular render offset (±1–3 px). Logical position stays exactly on the path; only the sprite draws offset (apply in `PawnBase.move_to()` to the sprite/offset node, not to `global_position` — logical position feeds pathfinding and save).
- **Speed jitter:** per-pawn ±5–10% multiplier on `speed`, hashed the same way. Breaks lock-step conga lines for free.
- **Arrival spreading:** when movement completes in a module that already contains stationary pawns, claim a free STAND anchor (generated) and walk the short tail to it — one query at arrival, never continuous.

## Files to touch
- **New:** `scripts/pathing/anchor_def.gd` (Resource: type enum, path_index, offset)
- `modules/components/path_component.gd` — anchors export, `generate_anchors()`, claim/release, final-leg path to anchor (`get_path_to_anchor(entry_module, anchor)`)
- `pawns/pawn_movement_component.gd` — `move_to(..., target_anchor)`, final-module sub-path uses anchor leg, straight-line tail for offsets
- `pawns/pawn_base.gd` — lane offset + speed jitter (hash of instance id; apply offset at render in `move_to()`, jitter to `speed` at `_ready`)
- `modules/transport/module_turbolift.gd`, `turbolift_shaft.gd` — waiting-slot teleport → QUEUE anchor claim + walk; release on board/cancel/destroy
- `modules/transport/ride_request.gd` — carries the claimed anchor
- `scripts/jobs/job_idle.gd` / movement-complete hook — arrival spreading (claim STAND when stopping among others)
- Module scenes (opportunistic): author BUNK anchors on `basic_sleeping_pod.tscn`, WORKSTATION on processors — can trickle in per-module later; generation covers hallways day one
- WI-03 followup: nothing — anchors are static data, claims are transient (verify no save changes needed)

## Implementation order
1. Path-to-anchor primitive (final-leg sub-path + `move_to` parameter) — test by hard-coding a target index.
2. AnchorDef + authored anchors + claim/release.
3. Generated anchors (hallway subdivision).
4. Turbolift queue anchors (replaces the pop-in; most visible payoff).
5. Lane offset + speed jitter (independent — can be done any time, even first; it's an afternoon).
6. Arrival spreading.

## Edge cases
- Anchor claimed, then the job cancels on ANY path → release (same invariant as storage reservations; hook into the WI-04 cancel contract if it has landed).
- Two pawns race for the last QUEUE anchor → second claim fails → fall back to module-center target (current behavior) — never block movement on anchor scarcity.
- Module removed while a pawn is walking to its anchor → existing `module_removed` repath handles it; the claim must release via the job's cancel, not be forgotten (pile of stale claims = anchors leak; add a debug assert that claims ≤ anchor count).
- Anchor in a flipped module — authored `path_index` refers to the flipped scene's own `path_points`, so flipping is transparent (flipped_scene has its own PathComponent data); verify with one flipped airlock.
- Lane offset near doors: the render offset can visually clip doorframes at 64px cell size — clamp the offset to 0 over the final N pixels of a sub-path segment that ends at a door index (cheap lerp), or accept the clip in v1 (evaluate visually).
- Speed jitter × stairs multiplier (WI-11) × `Job_IdleWander`'s 0.4 — multipliers compose; verify no near-zero crawl (same check WI-11 lists).
- Save/load mid-walk-to-anchor → movement isn't saved; pawn re-derives a job and re-claims. Verify no orphan claims after load (claims live only in runtime PathComponent state, which is rebuilt — automatically clean).
- Generated anchors on a 1-cell hallway (very short edge) → at least 1 slot, degenerate spacing handled.

## Verification
1. Debug: order a pawn to a specific interior point of a 2×2 module (console/test hook) → walks through the door, along the micro path, stops at the exact point.
2. Turbolift: 3+ pawns calling a cab on one floor → they *walk* to distinct waiting spots (no teleport pop), board one at a time, spots free up for the next callers.
3. Two pawns hauling the same route → visually distinct (offset lanes, drifting apart over distance from speed jitter); logical paths identical (debug path draw unchanged).
4. 4+ idle pawns wander into one hallway → they spread along it instead of stacking on the center point.
5. Sleeping pod with an authored BUNK anchor (+ WI-05 if landed): pawn sleeps *on the bunk*, not at module center.
6. Anchor-leak assert stays silent through a 10-minute 4× session with turbolift traffic and cancelled jobs (delete a target module mid-route).
7. Perf sanity: no new per-frame work — anchors only touched at path start, arrival, and claim/release.
