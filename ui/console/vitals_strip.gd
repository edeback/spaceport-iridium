class_name VitalsStrip
extends HBoxContainer

## The console's flex zone (WI-52): six chips the player curates, plus the fixed
## LEDGER control on the right.
##
## Invariant 4 - "vitals are pinned; everything else is the ledger" - is really a
## claim that the layout must be *indifferent to the resource count*. A strip that
## grew with the resource list would eventually wrap, or shrink its numbers below
## the 11px floor. Pinning moves the curation decision to the player and makes the
## strip's width a constant; the ledger is where completeness lives.
##
## Three kinds of chip, because three things worth watching are not resources:
##
##   - **Resource chips.** A [ResourceData] and its `get_total()`. Any resource
##     that opts into the ledger can be one.
##   - **Derived chips.** ENERGY, OXYGEN and CREW are computed from
##     [PowerManager], [AtmosphereManager] and [CrewManager]. They cannot be rows
##     in the ledger's resource list because they are not resources, so they are
##     always available and separately pinnable under [LedgerModel]'s `derived:`
##     ids.
##   - **The ledger chip.** Fixed, never pinned away, carries the tracked count.
##
## Refresh has two channels on purpose. A resource chip is repainted the moment
## its `total_changed` fires, because credits leaving the account must move the
## most-watched number on screen immediately (that is bug C13, fixed in
## [method ResourceData.force_withdraw]). Everything else - the derived chips, and
## the falling-vital treatment, which needs a rate - rides a real-time timer, for
## the same reason [ConsoleBar]'s adornments do: the console is chrome and must
## not do four times the work because the player pressed 4x.
##
## Chips are rebuilt on pin changes **only**; values update in place into a
## fixed-width tile. An HBox re-laying out because a number gained a digit is a
## real cost and a visible jitter.

## Chip captions. The three derived ids plus a fallback; a resource chip uses the
## resource's own name.
const DERIVED_CAPTIONS: Dictionary[StringName, String] = {
	LedgerModel.DERIVED_ENERGY: "Energy",
	LedgerModel.DERIVED_OXYGEN: "Oxygen",
	LedgerModel.DERIVED_CREW: "Crew",
}

const DERIVED_ICONS: Dictionary[StringName, Texture2D] = {
	LedgerModel.DERIVED_ENERGY: preload("res://ui/icons/energy.svg"),
	LedgerModel.DERIVED_OXYGEN: preload("res://ui/icons/oxygen.png"),
	LedgerModel.DERIVED_CREW: preload("res://ui/icons/console/crew.svg"),
}

## Save section id and restore order. Late: pins only need resource ids to
## resolve against, and those come from a content scan rather than from another
## section, so nothing here constrains anything else.
const SAVE_SECTION: StringName = &"vitals"
const SAVE_ORDER: int = 200

# --- tuning -------------------------------------------------------------------
# Exported rather than const because these are the numbers a playtest moves, and
# "how low is low" is a balance question (WI-52 §2).

## A resource chip goes amber when its rate is below this AND its total is at or
## under [member low_stock_threshold]. Both, not either: a big stockpile draining
## slowly is normal operation, and a small stable one is not a warning.
@export var falling_rate_per_cycle: float = -0.5
@export var low_stock_threshold: int = 25
## Station-average O2 partial (0-100) the OXYGEN chip goes amber below. Matches
## AtmosphereManager.alert_o2_partial's default so the chip and the low-oxygen
## alert agree.
@export var low_oxygen_partial: float = 40.0
## Real seconds between derived-chip refreshes. Real, not sim: the HUD does not
## speed up with the simulation.
@export var refresh_interval: float = 0.5

## Emitted when the LEDGER chip is pressed. [UIMain] owns the flyout, because the
## flyout has to sit above the console rather than inside it.
signal ledger_toggled

## Emitted after the pin list changes, so an open ledger can re-mark its rows.
signal pins_changed

var _chip_row: HBoxContainer
var _ledger_button: ActionButton

var _pins: Array[StringName] = []
var _chips: Dictionary[StringName, VitalsChip] = {}
## Resources whose `total_changed` this strip is currently connected to. Held so
## a rebuild can disconnect exactly what it connected - the signal lives on a
## shared `.tres` that outlives this node, so a missed disconnect is a call into
## a freed Control on the next scene (the WI-38 A8 family of bug).
var _connected: Array[ResourceData] = []

## Last power balance seen. Cached rather than polled because [PowerManager]
## reports it as a signal argument and has no getter for it.
var _power_desired: float = 0.0
var _power_generated: float = 0.0

func _ready() -> void:
	add_theme_constant_override("separation", UIMetrics.VITALS_CHIP_GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build_frame()
	SaveManager.register_section(SAVE_SECTION, SAVE_ORDER, get_save_data, load_save_data)
	_connect_sources()
	# The designed six until a save says otherwise. A load overwrites this one
	# deferred tick later through the section; a new game keeps it.
	_apply_pins(LedgerModel.resolve_pins([], _known_resource_ids()))

func _exit_tree() -> void:
	_disconnect_resources()

# --- frame --------------------------------------------------------------------

func _build_frame() -> void:
	_chip_row = HBoxContainer.new()
	_chip_row.name = "Chips"
	_chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_row.add_theme_constant_override("separation", UIMetrics.VITALS_CHIP_GAP)
	add_child(_chip_row)

	# The ledger chip is pinned to the right end of the zone, so the spacer takes
	# whatever width a wider display hands the console.
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	_ledger_button = ActionButton.create("Ledger", ActionButton.Weight.SECONDARY)
	_ledger_button.name = "LedgerChip"
	_ledger_button.custom_minimum_size = Vector2(
		float(UIMetrics.LEDGER_CHIP_WIDTH), float(UIMetrics.CONSOLE_TILE_HEIGHT))
	_ledger_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ledger_button.pressed.connect(ledger_toggled.emit)
	add_child(_ledger_button)

func _connect_sources() -> void:
	if Global.power_manager != null:
		Global.power_manager.power_updated.connect(_on_power_updated)
	# Everything with no signal worth subscribing to at HUD granularity - the
	# oxygen average, the crew count, the rates - rides one real-time timer.
	var timer := Timer.new()
	timer.name = "RefreshTimer"
	timer.wait_time = refresh_interval
	timer.autostart = true
	timer.timeout.connect(refresh)
	add_child(timer)

func _on_power_updated(desired: float, generated: float) -> void:
	_power_desired = desired
	_power_generated = generated

# --- pins ---------------------------------------------------------------------

## One pinned chip by id, or null when it is not on the strip. What a coach mark
## points at (WI-63); the sleep advisory's whole content is "the crew-against-
## bunks count is in the console", and pointing at it is the difference between
## that being instruction and being trivia.
func chip(id: StringName) -> VitalsChip:
	return _chips.get(id)

func pinned_ids() -> Array[StringName]:
	return _pins.duplicate()

func is_pinned(id: StringName) -> bool:
	return _pins.has(id)

func pin_count() -> int:
	return _pins.size()

func has_room_to_pin() -> bool:
	return _pins.size() < LedgerModel.PIN_CAP

## Pins or unpins `id`. Returns true when the strip changed - so a caller can tell
## "unpinned" from "refused because the strip is full" without a second query.
##
## An unpin leaves the strip one chip shorter. Deliberately **not** routed through
## [method LedgerModel.resolve_pins]: that refills from the defaults, which is
## right when a save lost an id it expected to have and wrong here, because
## unpinning one of the defaults would immediately put it back and the control
## would look broken.
##
## The cap is a refusal rather than an eviction, for the mirror-image reason:
## silently dropping whichever pin happened to be oldest would make a mis-click
## destroy a curation decision the player made deliberately.
func toggle_pin(id: StringName) -> bool:
	if _pins.has(id):
		var reduced: Array[StringName] = _pins.duplicate()
		reduced.erase(id)
		_apply_pins(reduced)
		return true
	if not has_room_to_pin():
		return false
	if not LedgerModel.can_pin(id, _known_resource_ids()):
		return false
	var grown: Array[StringName] = _pins.duplicate()
	grown.append(id)
	_apply_pins(grown)
	return true

## Rebuilds the chips to match `ids`. The only path that touches the chip row -
## everything else updates values in place.
func _apply_pins(ids: Array[StringName]) -> void:
	_pins = ids.duplicate()
	_disconnect_resources()
	for child: Node in _chip_row.get_children():
		_chip_row.remove_child(child)
		child.queue_free()
	_chips.clear()
	for id: StringName in _pins:
		var chip: VitalsChip = VitalsChip.create()
		_chip_row.add_child(chip)
		_chips[id] = chip
		if LedgerModel.is_derived(id):
			chip.configure(id, DERIVED_CAPTIONS.get(id, String(id)), DERIVED_ICONS.get(id))
			continue
		var resource: ResourceData = _resource_by_id(id)
		if resource == null:
			continue
		chip.configure(id, resource.name, resource.icon)
		# Immediate repaint on the resource's own signal - the C13 half of the
		# refresh contract. The timer would otherwise put up to half a second
		# between spending credits and the number moving.
		resource.total_changed.connect(_on_resource_total_changed.bind(resource))
		_connected.append(resource)
	_assert_fits()
	pins_changed.emit()
	refresh()

## Rebuilds the same bound [Callable] to disconnect with. `bind()` produces a
## callable that compares equal for equal arguments, so this is symmetric with
## the connect in [method _apply_pins] - the bare `_on_resource_total_changed`
## would not be, and the disconnect would silently no-op.
func _disconnect_resources() -> void:
	for resource: ResourceData in _connected:
		var handler: Callable = _on_resource_total_changed.bind(resource)
		if resource.total_changed.is_connected(handler):
			resource.total_changed.disconnect(handler)
	_connected.clear()

## The zone is a fixed reserve and the chips are what has to fit in it. Asserted
## at build time rather than only in a test, the same way [ConsoleBar] asserts its
## mode zone - the failure mode is the ledger chip sliding off the right edge,
## which is invisible until somebody screenshots it.
func _assert_fits() -> void:
	var needed: float = UIMetrics.vitals_strip_width(_pins.size())
	var available: float = UIMetrics.vitals_zone_width()
	if needed > available:
		push_warning("VitalsStrip: %d chips need %dpx but the console's flex zone has %d"
			% [_pins.size(), int(needed), int(available)])

func _known_resource_ids() -> Array[StringName]:
	if Global.resource_manager == null:
		return [] as Array[StringName]
	var ids: Array[StringName] = []
	for resource: ResourceData in Global.resource_manager.ledger_resources():
		ids.append(resource.id)
	return ids

## Through [SaveManager]'s id table rather than a scan of the ledger list: it is
## the same content scan, already indexed, and this runs once per chip per
## refresh. Anything it can resolve that is not ledger-visible was rejected by
## [method LedgerModel.can_pin] before it could become a pin.
func _resource_by_id(id: StringName) -> ResourceData:
	if Global.save_manager == null:
		return null
	return Global.save_manager.get_resource_by_id(id)

# --- values -------------------------------------------------------------------

func _on_resource_total_changed(_total: int, resource: ResourceData) -> void:
	var chip: VitalsChip = _chips.get(resource.id)
	if chip != null:
		_refresh_resource_chip(chip, resource)

## Repaints every chip and the ledger count. Cheap: at most six chips, each
## setting two strings into a fixed-size tile.
func refresh() -> void:
	for id: StringName in _chips:
		var chip: VitalsChip = _chips[id]
		if LedgerModel.is_derived(id):
			_refresh_derived_chip(id, chip)
		else:
			_refresh_resource_chip(chip, _resource_by_id(id))
	_refresh_ledger_button()

func _refresh_ledger_button() -> void:
	if _ledger_button == null:
		return
	var tracked: int = 0
	if Global.resource_manager != null:
		tracked = Global.resource_manager.ledger_resources().size()
	_ledger_button.set_label("Ledger · %d  ▸" % tracked)

func _refresh_resource_chip(chip: VitalsChip, resource: ResourceData) -> void:
	if chip == null or resource == null:
		return
	var total: int = resource.get_total()
	var rate: float = ResourceRateTracker.NO_RATE
	if Global.resource_manager != null:
		rate = Global.resource_manager.rate_per_cycle(resource)
	var falling: bool = (ResourceRateTracker.has_rate(rate)
		and rate <= falling_rate_per_cycle and total <= low_stock_threshold)
	chip.set_value(LedgerModel.format_compact(total),
		VitalsChip.FALLING_GLYPH if falling else "",
		UIPalette.Row.AMBER if falling else UIPalette.Row.INERT)

## The three computed chips. Each reads its manager live rather than caching,
## except power, which arrives as a signal argument and has no getter.
func _refresh_derived_chip(id: StringName, chip: VitalsChip) -> void:
	match id:
		LedgerModel.DERIVED_ENERGY:
			# Headroom over capacity, exactly what the retired energy_display_ui
			# showed: a negative headroom is a brownout, which is a breach-class
			# event and therefore one of amber's sanctioned spends.
			# Through `format_compact` like every resource chip, not a raw "%d"
			# (WI-58). Two fusion reactors put "3200" over "/4000" into a tile that
			# had room for neither, and a chip that outgrows its tile re-lays the
			# whole strip out - the one thing the fixed chip width exists to stop.
			var headroom: float = _power_generated - _power_desired
			chip.set_value(LedgerModel.format_compact(roundi(headroom)),
				"/" + LedgerModel.format_compact(roundi(_power_generated)),
				UIPalette.Row.AMBER if headroom < 0.0 else UIPalette.Row.INERT)
		LedgerModel.DERIVED_OXYGEN:
			var partial: float = 0.0
			if Global.atmosphere_manager != null:
				partial = Global.atmosphere_manager.station_average_o2_partial()
			# Amber is muted while the crew live in suits (WI-67): at Tier 1 a thin
			# station harms nobody, so the chip going amber is the same false alarm
			# the low-O2 alert is gated for. The number still prints - this mutes
			# the warning, not the readout - and the gate re-reads on every refresh,
			# so promotion lights it with no wiring.
			var suited: bool = Global.unlock_manager != null \
				and Global.unlock_manager.suits_mandatory()
			chip.set_value("%d%%" % roundi(partial), "",
				UIPalette.Row.AMBER if partial < low_oxygen_partial and not suited
					else UIPalette.Row.INERT)
		LedgerModel.DERIVED_CREW:
			var crew: int = 0
			var bunks: int = 0
			if Global.crew_manager != null:
				crew = Global.crew_manager.crew_count()
				bunks = Global.crew_manager.sleep_capacity()
			# Amber when somebody has nowhere to sleep. That is a real early
			# warning (unrested crew resign) and it is the only crew state the
			# player can act on from a glance.
			chip.set_value(LedgerModel.format_compact(crew),
				"/" + LedgerModel.format_compact(bunks),
				UIPalette.Row.AMBER if crew > bunks else UIPalette.Row.INERT)

# --- persistence --------------------------------------------------------------

## The curated strip is a player decision, not derived state, so it saves (the
## WI-45 rule). Ids, never indices or paths.
##
## One ordered list rather than the two the WI sketched (`pinned` + `derived`):
## the strip's *order* is part of what the player chose, and two lists cannot
## express a derived chip sitting between two resource chips. Derived entries
## carry [constant LedgerModel.DERIVED_PREFIX], which no resource id can collide
## with - base-game ids are hand-authored and a mod's must begin with its own
## `modid.` prefix.
func get_save_data() -> Dictionary:
	var ids: Array[String] = []
	for id: StringName in _pins:
		ids.append(String(id))
	return {"pins": ids}

## Absent key = the designed default six, which is what makes a pre-WI-52 save
## load correctly without moving SAVE_VERSION. An id that no longer resolves is
## dropped with a warning and the strip refills from the defaults rather than
## rendering a gap - see [method LedgerModel.resolve_pins].
func load_save_data(data: Dictionary) -> void:
	var saved: Array = data.get("pins", [])
	_apply_pins(LedgerModel.resolve_pins(saved, _known_resource_ids()))
