class_name ContractsTab
extends VBoxContainer

## The Trade panel's `CONTRACTS` tab (WI-55) - what `contracts_screen` was
## (WI-14): offered contracts to accept or decline, active ones with progress and
## a deadline, and recent history.
##
## Contracts get a tab rather than a console slot of their own (program decision
## 1): a contract *is* a trade, the design's own Trade panel lists `CONTRACTS`
## beside `ORDERS`, and every one of them fulfils out of the same docking bay the
## order sheet stages goods into. The full-rect dimming overlay it used to wear is
## gone with the rest of them.
##
## The tab shows [method ContractManager.accept_block_reason] inline as well as on
## the button, because "no docking bay" is a thing the player reads the alert
## about and then comes *here* to act on - and a disabled button with the reason
## hidden in its label is not an explanation.

## Rows past this in the history block are dropped from the view. The manager
## keeps twenty; the tab is a glance at what recently resolved, not a ledger.
const HISTORY_SHOWN: int = 8

var _reputation: Chip
var _blocked_notice: Label
var _offers: VBoxContainer
var _active: VBoxContainer
var _history: VBoxContainer

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	_build()
	if Global.contract_manager != null:
		Global.contract_manager.contracts_changed.connect(_on_contracts_changed)

func _build() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	add_child(head)
	_reputation = Chip.create()
	head.add_child(_reputation)
	_blocked_notice = Label.new()
	_blocked_notice.theme_type_variation = UIType.BODY
	_blocked_notice.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)
	_blocked_notice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_blocked_notice)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	scroll.add_child(column)

	_offers = _add_section(column, "Offers")
	_active = _add_section(column, "Active")
	_history = _add_section(column, "History")

func _add_section(parent: Node, title: String) -> VBoxContainer:
	parent.add_child(SectionLabel.create(title))
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	parent.add_child(rows)
	return rows

## Live while the tab is on screen. The panel also calls [method refresh] when the
## tab is selected, so a contract that resolved while ORDERS was showing is caught
## on the way in.
func _on_contracts_changed() -> void:
	if is_visible_in_tree():
		refresh()

func refresh() -> void:
	var manager: ContractManager = Global.contract_manager
	if manager == null or _offers == null:
		return
	_reputation.configure("Reputation", str(manager.reputation), Color(0, 0, 0, 0),
		UIPalette.Row.LIVE if manager.reputation > 0 else UIPalette.Row.INERT)
	var blocked: String = manager.accept_block_reason()
	_blocked_notice.text = blocked
	_blocked_notice.visible = not blocked.is_empty() and not manager.offers.is_empty()

	_fill(_offers, manager.offers, _build_offer_row, "No offers - traders bring new ones")
	_fill(_active, manager.active, _build_active_row, "No active contracts")
	var recent: Array[ContractData] = manager.history.slice(0, HISTORY_SHOWN)
	_fill(_history, recent, _build_history_row, "Nothing yet")

func _fill(container: VBoxContainer, contracts: Array[ContractData], builder: Callable,
		empty_text: String) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
	if contracts.is_empty():
		var empty := Label.new()
		empty.text = empty_text.to_upper()
		empty.theme_type_variation = UIType.META_LINE
		empty.add_theme_color_override("font_color", UIPalette.TEXT_META)
		container.add_child(empty)
		return
	for contract: ContractData in contracts:
		container.add_child(builder.call(contract) as Control)

func _summary(contract: ContractData) -> String:
	return "%d %s for %s" % [contract.amount, contract.resource.name, contract.issuer]

## An offer: the terms on a [ListRow], with ACCEPT and DECLINE beside it. The row
## carries the numbers and the buttons carry the decision, rather than one label
## carrying both - which is what made the old two-line paragraph unreadable at a
## glance.
func _build_offer_row(contract: ContractData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIMetrics.ROW_GAP)

	var entry: ListRow = ListRow.create()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.focus_mode = Control.FOCUS_NONE
	entry.configure(_summary(contract),
		"%d cr each · by cycle %d · penalty %d cr" % [
			contract.unit_price, contract.deadline_cycle, contract.penalty],
		"%d cr" % contract.total_payout(), UIPalette.Row.INERT)
	entry.set_swatch(UIPalette.LIVE)
	# All-or-nothing is the term that surprises people, so it is the tooltip
	# rather than a third line on every row.
	entry.tooltip_text = "All-or-nothing: partial delivery pays only market price."
	row.add_child(entry)

	var reason: String = Global.contract_manager.accept_block_reason()
	var accept: ActionButton = ActionButton.create("Accept", ActionButton.Weight.PRIMARY)
	accept.disabled = not reason.is_empty()
	accept.tooltip_text = reason
	# Shrink-centre, not the container's default fill: a button stretched to a
	# two-line row's height reads as a panel rather than as a control.
	accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	accept.pressed.connect(func() -> void: Global.contract_manager.accept(contract))
	row.add_child(accept)

	var decline: ActionButton = ActionButton.create("Decline", ActionButton.Weight.SECONDARY)
	decline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	decline.pressed.connect(func() -> void: Global.contract_manager.decline(contract))
	row.add_child(decline)
	return row

func _build_active_row(contract: ContractData) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var cycles_left: int = contract.deadline_cycle - Global.time_manager.cycle
	var final_cycle: bool = cycles_left <= 0
	var due: String = "final cycle" if final_cycle else \
		"due cycle %d · %d left" % [contract.deadline_cycle, cycles_left]
	var staged: int = Global.contract_manager.staged_for(contract)

	var entry: ListRow = ListRow.create()
	entry.focus_mode = Control.FOCUS_NONE
	entry.configure(_summary(contract),
		"%s · %d staged at the bay" % [due, staged],
		"%d cr" % contract.total_payout(),
		UIPalette.Row.AMBER if final_cycle else UIPalette.Row.LIVE)
	box.add_child(entry)

	var bar: StatBar = StatBar.create()
	bar.configure("Shipped", float(contract.delivered) / maxf(float(contract.amount), 1.0),
		"%d / %d" % [contract.delivered, contract.amount],
		UIPalette.ATTENTION if final_cycle else UIPalette.GROWTH)
	box.add_child(bar)
	return box

func _build_history_row(contract: ContractData) -> Control:
	var settled: int = contract.total_payout() if contract.state == ContractData.State.FULFILLED \
		else -contract.penalty
	var entry: ListRow = ListRow.create()
	entry.focus_mode = Control.FOCUS_NONE
	entry.configure(_summary(contract), contract.state_name(), "%+d cr" % settled,
		UIPalette.Row.INERT)
	entry.set_swatch(UIPalette.GROWTH if contract.state == ContractData.State.FULFILLED
		else UIPalette.DESTRUCTIVE)
	entry.set_action_color(UIPalette.sign_color(float(settled)))
	return entry
