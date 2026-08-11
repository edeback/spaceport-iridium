class_name EventEffectDiseaseOutbreak
extends EventEffect

## Seeds a disease outbreak (WI-31): picks one infectious disease unlocked at the
## current station tier - the outbreak pool only holds contagious, outbreak-tagged
## diseases, so Void Sickness is never chosen - and infects a handful of random,
## currently-uninfected crew. Capped at crew-1 so even a two-crew station keeps
## someone on their feet (WI-31 edge case). From there it spreads on its own via
## PawnDiseaseComponent transmission.

@export var min_infections: int = 1
@export var max_infections: int = 3

func apply(_event: EventData) -> void:
	if Global.unlock_manager == null or Global.crew_manager == null:
		return
	var pool: Array[DiseaseData] = DiseaseData.outbreak_pool(Global.unlock_manager.current_tier)
	if pool.is_empty():
		return
	var disease: DiseaseData = pool.pick_random()
	# Only crew who could actually catch it: has a disease component (organic crew,
	# not a robot) and isn't already carrying this disease.
	var candidates: Array[PawnDiseaseComponent] = []
	for pawn: PawnBase in Global.crew_manager.get_crew():
		var disease_component: PawnDiseaseComponent = pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
		if disease_component != null and not disease_component.has_disease(disease.id):
			candidates.append(disease_component)
	if candidates.is_empty():
		return
	candidates.shuffle()
	# Leave at least one crew member uninfected by this outbreak (survivability).
	var cap: int = maxi(0, Global.crew_manager.get_crew().size() - 1)
	var count: int = clampi(randi_range(min_infections, max_infections), 0, mini(candidates.size(), cap))
	if count <= 0:
		return
	AlertManager.raise_alert(&"outbreak", AlertData.Priority.HIGH, "Disease outbreak",
		"%s is spreading through the station" % disease.display_name, null, &"crew")
	for i: int in count:
		candidates[i].infect(disease.id)

func describe() -> String:
	return "A disease outbreak infects several crew"
