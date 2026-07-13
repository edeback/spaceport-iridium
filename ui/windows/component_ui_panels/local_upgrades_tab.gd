class_name LocalUpgradesTab
extends ScrollContainer

## A tab added to the module info panel listing the local (per-instance) upgrades
## available to the viewed module, with tier progress and a purchase button.
## Code-generated so the info panel can add it like any other component UI.

var module: ModuleBase
var _list: VBoxContainer

func setup(m: ModuleBase) -> void:
	module = m
	name = "Upgrades"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)

	if not SignalBus.module_upgraded.is_connected(_on_module_upgraded):
		SignalBus.module_upgraded.connect(_on_module_upgraded)
	refresh()

func refresh() -> void:
	for child: Node in _list.get_children():
		child.queue_free()

	if module == null:
		return
	var catalog := Global.unlock_manager.get_local_upgrade_catalog(module)
	if catalog.is_empty():
		var empty := Label.new()
		empty.text = "No upgrades available."
		_list.add_child(empty)
		return

	for upgrade: LocalUpgradeData in catalog:
		_list.add_child(_build_row(upgrade))

func _build_row(upgrade: LocalUpgradeData) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var tier: int = module.get_local_upgrade_tier(upgrade)
	var title := Label.new()
	title.text = "%s  (%d/%d)" % [upgrade.name, tier, upgrade.max_tiers]
	info.add_child(title)

	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 12)
	if tier >= upgrade.max_tiers:
		detail.text = "Maxed out"
	else:
		detail.text = "Next: " + _cost_text(upgrade, tier)
	info.add_child(detail)

	var buy := Button.new()
	buy.text = "Buy"
	buy.disabled = not module.can_apply_local_upgrade(upgrade)
	buy.pressed.connect(_on_buy.bind(upgrade))
	row.add_child(buy)

	return panel

func _on_buy(upgrade: LocalUpgradeData) -> void:
	module.try_apply_local_upgrade(upgrade)

func _on_module_upgraded(upgraded_module: ModuleBase) -> void:
	if upgraded_module == module:
		refresh()

func _cost_text(upgrade: LocalUpgradeData, tier: int) -> String:
	var cost := upgrade.get_cost_for_tier(tier)
	if cost.is_empty():
		return "Free"
	var parts: Array[String] = []
	for resource: ResourceData in cost:
		parts.append("%d %s" % [cost[resource], resource.name])
	return ", ".join(parts)
