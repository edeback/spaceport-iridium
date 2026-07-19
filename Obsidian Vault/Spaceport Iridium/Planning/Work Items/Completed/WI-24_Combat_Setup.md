# WI-24 — Combat Setup: Module HP, Repair Jobs, Breakdowns, Pirate Extortion

## Goal
The framework for the station getting damaged and repaired, ahead of real space battles (WI-32): every module has hit points; damage shows via shader and degrades the module's output; non-truss modules are destroyed at 0 HP (truss replaces them, as removal already does); truss becomes "damaged" instead of destroyed so the station can never split; pawns repair damage over time (no resources); WI-17 hull breaches become repair jobs; modules occasionally break down; and a pirate "raid" event offers pay-or-suffer — actual ship combat comes later.

## Design
- **HP.** `ModuleData` gains `max_hp` (balance in .tres; trusses and armor high, solar panels low). `ModuleBase` gains `hp` (init to max on build; blueprints use a fraction of progress — v1: blueprints are simply destroyed at 0 without truss nuance), `apply_damage(amount, source: StringName)`, `repair(amount)`, and signals through SignalBus: `module_damaged(module, amount)`, `module_destroyed(module)`, `module_repaired(module)`.
- **Damage → shader.** New `DAMAGE` shader param (0..1 = 1 − hp/max) alongside PREVIEW/SELECTED/PROGRESS in the shared module shader; `_update_shader` writes it on hp change (scorch/crack overlay in the shader; art can iterate independently).
- **Damage → efficiency.** Reuse the StatModifiers layer: on hp change, `ModuleBase` writes a MULT modifier with reserved source `&"damage"` — value `lerp(min_damaged_efficiency, 1.0, hp/max)` — onto the stats the module's components consume (`process_time` inverse, power output, mining rate…). Mechanically: add a small set of shared stat keys — `power_output` consumed by `PowerGenerationComponent`/`SolarPowerComponent` through `get_effective_stat` (they must start routing their output through it if they don't yet), `process_time` already exists, `mining_rate` for MiningComponent. One helper on ModuleBase (`_refresh_damage_modifier()`) keeps it in one place. StatModifiers needs an update-in-place/remove-by-source API if it lacks one.
- **Destruction.** `apply_damage` reaching 0 on a non-truss module → the existing `remove_module` flow (which already ejects stored resources as debris via `pre_delete` and auto-places truss via `replacement_on_delete`); pawns inside are handled by existing module_removed reactions (they end up in space/adjacent — verify, this becomes combat-critical). **Truss at 0 HP** → `damaged` state instead: stays placed, keeps StructureManager attachment (station can't split), but its PathComponent traversal cost multiplies heavily (EVA over wreckage) until repaired to a threshold. No module is ever removed by damage if it's the structural layer's placeholder.
- **Repair jobs.** New `Job_Repair` (Category WORK, `get_skill()` = construction). Posting: a slow_tick scan in a new small `RepairManager`… no — keep composition: `ModuleBase` posts its own repair job when `hp < max_hp` after a grace period (avoid posting during active bombardment spam: post when damaged and no job outstanding, re-post on cancel). Pawn paths to the module (workstation anchor if present, else adjacent/inside), works `repair_rate` HP/hour × skill × work_speed. No resource cost (per design; destroyed modules are gone — rebuild is construction's job).
- **Breach repair.** `AtmosphereComponent`'s breach gains a repair path: `Job_RepairBreach` (or `Job_Repair` flavored by target) that seals the breach on completion; the WI-17 self-seal timer is retained as the long fallback (repair is much faster). Sealing via repair emits the existing `module_breach_sealed`.
- **Breakdowns.** Per built module with a new `can_break_down` ModuleData flag (industrial modules true): each `hour_changed`, roll `breakdown_chance_per_hour` (tiny, .tres). Effect (rolled): direct damage (small % of max_hp) OR a `&"breakdown"` MULT modifier (e.g. 0.5× output) that persists until a repair job completes on the module. Alert on breakdown. WI-30's Maintenance Facility will reduce the chance via adjacency later — read the chance through `get_effective_stat(&"breakdown_chance", …)` now so that hook is free.
- **Pirate extortion event.** `data/events/pirate_extortion.tres` + new `EffectPirateRaid` event effect: choice A "Pay them off" (large credit cost — event choice cost gating already exists), choice B "Refuse" → damage + hull breaches across 2–4 random built modules (reuses `apply_damage` + the `EffectHullBreach` mechanism). Weight/cooldown/min-cycle tuned so it's rare and mid-game (condition: min credits or min module count so a day-1 station never sees it). This event gets replaced/expanded by WI-32's real raids.
- **Save:** `hp` + truss-damaged state + active breakdown modifiers in the module section (WI-21's job save handles in-flight repairs).

## Files to touch
- `data/modules/module_data.gd` — `max_hp`, `min_damaged_efficiency`, `can_break_down`, `breakdown_chance_per_hour`; sweep existing module .tres for values
- `modules/templates/module_base.gd` — hp, damage/repair API, damage modifier refresh, repair-job posting, save fields
- `modules/templates/stat_modifiers.gd` — remove/update-by-source API if missing
- Module shader (`modules/**/*.gdshader` wherever the shared one lives) — DAMAGE param + visual
- `modules/components/power_generation_component.gd`, `solar_power_component.gd`, `mining_component.gd` — route output through `get_effective_stat`
- `modules/truss.gd` — damaged state, traversal cost multiplier via its PathComponent
- **New:** `scripts/jobs/job_repair.gd` (+ breach variant), `data/events/effects/effect_pirate_raid.gd`, `data/events/pirate_extortion.tres`
- `modules/components/atmosphere_component.gd` — breach repairable hook
- `scripts/managers/signal_bus.gd` — damaged/destroyed/repaired signals
- `ui/windows/module_info_ingame_panel.gd` — HP bar + damaged/breakdown status line
- WI-21 followup: `Job_Repair` save entry; WI-19 followup: breakdown-roll and damage-modifier unit tests

## Implementation order
1. HP + `apply_damage`/`repair` + shader param + HP bar (cheat: `Global.cheats.damage_module(cell, amount)`).
2. Damage→efficiency modifier plumbing (incl. routing power/mining through effective stats).
3. Destruction path + truss damaged state.
4. `Job_Repair` + breach repair.
5. Breakdowns.
6. Pirate extortion event.

## Edge cases
- Module destroyed while a pawn works inside (repairing it, even): existing module_removed flow must leave the pawn somewhere sane — this is the test to write *first*, WI-32 will hammer it.
- Destruction of a module holding atmosphere: gas dies with it (WI-17 rule), neighbors keep their pressure but the new truss is vacuum — verified behavior, just re-verify via the damage path.
- Repair job on a module that gets destroyed mid-repair: `is_valid` fails on the dead ref → clean cancel.
- Damage during construction (blueprint): reduces construction progress? No — v1: blueprints have token HP and die at 0, materials already delivered are lost as debris (harsh but simple; note for balance pass).
- Truss damaged state + turbolift/corridor stacked on the same cell: damage targets one layer's module; stacked modules are independent HP pools.
- Breakdown modifier + damage modifier both active: multiplicative by design (StatModifiers sources are independent).
- Extortion "pay" choice when the player can't afford it: choice greys out (has_free_choice guard exists — refuse is the free choice).
- Repair must not fight the priority bands: WORK category, normal priority — construction hauling (+99) always outranks it.

## Verification
1. Cheat-damage a refinery to 50%: sprite visibly damaged, throughput measurably halved (watch batch times), repair job posts, pawn repairs to full, modifier and visual clear.
2. Cheat-damage to 0: module ejects stored resources as debris, truss appears, path/structure graphs stay consistent (`logs_read` clean, pawns re-path).
3. Damage a truss to 0: it stays, EVA across it is slow, station never splits; repair restores cost.
4. Force a breakdown: alert fires, output drops, repair clears it.
5. Fire pirate_extortion via debug: pay path deducts credits; refuse path damages + breaches multiple modules, O2 drains, repair jobs + breach repairs restore the station end-to-end.
6. Save/load: hp values, damaged truss, breakdown modifiers, in-flight repair jobs all round-trip.
7. Regression: undamaged modules behave identically (effective-stat routing must be a no-op at full HP); GUT tests green.
