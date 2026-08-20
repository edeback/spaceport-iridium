class_name MiningComponentUI
extends ModuleComponentUI

@export var drones_label: Label
@export var priority_ore_selector: OptionButton

var mining_component: MiningComponent

func set_mining_component(component: MiningComponent) -> void:
	mining_component = component
	_refresh_drones_label()
	priority_ore_selector.clear()
	# Index 0 = no preference; ore N sits at index N + 1.
	priority_ore_selector.add_item("None")
	var ores: Array[ResourceData] = _selectable_ores()
	for ore: ResourceData in ores:
		priority_ore_selector.add_item(ore.name)
	var current: int = ores.find(component.priority_ore)
	priority_ore_selector.select(current + 1 if current >= 0 else 0)
	priority_ore_selector.item_selected.connect(_on_priority_ore_selected)

func _process(_delta: float) -> void:
	# Drones build/destruct over time; cheap enough to just poll while open.
	if mining_component != null:
		_refresh_drones_label()

func _refresh_drones_label() -> void:
	drones_label.text = "Mining drones: %d / %d" % [mining_component.drones.size(), mining_component.max_drones]

func _on_priority_ore_selected(index: int) -> void:
	var ores: Array[ResourceData] = _selectable_ores()
	mining_component.priority_ore = null if index <= 0 else ores[index - 1]

## Everything any kind of mineable body can yield (WI-61), not the belt's
## authored ore list this used to read. That list silently omitted a comet-only
## resource - and, a latent WI-47 gap, any mod ore that had joined the belt
## through ResourceData.asteroid_spawn_weight rather than through the export.
##
## Built the same way in both places rather than cached: the list is short, it
## is only walked when the panel opens or the player picks, and a cached copy is
## one more thing to invalidate when a mod loads.
func _selectable_ores() -> Array[ResourceData]:
	return Global.asteroid_manager.spawnable_yields()
