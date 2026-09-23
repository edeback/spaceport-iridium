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
## category_id. A module carries as many tags as those systems need.
@export var tags: Array[String]
## Single build-menu bucket this module lives in, naming a BuildCategoryData by id.
## One category per module - the rail groups on this, never on tags. Display-only
## metadata; not saved (saves key on id).
##
## Was a fixed UICategory enum until WI-47 M5. An enum can't be extended from data,
## so every modded module landed in OTHER however it was authored; a scanned
## resource can be added to. An id nothing declares still renders (under its own
## name, sorted last) rather than disappearing.
@export var category_id: StringName = BuildCategoryData.DEFAULT_ID

## Optional minimap fill (WI-47 audit sweep). The minimap otherwise colours a
## module by looking its tags up in its own authored tag->colour table, which a
## mod cannot add to - so a modded module with a new tag silently drew in the
## fallback hull grey. Alpha 0 (the default) keeps the tag lookup.
@export var minimap_color: Color = Color(0, 0, 0, 0)
## Can you click-drag to place multiples, and along which axis? A drag is judged
## as one line rather than cell by cell (see [MultiplacementPlan]), so there is no
## companion flag to skip the connection check any more: a module halfway down a
## drag is held up by the ones queued in front of it, and whether that holds all
## the way along is something the plan works out, not something a module asserts.
@export var multiplacement := WorldManager.Multiplacement.NONE
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
## get_effective_stat(Stats.BREAKDOWN_CHANCE, ...) so WI-30's Maintenance Facility
## can lower it via adjacency for free.
@export var breakdown_chance_per_hour: float = 0.0
## How strongly a nearby Maintenance Facility's &"maintenance" field suppresses
## this module's breakdown chance (WI-30): effective chance is multiplied by
## 1/(1 + maintenance * k). Higher = more protective. Only matters when
## can_break_down.
@export var maintenance_breakdown_k: float = 1.0
## Output multiplier a broken-down module runs at until a repair job clears it.
## Was a code constant on [ModuleBase]; balance belongs in data (WI-72 §4), and a
## module type that should limp rather than halve can now say so.
const DEFAULT_BREAKDOWN_EFFICIENCY: float = 0.5
@export var breakdown_efficiency: float = DEFAULT_BREAKDOWN_EFFICIENCY
## Of the breakdowns this module rolls, the share that are WEAR - direct damage,
## fixed by an ordinary HP repair - rather than a JAM, a lingering efficiency hit
## that only a completed repair job lifts. 0 = always a jam, 1 = always wear.
const DEFAULT_BREAKDOWN_WEAR_CHANCE: float = 0.5
@export var breakdown_wear_chance: float = DEFAULT_BREAKDOWN_WEAR_CHANCE
## How much of max_hp a wear breakdown takes off.
const DEFAULT_BREAKDOWN_WEAR_DAMAGE: float = 0.15
@export var breakdown_wear_damage_fraction: float = DEFAULT_BREAKDOWN_WEAR_DAMAGE

## --- heat (WI-60) -----------------------------------------------------------
## Energy it takes to move ONE CELL of this module one degree Fahrenheit. The
## module's total thermal mass is this times its footprint, so a big armoured
## module changes temperature slowly and a corridor cell whips around. Lives here
## rather than on HeatComponent because that component is runtime-attached and
## therefore has nowhere to carry per-module-type tuning.
const DEFAULT_THERMAL_MASS_PER_CELL: float = 4.0
@export var heat_thermal_mass_per_cell: float = DEFAULT_THERMAL_MASS_PER_CELL
## How good this module is at shedding heat to space, per unit of exposed face.
## 1.0 is ordinary hull. The Radiator is nothing but this number turned up - the
## exposure scaling it needs is the same term every module already runs.
@export var heat_radiation_mult: float = 1.0
## Does this module slow down when it gets hot? Off for the ninety-odd modules
## that don't care, so they carry one unchecked box rather than three meaningless
## numbers. The three below only matter when this is true.
@export var throttles_when_hot: bool = false
## Temperature at which the throttle begins, and the one at which it reaches
## heat_throttle_max_mult. A lerp between them - never a step, because a hard
## cutoff plus work-proportional heat production is an oscillator.
@export var heat_throttle_start_f: float = 250.0
@export var heat_throttle_full_f: float = 450.0
## Worst-case process_time multiplier. Finite on purpose: a machine that stops
## dead gives the player no gradient to read.
@export var heat_throttle_max_mult: float = 4.0

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
	var cost: int = credit_cost()
	if cost > 0:
		Global.resource_manager.credit_resource.force_withdraw(cost)

## The credit part of [member resource_costs] - what placing one charges up front,
## before any material is delivered.
func credit_cost() -> int:
	return int(resource_costs.get(Global.resource_manager.credit_resource, 0))

func is_unlocked() -> bool:
	if unlocked_by_default:
		return true
	if Global.unlock_manager != null:
		return Global.unlock_manager.is_module_granted(self)
	return false
