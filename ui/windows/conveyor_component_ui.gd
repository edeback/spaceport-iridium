class_name ConveyorComponentUI
extends ModuleComponentUI

## Info-panel tab for a Conveyor (WI-27). Renders one configurable block per lane -
## source, destination, and resource dropdowns plus a buffer/status line - and
## rebuilds when the Extra Belt upgrade adds a lane (lanes_changed). Code-generated
## like LocalUpgradesTab.

var conveyor: ConveyorComponent
var _vbox: VBoxContainer
## One entry per lane block, holding its widgets and the option->object maps.
var _rows: Array[Dictionary] = []

func set_conveyor(component: ConveyorComponent) -> void:
	conveyor = component
	name = "Conveyor"

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UIMetrics.COMPONENT_PAGE_PAD)
	add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	margin.add_child(_vbox)

	if not conveyor.lanes_changed.is_connected(_rebuild):
		conveyor.lanes_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for child: Node in _vbox.get_children():
		child.queue_free()
	_rows.clear()
	for i: int in conveyor.lanes.size():
		_build_lane_block(i)

func _build_lane_block(index: int) -> void:
	var lane: ConveyorLane = conveyor.lanes[index]

	var panel := PanelContainer.new()
	_vbox.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", UIMetrics.COMPONENT_BLOCK_GAP)
	var pmargin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		pmargin.add_theme_constant_override("margin_" + side, UIMetrics.COMPONENT_BLOCK_PAD)
	panel.add_child(pmargin)
	pmargin.add_child(inner)

	# Only label the lanes once there's more than one (a single-lane conveyor
	# reads cleaner without a "Belt 1" header).
	if conveyor.lanes.size() > 1:
		var header := Label.new()
		header.text = "Belt %d" % (index + 1)
		header.theme_type_variation = UIType.BODY
		inner.add_child(header)

	var source_selector := _add_row(inner, "Source:")
	var dest_selector := _add_row(inner, "Destination:")
	var resource_selector := _add_row(inner, "Resource:")

	var buffer_label := Label.new()
	buffer_label.theme_type_variation = UIType.META_LINE
	inner.add_child(buffer_label)
	var status_label := Label.new()
	status_label.theme_type_variation = UIType.META_LINE
	status_label.add_theme_color_override("font_color", UIPalette.ATTENTION)
	inner.add_child(status_label)

	var row: Dictionary = {
		"lane": lane,
		"source": source_selector,
		"dest": dest_selector,
		"resource": resource_selector,
		"buffer_label": buffer_label,
		"status_label": status_label,
		"source_opts": [] as Array[ComponentBase],
		"dest_opts": [] as Array[ComponentBase],
		"resource_opts": [] as Array[ResourceData],
	}
	_rows.append(row)

	source_selector.item_selected.connect(_on_source_selected.bind(row))
	dest_selector.item_selected.connect(_on_dest_selected.bind(row))
	resource_selector.item_selected.connect(_on_resource_selected.bind(row))
	_fill_row(row)

func _add_row(parent: VBoxContainer, label_text: String) -> OptionButton:
	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(UIMetrics.COMPONENT_LABEL_WIDTH, 0)
	hbox.add_child(label)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(selector)
	parent.add_child(hbox)
	return selector

func _process(_delta: float) -> void:
	if conveyor == null:
		return
	for row: Dictionary in _rows:
		var lane: ConveyorLane = row["lane"]
		(row["buffer_label"] as Label).text = "Buffer: %d / %d" % [conveyor.lane_buffer_amount(lane), conveyor.buffer_size]
		(row["status_label"] as Label).text = lane.status

## Repopulate one lane block's dropdowns. Called on open and whenever an endpoint
## choice changes (resource options depend on the chosen source).
func _fill_row(row: Dictionary) -> void:
	var lane: ConveyorLane = row["lane"]
	_fill_endpoint_selector(row["source"], conveyor.get_source_options(), lane.source, row["source_opts"])
	_fill_endpoint_selector(row["dest"], conveyor.get_destination_options(), lane.destination, row["dest_opts"])
	_fill_resource_selector(row)

func _fill_endpoint_selector(selector: OptionButton, options: Array[ComponentBase], current: ComponentBase, store: Array[ComponentBase]) -> void:
	selector.clear()
	store.clear()
	selector.add_item("None")
	store.append(null)
	var select_index: int = 0
	for endpoint: ComponentBase in options:
		selector.add_item(_endpoint_label(endpoint))
		store.append(endpoint)
		if endpoint == current:
			select_index = store.size() - 1
	selector.select(select_index)

func _fill_resource_selector(row: Dictionary) -> void:
	var lane: ConveyorLane = row["lane"]
	var selector: OptionButton = row["resource"]
	var store: Array[ResourceData] = row["resource_opts"]
	selector.clear()
	store.clear()
	selector.add_item("None")
	store.append(null)
	var select_index: int = 0
	for res: ResourceData in conveyor.get_resource_options_for(lane):
		selector.add_item(res.name)
		store.append(res)
		if res == lane.resource:
			select_index = store.size() - 1
	selector.select(select_index)

func _endpoint_label(endpoint: ComponentBase) -> String:
	var cell: Vector2i = endpoint.owner_module.module_cell if endpoint.owner_module != null else Vector2i.ZERO
	var base_name: String = "Conveyor" if endpoint is ConveyorComponent else _module_name(endpoint)
	return "%s (%d,%d)" % [base_name, cell.x, cell.y]

func _module_name(endpoint: ComponentBase) -> String:
	if endpoint.owner_module != null and endpoint.owner_module.module_data != null:
		return endpoint.owner_module.module_data.name
	return "Storage"

func _on_source_selected(index: int, row: Dictionary) -> void:
	var opts: Array[ComponentBase] = row["source_opts"]
	conveyor.set_lane_source(row["lane"], opts[index] if index < opts.size() else null)
	_fill_row(row)

func _on_dest_selected(index: int, row: Dictionary) -> void:
	var opts: Array[ComponentBase] = row["dest_opts"]
	conveyor.set_lane_destination(row["lane"], opts[index] if index < opts.size() else null)
	_fill_row(row)

func _on_resource_selected(index: int, row: Dictionary) -> void:
	var opts: Array[ResourceData] = row["resource_opts"]
	conveyor.set_lane_resource(row["lane"], opts[index] if index < opts.size() else null)
