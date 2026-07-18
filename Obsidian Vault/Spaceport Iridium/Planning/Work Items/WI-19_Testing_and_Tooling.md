# WI-19 — Testing & Tooling: GUT + Cheat Console

## Goal
Adopt GUT for unit tests over the pure-logic classes (`ModuleGraph`, `StorageData`, `StatModifiers`, `MarketManager` pricing, `LocalUpgradeData` cost scaling, contract/event resolution rules), and add a cheat console (spawn resource / spawn pawn / force unlock, plus the existing debug hooks) so every later Phase 3 WI can be exercised without playing twenty minutes first. This lands early in the phase deliberately: it is a force multiplier for the other nineteen items.

## Design
- **GUT** (addons/gut, Godot 4.x branch) with tests under `res://tests/unit/`. Headless run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` (also runnable via the godot-ai MCP for the Claude verify loop). Exclude `tests/` and `addons/gut/` from the export preset.
- **Test seams, not test heroics.** The listed classes are testable to different degrees:
  - `ModuleGraph`/`ModuleGraphVertex`, `StorageData`, `StatModifiers`, `LocalUpgradeData` cost scaling — pure logic, construct directly.
  - `MarketManager` pricing — `get_base_price`/`get_buy_price`/`get_sell_price` read only `market_data` + resource fields; instantiate the node without adding to tree (skip `_ready`, fill `market_data` by hand). Same trick for `ContractManager` resolution rules and `EventData.is_eligible`. Where a method reaches for `Global.*`, prefer extracting the calculation into a static/parameterized function over stubbing Global.
  - Typed-GDScript warnings: GUT's own addon code won't meet the project's warning bar — confirm warnings are path-scoped or set `exclude_addons` accordingly in project.godot; project test code itself stays fully typed.
- **Cheat console rides Panku** (already installed: `addons/panku_console`). No new UI: a `Cheats` helper class (`scripts/utility/cheats.gd`, `class_name Cheats`, registered as `Global.cheats` by Main) exposing typed methods, callable from Panku's REPL as `Global.cheats.<method>(...)`:
  - `spawn_resource(id: StringName, amount: int, cell: Vector2i)` — creates a `ResourcePile` at the cell (or deposits into the module's storage there if one accepts).
  - `spawn_pawn(cell: Vector2i)` — `CrewManager.spawn_crew` at the module on that cell (or nearest).
  - `force_unlock(id: StringName)` — `UnlockManager.force_unlock` by id; `unlock_all()` convenience.
  - `add_credits(amount: int)`, `set_time_speed(x)`, `advance_hours(n)` (drives TimeManager forward), `fire_event(id)`, `offer_contract()` — wrapping hooks that already exist (F-key debug bindings stay).
  - Each method returns a human-readable result string so the REPL echoes success/failure.
- **Guard rail:** cheats are compiled in but each call emits a `station_alert` "CHEAT: …" so a playtest save that used cheats is self-documenting. No cheat state needs saving.

## Files to touch
- **New:** `addons/gut/` (vendor), `tests/unit/test_module_graph.gd`, `test_storage_data.gd`, `test_stat_modifiers.gd`, `test_market_pricing.gd`, `test_local_upgrade_costs.gd`, `test_contract_resolution.gd`, `test_event_eligibility.gd`
- **New:** `scripts/utility/cheats.gd`
- `scripts/managers/main.gd` — instantiate/register `Global.cheats`
- `scripts/managers/global.gd` — `cheats` slot
- `project.godot` — warning path scoping if needed; export preset exclusion
- Possibly small seam extractions in `market_manager.gd` / `contract_manager.gd` (pure-function refactors only, no behavior change)
- Remember: `filesystem_manage(op="scan")` after the new `class_name` files

## Implementation order
1. Vendor GUT, get one trivial test green headless; wire the command line into the repo notes (CLAUDE.md "Running & verifying").
2. `ModuleGraph` tests first — groups, subgraph ids, `is_reachable`, group cost multipliers; this is the highest-risk logic in the game and WI-20/24/32 all lean on it.
3. `StorageData` (reserve/withdraw/deposit reconciliation — encode the "reservations reconcile to zero after cancel" invariant as a test), `StatModifiers`, upgrade cost scaling.
4. Market pricing + contract/event resolution, extracting seams as needed.
5. `Cheats` class + Panku exposure.

## Edge cases
- Tests must not touch autoload state: `Global`/`SignalBus` exist even headless (autoloads load in cmdln runs) — tests that mutate them must restore in `after_each` or avoid them.
- `StorageData.end_all_jobs` and friends emit through SignalBus — storage tests should run against components detached from the board (no JobManager present) and assert no crash.
- GUT + typed warnings: if the editor treats addon warnings as errors, the project won't run — resolve before committing the vendor drop.
- Panku input focus: the console grabs keyboard; verify game hotkeys (F5 quicksave etc.) don't fire while typing.

## Verification
1. `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` exits 0 with all suites green; a deliberately broken assertion exits non-zero.
2. In-game: open Panku, `Global.cheats.spawn_resource(&"iron_ore", 50, Vector2i(16,8))` → pile appears and crew haul it; `spawn_pawn`, `add_credits`, `force_unlock`, `fire_event` each observably work.
3. Editor still opens with zero new warnings from project code; export preset builds without tests/GUT.
4. Regression: normal play unaffected with the console closed.
