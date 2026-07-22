# WI-40 — Storage Query Helper

## Goal
Collapse the four near-identical "find the best storage" loops into one parameterized helper, so storage routing is one decision in one place instead of four that drift apart. Closes **C5**.

**Depends on [[WI-38_Bug_Fix_Pass_2]]** (A5 + A7), which is what makes this cheap: A5 fixes `Job_StoreInventory`'s scoring in place, after which two of the four functions are byte-identical and the third differs by a single filter. Doing this WI first would mean shipping the bug fix and the refactor in one diff, which is exactly what WI-38 was scoped to avoid.

Behavior-preserving by design. This is not the place to change routing rules.

## Design

The four sites and what they actually want, post-WI-38:

| Site | Kind | Priority filter | Scoring |
|---|---|---|---|
| `Job_GetResource._find_export_storage` (`job_get_resource.gd:118`) | source | `< deposit.priority` | prefer a source that fills the whole trip (nearest of those); else most stock, tie → nearest |
| `Job_GetResource._find_deposit_storage` (`job_get_resource.gd:148`) | sink | `> export.priority` | highest priority, tie → nearest |
| `Job_CollectPile._find_deposit_storage` (`job_collect_pile.gd:120`) | sink | none (a pile has no priority to compare against) | highest priority, tie → nearest |
| `Job_StoreInventory._find_closest_import_storage` (`job_store_inventory.gd:129`) | sink | none | highest priority, tie → nearest *(after WI-38; nearest-only before)* |

So it's **two queries, not four**: one source query, one sink query, with the priority filter as an optional knob.

```gdscript
class_name StorageQuery

## Sentinel meaning "no priority floor/ceiling" - a pile or a carried-cargo
## sweep has no priority of its own to compare against.
const ANY_PRIORITY: int = -0x7FFFFFFF

static func find_source(pawn: PawnBase, resource: ResourceData, trip_cap: int,
		below_priority: int = ANY_PRIORITY) -> StorageComponent
static func find_sink(pawn: PawnBase, resource: ResourceData,
		above_priority: int = ANY_PRIORITY) -> StorageComponent
```

Two things to preserve carefully, both currently expressed only as behavior:

- **The priority filters are strict and directional** (`>=` / `<=` reject in the current code, i.e. a source must be strictly *below* the sink). This is what stops a haul flip-flopping between two equal-priority bins forever. Comment it at the helper, not at the call sites.
- **The sweep and the pile deliberately have no filter.** A pawn holding cargo must accept *any* bin that will take it rather than stranding itself; `pawn_base.gd:211-217` depends on `Job_StoreInventory` falling through cleanly when nothing accepts. WI-38 already notes this as a comment-worthy asymmetry — this WI is where the comment finally has one home.

**Keep it a filter+score walk, not a rewrite.** Both queries stay `get_nodes_in_group("resource_storage")` → filter → score. The win is deduplication and one place for the rules, not a new data structure.

**The indexing payoff is deliberately deferred.** `ResourceData.registered_storage` already exists (`resource_data.gd:37`), is maintained symmetrically by `StorageComponent` register/unregister, and is used only by `_recalc_resource`. Once these queries live in one function, swapping the group scan for a per-resource index is a one-function change. Do **not** do it here — that's a behavior-risk change (registration timing vs. group membership timing differ) and it wants its own verification. Note it in the helper's docstring as the intended next step.

## Files to touch
- **New:** `scripts/utility/storage_query.gd`
- `scripts/jobs/job_get_resource.gd` — delete two finders, call the helper
- `scripts/jobs/job_collect_pile.gd` — delete finder, call the helper
- `scripts/jobs/job_store_inventory.gd` — delete finder, call the helper
- `tests/unit/test_storage_query.gd` — new suite (see below)
- Remember: `filesystem_manage(op="scan")` after the new `class_name`

## Implementation order
1. Write `StorageQuery` with both functions, ported from `Job_GetResource`'s two (they're the most complete — they have the priority filters and the fill-the-trip preference).
2. Extract the scoring comparisons as pure static predicates first (see testing note), then build the walks on top of them.
3. Convert the call sites one at a time, running the game between each. `Job_GetResource` last — it's the one whose behavior is being copied *from*, so converting it last means any behavior drift shows up on the simpler sites first.
4. Delete the four old finders.

## Testing note — what's actually unit-testable
The walks read `Global.path_manager.is_reachable` and `Global.world_to_cell`, so they can't be constructed in a GUT test under the project's pure-classes-only rule. Don't contort the API to fix that (no injecting a reachability callable).

Instead **extract the comparisons**, which are pure and are where the drift actually happened:

```gdscript
static func sink_beats(cand_priority: int, cand_dist: int, best_priority: int, best_dist: int) -> bool
static func source_beats_partial(cand_amount: int, cand_dist: int, best_amount: int, best_dist: int) -> bool
```

Those get the suite: priority dominates distance, distance breaks ties, the fill-the-trip branch outranks any partial, and an empty candidate set returns null. That's the rule set that silently diverged between two files — pinning it in tests is most of this WI's long-term value.

## Edge cases
- **Equal-priority sink vs. current behavior**: `Job_GetResource._find_deposit_storage` uses `storage.priority > best_priority` (strict), so among equals the *first* one scanned wins unless distance breaks it — confirm the extracted predicate reproduces that exactly, including which side of the tie wins.
- **`trip_cap`**: only `_find_export_storage` clamps by `pawn.inventory_component.space_available()` (`job_get_resource.gd:119-121`), and the pawn may have no inventory component. Preserve the null guard.
- **Null storage in the group**: WI-38's A7 adds the missing guard to `Job_StoreInventory`; the helper must carry it for all callers (one guard, one place — that's the point).
- **`can_deposit(resource, 1)`**: the sink query probes with 1 unit, not the full amount. That's intentional (a partially-full bin is still a valid target) and must not silently become a full-amount check.
- **Reachability cost**: `is_reachable` is O(1) via subgraph ids and jobs rely on that. Keep it as the *last* filter in the walk, after the cheap rejects, exactly as the current code does.
- Callers pass `requester.get_tree()` vs `_pawn.get_tree()` today. Both reach the same tree; standardize on the pawn and confirm no call site relies on a requester that outlives its pawn.

## Verification
1. Regression sweep of every routing path the helper now serves: construct a module end-to-end (import at +99), deconstruct one (export at −99), collect a debris pile, and cancel a haul mid-carry so the pawn sweeps its cargo. All four must behave exactly as before.
2. Two storage bins at different priorities with the same resource → a push job still routes uphill to the higher-priority bin; a pull job still sources from the lower one.
3. Two bins at *equal* priority → no flip-flop, no oscillating haul.
4. A pawn carrying cargo nothing will accept → falls through to a normal job rather than deadlocking (`pawn_base.gd:216`).
5. Storage under load: a station with 10+ bins and several haulers running → job throughput unchanged, no new "job failed" spam.
6. **GUT**: new `test_storage_query` suite green; full suite green.
