class_name AlertManager
extends Node

## Owns the live alert queue, the history log and the critical-alert pause latch
## (WI-53).
##
## This is the one item in the UI rework with real gameplay consequence.
## Everything else in the program changes how things look; this changes what the
## game does to you - a CRITICAL alert holds the simulation stopped until the
## player clicks it.
##
## Three tiers, and importance is enforced rather than merely styled:
##
##   - **LOW** is transient. Someone is hungry; it fades after fifteen wall-clock
##     seconds, exactly as the strip this replaces did.
##   - **HIGH** is sticky. It stays in the feed until the player clicks it, which
##     is the tier that earns most of this item's value and carries none of its
##     risk.
##   - **CRITICAL** additionally holds the sim. Deliberately tiny: the test for
##     membership is "the player will lose something irreversible if they are
##     looking away", and if more than one or two fire in twenty minutes at 4x
##     the classification is wrong.
##
## **The legacy signal stays.** `SignalBus.station_alert(message: String)` has
## fifty-odd emit sites and this manager subscribes to it, wrapping each message
## as a LOW alert with no subject. That is the difference between an item that
## can ship and one that cannot: every site keeps working from day one, the ones
## that deserve a higher tier were migrated deliberately (WI-53 §4), and a mod
## (WI-47) emitting the old signal still gets an alert. It is not deprecated on a
## timetable - "something happened, mention it" is genuinely what most sites mean.
##
## The classification *rules* are [AlertRules], which is pure and tested; this
## node is the state and the wiring.
##
## ## Transmissions (WI-57)
##
## This manager also owns the [TransmissionLog], on the WI's own "one owner for
## things that arrived" reading. The two lists stay sharply distinct - an alert is
## "look at this now", a transmission is "this arrived and you can read it later",
## a hull breach is never a transmission and a contract offer is both - but they
## are raised **together, by one helper** ([method transmit]) rather than at
## twenty separate call sites, which is the only way the durable half stays in
## step with the transient one.

## The alert history's save section. Late: it depends on nothing and nothing
## depends on it, and it must restore after the calendar so a stamp reads right.
const SAVE_SECTION: StringName = &"alerts"
const SAVE_ORDER: int = 210

## The transmission log's own section, beside the alert log for the same reasons.
## Absent key = an empty log, so a pre-WI-57 save loads and `SAVE_VERSION` stays
## put.
const TRANSMISSION_SECTION: StringName = &"transmissions"
const TRANSMISSION_ORDER: int = 215

## This manager's entry in [TimeManager]'s hold set. One hold for the whole
## queue, not one per alert: three simultaneous criticals stop the sim once and
## release it when the last of them is acknowledged.
const PAUSE_HOLD: StringName = &"critical_alert"

## Master switch for the intrusive half. Left as one property rather than making
## every caller decide, because the Phase-4 tutorial/onboarding item will want to
## suppress the pause without suppressing the alerts.
@export var pause_on_critical: bool = true

## How long a LOW alert survives, in real seconds. Exported because it is the
## number a playtest moves.
@export var low_ttl_seconds: float = AlertRules.LOW_TTL_SECONDS

## Real seconds between age-out sweeps. Real, not `slow_tick`: a transient alert
## is a UI affordance and must not last four times longer because the player
## dropped to 0.5x.
@export var sweep_interval: float = 1.0

## Live alerts, unordered. [method AlertRules.order] is what the feed renders.
var _live: Array[AlertData] = []
## The same alerts by id, so a repeat is an O(1) refresh rather than a scan.
var _by_id: Dictionary[StringName, AlertData] = {}
## HIGH and CRITICAL alerts, newest first, bounded and saved.
var _history: Array[AlertData] = []
## Everything that arrived and can be read later (WI-57). Pure and tested; this
## node only owns it, saves it, and announces that it moved.
var transmissions: TransmissionLog = TransmissionLog.new()
## Monotonic raise counter - the recency tiebreak, see [member AlertData.sequence].
var _sequence: int = 0
## Whether this manager currently holds the sim.
var _pause_held: bool = false
## False until [signal SignalBus.game_bootstrapped]. Alerts raised before the
## world is up cannot pause, for the same reason alerts raised during a load
## cannot: a game the player has not seen yet must not open on a modal.
var _armed: bool = false

func _ready() -> void:
	Global.alert_manager = self
	SaveManager.register_section(SAVE_SECTION, SAVE_ORDER, get_save_data, load_save_data, {})
	SaveManager.register_section(TRANSMISSION_SECTION, TRANSMISSION_ORDER,
		get_transmission_save_data, load_transmission_save_data, {})
	_connect_sources()
	var timer := Timer.new()
	timer.name = "SweepTimer"
	timer.wait_time = sweep_interval
	timer.autostart = true
	timer.timeout.connect(sweep)
	add_child(timer)

func _exit_tree() -> void:
	# A scene swap frees this node while it may still be holding the sim. The
	# TimeManager goes with it, so this is belt-and-braces - but a manager that
	# can stop the game must not be able to leave it stopped.
	_release_pause()

# --- the static entry point -----------------------------------------------------

## Raises an alert from anywhere, without the caller having to reach for
## [Global] or null-check the manager.
##
## This is the shape every migrated emit site uses:
## `AlertManager.raise_alert(AlertRules.make_id(&"breach", module),
## AlertData.Priority.CRITICAL, "Hull breach", "Reactor Hall · seals in 1.5h",
## module)`.
##
## With no manager in the tree (a GUT suite, a headless probe that skipped the
## scene) it falls back to the legacy signal, so the message is still announced
## and nothing silently swallows it.
static func raise_alert(id: StringName, priority: AlertData.Priority, title: String,
		detail: String = "", subject: Variant = null, route: StringName = &"",
		group_title: String = "") -> AlertData:
	var manager: AlertManager = Global.alert_manager
	if manager == null or not is_instance_valid(manager):
		SignalBus.station_alert.emit(title if detail.is_empty() else "%s - %s" % [title, detail])
		return null
	return manager.raise(id, priority, title, detail, subject, route, group_title)

## Drops the live alert `id`, if it is still up - the "the condition ended"
## path. A sealed breach, a departed trader, a cancelled resignation.
##
## Distinct from acknowledgement on purpose: the player never saw this one and
## it leaves no acknowledged mark, but the history entry it already wrote stays.
static func resolve_alert(id: StringName) -> void:
	var manager: AlertManager = Global.alert_manager
	if manager != null and is_instance_valid(manager):
		manager.resolve(id)

# --- transmissions (WI-57) ------------------------------------------------------

## Raises an alert **and** posts the durable transmission behind it, in one call.
##
## This is the helper WI-57 §3 asks for, and the reason it exists is arithmetic:
## the alternative is twenty call sites each remembering to do both, and the first
## one that forgets produces a notification the player can miss forever. A caller
## that wants only the transient half still calls [method raise_alert]; a hull
## breach must never come through here.
##
## The first four arguments are the alert's, unchanged from [method raise_alert],
## so a converted call site keeps the row it already had. The rest are the
## transmission's, and only two of them are new information:
##
##   - `family` - what kind of thing arrived, for the row's avatar slot;
##   - `sender` - who it is from, which becomes the row's **name** column where an
##     alert row carries the title;
##   - `body` - the long form, revealed when the row is expanded. Empty falls back
##     to the subject line, so a caller with nothing more to say may omit it.
##
## The transmission's one-line subject **is** the alert's `title`, deliberately
## rather than a tenth parameter: it is the same sentence, and a signature that
## let a caller give the two lists different words is a signature that eventually
## would.
##
## Returns the alert, matching [method raise_alert], because that is the half a
## caller occasionally wants to adjust afterwards.
static func transmit(id: StringName, priority: AlertData.Priority, title: String, detail: String,
		family: StringName, sender: String, body: String = "", route: StringName = &"",
		subject_ref: Variant = null, group_title: String = "") -> AlertData:
	var manager: AlertManager = Global.alert_manager
	if manager != null and is_instance_valid(manager):
		manager.post_transmission(family, sender, title, body, route, subject_ref)
	return raise_alert(id, priority, title, detail, subject_ref, route, group_title)

## Posts a transmission without raising an alert - for something that arrived and
## genuinely does not warrant interrupting anyone. Rare on purpose: if it is worth
## logging it is usually worth a LOW alert, which is free.
func post_transmission(family: StringName, sender: String, subject: String,
		body: String = "", route: StringName = &"",
		subject_ref: Variant = null) -> TransmissionData:
	var cycle: int = Global.time_manager.cycle if Global.time_manager != null else 0
	var hour: int = Global.time_manager.hour if Global.time_manager != null else 0
	var entry: TransmissionData = transmissions.post(
		family, sender, subject, body, cycle, hour, route, subject_ref)
	SignalBus.transmissions_changed.emit()
	return entry

## `MARK ALL READ`. Non-destructive - it zeroes the badge and deletes nothing.
func mark_transmissions_read() -> void:
	if transmissions.mark_all_read():
		SignalBus.transmissions_changed.emit()

## Marks one entry read - what expanding a row does.
func mark_transmission_read(entry: TransmissionData) -> void:
	if transmissions.mark_read(entry):
		SignalBus.transmissions_changed.emit()

## The console's COMMS badge.
func unread_transmissions() -> int:
	return transmissions.unread_count()

# --- raising --------------------------------------------------------------------

## Raises or refreshes the alert `id`. Returns the record, so a caller can set
## the fields this signature does not carry.
##
## A repeat **refreshes rather than stacks**: the row moves to the top with a new
## timestamp and a bumped count, which is why the id has to include the subject
## (two modules breaching are two alerts; one module breaching twice is one).
func raise(id: StringName, priority: AlertData.Priority, title: String,
		detail: String = "", subject: Variant = null, route: StringName = &"",
		group_title: String = "") -> AlertData:
	if id == &"":
		push_warning("AlertManager: refusing an alert with no id (\"%s\")" % title)
		return null
	var existing: AlertData = _by_id.get(id)
	var alert: AlertData = existing
	if alert == null:
		alert = AlertData.create(id, priority, title, detail, subject, route)
		_live.append(alert)
		_by_id[id] = alert
	else:
		alert.count += 1
		# A repeat may escalate but never de-escalates: a module that was merely
		# low on oxygen and is now breached must not have its row quietened, and
		# an already-acknowledged critical must not re-arm the pause (it is only
		# still here because something re-raised it, and the player has read it).
		if int(priority) > int(alert.priority):
			alert.priority = priority
		alert.title = title
		alert.detail = detail
		alert.subject = subject
		alert.route = route
	alert.group_title = group_title
	_sequence += 1
	alert.sequence = _sequence
	alert.raised_at = _now()
	if Global.time_manager != null:
		alert.cycle = Global.time_manager.cycle
		alert.hour = Global.time_manager.hour
	# Latched, never cleared: an alert that was not allowed to pause when it was
	# raised must not become allowed to when the next one arrives.
	if not _pause_allowed():
		alert.suppress_pause = true
	if existing == null:
		_log(alert)
	SignalBus.station_alert_raised.emit(alert)
	_changed()
	return alert

## Whether an alert raised *right now* may hold the sim.
##
## Two gates, and each is a way a load becomes hateful. [SaveManager] applies a
## pending load deferred and restores a whole in-progress raid; a critical alert
## fired during that restoration would pause a game the player has not seen. The
## same gate covers a breach that was still open when the save was written -
## [AtmosphereComponent] re-announces it on its next tick, and it must not be a
## modal on the loading screen.
func _pause_allowed() -> bool:
	return _armed and not SaveManager.is_loading()

# --- acknowledging & clearing ---------------------------------------------------

## Marks `alert` read and takes it out of the feed. This is what a click on the
## row does, and for a CRITICAL it is what releases the pause.
##
## **Esc deliberately cannot do this.** The player hammers Esc, and an
## acknowledgement Esc can satisfy is one that gets satisfied without being read.
## This is a considered exception to the "Esc is always an exit" invariant
## (WI-36) and [UIMain]'s Esc ladder says so at the code.
func acknowledge(alert: AlertData) -> void:
	if alert == null or not _by_id.has(alert.id):
		return
	alert.acknowledged = true
	_drop(alert)
	_changed()

## Acknowledges every member of a coalesced row. A group row is all-or-nothing:
## the six pawns behind "6 crew have fallen ill" were never individually visible,
## so dismissing five of them would leave a row the player cannot explain.
func acknowledge_group(group: AlertRules.Group) -> void:
	if group == null:
		return
	for alert: AlertData in group.members:
		if alert.acknowledged or not _by_id.has(alert.id):
			continue
		alert.acknowledged = true
		_drop(alert)
	_changed()

## `CLEAR ALL`. Non-destructive precisely because history exists, which is what
## makes players willing to use it instead of letting forty rows pile up - and it
## leaves outstanding criticals alone, because a clear that can dismiss a
## game-pausing alert defeats the tier.
func clear_dismissible() -> void:
	for alert: AlertData in _live.duplicate():
		if AlertRules.is_clearable(alert):
			alert.acknowledged = true
			_drop(alert)
	_changed()

## See [method resolve_alert].
func resolve(id: StringName) -> void:
	var alert: AlertData = _by_id.get(id)
	if alert == null:
		return
	_drop(alert)
	_changed()

## Ages out the expired LOW alerts. On a real-time timer; see [member sweep_interval].
func sweep() -> void:
	var stale: Array[AlertData] = AlertRules.expired(_live, _now(), low_ttl_seconds)
	if stale.is_empty():
		return
	for alert: AlertData in stale:
		_drop(alert)
	_changed()

func _drop(alert: AlertData) -> void:
	_live.erase(alert)
	_by_id.erase(alert.id)

# --- reads ----------------------------------------------------------------------

## The live alerts, unordered. Callers render through [method AlertRules.group].
func live() -> Array[AlertData]:
	return _live.duplicate()

## The history log, newest first.
func history() -> Array[AlertData]:
	return _history.duplicate()

func outstanding_count() -> int:
	return AlertRules.outstanding_count(_live)

func has_outstanding_critical() -> bool:
	return outstanding_count() > 0

func is_holding_pause() -> bool:
	return _pause_held

func find(id: StringName) -> AlertData:
	return _by_id.get(id)

# --- history --------------------------------------------------------------------

## Writes an alert into the log, newest first. LOW never gets here (it was
## designed to be missable and logging it would bury the rest); nor does a cheat
## message, whatever tier it was raised at, because `Cheats.fire_alert` exists
## precisely to raise criticals on demand and a log full of them is useless.
func _log(alert: AlertData) -> void:
	if not AlertRules.is_logged(alert.priority) or AlertRules.is_cheat(alert.title):
		return
	_history.push_front(alert)
	_history = AlertRules.trim_history(_history)

# --- the pause latch ------------------------------------------------------------

## One place decides whether the sim is held, re-derived from the queue rather
## than incremented and decremented - so no acknowledge path can leak a hold.
func _update_pause() -> void:
	var wanted: bool = pause_on_critical and AlertRules.any_holds_pause(_live)
	if wanted == _pause_held:
		return
	if wanted:
		_pause_held = true
		if Global.time_manager != null:
			Global.time_manager.hold_pause(PAUSE_HOLD)
		return
	_release_pause()

func _release_pause() -> void:
	if not _pause_held:
		return
	_pause_held = false
	if Global.time_manager != null and is_instance_valid(Global.time_manager):
		Global.time_manager.release_pause(PAUSE_HOLD)

## The single "the queue moved" path: re-derive the pause, then tell the feed.
## In that order, so a handler that reads the pause state during the refresh sees
## the settled answer.
func _changed() -> void:
	_update_pause()
	SignalBus.alerts_changed.emit()

## Wall-clock seconds. Alerts are stamped in sim cycles and hours (game facts)
## and aged on wall-clock (a UI affordance). Both are correct; they are not
## unified.
func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

# --- sources --------------------------------------------------------------------

## Everything that produces an alert without going through [method raise].
##
## The five signals here are the ones `ui_main.gd` used to handle itself, plus
## the three that *resolve* an alert - which is knowledge that belongs in one
## place rather than at each emit site.
func _connect_sources() -> void:
	SignalBus.station_alert.connect(_on_station_alert)
	SignalBus.pawn_critical_need.connect(_on_pawn_critical_need)
	SignalBus.crew_resigning.connect(_on_crew_resigning)
	SignalBus.crew_resignation_cancelled.connect(_on_crew_resignation_cancelled)
	SignalBus.crew_departed.connect(_on_crew_departed)
	SignalBus.trader_arrived.connect(_on_trader_arrived)
	SignalBus.trader_departed.connect(_on_trader_departed)
	SignalBus.module_breach_sealed.connect(_on_breach_sealed)
	SignalBus.module_destroyed.connect(_on_module_destroyed)
	SignalBus.raid_ended.connect(_on_raid_ended)
	SignalBus.game_bootstrapped.connect(_on_game_bootstrapped)

## The world is up. Anything raised before this point (a manager complaining
## during its own `_ready`, a restored breach) was recorded but could not pause.
func _on_game_bootstrapped() -> void:
	_armed = true

## The legacy shim. Every unmigrated site lands here at LOW, keyed on its own
## message - which is exactly the dedupe the old strip did.
func _on_station_alert(message: String) -> void:
	raise(StringName(message), AlertData.Priority.LOW, message)

func _pawn_label(pawn: PawnBase) -> String:
	if pawn == null or not is_instance_valid(pawn):
		return "A crew member"
	return pawn.pawn_name if not pawn.pawn_name.is_empty() else "A crew member"

## Edge-triggered by the needs component's `was_critical` latch, so this is one
## alert per episode rather than one per tick.
func _on_pawn_critical_need(pawn: PawnBase, need: StringName) -> void:
	var label: String = String(need)
	raise(AlertRules.make_id(StringName("need_%s" % need), pawn), AlertData.Priority.HIGH,
		"%s critical" % label.capitalize(), _pawn_label(pawn), pawn, &"crew",
		"%%d crew have critical %s" % label)

## CRITICAL: an irreversible departure with a grace window the player can still
## act inside.
func _on_crew_resigning(pawn: PawnBase, grace_hours: float) -> void:
	raise(AlertRules.make_id(&"resigning", pawn), AlertData.Priority.CRITICAL,
		"Crew resigning", "%s · leaves in %dh" % [_pawn_label(pawn), int(grace_hours)],
		pawn, &"crew", "%d crew are resigning")

func _on_crew_resignation_cancelled(pawn: PawnBase) -> void:
	resolve(AlertRules.make_id(&"resigning", pawn))
	raise(AlertRules.make_id(&"stayed", pawn), AlertData.Priority.LOW,
		"Resignation withdrawn", "%s decided to stay" % _pawn_label(pawn), pawn)

func _on_crew_departed(pawn: PawnBase) -> void:
	resolve(AlertRules.make_id(&"resigning", pawn))
	raise(AlertRules.make_id(&"departed", pawn), AlertData.Priority.LOW,
		"Crew departed", "%s has left the station" % _pawn_label(pawn))

## WI-50 dropped the trader screen's auto-open: under exclusive mounting, an
## incoming trader force-closing the player's open Build panel mid-placement is
## hostile. This is the alert that replaced it, and its subject is the docking
## bay - so the row's JUMP lands on the thing the player has to click anyway.
##
## Both halves since WI-57. A visit is durable news - it happened, it had a
## trader's name on it, and a player who was mid-build when it docked should be
## able to find out later who came. **The repeats do not collapse**: the same
## caravan arriving on five cycles is five rows in the log, where it is one
## refreshed row in the feed, which is the difference between the two lists.
func _on_trader_arrived(trader: TraderData) -> void:
	var bay: ModuleBase = _docking_bay()
	# The instance methods rather than the static [method transmit]: this is the
	# manager, so routing back out through `Global.alert_manager` to reach itself
	# would only add a way for the call to go somewhere else.
	post_transmission(&"trader", trader.trader_name, "Trader docked",
		"We are alongside and open for business. Set your orders before we cast off.",
		&"trade", bay)
	raise(&"trader_docked", AlertData.Priority.HIGH, "Trader docked",
		"%s · open the docking bay to trade" % trader.trader_name, bay)

func _on_trader_departed(trader: TraderData) -> void:
	resolve(&"trader_docked")
	raise(&"trader_departed", AlertData.Priority.LOW, "Trader departed",
		"%s has left" % trader.trader_name)

func _docking_bay() -> ModuleBase:
	if Global.trader_manager == null:
		return null
	var trade: TradeComponent = Global.trader_manager.active_bay_trade_component()
	return trade.owner_module if trade != null else null

## The condition ended, so the alert goes - whether or not it was ever read.
func _on_breach_sealed(module: ModuleBase) -> void:
	resolve(AlertRules.make_id(&"breach", module))

## A destroyed module's problems are no longer problems, and the destruction is
## the news. This is the one case that overrides "never drop an alert because its
## subject went away": the rule exists so a *live* condition cannot vanish
## unread, and a module that no longer exists has no live condition - leaving an
## outstanding CRITICAL about a breach in something that has already been
## replaced by truss would hold the sim on a fact that has stopped being true.
##
## Fired just before `remove_module` tears the module down, so the ids still
## resolve.
func _on_module_destroyed(module: ModuleBase) -> void:
	for family: StringName in [&"breach", &"low_o2", &"breakdown", &"cut_vertex"]:
		resolve(AlertRules.make_id(family, module))

func _on_raid_ended(_outcome: StringName) -> void:
	resolve(&"raid")

# --- persistence ----------------------------------------------------------------

## Only the history log is saved.
##
## The WI sketched a second `outstanding` block, and it turns out to be the same
## rows twice: an alert is logged the moment it is raised, so every outstanding
## HIGH or CRITICAL is *already* a history entry and restoring both would need a
## de-duplication pass to avoid printing each one twice.
##
## Live alerts are therefore not restored at all, which is also the safe reading
## of §8: a loaded save must not open on a pause modal, and everything that is
## still true gets re-raised by the system that owns it (a breach is still
## breached, and [AtmosphereComponent] says so on its next tick). What the player
## loses is a row for a condition that has since resolved itself, which is a row
## that should not have been there anyway.
func get_save_data() -> Dictionary:
	var entries: Array[Dictionary] = []
	for alert: AlertData in _history:
		entries.append(alert.to_dict())
	return {"history": entries}

## Absent key = an empty log, which is what makes a pre-WI-53 save load without
## moving SAVE_VERSION.
func load_save_data(data: Dictionary) -> void:
	_history.clear()
	for entry: Variant in data.get("history", []):
		var record: Dictionary = entry as Dictionary
		if record == null:
			continue
		_history.append(AlertData.from_dict(record))
	_history = AlertRules.trim_history(_history)
	SignalBus.alerts_changed.emit()

## The transmission log's section (WI-57). Separate from the alert history's on
## purpose: the two lists have different lifetimes and different rules, and a
## single blob would make "absent key = empty" ambiguous between them.
func get_transmission_save_data() -> Dictionary:
	return transmissions.to_save()

func load_transmission_save_data(data: Dictionary) -> void:
	transmissions.load_save(data)
	SignalBus.transmissions_changed.emit()
