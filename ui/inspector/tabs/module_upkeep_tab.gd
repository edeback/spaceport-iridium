class_name ModuleUpkeepTab
extends VBoxContainer

## What keeping a standing module costs (2026-09-13): its integrity, whether it
## has broken down, and its share of the upkeep bill.
##
## The inverted inspector made this a tab. Integrity used to be a bar in the
## subject block, above every module's tabs; the identity strip now carries it as
## a number on the meta line (`INT 88%`) and the amber status line still says
## "Damaged" the moment it matters, so the bar moved here, beside the other things
## about the hull's condition. DECONSTRUCT and DEMOLISH hang under this page too,
## through [method ModuleTabSet.page_footer] - the design keeps anything
## destructive off the strip.

var _module: ModuleBase = null
var _bar: StatBar = null
var _rows: VBoxContainer = null

func setup(module: ModuleBase) -> void:
	_module = module
	name = "Upkeep"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_bar = StatBar.create()
	add_child(_bar)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	add_child(_rows)
	SignalBus.module_damaged.connect(_on_durability_changed)
	SignalBus.module_repaired.connect(_on_durability_changed)
	# A breakdown is rolled on the hour and cleared by a repair job; neither
	# announces itself on a signal of its own, so the hour is when to look.
	Global.time_manager.hour_changed.connect(_on_hour_changed)
	refresh()

func _on_durability_changed(module: ModuleBase, _amount: float) -> void:
	if module == _module:
		refresh()

func _on_hour_changed(_hour: int) -> void:
	refresh()

func refresh() -> void:
	if _module == null or not is_instance_valid(_module) or _rows == null:
		return
	var fraction: float = _module.hp_fraction()
	# Through the palette's threshold, like every gauge (WI-58): a module one point
	# down is not a falling vital.
	_bar.configure("Integrity", fraction, "%d%%" % roundi(fraction * 100.0),
		UIPalette.gauge_tint(fraction))
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if _module.has_breakdown():
		# Inert, not amber: the status line on the strip already spends amber on
		# "Broken down", and the same fact twice is the budget spent for nothing.
		_add_row("Breakdown", "a repair job clears it", "BROKEN")
	_add_upkeep_row()

## The module's line of the station's upkeep bill, at the current difficulty -
## the same figure [method EconomyManager.upkeep_total] sums.
func _add_upkeep_row() -> void:
	var data: ModuleData = _module.module_data
	var base: int = data.upkeep_per_cycle if data != null else 0
	var economy: EconomyManager = Global.economy_manager
	if base <= 0 or economy == null:
		_add_row("Upkeep", "this module costs nothing to keep", "—")
		return
	var charged: int = EconomyManager.scaled_cost(base, economy.upkeep_multiplier())
	# Upkeep switches on with ARC's first promotion (WI-26). Quoting the bill with
	# no word about that would read as money already leaving.
	var when: String = "charged each cycle" if economy.upkeep_enabled \
		else "charged once ARC promotes the station"
	_add_row("Upkeep", when, "%d cr/cycle" % charged)

func _add_row(title: String, meta: String, value: String) -> void:
	var row: ListRow = ListRow.create()
	row.disabled = true
	row.focus_mode = Control.FOCUS_NONE
	_rows.add_child(row)
	row.configure(title, meta, value, UIPalette.Row.INERT)
