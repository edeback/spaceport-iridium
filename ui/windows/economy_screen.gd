class_name EconomyScreen
extends Control

## The economy page (WI-25): current balance, this-cycle and last-cycle ledger
## breakdowns, the ARC levy summary, loan controls, and the read-only state of
## the recurring-cost toggles. A management screen like Research/Contracts - it
## does NOT pause the sim and refreshes live off SignalBus.economy_changed while
## open. Built entirely in code (like UnlockPanel) so there's no .tscn to author.

const COST_ORDER: Array[StringName] = [
	&"loan_payment", &"wages", &"upkeep", &"levy_fee", &"levy_skim", &"severance", &"penalty", &"event",
]
const INCOME_ORDER: Array[StringName] = [&"trade", &"contract", &"shops", &"hotels", &"dining", &"event"]

var _content: VBoxContainer

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()
	SignalBus.economy_changed.connect(_on_economy_changed)
	# Visitor count/reputation move independently of the ledger (WI-33), so refresh
	# the open page on those too.
	SignalBus.visitors_changed.connect(_on_economy_changed)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	refresh()

func _on_economy_changed() -> void:
	if visible:
		refresh()

func _build_shell() -> void:
	var window := PanelContainer.new()
	window.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	window.custom_minimum_size = Vector2(440, 560)
	window.offset_right = -16
	window.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	window.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(window)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	window.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)
	var title := Label.new()
	title.text = "Economy"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 0)
	close_btn.pressed.connect(func() -> void: visible = false)
	title_bar.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

func refresh() -> void:
	if _content == null:
		return
	for child: Node in _content.get_children():
		child.queue_free()
	var economy: EconomyManager = Global.economy_manager
	if economy == null:
		return
	_build_balance(economy)
	_build_toggles(economy)
	_build_visitors_section()
	_build_cycle_section("This cycle", economy.current_record(), economy)
	_build_cycle_section("Last cycle", economy.last_record(), economy)
	_build_levy_summary(economy)
	_build_loan_section(economy)

# --- sections -----------------------------------------------------------------

func _build_balance(economy: EconomyManager) -> void:
	var balance: int = economy.balance()
	var label := Label.new()
	label.text = "Balance: %d cr" % balance
	label.add_theme_font_size_override("font_size", 20)
	label.self_modulate = Color(1.0, 0.5, 0.45) if balance < 0 else Color(0.6, 1.0, 0.6)
	_content.add_child(label)

func _build_toggles(economy: EconomyManager) -> void:
	var any_on: bool = economy.wages_enabled or economy.upkeep_enabled or economy.levy_enabled
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	if not any_on:
		box.add_child(_muted("Recurring costs begin after your first ARC inspection."))
	else:
		box.add_child(_muted("Active cost streams: %s" % _active_streams(economy)))
	_content.add_child(box)

func _active_streams(economy: EconomyManager) -> String:
	var parts: Array[String] = []
	if economy.wages_enabled:
		parts.append("wages")
	if economy.upkeep_enabled:
		parts.append("upkeep")
	if economy.levy_enabled:
		parts.append("ARC levy")
	return ", ".join(parts) if not parts.is_empty() else "none"

func _build_cycle_section(heading: String, record: Dictionary, economy: EconomyManager) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	var header := Label.new()
	var cycle_no: int = int(record.get("cycle", 0))
	header.text = "%s (cycle %d)" % [heading, cycle_no] if cycle_no > 0 else heading
	header.add_theme_font_size_override("font_size", 16)
	section.add_child(header)

	var income: Dictionary = record.get("income", {})
	var costs: Dictionary = record.get("costs", {})
	if income.is_empty() and costs.is_empty():
		section.add_child(_muted("  Nothing recorded yet."))
		_content.add_child(section)
		return

	var gross_income: int = 0
	for category: StringName in INCOME_ORDER:
		var value: int = int(income.get(category, 0))
		if value > 0:
			gross_income += value
			section.add_child(_line("  %s" % EconomyManager.category_label(category), "+%d" % value, Color(0.6, 1.0, 0.6)))

	var total_cost: int = 0
	for category: StringName in COST_ORDER:
		var value: int = int(costs.get(category, 0))
		if value > 0:
			total_cost += value
			# Wages and upkeep expand into a per-pawn / per-module list. The detail
			# reflects the CURRENT roster/station (the projection for the next
			# settlement) - the closest available breakdown of a charged total.
			if category == &"wages":
				section.add_child(_expandable(EconomyManager.category_label(category), value, _wage_detail(economy)))
			elif category == &"upkeep":
				section.add_child(_expandable(EconomyManager.category_label(category), value, _upkeep_detail(economy)))
			else:
				section.add_child(_line("  %s" % EconomyManager.category_label(category), "-%d" % value, Color(1.0, 0.6, 0.55)))

	var net: int = gross_income - total_cost
	section.add_child(_line("  Net", "%+d" % net, Color(0.6, 1.0, 0.6) if net >= 0 else Color(1.0, 0.6, 0.55)))
	_content.add_child(section)

## Visitor economy summary (WI-33): live guest count + station reputation. The
## per-category income (shops/hotels/dining) shows in the cycle ledger above.
func _build_visitors_section() -> void:
	var visitors: VisitorManager = Global.visitor_manager
	if visitors == null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var header := Label.new()
	header.text = "Visitors"
	header.add_theme_font_size_override("font_size", 16)
	box.add_child(header)
	box.add_child(_line("  On station", str(visitors.visitor_count()), Color(1, 1, 1, 0.8)))
	box.add_child(_line("  Reputation", "%d%%" % roundi(visitors.reputation * 100.0), Color(1, 1, 1, 0.8)))
	_content.add_child(box)

func _build_levy_summary(economy: EconomyManager) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var header := Label.new()
	header.text = "ARC levy"
	header.add_theme_font_size_override("font_size", 16)
	box.add_child(header)
	if economy.levy_enabled:
		box.add_child(_muted("  %d%% of income skimmed, plus %d cr every %d cycles." %
			[int(round(economy.levy_fraction * 100.0)), economy.levy_fee_amount, economy.levy_fee_cycles]))
	else:
		box.add_child(_muted("  Not yet levied."))
	_content.add_child(box)

func _build_loan_section(economy: EconomyManager) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var header := Label.new()
	header.text = "Loan"
	header.add_theme_font_size_override("font_size", 16)
	box.add_child(header)
	if economy.loan_active:
		box.add_child(_muted("  Owed: %d cr, drafting %d cr/cycle (%d left)." %
			[economy.loan_remaining, economy.loan_payment, economy.loan_payments_left]))
		var repay := Button.new()
		repay.text = "Repay in full (%d cr)" % economy.loan_remaining
		repay.pressed.connect(func() -> void: economy.repay_loan_early())
		box.add_child(repay)
	else:
		box.add_child(_muted("  Borrow from ARC at %d%% interest, repaid over %d cycles." %
			[int(round(economy.loan_interest_fraction * 100.0)), economy.loan_term_cycles]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for principal: int in economy.loan_principal_tiers:
			var btn := Button.new()
			btn.text = "Take %d" % principal
			btn.pressed.connect(func() -> void: economy.take_loan(principal))
			row.add_child(btn)
		box.add_child(row)
	_content.add_child(box)

# --- detail lists -------------------------------------------------------------

func _wage_detail(economy: EconomyManager) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var breakdown: Dictionary = economy.wage_breakdown()
	if breakdown.is_empty():
		box.add_child(_muted("    (no wage-drawing crew)"))
	for pawn: PawnBase in breakdown:
		var name_text: String = pawn.pawn_name if not pawn.pawn_name.is_empty() else "Crew"
		box.add_child(_line("    %s" % name_text, "-%d" % int(breakdown[pawn]), Color(1, 1, 1, 0.7)))
	return box

func _upkeep_detail(economy: EconomyManager) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var breakdown: Dictionary = economy.upkeep_breakdown()
	if breakdown.is_empty():
		box.add_child(_muted("    (no upkeep modules)"))
	var base: int = 0
	for module: ModuleBase in breakdown:
		base += int(breakdown[module])
		box.add_child(_line("    %s" % module.module_data.name, "-%d" % int(breakdown[module]), Color(1, 1, 1, 0.7)))
	# Difficulty scales the bill as a whole (WI-37), so the per-module rows are base
	# costs. Show the adjustment explicitly rather than let the rows fail to sum to
	# the charged total above them.
	var scaled: int = economy.upkeep_total()
	if scaled != base:
		var difficulty_name: String = SaveManager.difficulty_label(Global.difficulty_id())
		box.add_child(_line("    %s rate" % difficulty_name, "%+d" % (base - scaled), Color(1, 1, 1, 0.7)))
	return box

# --- widgets ------------------------------------------------------------------

## A collapsible cost row: a flat toggle button "▸ Label   -amount" that reveals
## `detail` when clicked. Detail starts hidden.
func _expandable(label: String, amount: int, detail: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	detail.visible = false
	var toggle := Button.new()
	toggle.flat = true
	toggle.toggle_mode = true
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.self_modulate = Color(1.0, 0.6, 0.55)
	toggle.text = "  ▸ %s      -%d" % [label, amount]
	toggle.toggled.connect(func(pressed: bool) -> void:
		toggle.text = "  %s %s      -%d" % ["▾" if pressed else "▸", label, amount]
		detail.visible = pressed)
	box.add_child(toggle)
	box.add_child(detail)
	return box

func _line(left_text: String, right_text: String, color: Color = Color.WHITE) -> Control:
	var row := HBoxContainer.new()
	var left := Label.new()
	left.text = left_text
	left.self_modulate = color
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := Label.new()
	right.text = right_text
	right.self_modulate = color
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(right)
	return row

func _muted(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.self_modulate = Color(1, 1, 1, 0.55)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
