# WI-05 — Needs Completion: Sleep, Recreation, Social, Happiness

## Goal
Bring the remaining pawn needs to the same working state as hunger, and derive a happiness value with visible consequences (productivity multiplier v1; departure comes in WI-07). Serving modules: sleeping pod (exists as scene), holodeck-style recreation (EntertainmentComponent stub), social spaces (SocialComponent stub — mess hall & future promenade).

## Design
- **Pattern per need** (copying the hunger/Job_Eat template):
  - Decay in game-hours (WI-02).
  - Below `percent_to_look_for_needs` → queue a personal job (never on the shared board).
  - Job: find best reachable serving component → move → occupy for a duration → need restores over the stay.
- **Sleep:** `SleepComponent` (new, on sleeping pod module) with `capacity` slots and `sleep_quality` multiplier. Job_Sleep: pawn occupies a slot, plays `layDown` animation (frames exist in the sprite kit), restores sleep over ~`8 game-hours / quality`. Slot reservation so two pawns don't share a pod. **Ownership (assigned beds) is out of scope v1** — first free pod wins. If [[WI-16_Micro_Anchors_and_Pawn_Positioning]] has landed, sleep slots should be authored BUNK anchors (pawn lies on the bunk, not at module center); otherwise "stand anywhere in the module" is the accepted v1 and anchors upgrade it later.
- **Recreation:** `EntertainmentComponent` gets `capacity`, `fun_per_hour`, optional `power_consumption_component` gate. Job_Recreate: occupy up to N hours or until full.
- **Social:** v1 is passive-and-cheap: `SocialComponent` marks a module as a social space; Job_Socialize sends the pawn there for ~1 game-hour; social restores faster per additional pawn present in the module (simple count of pawns whose `current_module` is this one). Deep conversation simulation: no.
- **Happiness:** computed on `PawnNeedsComponent` as weighted mean of need percentages, plus a modifier list (`add_modifier(id, value, duration_hours)`) mirroring StatModifiers in spirit — this is where "menial work" penalties, food quality boosts, and event effects plug in later. **Consequence v1:** pawn work speed multiplier `lerp(0.5, 1.1, happiness)` applied to construction work rate and processor-adjacent jobs (via a `PawnBase.work_speed()` accessor jobs consult); mining drones unaffected (no needs component).
- **Critical-need handling** (the starvation-lock problem in the code comments): no forced interrupts. Instead: at `percent_critical`, (a) the queued need-job is moved to queue front, (b) a station **alert** is emitted (`SignalBus.pawn_critical_need(pawn, need)`) shown in a minimal alerts strip in the main UI. Pawns visibly suffering + player informed beats deadlock-prone auto-interrupts.

## Files to touch
- `pawns/pawn_needs_component.gd` — generalize: a small `NeedDef` inner class or per-need blocks for sleep/entertainment/social matching hunger's queue logic; happiness calc + modifiers; critical alerts. Enable `has_sleep_need` etc. in `pawns/crew_pawn.tscn`
- **New:** `scripts/jobs/job_sleep.gd`, `scripts/jobs/job_recreate.gd`, `scripts/jobs/job_socialize.gd` (category NEEDS per WI-04)
- **New:** `modules/components/sleep_component.gd` (+ `.tscn` component scene per existing component conventions)
- `modules/components/entertainment_component.gd`, `social_component.gd` — implement (they're empty class stubs)
- `modules/crew/basic_sleeping_pod.tscn` — add SleepComponent; **remove the embedded `crew_pawn.tscn` instance / PawnStorageComponent spawning** if present (pods should not create crew; that becomes WI-07's job — check `basic_sleeping_pod.tscn` which references crew_pawn.tscn, and `starting_module.tscn`; leave starting module's spawns for now, they're the starter crew)
- `modules/crew/mess_hall.tscn` — add SocialComponent
- **New module:** holodeck or lounge — scene + `data/modules/crew/holodeck_mdata.tres` + unlock entry in a tree (`data/unlocks/…`) — smallest full pass through the content pipeline, validates it
- `pawns/pawn_base.gd` — `work_speed()`; queue-front promotion helper
- `scripts/jobs/job_construct_module.gd` — multiply work rate by `pawn.work_speed()`
- `ui/pawns/pawn_needs_tab.gd` — show all needs + happiness (check current state; extend rows)
- `ui/ui_main.gd` (or new `ui/alerts_strip.gd`) — minimal alert display for critical needs
- `scripts/managers/signal_bus.gd` — `pawn_critical_need` signal
- WI-03 followup: needs values into pawn save section (should fall out of existing pawn serializer; verify fields)

## Implementation order
1. SleepComponent + Job_Sleep + pod scene wiring (hardest: occupancy slots + animation + duration-based restore; get one need fully right first).
2. Generalize the queue-a-need logic in PawnNeedsComponent (dedupe the hunger copy-paste while adding sleep).
3. Entertainment + Social components and jobs (fast, following the pattern).
4. Happiness derivation + modifiers + work_speed consequence.
5. Critical alerts + queue-front promotion.
6. Needs tab UI + new module content (holodeck) + unlock entry.

## Edge cases
- All pods occupied → Job_Sleep `can_do_job` false → pawn keeps working, retries next queue check; exhaustion floor: sleep at 0 applies a heavy happiness penalty (not collapse v1 — collapse needs "pathfind to position" work that isn't built).
- Pawn sleeping when module is deconstructed/deleted → `module_removed` signal → job cancels gracefully, pawn ejected (current_module null-safe already via `_on_module_removed`).
- Sleeping pawn's slot must free on ANY job end path (release in `cancel()`, per WI-04 contract).
- Two needs critical at once → both queued front; order = most-critical-percentage first (sort personal queue insert).
- Save/load mid-sleep → job not persisted (WI-03 rule); pawn wakes standing in the pod module, re-queues sleep if still tired. Verify no slot-leak (slots are runtime state, rebuilt empty on load).
- Need decay while doing the satisfying job (eating while hungry) — restore rate must exceed decay by construction; assert in NeedDef setup.
- Pawns in space (EVA construction) with a critical need — Job_Sleep can_do_job requires reachability; space-stranded pawns already fail gracefully.
- Happiness with a need disabled (`has_*_need = false`, e.g. future robots) — excluded from the weighted mean, not counted as 0.

## Verification
1. Speed time 4×: crew visibly cycles — work, eat at mess hall, sleep in pods (layDown animation), occasionally holodeck/socialize. Watch 3+ full cycles without stuck pawns.
2. Remove all food: hunger alert fires at critical, pawns keep attempting other work between eat retries (no deadlock — the original bug scenario).
3. Build 1 pod for 3 crew: pod contention resolves (queueing, no double-occupancy), latecomers' sleep tanks, their happiness drops, their construction work rate visibly slows (time a wall build with rested vs. exhausted pawn).
4. Needs tab: all five bars + happiness live-update; alert strip shows/clears.
5. Save/load mid-cycle: needs values survive; sleepers resume sensibly.
6. New holodeck module: locked until unlock purchased → buildable → serves recreation. (Validates the whole content pipeline end-to-end.)
