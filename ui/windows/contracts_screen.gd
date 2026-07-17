class_name ContractsScreen
extends Control

## Contracts board (WI-14): offered contracts (accept/decline), active ones
## (progress + time remaining), and recent history. A management screen like
## the research panel - it does NOT pause the sim, and refreshes live off
## ContractManager.contracts_changed while open.

func _ready() -> void:
	visible = false
	Global.contract_manager.contracts_changed.connect(_on_contracts_changed)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	refresh()

func _on_contracts_changed() -> void:
	if visible:
		refresh()

func _on_close_pressed() -> void:
	visible = false

func refresh() -> void:
	var manager: ContractManager = Global.contract_manager
	%ReputationLabel.text = "Reputation: %d" % manager.reputation
	_fill_section(%OfferRows, manager.offers, _build_offer_row, "No offers - traders bring new ones")
	_fill_section(%ActiveRows, manager.active, _build_active_row, "No active contracts")
	_fill_section(%HistoryRows, manager.history, _build_history_row, "Nothing yet")

func _fill_section(container: VBoxContainer, contracts: Array[ContractData], builder: Callable, empty_text: String) -> void:
	for child: Node in container.get_children():
		child.queue_free()
	if contracts.is_empty():
		var empty := Label.new()
		empty.text = empty_text
		empty.self_modulate = Color(1, 1, 1, 0.5)
		container.add_child(empty)
		return
	for contract: ContractData in contracts:
		container.add_child(builder.call(contract))

func _summary(contract: ContractData) -> String:
	return "%d %s for %s" % [contract.amount, contract.resource.name, contract.issuer]

func _build_offer_row(contract: ContractData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var info := Label.new()
	info.text = "%s — %d cr each (%d total), by cycle %d. Penalty %d cr.\nAll-or-nothing bonus: partial delivery pays only market price." \
		% [_summary(contract), contract.unit_price, contract.total_payout(), contract.deadline_cycle, contract.penalty]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(info)
	var accept := Button.new()
	var reason: String = Global.contract_manager.accept_block_reason()
	accept.text = "Accept" if reason.is_empty() else "Accept (%s)" % reason
	accept.disabled = not reason.is_empty()
	accept.pressed.connect(func() -> void: Global.contract_manager.accept(contract))
	row.add_child(accept)
	var decline := Button.new()
	decline.text = "Decline"
	decline.pressed.connect(func() -> void: Global.contract_manager.decline(contract))
	row.add_child(decline)
	return row

func _build_active_row(contract: ContractData) -> Control:
	var box := VBoxContainer.new()
	var info := Label.new()
	var cycles_left: int = contract.deadline_cycle - Global.time_manager.cycle
	var due: String = "due cycle %d (%d left)" % [contract.deadline_cycle, cycles_left] if cycles_left > 0 else "FINAL CYCLE"
	info.text = "%s — %d cr on completion, %s" % [_summary(contract), contract.total_payout(), due]
	box.add_child(info)
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 0)
	bar.max_value = contract.amount
	bar.value = contract.delivered
	bar.show_percentage = false
	progress_row.add_child(bar)
	var staged: int = Global.contract_manager.staged_for(contract)
	var progress := Label.new()
	progress.text = "%d / %d shipped (%d staged at bay)" % [contract.delivered, contract.amount, staged]
	progress_row.add_child(progress)
	box.add_child(progress_row)
	return box

func _build_history_row(contract: ContractData) -> Control:
	var label := Label.new()
	label.text = "[%s] %s — %d cr" % [contract.state_name(), _summary(contract),
		contract.total_payout() if contract.state == ContractData.State.FULFILLED else -contract.penalty]
	match contract.state:
		ContractData.State.FULFILLED:
			label.self_modulate = Color(0.6, 1.0, 0.6)
		ContractData.State.FAILED:
			label.self_modulate = Color(1.0, 0.5, 0.45)
		_:
			label.self_modulate = Color(1, 1, 1, 0.6)
	return label
