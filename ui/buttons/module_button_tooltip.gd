class_name ModuleButtonTooltip
extends PanelContainer

## The hover card behind a module tile (WI-54: demoted, not deleted).
##
## The flyout's selected row now explains the module inline, which is where a
## player reading a list should find it. This survives for the one place there is
## no room for that: the recently-built strip, whose tiles are 40px icons with no
## text on them at all. Without it a recent tile is an unlabelled picture.
##
## It is deliberately a *convenience*, so it carries only what a tile cannot: the
## name, the cost, and - for a locked module - the tech that grants it. Anything
## richer belongs in the list, where it survives keyboard navigation.

const SCENE_PATH: String = "res://ui/buttons/module_button_tooltip.tscn"

var _icon: TextureRect
var _name_label: Label
var _description: Label
var _costs: HFlowContainer

func _ready() -> void:
	_ensure_refs()

func _ensure_refs() -> void:
	if _name_label != null:
		return
	_icon = get_node_or_null("Pad/Column/Head/Icon") as TextureRect
	_name_label = get_node_or_null("Pad/Column/Head/Name") as Label
	_description = get_node_or_null("Pad/Column/Description") as Label
	_costs = get_node_or_null("Pad/Column/Costs") as HFlowContainer

func set_module_data(module_data: ModuleData, locked: bool = false,
		gating_label: String = "") -> void:
	_ensure_refs()
	if module_data == null or _name_label == null:
		return
	_name_label.text = module_data.name
	_icon.texture = module_data.icon
	_icon.custom_minimum_size = Vector2(
		float(UIMetrics.BUILD_ROW_ICON), float(UIMetrics.BUILD_ROW_ICON))
	_description.text = module_data.description
	_description.visible = not module_data.description.is_empty()
	for child: Node in _costs.get_children():
		_costs.remove_child(child)
		child.queue_free()
	if locked:
		# A locked module has no cost worth quoting - what it has is a gate.
		#
		# Inert, matching the row this tooltip belongs to (WI-58). The row already
		# dims and prints its gate in TEXT_META; the tooltip alone wore amber, so
		# hovering a locked entry raised an alarm about a module the player has
		# simply not researched yet.
		var gate: Chip = Chip.create()
		gate.configure(gating_label, "", Color.TRANSPARENT, UIPalette.Row.INERT)
		_costs.add_child(gate)
		return
	# One chip per resource, in the same descending-amount order the row's meta
	# line uses, so the tooltip and the list never disagree about which cost is
	# the headline.
	for resource: ResourceData in _cost_order(module_data.resource_costs):
		var amount: int = module_data.resource_costs[resource]
		var chip: Chip = Chip.create()
		var affordable: bool = resource.get_total() >= amount
		chip.configure(resource.name, str(amount), Color.TRANSPARENT,
			UIPalette.Row.INERT if affordable else UIPalette.Row.AMBER)
		chip.set_icon(resource.icon)
		_costs.add_child(chip)

func _cost_order(costs: Dictionary[ResourceData, int]) -> Array[ResourceData]:
	var out: Array[ResourceData] = []
	for resource: ResourceData in costs:
		if resource != null and costs[resource] > 0:
			out.append(resource)
	out.sort_custom(func(a: ResourceData, b: ResourceData) -> bool:
		if costs[a] != costs[b]:
			return costs[a] > costs[b]
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return out
