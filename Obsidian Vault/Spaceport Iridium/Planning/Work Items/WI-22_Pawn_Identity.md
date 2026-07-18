# WI-22 — Pawn Identity: Names, Variance, Skills, Traits, Hiring Choice

## Goal
Pawns get generated names, visual variance (v1: modulate tint), a ten-skill system that modifies job quality/speed and grows with use, and traits (bonuses/maluses/flavor). Hiring becomes a choice among generated candidates whose price reflects skills and traits. This is load-bearing for half of Phase 3: Work Improvements consumes skills, Economic Sinks prices wages off hire cost, Combat reads Accuracy, Health reads Medical.

## Design
- **Names.** Vendor the m12 Name Generator (https://github.com/monk125/m12-name-generator) behind a thin `NameGenerator` utility (`scripts/utility/name_generator.gd`) so faction-specific styles can swap in later without touching call sites; if m12 doesn't drop cleanly into 4.7/typed-GDScript, fall back to a syllable-table generator inside the same utility (same API, ~50 lines). `PawnBase.pawn_name` already exists; set at spawn, show in pawn panel + nameplate hover.
- **Tint.** Per-pawn `modulate` on the AnimatedSprite2D, rolled from a curated palette at spawn (not full random — keep them readable against module interiors). Unlike `speed_jitter` this is identity, so it saves (pawn section). Different sprites are future work (asset-bound).
- **Skills.** New `PawnSkillsComponent` (`pawns/pawn_skills_component.gd`). Skill set (StringName keys): `accuracy, skirmishing, construction, mining, growing, crafting, medical, social, intellectual, leadership`. Definitions as `SkillData` .tres in `data/skills/` (display name, icon, xp curve constants — balance in data per the invariant), discovered via `ResourceScanner`. Runtime state per pawn: `{skill: {level: int 0..10, xp: float}}`.
  - **Effect on work:** `skill_mult(skill) -> float` mapping level→multiplier (e.g. lerp 0.6..1.5 across 0..10; exact curve in SkillData). Jobs consult it the same way they consult `work_speed()` today: `JobBase` gains `get_skill() -> StringName` (default `&""` = unskilled job); job subclasses declare theirs (construct/repair→construction, mine→mining, etc.). Quality effects (food quality, treatment quality) come in the consuming WIs — this WI ships speed/efficiency only.
  - **XP:** on successful completion (`_end_current_job`, only when `is_finished()`), pawn grants a small xp amount to `current_job.get_skill()`; long jobs can also trickle xp in `process_job` via the job calling a helper (mining trips are long — trickle there, else completion-only). Level-up emits a signal for UI/alert flavor.
- **Traits.** `TraitData` .tres in `data/traits/` (id, name, description, hooks) + `PawnTraitsComponent` holding 0–2 per pawn. v1 hook surface, deliberately narrow:
  - flat happiness offset (Optimist +, Pessimist −) → a permanent (`INF` duration) modifier via `PawnNeedsComponent.add_modifier` keyed by trait id
  - damage multiplier (Hardy 0.75, Weak 1.25) → consulted by `PawnHealthComponent` wherever decay/damage applies
  - social/recreation hooks (Introvert: no passive-social gain, +recreation when alone in a module; Extrovert: double passive-social gain, higher cap) → consulted by `SocializeComponent`/recreation logic
  - Spacer: happiness modifier active while `current_module == null` (exterior)
  - Conceited is deferred (needs module quality tiers — Phase 4 note).
  - Traits express through *existing* systems' queries, not their own process loops.
- **Hiring choice.** `CrewManager` generates a candidate pool: `HireCandidate` (name, tint, rolled skills — mostly low with 1–2 standouts, 0–2 traits, computed price). Price = `hire_cost` base × skill premium × trait modifier (good traits up, bad down); formula constants exported on CrewManager. Pool of 3–5, refreshed each trader visit (`trader_arrived`) and on tier-up later. `ui_crew_recruitment` becomes a candidate list (name/skills/traits/price) → `request_hire(bay, candidate)`; arrival flow (shuttle, sleep-capacity gate, refund) unchanged. The pawn's hire price is stored on the pawn — WI-25 wages read it.
- **Save:** pawn section gains name, tint, skills, traits, hire_price; CrewManager section gains the candidate pool. Existing starting crew get median stats rolled on migration.

## Files to touch
- **New:** `pawns/pawn_skills_component.gd`, `pawns/pawn_traits_component.gd`, `scripts/utility/name_generator.gd`, `data/skills/skill_data.gd` + ten .tres, `data/traits/trait_data.gd` + ~8 .tres, vendor `addons/m12_name_generator/` (or fallback tables)
- `pawns/pawn_base.gd` — tint, xp grant in `_end_current_job`, hire_price
- `scripts/jobs/job_base.gd` + skill-relevant subclasses — `get_skill()`, `skill_mult` consumption (construction job already consults `work_speed()`; multiply, don't replace)
- `pawns/pawn_needs_component.gd`, `pawn_health_component.gd`, `pawns/socialize_component.gd` — trait hook queries
- `scripts/managers/crew_manager.gd` — candidate generation/pool/pricing, `request_hire(bay, candidate)`
- `ui/windows/ui_crew_recruitment.gd/.tscn` — candidate list UI; `ui/pawns/pawn_info_panel.gd` + new skills/traits tab
- `scripts/managers/save_manager.gd` — pawn section fields, migration
- Crew pawn scene — add the two components
- Remember: `filesystem_manage(op="scan")` after each new `class_name`

## Implementation order
1. NameGenerator + tint + pawn panel display (pure cosmetics, ships alone).
2. Skills component, SkillData, `get_skill()` on jobs, speed multiplier through construction + mining first; xp gain; skills tab.
3. Traits component + the six v1 traits through their host-system hooks.
4. Hiring candidates: generation, pricing, recruitment UI, hire flow.
5. Save/migration for all of the above.

## Edge cases
- Drones/robots: no skills/traits components → `skill_mult` path must no-op to 1.0 (same pattern as `work_speed()` for pawns without needs).
- Trait happiness modifiers must survive save/load — they're re-applied from the trait list on load, NOT saved as modifiers (avoid double-apply; mirror how EventManager re-applies station-wide effects).
- Introvert "alone in a module" check: evaluate on `module_changed` + slow_tick, never per-frame group scans.
- Candidate pool with 0 affordable candidates: UI shows them greyed with prices — no free hire fallback; pool refresh must not fire while the recruitment window is open mid-selection (or the UI re-reads on refresh signal).
- XP for jobs cancelled at 99%: none (completion-only) — acceptable; trickle-xp jobs (mining) keep what they earned.
- Two standout skills both rolled on a cheap candidate: price formula must be monotonic in total skill so no "elite for free" rolls.
- Skill multiplier interaction with `work_speed()` happiness multiplier: multiplicative, and clamp the product so min-happiness min-skill never hits near-zero progress (floor ~0.3).

## Verification
1. New game: every pawn uniquely named and tinted; pawn panel shows skills/traits.
2. Set a pawn's construction to 0 and another's to 10 (`Global.cheats` helper — add `set_skill`): same module build, measurably different times; xp visibly accrues and levels up with an alert.
3. Optimist vs Pessimist pawns diverge in steady-state happiness by the expected offset; Hardy pawn loses health slower under forced starvation than Weak.
4. Recruitment: pool shows 3–5 candidates with coherent prices (high-skill = expensive); hiring one removes them from the pool; arrival/refund flow regression-clean.
5. Save/load: names, tints, skills (incl. partial xp), traits, and the candidate pool round-trip; happiness modifiers not doubled.
6. GUT: pricing formula and xp-curve unit tests; migration of a pre-WI-22 save loads with rolled median crew.
