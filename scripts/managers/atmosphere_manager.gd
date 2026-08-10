class_name AtmosphereManager
extends Node

## Life support (WI-17): attaches an AtmosphereComponent to every eligible
## module and runs gas diffusion between connected modules on the sim's
## slow tick. Eligibility (has a PathComponent, non-SPACE layer - i.e. pawns
## can be inside it) is decided here once instead of per-scene; truss and
## exterior hardware never qualify.
##
## Adjacency reuses PathManager's traversal graph: door edges between two
## registered built modules exchange gas pairwise, and turbolift-shaft group
## cliques equalize as a shared plenum. Exterior-flagged vertices
## (deconstruction sites) and space never exchange - the only path to space
## is a hull breach, which the component vents itself.

## Fraction of the way to pairwise equilibrium per game-hour (exponential).
## 2.5 means a fresh vacuum module reaches ~90% of its neighbors' pressure
## within a game-hour - "fairly quick", no player-built ducting.
@export var diffusion_rate_per_hour: float = 25
## Station alert fires when a module's O2 partial drops below this...
@export var alert_o2_partial: float = 40.0
## ...and re-arms once it recovers above alert + margin (no alert spam).
@export var alert_rearm_margin: float = 5.0
## UI panel scene handed to runtime-attached components.
@export var atmosphere_ui_scene: PackedScene

var _components: Dictionary[ModuleBase, AtmosphereComponent] = {}
## Modules currently latched in the low-O2 alert state. Not saved (WI-45 A7):
## the latch only suppresses a repeat alert, so a load costs one duplicate
## warning about a room that is genuinely still low on O2.
var _low_o2_alerted: Dictionary[ModuleBase, bool] = {}

func _ready() -> void:
	Global.atmosphere_manager = self
	SignalBus.module_added.connect(_on_module_added)
	Global.time_manager.slow_tick.connect(_on_slow_tick)

## Attach to anything a pawn can stand inside. Runs for previews too - the
## component stays inert (unregistered, no processing) until ready_constructed.
func _on_module_added(module: ModuleBase) -> void:
	if module.module_data == null:
		return
	if module.module_data.interaction_layer == WorldManager.StructureLayer.SPACE:
		return
	if not module.has_atmosphere or module.get_path_component() == null:
		return
	if module.get_component_by_type(AtmosphereComponent) != null:
		return
	var component: AtmosphereComponent = AtmosphereComponent.new()
	component.name = "AtmosphereComponent"
	component.owner_module = module
	component.ui_info_panel_element = atmosphere_ui_scene
	module.add_child(component)

func register_component(component: AtmosphereComponent) -> void:
	_components[component.owner_module] = component
	# Pre-latch when registering already-low (fresh builds start at vacuum,
	# loads restore gas after this): the alert only fires on a healthy->low
	# transition, so construction sprees don't spam the strip.
	if component.o2_partial() < alert_o2_partial:
		_low_o2_alerted[component.owner_module] = true

func unregister_component(component: AtmosphereComponent) -> void:
	if component.owner_module != null and _components.get(component.owner_module) == component:
		_components.erase(component.owner_module)
		_low_o2_alerted.erase(component.owner_module)

func get_component(module: ModuleBase) -> AtmosphereComponent:
	return _components.get(module)

## New-game seeding (WorldManager.spawn_starting_station): the starting station
## begins fully O2-pressurized so the player has slack while expanding. Never
## runs on load - saved pressures arrive via the module save section instead.
## Every starter module registers synchronously before this call (WI-18), so a
## single pass over the registered components covers them all.
func seed_starting_atmosphere() -> void:
	for component: AtmosphereComponent in _components.values():
		component.seed_full_o2()

## Random target for the hull-breach event effect. Prefers un-breached
## modules; if everything is already venting, refreshing one is fine.
func get_random_breach_target() -> AtmosphereComponent:
	var candidates: Array[AtmosphereComponent] = []
	var fallback: Array[AtmosphereComponent] = []
	for component: AtmosphereComponent in _components.values():
		if component.owner_module == null or not component.owner_module.is_complete():
			continue
		fallback.append(component)
		if not component.is_breached():
			candidates.append(component)
	if candidates.is_empty():
		candidates = fallback
	if candidates.is_empty():
		return null
	return candidates.pick_random()

func _on_slow_tick(interval: float) -> void:
	var sim_hours: float = interval / TimeManager.SECONDS_PER_HOUR
	_diffuse(sim_hours)
	_check_alerts()

## Pairwise door diffusion plus per-group plenum equalization. Both are
## exponential relaxations clamped so a tick never overshoots equilibrium,
## and both move gas symmetrically - total gas is conserved exactly.
func _diffuse(sim_hours: float) -> void:
	var step: float = minf(diffusion_rate_per_hour * sim_hours, 1.0)
	var groups: Dictionary[StringName, Array] = {}
	for module: ModuleBase in _components:
		var component: AtmosphereComponent = _components[module]
		var vertex: ModuleGraphVertex = Global.path_manager.get_vertex(module)
		if vertex == null or vertex.is_exterior:
			continue
		if vertex.group != &"":
			var members: Array = groups.get_or_add(vertex.group, [])
			members.append(component)
		for other_vertex: ModuleGraphVertex in vertex.edges.keys():
			var other_module: ModuleBase = other_vertex.node as ModuleBase
			if other_module == null or other_vertex.is_exterior:
				continue
			# Edges are symmetric; process each unordered pair once.
			if other_module.module_id <= module.module_id:
				continue
			var other: AtmosphereComponent = _components.get(other_module)
			if other == null:
				continue
			_exchange_pair(component, other, step)
	for group: StringName in groups:
		var members: Array = groups[group]
		if members.size() > 1:
			_equalize_group(members, step)

## Moves each gas `step` of the way toward the pair's shared equilibrium
## partial. The reduced volume va*vb/(va+vb) makes the full-step move land
## exactly at equal partials, so clamping step at 1 can never overshoot.
func _exchange_pair(a: AtmosphereComponent, b: AtmosphereComponent, step: float) -> void:
	var va: float = a.volume()
	var vb: float = b.volume()
	var reduced_volume: float = va * vb / (va + vb)
	var o2_flow: float = (a.o2 / va - b.o2 / vb) * reduced_volume * step
	a.o2 -= o2_flow
	b.o2 += o2_flow
	var co2_flow: float = (a.co2 / va - b.co2 / vb) * reduced_volume * step
	a.co2 -= co2_flow
	b.co2 += co2_flow

## Turbolift shafts: all cells of a shaft act as one connected air column, so
## equalize every member toward the group mean partial. Deltas sum to zero by
## construction (each target is the member's volume share of the total).
func _equalize_group(members: Array, step: float) -> void:
	var total_volume: float = 0.0
	var total_o2: float = 0.0
	var total_co2: float = 0.0
	for member: AtmosphereComponent in members:
		total_volume += member.volume()
		total_o2 += member.o2
		total_co2 += member.co2
	for member: AtmosphereComponent in members:
		var share: float = member.volume() / total_volume
		member.o2 += (total_o2 * share - member.o2) * step
		member.co2 += (total_co2 * share - member.co2) * step

## One alert per low-O2 episode per module; re-arms after recovery so a
## slowly oscillating module doesn't spam the strip.
func _check_alerts() -> void:
	for module: ModuleBase in _components:
		var component: AtmosphereComponent = _components[module]
		var partial: float = component.o2_partial()
		if _low_o2_alerted.get(module, false):
			if partial > alert_o2_partial + alert_rearm_margin:
				_low_o2_alerted.erase(module)
		elif partial < alert_o2_partial:
			_low_o2_alerted[module] = true
			var module_name: String = module.module_data.name if module.module_data != null else "module"
			SignalBus.station_alert.emit("Low oxygen in %s!" % module_name)

## Station-average O2 partial pressure across completed pressurized modules, as
## the percentage the OXYGEN vitals chip reads (WI-52).
##
## Volume-weighted, not a mean of the per-module partials: a 1-cell corridor at
## 10% and a 6-cell habitat at 100% is a station that is mostly fine, and an
## unweighted average would call it 55% and light the strip amber.
##
## Registration already implies "constructed" (a component registers in
## ready_constructed and unregisters on the way back to blueprint), so the
## validity check is only a guard against a module freed between ticks.
##
## On the same 0-100 scale as `alert_o2_partial` and `nominal_pressure`, so the
## chip's threshold and the low-O2 alert's agree by construction.
func station_average_o2_partial() -> float:
	var total_o2: float = 0.0
	var total_volume: float = 0.0
	for module: ModuleBase in _components:
		if module == null or not is_instance_valid(module):
			continue
		var volume: float = _components[module].volume()
		if volume <= 0.0:
			continue
		total_o2 += _components[module].o2
		total_volume += volume
	if total_volume <= 0.0:
		return 0.0
	return total_o2 / total_volume

## Console/debug helper: one line per registered module.
func debug_dump() -> String:
	var lines: Array[String] = []
	for module: ModuleBase in _components:
		var component: AtmosphereComponent = _components[module]
		var module_name: String = module.module_data.name if module.module_data != null else module.name
		lines.append("%s (id %d): pressure %.1f | O2 %.1f | CO2 %.1f%s" % [
			module_name, module.module_id, component.pressure(), component.o2_partial(),
			component.co2_partial(), " | BREACHED %.2fh" % component.breach_remaining_hours if component.is_breached() else ""])
	var total_gas: float = 0.0
	var total_volume: float = 0.0
	for component: AtmosphereComponent in _components.values():
		total_gas += component.o2 + component.co2
		total_volume += component.volume()
	lines.append("TOTAL: %.0f gas over %.0f volume (mean %.1f)" % [total_gas, total_volume, total_gas / total_volume if total_volume > 0.0 else 0.0])
	return "\n".join(lines)
