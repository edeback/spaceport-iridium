# WI-37 — Difficulty Levels

## Goal
Peaceful / Easy / Normal / Hard, chosen at New Game: Peaceful = no pirate raids, low upkeep, flat mood bonus; Easy = low upkeep, small mood bonus; Normal = no changes; Hard = higher upkeep, small mood penalty. Deliberately last in Phase 3 — it's a thin data layer over knobs the earlier WIs installed (WI-25 costs, WI-32 raids, WI-05 mood).

## Design
- **`DifficultyData`** .tres per level in `data/difficulty/` (ResourceScanner): id, name, description, `upkeep_multiplier` (applies to wages + module upkeep + levy fee — one knob v1), `raids_enabled: bool`, `mood_offset: float` (flat happiness modifier, ±), plus room to grow (future: breakdown-rate mult, market harshness). Balance strictly in the .tres.
- **Selection & storage.** WI-36's New Game path shows the four cards (description + effect summary); chosen id stored on a small `Global.difficulty: DifficultyData` set before the game scene loads (staged the same way SaveManager stages pending loads — a static, read by managers at ready) and saved in the envelope meta + a `difficulty` save field. Default Normal everywhere (including pre-WI-37 saves via migration default).
- **Consumption — three touch points, no scattering:**
  - `EconomyManager` (WI-25): multiplies each charge by `upkeep_multiplier` at charge time (ledger records the multiplied truth).
  - `RaidManager` (WI-32): `start_raid` no-ops on `raids_enabled == false`; the extortion/raid *events* also gate via an event condition (`ConditionDifficultyAllowsRaids` — new EventCondition, one-liner) so Peaceful never even draws the card.
  - Mood: a permanent station-wide happiness modifier id `&"difficulty"` applied through the same machinery EventManager uses for station-wide effects (re-applied to new hires, survives load by re-derivation from the difficulty, never saved as a modifier).
- **Not changeable mid-game** v1 (the honest version of difficulty); the settings screen shows the current difficulty read-only.

## Files to touch
- **New:** `data/difficulty/difficulty_data.gd` + `peaceful/easy/normal/hard.tres`, `data/events/conditions/condition_difficulty_allows_raids.gd`
- `scripts/managers/global.gd` — difficulty slot + staged-selection static
- `ui/menus/main_menu.gd` (WI-36) — selection cards in New Game
- `scripts/managers/economy_manager.gd` — multiplier application
- `scripts/managers/raid_manager.gd` — gate
- Mood application — wherever station-wide happiness effects live (`event_manager.gd`'s effect machinery or `pawn_needs_component` directly on spawn)
- `scripts/managers/save_manager.gd` — envelope meta + save/load + Normal migration
- WI-19 followup: multiplier/gate unit tests
- Remember: `filesystem_manage(op="scan")` after new `class_name` files

## Implementation order
1. DifficultyData + Global plumbing + save/migration (game runs on Normal implicitly).
2. New Game selection UI.
3. The three consumption points.
4. Tests + a balance sanity pass of the four .tres.

## Edge cases
- Peaceful + WI-24 breakdowns/extortion: breakdowns still occur (Peaceful removes *pirates*, not maintenance); the extortion event is a raid-family event → gated off. Document the family membership on each event .tres.
- Mood offset stacking with event happiness effects and traits: independent modifier ids — additive by existing modifier semantics; verify Hard's penalty doesn't push a fresh station below the resignation threshold on cycle 1 (balance floor).
- Loading a Hard save after playing a Peaceful run: staged difficulty must come from the save, not the menu leftover — clear the staged static on load path.
- Difficulty read before managers ready (EconomyManager _ready order): read lazily at charge time (`Global.difficulty` is set pre-scene either way).
- Envelope meta shows difficulty in the WI-36 slot list (nice, nearly free — add it).

## Verification
1. Start one game per difficulty: selection card reflected in-game (settings read-only display + slot metadata).
2. Hard vs Easy: identical station, cycle charges differ by exactly the multipliers (ledger check); Hard crew sit measurably lower on happiness, Peaceful/Easy higher.
3. Peaceful: force-roll raid/extortion events via debug → ineligible, never fire; `RaidManager.start_raid` cheat-call no-ops with a log line; Normal fires as before.
4. Save/load each difficulty: persists, mood modifier re-applies once (no stacking across loads), new hires on Peaceful get the bonus.
5. Pre-WI-37 save loads as Normal.
6. GUT: multiplier math, condition gate, modifier re-derivation green.
