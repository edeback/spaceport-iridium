class_name HeatManager
extends Node

## The station's thermal network (WI-60): attaches a [HeatComponent] to every
## module on the structure graph, conducts heat between physically attached
## modules, and bleeds it to space through exposed faces.
##
## This is shaped like [AtmosphereManager], not like [AdjacencyManager], and the
## difference is the whole design. Adjacency fields are pure derived state -
## recomputed from scratch on every topology change and never saved - which works
## because a field level is a closed-form sum over its sources. A temperature is
## nothing but memory: a forge shut off an hour ago leaves a warm room. So heat
## is stored, ticked, and saved, exactly as gas is.
##
## Three deliberate differences from atmosphere:
##   - it conducts over the STRUCTURE relation (physical attachment), not the
##     path graph, because heat moves through plating rather than through doors.
##     That is also what lets a Radiator - no interior, no atmosphere, bolted to
##     the outside - be part of the network at all, and what makes truss conduct.
##   - EVERY module gets a thermal body, with no opt-in flag, so a modded module
##     joins for free.
##   - the sink is every exposed face, continuously, rather than only a breach.
##
## Every formula lives in the pure [HeatMath]; this class owns the pass.

## One exchange pass finished. Repaint signal for the inspector - deliberately
## NOT per-module (temperatures move on every module every pass, so a per-module
## signal over a few hundred modules would be pure spam).
signal heat_pass_completed

## Fraction of the way to pairwise equilibrium per game-hour. An order of
## magnitude below atmosphere's diffusion rate on purpose: air moves, steel does
## not, and the design asks for "hours, not cycles".
@export var conduction_rate_per_hour: float = 1.5
## Energy shed per degree above space, per unit of exposed face, per game-hour.
## The master knob for how punishing heat is - it scales the whole curve, and is
## the lever to reach for before touching the exposure floor or the habitable band.
@export var radiation_coefficient: float = 0.35
## What a fully exposed, unheated module tends toward. A balance knob, not
## physics - see HeatMath.DEFAULT_SPACE_TEMPERATURE_F, which this initialises
## from so the pure default and the tunable one cannot drift.
@export var space_temperature_f: float = HeatMath.DEFAULT_SPACE_TEMPERATURE_F
## Game-hours between exchange passes.
##
## The one place this deliberately diverges from atmosphere's tick shape.
## slow_tick fires at 4 Hz SIM-time, which at SECONDS_PER_HOUR = 10 is forty
## ticks per game-hour, and heat covers every module rather than only the
## pressurised ones. A process measured in hours does not need 4 Hz resolution,
## and the accumulator buys a ~40x reduction in pass count for no observable
## difference. The relaxation math is step-size independent, so this is a pure
## performance knob.
@export var pass_interval_hours: float = 0.25

var _components: Dictionary[ModuleBase, HeatComponent] = {}
## Built emitters currently producing. A module may host more than one.
var _emitters: Array[HeatEmitterComponent] = []
## Sim-hours banked toward the next pass.
var _hours_since_pass: float = 0.0
## Components registered this frame that still need a starting temperature.
## Deferred because a module's structural connections are formed AFTER its
## components ready (ModuleBase.ready_constructed calls make_connections last),
## so at registration time a fresh build does not yet know its neighbours.
var _seed_queue: Array[HeatComponent] = []
var _seed_queued: bool = false

func _ready() -> void:
	Global.heat_manager = self
	SignalBus.module_added.connect(_on_module_added)
	Global.time_manager.slow_tick.connect(_on_slow_tick)

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.heat_manager)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.heat_manager == self:
		Global.heat_manager = null

## Attach to anything that sits on the structure graph - which is everything the
## player places, truss and exterior hardware included. One eligibility rule in
## one place (the WI-17 pattern); a module never opts in, so a modded one is in
## the network for nothing. Runs for previews too: the component stays inert
## (unregistered) until ready_constructed.
func _on_module_added(module: ModuleBase) -> void:
	if module == null or module.get_structure_component() == null:
		return
	if module.get_component_by_type(HeatComponent) != null:
		return
	var component := HeatComponent.new()
	component.name = "HeatComponent"
	component.owner_module = module
	module.add_child(component)

# --- registration -------------------------------------------------------------

func register_component(component: HeatComponent) -> void:
	if component == null or component.owner_module == null:
		return
	_components[component.owner_module] = component
	_queue_seed(component)

func unregister_component(component: HeatComponent) -> void:
	if component.owner_module != null and _components.get(component.owner_module) == component:
		_components.erase(component.owner_module)

func get_component(module: ModuleBase) -> HeatComponent:
	return _components.get(module)

## The temperature at `module`, or the neutral seed for anything with no thermal
## body (an unbuilt blueprint, a module mid-teardown). Consumers call this rather
## than reaching for the component.
func temperature_at(module: ModuleBase) -> float:
	var component: HeatComponent = _components.get(module)
	return component.temperature_f if component != null else HeatMath.NEUTRAL_TEMPERATURE_F

## Called by a HeatEmitterComponent when its module finishes construction.
func register_emitter(emitter: HeatEmitterComponent) -> void:
	if emitter == null or _emitters.has(emitter):
		return
	_emitters.append(emitter)

func unregister_emitter(emitter: HeatEmitterComponent) -> void:
	_emitters.erase(emitter)

# --- seeding ------------------------------------------------------------------

func _queue_seed(component: HeatComponent) -> void:
	_seed_queue.append(component)
	if _seed_queued:
		return
	_seed_queued = true
	_flush_seeds.call_deferred()

## Give every freshly registered component a starting temperature.
##
## A new module seeds at the mean of its already-registered structural
## neighbours: its plating was manufactured on a station that is already at that
## temperature. Energy is not conserved at that instant, and that is correct -
## placing a module ADDS mass to the station, it is not a leak. The alternative
## (start at space temperature) means every corridor you add briefly chills the
## block it was added to, which is a nuisance with no gameplay in it.
##
## With no registered neighbours it falls back to the neutral, habitable seed
## rather than to space temperature. That case is reachable exactly twice - the
## first module of a new game, and a save written before this system existed -
## and BOTH want a habitable station. Seeding those at space temperature would
## start a new game, and every existing save, with the crew freezing to death.
##
## A component whose temperature came out of a save file is skipped: load_save_data
## runs before this deferred flush, and clobbering it would discard the save.
func _flush_seeds() -> void:
	_seed_queued = false
	var queue: Array[HeatComponent] = _seed_queue
	_seed_queue = []
	for component: HeatComponent in queue:
		if not is_instance_valid(component) or component.temperature_is_known():
			continue
		component.temperature_f = _neighbour_mean(component)
		component.mark_temperature_known()
		component.refresh_throttle()

func _neighbour_mean(component: HeatComponent) -> float:
	var total: float = 0.0
	var count: int = 0
	for neighbour: HeatComponent in _neighbours(component):
		if neighbour.temperature_is_known():
			total += neighbour.temperature_f
			count += 1
	if count == 0:
		return HeatMath.NEUTRAL_TEMPERATURE_F
	return total / float(count)

## The registered thermal bodies physically attached to this one.
##
## Read off StructureComponent.module_connections rather than out of
## StructureManager's graph: that dictionary IS the physical-attachment relation
## (the graph is built from the same signals), it is symmetric by construction,
## and going direct keeps this manager independent of the graph's internals.
## Cross-layer connections count - a corridor sharing a cell with a module is in
## contact with it, whatever layer the two live on.
func _neighbours(component: HeatComponent) -> Array[HeatComponent]:
	var out: Array[HeatComponent] = []
	var module: ModuleBase = component.owner_module
	if module == null or not is_instance_valid(module):
		return out
	var structure: StructureComponent = module.get_structure_component()
	if structure == null:
		return out
	# Through `keys()`, with the guard OUTSIDE the indexing (WI-71 §3). Iterating
	# a `Dictionary[ModuleBase, ...]` directly errors inside `next()` on a freed
	# key, before any guard in the body can run - so the guard this used to
	# carry was dead code. `keys()` is the one accessor that hands a freed key
	# back without complaining. The dictionary belongs to [StructureComponent],
	# whose own pairing keeps it clean; this is the reader that must not depend
	# on that holding.
	for key: Variant in structure.module_connections.keys():
		if not is_instance_valid(key):
			continue
		var neighbour: ModuleBase = key as ModuleBase
		if neighbour == null:
			continue
		var other: HeatComponent = _components.get(neighbour)
		if other != null:
			out.append(other)
	return out

# --- the pass -----------------------------------------------------------------

func _on_slow_tick(interval: float) -> void:
	_hours_since_pass += interval / TimeManager.SECONDS_PER_HOUR
	if _hours_since_pass < pass_interval_hours:
		return
	var hours: float = _hours_since_pass
	_hours_since_pass = 0.0
	run_pass(hours)

## One exchange pass over `hours` of game time. Public so the cheat console and
## the verification probe can drive it deterministically.
func run_pass(hours: float) -> void:
	if hours <= 0.0:
		return
	_conduct(hours)
	_produce(hours)
	_radiate(hours)
	for component: HeatComponent in _components.values():
		component.refresh_throttle()
	heat_pass_completed.emit()

## Pairwise conduction between physically attached modules. Symmetric and
## exactly energy-conserving (HeatMath.exchange_flow's reduced-mass form), with
## the step clamped at 1.0 so a pass can never overshoot equilibrium however
## large the interval.
func _conduct(hours: float) -> void:
	var step: float = minf(conduction_rate_per_hour * hours, 1.0)
	if step <= 0.0:
		return
	for module: ModuleBase in _components:
		var component: HeatComponent = _components[module]
		for other: HeatComponent in _neighbours(component):
			# Attachment is symmetric, so process each unordered pair once - the
			# same module_id comparison AtmosphereManager uses.
			if other.owner_module == null or other.owner_module.module_id <= module.module_id:
				continue
			var flow: float = HeatMath.exchange_flow(
				component.temperature_f, component.thermal_mass(),
				other.temperature_f, other.thermal_mass(), step)
			component.add_energy(-flow)
			other.add_energy(flow)

func _produce(hours: float) -> void:
	# Purge emitters whose module was freed without unregistering (defensive, the
	# AdjacencyManager pattern).
	_emitters = _emitters.filter(func(e: HeatEmitterComponent) -> bool:
		return is_instance_valid(e) and is_instance_valid(e.owner_module))
	for emitter: HeatEmitterComponent in _emitters:
		var component: HeatComponent = _components.get(emitter.owner_module)
		if component == null:
			continue
		component.add_energy(emitter.take_energy(hours))

func _radiate(hours: float) -> void:
	for component: HeatComponent in _components.values():
		var loss: float = HeatMath.space_loss(component.temperature_f, space_temperature_f,
			component.exposure(), radiation_coefficient * component.radiation_multiplier(),
			component.thermal_mass(), hours)
		component.add_energy(-loss)

# --- debug --------------------------------------------------------------------

## Console/debug helper (Cheats.dump_heat): one line per module, plus the totals
## that make an equilibrium claim checkable by eye.
func debug_dump() -> String:
	var lines: Array[String] = []
	var total_energy: float = 0.0
	for module: ModuleBase in _components:
		var component: HeatComponent = _components[module]
		var module_name: String = module.module_data.name if module.module_data != null else module.name
		var throttle: float = component.throttle_penalty()
		lines.append("%s (id %d): %s | mass %.1f | exposure %.2f | radiate x%.1f%s" % [
			module_name, module.module_id, HeatMath.format_temperature(component.temperature_f),
			component.thermal_mass(), component.exposure(), component.radiation_multiplier(),
			" | THROTTLED -%d%%" % int(round(throttle * 100.0)) if throttle > 0.0 else ""])
		total_energy += component.energy_above(space_temperature_f)
	lines.append("TOTAL: %d bodies, %.0f energy above space (%s)" % [
		_components.size(), total_energy, HeatMath.format_temperature(space_temperature_f)])
	return "\n".join(lines)
