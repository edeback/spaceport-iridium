# WI-39 — Power Registry

## Goal
Two things, both in the power system:

1. Replace `PowerManager`'s three per-tick `get_nodes_in_group` scans with explicit registration arrays, and delete the dead scaffolding around them. Closes **C4** and the remainder of design-debt **B2**. Behavior-preserving: the power balance produces the same numbers, it just stops rebuilding its participant lists four times a sim-second.
2. **Persist `BatteryComponent.total_power_stored`** — found while scoping the refactor. It's the same unsaved-stateful-field bug as WI-38's A2 (shield capacitor), missed because that pass audited combat components. See below.

The refactor's real payoff isn't the scan cost (small at current station sizes) — it's that a registry is the natural home for per-module power priority, so life support can brown out last instead of whichever node the scene tree happened to list first. **That feature is not in this WI**; this is the plumbing it needs.

## Design

`PowerManager` already declares `power_generators` and `power_consumers` as typed arrays (`power_manager.gd:4-5`) — they were never populated and nothing reads them. There's also a commented-out `node_grouped`/`node_ungrouped` pair (`power_manager.gd:18-32`) sketching a signal-driven version of exactly this. Finish the intent and delete the sketch.

- **Three arrays on the manager**: `power_generators: Array[PowerGenerationComponent]`, `power_consumers: Array[PowerConsumptionComponent]`, `batteries: Array[BatteryComponent]`.
- **Explicit register/unregister** replacing the group joins:
  - `PowerGenerationComponent.ready_constructed` → `register_generator(self)` (currently `add_to_group("power_generator")`, `power_generation_component.gd:33`)
  - `PowerConsumptionComponent.ready_constructed` → `register_consumer(self)` (`power_consumption_component.gd:41`)
  - `BatteryComponent._on_enabled`/`_on_disabled` → `register_battery`/`unregister_battery` (`battery_component.gd:24-28`). The battery is the only one of the three that already handles *leaving* its group; the other two rely on node-free to drop them out, which a plain array won't do for free — see edge cases.
- **Delete the three groups entirely.** `power_generator`, `power_consumer` and `battery` are each referenced exactly twice or three times: the join, the (battery) leave, and the `PowerManager` scan. Nothing else in the codebase uses them, so they don't need converting — they need removing. This also drops three strings off [[WI-41_Group_Constants]]'s workload.
- **Register/unregister go through `PowerManager` methods, not raw array access**, so priority insertion has one place to land later.

### Battery charge persistence

`BatteryComponent.total_power_stored` (`battery_component.gd:10`) is mutable runtime state with no save key — `ModuleBase.get_save_data()` has no `battery` block. Every battery therefore reloads at 0 regardless of how charged it was, which on a station running a night-cycle off battery reserve is a silent, load-bearing swing.

Follow the shape WI-38 already established for the shield capacitor (A2), so the two read identically:

- `BatteryComponent.get_save_data()` → `{"stored": total_power_stored}`; `load_save_data()` clamps to `max_power_stored` and defaults to the current value on a missing key (absent key = pristine, the `sustenance`/`shop`/`shield` convention).
- A `"battery"` block in `ModuleBase.get_save_data()` / `load_save_data()`, alongside the shield block (`module_base.gd:466`, `:533`).

One difference from the shield worth noting in the code: `max_power_stored` is a plain `@export` and is **not** routed through `get_effective_stat`, so unlike `ShieldComponent.effective_capacity()` there's no upgrade-ordering subtlety — the clamp is against a constant. If battery capacity ever becomes upgradeable, it needs to move behind `get_effective_stat` and the restore needs to happen after the upgrades block, exactly as the shield's does.

Additive save key, so pre-WI-39 saves load unchanged (batteries come back empty, as they do today).

## Files to touch
- `scripts/managers/power_manager.gd` — arrays, register/unregister API, `power_modules` rewrite, delete dead fields + commented hooks
- `modules/components/power_generation_component.gd` — register/unregister
- `modules/components/power_consumption_component.gd` — register/unregister
- `modules/components/battery_component.gd` — register/unregister, save/load
- `modules/templates/module_base.gd` — `battery` save block
- `tests/unit/` — see verification

## Implementation order
1. **Battery persistence first** — it's independent of the refactor and small, so it lands and gets verified without the registry churn in the diff.
2. Add the three arrays + `register_*`/`unregister_*` methods to `PowerManager`, populated alongside the existing group joins (both live at once).
3. Switch `power_modules` to read the arrays. Verify identical behavior with both mechanisms running.
4. Remove the group joins/leaves and the three group strings.
5. Delete the dead `node_grouped`/`node_ungrouped` comment block and any now-unused fields.

## Edge cases
- **Unregistration is the whole risk.** Groups auto-drop freed nodes; arrays don't. Generators and consumers currently never leave their group — they rely on being freed. Add `_exit_tree()` unregistration to all three components. `WorldManager.remove_module` calls `canvas.remove_child(module)` before `queue_free()` (`world_manager.gd:166-170`), so `_exit_tree` fires on descendants either way, but belt-and-braces: filter `is_instance_valid` in `power_modules` as well, since a stale entry there is a hard crash rather than a wrong number.
- **Blueprint → built transition**: generators/consumers register in `ready_constructed`, which for a non-instant module runs once, after construction. Confirm a module that goes preview → blueprint → built registers exactly once, and that `ready_constructed` isn't re-entered on load (`ModuleBase` already guards its own durability connections against a double ready pass — mirror that idiom).
- **Load path**: `WorldManager.load_save_data` places every module with ready deferred, then runs the ready pass in placement order. Registration therefore happens during the world section; confirm the first `slow_tick` after load sees a complete registry, not a partial one.
- **Brownout victim order is arbitrary today and stays arbitrary.** `power_modules` distributes to consumers in iteration order, so whoever is first gets power when supply is short. Group order is tree order; array order is registration order. Both are incidental. This WI must not silently change which modules brown out *first* in a way that reads as a balance change — note in the code that ordering is not yet meaningful, and leave the fix to the priority feature.
- **Battery `component_enabled`** can toggle at runtime (preview/blueprint/built transitions drive it). Double-register and double-unregister must both be no-ops.
- **Battery restore vs. `ready_constructed`**: `ModuleBase.load_save_data` runs after the ready pass, so the restored charge must not be clobbered by anything `ready_constructed`/`_on_enabled` sets. Batteries currently initialize `total_power_stored` at its declared default and never re-seed it (unlike the shield, which re-seeds from `initial_charge_fraction`), so this should be free — confirm rather than assume.
- **A battery saved above `max_power_stored`** (from a hand-edited save, or a `.tres` whose capacity was reduced after the save was written) clamps down on load rather than restoring an over-full bank.

## Verification
1. Station with mixed generators, consumers and batteries: record `power_updated(desired, generated)` over a few minutes before the change, repeat after → same numbers.
2. Build a generator mid-run → it contributes on the next tick. Destroy it (raid or manual delete) → it stops contributing, no error, no stale entry.
3. Deconstruct a *battery* specifically (the `component_enabled` path) → drops out cleanly; rebuild → rejoins.
4. Underpower the station deliberately → brownouts still occur and still resolve when generation returns.
5. Save/load a station with charged batteries and running generators → registry rebuilds, power balance resumes identically.
6. **Battery persistence**: charge a bank to a distinctive partial level (say 40%), save, load → it comes back at 40%, not empty and not full. Then run the station into a generation deficit overnight → it discharges from the restored level, not from a reset one. Finally, load a pre-WI-39 save → batteries come back empty with no warnings, exactly as today.
7. **GUT**: the pure part of the balance (desired vs generated vs battery draw/store arithmetic) is worth extracting and testing if it comes out cheaply — construct the components directly, no `Global`. If extraction isn't clean, skip it rather than contorting the manager; this WI is mostly plumbing and the existing suite passing is the real gate. The battery save/load round-trip *is* cheaply testable (construct a `BatteryComponent`, set a charge, round-trip the dict, assert including the over-capacity clamp) — add that one.
