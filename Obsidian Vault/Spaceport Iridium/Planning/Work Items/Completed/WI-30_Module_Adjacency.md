# WI-30 — Module Adjacency Effects

## Goal
Layout matters: industrial modules radiate vibration that penalizes nearby rest/recreation facilities; beneficial modules enhance their neighbors (garden → sleeping desirability, Maintenance Facility → lower breakdown chance nearby, air purifiers → lower disease spread for WI-31). Effects propagate through *physical connections* (vibration doesn't cross vacuum), not straight-line distance.

## Design
- **Propagation model.** Effects travel over the **StructureManager** graph (physical attachment — the design's "connection-based" requirement) with hop-count falloff. Each source defines `{effect_id: StringName, intensity: float, range_hops: int, falloff: per-hop multiplier}`; a receiving module's *field level* for an effect = sum over sources of `intensity × falloff^hops` (BFS within range). Truss conducts (it's structure) — exported per-effect flag if some effect shouldn't cross truss later.
- **Recompute on topology change only.** New `AdjacencyManager` (manager node, `Global.adjacency_manager`, after StructureManager): maintains `field: Dictionary[effect_id, Dictionary[ModuleBase, float]]`. Rebuilds affected neighborhoods on `module_added` / `module_removed` / build-state change (sources only radiate when Built) — never per-frame, never slow_tick scans. Query API: `get_field(module, effect_id) -> float`. Stations are hundreds of modules at most; a scoped BFS per change is cheap.
- **Sources.** `AdjacencyEmitterComponent` (`modules/components/adjacency_emitter_component.gd`): exported list of effect specs, registers with the manager on `ready_constructed`. Authored into scenes: refinery/forge/reactor emit `&"vibration"`; garden (new module, this WI) emits `&"greenery"`; Maintenance Facility (new module, this WI) emits `&"maintenance"`; air purifier (built in WI-31) emits `&"purified_air"`. Intensity/range in the scene exports or mdata (balance in data).
- **Receivers decide meaning.** Consumers read the field and translate locally — the manager never pushes modifiers:
  - `SleepComponent`: rest effectiveness × `1/(1 + vibration × k)`; + desirability bonus from `greenery` (desirability = tie-break when choosing among free bunks; rest bonus small).
  - Recreation/entertainment components: same vibration penalty shape on recreation gain.
  - WI-24 breakdown roll: chance × `1/(1 + maintenance × k)` — routed through the `&"breakdown_chance"` effective-stat hook WI-24 left, via a stat modifier the receiver refreshes when its field changes (source `&"adjacency"`).
  - WI-31 will read `purified_air` in its transmission roll.
  - Receivers refresh on a manager `fields_changed(module)` signal, not by polling.
- **Maintenance Facility.** New module (industrial tree, mid-tier): no jobs v1, pure emitter + upkeep cost — its value is the aura. (A future version could require a stocked parts storage; note only.)
- **Garden.** New module (crew tree, mid-tier): no jobs v1, pure emitter + upkeep cost — its value is the aura. (A future version could require a water input storage; note only.)
- **UI.** Module panel gains an "Environment" section listing nonzero fields with friendly wording ("Vibration: high — rest quality −30%"). The vibration overlay ships in WI-35; this WI exposes `get_field` for it.
- **Save:** nothing — fields are pure derived state, rebuilt on load after world placement.

## Files to touch
- **New:** `scripts/managers/adjacency_manager.gd` (+ `Global` slot + `main.tscn` node after StructureManager), `modules/components/adjacency_emitter_component.gd`, `modules/maintenance/maintenance_facility.tscn` + mdata + unlock entry, `modules/crew/garden.tscn` + mdata + unlock entry
- `modules/components/sleep_component.gd`, `recreation_provider_component.gd`, `entertainment_component.gd`, `social_component.gd` (whichever grant recreation) — vibration/greenery consumption
- Industrial + garden module scenes — emitter components
- `modules/templates/module_base.gd` — breakdown-chance adjacency modifier refresh (or wherever WI-24 put the roll)
- `ui/windows/module_info_ingame_panel.gd` — Environment section
- WI-19 followup: BFS/falloff unit tests over a hand-built ModuleGraph
- Remember: `filesystem_manage(op="scan")` after new `class_name` files

## Implementation order
1. AdjacencyManager + emitter component + `get_field` + debug dump (cheat: print fields for the selected module).
2. Vibration → sleep/recreation penalties + Environment UI.
3. Greenery + garden module + garden emitter; maintenance + the new facility + breakdown hook.
4. Overlay data hook for WI-35; tests.

## Edge cases
- Module that is both source and receiver (a forge next to a forge): sources don't affect themselves; hops ≥ 1 only.
- Emitter module damaged (WI-24): intensity scales with the damage efficiency multiplier? v1: no — binary Built/not (keep the field model simple); note for balance.
- Deconstruct→truss on a path between source and receiver: truss conducts, so the field *persists* across the gap — this is correct (they're still physically attached); vacuum separation requires actual disconnection.
- Two stations sections connected only by turbolift shaft: shaft modules are structure — conducts; acceptable.
- Rapid build/demolish churn (blueprint spam): only Built modules radiate, and blueprint placement still triggers neighborhood rebuilds — coalesce rebuilds within a frame (dirty-set + deferred flush).
- Receiver rechecks on its own build completion (a pod built inside an existing vibration field must start penalized).
- Fields after load: rebuild once after the world section places all modules (subscribe to a post-load signal or WI-18's `game_bootstrapped`), not per module during load.

## Verification
1. Sleeping pod adjacent to a refinery: rest effectiveness visibly reduced (pawn sleeps longer for the same recovery), Environment section explains it; move the pod three hops away → penalty shrinks per falloff; disconnect entirely → zero.
2. Garden next to pods: desirability/rest bonus appears; pawns prefer the garden-side pod when both free.
3. Maintenance Facility near a forge: breakdown chance drops (verify via the effective stat readout / forced high base chance).
4. Build/demolish a corridor bridging a forge to a distant pod: field appears/disappears with the topology change only (no per-frame cost — check the profiler/monitors).
5. Save/load: fields identical after rebuild (dump before/after).
6. GUT: falloff sums on a synthetic graph, including the truss-conduction case.
