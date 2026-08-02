# WI-46 — Structure Connectivity

> **STATUS: COMPLETE (2026-08-02).** Closes the section-B / D9 design debt: `StructureManager.can_remove_module`, disabled since Phase 0, is enabled again and now works. Three changes: blueprints form their structural edges when placed (not when finished), the split test became a local cut-vertex check instead of a fragile whole-graph one, and the delete guard in `WorldManager.remove_module` is re-enabled with player feedback. Five code files, one test suite. **505 GUT green** (39 suites), including **7 new cut-vertex tests** in `test_module_graph.gd`. Integration verified by a temporary autoload probe: 16 checks over a line of real 1×1 blueprints — they form the expected chain, leaf removals read safe, bridge removals read unsafe, and it stays correct even though the pod chain is a *separate* component from the starting station (the case the old check couldn't handle). Combat destruction and finished deconstruction are unaffected — both pass `structure_check = false`.

## Goal

Never allow the station to split into two disconnected pieces. Every module must stay connected to the rest by *something* — a corridor, a truss segment, an adjacent module. Distant clusters are fine as long as a structural chain joins them.

The mechanism for this already existed and was switched off. `WorldManager.remove_module` had a `StructureManager.can_remove_module` guard, gated per-module by `ModuleBase.structure_check_before_delete`, but it was commented out because it produced false positives on any station with construction in progress and would "easily get into the state of disallowing any module destruction." So this WI is the D9 decision made in the "fix it" direction rather than the "delete the flag" one.

## The bug

`StructureComponent` connections — the physical-attachment edges in the `StructureManager` graph — were only formed in `ModuleBase.ready_constructed()`. `ready_blueprint()` never formed them. A construction site was therefore an **isolated vertex**: present in the graph (added on `module_added` at `_ready`), but with no edges.

Two consequences compounded:

1. Adjacency (WI-30) and connectivity accounting both read a graph that didn't match the physical structure while anything was under construction.
2. The old `can_remove_module` asked *"is the entire graph exactly one connected component after I block this vertex?"* (`graph.last_subgraph == 1`). A single blueprint anywhere is an extra component, so the answer was "no" for **every** deletion the instant construction started. That is why it had to be disabled — not because the guard was wrong in spirit, but because the graph it consulted was lying and the question it asked was too global to tolerate the lie.

Removing the middle of a line of construction sites was the concrete failure: the sites weren't graph-connected, so nothing modelled them as a chain that shouldn't be cut.

## Design

Three independent pieces; each is a net improvement on its own.

### 1 — Blueprints connect from placement

Structural attachment is physical: it exists the moment a construction site is placed, not when the module finishes. `ready_blueprint()` now forms the structural connections; pawn-traversal (`PathComponent`) connections still wait for `ready_constructed()`, because a blueprint is not yet walkable.

- Split `ModuleBase.make_connections()` into itself (path + structure, unchanged callers) and a new `make_structure_connections()` (structure only). `ready_blueprint()` calls the latter.
- `ready_constructed()` still calls the full `make_connections()`. To keep the blueprint→built transition from re-forming the same edges, `StructureComponent.make_connections()` gained a `_connections_made` idempotency guard (early-return if already connected; cleared in `remove_connections()`). Instant/force-built modules that skip the blueprint phase still form their edges on the single `ready_constructed()` pass. `try_connect()` is deliberately **not** guarded — a later neighbour must always be able to attach to an existing module.

This alone makes the graph honest during construction, which is the load-bearing part; the adjacency layer (which conducts over the same graph, and where truss already conducts) benefits for free.

### 2 — A local cut-vertex test

`graph.last_subgraph == 1` is replaced by `ModuleGraph.would_removal_split(node)` — a proper articulation-point test. It blocks the vertex, re-floods subgraphs, and checks whether the vertex's **own neighbours** landed in the same component; it restores the graph afterward. A leaf (or isolated) vertex returns "won't split" immediately.

The reason this matters beyond tidiness: the local comparison is **immune to unrelated islands**. The global count vetoed every deletion the instant one disconnected fixture existed anywhere on the map — the exact failure mode that forced the disable, and one that a blueprint fix alone would not have fully cured (any future module type that doesn't structurally connect would resurrect it). `StructureManager.can_remove_module` is now a one-line delegate.

### 3 — The guard, re-enabled with feedback

`WorldManager.remove_module` runs the check again, still gated by `structure_check_before_delete`. That flag is the correct scoping and was left as-is:

- It defaults **false** (`module_base.tscn`) and is **true** only on `hallway`, `truss`, and `starting_module`. MODULE-layer deletes auto-place a truss replacement at the vacated cells, so they can't split the station and don't need the check. Corridors, truss, and the starting module leave no backfill, so they do.
- A refused delete now emits a `station_alert` ("Can't remove X: it would split the station into disconnected pieces") instead of failing silently — a silent no-op on the demolish button was worse than no guard.

Untouched by design: `ModuleBase._on_hp_zero` (combat) and `ConstructionComponent`'s deconstruction-complete removal both call `remove_module(module, false)` and bypass the check, exactly as before.

## Files touched

- `scripts/utility/module_graph.gd` — new `would_removal_split(node)`.
- `scripts/managers/structure_manager.gd` — `can_remove_module` delegates to it (old block-and-count logic deleted).
- `modules/components/structure_component.gd` — `_connections_made` idempotency guard in `make_connections()` / reset in `remove_connections()`.
- `modules/templates/module_base.gd` — `ready_blueprint()` calls new `make_structure_connections()`; `make_connections()` split.
- `scripts/managers/world_manager.gd` — re-enabled the `structure_check_before_delete` guard + `station_alert` on refusal.
- `tests/unit/test_module_graph.gd` — 7 cut-vertex tests.

## Edge cases

- **Instant / force-built modules** (starting station, `instant_build` data) skip `ready_blueprint` and form edges on the one `ready_constructed` pass — the guard makes the double-call path safe without penalising the single-call path.
- **Two blueprints placed the same frame** both scan for neighbours on their deferred ready, so an edge can be emitted from both ends. `StructureManager.add_edge` is idempotent and `AdjacencyManager` coalesces the resulting topology signals — redundant, not incorrect.
- **Deleting the last module** returns 0 components after blocking; the local test reads that as "no neighbours to split," i.e. removable. Fine — the starting module is `can_delete = false` anyway.
- **Truss backfill vs. the check**: MODULE-layer modules that *would* be bridges are exempt (flag false) precisely because truss reconnects them; the check only ever runs where no backfill happens.
- **Graph left intact**: `would_removal_split` restores the blocked/unblocked and subgraph state before returning; a test asserts reachability and the blocked flag are unchanged afterward.

## Verification

1. **GUT:** full suite green — 505 tests across 39 suites — with 7 new cut-vertex tests (`test_module_graph.gd`, now 25): isolated/leaf never split, bridge splits, cycle-redundant doesn't, unrelated-island robustness, graph-left-intact, missing-vertex.
2. **Integration probe** (temporary autoload, `main.tscn` headless — the standard fallback since MCP is unreliable): placed four real 1×1 blueprints in a line and confirmed 16 checks — all four genuinely `Blueprint` state, structural degrees 1‑2‑2‑1, leaf `can_remove` true / bridge false on both middles, and correctness preserved with the chain as a *separate* component from the station (`last_subgraph >= 2`, which the old test could not survive). Probe removed after.

## Related

- [[03_Bugs_and_Improvements]] — resolves **B1** (`can_remove_module` disabled) and the **D9** decision.
- [[WI-30_Module_Adjacency]] — the other consumer of the `StructureManager` graph; blueprints conducting adjacency is the same "truss conducts" rule, now applied a phase earlier.
- [[WI-47_Modding_Support]] — M2's component save-hook refactor touches the same `ModuleBase` ready chain this WI added a connection call to; keep `ready_blueprint`'s `make_structure_connections()` when collapsing it.
- [[01_Technical_Specification]] — §2.4 cleanup entry and §1.3 manager note updated to reflect the check is live.
