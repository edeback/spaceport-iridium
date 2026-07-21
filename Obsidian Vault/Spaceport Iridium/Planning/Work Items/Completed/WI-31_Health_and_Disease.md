# WI-31 — Health & Disease

## Goal
Expand crew health: diseases with staged effects (health drain, skill maluses, worsening untreated), transmission between co-located pawns, a Medical Bay where crew heal and get treated (with a Doctoring job whose quality depends on the doctor's Medical skill), and air purifiers that passively suppress spread nearby. Acquisition v1: events (outbreak), space-exposure sickness, and a hook for infected visitors (activates with WI-33). Diseases have per-station-level unlock, no disease (and therefore no outbreak events either) at station level 1.

## Design
- **`DiseaseData`** .tres in `data/diseases/` (ResourceScanner): id, name, description, `stages: Array` of `{duration_hours, health_drain_per_hour, skill_maluses: {skill: -levels}, mood_modifier}`, `contagious_rate` (0 = non-infectious), `acquisition` tags (outbreak/space/visitor), treatment parameters (`treat_hours_base`, `cure_at_stage_reset: bool`), station unlock level. v1 content: **Station Flu** (contagious, mild drain, social/crafting malus, worsens to heavy drain), **Void Sickness** (non-contagious, from cumulative EVA hours, intellectual/accuracy malus), **Fervent Fever** (mildly contagious, mild drain, minus intellectual/social, **bonus** movement speed).
- **`PawnDiseaseComponent`** (crew scene only; robots never): active diseases `{disease_id: {stage, stage_hours}}`. Per sim-hour: advance stage timers, apply stage effects —
  - health drain joins the WI-24/WI-17 pattern in `PawnHealthComponent`: a `disease_drain_per_hour` contribution that *stacks* with starvation/suffocation and, like them, suppresses regen while any drain is active (extend the exclusivity rule: regen only when no drain source active).
  - skill maluses: `PawnSkillsComponent.skill_mult` consults a malus overlay set by the disease component (temporary level reduction, floor 0).
  - mood: timed modifier per stage via `add_modifier(disease_id, …)`.
- **Transmission.** On `hour_changed`: for each contagious sick pawn, pawns sharing its `current_module` roll `contagious_rate × hours` — scaled down by the module's `purified_air` adjacency field (WI-30) and skipped entirely for robots and pawns already infected. One roll site in the disease component (iterate module occupants — pawn group filter by module; hourly cadence keeps it cheap).
- **Medical Bay.** New module (crew tree; tier-gated per WI-26): `MedicalComponent` with treatment slots (BUNK anchors), and a WORKSTATION anchor for the doctor.
  - **Patient side:** sick/injured crew queue `Job_GetTreatment` (NEEDS; queued at disease detection or health < threshold, promoted when critical — the WI-05 pattern): lie in a bunk (lay_down anchor animation, WI-23); while occupied, accelerated health regen (overrides the no-regen-while-diseased rule) and treatment progress accrues on their disease.
  - **Doctor side:** `Job_Doctor` (WORK, `get_skill()` = medical, workspace-assignable per WI-23) posts while patients occupy slots: doctor works at the workstation; treatment progress rate × `skill_mult(medical)`. Untended patients treat at a slow baseline (auto-med systems) — a doctor makes it several times faster; exported rates.
  - **Cure:** treatment progress ≥ disease's `treat_hours` → cured (or stage regression per data flag). Untreated diseases run their stages to the final one, which persists until treated (drains indefinitely — death only via the existing health-at-0-does-nothing rule until pawn death exists; keep that boundary explicit).
- **Air purifier module.** Small module: powered + `AdjacencyEmitterComponent` radiating `purified_air` (WI-30 delivers the mechanism; this WI ships the module + the transmission consumption).
- **Void Sickness accrual:** `PawnBreathingComponent` (or the disease component) tracks cumulative exterior hours; roll chance per EVA hour beyond a threshold, reset partially by cycles inside.
- **Outbreak event:** `data/events/outbreak.tres` + `EffectDiseaseOutbreak` (infect 1–3 random crew with a data-chosen disease). Only possible when at least one disease is unlocked, and can only choose an infectious disease (in this case, no Void Sickness).
- **UI:** pawn panel health tab lists diseases + stage + treatment state; alerts on infection and on worsening.
- **Save:** disease states + EVA accrual in the pawn section; treatment jobs via WI-21.

## Files to touch
- **New:** `data/diseases/disease_data.gd` + 3 .tres, `pawns/pawn_disease_component.gd`, `modules/medical/medical_bay.tscn`, `air_purifier.tscn` + mdata/unlock .tres, `modules/components/medical_component.gd`, `scripts/jobs/job_get_treatment.gd`, `job_doctor.gd`, `data/events/effects/effect_disease_outbreak.gd`, `data/events/outbreak.tres`
- `pawns/pawn_health_component.gd` — disease drain + regen exclusivity extension + medical-bay regen override
- `pawns/pawn_skills_component.gd` (WI-22) — malus overlay
- `pawns/pawn_breathing_component.gd` — EVA-hours accrual
- Crew pawn scene — disease component
- `ui/pawns/pawn_needs_tab.gd`/health tab — disease display
- `scripts/managers/save_manager.gd` — pawn-section fields
- WI-33 note: visitor arrival roll hooks `acquisition: visitor`
- Remember: `filesystem_manage(op="scan")` after new `class_name` files

## Implementation order
1. DiseaseData + disease component + stage effects (infect via cheat: `Global.cheats.infect(pawn, id)`), health-drain integration.
2. Transmission + purifier scaling hook (purifier module itself can land with or after WI-30's emitter plumbing — sequence assumes WI-30 done).
3. Medical Bay: patient flow, then doctor flow.
4. Void Sickness accrual + outbreak event.
5. UI, save, tests.

## Edge cases
- Doctor catches the flu from the patient: transmission counts the bay like any module — intended, purifiers near medical are the counterplay; doctor keeps working while sick (maluses apply).
- The only doctor is the patient: `Job_Doctor` requires a pawn other than the occupant; solo-crew stations rely on baseline auto-treatment.
- Patient's treatment interrupted (raid alert, starvation): `Job_GetTreatment` cancels gracefully, progress persists on the disease state, re-queues.
- All bunks full: NEEDS job waits in the personal queue (no board spam); critical patients promote to queue front — but can't jump the bunk queue; alert "medical capacity exceeded".
- Two diseases at once: drains stack, maluses take the worse per skill, both treat sequentially (one treatment progress at a time, worst-first).
- Disease modifiers must re-apply from disease state on load, not save as modifiers (the WI-22 trait rule).
- Outbreak event on a 2-crew station: cap infections at crew − 1 so it's survivable.
- Transmission roll when a conveyor/robot shares the module: robots excluded by component absence — verify the occupant filter.
- No outbreaks when no disease is unlocked (station level 1), even via event.

## Verification
1. Cheat-infect a pawn: stage effects appear (drain, malus visible in skills tab, mood), worsen on schedule untreated.
2. Sick pawn + healthy pawn share a corridor for hours: transmission occurs at the expected rate; add a purifier next door → measurably rarer (force rates high for the test).
3. Medical Bay: patient walks in, lies down; doctor mans the station; treatment completes several times faster than untended baseline; skill-10 doctor beats skill-0.
4. Void Sickness: park a miner on long EVA rotations → eventually sick; interior crew never.
5. Outbreak event fires and resolves end-to-end through treatment. Can not fire when no diseases available to be chosen. Void Sickness never chosen.
6. Save/load mid-disease, mid-treatment: stages, progress, EVA accrual round-trip; no doubled modifiers.
7. Regression: healthy-station behavior unchanged; suffocation/starvation drain interplay still correct (all three at once stack).
