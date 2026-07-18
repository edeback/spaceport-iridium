# WI-28 — Robotic Needs: Energy & Integrity

## Goal
Robots (mining drones, WI-27 hauler robots, future combat bots) stop being free labor: they consume energy while moving/working and must recharge; they have an integrity (health) stat that only a Repair Bay restores — at zero the robot is destroyed.

## Design
- **Who is a robot:** introduce `RobotPawnBase` (`pawns/robot_pawn_base.gd`) extending PawnBase, and rebase `MiningDronePawn` + `HaulerRobotPawn` onto it. It carries the two new components and the shared "no needs/schedule/skills" nature. (CrewManager's drone exclusion check should switch from `is MiningDronePawn` to `is RobotPawnBase`.)
- **Energy.** `RobotPowerComponent` (`pawns/robot_power_component.gd`): `energy_max`, drain rates per sim-hour split `drain_moving` / `drain_working` (working = has a current job that isn't idle; moving = `movement_component.is_traveling()`), idle drain ~0.
  - **Recharge:** at `seek_threshold` %, queue `Job_Recharge` (Category NEEDS — reuses the personal-queue pattern from PawnNeedsComponent: queue once, promote at critical, never board): path to the nearest recharger — the robot's home module (bay gains an implicit charger) or a standalone `recharge_station` module (`RechargeComponent`, powered, `charge_rate_per_hour`, limited slots via anchor claims). Charging draws station power through the host's PowerConsumptionComponent (or a per-charge draw registered with PowerManager — match how sustenance-style consumption is modeled; keep it simple: charger has a fixed draw while occupied).
  - **Zero energy:** "emergency backup power" — speed multiplier (e.g. 0.25×) and the robot may *only* take/continue `Job_Recharge`; any other current job cancels gracefully (cargo kept, swept later). Never fully bricks: it can always crawl to a charger; if no charger is reachable, it parks and retries on cooldown (alert once).
- **Integrity.** `RobotIntegrityComponent`: `integrity_max`, no regen. Damage sources: combat (WI-32), and "accidents" — a small malfunction roll alongside WI-24's breakdown machinery (robots roll on hour_changed with a tiny chance; a malfunction deals minor integrity damage). At `repair_threshold`, queue `Job_GetRepaired` (NEEDS): path to a **Repair Bay** module (`RobotRepairComponent`, powered, repairs integrity/hour, maybe consumes a small resource — exported, default none for v1 consistency with WI-24 repairs). At 0 → destroyed: cargo drops as a pile (invariant), owning bay notified (frees a robot slot), alert.
  - The Logistics Bay is *not* automatically a repair bay (recharge yes, repair no) — repair is a dedicated module so losing it matters. The Repair Bay repairs any robot type.
- **UI:** robot click panel shows energy + integrity bars and current state; bay UI lists owned robots with both stats.
- **Save:** energy/integrity per robot in the pawn section; charger occupancy re-derives.

## Files to touch
- **New:** `pawns/robot_pawn_base.gd`, `robot_power_component.gd`, `robot_integrity_component.gd`, `scripts/jobs/job_recharge.gd`, `job_get_repaired.gd`, `modules/logistics/recharge_station.tscn`, `repair_bay.tscn`, `modules/components/recharge_component.gd`, `robot_repair_component.gd`, mdata + unlock .tres for both modules
- `pawns/mining_drone_pawn.gd`, `hauler_robot.gd` — rebase; drone `powered` flag reconciles with energy (the bay-power gate becomes "bay unpowered = can't recharge", not "drone freezes" — drones now run on their own battery)
- `scripts/managers/crew_manager.gd` — exclusion check
- `modules/components/logistics_bay_component.gd`, `mining_component.gd` — home-charger, destroyed-robot slot handling
- `ui/pawns/pawn_info_panel.gd` — robot variant panel
- `scripts/managers/save_manager.gd` — pawn-section fields
- WI-21 followup: recharge/repair job save entries. WI-19: drain/charge math tests.
- Remember: `filesystem_manage(op="scan")` after new `class_name` files

## Implementation order
1. `RobotPawnBase` rebase (pure refactor, verify drones unchanged).
2. Energy component + drain + home recharge on the mining bay; then the standalone recharge station.
3. Zero-energy crawl state.
4. Integrity + malfunction roll + Repair Bay + destruction path.
5. UI + save.

## Edge cases
- Drone mid-EVA at zero energy: crawls home through space at 0.25× — acceptable drama; verify the mining trip job cancels gracefully and ore isn't lost.
- Recharge job posted while the only charger is unpowered: `can_do_job` fails → cooldown retry (no pathfinding spam — mirror the WI-17 flee throttle).
- All chargers occupied: anchor claims gate slots; queued robots wait nearby (QUEUE anchors if authored, else stand).
- Robot destroyed mid-haul with a storage reservation: standard cancel path releases reservations; cargo pile per invariant. Assert reconciliation.
- Energy drain during CONVEYED (turbolift ride): counts as moving — fine, but rides must not strand a zero-energy robot in a cab (it can still complete the ride; crawl starts after).
- Malfunction roll vs WI-24 module breakdowns: independent systems, both alert — rate-limit combined alert spam.
- Pre-WI-28 saves: robots load at full energy/integrity (migration default).
- Repair Bay deconstructed with robots en route: jobs invalidate cleanly; alert if a damaged robot has no reachable repair bay.

## Verification
1. Watch a hauler through a full duty cycle: drain while hauling, seek charger at threshold, charge, resume — no board jobs taken below threshold until charged.
2. Cut power to all chargers: robots drain to zero, crawl, park with one alert; restore power → recovery.
3. Cheat-damage a robot to the repair threshold: it books into the Repair Bay, integrity restores; damage to 0 → destroyed, cargo pile, bay slot freed, buy replacement works.
4. Mining drone regression: mining loop unchanged in the happy path (rates aside); bay unpowered no longer freezes a mid-flight drone (new semantics verified deliberately).
5. Save/load mid-charge and mid-crawl: stats and behavior resume.
6. GUT: drain/charge/threshold math; crawl-speed gate only allows recharge jobs.
