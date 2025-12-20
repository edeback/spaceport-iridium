# Grid Building Plugin v5.0.0

**Documentation:** https://gridbuilding.pages.dev/

A comprehensive building and grid targeting system for 2D Godot games featuring dependency injection, modular architecture, and extensive validation.

## Features

- **Advanced Grid Systems** - Flexible grid positioning and validation for top-down, platformer, and isometric games
- **Building Mechanics** - Complete placement workflow from preview to confirmation
- **Visual Feedback** - Real-time indicators and validation feedback
- **Object Manipulation** - Move, rotate, flip, and demolish placed objects
- **Modular Architecture** - Dependency injection with clean separation of concerns
- **Comprehensive Testing** - 1410 automated tests at 100% pass rate
- **Extensively Documented** - 126+ classes with detailed API documentation

## Requirements

- **Godot:** 4.4.0, 4.4.1, or 4.5 (stable)
- **TileMapLayer:** Uses Godot 4.4+ TileMapLayer nodes (not legacy TileMap)
- Basic understanding of 2D games and tilemaps

## Resources

- **Complete Documentation:** https://gridbuilding.pages.dev/
- **API Reference:** https://gridbuilding.pages.dev/v5-0-0/api/
- **User Guides:** https://gridbuilding.pages.dev/v5-0-0/guides/
- **Test Suite:** https://github.com/ChrisTutorials/grid_building_test (1410 tests)
- **Tutorials:** [YouTube Playlist](https://www.youtube.com/playlist?list=PLyH-qXFkNSxl5bQkTYzMXyRwVr8Vc4Sib)
- **Support:** [Discord Server](https://discord.gg/4d85Nd56Wf)

## Installation

1. Download and extract the plugin to `addons/grid_building/`
2. Enable the plugin in **Project Settings → Plugins**
3. Copy `templates/grid_building_templates/` to your project root for easy customization

## Quick Start

For a complete step-by-step setup guide, see the **[Getting Started Guide](https://gridbuilding.pages.dev/v5-0-0/guides/getting-started/)**.

### Basic Setup (5 minutes)

1. **Add Core Systems** - Drop `templates/systems.tscn` into your main scene
2. **Add Grid Stack** - Add `templates/grid_positioner_stack.tscn` and configure collision mask
3. **Set Runtime Context** - Add GBOwner to player, GBLevelContext to level
4. **Add UI** - Add `templates/placeable_selection_ui.tscn` to your UI
5. **Configure Input** - Add `build_confirm` and `build_cancel` actions in Input Map
6. **Create Placeables** - Make Placeable resources pointing to your building scenes
7. **Test** - Run and select a placeable to enter build mode

**Need more details?** See the full [Getting Started Guide](https://gridbuilding.pages.dev/v5-0-0/guides/getting-started/) for detailed instructions, examples, and troubleshooting.

## Architecture Overview

The plugin uses a **dependency injection system** to automatically wire up all components:

- **GBInjectorSystem** - Root system that configures all dependencies
- **GBCompositionContainer** - Central container providing states and configuration
- **Core Systems** - BuildingSystem, GridTargetingSystem, ManipulationSystem, IndicatorManager
- **State Management** - BuildingState, ModeState, GridTargetingState, ManipulationState
- **Context Providers** - GBOwner (player), GBLevelContext (level/tilemap)

All systems are automatically configured when present in your scene. No manual dependency wiring required.

**Learn more:** [Architecture Guide](https://gridbuilding.pages.dev/v5-0-0/guides/architecture/)

---

## Building Rules & Validation

Placement rules validate where objects can be placed. Rules can be:
- **Global** - Set on IndicatorManager (apply to all placeables)
- **Per-Object** - Set on individual Placeable resources

**Built-in Rules:** CollisionCheckRule, WithinTilemapBoundsRule, ValidPlacementTileRule, SpendMaterialsRuleGeneric

**Create Custom Rules:** Inherit from PlacementRule or TileCheckRule

**Learn more:** [Placement Rules Guide](https://gridbuilding.pages.dev/v5-0-0/guides/placement-rules/)

---

## Object Manipulation

Enable object manipulation by adding a **Manipulatable** node to your building scenes. Configure which operations are allowed (move, rotate, flip, demolish) via **ManipulatableSettings**.

**Learn more:** [Object Manipulation Guide](https://gridbuilding.pages.dev/v5-0-0/guides/manipulation/)

---

## Additional Features

### Optional Inventory System

The plugin includes an optional inventory addon (`addons/grid_building_inventory/`) for resource-based building with ItemContainer, BaseItem, and SpendMaterialsRule.

**Learn more:** [Inventory Guide](https://gridbuilding.pages.dev/v5-0-0/guides/inventory/)

### Optional Components

- **TargetHighlighter** - Visual tinting for valid/invalid placements
- **CursorChanger** - Dynamic cursor updates
- **CategoricalTag** - Organize placeables by category

**Learn more:** [Optional Components Guide](https://gridbuilding.pages.dev/v5-0-0/guides/optional-components/)

---

## Asset Credits

See credits: [Pastebin](https://pastebin.com/HYznA3F8)

---

## Troubleshooting

For common issues and solutions, see the **[Troubleshooting Guide](https://gridbuilding.pages.dev/v5-0-0/guides/troubleshooting/)**.

**Quick Tips:**
- Preview disappears over UI? Set UI nodes' Mouse Filter to "Pass" or "Ignore", or disable `hide_on_handled` in GridTargetingSettings
- For more details on grid targeting visibility behavior, see the [Grid Targeting Guide](https://gridbuilding.pages.dev/v5-0-0/guides/grid_targeting/#hide-on-handled-behavior)

---
