# WI-05 — Needs Completion: Sleep, Recreation, Happiness

## Goal
Bring the remaining pawn needs to the same working state as hunger — sleep, recreation, and health (job-less, self-healing, damaged by starvation) — and derive a happiness value with visible consequences (productivity multiplier v1; departure comes in WI-07). Serving modules: sleeping pod (exists as scene), holodeck-style recreation (EntertainmentComponent stub), social spaces (SocialComponent stub — mess hall & future promenade); health has no serving module yet (Medical Bay out of scope).

## Design
- **Pattern per need** (copying the hunger/Job_Eat template):
  - Decay in game-hours (WI-02).
  - Below `percent_to_look_for_needs` → queue a personal job (never on the shared board).
  - Job: find best reachable serving component → move → occupy for a duration → need restores over the stay.
- **Sleep:** `SleepComponent` (new, on sleeping pod module) with `capacity` slots and `sleep_quality` multiplier. Job_Sleep: pawn occupies a slot, plays `layDown` animation (frames exist in the sprite kit), restores sleep over ~`8 game-hours / quality`. Slot reservation so two pawns don't share a pod. **Ownership (assigned beds) is out of scope v1** — first free pod wins. If [[WI-16_Micro_Anchors_and_Pawn_Positioning]] has landed, sleep slots should be authored BUNK anchors (pawn lies on the bunk, not at module center); otherwise "stand anywhere in the module" is the accepted v1 and anchors upgrade it later.
- **Recreation (includes socializing):** Social is **not** its own need — socializing is one way of restoring recreation. Both `EntertainmentComponent` and `SocialComponent` are *recreation providers* behind a small shared base (`RecreationProviderComponent`: `capacity`, occupy/release, `recreation_per_hour(pawn)`). Entertainment restores at a flat `fun_per_hour` (optional `power_consumption_component` gate); social restores faster per additional pawn present in the module (simple count of pawns whose `current_module` is this one — a solo pawn at a social space still restores, just at base rate). One job: **Job_Recreate** gathers all reachable providers of *either* kind and picks randomly from the combined pool (v1 randomness; degrades gracefully — early game the mess hall is likely the only provider), then occupies up to N hours or until full. There is no Job_Socialize. Deep conversation simulation: no.
- **Health:** the fourth need, but inverted and job-less. Lives in its own `PawnHealthComponent` (PawnComponent), deliberately severed from PawnNeedsComponent — it doesn't decay like the others and will interact with future systems (combat injuries, disease) that the other needs never touch. Behavior: passively ticks **up** over time (self-healing, exported rate); while starving (hunger at 0) it ticks **down** instead (exported rate — decay *replaces* regen, they don't fight). No Job_Heal and no Medical Bay — out of scope for now. Health still feeds the happiness weighted mean: PawnNeedsComponent reads the sibling component via `get_component_by_type`, and an absent component is excluded from the mean (same rule as disabled needs — automatically covers drones). Critical health emits the same `pawn_critical_need` alert (informational only; there's no job to queue). Health at 0 does nothing yet — no pawn death system exists (WI-07+ territory); clamp at 0 and let the tanked happiness be the v1 consequence.
- **Passive socializing (optional stretch — step 8, severable):** long-term, socializing should also happen ambiently during other tasks. `SocializeComponent` (PawnComponent, crew pawns only) checks on `slow_tick` whether `current_module` holds another pawn with the same component and ticks *both* pawns' recreation slightly — component presence naturally excludes drones. **Balance guard is mandatory:** passive restore capped hard (can only lift recreation to ~50%; active recreation required above that), otherwise crowded stations never decay recreation and Job_Recreate becomes dead code. The rate itself must modestly *exceed* decay (implemented: 9/hr gross vs ~6.7/hr decay) — below decay it would never visibly restore, only slow the slide, defeating the point. Don't tune this until steps 1–6 are observable; fine to split off entirely if it drags.
- **Happiness:** computed on `PawnNeedsComponent` as weighted mean of need percentages, plus a modifier list (`add_modifier(id, value, duration_hours)`) mirroring StatModifiers in spirit — this is where "menial work" penalties, food quality boosts, and event effects plug in later. **Consequence v1:** pawn work speed multiplier `lerp(0.5, 1.1, happiness)` applied to construction work rate and processor-adjacent jobs (via a `PawnBase.work_speed()` accessor jobs consult); mining drones unaffected (no needs component).
- **Critical-need handling** (the starvation-lock problem in the code comments): no forced interrupts. Instead: at `percent_critical`, (a) the queued need-job is moved to queue front, (b) a station **alert** is emitted (`SignalBus.pawn_critical_need(pawn, need)`) shown in a minimal alerts strip in the main UI. Pawns visibly suffering + player informed beats deadlock-prone auto-interrupts.

## Files to touch
- `pawns/pawn_needs_component.gd` — generalize: a small `NeedDef` inner class or per-need blocks for sleep/recreation matching hunger's queue logic (no separate social need — drop any `has_social_need`); happiness calc + modifiers; critical alerts. Enable `has_sleep_need` etc. in `pawns/crew_pawn.tscn`
- **New:** `scripts/jobs/job_sleep.gd`, `scripts/jobs/job_recreate.gd` (category NEEDS per WI-04) — no job_socialize; Job_Recreate covers both provider kinds
- **New:** `modules/components/sleep_component.gd` (+ `.tscn` component scene per existing component conventions)
- **New:** `modules/components/recreation_provider_component.gd` — shared base: `capacity`, occupy/release, `recreation_per_hour(pawn)`
- `modules/components/entertainment_component.gd`, `social_component.gd` — implement against the shared base (they're empty class stubs); subclass only differentiates the restore rate
- **New:** `pawns/pawn_health_component.gd` — self-heal regen, starvation decay, critical alert; wire into `pawns/crew_pawn.tscn` (drones don't get one)
- **Optional (step 8):** `pawns/socialize_component.gd` — passive ambient socializing PawnComponent, crew pawns only
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
3. RecreationProviderComponent base + Entertainment/Social subclasses + Job_Recreate picking from the combined provider pool (fast, following the pattern).
4. PawnHealthComponent: self-heal regen + starvation decay + critical alert (simple, job-less — but do it before happiness so happiness has all its inputs).
5. Happiness derivation (health included via sibling lookup) + modifiers + work_speed consequence.
6. Critical alerts + queue-front promotion.
7. Needs tab UI + new module content (holodeck) + unlock entry.
8. *(Optional, severable)* SocializeComponent passive recreation tick — only after steps 1–7 verify, with the rate/cap balance guards from the Design section.

## Edge cases
- All pods occupied → Job_Sleep `can_do_job` false → pawn keeps working, retries next queue check; exhaustion floor: sleep at 0 applies a heavy happiness penalty (not collapse v1 — collapse needs "pathfind to position" work that isn't built).
- Pawn sleeping when module is deconstructed/deleted → `module_removed` signal → job cancels gracefully, pawn ejected (current_module null-safe already via `_on_module_removed`).
- Sleeping pawn's slot must free on ANY job end path (release in `cancel()`, per WI-04 contract).
- Two needs critical at once → both queued front; order = most-critical-percentage first (sort personal queue insert).
- Save/load mid-sleep → job not persisted (WI-03 rule); pawn wakes standing in the pod module, re-queues sleep if still tired. Verify no slot-leak (slots are runtime state, rebuilt empty on load).
- Need decay while doing the satisfying job (eating while hungry) — restore rate must exceed decay by construction; assert in NeedDef setup.
- Pawns in space (EVA construction) with a critical need — Job_Sleep can_do_job requires reachability; space-stranded pawns already fail gracefully.
- Happiness with a need disabled (`has_*_need = false`, e.g. future robots) — excluded from the weighted mean, not counted as 0.
- Job_Recreate's randomly chosen provider full/unreachable by the time the pawn commits → fall back to the remaining pool before failing the job entirely.
- Solo pawn at a social space → still restores at base rate (slow but valid), never zero — otherwise a lone early-game pawn can never satisfy recreation.
- *(If step 8 lands)* passive tick must respect the restore cap, never fire for pawn pairs where either lacks SocializeComponent (drones), and no-op mid-EVA (`current_module` null already handles that).
- Starvation decay *replaces* self-heal regen while hunger is 0 — never apply both in the same tick, and regen resumes as soon as the pawn eats anything.
- Health lives outside PawnNeedsComponent, so the WI-03 save followup must cover it separately: PawnHealthComponent needs its own get/load_save_data (verify pawn serializer picks up sibling components).
- Pawn with health critical but food available — no special behavior: eating fixes the cause, regen fixes the value; the alert is just information.

## Verification
1. Speed time 4×: crew visibly cycles — work, eat at mess hall, sleep in pods (layDown animation), occasionally holodeck/socialize. Watch 3+ full cycles without stuck pawns.
2. Remove all food: hunger alert fires at critical, pawns keep attempting other work between eat retries (no deadlock — the original bug scenario). Leave them starving: once hunger hits 0, health visibly ticks down and its own critical alert fires; restore food and health self-heals back up.
3. Build 1 pod for 3 crew: pod contention resolves (queueing, no double-occupancy), latecomers' sleep tanks, their happiness drops, their construction work rate visibly slows (time a wall build with rested vs. exhausted pawn).
4. Needs tab: all four need bars (hunger, sleep, recreation, health) + happiness live-update; alert strip shows/clears. No separate social bar.
4b. Station with *only* a mess hall (no holodeck): recreation still gets satisfied via the social provider.
5. Save/load mid-cycle: needs values survive; sleepers resume sensibly.
6. New holodeck module: locked until unlock purchased → buildable → serves recreation. (Validates the whole content pipeline end-to-end.)
7. *(If step 8 lands)* Two idle crew sharing a module tick recreation up slowly (capped); a crew + drone pair doesn't; recreation still decays overall on a busy station (Job_Recreate not obsoleted).
