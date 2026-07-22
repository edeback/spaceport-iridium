# WI-12 — Storage QoL: Venting, Configuration

STATUS: Done, 7/19. Most by hand, some tasks removed.
## Goal
Player control over storage: configure which resources a storeroom accepts (the `player_configurable` flag exists but the UI is minimal), remove a resource option without destroying stock (drain naturally), vent/dump unwanted stock (creating debris piles — mechanism exists), auto-dump toggle, per-storage priority editing.

## Design
- **Config UI:** storage tab gains an "Edit" mode for `player_configurable` storages: checklist of storable resources (from `ResourceManager.storable_resources`), desired-amount spinbox per resource, priority spinbox for the whole component. Non-configurable storages (processor input/output bays) unchanged.
- Unchecking a resource with stock → dump_all_to_pile that resource, automatic haul jobs will move it to where it needs to go
- **Vent to Space:** per-resource button → resources are destroyed. Requires confirmation.
- **Auto-dump toggle:** per-resource: when stored > desired for T hours and no export sink exists, dump the surplus. Off by default.

## Files to touch
- `modules/components/storage_component.gd` — draining flag handling in the posting scan; vent methods; auto-dump check on slow_tick
- `modules/components/storage_data.gd` — `draining: bool`; unreserved-amount accessor
- `ui/windows/ui_storage_component.gd` / `.tscn`, `ui/windows/storage_resource_line.gd` — edit mode, per-resource controls (desired, vent, auto-dump), priority control (calls existing `update_priority`)
- `modules/storage/*.tscn` — ensure `player_configurable = true` on the three storerooms and `allow_any_resource` interplay decided: config UI *replaces* allow-any for storerooms (explicit list beats wildcard for job-posting cost; keep allow_any for piles/special cases)
- `ui/windows/component_ui_panels/trade_component_ui.gd` — mass-sell button
- `scripts/managers/resource_manager.gd` — no change (source of the checklist)
- WI-03 followup: draining/auto-dump flags in storage save data

## Implementation order
1. Priority + desired-amount editing in the storage tab (pure UI over existing fields).
2. Add/remove resource options.
3. Vent (floor-dump + destroy variant).
4. Auto-dump.

## Edge cases
- Removing a resource that has an in-flight import job → cancel the import job (StorageData.end_all_jobs covers per-resource? it's all-jobs; add per-resource variant), let carried cargo divert via Job_StoreInventory.
- Vent while a withdraw job is reserved against the stock → vent only `stored − reserved_withdraw`.
- Vent into a module whose overflow pile already exists → tops up (exists); pile in an unreachable module → collection job simply unclaimable (existing behavior) — fine.
- Desired raised above max_stored → clamp to capacity.
- Draining slot receiving a deposit from an in-flight job accepted before the flag → allow it (reserved deposits complete), then continue draining.
- Auto-dump of the ONLY food/fuel stock — it only fires when stored > desired; desired 0 + auto-dump on is player error, but confirm dialog on enabling auto-dump for a resource a Sustenance/Power component consumes would be kind. (Skip if scope-tight.)
- allow_any storages (mining bay output?) in the config UI — read-only list display.

## Verification
1. Storeroom: change accepted resources and desired amounts → haulers rebalance the station accordingly (watch import/export jobs).
2. Uncheck iron with 30 stored → no new iron arrives; existing iron hauls away to other storage/export; slot vanishes at 0.
3. Vent 20 carbon → pile appears in the module, crew collect it back to *other* storage (or it sits if nowhere accepts). Destroy-vent actually deletes (resource totals drop).
4. Priority: set a reactor's fuel bay priority above general storage → hydrogen preferentially flows there when scarce (the "prioritize hydrogen to the reactor" scenario from the design notes).
5. Mass-sell empties the export bin into credits (or flags for trader, post-WI-08).
6. Save/load mid-drain and with auto-dump enabled → flags persist, drain completes.
7. Regression: construction material delivery (priority 99 flow) untouched.
