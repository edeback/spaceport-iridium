class_name LocalUpgradesTab
extends ScrollContainer

## An inspector tab listing the local (per-instance) upgrades available to the
## selected module, with tier progress and a purchase button. Code-generated so
## the module tab set can add it like any other component UI.

## The tab grows with the catalogue up to this, then scrolls.
##
## It has to be driven from code because **a ScrollContainer reports a minimum
## height of zero** - it is built to be handed a size, not to ask for one. Inside
## the old TabContainer that did not matter, because the container handed every
## page the full panel; the inspector sizes itself to its content, so an
## unmeasured scroll collapsed this tab to nothing while every upgrade row
## underneath was correct. Same trap as WI-48's Social tab, same fix.
const MAX_CONTENT_HEIGHT: float = 320.0

var module: ModuleBase
var _list: VBoxContainer

func setup(m: ModuleBase) -> void:
	module = m
	name = "Upgrades"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	add_child(_list)
	# Backstop: a later layout pass (fonts settling, the tab entering the tree)
	# can change what the rows ask for after refresh() has measured them.
	_list.minimum_size_changed.connect(_fit_height)

	if not SignalBus.module_upgraded.is_connected(_on_module_upgraded):
		SignalBus.module_upgraded.connect(_on_module_upgraded)
	refresh()

## Deliberately synchronous and tree-agnostic: the tab set builds this page and
## configures it before it enters the tree, so anything that awaited a frame or
## touched get_tree() would run against a null tree.
func _fit_height() -> void:
	if _list == null:
		return
	custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, MAX_CONTENT_HEIGHT)

func refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	if module == null:
		_fit_height()
		return
	var catalog := Global.unlock_manager.get_local_upgrade_catalog(module)
	if catalog.is_empty():
		var empty := Label.new()
		empty.text = "No upgrades available."
		empty.theme_type_variation = UIType.META_LINE
		empty.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
		_list.add_child(empty)
		_fit_height()
		return

	for upgrade: LocalUpgradeData in catalog:
		_list.add_child(_build_row(upgrade))
	_fit_height()

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
	detail.theme_type_variation = UIType.BODY
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
