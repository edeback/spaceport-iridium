# WI-32 — Combat v1: Pirate Ships, Station Defenses

## Goal
First real space battles on top of WI-24's damage framework: pirate ships with HP and laser weapons fly around the station (no collision) shooting the modules nearest to them; the station fights back with weapon modules (firing arcs, energy cost), armor plating (high-HP buffers), and shields (circular absorption zones with a slowly-charging capacitor). Raids end by pay-off ("surrender" hail, available any time), by driving the pirates off (they flee at low HP), or by attrition.

## Design
- **`RaidManager`** (new manager node, `Global.raid_manager`): owns raid lifecycle — spawn wave, track ships, hail/payoff pricing, flee checks, victory/defeat resolution, and raid serialization. Raids trigger via the event system: WI-24's `pirate_extortion` upgrades — refusing (or a new `pirate_raid` event once defenses exist) calls `RaidManager.start_raid(strength)`. Strength scales with station value (module count/credits — exported formula).
- **Pirate ships.** `objects/pirate_ship.gd/.tscn` (Node2D, patterned on ArrivalShuttle's flight but persistent): `hp`, `speed`, `laser_damage`, `fire_interval`, `preferred_range`. Flight: pick orbit waypoints around the station's bounding area (outside the module grid), glide between them, no collision with anything. Sim-scaled movement (`scale(delta)`), pauses cleanly.
  - **Targeting:** only *exposed* modules — the module whose footprint is nearest the ship along the fire line, never interior-through-hull. Implementation: 2D ray/grid-march from ship toward a candidate cell; first cell occupied on any structural layer is the target (WorldManager cell maps make this cheap). Re-pick after each kill or on waypoint change.
  - **Firing:** every `fire_interval` sim-seconds while a target is in range: beam VFX (Line2D flash + impact particles + module damage-flash) → `target.apply_damage(laser_damage, &"pirate_laser")` — WI-24 handles efficiency loss, destruction, truss rules; breaches: laser kills on atmosphere modules roll a breach via the existing mechanism *before* destruction threshold (exported chance on hit).
- **Weapon modules.** `modules/defense/laser_turret.tscn` + `WeaponComponent` (`modules/components/weapon_component.gd`): `arc_center`/`arc_width` (derived from module orientation/flip — exterior-facing), `range`, `damage`, `fire_interval`, energy per shot drawn through `PowerConsumptionComponent`/battery (insufficient energy = holds fire; optional ammo resource via an input storage — exported, v1 lasers energy-only). Auto-fires at the nearest ship inside arc+range. Manned bonus (stretch, behind a flag): a WI-23 workspace assignment + gunner's Accuracy skill scales damage/interval — ship the flag off if time presses.
- **Armor plating.** `modules/defense/armor_plate.tscn`: structure-layer module, very high `max_hp`, no components, cheap-ish, exists to *be* the nearest exposed module. No special code — WI-24's targeting-the-nearest does the work.
- **Shields.** `modules/defense/shield_generator.tscn` + `ShieldComponent`: projects a circular zone (`radius`, exported per size variant/upgrades) centered on the module; a capacitor (`capacity`, `charge_rate` via power draw) absorbs any pirate hit whose *impact point* falls inside the radius — hit consumes charge equal to damage, laser VFX terminates on a shield-bubble flash instead of the module. Depleted → offline until recharged above a re-engage threshold (hysteresis). Overlapping shields: the one covering the impact with the most charge takes it (deterministic rule, documented). Bubble rendered faintly while charged, flash on absorb.
- **Hail / surrender.** A raid banner UI (top strip) with "Hail pirates": pay `payoff = f(strength, damage already dealt to them)` — decreases as you hurt them; paying ends the raid (ships leave). **Flee:** each ship retreats and despawns below `flee_hp_fraction`; raid ends when all ships gone (destroyed/fled/paid). Destroyed ships: small salvage drop (resource pile in space near the station — collectable by EVA, reuses `EffectSpawnSalvage` machinery).
- **Save:** raid state (active, ships' pos/hp/target, payoff state) in a `raid` section — a save mid-raid resumes the fight; simpler degradations rejected because save-scumming *out* of a raid would gut the threat.
- **Alerts/pacing:** raid warning alert a sim-hour before ships arrive (spawn far, fly in). Difficulty (WI-37) gates raids entirely on Peaceful.

## Files to touch
- **New:** `scripts/managers/raid_manager.gd` (+ Global slot + main.tscn), `objects/pirate_ship.gd/.tscn`, `modules/components/weapon_component.gd`, `shield_component.gd`, `modules/defense/laser_turret.tscn`, `armor_plate.tscn`, `shield_generator.tscn` (+ size variants/upgrades), mdata + unlock .tres (defense branch, tier-gated per WI-26), `data/events/pirate_raid.tres`
- `data/events/effects/effect_pirate_raid.gd` (WI-24) — route into RaidManager
- `ui/` — raid banner + hail dialog; `signal_bus.gd` — `raid_started/raid_ended`, `ship_destroyed`
- `scripts/managers/save_manager.gd` — raid section
- WI-19 followup: targeting-march and shield-selection unit tests
- Remember: `filesystem_manage(op="scan")` after new `class_name` files

## Implementation order
1. Pirate ship flight + targeting + laser VFX + damage against a defenseless station (raid start via cheat); hail/payoff; flee.
2. Weapon module: arc math, energy draw, auto-fire; ships die, salvage drops.
3. Armor plating (content only) + a balance pass on the exchange rate.
4. Shields: absorption, capacitor, hysteresis, overlap rule, VFX.
5. Raid event integration (extortion → raid), warning lead time, save section.

## Edge cases
- Module destroyed while a ship targets it: re-pick next nearest (truss replacement may now be the nearest — trusses are valid targets but low-value; pirates skip full-dead truss
- Pawn inside a module when a laser destroys it: WI-24's destruction-with-pawn path — this WI is why that test existed; EVA crew are never directly targeted v1 (no anti-personnel fire).
- All weapons unpowered mid-raid (power death spiral): holds fire — the brown-out is the player's emergency; verify batteries drain per shot correctly.
- Shield covering the shield generator itself: yes — the bubble protects its own emitter (else shields are useless).
- Payoff while ships mid-volley: raid ends, in-flight beam resolves, no further fire; ships leave via waypoints.
- Save/load mid-raid: ships restore positions/hp; in-progress repair jobs (WI-21/24) coexist with ongoing damage; verify no double raid from the event system on load.
- Raid vs ARC inspection (WI-26) simultaneously: inspector may be harmed → inspection fails — acceptable and darkly correct; verify no crash.
- Performance: ≤ ~6 ships, per-ship ray-march on retarget only — profile at 4× speed.

## Verification
1. Cheat-start a raid on an undefended station: ships orbit, lasers hit only hull-exposed modules (interior modules untouched — verify with a cross-section), damage/breach/destruction flow correct, payoff ends it, price drops after damaging a ship.
2. Two turrets with distinct arcs: only fire inside their arcs/range, drain energy per shot, kill a ship → salvage collectable.
3. Armor line on the raid-facing side: soaks the volley, production core untouched — the layout lesson lands.
4. Shield over the reactor: hits inside the bubble deplete charge with no module damage; deplete fully → damage leaks through until recharge re-engages at the hysteresis threshold.
5. Ships flee at low HP; wiping the wave ends the raid with a victory alert.
6. Save/load mid-raid at each phase resumes correctly; Peaceful difficulty (once WI-37 lands) never raids.
7. Regression: WI-24 repair loop cleans up after a raid end-to-end; traders/inspectors unaffected outside raids; `logs_read` clean at 4× through a full raid.
