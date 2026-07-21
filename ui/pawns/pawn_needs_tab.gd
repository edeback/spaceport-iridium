class_name PawnNeedsTab
extends PanelContainer

@export var health_bar: ProgressBar
@export var sleep_bar: ProgressBar
@export var hunger_bar: ProgressBar
@export var recreation_bar: ProgressBar
@export var happiness_bar: ProgressBar

var pawn_needs: PawnNeedsComponent = null
var pawn_health: PawnHealthComponent = null
var pawn_disease: PawnDiseaseComponent = null
## Dynamic disease list (WI-31), built in code and appended below the bars.
var _diseases_box: VBoxContainer = null

func set_pawn(_pawn: PawnBase) -> void:
	pawn_needs = _pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	pawn_health = _pawn.get_component_by_type(PawnHealthComponent) as PawnHealthComponent
	pawn_disease = _pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
	if pawn_needs == null and pawn_health == null:
		visible = false
		return
	# Active diseases + stage + treatment state (WI-31), for pawns that can get sick.
	if pawn_disease != null:
		pawn_disease.diseases_changed.connect(_rebuild_diseases)
		_rebuild_diseases()
	# Health lives in its own component (WI-05) - row shown iff it exists.
	if pawn_health != null:
		pawn_health.health_changed.connect(_on_health_changed)
		health_bar.value = pawn_health.health_value
	else:
		%HealthContainer.visible = false
	if pawn_needs != null:
		if pawn_needs.has_sleep_need:
			pawn_needs.sleep_changed.connect(_on_sleep_changed)
			sleep_bar.value = pawn_needs.sleep_value
		else:
			%SleepContainer.visible = false
		if pawn_needs.has_hunger_need:
			pawn_needs.hunger_changed.connect(_on_hunger_changed)
			hunger_bar.value = pawn_needs.hunger_value
		else:
			%HungerContainer.visible = false
		if pawn_needs.has_recreation_need:
			pawn_needs.recreation_changed.connect(_on_recreation_changed)
			recreation_bar.value = pawn_needs.recreation_value
		else:
			%RecreationContainer.visible = false
		pawn_needs.happiness_changed.connect(_on_happiness_changed)
		happiness_bar.value = pawn_needs.happiness * 100.0
	else:
		%SleepContainer.visible = false
		%HungerContainer.visible = false
		%RecreationContainer.visible = false
		%HappinessContainer.visible = false

func _on_health_changed(new_health: float) -> void:
	health_bar.value = new_health

func _on_sleep_changed(new_sleep: float) -> void:
	sleep_bar.value = new_sleep

func _on_hunger_changed(new_hunger: float) -> void:
	hunger_bar.value = new_hunger

func _on_recreation_changed(new_recreation: float) -> void:
	recreation_bar.value = new_recreation

func _on_happiness_changed(new_happiness: float) -> void:
	happiness_bar.value = new_happiness * 100.0

## Rebuilds the disease list from the pawn's active diseases (WI-31). Fires on
## infect/cure/worsen; the treatment % shows its value at build/change time.
func _rebuild_diseases() -> void:
	if pawn_disease == null:
		return
	if _diseases_box == null:
		_diseases_box = VBoxContainer.new()
		var container: VBoxContainer = get_node("MarginContainer/VBoxContainer") as VBoxContainer
		if container == null:
			return
		container.add_child(HSeparator.new())
		container.add_child(_diseases_box)
	for child: Node in _diseases_box.get_children():
		child.queue_free()
	var header := Label.new()
	header.text = "Diseases"
	_diseases_box.add_child(header)
	var ids: Array[StringName] = pawn_disease.active_ids()
	if ids.is_empty():
		var healthy := Label.new()
		healthy.text = "Healthy"
		healthy.modulate = Color(0.6, 1.0, 0.6)
		_diseases_box.add_child(healthy)
		return
	for id: StringName in ids:
		var disease: DiseaseData = DiseaseData.by_id(id)
		if disease == null:
			continue
		var row := Label.new()
		var stage: int = pawn_disease.stage_of(id)
		var treated: int = int(round(pawn_disease.treat_fraction(id) * 100.0))
		row.text = "%s - stage %d/%d - treated %d%%" % [disease.display_name, stage + 1, disease.stage_count(), treated]
		row.modulate = Color(1.0, 0.7, 0.6)
		row.tooltip_text = disease.description
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		_diseases_box.add_child(row)
