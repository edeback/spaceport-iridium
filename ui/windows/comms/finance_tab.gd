class_name FinanceTab
extends VBoxContainer

## The `FINANCE` tab of the Comms panel (WI-57 §4): the station's books - balance,
## this-cycle and last-cycle ledger breakdowns by category, the expandable
## wages/upkeep per-payer detail, visitors and reputation, the ARC levy summary,
## and the loan controls.
##
## This is `economy_screen.gd`, moved. Its **content is unchanged**; what it lost
## is a bespoke `PanelContainer` window it anchored to the centre-right of the
## screen, a 24px title, an `X` button, and its own `close_requested` signal - all
## four of which the [ConsolePanel] frame above it now provides once for every
## panel in the game (invariant 6).
##
## It belongs to Comms because it is ARC's business end to end: the levy is ARC's
## skim, the loans are ARC's loans, and the cost streams switch on the moment ARC
## promotes the station (program decision 1). A ledger with no console slot of its
## own was the other option and it would have been the twentieth surface this
## program exists to delete.
##
## Refreshes live off [signal SignalBus.economy_changed] while visible, and does
## **not** pause the sim.
##
## Each cycle shows two bottom lines (WI-68 F4). **Operating net** is the ledger:
## income minus costs, every booked category included. **Balance change** is what
## the balance actually did, which also counts the spending the ledger treats as
## capital - building, research, upgrades - and loan principal. The tab used to
## show one "Net" that left out purchases, ransoms and hire fees too, so a cycle
## could read +250 while the balance fell by thousands.
##
## Category order comes from EconomyManager's declared lists; this tab keeps no
## list of its own, which is how a category once went missing from the total.

var _content: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_body()
	SignalBus.economy_changed.connect(_on_economy_changed)
	# Visitor count/reputation move independently of the ledger (WI-33), so refresh
	# the open page on those too.
	SignalBus.visitors_changed.connect(_on_economy_changed)
	refresh()

func _on_economy_changed() -> void:
	if is_visible_in_tree():
		refresh()

## Just a scroll and a column now. The window this used to build is the frame's
## job; a tab that drew its own would be exactly the inconsistency invariant 6
## names as most of the polish gap.
func _build_body() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	scroll.add_child(_content)

func refresh() -> void:
	if _content == null:
		return
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var economy: EconomyManager = Global.economy_manager
	if economy == null:
		return
	_build_balance(economy)
	_build_cycle_section("This cycle", economy.current_record(), economy)
	_build_cycle_section("Last cycle", economy.last_record(), economy)
	_build_visitors_section()
	_build_levy_summary(economy)
	_build_loan_section(economy)

# --- sections -----------------------------------------------------------------

## The balance, plus which cost streams are live. The two belong together: a
## healthy balance with the streams still off is a different situation from the
## same number after a promotion, and the player has to be able to tell.
func _build_balance(economy: EconomyManager) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	block.add_child(SectionLabel.create("Balance"))

	var balance: int = economy.balance()
	var label := Label.new()
	label.text = "%d cr" % balance
	label.theme_type_variation = UIType.METRIC_LARGE
	# A negative balance is a falling vital, which is one of the four sanctioned
	# amber uses (invariant 5).
	label.add_theme_color_override("font_color", UIPalette.sign_color(float(balance)))
	block.add_child(label)

	var any_on: bool = economy.wages_enabled or economy.upkeep_enabled or economy.levy_enabled
	block.add_child(_muted("Recurring costs begin after your first ARC inspection."
		if not any_on else "Active cost streams: %s" % _active_streams(economy)))
	_content.add_child(block)

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
	var cycle_no: int = int(record.get("cycle", 0))
	section.add_child(SectionLabel.create(
		"%s (cycle %d)" % [heading, cycle_no] if cycle_no > 0 else heading))

	var income: Dictionary = record.get("income", {})
	var costs: Dictionary = record.get("costs", {})
	var knows_change: bool = EconomyManager.knows_balance_change(record)
	var change: int = EconomyManager.balance_change(record, economy.balance())
	# A cycle spent only on building has an empty ledger but a very real balance
	# change - that is not "nothing recorded".
	if income.is_empty() and costs.is_empty() and (not knows_change or change == 0):
		section.add_child(_muted("Nothing recorded yet."))
		_content.add_child(section)
		return

	for category: StringName in _in_display_order(income, EconomyManager.INCOME_CATEGORIES):
		var value: int = int(income[category])
		if value > 0:
			section.add_child(_line(EconomyManager.category_label(category), "+%d" % value, UIPalette.LIVE))

	for category: StringName in _in_display_order(costs, EconomyManager.COST_CATEGORIES):
		var value: int = int(costs[category])
		if value > 0:
			# Wages and upkeep expand into a per-pawn / per-module list. The detail
			# reflects the CURRENT roster/station (the projection for the next
			# settlement) - the closest available breakdown of a charged total.
			if category == &"wages":
				section.add_child(_expandable(EconomyManager.category_label(category), value, _wage_detail(economy)))
			elif category == &"upkeep":
				section.add_child(_expandable(EconomyManager.category_label(category), value, _upkeep_detail(economy)))
			else:
				section.add_child(_line(EconomyManager.category_label(category), "-%d" % value, UIPalette.ATTENTION))

	var net: int = EconomyManager.record_net(record)
	section.add_child(_line("Operating net", "%+d" % net, UIPalette.sign_color(float(net))))
	# Absent for a cycle from a save that predates WI-68 - hidden rather than
	# guessed, since "since the load" would be a different number.
	if knows_change:
		section.add_child(_line("Balance change", "%+d" % change, UIPalette.sign_color(float(change))))
		if change != net:
			section.add_child(_muted("Balance change also counts building, research, upgrades and loans."))
	_content.add_child(section)

## A record's categories in the declared display order, then any undeclared ones
## (EconomyManager has already reported those) - so nothing booked is left off
## the page, and the lines always add up to the operating net beneath them.
static func _in_display_order(bucket: Dictionary, declared: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for category: StringName in declared:
		if bucket.has(category):
			out.append(category)
	for category: Variant in bucket:
		var id: StringName = StringName(str(category))
		if not out.has(id):
			out.append(id)
	return out

## Visitor economy summary (WI-33): live guest count + station reputation. The
## per-category income (shops/hotels/dining) shows in the cycle ledger above.
func _build_visitors_section() -> void:
	var visitors: VisitorManager = Global.visitor_manager
	if visitors == null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(SectionLabel.create("Visitors"))
	box.add_child(_line("On station", str(visitors.visitor_count()), UIPalette.TEXT))
	box.add_child(_line("Reputation", "%d%%" % roundi(visitors.reputation * 100.0), UIPalette.TEXT))
	_content.add_child(box)

func _build_levy_summary(economy: EconomyManager) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(SectionLabel.create("ARC levy"))
	if economy.levy_enabled:
		box.add_child(_muted("%d%% of income skimmed, plus %d cr every %d cycles." %
			[int(round(economy.levy_fraction * 100.0)), economy.levy_fee_amount, economy.levy_fee_cycles]))
	else:
		box.add_child(_muted("Not yet levied."))
	_content.add_child(box)

func _build_loan_section(economy: EconomyManager) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	box.add_child(SectionLabel.create("Loan"))
	if economy.loan_active:
		box.add_child(_muted("Owed: %d cr, drafting %d cr/cycle (%d left)." %
			[economy.loan_remaining, economy.loan_payment, economy.loan_payments_left]))
		var repay: ActionButton = ActionButton.create(
			"Repay in full (%d cr)" % economy.loan_remaining, ActionButton.Weight.PRIMARY)
		repay.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		repay.pressed.connect(func() -> void: economy.repay_loan_early())
		box.add_child(repay)
	else:
		box.add_child(_muted("Borrow from ARC at %d%% interest, repaid over %d cycles." %
			[int(round(economy.loan_interest_fraction * 100.0)), economy.loan_term_cycles]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
		for principal: int in economy.loan_principal_tiers:
			var button: ActionButton = ActionButton.create(
				"Take %d" % principal, ActionButton.Weight.SECONDARY)
			button.pressed.connect(func() -> void: economy.take_loan(principal))
			row.add_child(button)
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
		box.add_child(_line("    %s" % name_text, "-%d" % int(breakdown[pawn]), UIPalette.TEXT_SECONDARY))
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
		box.add_child(_line("    %s" % module.module_data.name, "-%d" % int(breakdown[module]), UIPalette.TEXT_SECONDARY))
	# Difficulty scales the bill as a whole (WI-37), so the per-module rows are base
	# costs. Show the adjustment explicitly rather than let the rows fail to sum to
	# the charged total above them.
	var scaled: int = economy.upkeep_total()
	if scaled != base:
		var difficulty_name: String = SaveManager.difficulty_label(Global.difficulty_id())
		box.add_child(_line("    %s rate" % difficulty_name, "%+d" % (base - scaled), UIPalette.TEXT_SECONDARY))
	return box

# --- widgets ------------------------------------------------------------------

## A collapsible cost row: a flat toggle "▸ Label   -amount" that reveals `detail`
## when clicked. Detail starts hidden.
func _expandable(label: String, amount: int, detail: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	detail.visible = false
	var toggle := Button.new()
	toggle.flat = true
	toggle.toggle_mode = true
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.add_theme_color_override("font_color", UIPalette.ATTENTION)
	toggle.text = "▸ %s      -%d" % [label, amount]
	toggle.toggled.connect(func(pressed: bool) -> void:
		toggle.text = "%s %s      -%d" % ["▾" if pressed else "▸", label, amount]
		detail.visible = pressed)
	box.add_child(toggle)
	box.add_child(detail)
	return box

func _line(left_text: String, right_text: String, color: Color = UIPalette.TEXT) -> Control:
	var row := HBoxContainer.new()
	var left := Label.new()
	left.text = left_text
	left.add_theme_color_override("font_color", color)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Ellipsed rather than allowed to grow: a long module name in the upkeep detail
	# would otherwise push the amount column off the panel (the WI-53 [ListRow]
	# lesson, which applies to any hand-built row too).
	left.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(left)
	var right := Label.new()
	right.text = right_text
	right.theme_type_variation = UIType.METRIC
	right.add_theme_color_override("font_color", color)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(right)
	return row

func _muted(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UIType.BODY
	label.add_theme_color_override("font_color", UIPalette.TEXT_META)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
