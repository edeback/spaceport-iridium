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
	var ores: Array[ResourceData] = Global.asteroid_manager.ore_types_available
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
	var ores: Array[ResourceData] = Global.asteroid_manager.ore_types_available
	mining_component.priority_ore = null if index <= 0 else ores[index - 1]
