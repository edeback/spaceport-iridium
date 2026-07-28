class_name ModuleData
extends Resource

## Stable identifier for save files (matches the .tres file stem). Never
## rename once players have saves referencing it.
@export var id: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var scene: PackedScene
@export var icon: Texture2D
@export var instant_build: bool = true
@export var resource_costs: Dictionary[ResourceData, int]
## Gameplay tags (upgrade eligibility, global stat-modifier targeting, inspection
## checklist, event conditions, minimap color). NOT the build-menu grouping - that is
## ui_category. A module carries as many tags as those systems need.
@export var tags: Array[String]
## Build-menu categories. Declared in rail-display order - BuildMenuModel sorts the
## rail by these enum values, so OTHER (the catch-all default) always lands last.
## Adding a category means adding it here and giving BuildMenuModel.category_name a
## label. Not a gameplay concept - purely how the build menu groups modules.
enum UICategory {
	CORE,
	POWER,
	LIFE_SUPPORT,
	INDUSTRY,
	FOOD,
	MINING,
	STORAGE,
	CREW,
	COMMERCE,
	DEFENSE,
	LOGISTICS,
	OTHER,
}
## Single build-menu bucket this module lives in. One category per module - the rail
## groups on this, never on tags. Display-only metadata; not saved (saves key on id).
@export var ui_category: UICategory = UICategory.OTHER
## Can you click-drag to place multiples?
@export var multiplacement := WorldManager.Multiplacement.NONE
@export var ignore_multiplacement_connection_check: bool = false
## If hidden, does not show in UI
@export var hidden: bool = false

## If true, this module is buildable from the start. Set false for modules gated
## behind a global unlock - a GrantModuleEffect flips it on at runtime.
@export var unlocked_by_default: bool = true

## Where the structure is placed
@export var interaction_layer: WorldManager.StructureLayer = WorldManager.StructureLayer.MODULE
## Where the structure connects to, could be cross-layer
@export var connection_layer: WorldManager.StructureLayer = WorldManager.StructureLayer.MODULE

@export var flippable: bool = false
@export var flipped_scene: PackedScene

## --- combat / durability (WI-24) --------------------------------------------
## Hit points at full health. Trusses and armor sit high, fragile hardware
## (solar panels) low. Balance lives here per module; the export default is the
## catch-all for the many modules that don't override it.
@export var max_hp: float = 100.0
## Output multiplier at (near) zero HP - damage lerps efficiency between this and
## 1.0 by hp fraction. 1.0 = damage never degrades output (structure/decor).
@export var min_damaged_efficiency: float = 0.25
## Industrial hardware wears out; roll a breakdown each game-hour when true.
@export var can_break_down: bool = false
## Per-game-hour breakdown probability (0..1) when can_break_down. Read through
## get_effective_stat(&"breakdown_chance", ...) so WI-30's Maintenance Facility
## can lower it via adjacency for free.
@export var breakdown_chance_per_hour: float = 0.0
## How strongly a nearby Maintenance Facility's &"maintenance" field suppresses
## this module's breakdown chance (WI-30): effective chance is multiplied by
## 1/(1 + maintenance * k). Higher = more protective. Only matters when
## can_break_down.
@export var maintenance_breakdown_k: float = 1.0

## --- economy (WI-25) --------------------------------------------------------
## Credits this module costs per cycle in upkeep once EconomyManager's upkeep
## toggle is on (WI-26's first ARC inspection). 0 for most modules; industrial
## and comfort modules carry a running cost. Charged over BUILT modules only -
## blueprints and truss are free. Balance lives here per module.
@export var upkeep_per_cycle: int = 0

signal module_lock_changed(locked: bool)

func can_afford() -> bool:
	for resource in resource_costs:
		if resource.get_total() < resource_costs[resource]:
			return false
	return true

## TODO Mostly debug as instantly withdraws instead of setting up jobs
func withdraw_cost() -> void:
	for resource in resource_costs:
		resource.force_withdraw(resource_costs[resource])

func withdraw_credit_cost() -> void:
	var cost = resource_costs.get(Global.resource_manager.credit_resource, 0)
	if cost > 0:
		Global.resource_manager.credit_resource.force_withdraw(cost)

func is_unlocked() -> bool:
	if unlocked_by_default:
		return true
	if Global.unlock_manager != null:
		return Global.unlock_manager.is_module_granted(self)
	return false
