# WI-43 — Build Menu Reorganization

> **STATUS: COMPLETE (2026-07-27).** Shipped. The overflowing per-tag `FoldableContainer` accordion is replaced by a fixed **category rail** that opens a floating, internally-scrolling **flyout grid**, plus a live **search** field and a **recently-built** strip. Grouping moved off the multi-purpose `tags` field onto a new single-value `ModuleData.UICategory` enum, so `tags` stays untouched for gameplay. 393 GUT tests green (+16 new in `test_build_menu_model.gd`). Save-neutral (`ui_category` is display-only; saves key on `id`). Not committed.
>
> **Player problem it fixes:** late game, a single tag section grew taller than the screen. The list had no `ScrollContainer`, so an open category pushed the headers of every *other* category off the bottom with no way to reach them. The rail's height is now bounded by category count (~11), never by module count, so it can't overflow; each category's modules live in a bounded flyout that scrolls internally.

## Goal

Make the build menu navigable at any station size, and stop overloading `tags` (a gameplay field) with UI-grouping duty.

## Design

### Categories are their own field, not `tags`

`tags` is load-bearing for gameplay — it drives local-upgrade eligibility (`local_upgrade_data.gd:42`), global stat-modifier targeting (`unlock_manager.gd:58`), the ARC inspection facility checklist (`inspection_runner.gd:213`, `tier_data.gd`), event conditions (`condition_has_module_tag.gd`), and minimap fill colors (`minimap.gd:213`). A module also carries several tags at once. So the build menu keys on a **new dedicated field** instead, leaving `tags` exactly as it was.

`ModuleData.UICategory` is a plain enum, declared in **rail-display order** so ordering is just an ascending sort of the enum values (`OTHER`, the catch-all default, is the max and lands last):

```
CORE, POWER, LIFE_SUPPORT, INDUSTRY, FOOD, MINING,
STORAGE, CREW, COMMERCE, DEFENSE, LOGISTICS, OTHER
```

`@export var ui_category: UICategory = UICategory.OTHER`. One category per module (no more cross-category duplicates like Hotel Room appearing under both Commerce and Lodging). An enum, not a string, so a typo can't silently create a phantom bucket.

**Taxonomy** (largest bucket 5, dissolving the old 11-module `Industrial` tag for menu purposes; `tags` themselves unchanged):

| Category | Modules |
|---|---|
| Core | airlock, turbolift, truss, stairs, hallway |
| Power | solar_panel, fusion_reactor, debug_power |
| Life Support | o2_generator, o2_scrubber, air_purifier |
| Industry | ore_processor, ice_processor, electrolysis_processor, forge, maintenance_facility |
| Food | hydroponics_bay, algae_tank, algae_vats |
| Mining | mining_bay |
| Storage | small/medium/large_storage |
| Crew | sleeping_pod, mess_hall, holodeck, garden, medical_bay |
| Commerce | shop, hotel_room, docking_bay |
| Defense | shield_generator, laser_turret, armor_plate |
| Logistics | repair_bay, recharge_station, logistics_bay, conveyor, teleporter |

### Pure logic in `BuildMenuModel`

Autoload-free, static, GUT-tested — same contract as `StorageQuery`/`MinimapTransform`:
- `group_modules(modules)` → `Dictionary[UICategory, Array[ModuleData]]`, hidden dropped, buckets name-sorted.
- `category_order(Array[int])` → present categories de-duped and sorted ascending (enum order == rail order).
- `category_name(UICategory)` → the rail label (a `match`; GDScript can't reflect a custom enum's member names at runtime).
- `filter_by_name(modules, query)` → case-insensitive substring, blank query → empty.
- `push_recent(recent, id, cap)` → MRU insert/dedupe/cap on stable `id`s, non-mutating.

### `BuildMenu` (view only)

Root `VBoxContainer` mounted where the accordion's `ButtonContainer` was in `ui_main.tscn`. Owns:
- **Search** `LineEdit` — non-empty shows a flat flyout of name matches (rail selection ignored); cleared closes it.
- **Recent** `HFlowContainer` — the last 5 placed modules as **small (40px) icon-only** buttons (name via the existing hover tooltip). Session-only; excludes `hidden` and the auto-placed `truss_mdata`. *(Was full icon+name `ModuleButton`s that ate far too much vertical space — the reason this strip was reworked.)*
- **Category rail** `VBoxContainer` — one button per category in `category_order`. Each shows a **fixed 64×64 icon + the category name**. Icons come from an inspector-set `@export var cat_icon: Dictionary[UICategory, Texture2D]`, falling back to a representative module's icon for any category left unset. The icon is a composed `TextureRect` (not `Button.icon`) because `Button.icon`/`expand_icon` can't pin an exact size while text is present. A category's rail button hides when all its modules are locked.
- **Flyout** — a `top_level` `PanelContainer` (positions in global space, floats over the game view) → `ScrollContainer` (height capped at 440px, then scrolls) → `VBoxContainer` list of the standard `ModuleButton`s (icon + name, **unchanged** from before). Positioned to the right of the rail at the clicked button's y, clamped inside the viewport. Selecting a module drops into placement mode and dismisses the flyout.

Unlock reactivity: every `ModuleData.module_lock_changed` fires one shared zero-arg handler that recomputes rail-button visibility and rebuilds the open flyout — cheap given the small module count.

## Files

**New**
- `ui/buttons/build_menu_model.gd` (`class_name BuildMenuModel`) — pure logic
- `ui/buttons/build_menu.gd` + `build_menu.tscn` (`class_name BuildMenu`)
- `tests/unit/test_build_menu_model.gd` — 16 tests

**Changed**
- `data/modules/module_data.gd` — added `UICategory` enum + `ui_category` field (`tags` untouched)
- 39 non-hidden module `.tres` under `data/modules/**` — set `ui_category` (int enum value)
- `ui/ui_main.gd` / `ui_main.tscn` — removed the old scan/group code (`load_moduledatas`, `create_module_button_groups`, `module_data_groups`, `temp_modules`, `button_group`/`button_container`); instanced `build_menu.tscn`; widened the left column 176→190

**Deleted (dead after this)**
- `ui/buttons/module_button_group.gd` + `.tscn`, `ui/data/module_group.tres` (the accordion + its `FoldableGroup`)

**Reused unchanged**
- `ui/buttons/module_button.gd` (flyout + recent), `module_button_tooltip.*`, `ResourceScanner.scan_paths`, `ModuleData.is_unlocked()`, `SignalBus.module_added`, `ModuleBase.module_data`

## Verification

1. `godot --headless --editor --quit` reimport → no parse errors (the enum-typed `Dictionary[UICategory, Texture2D]` export parses).
2. Full GUT suite green: **393** (was 377 pre-WI-43; +16 in `test_build_menu_model.gd` covering grouping, `hidden` exclusion, enum ordering + OTHER-last + dedupe, `category_name`, search case-insensitivity/empty/no-match/hidden, and MRU prepend/dedupe/cap/non-mutation).
3. Clean headless smoke run of `main.tscn` (200 frames) — enum `.tres` values load into the new property and `BuildMenu` builds the rail + recent strip with no runtime errors.
4. Live MCP run (before the final icon-sizing pass): confirmed rail order, unlock-gating (Life Support / Defense / Logistics hidden at game start), the Recent strip populating from the auto-placed starting modules, and the flyout opening beside the rail with the right modules (Industry → Forge / Ice Processor / Ore Processor). Standard `Control` UI (no `_draw`/shader), so headless + one live run cover it.

## Notes / follow-ups

- Recent is session-only (not persisted). Persisting it is a small future add — `push_recent` already keys on stable `id`.
- The rail with 64px icons is ~11 × ~72px tall; comfortable at 1080p. On much shorter windows it could want its own `ScrollContainer` — deferred until it's a real problem.
- `cat_icon` starts empty; until filled in the inspector, rail icons fall back to a representative module's icon, so the rail is never blank.

Related: [[WI-42_Preview_Metadata_Cache]], [[WI-41_Group_Constants]], `01_Technical_Specification.md` (build-menu discovery still scans `data/` via `ResourceScanner`; grouping field is now `ui_category`).
