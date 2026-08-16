class_name HeatComponent
extends ComponentBase

## One module's thermal body (WI-60): its temperature, its capacity, and the
## throttle it puts on itself when it gets hot.
##
## Runtime-attached by [HeatManager] to every module on the structure graph -
## truss and exterior hardware included - so a module never has to opt in and a
## modded module joins the thermal network for nothing. This mirrors
## [AtmosphereComponent] deliberately; the difference is eligibility (heat
## conducts through plating, so there is no atmosphere or interior requirement)
## and the sink (every exposed face, continuously, rather than only a breach).
##
## The component holds state and reads its own module; every formula lives in the
## pure [HeatMath], and the manager owns the pass that drives them.

## Degrees Fahrenheit. The saved state, and the only number any consumer reads.
var temperature_f: float = HeatMath.NEUTRAL_TEMPERATURE_F

## True once the manager has this component in its pass. Only Built modules
## register - a blueprint is a frame, not a room.
var _registered: bool = false

## True once `temperature_f` means something: either a save restored it or the
## manager seeded it from this module's neighbours.
##
## This is what keeps the two from fighting. Registration happens during the ready
## pass and queues a DEFERRED seed (a fresh build has not formed its structural
## connections yet at that point), while load_save_data runs synchronously right
## after - so without this flag the deferred seed would land last and quietly
## discard every temperature in the save file.
var _temperature_known: bool = false

func _ready() -> void:
	# Runtime-attached: HeatManager sets owner_module before add_child, because
	# ComponentBase._ready derives it from the scene `owner` and a runtime node
	# has none. Keep the components-array registration either way (it is what
	# carries the save block).
	if owner_module == null:
		owner_module = get_parent_module()
	if owner_module != null and not owner_module.components.has(self):
		owner_module.components.append(self)

func ready_preview() -> void:
	_unregister()

func ready_blueprint() -> void:
	_unregister()

func ready_constructed() -> void:
	if Global.heat_manager != null:
		Global.heat_manager.register_component(self)
		_registered = true

## A module coming apart stops being a live part of the thermal network, the same
## way WI-39 drops a teardown site off the power grid.
func ready_deconstructing() -> void:
	_unregister()

func _exit_tree() -> void:
	_unregister()

func _unregister() -> void:
	_registered = false
	# The throttle is ours; leaving it behind would strand a stat modifier on a
	# module nothing is heating any more.
	if owner_module != null and is_instance_valid(owner_module):
		owner_module.stat_modifiers.remove_source(ModuleBase.HEAT_SOURCE)
	if Global.heat_manager != null:
		Global.heat_manager.unregister_component(self)

func is_registered() -> bool:
	return _registered

func temperature_is_known() -> bool:
	return _temperature_known

func mark_temperature_known() -> void:
	_temperature_known = true

# --- physical properties ------------------------------------------------------

## How much energy it takes to move this module one degree. The direct analogue
## of AtmosphereComponent.volume(): footprint cells scaled by a per-module-type
## density, so a big armoured module changes temperature slowly and a corridor
## cell whips around.
func thermal_mass() -> float:
	if owner_module == null:
		return 1.0
	var cells: int = maxi(owner_module.size.x * owner_module.size.y, 1)
	var per_cell: float = ModuleData.DEFAULT_THERMAL_MASS_PER_CELL
	if owner_module.module_data != null:
		per_cell = owner_module.module_data.heat_thermal_mass_per_cell
	return maxf(float(cells) * per_cell, 0.001)

## Fraction of this module's faces open to vacuum. Never zero - the implicit back
## face in [HeatMath.exposure_fraction] is what makes a sealed module settle at a
## finite temperature instead of climbing forever.
func exposure() -> float:
	if owner_module == null:
		return 1.0
	var structure: StructureComponent = owner_module.get_structure_component()
	if structure == null:
		# No structure component at all (nothing in the base game): treat it as
		# hanging in the open rather than as perfectly insulated, so it can still
		# reach equilibrium.
		return 1.0
	return structure.open_face_fraction()

## How good this module is at dumping heat, per unit of exposure. 1.0 for
## ordinary hull; the Radiator is nothing but this number turned up.
func radiation_multiplier() -> float:
	if owner_module == null or owner_module.module_data == null:
		return 1.0
	return maxf(owner_module.module_data.heat_radiation_mult, 0.0)

# --- energy -------------------------------------------------------------------

## Add (or, negative, remove) energy, converting through thermal mass. The one
## way anything outside this component changes a temperature.
func add_energy(energy: float) -> void:
	if energy == 0.0:
		return
	temperature_f += energy / thermal_mass()

## Total energy relative to a reference temperature. Only used by tests and the
## debug dump to assert conservation - the sim never needs an absolute figure.
func energy_above(reference_f: float) -> float:
	return (temperature_f - reference_f) * thermal_mass()

# --- throttle -----------------------------------------------------------------

## Re-derive this module's heat throttle from its current temperature.
##
## Writes the reserved &"heat" MULT layer on `process_time`, joining damage,
## breakdown and adjacency as a source that stacks with them and clears
## independently. Removed entirely below the start threshold, so a module that is
## merely warm has byte-for-byte its authored stats - the same regression
## guarantee _refresh_damage_modifier makes.
##
## This is half of the feedback loop the design rests on: throttling multiplies
## process_time up, a batch therefore advances a smaller fraction per second, and
## HeatEmitterComponent bills heat per batch-fraction - so a throttled machine
## emits proportionally less heat without anything knowing it is a loop.
func refresh_throttle() -> void:
	if owner_module == null or not is_instance_valid(owner_module):
		return
	var data: ModuleData = owner_module.module_data
	if data == null or not data.throttles_when_hot:
		return
	var multiplier: float = HeatMath.throttle_multiplier(temperature_f,
		data.heat_throttle_start_f, data.heat_throttle_full_f, data.heat_throttle_max_mult)
	if multiplier <= 1.0:
		owner_module.stat_modifiers.remove_source(ModuleBase.HEAT_SOURCE)
		return
	owner_module.stat_modifiers.set_single_modifier(&"process_time",
		StatModifiers.Op.MULT, multiplier, ModuleBase.HEAT_SOURCE)

## The throttle as the player reads it: 0 when running at full rate, 0.75 when a
## batch takes four times as long. Used by the Environment tab.
func throttle_penalty() -> float:
	var data: ModuleData = owner_module.module_data if owner_module != null else null
	if data == null or not data.throttles_when_hot:
		return 0.0
	var multiplier: float = HeatMath.throttle_multiplier(temperature_f,
		data.heat_throttle_start_f, data.heat_throttle_full_f, data.heat_throttle_max_mult)
	if multiplier <= 1.0:
		return 0.0
	return 1.0 - 1.0 / multiplier

# --- persistence --------------------------------------------------------------
#
# A temperature is genuinely stateful - it is the integral of everything that has
# happened to this module - so unlike the WI-30 adjacency fields it is saved
# rather than re-derived. One float.

## 65: free between the atmosphere block (60) and the O2 generator (70). Nothing
## orders against it; a temperature depends on no other component's restored
## state.
func save_order() -> int:
	return 65

func save_key() -> StringName:
	return &"heat"

func get_save_data() -> Dictionary:
	return {"temperature": temperature_f}

func load_save_data(data: Dictionary) -> void:
	temperature_f = float(data.get("temperature", HeatMath.NEUTRAL_TEMPERATURE_F))
	# Claim the temperature so the manager's deferred seed leaves it alone. A
	# save written before WI-60 has no block at all, so this never runs for one -
	# that module falls through to the seed, whose no-neighbour fallback is the
	# habitable midpoint rather than space. An old station loads warm.
	mark_temperature_known()
	refresh_throttle()
