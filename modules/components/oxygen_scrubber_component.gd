class_name OxygenScrubberComponent
extends ComponentBase

## Regenerative O2 scrubber (WI-17): converts local CO2 back into O2 at a
## fixed rate. A 1:1 swap - restores breathable air but never raises total
## pressure, so it can't outrun a breach (that's the O2 generator's job).
## Diffusion keeps feeding CO2 from the rest of the station into this
## module, so one scrubber serves everything connected to it.

## CO2 units converted to O2 per game-hour. Routed through
## get_effective_stat(Stats.SCRUB_RATE) so upgrades apply non-destructively.
@export var scrub_rate_per_hour: float = 40.0
## Unpowered scrubbers stop dead - CO2 accumulates (intended death spiral).
@export var power_consumption_component: PowerConsumptionComponent

func _ready() -> void:
	super()
	set_process(false)

func ready_preview() -> void:
	set_process(false)

func ready_blueprint() -> void:
	set_process(false)

func ready_constructed() -> void:
	set_process(true)

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	if power_consumption_component != null and not power_consumption_component.powered:
		return
	var atmosphere: AtmosphereComponent = owner_module.get_component_by_type(AtmosphereComponent) as AtmosphereComponent
	if atmosphere == null:
		return
	var rate: float = owner_module.get_effective_stat(Stats.SCRUB_RATE, scrub_rate_per_hour)
	atmosphere.convert_co2_to_o2(rate * sim_hours)
